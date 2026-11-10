//+------------------------------------------------------------------+
//|  RM_NT8Espelho.mq5  v2.3  (versao leve)                           |
//|  Espelho do grafico NT8 no MT5: VWAP + bandas, bolhas de delta,   |
//|  PCR / 2x / X2 e absorcao, a partir de um horario do dia.         |
//|                                                                   |
//|  Feito para NAO disputar a fila do grafico com o Scalper Pro:     |
//|   - le os arquivos so na virada do minuto (varredura curta)       |
//|   - desenho INCREMENTAL: cria so o que e novo, nao apaga/recria   |
//|   - escala do grafico consultada no maximo a cada 2 s             |
//|   - reposiciona so os objetos VISIVEIS e so se a escala mudou     |
//|   - NENHUMA chamada que espera o grafico (ChartGet*, ObjectFind,  |
//|     ChartIndicator*): escala e area visivel vem do servico        |
//|     RM_NT8Escala via variaveis globais do terminal                |
//|  v2.1: botao ESPELHO do Scalper Pro (v6.04+) esconde/mostra      |
//|     VWAP, bandas, bolhas e absorcao na hora (evento do grafico); |
//|     os dados continuam sendo lidos, entao reaparecem atualizados |
//|  v2.2: confirma ao Scalper Pro (GV RMESP_ACK_<grafico>) que      |
//|     escondeu/mostrou, para o EA avisar se o indicador nao responde|
//|  v2.3: bolhas/textos/absorcao desenhados no fundo (nao cobrem o  |
//|     painel do Scalper Pro) e linha de status discreta            |
//+------------------------------------------------------------------+
#property copyright   "Rodrigo Mello"
#property version     "2.30"
#property description "Espelho leve NT8 -> MT5: VWAP, bolhas de delta e absorcao a partir de um horario."
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_label1  "VWAP NT8"
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrDodgerBlue
#property indicator_width1  2
#property indicator_label2  "Banda+ NT8"
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrMediumSeaGreen
#property indicator_width2  1
#property indicator_label3  "Banda- NT8"
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrMediumSeaGreen
#property indicator_width3  1

input string PrefixoAtivo     = "NQ";          // ativo no NT8 (acha sozinho o contrato: NQ_12-26, NQ_03-27...)
input int    HoraInicioBRT    = 1120;          // inicio (HHMM, Brasilia)
input int    HoraFimBRT       = 0;             // fim (HHMM, Brasilia; 0 = ate o fim do dia)
input bool   MostrarVWAP      = true;
input bool   MostrarBolhas    = true;
input bool   MostrarNumeros   = true;          // valor do delta ao lado da bolha
input bool   MostrarAbsorcao  = true;
input bool   MostrarPCR       = true;          // marcacoes PCR
input bool   MostrarDobro     = true;          // marcacoes 2x (verde-limao)
input bool   MostrarX2        = true;          // marcacoes X2 (virada do delta)
input int    DistBolhaPx      = 2;             // distancia bolha-candle em PIXELS (0 = colada na max/min)
input int    EspacoTextoPx    = 1;             // espaco entre bolha e numero, em pixels
input bool   OffsetAutomatico = true;          // calibra a diferenca de preco NQ (futuro) x simbolo do MT5
input double OffsetManual     = 0.0;           // usado se OffsetAutomatico = false (preco MT5 - preco NT8)
input int    InicioVarreduraSeg = 58;          // segundo do minuto em que comeca a varredura rapida
input int    FimVarreduraSeg  = 20;            // segundo do minuto seguinte em que desiste (se o NT8 nao gravar)
input int    IntervaloRapidoMs = 50;           // intervalo das conferencias durante a varredura (ms)
input int    IntervaloLentoSeg = 5;            // fora da varredura: confere VWAP/absorcao/status
input int    VerificarEscalaSeg = 1;           // de quanto em quanto tempo confere se a escala do grafico mudou
input int    AlturaEstimadaPx = 500;           // so sem o servico RM_NT8Escala: altura aproximada do grafico (px)
input int    BarrasEstimadas  = 100;           // so sem o servico: quantos candles cabem na tela
input int    MaxMinutosNaTela = 120;           // so desenha sinais dos ultimos N minutos (menos objetos = grafico mais leve; 0 = todos)
input color  CorCompra        = clrTurquoise;
input color  CorVenda         = clrMagenta;
input color  CorAbsorcao      = clrGold;
input color  CorDobro         = clrLime;
input color  CorNeutro        = clrGray;
input int    TamanhoAbsorcao  = 3;             // tamanho do ponto de absorcao (1 a 5)
input int    FonteAbsorcao    = 0;             // tamanho direto da fonte do ponto (0 = usa TamanhoAbsorcao)
input int    AjusteAbsorcaoPontos = 0;         // sobe (+) ou desce (-) o ponto amarelo, em pontos do MT5
input double OffsetAbsorcao   = 0.0;           // diferenca de preco so p/ absorcao (MT5 - NT8); 0 = usa a automatica
input bool   PrenderAbsorcaoNoCandle = true;   // mantem o ponto dentro do candle do MT5
input int    MargemAbsorcaoPx = 2;             // folga do ponto amarelo ate a max/min do candle, em pixels
input int    TamanhoFonte     = 8;
input bool   MostrarStatus    = true;
input bool   StatusDetalhado  = false;         // false = linha curta e discreta (detalhes ao passar o mouse)
input bool   DesenharNoFundo  = true;          // bolhas/textos/absorcao atras do grafico: nao cobrem o painel do Scalper Pro
input bool   Diagnostico      = true;          // registra no log (aba Experts) travamentos e execucoes lentas
input int    LimiteDiagMs     = 30;            // registra execucoes do indicador acima deste tempo (ms)
input int    LimiteTravaMs    = 400;           // registra quando o MT5 ficou parado mais que isto (ms)
input bool   MonitorarConexao = true;          // registra quedas/voltas da conexao com a corretora e ping alto
input int    LimitePingMs     = 400;           // registra quando o ping passar disto (ms)

double bVwap[], bUp[], bDn[];

const string PFX = "RMN8_";
string   inst        = "";
long     srvOff      = 0;        // horario do servidor - UTC (s)
double   offsetPreco = 0;
bool     offsetOk    = false;
long     ultHdrEpoch = 0;
datetime modVwap = 0, modBol = 0, modAbs = 0;
long     minutoLido = -1, minutoAlvoAtual = -1;
ulong    ultLento = 0, ultEscala = 0, ultEvento = 0, ultCopias = 0, repasseEm = 0;
string   ultLeitura = "-";
long     diaAtual = -1;
int      nBolhas = 0, nAbs = 0;
string   ultBolha = "-";
string   aviso = "", avisoCopias = "";
bool     statusCriado = false;
bool     escalaPendente = false;
string   gvBase = "";                     // prefixo das variaveis globais deste grafico
bool     servicoOk = false;
int      conexAnt = -1;                   // -1 = ainda nao conferido
ulong    quedaEm = 0, ultAvisoQueda = 0, ultPingChk = 0, ultPingLog = 0;
long     pingAtual = 0;
ulong    diagUltUs = 0, diagUltPrint = 0;
string   diagEtapa = "";
string   statusTexto = "";

// escala e area visivel do grafico (atualizadas no maximo a cada VerificarEscalaSeg)
double   pppAtual = 0;
datetime visIni = 0, visFim = 0;

// sinais lidos do arquivo de bolhas
struct Sinal
{
   string chave, fam, txt, corDot, corTxt;
   long   ep;
   bool   cima, temDot, temTxt;
};
Sinal    sinais[];
int      nsin = 0;
datetime usT[];
double   usCima[], usBaixo[];

// absorcoes lidas
datetime absT[];
double   absY[];
int      nAbsLidas = 0;

// objetos que ESTE indicador desenhou (o grafico nunca e consultado)
struct Obj
{
   string   nome, assin;
   int      tipo;              // 0 = bolinha, 1 = texto, 2 = absorcao
   datetime t;
   double   ext, hi, lo, bruto, px, y, pppUsado;
   bool     cima, vivo;
   int      fs;
};
Obj      objs[];
int      nObj = 0;

// botao ESPELHO do Scalper Pro: evento CHARTEVENT_CUSTOM+7101 (lparam 1 = esconder, 0 = mostrar)
// e estado persistente na global do terminal RMESP_OCULTO_<id do grafico>
const int ESPELHO_EVENTO = 7101;
bool     oculto = false;

//+------------------------------------------------------------------+
int OnInit()
{
   SetIndexBuffer(0, bVwap, INDICATOR_DATA);
   SetIndexBuffer(1, bUp,   INDICATOR_DATA);
   SetIndexBuffer(2, bDn,   INDICATOR_DATA);
   for(int i = 0; i < 3; i++) PlotIndexSetDouble(i, PLOT_EMPTY_VALUE, EMPTY_VALUE);
   ArraySetAsSeries(bVwap, true);
   ArraySetAsSeries(bUp,   true);
   ArraySetAsSeries(bDn,   true);
   IndicatorSetString(INDICATOR_SHORTNAME, "RM_NT8Espelho");

   srvOff = ServerOffset();
   // ao trocar parametros o MT5 reaproveita as globais: zera tudo para redesenhar com os valores novos
   modVwap = 0; modBol = 0; modAbs = 0;
   inst = ""; diaAtual = -1;
   nBolhas = 0; nAbs = 0; ultBolha = "-";
   nsin = 0; nAbsLidas = 0; nObj = 0; ArrayResize(objs, 0);
   statusCriado = false; statusTexto = ""; avisoCopias = "";
   minutoLido = -1; minutoAlvoAtual = -1;
   ultLento = 0; ultEscala = 0; ultEvento = 0; ultCopias = 0; repasseEm = 0;
   pppAtual = 0; diagUltUs = 0; diagUltPrint = 0; escalaPendente = false;
   conexAnt = -1; quedaEm = 0; ultAvisoQueda = 0; ultPingChk = 0; ultPingLog = 0; pingAtual = 0;
   ObjectsDeleteAll(0, PFX);
   gvBase = "RMN8_" + (string)ChartID() + "_";
   GlobalVariableTemp(gvBase + "ind");
   GlobalVariableSet(gvBase + "ind", 1);                           // avisa o servico: este grafico precisa de escala

   oculto = LerOcultoGV();
   AplicarVisibilidade(false);

   EventSetMillisecondTimer(MathMax(20, IntervaloRapidoMs));
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   ObjectsDeleteAll(0, PFX);
   if(gvBase != "") GlobalVariablesDeleteAll(gvBase);
   GlobalVariableDel("RMESP_ACK_" + (string)ChartID());
   nObj = 0; statusCriado = false;
   ChartRedraw();
}

int OnCalculate(const int rates_total, const int prev_calculated,
                const datetime &time[], const double &open[], const double &high[],
                const double &low[], const double &close[], const long &tick_volume[],
                const long &volume[], const int &spread[])
{
   if(prev_calculated == 0)
   {
      ArrayInitialize(bVwap, EMPTY_VALUE);
      ArrayInitialize(bUp,   EMPTY_VALUE);
      ArrayInitialize(bDn,   EMPTY_VALUE);
      modVwap = 0;                                    // forca reler a VWAP
   }
   else
   {
      int novas = rates_total - prev_calculated;      // barra nova: estende a ultima VWAP ate o arquivo atualizar
      for(int i = novas - 1; i >= 0; i--)
      {
         if(i + 1 >= rates_total) continue;
         bVwap[i] = bVwap[i + 1]; bUp[i] = bUp[i + 1]; bDn[i] = bDn[i + 1];
      }
   }
   return(rates_total);
}

//+------------------------------------------------------------------+
//  Timer: dorme o minuto inteiro; acorda no seg 58 e confere SO a data
//  do arquivo de bolhas a cada 50 ms ate o NT8 gravar.
//+------------------------------------------------------------------+
void OnTimer()
{
   // DIAGNOSTICO: o timer roda a cada 50 ms. Se passou muito mais que isso desde a ultima chamada,
   // o MT5 (ou a fila dos indicadores) ficou parado - por qualquer motivo, nao so por este indicador.
   ulong us0 = GetMicrosecondCount();
   if(Diagnostico && diagUltUs > 0)
   {
      ulong gap = (us0 - diagUltUs) / 1000;
      if(gap >= (ulong)LimiteTravaMs)
         DiagPrint(StringFormat("TRAVA: MT5 ficou %I64u ms sem rodar o timer (ate %s) | conexao %s",
                   gap, HoraMs(), TerminalInfoInteger(TERMINAL_CONNECTED) ? "ok" : "CAIDA") +
                   (gap >= 3000 ? " | parada longa: provavel pausa do Windows/Parallels ou tela travada" : ""));
   }
   diagUltUs = us0;
   diagEtapa = "";
   MonitorarRede();
   OnTimerTrabalho();
   if(Diagnostico)
   {
      ulong dur = (GetMicrosecondCount() - us0) / 1000;
      if(dur >= (ulong)LimiteDiagMs)
         DiagPrint(StringFormat("LENTO: indicador levou %I64u ms as %s [%s]", dur, HoraMs(), diagEtapa));
      diagUltUs = GetMicrosecondCount();                           // o proprio trabalho nao conta como trava
   }
}

// Conexao com a corretora: consulta ao terminal (nao espera a tela), barata.
//   QUEDA / VOLTOU (com duracao) / AINDA SEM CONEXAO (a cada 10 s) / PING ALTO (no maximo 1x a cada 30 s)
void MonitorarRede()
{
   if(!MonitorarConexao) return;
   ulong ms  = GetTickCount64();
   int   con = TerminalInfoInteger(TERMINAL_CONNECTED) ? 1 : 0;
   if(conexAnt == -1) { conexAnt = con; if(con == 0) quedaEm = ms; }
   else if(con != conexAnt)
   {
      if(con == 0)
      {
         quedaEm = ms; ultAvisoQueda = ms;
         Print("RMN8 rede | QUEDA: conexao com a corretora perdida as ", HoraMs());
      }
      else
      {
         ulong dur = quedaEm > 0 ? ms - quedaEm : 0;
         Print("RMN8 rede | VOLTOU apos ", dur, " ms as ", HoraMs(),
               " | ping ", (long)(TerminalInfoInteger(TERMINAL_PING_LAST) / 1000), " ms");
         quedaEm = 0;
      }
      conexAnt = con;
   }
   if(con == 0 && quedaEm > 0 && ms - ultAvisoQueda >= 10000)
   {
      ultAvisoQueda = ms;
      Print("RMN8 rede | AINDA SEM CONEXAO ha ", (ms - quedaEm) / 1000, " s (", HoraMs(), ")");
   }
   if(con == 1 && ms - ultPingChk >= 2000)
   {
      ultPingChk = ms;
      pingAtual  = (long)(TerminalInfoInteger(TERMINAL_PING_LAST) / 1000);
      if(pingAtual >= LimitePingMs && ms - ultPingLog >= 30000)
      {
         ultPingLog = ms;
         Print("RMN8 rede | PING ALTO: ", pingAtual, " ms as ", HoraMs());
      }
   }
}

string HoraMs()
{
   return TimeToString(TimeLocal(), TIME_SECONDS) + "." + StringFormat("%03d", (int)(GetTickCount64() % 1000));
}

void DiagPrint(string t)
{
   ulong ms = GetTickCount64();
   if(ms - diagUltPrint < 200) return;                             // nao inunda o log
   diagUltPrint = ms;
   Print("RMN8 diag | ", t);
}

// mede uma etapa e anota no resumo do diagnostico
void Etapa(string nome, ulong desdeUs)
{
   if(!Diagnostico) return;
   ulong d = (GetMicrosecondCount() - desdeUs) / 1000;
   if(d >= 5) diagEtapa += (diagEtapa == "" ? "" : ", ") + nome + " " + (string)d + " ms";
}

void OnTimerTrabalho()
{
   ulong ms   = GetTickCount64();
   long agora = (long)TimeGMT();
   int  seg   = (int)(agora % 60);
   long alvo  = (seg >= InicioVarreduraSeg) ? agora / 60 + 1 : agora / 60;
   bool varrendo = (alvo != minutoLido) && (seg >= InicioVarreduraSeg || seg <= FimVarreduraSeg);
   bool lento    = (ms - ultLento >= (ulong)MathMax(1, IntervaloLentoSeg) * 1000);
   bool repasse  = (repasseEm > 0 && ms >= repasseEm);

   bool porEvento = escalaPendente && ms - ultEvento >= 300;
   if(!oculto && nObj > 0 && (porEvento || ms - ultEscala >= (ulong)MathMax(1, VerificarEscalaSeg) * 1000))
   {
      ultEscala = ms;
      escalaPendente = false;
      ulong u = GetMicrosecondCount();
      AjustarEscala();
      Etapa("escala", u);
   }

   if(!varrendo && !lento && !repasse) return;
   if(alvo != minutoAlvoAtual) minutoAlvoAtual = alvo;

   bool mudou = false, mostrar = false;
   if(lento)
   {
      ultLento = ms;
      mostrar  = true;
      srvOff   = ServerOffset();
      aviso    = "";
      bool oc = LerOcultoGV();                                     // seguranca: se o evento se perdeu
      if(oc != oculto) { oculto = oc; AplicarVisibilidade(true); }
      if(ms - ultCopias >= 60000 || ultCopias == 0)               // copias repetidas (contadas pelo servico)
      {
         ulong uc = GetMicrosecondCount();
         ultCopias = ms;
         int copias = (int)GlobalVariableGet(gvBase + "copias");
         avisoCopias = copias > 1 ? "ATENCAO: " + (string)copias + " copias deste indicador no grafico - remova as extras (Ctrl+I)" : "";
         Etapa("copias", uc);
      }
      long hoje = DiaBRT();
      if(hoje != diaAtual)
      {
         if(diaAtual != -1)
         {
            ObjectsDeleteAll(0, PFX); nObj = 0; ArrayResize(objs, 0); statusCriado = false;
            ArrayInitialize(bVwap, EMPTY_VALUE); ArrayInitialize(bUp, EMPTY_VALUE); ArrayInitialize(bDn, EMPTY_VALUE);
            modVwap = 0; modBol = 0; modAbs = 0; nBolhas = 0; nAbs = 0; ultBolha = "-"; nsin = 0; nAbsLidas = 0;
         }
         diaAtual = hoje;
      }
      if(inst == "" || !FileIsExist("mirror_" + inst + "_OrderFlowBolhas.txt", FILE_COMMON))
      {
         inst = DetectarInstrumento();
         if(inst == "") { aviso = "nao achei mirror_" + PrefixoAtivo + "*_OrderFlowBolhas.txt em Common\\Files (NT8 aberto?)"; Status(); return; }
      }
   }
   if(inst == "") return;

   datetime aB = modBol;
   ulong u1 = GetMicrosecondCount();
   if(MostrarBolhas) mudou |= ProcessarBolhas();
   Etapa("bolhas", u1);
   bool chegou = (modBol != aB);
   if(chegou || lento || repasse || !MostrarBolhas)
   {
      ulong u2 = GetMicrosecondCount();
      mudou |= ProcessarVWAP();
      Etapa("vwap", u2);
      ulong u3 = GetMicrosecondCount();
      if(MostrarAbsorcao) mudou |= ProcessarAbsorcao();
      Etapa("absorcao", u3);
   }
   if(repasse) repasseEm = 0;

   if(chegou)
   {
      repasseEm = ms + 500;                                        // VWAP/absorcao gravadas logo depois
      mostrar   = true;
      if(varrendo)
      {
         minutoLido = alvo;
         ultLeitura = TimeToString(TimeLocal(), TIME_SECONDS);
      }
   }
   else if(varrendo && !MostrarBolhas) minutoLido = alvo;

   if(mudou) { ChartRedraw(); mostrar = true; }
   ulong u4 = GetMicrosecondCount();
   if(mostrar) Status();
   Etapa("status", u4);
}

// zoom / rolagem / redimensionar: confere a escala (no maximo a cada 150 ms)
// zoom / rolagem / redimensionar: NAO consulta o grafico aqui (evita esperar a tela);
// so agenda o ajuste, que o timer faz uma vez, 300 ms depois do ultimo movimento
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CUSTOM + ESPELHO_EVENTO)                    // botao ESPELHO do Scalper Pro
   {
      bool oc = (lparam == 1);
      if(oc != oculto) { oculto = oc; AplicarVisibilidade(true); }
      return;
   }
   if(id != CHARTEVENT_CHART_CHANGE || nObj == 0 || oculto) return;
   escalaPendente = true;
   ultEvento = GetTickCount64();
}

bool LerOcultoGV()
{
   string g = "RMESP_OCULTO_" + (string)ChartID();
   return GlobalVariableCheck(g) && GlobalVariableGet(g) > 0.5;
}

// esconde/mostra tudo de uma vez: so propriedades (sem apagar/recriar e sem consultar o grafico)
void AplicarVisibilidade(bool redesenhar)
{
   for(int i = 0; i < 3; i++) PlotIndexSetInteger(i, PLOT_DRAW_TYPE, oculto ? DRAW_NONE : DRAW_LINE);
   long tf = oculto ? OBJ_NO_PERIODS : OBJ_ALL_PERIODS;
   for(int i = 0; i < nObj; i++) ObjectSetInteger(0, objs[i].nome, OBJPROP_TIMEFRAMES, tf);
   if(!oculto && nObj > 0) { escalaPendente = true; ultEvento = 0; }   // a escala pode ter mudado enquanto oculto
   if(statusCriado) { statusTexto = ""; Status(); }
   GlobalVariableSet("RMESP_ACK_" + (string)ChartID(), oculto ? 1.0 : 0.0);   // resposta ao Scalper Pro
   if(redesenhar) ChartRedraw();
}

//+------------------------------------------------------------------+
//  Tempo
//+------------------------------------------------------------------+
long ServerOffset()
{
   long d = (long)(TimeTradeServer() - TimeGMT());
   return (long)MathRound(d / 900.0) * 900;
}

long DiaBRT()                      // numero do dia em Brasilia (UTC-3)
{
   long brt = (long)TimeGMT() - 3 * 3600;
   return brt / 86400;
}

bool NaJanela(long epochUtc)
{
   long dia = DiaBRT() * 86400 + 3 * 3600;                               // 00:00 de Brasilia, em UTC
   long ini = dia + (HoraInicioBRT / 100) * 3600 + (HoraInicioBRT % 100) * 60;
   long fim = HoraFimBRT > 0 ? dia + (HoraFimBRT / 100) * 3600 + (HoraFimBRT % 100) * 60 : dia + 86400;
   long inicioBarra = epochUtc - 60;
   return (inicioBarra >= ini && inicioBarra < fim);
}

datetime InicioBarraServidor(long epochUtc) { return (datetime)(epochUtc - 60 + srvOff); }

int ShiftDe(long epochUtc)
{
   return iBarShift(_Symbol, _Period, InicioBarraServidor(epochUtc), _Period == PERIOD_M1);
}

//+------------------------------------------------------------------+
//  Arquivos
//+------------------------------------------------------------------+
string DetectarInstrumento()
{
   string suf = "_OrderFlowBolhas.txt", nome, melhor = "";
   datetime mm = 0;
   long h = FileFindFirst("mirror_" + PrefixoAtivo + "*" + suf, nome, FILE_COMMON);
   if(h == INVALID_HANDLE) return "";
   do
   {
      datetime m = (datetime)FileGetInteger(nome, FILE_MODIFY_DATE, true);
      if(m >= mm) { mm = m; melhor = nome; }
   }
   while(FileFindNext(h, nome));
   FileFindClose(h);
   int len = StringLen(melhor) - 7 - StringLen(suf);
   return len > 0 ? StringSubstr(melhor, 7, len) : "";
}

bool LerLinhas(string arq, string &linhas[], datetime &mod)
{
   if(!FileIsExist(arq, FILE_COMMON)) return false;
   datetime m = (datetime)FileGetInteger(arq, FILE_MODIFY_DATE, true);
   if(mod != 0 && m == mod) return false;
   int h = FileOpen(arq, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return false;              // arquivo em troca: tenta no proximo ciclo
   int n = 0;
   ArrayResize(linhas, 0, 2048);
   while(!FileIsEnding(h))
   {
      string s = FileReadString(h);
      if(StringLen(s) == 0) continue;
      ArrayResize(linhas, n + 1, 2048);
      linhas[n++] = s;
   }
   FileClose(h);
   mod = m;
   return n > 0;
}

//+------------------------------------------------------------------+
//  Diferenca de preco futuro (NT8) x simbolo do MT5
//+------------------------------------------------------------------+
void AtualizarOffset(long ep, double ntPreco)
{
   if(!OffsetAutomatico || ep == ultHdrEpoch || ntPreco <= 0) return;
   int sh = iBarShift(_Symbol, PERIOD_M1, InicioBarraServidor(ep), true);
   if(sh < 0) return;
   double mt = iOpen(_Symbol, PERIOD_M1, sh);
   if(mt <= 0) return;
   double o = mt - ntPreco;
   offsetPreco = offsetOk ? offsetPreco + 0.3 * (o - offsetPreco) : o;
   offsetOk = true;
   ultHdrEpoch = ep;
}

bool PrecoPronto()  { return !OffsetAutomatico || offsetOk; }
double Offset()     { return OffsetAutomatico ? offsetPreco : OffsetManual; }

//+------------------------------------------------------------------+
//  VWAP:  H;VWAPAncorada;inst;epoch;close   /   V;epoch;vwap;banda+;banda-;volume
//+------------------------------------------------------------------+
bool ProcessarVWAP()
{
   string L[];
   string arq = "mirror_" + inst + "_VWAPAncorada.txt";
   if(!FileIsExist(arq, FILE_COMMON)) { if(MostrarVWAP || MostrarAbsorcao) aviso = "sem " + arq + " (VWAP e absorcao precisam dele)"; return false; }
   if(!LerLinhas(arq, L, modVwap)) return false;

   int n = ArraySize(L);
   for(int i = 0; i < n; i++)
   {
      if(StringGetCharacter(L[i], 0) != 'H') continue;
      string f[];
      if(StringSplit(L[i], ';', f) >= 5) AtualizarOffset(StringToInteger(f[3]), StringToDouble(f[4]));
      break;
   }
   if(!MostrarVWAP || !PrecoPronto() || ArraySize(bVwap) == 0) return false;

   double off = Offset();
   int    sMin = -1;
   double lv = EMPTY_VALUE, lu = EMPTY_VALUE, ld = EMPTY_VALUE;
   int    tot = ArraySize(bVwap);
   for(int i = 0; i < n; i++)
   {
      if(StringGetCharacter(L[i], 0) != 'V') continue;
      string f[];
      if(StringSplit(L[i], ';', f) < 5) continue;
      long ep = StringToInteger(f[1]);
      if(!NaJanela(ep)) continue;
      int sh = ShiftDe(ep);
      if(sh < 0 || sh >= tot) continue;
      bVwap[sh] = StringToDouble(f[2]) + off;
      bUp[sh]   = StringToDouble(f[3]) + off;
      bDn[sh]   = StringToDouble(f[4]) + off;
      if(sMin < 0 || sh < sMin) { sMin = sh; lv = bVwap[sh]; lu = bUp[sh]; ld = bDn[sh]; }
   }
   for(int s = sMin - 1; s >= 0; s--) { bVwap[s] = lv; bUp[s] = lu; bDn[s] = ld; }   // barra(s) em formacao
   return sMin >= 0;
}

//+------------------------------------------------------------------+
//  Escala e objetos (o indicador guarda o que desenhou; nunca consulta o grafico)
//+------------------------------------------------------------------+
double PxBolha(int w)  { return 6.0 + 2.5 * w; }
double PxTexto(int fs) { return 1.35 * fs + 1.0; }

// Escala e area visivel SEM consultar o grafico: o servico RM_NT8Escala mede e publica em
// variaveis globais do terminal (leitura instantanea, nunca espera a tela).
// Sem o servico: estimativa pelos ultimos candles (BarrasEstimadas / AlturaEstimadaPx).
void LerEscala()
{
   double t = GlobalVariableGet(gvBase + "t");
   if(t > 0 && (long)TimeLocal() - (long)t <= 10)
   {
      double p = GlobalVariableGet(gvBase + "ppp");
      if(p > 0)
      {
         pppAtual  = p;
         visIni    = (datetime)(long)GlobalVariableGet(gvBase + "ini");
         visFim    = (datetime)(long)GlobalVariableGet(gvBase + "fim");
         servicoOk = true;
         return;
      }
   }
   servicoOk = false;
   double hi = 0, lo = 0;
   int n = MathMax(10, BarrasEstimadas);
   for(int i = 0; i < n; i++)
   {
      double h = iHigh(_Symbol, _Period, i), l = iLow(_Symbol, _Period, i);
      if(h <= 0 || l <= 0) break;
      if(hi == 0 || h > hi) hi = h;
      if(lo == 0 || l < lo) lo = l;
   }
   pppAtual = (hi > lo) ? (hi - lo) * 1.10 / MathMax(100, AlturaEstimadaPx) : _Point;
   visIni   = 0;
   visFim   = D'3000.01.01';
}

double YDe(const Obj &o, double ppp)
{
   if(o.tipo == 2)
   {
      double y = o.bruto;
      if(PrenderAbsorcaoNoCandle && o.hi > 0 && o.lo > 0)
      {
         double m = (MargemAbsorcaoPx + 0.30 * o.fs) * ppp;
         if(o.hi - o.lo > 2 * m) y = MathMin(MathMax(y, o.lo + m), o.hi - m);
         else                    y = (o.hi + o.lo) / 2;
      }
      return y;
   }
   return o.cima ? o.ext + o.px * ppp : o.ext - o.px * ppp;
}

int AcharObj(const string nome)
{
   for(int i = 0; i < nObj; i++) if(objs[i].nome == nome) return i;
   return -1;
}

// cria o objeto se for novo; se ja existe, so move/atualiza se algo mudou
bool Garantir(string nome, int tipo, datetime t, double ext, double hi, double lo, double bruto,
              bool cima, double px, int fs, string txt, color cor, int largura, string fonte)
{
   string assin = txt + "|" + (string)(int)cor + "|" + (string)largura + "|" + (string)fs + "|" + fonte + "|" + (cima ? "c" : "b");
   int  i = AcharObj(nome);
   bool novo = (i < 0);
   if(novo)
   {
      ArrayResize(objs, nObj + 1, 512); i = nObj++;
      objs[i].nome = nome; objs[i].assin = ""; objs[i].y = 0; objs[i].t = 0;
   }
   datetime tAnt = objs[i].t;
   objs[i].tipo = tipo; objs[i].t = t; objs[i].ext = ext; objs[i].hi = hi; objs[i].lo = lo; objs[i].bruto = bruto;
   objs[i].cima = cima; objs[i].px = px; objs[i].fs = fs; objs[i].vivo = true; objs[i].pppUsado = pppAtual;
   double y = YDe(objs[i], pppAtual);
   bool mexeu = false;

   if(novo)
   {
      bool ok = ObjectCreate(0, nome, tipo == 0 ? OBJ_ARROW : OBJ_TEXT, 0, t, y);
      if(!ok) ObjectMove(0, nome, 0, t, y);                        // sobra de execucao anterior
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
      if(tipo == 0) ObjectSetInteger(0, nome, OBJPROP_ARROWCODE, 108);
      // no fundo: o painel do Scalper Pro (objetos da frente) fica por cima das bolhas
      ObjectSetInteger(0, nome, OBJPROP_BACK, DesenharNoFundo);
      if(oculto) ObjectSetInteger(0, nome, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      mexeu = true;
   }
   else if(t != tAnt || MathAbs(y - objs[i].y) > 0.3 * pppAtual)
   {
      ObjectMove(0, nome, 0, t, y);
      mexeu = true;
   }
   objs[i].y = y;

   if(assin != objs[i].assin)
   {
      objs[i].assin = assin;
      ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
      if(tipo == 0)
      {
         ObjectSetInteger(0, nome, OBJPROP_WIDTH, largura);
         ObjectSetInteger(0, nome, OBJPROP_ANCHOR, cima ? ANCHOR_BOTTOM : ANCHOR_TOP);
      }
      else
      {
         ObjectSetString (0, nome, OBJPROP_TEXT, txt);
         ObjectSetString (0, nome, OBJPROP_FONT, fonte);
         ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, fs);
         ObjectSetInteger(0, nome, OBJPROP_ANCHOR, tipo == 2 ? ANCHOR_CENTER : (cima ? ANCHOR_LOWER : ANCHOR_UPPER));
      }
      mexeu = true;
   }
   return mexeu;
}

void CopiarObj(int k, int i)
{
   objs[k].nome = objs[i].nome;   objs[k].assin = objs[i].assin; objs[k].tipo = objs[i].tipo; objs[k].t = objs[i].t;
   objs[k].ext  = objs[i].ext;    objs[k].hi = objs[i].hi;       objs[k].lo = objs[i].lo;     objs[k].bruto = objs[i].bruto;
   objs[k].px   = objs[i].px;     objs[k].y = objs[i].y;         objs[k].pppUsado = objs[i].pppUsado;
   objs[k].cima = objs[i].cima;   objs[k].vivo = objs[i].vivo;   objs[k].fs = objs[i].fs;
}

void Marcar(bool bolhas)
{
   for(int i = 0; i < nObj; i++)
      if(bolhas ? objs[i].tipo <= 1 : objs[i].tipo == 2) objs[i].vivo = false;
}

// apaga so o que sumiu do arquivo
bool Recolher(bool bolhas)
{
   bool m = false;
   int  k = 0;
   for(int i = 0; i < nObj; i++)
   {
      bool grupo = bolhas ? objs[i].tipo <= 1 : objs[i].tipo == 2;
      if(grupo && !objs[i].vivo) { ObjectDelete(0, objs[i].nome); m = true; continue; }
      if(k != i) CopiarObj(k, i);
      k++;
   }
   nObj = k;
   ArrayResize(objs, nObj, 512);
   return m;
}

// escala mudou: move SO os objetos visiveis; os de fora da tela ajustam quando aparecerem
void AjustarEscala()
{
   LerEscala();
   if(pppAtual <= 0) return;
   bool m = false;
   for(int i = 0; i < nObj; i++)
   {
      if(MathAbs(objs[i].pppUsado - pppAtual) <= 0.02 * pppAtual) continue;
      if(objs[i].t < visIni || objs[i].t > visFim) continue;
      double y = YDe(objs[i], pppAtual);
      objs[i].pppUsado = pppAtual;
      if(MathAbs(y - objs[i].y) > 0.3 * pppAtual)
      {
         ObjectMove(0, objs[i].nome, 0, objs[i].t, y);
         objs[i].y = y;
         m = true;
      }
   }
   if(m) ChartRedraw();
}

//+------------------------------------------------------------------+
//  Bolhas:  O;<id>;<dot|text>;<epoch>;<preco>;<cor>;<texto>;<cima|baixo>;<linha>
//   ofbb/ofbn = bolha normal | pcrb/pcrn = PCR (ou "2x" verde-limao, mesmo id: o ultimo vale)
//   x2b/x2n   = X2. Nos candles com PCR/2x a bolha normal vem SEM numero.
//+------------------------------------------------------------------+
double Usado(datetime t, bool cima)
{
   for(int i = 0; i < ArraySize(usT); i++) if(usT[i] == t) return cima ? usCima[i] : usBaixo[i];
   return 0;
}

void Usar(datetime t, bool cima, double v)
{
   int k = ArraySize(usT);
   for(int i = 0; i < k; i++) if(usT[i] == t) { if(cima) usCima[i] = v; else usBaixo[i] = v; return; }
   ArrayResize(usT, k + 1, 256); ArrayResize(usCima, k + 1, 256); ArrayResize(usBaixo, k + 1, 256);
   usT[k] = t; usCima[k] = cima ? v : 0; usBaixo[k] = cima ? 0 : v;
}

color CorDe(string nome)
{
   if(nome == "magenta")   return CorVenda;
   if(nome == "turquoise") return CorCompra;
   if(nome == "lime")      return CorDobro;
   if(nome == "gray" || nome == "grey") return CorNeutro;
   if(nome == "yellow")    return CorAbsorcao;
   return clrSilver;
}

int OrdemFam(string fam) { if(fam == "ofb") return 0; if(fam == "x2") return 1; if(fam == "pcr") return 2; return 3; }

bool ProcessarBolhas()
{
   string L[];
   if(!LerLinhas("mirror_" + inst + "_OrderFlowBolhas.txt", L, modBol)) return false;

   // 1) junta ponto + texto de cada sinal (so os da janela do dia)
   ArrayResize(sinais, 0, 512);
   int ns = 0, n = ArraySize(L);
   for(int i = 0; i < n; i++)
   {
      if(StringFind(L[i], "O;") != 0) continue;
      string f[];
      int k = StringSplit(L[i], ';', f);
      if(k < 6) continue;
      long ep = StringToInteger(f[3]);
      if(!NaJanela(ep)) continue;
      string id = f[1];
      int p = 0;
      while(p < StringLen(id) && (StringGetCharacter(id, p) < '0' || StringGetCharacter(id, p) > '9')) p++;
      if(p < 2 || p >= StringLen(id)) continue;
      string fam = StringSubstr(id, 0, p - 1);                     // tira o 'b'/'n' final
      if(fam == "abs") continue;                                    // absorcao vem do outro arquivo
      string chave = fam + StringSubstr(id, p);
      string txt = k > 6 ? f[6] : "";
      string lado = k > 7 ? f[7] : "";

      int j = -1;
      for(int q = ns - 1; q >= 0 && q >= ns - 12; q--) if(sinais[q].chave == chave) { j = q; break; }
      if(j < 0)
      {
         ArrayResize(sinais, ns + 1, 512); j = ns++;
         sinais[j].chave = chave; sinais[j].fam = fam; sinais[j].ep = ep;
         sinais[j].temDot = false; sinais[j].temTxt = false; sinais[j].txt = ""; sinais[j].corDot = ""; sinais[j].corTxt = "";
         sinais[j].cima = false;
      }
      if(lado != "") sinais[j].cima = (lado == "cima");
      else if(f[5] == "magenta" || StringGetCharacter(txt, 0) == '-') sinais[j].cima = true;   // formato antigo
      if(f[2] == "dot")  { sinais[j].temDot = true; sinais[j].corDot = f[5]; }
      if(f[2] == "text") { sinais[j].temTxt = true; sinais[j].txt = txt; sinais[j].corTxt = f[5]; }   // o ultimo vale (PCR -> 2x)
   }

   nsin = ns;
   LerEscala();
   DesenharBolhas();
   return true;
}

bool DesenharBolhas()
{
   Marcar(true);
   ArrayResize(usT, 0); ArrayResize(usCima, 0); ArrayResize(usBaixo, 0);
   nBolhas = 0;
   bool m = false;

   if(MostrarBolhas)
      for(int ordem = 0; ordem <= 3; ordem++)
         for(int i = 0; i < nsin; i++)
         {
            if(OrdemFam(sinais[i].fam) != ordem) continue;
            bool dobro = (sinais[i].corDot == "lime" || sinais[i].corTxt == "lime" || StringFind(sinais[i].txt, "2x") == 0);
            if(sinais[i].fam == "pcr" && dobro && !MostrarDobro) continue;
            if(sinais[i].fam == "pcr" && !dobro && !MostrarPCR) continue;
            if(sinais[i].fam == "x2" && !MostrarX2) continue;

            if(MaxMinutosNaTela > 0 && sinais[i].ep < (long)TimeGMT() - MaxMinutosNaTela * 60) continue;
            int sh = ShiftDe(sinais[i].ep);
            if(sh < 0) continue;
            datetime tb = iTime(_Symbol, _Period, sh);
            bool   up  = sinais[i].cima;
            double ext = up ? iHigh(_Symbol, _Period, sh) : iLow(_Symbol, _Period, sh);
            double px  = Usado(tb, up);
            if(px == 0) px = DistBolhaPx;
            string nm  = PFX + "B" + sinais[i].chave;

            if(sinais[i].temDot)
            {
               int w;
               if(sinais[i].fam == "ofb")
               {
                  long a = (long)MathAbs((double)StringToInteger(sinais[i].txt));
                  w = sinais[i].temTxt ? (a >= 500 ? 4 : (a >= 200 ? 3 : (a >= 80 ? 2 : 1))) : 2;
               }
               else w = dobro ? 5 : (sinais[i].fam == "pcr" ? 4 : 3);
               m |= Garantir(nm + "d", 0, tb, ext, 0, 0, 0, up, px, 0, "", CorDe(sinais[i].corDot), w, "");
               px += PxBolha(w) + EspacoTextoPx;
               if(sinais[i].fam == "ofb") nBolhas++;
            }
            if(sinais[i].temTxt && (MostrarNumeros || sinais[i].fam != "ofb"))
            {
               int fs = dobro ? TamanhoFonte + 5 : TamanhoFonte;
               m |= Garantir(nm + "t", 1, tb, ext, 0, 0, 0, up, px, fs, sinais[i].txt, CorDe(sinais[i].corTxt), 0,
                             dobro ? "Arial Black" : "Arial");
               px += PxTexto(fs) + EspacoTextoPx;
               if(sinais[i].fam == "ofb") ultBolha = TimeToString(tb, TIME_MINUTES) + " " + sinais[i].txt;
            }
            Usar(tb, up, px + 2);
         }
   m |= Recolher(true);
   return m;
}

//+------------------------------------------------------------------+
//  Absorcao:  O;absbNNNN;dot;epoch;preco;yellow;
//+------------------------------------------------------------------+
bool ProcessarAbsorcao()
{
   string arqA = "mirror_" + inst + "_RaioXAbsorcao.txt";
   if(!FileIsExist(arqA, FILE_COMMON)) { aviso = "sem " + arqA + " (RaioX ativo no NT8?)"; return false; }
   if(!PrecoPronto())
   {
      if(aviso == "") aviso = "absorcao aguardando calibrar o preco (precisa do arquivo VWAPAncorada)";
      return false;
   }
   string L[];
   if(!LerLinhas(arqA, L, modAbs)) return false;

   double off = OffsetAbsorcao != 0.0 ? OffsetAbsorcao : Offset();
   ArrayResize(absT, 0, 256); ArrayResize(absY, 0, 256);
   nAbsLidas = 0;
   int n = ArraySize(L);
   for(int i = 0; i < n; i++)
   {
      if(StringFind(L[i], "O;absb") != 0) continue;
      string f[];
      if(StringSplit(L[i], ';', f) < 5) continue;
      long ep = StringToInteger(f[3]);
      if(!NaJanela(ep)) continue;
      int sh = ShiftDe(ep);
      if(sh < 0) continue;
      ArrayResize(absT, nAbsLidas + 1, 256); ArrayResize(absY, nAbsLidas + 1, 256);
      if(MaxMinutosNaTela > 0 && ep < (long)TimeGMT() - MaxMinutosNaTela * 60) continue;
      absT[nAbsLidas] = iTime(_Symbol, _Period, sh);
      absY[nAbsLidas] = StringToDouble(f[4]) + off + AjusteAbsorcaoPontos * _Point;
      nAbsLidas++;
   }
   if(pppAtual <= 0) LerEscala();
   return DesenharAbsorcao();
}

bool DesenharAbsorcao()
{
   Marcar(false);
   nAbs = 0;
   bool m = false;
   if(MostrarAbsorcao)
   {
      int fs = FonteAbsorcao > 0 ? FonteAbsorcao : 10 + 4 * TamanhoAbsorcao;
      for(int i = 0; i < nAbsLidas; i++)
      {
         datetime ta = absT[i];
         bool repetido = false;
         for(int k = 0; k < i; k++) if(absT[k] == ta) { repetido = true; break; }
         if(repetido) continue;
         int sh = iBarShift(_Symbol, _Period, ta, true);
         if(sh < 0) continue;
         m |= Garantir(PFX + "A" + (string)(long)ta, 2, ta, 0, iHigh(_Symbol, _Period, sh), iLow(_Symbol, _Period, sh),
                       absY[i], false, 0, fs, "\x25CF", CorAbsorcao, 0, "Arial");
         nAbs++;
      }
   }
   m |= Recolher(false);
   return m;
}

//+------------------------------------------------------------------+
void Status()
{
   string nm = PFX + "status";
   if(!MostrarStatus) { if(statusCriado) ObjectDelete(0, nm); statusCriado = false; return; }
   string av = avisoCopias != "" ? avisoCopias : aviso;
   string t = "NT8 " + (inst == "" ? "?" : inst) + " | lido " + ultLeitura + " | bolhas " + (string)nBolhas + " (ultima " + ultBolha + ")";
   if(MostrarAbsorcao) t += " | absorcao " + (string)nAbs;
   t += " | offset " + (PrecoPronto() ? DoubleToString(Offset(), 2) : "calibrando") + " | objetos " + (string)nObj;
   t += servicoOk ? " | escala: servico" : " | escala: ESTIMADA (inicie o servico RM_NT8Escala)";
   if(oculto) t += " | OCULTO (botao BOLHAS)";
   if(MonitorarConexao) t += conexAnt == 0 ? " | REDE: SEM CONEXAO" : " | rede ok " + (string)pingAtual + " ms";
   if(av != "") t += " | " + av;
   bool alerta = StringFind(av, "ATENCAO") == 0;
   // linha curta: instrumento, hora da ultima leitura e so o que pede atencao (o resto vai na dica do mouse)
   string curta = "NT8 " + (inst == "" ? "?" : inst) + " | " + ultLeitura;
   if(oculto) curta += " | oculto";
   if(MonitorarConexao && conexAnt == 0) curta += " | SEM CONEXAO";
   if(avisoCopias != "") curta += " | " + IntegerToString((int)GlobalVariableGet(gvBase + "copias")) + " copias do indicador (Ctrl+I)";
   else if(aviso != "") curta += " | aviso (passe o mouse)";
   string mostrar = StatusDetalhado ? t : curta;
   if(statusCriado && mostrar + "#" + t == statusTexto) return;    // nada mudou: nao mexe no grafico
   statusTexto = mostrar + "#" + t;
   if(!statusCriado)
   {
      ObjectCreate(0, nm, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(0, nm, OBJPROP_CORNER, CORNER_LEFT_LOWER);
      ObjectSetInteger(0, nm, OBJPROP_ANCHOR, ANCHOR_LEFT_LOWER);
      ObjectSetInteger(0, nm, OBJPROP_XDISTANCE, 8);
      ObjectSetInteger(0, nm, OBJPROP_YDISTANCE, 8);
      ObjectSetInteger(0, nm, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nm, OBJPROP_HIDDEN, true);
      statusCriado = true;
   }
   ObjectSetString (0, nm, OBJPROP_TEXT, mostrar);
   ObjectSetString (0, nm, OBJPROP_TOOLTIP, t);
   if(StatusDetalhado)
   {
      ObjectSetInteger(0, nm, OBJPROP_COLOR, alerta ? clrRed : clrSilver);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, alerta ? 11 : 8);
   }
   else
   {
      bool atencao = alerta || (MonitorarConexao && conexAnt == 0);
      ObjectSetInteger(0, nm, OBJPROP_COLOR, atencao ? clrDarkOrange : clrGray);
      ObjectSetInteger(0, nm, OBJPROP_FONTSIZE, 7);
   }
}
//+------------------------------------------------------------------+
