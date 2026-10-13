// ============================================================================
//  SPForcaMercado v1.0 - forca compradora x vendedora e volatilidade (NT8)
// ----------------------------------------------------------------------------
//  Para futuros (MNQ/NQ, MGC/GC...) no grafico de 1 minuto.
//
//  Delta real por agressao: cada negocio (tick "Last") e classificado como
//   compra  - executado no ask ou acima (comprador agrediu)
//   venda   - executado no bid ou abaixo (vendedor agrediu)
//   dentro do spread - pela direcao do ultimo preco (tick rule)
//  Delta do candle = volume comprado - volume vendido.
//  Delta acumulado = soma desde a abertura de NY (09:30 ET por padrao).
//
//  Volatilidade relativa ao horario: amplitude e volume de cada candle
//  comparados com a media do MESMO minuto nos ultimos N dias (RVOL).
//
//  Historico: precisa de "Tick Replay" ligado no grafico (Data Series >
//  Tick Replay). Sem ele, o delta comeca a ser contado quando o grafico abre.
// ============================================================================
#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

public enum SPForcaModoGrafico
{
    DeltaPorCandle,
    DeltaAcumulado
}

namespace NinjaTrader.NinjaScript.Indicators
{
    public class SPForcaMercado : Indicator
    {
        private class DadosDia
        {
            public DateTime Dia;
            public double   Maxima = double.MinValue;
            public double   Minima = double.MaxValue;
            public double   Compra;
            public double   Venda;
            public bool     Ativo;
        }

        // acumuladores do candle em formacao
        private double tickCompra, tickVenda;        // volume do ultimo negocio (aplicado no OnBarUpdate)
        private double candleCompra, candleVenda;
        private double ultimoPreco;
        private int    direcaoTick;                   // +1 / -1 (tick rule)
        private bool   recebeuTicks;

        // series
        private Series<double> serieCompra, serieVenda, serieAcum;

        // sessao NY
        private TimeZoneInfo tzNy, tzGrafico;
        private TimeSpan     aberturaEt;
        private DateTime     diaNyAtual = DateTime.MinValue;
        private double       acumulado;
        private readonly DadosDia janela = new DadosDia();
        private readonly List<double> amplitudesAbertura = new List<double>();   // amplitude da janela em dias anteriores

        // estatistica por minuto do dia (ET): ultimos N valores
        private readonly Dictionary<int, Queue<double>> ampPorMinuto = new Dictionary<int, Queue<double>>();
        private readonly Dictionary<int, Queue<double>> volPorMinuto = new Dictionary<int, Queue<double>>();

        #region Parametros
        [NinjaScriptProperty]
        [Display(Name = "Abertura de NY (HH:mm, horario de NY)", GroupName = "1. Sessao", Order = 1)]
        public string AberturaNY { get; set; }

        [NinjaScriptProperty]
        [Range(0, 1440)]
        [Display(Name = "Janela da abertura (min, 0 = sessao toda)", Description = "Periodo resumido no painel a partir da abertura", GroupName = "1. Sessao", Order = 2)]
        public int JanelaMinutos { get; set; }

        [NinjaScriptProperty]
        [Range(1, 120)]
        [Display(Name = "Dias para a media do horario", GroupName = "1. Sessao", Order = 3)]
        public int DiasMedia { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Grafico", GroupName = "2. Exibicao", Order = 1)]
        public SPForcaModoGrafico ModoGrafico { get; set; }

        [NinjaScriptProperty]
        [Range(0.01, 1.0)]
        [Display(Name = "Limiar de candle forte (|delta| / volume)", Description = "0,25 = 25% do volume do candle num so lado", GroupName = "2. Exibicao", Order = 2)]
        public double LimiarForte { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Mostrar resumo no grafico", GroupName = "2. Exibicao", Order = 3)]
        public bool MostrarResumo { get; set; }
        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name                     = "SPForcaMercado";
                Description              = "Delta (agressao compradora x vendedora), delta acumulado desde a abertura de NY e volatilidade/volume relativos ao horario.";
                Calculate                = Calculate.OnEachTick;
                IsOverlay                = false;
                DisplayInDataBox         = true;
                DrawOnPricePanel         = false;
                PaintPriceMarkers        = true;
                IsSuspendedWhileInactive = false;
                BarsRequiredToPlot       = 0;

                AberturaNY    = "09:30";
                JanelaMinutos = 60;
                DiasMedia     = 20;
                ModoGrafico   = SPForcaModoGrafico.DeltaPorCandle;
                LimiarForte   = 0.25;
                MostrarResumo = true;

                AddPlot(new Stroke(Brushes.Gray, 3), PlotStyle.Bar, "Delta");
                AddLine(new Stroke(Brushes.DimGray, DashStyleHelper.Dash, 1), 0, "Zero");
            }
            else if (State == State.DataLoaded)
            {
                serieCompra = new Series<double>(this, MaximumBarsLookBack.Infinite);
                serieVenda  = new Series<double>(this, MaximumBarsLookBack.Infinite);
                serieAcum   = new Series<double>(this, MaximumBarsLookBack.Infinite);

                tzGrafico = Core.Globals.GeneralOptions.TimeZoneInfo;
                try { tzNy = TimeZoneInfo.FindSystemTimeZoneById("Eastern Standard Time"); }
                catch (Exception) { tzNy = tzGrafico; }
                if (!TimeSpan.TryParseExact((AberturaNY ?? "").Trim(), new[] { @"hh\:mm", @"h\:mm" }, CultureInfo.InvariantCulture, out aberturaEt))
                    aberturaEt = new TimeSpan(9, 30, 0);

                if (ModoGrafico == SPForcaModoGrafico.DeltaAcumulado)
                {
                    Plots[0].PlotStyle = PlotStyle.Line;
                    Plots[0].Width     = 2;
                }
            }
        }

        // Classifica cada negocio. O volume e aplicado no OnBarUpdate seguinte, que ja
        // pertence ao candle correto (o OnMarketData do 1o tick chega antes do candle novo).
        protected override void OnMarketData(MarketDataEventArgs e)
        {
            if (e.MarketDataType != MarketDataType.Last || e.Volume <= 0) return;
            recebeuTicks = true;

            double preco = e.Price;
            int lado;
            if (e.Ask > 0 && preco >= e.Ask)       lado = 1;
            else if (e.Bid > 0 && preco <= e.Bid)  lado = -1;
            else
            {
                if (ultimoPreco > 0 && preco > ultimoPreco)      direcaoTick = 1;
                else if (ultimoPreco > 0 && preco < ultimoPreco) direcaoTick = -1;
                lado = direcaoTick;
            }
            ultimoPreco = preco;

            if (lado > 0)      tickCompra += e.Volume;
            else if (lado < 0) tickVenda  += e.Volume;
        }

        protected override void OnBarUpdate()
        {
            DateTime horaNy = TimeZoneInfo.ConvertTime(Time[0], tzGrafico, tzNy);
            int minutoDia = (int)horaNy.TimeOfDay.TotalMinutes;

            if (IsFirstTickOfBar)
            {
                if (CurrentBar > 0)
                    FinalizarCandle(CurrentBar - 1, Time[1]);
                candleCompra = 0;
                candleVenda  = 0;
                NovaSessaoSeAbertura(horaNy);
            }

            candleCompra += tickCompra;
            candleVenda  += tickVenda;
            tickCompra = 0;
            tickVenda  = 0;

            serieCompra[0] = candleCompra;
            serieVenda[0]  = candleVenda;
            double delta = candleCompra - candleVenda;

            double acumAtual = acumulado + (janela.Ativo && AposAbertura(horaNy) ? delta : 0);
            serieAcum[0] = acumAtual;

            if (ModoGrafico == SPForcaModoGrafico.DeltaAcumulado)
            {
                Value[0] = acumAtual;
                PlotBrushes[0][0] = acumAtual >= 0 ? Brushes.LimeGreen : Brushes.Red;
            }
            else
            {
                Value[0] = delta;
                double vol = candleCompra + candleVenda;
                bool forte = vol > 0 && Math.Abs(delta) / vol >= LimiarForte;
                PlotBrushes[0][0] = delta >= 0
                    ? (forte ? Brushes.LimeGreen : Brushes.DarkGreen)
                    : (forte ? Brushes.Red : Brushes.DarkRed);
            }

            // janela da abertura: maxima/minima e volume por lado ate agora (inclui o candle atual)
            if (janela.Ativo && DentroDaJanela(horaNy))
            {
                janela.Maxima = Math.Max(janela.Maxima, High[0]);
                janela.Minima = Math.Min(janela.Minima, Low[0]);
            }

            if (MostrarResumo && (State == State.Realtime || CurrentBar >= Count - 2))
                DesenharResumo(minutoDia, delta);
        }

        // Fecha o candle anterior: entra no acumulado e nas medias por minuto.
        private void FinalizarCandle(int idx, DateTime horaGrafico)
        {
            DateTime horaNy = TimeZoneInfo.ConvertTime(horaGrafico, tzGrafico, tzNy);
            double delta = serieCompra.GetValueAt(idx) - serieVenda.GetValueAt(idx);

            if (janela.Ativo && AposAbertura(horaNy))
            {
                acumulado += delta;
                if (DentroDaJanela(horaNy))
                {
                    janela.Compra += serieCompra.GetValueAt(idx);
                    janela.Venda  += serieVenda.GetValueAt(idx);
                }
            }

            int minuto = (int)horaNy.TimeOfDay.TotalMinutes;
            AdicionarMedia(ampPorMinuto, minuto, Bars.GetHigh(idx) - Bars.GetLow(idx));
            AdicionarMedia(volPorMinuto, minuto, Bars.GetVolume(idx));
        }

        private void NovaSessaoSeAbertura(DateTime horaNy)
        {
            if (!AposAbertura(horaNy) || horaNy.Date == diaNyAtual) return;

            // guarda a amplitude da janela do dia anterior para a media
            if (janela.Ativo && janela.Maxima > janela.Minima)
            {
                amplitudesAbertura.Add(janela.Maxima - janela.Minima);
                while (amplitudesAbertura.Count > DiasMedia) amplitudesAbertura.RemoveAt(0);
            }

            diaNyAtual    = horaNy.Date;
            acumulado     = 0;
            janela.Dia    = horaNy.Date;
            janela.Maxima = double.MinValue;
            janela.Minima = double.MaxValue;
            janela.Compra = 0;
            janela.Venda  = 0;
            janela.Ativo  = true;
        }

        // No NT8 o horario do candle e o do FECHAMENTO: o candle 09:31 cobre 09:30-09:31.
        private bool AposAbertura(DateTime horaNy)
        {
            return horaNy.TimeOfDay > aberturaEt;
        }

        private bool DentroDaJanela(DateTime horaNy)
        {
            if (!janela.Ativo || horaNy.Date != janela.Dia || !AposAbertura(horaNy)) return false;
            return JanelaMinutos <= 0 || horaNy.TimeOfDay <= aberturaEt + TimeSpan.FromMinutes(JanelaMinutos);
        }

        private void AdicionarMedia(Dictionary<int, Queue<double>> d, int minuto, double valor)
        {
            Queue<double> q;
            if (!d.TryGetValue(minuto, out q)) { q = new Queue<double>(); d[minuto] = q; }
            q.Enqueue(valor);
            while (q.Count > DiasMedia) q.Dequeue();
        }

        private static double Media(Dictionary<int, Queue<double>> d, int minuto)
        {
            Queue<double> q;
            if (!d.TryGetValue(minuto, out q) || q.Count == 0) return 0;
            double s = 0;
            foreach (double v in q) s += v;
            return s / q.Count;
        }

        private void DesenharResumo(int minutoDia, double deltaCandle)
        {
            CultureInfo br = new CultureInfo("pt-BR");
            double compra = janela.Compra + candleCompra;
            double venda  = janela.Venda + candleVenda;
            DateTime horaNy = TimeZoneInfo.ConvertTime(Time[0], tzGrafico, tzNy);
            bool naJanela = DentroDaJanela(horaNy);
            if (!naJanela) { compra = janela.Compra; venda = janela.Venda; }
            double total = compra + venda;

            string titulo = JanelaMinutos > 0
                ? string.Format("FORCA DA ABERTURA DE NY ({0:hh\\:mm} ET, {1} min)", aberturaEt, JanelaMinutos)
                : string.Format("FORCA DESDE A ABERTURA DE NY ({0:hh\\:mm} ET)", aberturaEt);

            string linhaForca;
            if (!janela.Ativo)
                linhaForca = "Aguardando a abertura.";
            else if (total <= 0)
                linhaForca = recebeuTicks ? "Sem negocios na janela ainda." : "Sem dados de negocio (ative o Tick Replay para o historico).";
            else
                linhaForca = string.Format(br, "Compradores {0:0}%  x  Vendedores {1:0}%   |   Delta {2:+#,##0;-#,##0;0}   |   Delta acumulado {3:+#,##0;-#,##0;0}",
                    100.0 * compra / total, 100.0 * venda / total, compra - venda, serieAcum[0]);

            double ampMedia = Media(ampPorMinuto, minutoDia);
            double volMedia = Media(volPorMinuto, minutoDia);
            double amp = High[0] - Low[0];
            string linhaCandle = string.Format(br, "Candle atual: delta {0:+#,##0;-#,##0;0} | amplitude {1:0.##} ({2}) | volume {3:#,##0} ({4})",
                deltaCandle, amp,
                ampMedia > 0 ? (amp / ampMedia).ToString("0.0", br) + "x a media do horario" : "sem media",
                Volume[0],
                volMedia > 0 ? "RVOL " + (Volume[0] / volMedia).ToString("0.0", br) + "x" : "sem media");

            string linhaRange = "";
            if (janela.Ativo && janela.Maxima > janela.Minima)
            {
                double ampJanela = janela.Maxima - janela.Minima;
                double mediaAb = 0;
                foreach (double v in amplitudesAbertura) mediaAb += v;
                mediaAb = amplitudesAbertura.Count > 0 ? mediaAb / amplitudesAbertura.Count : 0;
                linhaRange = string.Format(br, "Amplitude da janela: {0:0.##} pts{1}", ampJanela,
                    mediaAb > 0 ? string.Format(br, " ({0:0.0}x a media de {1} dias: {2:0.##} pts)", ampJanela / mediaAb, amplitudesAbertura.Count, mediaAb) : "");
            }

            Brush cor = total <= 0 ? Brushes.Gainsboro : (compra >= venda ? Brushes.LimeGreen : Brushes.Tomato);
            Draw.TextFixed(this, "SPForcaResumo",
                titulo + "\n" + linhaForca + "\n" + linhaCandle + (linhaRange != "" ? "\n" + linhaRange : ""),
                TextPosition.TopLeft, cor, new SimpleFont("Consolas", 11), Brushes.Transparent, Brushes.Black, 70);
        }

        #region Propriedades de saida
        [Browsable(false)]
        [XmlIgnore]
        public Series<double> Delta { get { return Values[0]; } }

        [Browsable(false)]
        [XmlIgnore]
        public Series<double> DeltaAcumuladoSerie { get { return serieAcum; } }
        #endregion
    }
}
