// ============================================================================
//  SPForcaMercado v1.9 - forca compradora x vendedora, sinais e volatilidade (NT8)
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
//  v1.2: barras de delta so para cima (cor = lado), resumo arrastavel com o
//  mouse, resultado de cada sinal no grafico e arquivo CSV com todos os sinais
//  em Documentos\NinjaTrader 8\SPForca\.
//
//  v1.3: horario dos sinais (padrao 09:30-10:30 NY = abertura), divergencia
//  mais seletiva (20 candles + diferenca minima de delta acumulado), alvo/stop
//  40/40 e MODO PESQUISA: grava todos os candles da janela com as
//  caracteristicas e o que o preco fez depois (5/10/15 min, alvo x stop)
//  em Documentos\NinjaTrader 8\SPForca\pesquisa_<contrato>.csv.
//
//  v1.4: filtro de volatilidade (LENTA/NORMAL/RAPIDA, com a estatistica do
//  proprio historico). O modo pesquisa funciona tambem sem Tick Replay
//  (colunas de delta ficam zeradas), para estudar anos de dados.
//  (o estudo de regioes/padroes da v1.4-1.5 foi retirado a pedido)
//
//  v1.6: LEITURA DO CANDLE em tempo real (sem regioes): agressao do candle e
//  dos ultimos 5 min, sinais de esgotamento e a chance de o candle romper a
//  propria maxima antes da minima (continuacao) medida no seu historico, ao
//  lado da chance "por acaso" dada so pela posicao do fechamento.
//
//  v1.7: sai o painel "Forca da abertura" (ficam volatilidade e leitura).
//  No grafico de PRECO:
//   seta F  - agressao acima da media (z-score do delta >= limite), na
//             direcao da agressao, no fechamento do candle
//   EX      - esgotamento/absorcao: depois de varios candles numa direcao,
//             um candle muito maior e com volume bem acima dos anteriores
//             faz novo extremo -> possivel entrada do lado oposto
//  Os sinais antigos C/A/D ficam desligados por padrao.
//
//  v1.8 (apos o estudo de 93 pregoes): o z-score da seta e da leitura passa a
//  comparar o delta com o MESMO MINUTO dos ultimos N dias (antes, contra os
//  ultimos 200 candles, que incluem o overnight calmo, 35% dos candles da
//  abertura viravam seta). Nova marca EXc: EX confirmado pelo candle seguinte
//  (fecha a favor da reversao), com estatistica propria.
//
//  v1.9: barras do delta sempre para cima (cor pela agressao ou pelo candle);
//  painel COMPACTO por padrao (fonte menor, fundo mais transparente, poucas
//  linhas). Clique no painel alterna compacto/detalhado; arraste para mover.
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
using System.Linq;
using System.Text;
using System.Windows;
using System.Windows.Media;
using System.Xml.Serialization;
using NinjaTrader.Gui;
using NinjaTrader.Gui.Tools;
using NinjaTrader.Gui.Chart;
using System.IO;
using NinjaTrader.Data;
using NinjaTrader.NinjaScript.DrawingTools;
#endregion

public enum SPForcaModoGrafico
{
    DeltaPorCandle,
    DeltaAcumulado,
    DeltaColorido      // barras so para cima, verde = compradores, vermelho = vendedores
}

public enum SPForcaCorBarras
{
    PelaAgressao,      // verde = delta comprador, vermelho = delta vendedor
    PeloCandle         // verde = candle de alta, vermelho = candle de baixa
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

        // --- sinais
        private const int NTIPOS = 12;
        private const int TIPO_SETA = 6, TIPO_EXAUSTAO = 8, TIPO_EXC = 10;
        private static readonly string[] NomeSinal = { "C\u25B2", "C\u25BC", "A\u25B2", "A\u25BC", "D\u25B2", "D\u25BC",
                                                       "F\u25B2", "F\u25BC", "EX\u25B2", "EX\u25BC", "EXc\u25B2", "EXc\u25BC" };
        private static readonly string[] DescSinal =
        {
            "continuacao compradora", "continuacao vendedora",
            "absorcao da venda (reversao p/ cima)", "absorcao da compra (reversao p/ baixo)",
            "divergencia de fundo (delta nao confirmou a minima)", "divergencia de topo (delta nao confirmou a maxima)",
            "agressao compradora acima da media", "agressao vendedora acima da media",
            "esgotamento da venda (possivel entrada compradora)", "esgotamento da compra (possivel entrada vendedora)",
            "esgotamento da venda confirmado pelo candle seguinte", "esgotamento da compra confirmado pelo candle seguinte"
        };
        private readonly Dictionary<int, int> rotulosPorLado = new Dictionary<int, int>();   // empilha os rotulos do mesmo candle
        private readonly double[] somaFavor  = new double[NTIPOS];
        private readonly double[] somaContra = new double[NTIPOS];
        private class SinalPendente
        {
            public int      Tipo;
            public int      Dir;
            public double   Entrada;
            public int      BarIdx;
            public DateTime HoraNy;
            public string   Tag;
            public double   Y;
            public int      Offset;
            public string   Campos;     // colunas de caracteristicas para o CSV
            public double   MaxFavor;
            public double   MaxContra;
        }
        private class LinhaPesquisa
        {
            public int      BarIdx;
            public string   Base;       // colunas ja conhecidas no fechamento do candle
            public double   Close;
            public double   MaxH, MinL;
            public double   F5, F10, F15;
            public int      ResCompra, ResVenda;   // 0 pendente, 1 alvo, -1 stop
            public int      CandlesCompra, CandlesVenda;
            public string   Extra = "";  // colunas adicionadas no fim da linha (v1.4)
            public double   AmpRel3;     // volatilidade no momento (para a estatistica do filtro)
            public int      Dir;         // padroes: +1 compra, -1 venda
        }

        // --- regioes (v1.4)
        private DateTime rthDia = DateTime.MinValue;
        private double rthH = double.NaN, rthL = double.NaN, rthC = double.NaN;
        private double pdh = double.NaN, pdl = double.NaN, pdc = double.NaN;
        private double onH = double.NaN, onL = double.NaN, onHHoje = double.NaN, onLHoje = double.NaN;
        private bool   emOvernight;
        private double or5H = double.NaN, or5L = double.NaN, or15H = double.NaN, or15L = double.NaN;
        private double vwapPV, vwapV;
        private DateTime diaGlobex = DateTime.MinValue;
        private double   diaH = double.NaN, diaL = double.NaN;

        // --- filtro de volatilidade (v1.4)
        private readonly Queue<double> ampRelRecentes = new Queue<double>();
        private double ampRel3Atual;
        private readonly int[]    volN    = new int[3];
        private readonly int[]    volAlvo = new int[3];
        private readonly double[] volMov  = new double[3];
        private string textoVol = "";
        private Brush  corVol = Brushes.Gainsboro;

        // --- leitura do candle (v1.6)
        private double zMedia, zDesvio;
        private readonly Queue<double[]> ultimos5 = new Queue<double[]>();   // {compra, venda} dos ultimos candles fechados
        private int      ultDir;
        private bool     ultTemNeg, ultValido;
        private double   ultZ, ultClvAl, ultCorpo, ultRatio, ultRvol, ultAmpRel, ultDelta;
        private DateTime ultHoraNy;
        private string   ultSinais = "";
        private class PendCont
        {
            public int    Idx, Dir, Fx, Fz;
            public double H, L, ClvAl;
        }
        private readonly List<PendCont> pendCont = new List<PendCont>();
        private readonly int[,]    contN   = new int[5, 3];
        private readonly int[,]    contK   = new int[5, 3];
        private readonly double[,] contEsp = new double[5, 3];
        private string textoLeitura = "";
        private string textoCompacto = "";
        private string ultimoSinalCurto = "";
        private Brush  corLeitura = Brushes.Gainsboro;
        private const int PESQ_HORIZONTE = 15;
        private readonly List<LinhaPesquisa> pesqPendentes = new List<LinhaPesquisa>();
        private readonly List<string> linhasPesquisa = new List<string>();
        private string arquivoPesquisa = "";
        private TimeSpan inicioSinais, fimSinais;

        private readonly List<string> linhasCsv = new List<string>();
        private string arquivoCsv = "";
        private bool   csvGravado;
        private int    diasComNegocios;

        // paineis desenhados no OnRender (arrastaveis)
        private SharpDX.RectangleF retResumo;
        private bool   mouseLigado, arrastando;
        private float  arrIniMouseX, arrIniMouseY;
        private int    arrIniX, arrIniY;
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
        private readonly Dictionary<int, Queue<double>> deltaPorMinuto = new Dictionary<int, Queue<double>>();
        private double zMinutoAtual = double.NaN;   // z do delta contra o mesmo minuto dos ultimos dias (NaN = sem base)
        private int    exPendIdx = -1, exPendDir;   // EX aguardando a confirmacao do candle seguinte
        private double exPendClose;
        private const int MIN_DIAS_Z_MINUTO = 10;

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
        [Display(Name = "Mostrar paineis (volatilidade e leitura do candle)", GroupName = "2. Exibicao", Order = 3)]
        public bool MostrarResumo { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Cor das barras", Description = "PelaAgressao: lado que dominou o delta. PeloCandle: direcao do preco no candle", GroupName = "2. Exibicao", Order = 4)]
        public SPForcaCorBarras CorBarras { get; set; }

        [Display(Name = "Painel compacto (clique no painel para alternar)", GroupName = "2. Exibicao", Order = 5)]
        public bool PainelCompacto { get; set; }

        [Range(8, 20)]
        [Display(Name = "Tamanho da fonte do painel", GroupName = "2. Exibicao", Order = 6)]
        public int TamanhoFonte { get; set; }

        [Range(0, 100)]
        [Display(Name = "Opacidade do fundo do painel (%)", Description = "0 = sem fundo, 100 = fundo preto solido", GroupName = "2. Exibicao", Order = 7)]
        public int OpacidadeFundo { get; set; }

        // posicao do resumo (arrastado com o mouse; salva no workspace/template)
        [Browsable(false)]
        public int ResumoX { get; set; }

        [Browsable(false)]
        public int ResumoY { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Mostrar sinais antigos C/A/D", Description = "Continuacao, absorcao e divergencia (v1.1-1.6). O estudo nao mostrou vantagem; desligado por padrao", GroupName = "3. Sinais", Order = 1)]
        public bool MostrarSinais { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Seta de agressao acima da media", GroupName = "3a. Setas e esgotamento", Order = 1)]
        public bool MostrarSetas { get; set; }

        [NinjaScriptProperty]
        [Range(0.5, 10.0)]
        [Display(Name = "Seta: z-score minimo do delta", Description = "Quantos desvios padrao o delta do candle precisa estar acima do normal do MESMO MINUTO nos ultimos dias. 2,0 = cerca de 1 candle em 12 na abertura", GroupName = "3a. Setas e esgotamento", Order = 2)]
        public double ZSetaMinimo { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Marcar esgotamento/absorcao (EX)", GroupName = "3a. Setas e esgotamento", Order = 3)]
        public bool MostrarExaustao { get; set; }

        [NinjaScriptProperty]
        [Range(2, 30)]
        [Display(Name = "EX: candles da tendencia anterior", GroupName = "3a. Setas e esgotamento", Order = 4)]
        public int BarrasTendencia { get; set; }

        [NinjaScriptProperty]
        [Range(1, 30)]
        [Display(Name = "EX: minimo de candles na direcao", Description = "Dos candles da tendencia, quantos precisam fechar na direcao (ex.: 3 de 5 vendedores)", GroupName = "3a. Setas e esgotamento", Order = 5)]
        public int MinBarrasTendencia { get; set; }

        [NinjaScriptProperty]
        [Range(3, 60)]
        [Display(Name = "EX: candles para a media de amplitude e volume", GroupName = "3a. Setas e esgotamento", Order = 6)]
        public int BarrasMediaExaustao { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 10.0)]
        [Display(Name = "EX: amplitude minima (x a media)", GroupName = "3a. Setas e esgotamento", Order = 7)]
        public double FatorAmplitudeExaustao { get; set; }

        [NinjaScriptProperty]
        [Range(1.0, 10.0)]
        [Display(Name = "EX: volume minimo (x a media)", GroupName = "3a. Setas e esgotamento", Order = 8)]
        public double FatorVolumeExaustao { get; set; }

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
        [Display(Name = "Sinais so no horario abaixo (desmarcado = qualquer horario)", GroupName = "3. Sinais", Order = 5)]
        public bool SinaisSoPregao { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Horario dos sinais: inicio (HH:mm, horario de NY)", Description = "09:30 NY = 10:30 Brasilia no horario de verao dos EUA", GroupName = "3. Sinais", Order = 8)]
        public string InicioSinaisNY { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Horario dos sinais: fim (HH:mm, horario de NY)", GroupName = "3. Sinais", Order = 9)]
        public string FimSinaisNY { get; set; }

        [NinjaScriptProperty]
        [Range(0.0, 20.0)]
        [Display(Name = "Divergencia: diferenca minima do delta acumulado (em desvios do delta)", Description = "0 = qualquer diferenca. 1,0 = pelo menos um desvio padrao do delta por candle", GroupName = "3. Sinais", Order = 10)]
        public double DivergenciaMinZ { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Modo pesquisa: gravar todos os candles do horario dos sinais", GroupName = "5. Pesquisa", Order = 1)]
        public bool ModoPesquisa { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Mostrar filtro de volatilidade", GroupName = "6. Volatilidade", Order = 1)]
        public bool MostrarVolatilidade { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Mostrar leitura do candle (agressao e continuacao)", GroupName = "7. Leitura do candle", Order = 1)]
        public bool MostrarLeitura { get; set; }

        [NinjaScriptProperty]
        [Range(1, 30)]
        [Display(Name = "Candles para medir a volatilidade", GroupName = "6. Volatilidade", Order = 2)]
        public int CandlesVolatilidade { get; set; }

        [NinjaScriptProperty]
        [Range(0.05, 10.0)]
        [Display(Name = "LENTA abaixo de (x a amplitude normal do horario)", GroupName = "6. Volatilidade", Order = 3)]
        public double VolLentaAbaixo { get; set; }

        [NinjaScriptProperty]
        [Range(0.05, 10.0)]
        [Display(Name = "RAPIDA acima de (x a amplitude normal do horario)", GroupName = "6. Volatilidade", Order = 4)]
        public double VolRapidaAcima { get; set; }

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
                DrawOnPricePanel         = true;    // setas e marcas no grafico de preco
                PaintPriceMarkers        = true;
                IsSuspendedWhileInactive = false;
                BarsRequiredToPlot       = 0;

                AberturaNY    = "09:30";
                JanelaMinutos = 60;
                DiasMedia     = 20;
                ModoGrafico   = SPForcaModoGrafico.DeltaColorido;
                ResumoX       = 10;
                ResumoY       = 10;
                LimiarForte   = 0.25;
                CorBarras     = SPForcaCorBarras.PelaAgressao;
                PainelCompacto = true;
                TamanhoFonte  = 11;
                OpacidadeFundo = 45;
                MostrarResumo = true;

                MostrarSinais      = false;
                MostrarSetas       = true;
                ZSetaMinimo        = 2.0;
                MostrarExaustao    = true;
                BarrasTendencia    = 5;
                MinBarrasTendencia = 3;
                BarrasMediaExaustao = 10;
                FatorAmplitudeExaustao = 1.8;
                FatorVolumeExaustao    = 1.8;
                ZScoreMinimo       = 2.0;
                RvolMinimo         = 1.2;
                CandlesDivergencia = 20;
                SinaisSoPregao     = true;
                InicioSinaisNY     = "09:30";
                FimSinaisNY        = "10:30";
                DivergenciaMinZ    = 1.0;
                ModoPesquisa       = true;
                MostrarVolatilidade = true;
                MostrarLeitura     = true;
                CandlesVolatilidade = 3;
                VolLentaAbaixo     = 0.65;
                VolRapidaAcima     = 1.28;
                PintarCandles      = true;
                AlertaSonoro       = false;
                AlvoPontos         = 40;
                StopPontos         = 40;
                CandlesAvaliacao   = 15;

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

                string pasta = Path.Combine(NinjaTrader.Core.Globals.UserDataDir, "SPForca");
                arquivoCsv = Path.Combine(pasta, "sinais_" + NomeArquivo(Instrument.FullName) + ".csv");
                arquivoPesquisa = Path.Combine(pasta, "pesquisa_" + NomeArquivo(Instrument.FullName) + ".csv");
                if (!LerHora(InicioSinaisNY, out inicioSinais)) inicioSinais = aberturaEt;
                if (!LerHora(FimSinaisNY, out fimSinais))       fimSinais = new TimeSpan(16, 0, 0);
            }
            else if (State == State.Historical)
            {
                if (ChartControl != null && !mouseLigado)
                {
                    mouseLigado = true;
                    ChartControl.Dispatcher.InvokeAsync(() =>
                    {
                        ChartControl.PreviewMouseLeftButtonDown += AoMouseDown;
                        ChartControl.PreviewMouseMove           += AoMouseMove;
                        ChartControl.PreviewMouseLeftButtonUp   += AoMouseUp;
                    });
                }
            }
            else if (State == State.Realtime)
            {
                GravarCsvCompleto();
            }
            else if (State == State.Terminated)
            {
                if (ChartControl != null && mouseLigado)
                {
                    mouseLigado = false;
                    ChartControl.Dispatcher.InvokeAsync(() =>
                    {
                        ChartControl.PreviewMouseLeftButtonDown -= AoMouseDown;
                        ChartControl.PreviewMouseMove           -= AoMouseMove;
                        ChartControl.PreviewMouseLeftButtonUp   -= AoMouseUp;
                    });
                }
            }
        }

        // ------------------------------------------------------------------
        //  Resumo: desenhado no OnRender, arrastavel com o mouse
        // ------------------------------------------------------------------
        protected override void OnRender(ChartControl chartControl, ChartScale chartScale)
        {
            base.OnRender(chartControl, chartScale);
            string tv = textoVol, tl = textoLeitura, tc = textoCompacto;
            if (!MostrarResumo || RenderTarget == null) return;
            if (PainelCompacto) { tv = tc; tl = ""; }
            if (string.IsNullOrEmpty(tv) && string.IsNullOrEmpty(tl)) return;

            using (SharpDX.DirectWrite.TextFormat formato = new SharpDX.DirectWrite.TextFormat(NinjaTrader.Core.Globals.DirectWriteFactory,
                       "Consolas", SharpDX.DirectWrite.FontWeight.Normal, SharpDX.DirectWrite.FontStyle.Normal, (float)TamanhoFonte))
            {
                int maxX = Math.Max(0, ChartPanel.W - 60);
                int maxY = Math.Max(0, ChartPanel.H - 20);
                float x = ChartPanel.X + Math.Max(0, Math.Min(ResumoX, maxX));
                float y = ChartPanel.Y + Math.Max(0, Math.Min(ResumoY, maxY));
                float largura = 0;
                float yFim = DesenharCaixa(tv, PainelCompacto ? corLeitura : corVol, formato, x, y, ref largura);
                yFim = DesenharCaixa(tl, corLeitura, formato, x, yFim, ref largura);
                retResumo = new SharpDX.RectangleF(x, y, largura, Math.Max(0, yFim - y - 4f));   // area para arrastar
            }
        }

        // Caixa de texto com borda colorida; retorna a posicao Y para a proxima caixa.
        private float DesenharCaixa(string texto, Brush cor, SharpDX.DirectWrite.TextFormat formato, float x, float y, ref float largura)
        {
            if (string.IsNullOrEmpty(texto)) return y;
            using (SharpDX.DirectWrite.TextLayout lv = new SharpDX.DirectWrite.TextLayout(NinjaTrader.Core.Globals.DirectWriteFactory,
                       texto, formato, 4000f, 4000f))
            {
                SharpDX.RectangleF rv = new SharpDX.RectangleF(x, y, lv.Metrics.Width + 10f, lv.Metrics.Height + 6f);
                largura = Math.Max(largura, rv.Width);
                if (OpacidadeFundo > 0)
                    using (SharpDX.Direct2D1.SolidColorBrush fundo = new SharpDX.Direct2D1.SolidColorBrush(RenderTarget, new SharpDX.Color4(0f, 0f, 0f, OpacidadeFundo / 100f)))
                        RenderTarget.FillRectangle(rv, fundo);
                SharpDX.Direct2D1.Brush pv = cor.ToDxBrush(RenderTarget);
                pv.Opacity = 0.9f;
                RenderTarget.DrawRectangle(rv, pv, 1f);
                RenderTarget.DrawTextLayout(new SharpDX.Vector2(rv.X + 5f, rv.Y + 3f), lv, pv);
                pv.Dispose();
                return rv.Y + rv.Height + 3f;
            }
        }

        private bool PosicaoMouse(System.Windows.Input.MouseEventArgs e, out float x, out float y)
        {
            x = 0;
            y = 0;
            if (ChartControl == null || ChartControl.PresentationSource == null) return false;
            System.Windows.Point p = e.GetPosition(ChartControl as System.Windows.IInputElement);
            x = (float)ChartingExtensions.ConvertToHorizontalPixels(p.X, ChartControl.PresentationSource);
            y = (float)ChartingExtensions.ConvertToVerticalPixels(p.Y, ChartControl.PresentationSource);
            return true;
        }

        private void AoMouseDown(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            float x, y;
            if (!MostrarResumo || retResumo.Width <= 0 || !PosicaoMouse(e, out x, out y)) return;
            if (!retResumo.Contains(x, y)) return;
            arrastando   = true;
            arrIniMouseX = x;
            arrIniMouseY = y;
            arrIniX      = ResumoX;
            arrIniY      = ResumoY;
            e.Handled    = true;   // nao arrasta o grafico
        }

        private void AoMouseMove(object sender, System.Windows.Input.MouseEventArgs e)
        {
            float x, y;
            if (!arrastando || !PosicaoMouse(e, out x, out y)) return;
            ResumoX = Math.Max(0, arrIniX + (int)(x - arrIniMouseX));
            ResumoY = Math.Max(0, arrIniY + (int)(y - arrIniMouseY));
            ChartControl.InvalidateVisual();
            e.Handled = true;
        }

        private void AoMouseUp(object sender, System.Windows.Input.MouseButtonEventArgs e)
        {
            if (!arrastando) return;
            arrastando = false;
            e.Handled  = true;
            float x, y;
            if (PosicaoMouse(e, out x, out y) && Math.Abs(x - arrIniMouseX) < 4 && Math.Abs(y - arrIniMouseY) < 4)
                PainelCompacto = !PainelCompacto;   // clique sem arrastar: alterna compacto / detalhado
            ChartControl.InvalidateVisual();
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
                // sempre para cima (o modo antigo DeltaPorCandle tambem): altura = tamanho do delta
                Value[0] = Math.Abs(delta);
                double vol = candleCompra + candleVenda;
                bool forte = vol > 0 && Math.Abs(delta) / vol >= LimiarForte;
                bool alta = CorBarras == SPForcaCorBarras.PeloCandle ? Close[0] >= Open[0] : delta >= 0;
                PlotBrushes[0][0] = alta
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
            {
                AtualizarTextoVolatilidade();
                AtualizarTextoLeitura();
                AtualizarTextoCompacto();
            }
        }

        private bool AlgumSinal { get { return MostrarSinais || MostrarSetas || MostrarExaustao; } }

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
            double ampMediaMinuto = Media(ampPorMinuto, minuto);
            double deltaIdx = serieCompra.GetValueAt(idx) + serieVenda.GetValueAt(idx) > 0 ? delta : double.NaN;
            zMinutoAtual = double.NaN;
            if (!double.IsNaN(deltaIdx))
            {
                double mD, dD;
                if (MediaDesvio(deltaPorMinuto, minuto, out mD, out dD) && dD > 0) zMinutoAtual = (delta - mD) / dD;
            }

            // volatilidade recente: amplitude / normal do horario, media dos ultimos N candles
            if (ampMediaMinuto > 0)
            {
                ampRelRecentes.Enqueue((Bars.GetHigh(idx) - Bars.GetLow(idx)) / ampMediaMinuto);
                while (ampRelRecentes.Count > CandlesVolatilidade) ampRelRecentes.Dequeue();
                double sAmp = 0;
                foreach (double v in ampRelRecentes) sAmp += v;
                ampRel3Atual = sAmp / ampRelRecentes.Count;
            }

            RolarSessaoRegioes(horaNy);
            if (AlgumSinal)    AvaliarPendentes(idx);
            if (ModoPesquisa)  AvaliarPesquisa(idx);
            ResolverContinuacao(idx);
            DetectarSinais(idx, horaNy, delta, volMediaMinuto, ampMediaMinuto);
            AtualizarRegioes(idx, horaNy);
            AdicionarMedia(ampPorMinuto, minuto, Bars.GetHigh(idx) - Bars.GetLow(idx));
            AdicionarMedia(volPorMinuto, minuto, Bars.GetVolume(idx));
            if (!double.IsNaN(deltaIdx)) AdicionarMedia(deltaPorMinuto, minuto, delta);
        }

        // Media e desvio padrao dos ultimos dias no mesmo minuto (exige MIN_DIAS_Z_MINUTO valores).
        private static bool MediaDesvio(Dictionary<int, Queue<double>> d, int minuto, out double media, out double desvio)
        {
            media = 0;
            desvio = 0;
            Queue<double> q;
            if (!d.TryGetValue(minuto, out q) || q.Count < MIN_DIAS_Z_MINUTO) return false;
            foreach (double v in q) media += v;
            media /= q.Count;
            foreach (double v in q) desvio += (v - media) * (v - media);
            desvio = Math.Sqrt(desvio / q.Count);
            return true;
        }

        // ------------------------------------------------------------------
        //  Sinais
        // ------------------------------------------------------------------
        private static bool LerHora(string s, out TimeSpan t)
        {
            return TimeSpan.TryParseExact((s ?? "").Trim(), new[] { @"hh\:mm", @"h\:mm" }, CultureInfo.InvariantCulture, out t);
        }

        // Horario do candle e o do FECHAMENTO: o candle 09:31 e o primeiro depois de 09:30.
        private bool NoPregao(DateTime horaNy)
        {
            if (!SinaisSoPregao) return true;
            TimeSpan t = horaNy.TimeOfDay;
            return janela.Ativo && horaNy.Date == janela.Dia && AposAbertura(horaNy)
                   && t > inicioSinais && t <= fimSinais;
        }

        private void DetectarSinais(int idx, DateTime horaNy, double delta, double volMediaMinuto, double ampMediaMinuto)
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
            bool temNegocios = vol > 0 && n >= 30 && desvio > 0;
            if (n >= 30 && desvio > 0) { zMedia = media; zDesvio = desvio; }

            double z     = temNegocios ? (delta - media) / desvio : 0;
            double ratio = vol > 0 ? delta / vol : 0;
            double o = Bars.GetOpen(idx), h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            double amp = h - l;
            double clv = amp > 0 ? (c - l) / amp : 0.5;
            double rvol = volMediaMinuto > 0 ? Bars.GetVolume(idx) / volMediaMinuto : 0;
            bool rvolOk = RvolMinimo <= 0 || volMediaMinuto <= 0 || rvol >= RvolMinimo;
            double ampRel = ampMediaMinuto > 0 ? amp / ampMediaMinuto : 0;

            // z do horario (mesmo minuto dos ultimos dias); sem base suficiente, usa o dos ultimos 200 candles
            double zH = temNegocios && !double.IsNaN(zMinutoAtual) ? zMinutoAtual : z;
            RegistrarLeitura(idx, horaNy, compra, venda, delta, zH, ratio, clv, rvol, ampRel, temNegocios);
            if (!NoPregao(horaNy)) { exPendIdx = -1; return; }
            if (ModoPesquisa)
            {
                RegistrarPesquisa(idx, horaNy, compra, venda, delta, z, ratio, clv, rvol, ampRel, temNegocios);
            }
            CultureInfo br = new CultureInfo("pt-BR");

            // seta: agressao acima da media, na direcao da agressao
            if (MostrarSetas && temNegocios && Math.Abs(zH) >= ZSetaMinimo)
            {
                int dirF = zH > 0 ? 1 : -1;
                RegistrarSinal(zH > 0 ? TIPO_SETA : TIPO_SETA + 1, idx, horaNy, string.Format(br,
                    "delta {0:+#,##0;-#,##0} (z {1:+0.0;-0.0}: {2}), {3:0}% do volume, candle {4}, fechou a {5:0}% do extremo da agressao{6}",
                    delta, zH, NivelZ(zH), 100 * Math.Abs(ratio), c > o ? "de alta" : (c < o ? "de baixa" : "doji"),
                    100 * (dirF > 0 ? clv : 1 - clv),
                    volMediaMinuto > 0 ? string.Format(br, ", RVOL {0:0.0}x", rvol) : ""),
                    CamposCsv(delta, zH, ratio, clv, rvol));
            }

            if (MostrarExaustao)
            {
                // confirmacao: o candle seguinte ao EX fecha na direcao da reversao e alem do fechamento do EX
                if (exPendIdx == idx - 1 && exPendDir * (c - exPendClose) > 0 && exPendDir * (c - o) > 0)
                    RegistrarSinal(exPendDir > 0 ? TIPO_EXC : TIPO_EXC + 1, idx, horaNy, string.Format(br,
                        "candle seguinte ao EX fechou {0:0.00} pts a favor da reversao", exPendDir * (c - exPendClose)),
                        CamposCsv(delta, zH, ratio, clv, rvol));
                exPendIdx = -1;
                DetectarExaustao(idx, horaNy, delta, zH, ratio, clv, rvol, temNegocios);
            }

            if (!MostrarSinais || !temNegocios) return;

            int tipo = -1;
            if (z >= ZScoreMinimo && ratio >= LimiarForte && clv >= 0.7 && c > o && rvolOk)       tipo = 0;
            else if (z <= -ZScoreMinimo && ratio <= -LimiarForte && clv <= 0.3 && c < o && rvolOk) tipo = 1;
            else if (z <= -ZScoreMinimo && c >= o && clv >= 0.5)                                   tipo = 2;
            else if (z >= ZScoreMinimo && c <= o && clv <= 0.5)                                    tipo = 3;

            if (tipo >= 0)
                RegistrarSinal(tipo, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "delta {0:+#,##0;-#,##0} (z {1:+0.0;-0.0}), {2:0}% do volume, fechou a {3:0}% do candle{4}",
                    delta, z, 100 * Math.Abs(ratio), 100 * clv,
                    volMediaMinuto > 0 ? string.Format(new CultureInfo("pt-BR"), ", RVOL {0:0.0}x", rvol) : ""),
                    CamposCsv(delta, z, ratio, clv, rvol));

            // divergencia: nova maxima/minima de N candles sem o delta acumulado confirmar
            int ini = idx - CandlesDivergencia;
            if (ini < 0) return;
            DateTime horaIni = TimeZoneInfo.ConvertTime(Bars.GetTime(ini), tzGrafico, tzNy);
            if (!AposAbertura(horaIni) || horaIni.Date != horaNy.Date) return;   // so dentro do mesmo pregao

            int jMax = ini, jMin = ini;
            for (int j = ini; j < idx; j++)
            {
                if (Bars.GetHigh(j) > Bars.GetHigh(jMax)) jMax = j;
                if (Bars.GetLow(j)  < Bars.GetLow(jMin))  jMin = j;
            }
            double cvd = serieAcum.GetValueAt(idx);
            double difMin = DivergenciaMinZ * desvio;
            if (h > Bars.GetHigh(jMax) && cvd < serieAcum.GetValueAt(jMax) - difMin)
                RegistrarSinal(5, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "nova maxima de {0} candles com delta acumulado {1:+#,##0;-#,##0} abaixo do topo anterior ({2:+#,##0;-#,##0})",
                    CandlesDivergencia, cvd, serieAcum.GetValueAt(jMax)),
                    CamposCsv(delta, z, ratio, clv, rvol));
            else if (l < Bars.GetLow(jMin) && cvd > serieAcum.GetValueAt(jMin) + difMin)
                RegistrarSinal(4, idx, horaNy, string.Format(new CultureInfo("pt-BR"),
                    "nova minima de {0} candles com delta acumulado {1:+#,##0;-#,##0} acima do fundo anterior ({2:+#,##0;-#,##0})",
                    CandlesDivergencia, cvd, serieAcum.GetValueAt(jMin)),
                    CamposCsv(delta, z, ratio, clv, rvol));
        }

        // Esgotamento/absorcao: varios candles numa direcao e, de repente, um candle muito maior,
        // com volume bem acima dos anteriores, que faz novo extremo. O lado que empurrava pode
        // ter gasto a forca; o sinal aponta para o lado oposto. Usa so preco e volume (funciona
        // sem Tick Replay); com dados de negocio, o delta ajuda a separar absorcao de climax.
        private void DetectarExaustao(int idx, DateTime horaNy, double delta, double z, double ratio, double clv, double rvol, bool temNegocios)
        {
            int nT = BarrasTendencia, nM = BarrasMediaExaustao;
            int ini = idx - Math.Max(nT, nM);
            if (ini < 0) return;
            DateTime horaIni = TimeZoneInfo.ConvertTime(Bars.GetTime(ini), tzGrafico, tzNy);
            if (horaIni.Date != horaNy.Date) return;

            double sAmp = 0, sVol = 0;
            for (int j = idx - nM; j < idx; j++)
            {
                sAmp += Bars.GetHigh(j) - Bars.GetLow(j);
                sVol += Bars.GetVolume(j);
            }
            double ampMed = sAmp / nM, volMed = sVol / nM;
            double o = Bars.GetOpen(idx), h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            double amp = h - l, vol = Bars.GetVolume(idx);
            if (ampMed <= 0 || volMed <= 0 || amp < FatorAmplitudeExaustao * ampMed || vol < FatorVolumeExaustao * volMed) return;

            int altas = 0, baixas = 0;
            double maxH = double.MinValue, minL = double.MaxValue;
            for (int j = idx - nT; j < idx; j++)
            {
                double oj = Bars.GetOpen(j), cj = Bars.GetClose(j);
                if (cj > oj) altas++;
                else if (cj < oj) baixas++;
                maxH = Math.Max(maxH, Bars.GetHigh(j));
                minL = Math.Min(minL, Bars.GetLow(j));
            }
            double mov = Bars.GetClose(idx - 1) - Bars.GetOpen(idx - nT);

            int tipo;
            if (baixas >= MinBarrasTendencia && mov < 0 && l < minL)      tipo = TIPO_EXAUSTAO;       // vendedores esgotando
            else if (altas >= MinBarrasTendencia && mov > 0 && h > maxH)  tipo = TIPO_EXAUSTAO + 1;   // compradores esgotando
            else return;

            int dirTend   = tipo == TIPO_EXAUSTAO ? -1 : 1;              // direcao de quem esgotou
            double volta  = dirTend < 0 ? clv : 1 - clv;                  // quanto o candle voltou do extremo (0 = fechou no extremo)
            string quem   = dirTend < 0 ? "vendedores" : "compradores";
            string natureza;
            if (temNegocios && z * dirTend >= 1.5 && volta >= 0.4)
                natureza = "ABSORCAO: " + quem + " agrediram forte e o preco nao acompanhou";
            else if (volta >= 0.5)
                natureza = "REJEICAO: o candle voltou do extremo";
            else if (volta < 0.25)
                natureza = "CLIMAX: fechou no extremo (pode haver mais um empurrao antes de virar)";
            else
                natureza = "ESGOTAMENTO";

            exPendIdx   = idx;
            exPendDir   = -dirTend;
            exPendClose = c;
            CultureInfo br = new CultureInfo("pt-BR");
            RegistrarSinal(tipo, idx, horaNy, string.Format(br,
                "{0} | depois de {1} de {2} candles {3}, amplitude {4:0.0}x e volume {5:0.0}x a media dos {6} anteriores, fechou a {7:0}% do extremo{8}",
                natureza, dirTend < 0 ? baixas : altas, nT, dirTend < 0 ? "de baixa" : "de alta",
                amp / ampMed, vol / volMed, nM, 100 * volta,
                temNegocios ? string.Format(br, ", delta {0:+#,##0;-#,##0} (z {1:+0.0;-0.0})", delta, z) : ""),
                CamposCsv(delta, z, ratio, clv, rvol));
        }

        private Brush CorSinal(int tipo)
        {
            switch (tipo)
            {
                case 0: return Brushes.LimeGreen;
                case 1: return Brushes.Red;
                case 2: return Brushes.DeepSkyBlue;
                case 3: return Brushes.Orange;
                case 6: return Brushes.Lime;
                case 7: return Brushes.OrangeRed;
                case 8:
                case 10: return Brushes.Gold;
                case 9:
                case 11: return Brushes.Magenta;
                default: return Brushes.Violet;
            }
        }

        private static string SemSeta(int tipo)
        {
            return NomeSinal[tipo].Replace("\u25B2", " compra").Replace("\u25BC", " venda");
        }

        private static string CamposCsv(double delta, double z, double ratio, double clv, double rvol)
        {
            CultureInfo br = new CultureInfo("pt-BR");
            return string.Format(br, "{0:0};{1:0.00};{2:0};{3:0};{4:0.00}", delta, z, 100 * Math.Abs(ratio), 100 * clv, rvol);
        }

        private void RegistrarSinal(int tipo, int idx, DateTime horaNy, string detalhe, string campos)
        {
            int dir = (tipo % 2 == 0) ? 1 : -1;
            int barsAgo = CurrentBar - idx;
            Brush cor = CorSinal(tipo);
            // no grafico de preco: sinais de compra abaixo da minima, de venda acima da maxima,
            // empilhados quando ha mais de um no mesmo candle
            double y = dir > 0 ? Bars.GetLow(idx) : Bars.GetHigh(idx);
            int chave = idx * 2 + (dir > 0 ? 1 : 0), nivel;
            rotulosPorLado.TryGetValue(chave, out nivel);
            rotulosPorLado[chave] = nivel + 1;
            int offset = dir * -(18 + 20 * nivel);
            string tag = "SPF_S" + idx + "_" + tipo;
            bool seta = tipo == TIPO_SETA || tipo == TIPO_SETA + 1;

            string ja;
            sinaisPorCandle[idx] = sinaisPorCandle.TryGetValue(idx, out ja) ? ja + " " + SemSeta(tipo) : SemSeta(tipo);

            pendentes.Add(new SinalPendente
            {
                Tipo = tipo, Dir = dir, Entrada = Bars.GetClose(idx), BarIdx = idx, HoraNy = horaNy,
                Tag = tag, Y = y, Offset = offset, Campos = campos
            });

            if (seta)
                Draw.Text(this, tag, false, dir > 0 ? "\u2191" : "\u2193", barsAgo, y, offset,
                    cor, new SimpleFont("Arial", 18) { Bold = true }, TextAlignment.Center, Brushes.Transparent, Brushes.Transparent, 0);
            else
                Draw.Text(this, tag, false, NomeSinal[tipo], barsAgo, y, offset,
                    cor, new SimpleFont("Arial", 11) { Bold = true }, TextAlignment.Center, Brushes.Transparent, Brushes.Transparent, 0);
            if (PintarCandles && !seta && barsAgo >= 0)
                BarBrushes[barsAgo] = cor;

            ultimoSinalTexto = string.Format("Ultimo sinal: {0} {1:HH:mm} ET - {2}: {3}", NomeSinal[tipo], horaNy, DescSinal[tipo], detalhe);
            ultimoSinalCurto = string.Format("{0} {1:HH:mm}", NomeSinal[tipo], horaNy);
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
                p.MaxFavor  = Math.Max(p.MaxFavor,  p.Dir > 0 ? h - p.Entrada : p.Entrada - l);
                p.MaxContra = Math.Max(p.MaxContra, p.Dir > 0 ? p.Entrada - l : h - p.Entrada);
                string resultado;
                if (bateuStop)        { erros[p.Tipo]++;   resultado = "erro"; }     // alvo e stop no mesmo candle conta como erro
                else if (bateuAlvo)   { acertos[p.Tipo]++; resultado = "acerto"; }
                else if (idx - p.BarIdx >= CandlesAvaliacao) { neutros[p.Tipo]++; resultado = "neutro"; }
                else continue;
                pendentes.RemoveAt(k);
                somaFavor[p.Tipo]  += p.MaxFavor;
                somaContra[p.Tipo] += p.MaxContra;
                MarcarResultado(p, resultado, idx);
            }
        }

        // Acrescenta o resultado ao rotulo do sinal (v / x / o) e registra no CSV.
        private void MarcarResultado(SinalPendente p, string resultado, int idx)
        {
            string marca = resultado == "acerto" ? " \u2713" : (resultado == "erro" ? " \u2717" : " \u2022");
            if (p.Tipo != TIPO_SETA && p.Tipo != TIPO_SETA + 1)   // a seta fica limpa; o resultado vai para o painel e o CSV
                Draw.Text(this, p.Tag, false, NomeSinal[p.Tipo] + marca, CurrentBar - p.BarIdx, p.Y, p.Offset,
                    CorSinal(p.Tipo), new SimpleFont("Arial", 11) { Bold = true }, TextAlignment.Center, Brushes.Transparent, Brushes.Transparent, 0);

            CultureInfo br = new CultureInfo("pt-BR");
            DateTime horaRes = TimeZoneInfo.ConvertTime(Bars.GetTime(idx), tzGrafico, tzNy);
            string linha = string.Format(br, "{0:dd/MM/yyyy};{0:HH:mm};{1};{2};{3};{4};{5};{6:HH:mm};{7};{8:0.##};{9:0.##}",
                p.HoraNy, NomeSinal[p.Tipo].Replace("\u25B2", " compra").Replace("\u25BC", " venda"), DescSinal[p.Tipo],
                p.Entrada.ToString("0.00", br), p.Campos, resultado, horaRes, idx - p.BarIdx, p.MaxFavor, p.MaxContra);
            linhasCsv.Add(linha);
            if (csvGravado)
                AnexarCsv(linha);
        }

        // ------------------------------------------------------------------
        //  Modo pesquisa: um registro por candle do horario dos sinais
        // ------------------------------------------------------------------
        private const string PESQ_CABECALHO =
            "data;hora_ET;min_desde_abertura;abertura;maxima;minima;fechamento;volume;compra;venda;delta;zscore;pct_volume;" +
            "fechamento_no_candle_pct;rvol;amplitude;amplitude_rel;delta_acum;delta_acum_5min;pos_na_faixa_pct;sinal;" +
            "fwd5_pts;fwd10_pts;fwd15_pts;max_alta15_pts;max_baixa15_pts;compra_alvo_antes_stop;compra_candles;venda_alvo_antes_stop;venda_candles";

        private void RegistrarPesquisa(int idx, DateTime horaNy, double compra, double venda, double delta, double z,
                                       double ratio, double clv, double rvol, double ampRel, bool temNegocios)
        {
            if (!NoPregao(horaNy)) return;
            CultureInfo br = new CultureInfo("pt-BR");
            double o = Bars.GetOpen(idx), h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            double cvd = serieAcum.GetValueAt(idx);
            string cvd5 = "";
            if (idx >= 5)
            {
                DateTime h5 = TimeZoneInfo.ConvertTime(Bars.GetTime(idx - 5), tzGrafico, tzNy);
                if (h5.Date == horaNy.Date && AposAbertura(h5))
                    cvd5 = (cvd - serieAcum.GetValueAt(idx - 5)).ToString("0", br);
            }
            string posFaixa = (janela.Ativo && janela.Maxima > janela.Minima)
                ? (100 * (c - janela.Minima) / (janela.Maxima - janela.Minima)).ToString("0", br) : "";
            int minAbertura = (int)(horaNy.TimeOfDay - aberturaEt).TotalMinutes;

            string b = string.Format(br, "{0:dd/MM/yyyy};{0:HH:mm};{1};{2:0.00};{3:0.00};{4:0.00};{5:0.00};{6:0};{7:0};{8:0};{9:0};{10:0.00};{11:0};{12:0};{13:0.00};{14:0.00};{15:0.00};{16:0};{17};{18}",
                horaNy, minAbertura, o, h, l, c, Bars.GetVolume(idx), compra, venda, delta, z, 100 * ratio, 100 * clv,
                rvol, h - l, ampRel, cvd, cvd5, posFaixa);
            pesqPendentes.Add(new LinhaPesquisa { BarIdx = idx, Base = b, Close = c, MaxH = c, MinL = c,
                                                  Extra = ColunasContexto(idx, c, temNegocios), AmpRel3 = ampRel3Atual });
        }

        // Distancia do fechamento a cada regiao (positivo = acima do nivel), movimento recente e volatilidade.
        private string ColunasContexto(int idx, double c, bool temNegocios)
        {
            CultureInfo br = new CultureInfo("pt-BR");
            double vwap = vwapV > 0 ? vwapPV / vwapV : double.NaN;
            return string.Join(";", new[]
            {
                Dist(c, pdh, br), Dist(c, pdl, br), Dist(c, pdc, br), Dist(c, onHHoje, br), Dist(c, onLHoje, br),
                Dist(c, vwap, br), Dist(c, or15H, br), Dist(c, or15L, br),
                idx >= 5  ? (c - Bars.GetClose(idx - 5)).ToString("0.00", br)  : "",
                idx >= 15 ? (c - Bars.GetClose(idx - 15)).ToString("0.00", br) : "",
                ampRel3Atual.ToString("0.00", br),
                temNegocios ? "1" : "0",
                Dist(c, diaH, br), Dist(c, diaL, br),
                double.IsNaN(zMinutoAtual) ? "" : zMinutoAtual.ToString("0.00", br)
            });
        }

        private static string Dist(double c, double nivel, CultureInfo br)
        {
            return double.IsNaN(nivel) ? "" : (c - nivel).ToString("0.00", br);
        }

        private const string PESQ_CABECALHO_EXTRA =
            ";dist_max_ontem;dist_min_ontem;dist_fech_ontem;dist_max_overnight;dist_min_overnight;dist_vwap;dist_max_faixa15;dist_min_faixa15;" +
            "ret5_pts;ret15_pts;volat_rel;tem_negocios;dist_max_dia;dist_min_dia;zscore_horario";

        // ------------------------------------------------------------------
        //  Regioes: dia anterior (pregao), overnight, faixa de abertura, VWAP
        // ------------------------------------------------------------------
        private bool NoRth(DateTime horaNy)
        {
            TimeSpan t = horaNy.TimeOfDay;
            return t > aberturaEt && t <= new TimeSpan(16, 0, 0);
        }

        // No primeiro candle do pregao: o pregao anterior vira "ontem" e o overnight e congelado.
        private void RolarSessaoRegioes(DateTime horaNy)
        {
            if (!NoRth(horaNy) || horaNy.Date == rthDia) return;
            if (rthDia != DateTime.MinValue && !double.IsNaN(rthH))
            {
                pdh = rthH;
                pdl = rthL;
                pdc = rthC;
            }
            onHHoje = onH;
            onLHoje = onL;
            rthDia = horaNy.Date;
            rthH = rthL = rthC = double.NaN;
            or5H = or5L = or15H = or15L = double.NaN;
            vwapPV = vwapV = 0;
            emOvernight = false;
        }

        // Dia de negociacao do CME: comeca as 18:00 NY do dia anterior.
        private static DateTime DiaGlobex(DateTime horaNy)
        {
            return horaNy.TimeOfDay > new TimeSpan(18, 0, 0) ? horaNy.Date.AddDays(1) : horaNy.Date;
        }

        private void AtualizarRegioes(int idx, DateTime horaNy)
        {
            double h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            DateTime dg = DiaGlobex(horaNy);
            if (dg != diaGlobex) { diaGlobex = dg; diaH = h; diaL = l; }
            else { diaH = Math.Max(diaH, h); diaL = Math.Min(diaL, l); }
            if (NoRth(horaNy) && horaNy.Date == rthDia)
            {
                rthH = double.IsNaN(rthH) ? h : Math.Max(rthH, h);
                rthL = double.IsNaN(rthL) ? l : Math.Min(rthL, l);
                rthC = c;
                double vol = Bars.GetVolume(idx);
                vwapPV += (h + l + c) / 3.0 * vol;
                vwapV  += vol;
                int min = (int)(horaNy.TimeOfDay - aberturaEt).TotalMinutes;
                if (min <= 5)
                {
                    or5H = double.IsNaN(or5H) ? h : Math.Max(or5H, h);
                    or5L = double.IsNaN(or5L) ? l : Math.Min(or5L, l);
                }
                if (min <= 15)
                {
                    or15H = double.IsNaN(or15H) ? h : Math.Max(or15H, h);
                    or15L = double.IsNaN(or15L) ? l : Math.Min(or15L, l);
                }
            }
            else if (!NoRth(horaNy))
            {
                if (!emOvernight) { onH = h; onL = l; emOvernight = true; }
                else { onH = Math.Max(onH, h); onL = Math.Min(onL, l); }
            }
        }

        // Acompanha os 15 candles seguintes de cada registro e grava quando completa.
        private void AvaliarPesquisa(int idx)
        {
            AvaliarLista(pesqPendentes, idx);
        }

        private int FaixaVol(double ampRel3)
        {
            if (ampRel3 < VolLentaAbaixo) return 0;
            return ampRel3 >= VolRapidaAcima ? 2 : 1;
        }

        private void AvaliarLista(List<LinhaPesquisa> lista, int idx)
        {
            double h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            for (int k = lista.Count - 1; k >= 0; k--)
            {
                LinhaPesquisa r = lista[k];
                int n = idx - r.BarIdx;
                if (n <= 0) continue;
                r.MaxH = Math.Max(r.MaxH, h);
                r.MinL = Math.Min(r.MinL, l);
                if (r.ResCompra == 0)
                {
                    if (l <= r.Close - StopPontos)       { r.ResCompra = -1; r.CandlesCompra = n; }
                    else if (h >= r.Close + AlvoPontos)  { r.ResCompra = 1;  r.CandlesCompra = n; }
                }
                if (r.ResVenda == 0)
                {
                    if (h >= r.Close + StopPontos)       { r.ResVenda = -1; r.CandlesVenda = n; }
                    else if (l <= r.Close - AlvoPontos)  { r.ResVenda = 1;  r.CandlesVenda = n; }
                }
                if (n == 5)  r.F5  = c - r.Close;
                if (n == 10) r.F10 = c - r.Close;
                if (n < PESQ_HORIZONTE) continue;
                r.F15 = c - r.Close;
                lista.RemoveAt(k);

                CultureInfo br = new CultureInfo("pt-BR");
                // estatistica do filtro de volatilidade: o alvo era alcancavel para algum lado em 15 candles?
                int fv = FaixaVol(r.AmpRel3);
                volN[fv]++;
                if (r.MaxH - r.Close >= AlvoPontos || r.Close - r.MinL >= AlvoPontos) volAlvo[fv]++;
                volMov[fv] += Math.Max(r.MaxH - r.Close, r.Close - r.MinL);

                string linha = r.Base + ";" + SinalDoCandle(r.BarIdx) + ";" + string.Format(br, "{0:0.00};{1:0.00};{2:0.00};{3:0.00};{4:0.00};{5};{6};{7};{8}",
                    r.F5, r.F10, r.F15, r.MaxH - r.Close, r.Close - r.MinL,
                    TextoRes(r.ResCompra), r.ResCompra != 0 ? r.CandlesCompra.ToString() : "",
                    TextoRes(r.ResVenda),  r.ResVenda  != 0 ? r.CandlesVenda.ToString()  : "")
                    + ";" + r.Extra;
                linhasPesquisa.Add(linha);
                if (csvGravado)
                    AnexarArquivo(arquivoPesquisa, linha);
            }
        }

        private static string TextoRes(int r) { return r > 0 ? "alvo" : (r < 0 ? "stop" : "nenhum"); }

        private readonly Dictionary<int, string> sinaisPorCandle = new Dictionary<int, string>();

        private string SinalDoCandle(int idx)
        {
            string s;
            return sinaisPorCandle.TryGetValue(idx, out s) ? s : "";
        }

        private const string CSV_CABECALHO = "data;hora_ET;sinal;descricao;entrada;delta;zscore;pct_volume;fechamento_no_candle_pct;rvol;resultado;hora_resultado_ET;candles;max_a_favor_pts;max_contra_pts";

        // Ao entrar em tempo real: grava todos os sinais do historico (arquivo refeito a cada carga).
        private void GravarCsvCompleto()
        {
            try
            {
                Directory.CreateDirectory(Path.GetDirectoryName(arquivoCsv));
                StringBuilder sb = new StringBuilder();
                sb.AppendLine(string.Format(CultureInfo.InvariantCulture, "# SPForcaMercado | {0} | alvo {1} / stop {2} pts em {3} candles | z {4} | gerado {5:dd/MM/yyyy HH:mm}",
                    Instrument.FullName, AlvoPontos, StopPontos, CandlesAvaliacao, ZScoreMinimo, DateTime.Now));
                sb.AppendLine(CSV_CABECALHO);
                foreach (string l in linhasCsv) sb.AppendLine(l);
                File.WriteAllText(arquivoCsv, sb.ToString(), Encoding.UTF8);

                if (ModoPesquisa)
                {
                    StringBuilder sp = new StringBuilder();
                    sp.AppendLine(string.Format(CultureInfo.InvariantCulture,
                        "# SPForcaMercado pesquisa | {0} | candles de {1:hh\\:mm} a {2:hh\\:mm} NY | alvo {3} / stop {4} pts | horizonte {5} candles | gerado {6:dd/MM/yyyy HH:mm}",
                        Instrument.FullName, inicioSinais, fimSinais, AlvoPontos, StopPontos, PESQ_HORIZONTE, DateTime.Now));
                    sp.AppendLine(PESQ_CABECALHO + PESQ_CABECALHO_EXTRA);
                    foreach (string l in linhasPesquisa) sp.AppendLine(l);
                    File.WriteAllText(arquivoPesquisa, sp.ToString(), Encoding.UTF8);

                }
                csvGravado = true;
            }
            catch (Exception ex) { Print("SPForcaMercado: falha ao gravar os arquivos CSV: " + ex.Message); }
        }

        // ------------------------------------------------------------------
        //  Leitura do candle
        // ------------------------------------------------------------------
        private static int FaixaClv(double clvAl)   // posicao do fechamento a favor do candle (0..1)
        {
            if (clvAl < 0.3) return 0;
            if (clvAl < 0.5) return 1;
            if (clvAl < 0.7) return 2;
            return clvAl < 0.9 ? 3 : 4;
        }

        private static int FaixaZ(double zAl)       // agressao a favor do candle
        {
            if (zAl < 1.0) return 0;
            return zAl < 2.5 ? 1 : 2;
        }

        private static string NivelZ(double z)
        {
            double a = Math.Abs(z);
            if (a < 1) return "fraca";
            if (a < 2) return "moderada";
            return a < 3 ? "FORTE" : "EXTREMA";
        }

        private void RegistrarLeitura(int idx, DateTime horaNy, double compra, double venda, double delta, double z,
                                      double ratio, double clv, double rvol, double ampRel, bool temNegocios)
        {
            ultimos5.Enqueue(new[] { compra, venda });
            while (ultimos5.Count > 5) ultimos5.Dequeue();

            double o = Bars.GetOpen(idx), h = Bars.GetHigh(idx), l = Bars.GetLow(idx), c = Bars.GetClose(idx);
            int dir = c > o ? 1 : (c < o ? -1 : 0);
            double amp = h - l;
            ultValido = true;
            ultDir    = dir;
            ultHoraNy = horaNy;
            ultTemNeg = temNegocios;
            ultZ      = z;
            ultDelta  = delta;
            ultRatio  = ratio;
            ultRvol   = rvol;
            ultAmpRel = ampRel;
            ultClvAl  = dir >= 0 ? clv : 1 - clv;
            ultCorpo  = amp > 0 ? Math.Abs(c - o) / amp : 0;

            // sinais descritivos do candle (o que aconteceu, nao previsao)
            List<string> sinais = new List<string>();
            double zAl = z * dir;
            string lado = dir > 0 ? "compradores" : "vendedores";
            if (dir != 0 && temNegocios)
            {
                if (zAl >= 2 && ultClvAl >= 0.7)      sinais.Add("agressao forte a favor e fechou no extremo");
                if (zAl >= 2 && ultClvAl < 0.5)       sinais.Add(lado + " agrediram forte mas o candle fechou longe do extremo (absorcao/esgotamento)");
                if (zAl <= -1.5)                      sinais.Add("agressao contraria ao candle (o lado oposto foi absorvido)");
            }
            if (dir != 0 && ultClvAl < 0.35)          sinais.Add("pavio de rejeicao: fechou longe do extremo");
            if (ampRel >= 2 && rvol >= 2)             sinais.Add("candle climatico: amplitude e volume acima de 2x o normal");
            ultSinais = sinais.Count > 0 ? string.Join(" | ", sinais) : "nenhum";

            // estatistica de continuacao (so na janela do estudo e com dados de negocio)
            if (dir != 0 && temNegocios && NoPregao(horaNy))
                pendCont.Add(new PendCont { Idx = idx, Dir = dir, H = h, L = l, ClvAl = ultClvAl,
                                            Fx = FaixaClv(ultClvAl), Fz = FaixaZ(zAl) });
        }

        // O candle continuou (rompeu a propria maxima, no candle de compra) antes de reverter
        // (romper a propria minima) nos 5 candles seguintes?
        private void ResolverContinuacao(int idx)
        {
            double h = Bars.GetHigh(idx), l = Bars.GetLow(idx), tick = TickSize;
            for (int k = pendCont.Count - 1; k >= 0; k--)
            {
                PendCont p = pendCont[k];
                if (idx <= p.Idx) continue;
                bool sobe = h >= p.H + tick, desce = l <= p.L - tick;
                if (sobe && desce) { pendCont.RemoveAt(k); continue; }     // os dois no mesmo candle: ignora
                if (sobe || desce)
                {
                    contN[p.Fx, p.Fz]++;
                    if ((sobe && p.Dir > 0) || (desce && p.Dir < 0)) contK[p.Fx, p.Fz]++;
                    contEsp[p.Fx, p.Fz] += p.ClvAl;
                    pendCont.RemoveAt(k);
                }
                else if (idx - p.Idx >= 5)
                    pendCont.RemoveAt(k);
            }
        }

        private void AtualizarTextoLeitura()
        {
            if (!MostrarLeitura || !ultValido) { textoLeitura = ""; return; }
            CultureInfo br = new CultureInfo("pt-BR");
            StringBuilder sb = new StringBuilder();

            double c5 = candleCompra, v5 = candleVenda;
            foreach (double[] cv in ultimos5) { c5 += cv[0]; v5 += cv[1]; }
            double t5 = c5 + v5;
            sb.Append("LEITURA DO CANDLE\n");
            if (t5 > 0)
                sb.AppendFormat(br, "Agressao ultimos 5 min: COMPRADORES {0:0}% x {1:0}% VENDEDORES (delta {2:+#,##0;-#,##0;0})\n",
                    100 * c5 / t5, 100 * v5 / t5, c5 - v5);
            else
                sb.Append(recebeuTicks ? "Agressao ultimos 5 min: sem negocios\n"
                                       : "Agressao ultimos 5 min: sem dados de negocio (ligue o Tick Replay)\n");

            double vAt = candleCompra + candleVenda;
            if (vAt > 0)
            {
                double dAt = candleCompra - candleVenda;
                // z ao vivo contra o mesmo minuto dos ultimos dias (o candle ainda nao fechou: tende a subir ate o fim)
                double mD, dD;
                int minAt = (int)TimeZoneInfo.ConvertTime(Time[0], tzGrafico, tzNy).TimeOfDay.TotalMinutes;
                bool temBase = MediaDesvio(deltaPorMinuto, minAt, out mD, out dD) && dD > 0;
                if (!temBase) { mD = zMedia; dD = zDesvio; }
                string zTxt = dD > 0 ? string.Format(br, " (z {0:+0.0;-0.0}: {1})", (dAt - mD) / dD, NivelZ((dAt - mD) / dD)) : "";
                sb.AppendFormat(br, "Candle em formacao: compradores {0:0}% | delta {1:+#,##0;-#,##0;0}{2}\n", 100 * candleCompra / vAt, dAt, zTxt);
            }

            string tipo = ultDir > 0 ? "COMPRA" : (ultDir < 0 ? "VENDA" : "DOJI");
            sb.AppendFormat(br, "Ultimo candle {0:HH:mm}: {1} | fechou a {2:0}% do extremo | corpo {3:0}%", ultHoraNy, tipo, 100 * ultClvAl, 100 * ultCorpo);
            if (ultTemNeg)
                sb.AppendFormat(br, " | delta {0:+#,##0;-#,##0;0} (z {1:+0.0;-0.0}: {2}, {3:0}% do volume)", ultDelta, ultZ, NivelZ(ultZ), 100 * Math.Abs(ultRatio));
            if (ultRvol > 0) sb.AppendFormat(br, " | RVOL {0:0.0}x", ultRvol);
            if (ultAmpRel > 0) sb.AppendFormat(br, " | amplitude {0:0.0}x", ultAmpRel);
            sb.Append("\n");

            if (ultDir != 0 && ultTemNeg)
            {
                int fx = FaixaClv(ultClvAl), fz = FaixaZ(ultZ * ultDir);
                int n = contN[fx, fz];
                string extremo = ultDir > 0 ? "maxima" : "minima", oposto = ultDir > 0 ? "minima" : "maxima";
                if (n >= 30)
                {
                    double real = 100.0 * contK[fx, fz] / n, acaso = 100.0 * contEsp[fx, fz] / n;
                    double dif = real - acaso;
                    string leitura = Math.Abs(dif) < 5
                        ? "a agressao NAO mudou a chance (dif. " + dif.ToString("+0;-0;0", br) + " p.p.)"
                        : (dif > 0 ? "a agressao AUMENTOU a chance em " : "a agressao REDUZIU a chance em ") + Math.Abs(dif).ToString("0", br) + " p.p.";
                    sb.AppendFormat(br, "Continua (rompe a {0} antes da {1} em ate 5 min): {2:0}% no seu historico (n={3}) | pela posicao do fechamento: {4:0}% -> {5}\n",
                        extremo, oposto, real, n, acaso, leitura);
                }
                else
                    sb.AppendFormat(br, "Continuacao: historico insuficiente para candles assim (n={0}; precisa de 30)\n", n);
            }
            sb.Append("Sinais: " + ultSinais);
            if (AlgumSinal)
            {
                sb.Append("\n" + TextoEstatistica());
                if (ultimoSinalTexto != "") sb.Append("\n" + ultimoSinalTexto);
            }

            textoLeitura = sb.ToString();
            corLeitura = t5 <= 0 ? Brushes.Gainsboro : (c5 >= v5 ? Brushes.LimeGreen : Brushes.Tomato);
        }

        // Painel compacto: o essencial em poucas linhas curtas (clique para ver o detalhado).
        private void AtualizarTextoCompacto()
        {
            CultureInfo br = new CultureInfo("pt-BR");
            List<string> l = new List<string>();
            if (MostrarVolatilidade && ampRelRecentes.Count > 0)
            {
                int fv = FaixaVol(ampRel3Atual);
                string est = volN[fv] >= 30 ? string.Format(br, " | alvo {0:0}: {1:0}%", AlvoPontos, 100.0 * volAlvo[fv] / volN[fv]) : "";
                l.Add(string.Format(br, "VOL {0} {1:0.00}x{2}", fv == 0 ? "LENTA" : (fv == 2 ? "RAPIDA" : "NORMAL"), ampRel3Atual, est));
            }
            if (MostrarLeitura && ultValido)
            {
                double c5 = candleCompra, v5 = candleVenda;
                foreach (double[] cv in ultimos5) { c5 += cv[0]; v5 += cv[1]; }
                double t5 = c5 + v5;
                if (t5 > 0)
                    l.Add(string.Format(br, "5min C {0:0}% x {1:0}% V  \u0394{2:+#,##0;-#,##0;0}", 100 * c5 / t5, 100 * v5 / t5, c5 - v5));
                double vAt = candleCompra + candleVenda;
                if (vAt > 0)
                {
                    double dAt = candleCompra - candleVenda, mD, dD;
                    int minAt = (int)TimeZoneInfo.ConvertTime(Time[0], tzGrafico, tzNy).TimeOfDay.TotalMinutes;
                    if (!(MediaDesvio(deltaPorMinuto, minAt, out mD, out dD) && dD > 0)) { mD = zMedia; dD = zDesvio; }
                    l.Add(string.Format(br, "Agora \u0394{0:+#,##0;-#,##0;0}{1}", dAt,
                        dD > 0 ? string.Format(br, " z{0:+0.0;-0.0} {1}", (dAt - mD) / dD, NivelZ((dAt - mD) / dD)) : ""));
                }
                string ult = string.Format(br, "{0:HH:mm} {1} fech {2:0}%", ultHoraNy, ultDir > 0 ? "ALTA" : (ultDir < 0 ? "BAIXA" : "DOJI"), 100 * ultClvAl);
                if (ultTemNeg) ult += string.Format(br, " z{0:+0.0;-0.0}", ultZ);
                if (ultRvol > 0) ult += string.Format(br, " RVOL {0:0.0}x", ultRvol);
                l.Add(ult);
            }
            if (AlgumSinal)
            {
                // acerto por familia (compra + venda somados)
                StringBuilder sf = new StringBuilder();
                for (int t = 0; t < NTIPOS; t += 2)
                {
                    bool ativo = t >= TIPO_EXAUSTAO ? MostrarExaustao : (t >= TIPO_SETA ? MostrarSetas : MostrarSinais);
                    int a = acertos[t] + acertos[t + 1], dec = a + erros[t] + erros[t + 1];
                    if (!ativo || dec == 0) continue;
                    if (sf.Length > 0) sf.Append(" | ");
                    sf.AppendFormat(br, "{0} {1:0}% n{2}", NomeSinal[t].Replace("\u25B2", ""), 100.0 * a / dec, dec);
                }
                if (sf.Length > 0) l.Add(sf.ToString());
                if (ultimoSinalCurto != "") l.Add("Ult: " + ultimoSinalCurto);
            }
            textoCompacto = string.Join("\n", l);
        }

        private void AtualizarTextoVolatilidade()
        {
            if (!MostrarVolatilidade || ampRelRecentes.Count == 0) { textoVol = ""; return; }
            CultureInfo br = new CultureInfo("pt-BR");
            int fv = FaixaVol(ampRel3Atual);
            string nome = fv == 0 ? "LENTA" : (fv == 2 ? "RAPIDA" : "NORMAL");
            corVol = fv == 0 ? Brushes.Orange : (fv == 2 ? Brushes.LimeGreen : Brushes.Gainsboro);
            string est = volN[fv] >= 30
                ? string.Format(br, "historico nessa faixa: alvo de {0:0} pts alcancavel em 15 min em {1:0}% (n={2}), maior movimento medio {3:0} pts",
                    AlvoPontos, 100.0 * volAlvo[fv] / volN[fv], volN[fv], volMov[fv] / volN[fv])
                : "historico insuficiente nessa faixa (ligue o modo pesquisa e carregue mais dias)";
            textoVol = string.Format(br, "VOLATILIDADE {0}: {1:0.00}x o normal do horario (ultimos {2} candles) | {3}",
                nome, ampRel3Atual, ampRelRecentes.Count, est);
        }

        private void AnexarCsv(string linha)
        {
            AnexarArquivo(arquivoCsv, linha);
        }

        private static void AnexarArquivo(string caminho, string linha)
        {
            try { File.AppendAllText(caminho, linha + Environment.NewLine, Encoding.UTF8); }
            catch (Exception) { }
        }

        private static string NomeArquivo(string s)
        {
            StringBuilder sb = new StringBuilder();
            foreach (char ch in (s ?? "")) sb.Append(char.IsLetterOrDigit(ch) || ch == '-' ? ch : '_');
            return sb.ToString();
        }

        private string TextoEstatistica()
        {
            CultureInfo br = new CultureInfo("pt-BR");
            StringBuilder sb = new StringBuilder();
            int dias = diasComNegocios + (janela.Ativo && janela.Compra + janela.Venda + candleCompra + candleVenda > 0 ? 1 : 0);
            sb.AppendFormat(br, "Sinais no seu historico ({0} pregao(oes) com negocios; alvo {1:0.##} antes de stop {2:0.##} pts em ate {3} candles):",
                dias, AlvoPontos, StopPontos, CandlesAvaliacao);
            for (int t = 0; t < NTIPOS; t++)
            {
                bool ativo = t >= TIPO_EXAUSTAO ? MostrarExaustao : (t >= TIPO_SETA ? MostrarSetas : MostrarSinais);
                if (!ativo) continue;
                int dec = acertos[t] + erros[t], tot = dec + neutros[t];
                sb.Append(t % 2 == 0 ? "\n  " : "   |   ");
                sb.AppendFormat(br, "{0} {1}", NomeSinal[t], dec > 0 ? string.Format(br, "{0:0}% ({1}/{2})", 100.0 * acertos[t] / dec, acertos[t], dec) : "sem casos");
                if (neutros[t] > 0) sb.AppendFormat(br, " +{0} neutros", neutros[t]);
                if (tot > 0) sb.AppendFormat(br, ", a favor {0:0} / contra {1:0} pts", somaFavor[t] / tot, somaContra[t] / tot);
            }
            return sb.ToString();
        }

        private void NovaSessaoSeAbertura(DateTime horaNy)
        {
            if (!AposAbertura(horaNy) || horaNy.Date == diaNyAtual) return;

            if (janela.Ativo && janela.Compra + janela.Venda > 0)
                diasComNegocios++;

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
