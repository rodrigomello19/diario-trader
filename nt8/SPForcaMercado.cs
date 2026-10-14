// ============================================================================
//  SPForcaMercado v1.1 - forca compradora x vendedora, sinais e volatilidade (NT8)
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
//  Sinais (v1.1), avaliados no fechamento do candle:
//   C  continuacao  - agressao forte (delta z-score alto, |delta|/vol alto,
//                     RVOL alto) e o preco ACOMPANHOU (fechou no extremo)
//   A  absorcao     - agressao forte e o preco NAO acompanhou (fechou contra):
//                     ordens passivas seguraram -> possivel reversao
//   D  divergencia  - nova maxima/minima de N candles sem o delta acumulado
//                     confirmar -> possivel exaustao/reversao
//  Cada sinal e testado no historico carregado: alvo X pts antes de stop Y pts
//  em ate K candles. O painel mostra a taxa de acerto e o numero de casos.
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
using System.Text;
using System.Windows;
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

        // --- sinais
        private const int NTIPOS = 6;
        private static readonly string[] NomeSinal = { "C\u25B2", "C\u25BC", "A\u25B2", "A\u25BC", "D\u25B2", "D\u25BC" };
        private static readonly string[] DescSinal =
        {
            "continuacao compradora", "continuacao vendedora",
            "absorcao da venda (reversao p/ cima)", "absorcao da compra (reversao p/ baixo)",
            "divergencia de fundo (delta nao confirmou a minima)", "divergencia de topo (delta nao confirmou a maxima)"
        };
        private class SinalPendente
        {
            public int    Tipo;
            public int    Dir;
            public double Entrada;
            public int    BarIdx;
        }
        private readonly List<SinalPendente> pendentes = new List<SinalPendente>();
        private readonly int[] acertos = new int[NTIPOS];
        private readonly int[] erros   = new int[NTIPOS];
        private readonly int[] neutros = new int[NTIPOS];
        private readonly Queue<double> deltasRecentes = new Queue<double>();
        private const int JANELA_ZSCORE = 200;
        private string ultimoSinalTexto = "";

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

        [NinjaScriptProperty]
        [Display(Name = "Mostrar sinais", GroupName = "3. Sinais", Order = 1)]
        public bool MostrarSinais { get; set; }

        [NinjaScriptProperty]
        [Range(0.5, 10.0)]
        [Display(Name = "Agressao forte: z-score do delta", Description = "Quantos desvios padrao o delta do candle precisa estar acima do normal (ultimos 200 candles)", GroupName = "3. Sinais", Order = 2)]
        public double ZScoreMinimo { get; set; }

        [NinjaScriptProperty]
        [Range(0.0, 20.0)]
        [Display(Name = "Continuacao: RVOL minimo", Description = "Volume do candle / media do mesmo minuto. 0 = nao exigir", GroupName = "3. Sinais", Order = 3)]
        public double RvolMinimo { get; set; }

        [NinjaScriptProperty]
        [Range(3, 200)]
        [Display(Name = "Divergencia: candles da maxima/minima", GroupName = "3. Sinais", Order = 4)]
        public int CandlesDivergencia { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Sinais so no pregao de NY (abertura ate 16:00 ET)", GroupName = "3. Sinais", Order = 5)]
        public bool SinaisSoPregao { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Pintar o candle do sinal no grafico de preco", GroupName = "3. Sinais", Order = 6)]
        public bool PintarCandles { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Alerta sonoro em tempo real", GroupName = "3. Sinais", Order = 7)]
        public bool AlertaSonoro { get; set; }

        [NinjaScriptProperty]
        [Range(0.25, 100000)]
        [Display(Name = "Alvo para contar acerto (pontos)", GroupName = "4. Estatistica dos sinais", Order = 1)]
        public double AlvoPontos { get; set; }

        [NinjaScriptProperty]
        [Range(0.25, 100000)]
        [Display(Name = "Stop para contar erro (pontos)", GroupName = "4. Estatistica dos sinais", Order = 2)]
        public double StopPontos { get; set; }

        [NinjaScriptProperty]
        [Range(1, 500)]
        [Display(Name = "Candles para avaliar", Description = "Sem alvo nem stop nesse prazo = neutro", GroupName = "4. Estatistica dos sinais", Order = 3)]
        public int CandlesAvaliacao { get; set; }
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

                MostrarSinais      = true;
                ZScoreMinimo       = 2.0;
                RvolMinimo         = 1.2;
                CandlesDivergencia = 10;
                SinaisSoPregao     = true;
                PintarCandles      = true;
                AlertaSonoro       = false;
                AlvoPontos         = 20;
                StopPontos         = 20;
                CandlesAvaliacao   = 10;

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
            double volMediaMinuto = Media(volPorMinuto, minuto);   // antes de incluir este candle
            if (MostrarSinais)
            {
                AvaliarPendentes(idx);
                DetectarSinais(idx, horaNy, delta, volMediaMinuto);
            }
            AdicionarMedia(ampPorMinuto, minuto, Bars.GetHigh(idx) - Bars.GetLow(idx));
            AdicionarMedia(volPorMinuto, minuto, Bars.GetVolume(idx));
        }

        // ------------------------------------------------------------------
        //  Sinais
        // ------------------------------------------------------------------
        private bool NoPregao(DateTime horaNy)
        {
            if (!SinaisSoPregao) return true;
            return janela.Ativo && horaNy.Date == janela.Dia && AposAbertura(horaNy)
                   && horaNy.TimeOfDay <= new TimeSpan(16, 0, 0);
        }

        private void DetectarSinais(int idx, DateTime horaNy, double delta, double volMediaMinuto)
        {
            double compra = serieCompra.GetValueAt(idx);
            double venda  = serieVenda.GetValueAt(idx);
            double vol    = compra + venda;

            // z-score do delta contra os ultimos candles (sem incluir o atual)
            double media = 0, desvio = 0;
            int n = deltasRecentes.Count;
            if (n > 0)
            {
                foreach (double d in deltasRecentes) media += d;
                media /= n;
                foreach (double d in deltasRecentes) desvio += (d - media) * (d - media);
                desvio = Math.Sqrt(desvio / n);
            }
            if (vol > 0)
            {
                deltasRecentes.Enqueue(delta);
                while (deltasRecentes.Count > JANELA_ZSCORE) deltasRecentes.Dequeue();
            }
            if (vol <= 0 || n < 30 || desvio <= 0 || !NoPregao(horaNy)) return;

            double z     = (delta - media) / desvio;
            double ratio = delta / vol;
            double o = Bars.GetOpen(idx), h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            double amp = h - l;
            double clv = amp > 0 ? (c - l) / amp : 0.5;
            double rvol = volMediaMinuto > 0 ? Bars.GetVolume(idx) / volMediaMinuto : 0;
            bool rvolOk = RvolMinimo <= 0 || volMediaMinuto <= 0 || rvol >= RvolMinimo;

            int tipo = -1;
            if (z >= ZScoreMinimo && ratio >= LimiarForte && clv >= 0.7 && c > o && rvolOk)       tipo = 0;
            else if (z <= -ZScoreMinimo && ratio <= -LimiarForte && clv <= 0.3 && c < o && rvolOk) tipo = 1;
            else if (z <= -ZScoreMinimo && c >= o && clv >= 0.5)                                   tipo = 2;
            else if (z >= ZScoreMinimo && c <= o && clv <= 0.5)                                    tipo = 3;

            if (tipo >= 0)
                RegistrarSinal(tipo, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "delta {0:+#,##0;-#,##0} (z {1:+0.0;-0.0}), {2:0}% do volume, fechou a {3:0}% do candle{4}",
                    delta, z, 100 * Math.Abs(ratio), 100 * clv,
                    volMediaMinuto > 0 ? string.Format(new CultureInfo("pt-BR"), ", RVOL {0:0.0}x", rvol) : ""));

            // divergencia: nova maxima/minima de N candles sem o delta acumulado confirmar
            int ini = idx - CandlesDivergencia;
            if (ini < 0) return;
            DateTime horaIni = TimeZoneInfo.ConvertTime(Bars.GetTime(ini), tzGrafico, tzNy);
            if (!NoPregao(horaIni) || horaIni.Date != horaNy.Date) return;

            int jMax = ini, jMin = ini;
            for (int j = ini; j < idx; j++)
            {
                if (Bars.GetHigh(j) > Bars.GetHigh(jMax)) jMax = j;
                if (Bars.GetLow(j)  < Bars.GetLow(jMin))  jMin = j;
            }
            double cvd = serieAcum.GetValueAt(idx);
            if (h > Bars.GetHigh(jMax) && cvd < serieAcum.GetValueAt(jMax))
                RegistrarSinal(5, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "nova maxima de {0} candles com delta acumulado {1:+#,##0;-#,##0} abaixo do topo anterior ({2:+#,##0;-#,##0})",
                    CandlesDivergencia, cvd, serieAcum.GetValueAt(jMax)));
            else if (l < Bars.GetLow(jMin) && cvd > serieAcum.GetValueAt(jMin))
                RegistrarSinal(4, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "nova minima de {0} candles com delta acumulado {1:+#,##0;-#,##0} acima do fundo anterior ({2:+#,##0;-#,##0})",
                    CandlesDivergencia, cvd, serieAcum.GetValueAt(jMin)));
        }

        private Brush CorSinal(int tipo)
        {
            switch (tipo)
            {
                case 0: return Brushes.LimeGreen;
                case 1: return Brushes.Red;
                case 2: return Brushes.DeepSkyBlue;
                case 3: return Brushes.Orange;
                default: return Brushes.Violet;
            }
        }

        private void RegistrarSinal(int tipo, int idx, DateTime horaNy, string detalhe)
        {
            int dir = (tipo % 2 == 0) ? 1 : -1;
            pendentes.Add(new SinalPendente { Tipo = tipo, Dir = dir, Entrada = Bars.GetClose(idx), BarIdx = idx });

            int barsAgo = CurrentBar - idx;
            Brush cor = CorSinal(tipo);
            double y = Values[0].GetValueAt(idx);
            Draw.Text(this, "SPF_S" + idx + "_" + tipo, false, NomeSinal[tipo], barsAgo, y,
                dir > 0 ? -16 - (tipo >= 4 ? 14 : 0) : 16 + (tipo >= 4 ? 14 : 0),
                cor, new SimpleFont("Arial", 11) { Bold = true }, TextAlignment.Center, Brushes.Transparent, Brushes.Transparent, 0);
            if (PintarCandles && barsAgo >= 0)
                BarBrushes[barsAgo] = cor;

            ultimoSinalTexto = string.Format("Ultimo sinal: {0} {1:HH:mm} ET - {2}: {3}", NomeSinal[tipo], horaNy, DescSinal[tipo], detalhe);
            if (AlertaSonoro && State == State.Realtime)
                Alert("SPF_" + tipo, Priority.Medium, "SPForca " + NomeSinal[tipo] + " " + DescSinal[tipo],
                    NinjaTrader.Core.Globals.InstallDir + @"\sounds\Alert2.wav", 10, Brushes.Black, cor);
        }

        // Atualiza os sinais em aberto com a maxima/minima do candle idx.
        private void AvaliarPendentes(int idx)
        {
            double h = Bars.GetHigh(idx), l = Bars.GetLow(idx);
            for (int k = pendentes.Count - 1; k >= 0; k--)
            {
                SinalPendente p = pendentes[k];
                if (p.BarIdx >= idx) continue;
                double alvo = p.Entrada + p.Dir * AlvoPontos;
                double stop = p.Entrada - p.Dir * StopPontos;
                bool bateuAlvo = p.Dir > 0 ? h >= alvo : l <= alvo;
                bool bateuStop = p.Dir > 0 ? l <= stop : h >= stop;
                if (bateuStop)        erros[p.Tipo]++;     // alvo e stop no mesmo candle conta como erro
                else if (bateuAlvo)   acertos[p.Tipo]++;
                else if (idx - p.BarIdx >= CandlesAvaliacao) neutros[p.Tipo]++;
                else continue;
                pendentes.RemoveAt(k);
            }
        }

        private string TextoEstatistica()
        {
            CultureInfo br = new CultureInfo("pt-BR");
            StringBuilder sb = new StringBuilder();
            sb.AppendFormat(br, "Acerto dos sinais (alvo {0:0.##} antes de stop {1:0.##} pts, ate {2} candles):", AlvoPontos, StopPontos, CandlesAvaliacao);
            for (int t = 0; t < NTIPOS; t++)
            {
                int dec = acertos[t] + erros[t];
                sb.Append(t % 2 == 0 ? "\n  " : "   |   ");
                sb.AppendFormat(br, "{0} {1}", NomeSinal[t], dec > 0 ? string.Format(br, "{0:0}% ({1}/{2})", 100.0 * acertos[t] / dec, acertos[t], dec) : "sem casos");
                if (neutros[t] > 0) sb.AppendFormat(br, " +{0} neutros", neutros[t]);
            }
            return sb.ToString();
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

            string linhaSinais = MostrarSinais
                ? "\n" + TextoEstatistica() + (ultimoSinalTexto != "" ? "\n" + ultimoSinalTexto : "")
                : "";

            Brush cor = total <= 0 ? Brushes.Gainsboro : (compra >= venda ? Brushes.LimeGreen : Brushes.Tomato);
            Draw.TextFixed(this, "SPForcaResumo",
                titulo + "\n" + linhaForca + "\n" + linhaCandle + (linhaRange != "" ? "\n" + linhaRange : "") + linhaSinais,
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
