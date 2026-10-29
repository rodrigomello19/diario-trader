//+------------------------------------------------------------------+
//|                     SCALPER PRO v6.01 - MT5                       |
//+------------------------------------------------------------------+
#property copyright "Copyright 2026, Scalper Pro"
#property version       "6.01"
#property strict

#include <Trade/Trade.mqh>

const string SP_EA_VERSAO = "6.01";

CTrade trade;

enum ENUM_PERFIL_SETUP
{
   PERFIL_NORMAL  = 0,   // Mercado normal
   PERFIL_VOLATIL = 1    // Mercado volatil
};

enum ENUM_MODO_TRAIL
{
   TRAIL_FIXO     = 0,   // SL fixo apos ativacao
   TRAIL_DINAMICO = 1    // Distancia Trail-Step, avanca a cada Step pts
};

enum ENUM_COPY_MODO
{
   COPY_DESLIGADO = 0,   // Desligado
   COPY_MAE       = 1,   // Mae (publica as posicoes)
   COPY_FILHA     = 2    // Filha (copia a mae)
};

enum ENUM_COPY_LOTE
{
   COPY_LOTE_MULT     = 0,   // Lote da mae x multiplicador
   COPY_LOTE_NOCIONAL = 1,   // Mesma exposicao (tam. contrato) x multiplicador
   COPY_LOTE_FIXO     = 2,   // Lote fixo
   COPY_LOTE_RISCO    = 3,   // Risco % do saldo ate o SL
   COPY_LOTE_BOLETA   = 4    // Lote da boleta da filha
};

enum ENUM_COPY_SLTP
{
   COPY_SLTP_PRECO_AJUST = 0,   // Preco da mae + diferenca de cotacao entre corretoras
   COPY_SLTP_DISTANCIA   = 1,   // Mesma distancia a partir da entrada da filha
   COPY_SLTP_LOCAL       = 2,   // SL/TP/trailing da boleta da filha
   COPY_SLTP_SO_FECHA    = 3    // Nao copia SL/TP: fecha quando a mae fechar
};

input group "=== Parametros de entrada ==="
input ENUM_PERFIL_SETUP InpSetupInicial = PERFIL_NORMAL;  // Setup ao iniciar

input group "=== Perfil NORMAL ==="
input double InpNorm_Lote            = 0.20;     // Lote
input double InpNorm_TakeProfit        = 1500;   // T.P. (pts)
input double InpNorm_StopLoss          = 1000;   // S.L. (pts)
input double InpNorm_TrailingStart     = 500;    // Trail (pts)
input double InpNorm_TrailingStep      = 100;    // Step (pts)

input group "=== Perfil VOLATIL ==="
input double InpVol_Lote            = 0.10;   // Lote
input double InpVol_TakeProfit      = 3000;   // T.P. (pts)
input double InpVol_StopLoss        = 2000;   // S.L. (pts)
input double InpVol_TrailingStart   = 1000;   // Trail (pts)
input double InpVol_TrailingStep    = 200;    // Step (pts)

input group "=== Execucao ==="
input bool   InpTPVirtual        = false;    // TP virtual

input group "=== Parciais ==="
input bool   InpUsarParciais       = true;   // Usar parciais (botao ON/OFF no painel)
input double InpP1_Pontos          = 500;    // P1: pontos de lucro
input double InpP1_Pct             = 50;     // P1: % do lote inicial
input double InpP2_Pontos          = 1000;   // P2: pontos de lucro
input double InpP2_Pct             = 30;     // P2: % do lote inicial
input bool   InpTrailAvancaAposP1  = true;   // Apos P1: SL vai para entrada + X pts
input int    InpTrailAvancaPtsP1   = 100;    // Apos P1: X (pts)
input bool   InpSlAvancaAposP2     = true;   // Apos P2: SL vai para o nivel do P1
input int    InpTentativasEnvio    = 3;      // Tentativas de envio por parcial
input int    InpCooldownMs         = 100;    // Espera entre tentativas (ms)

input group "=== Copiador NinjaTrader ==="
input bool   InpCopyNT_Ativo = false;   // Ativar copiador p/ NinjaTrader
// Simbolo NT8, mapeamento de contratos e conta ficam configurados na ponte (bridge),
// nao aqui, para nao exigir recompilar o EA a cada rolagem de contrato futuro.

input group "=== Copiador MT5 (contas na mesma maquina) ==="
input ENUM_COPY_MODO InpCopyModo          = COPY_DESLIGADO;        // Modo do copiador
input string         InpCopyCanal         = "SP1";                 // Canal (mesmo nome na mae e nas filhas)
input int            InpCopyIntervaloMs   = 20;                    // Intervalo de envio/leitura (ms)
input ENUM_COPY_LOTE InpCopyLoteModo      = COPY_LOTE_BOLETA;      // Filha: calculo do lote
input double         InpCopyLoteValor     = 1.0;                   // Filha: multiplicador / lote fixo / risco % (fora do modo boleta)
input double         InpCopyLoteMax       = 0;                     // Filha: lote maximo (0 = sem limite)
input ENUM_COPY_SLTP InpCopySLTPModo      = COPY_SLTP_LOCAL;       // Filha: como definir SL/TP
input double         InpCopySLEmergPts    = 0;                     // Filha: SL emergencia se nao houver SL (pts, 0 = nao)
input bool           InpCopyInverter      = false;                 // Filha: inverter direcao
input int            InpCopyIdadeMaxSeg   = 5;                     // Filha: nao abrir posicao da mae mais antiga que (s, 0 = sem limite)
input int            InpCopyDesvioPts     = 50;                    // Filha: desvio maximo na execucao (pts)
input int            InpCopyMaeOfflineSeg = 0;                     // Filha: fechar copias se a mae ficar offline por (s, 0 = nunca)
input long           InpCopyMagic         = 53504350;              // Filha: magic das ordens copiadas

input group "=== Pendentes ==="
input double InpOffsetPendPts      = 0.0;     // Entrada acima corpo (pts)
input string InpAtivoCopiarLinhas  = "";      // SYNC: ativo do grafico de estudo ("" = mesmo ativo deste grafico)

input group "=== Linhas do dia (arquivo SP_Linhas.txt) ==="
input bool   InpLinhasArquivo      = false;   // Carregar SP_Linhas.txt ao iniciar o EA (padrao: so pelo botao LINHAS)
input bool   InpLinhasAutoRecarga  = false;   // Redesenhar sozinho quando o arquivo for salvo
input double InpLinhasFaixaPct     = 10.0;    // Ignorar precos a mais de X% do preco atual (erro de digitacao)

input group "=== Timer grafico ==="
input double InpTimerDeslocPts     = 1.0;    // Deslocamento vertical (pts)
input double InpTimerPosPct        = 1.0;    // Posicao timer (0-1)

input group "=== Desempenho / Log ==="
input bool   InpLogDetalhado     = false;   // Log completo no Experts
input int    InpPerfLogSeg       = 10;      // Janela do log de performance (s)

input group "=== Fechamento por limites (popup PIN) ==="
input int    InpFecharDelaySeg   = 5;       // Segundos antes fechar MT5
input string InpMsgFecharPontos  = "Meta de pontos atingida."; //Msg fechar pontos
input string InpMsgFecharOper    = "Limite de operacoes atingido."; //Msg fechar num operações

input group "=== Caixa de mensagem (bloqueio / fechar MT5) ==="
input int    InpMsgBoxLargura    = 700;     // Largura (px)
input int    InpMsgBoxAltura     = 100;     // Altura (px)
input int    InpMsgBoxPosX       = -1;      // Pos X esquerda (-1=centralizar)
input int    InpMsgBoxPosY       = -1;      // Pos Y topo (-1=centralizar)
input int    InpMsgBoxFonte      = 10;      // Tamanho da fonte

input group "=== Teclas (codigo ASCII) ==="
input int    InpTeclaCompPend    = 74;      // Compra pendente (J)
input int    InpTeclaVendPend    = 76;      // Venda pendente (L)
input int    InpTeclaCancPend    = 75;      // Cancelar pendentes (K)
input int    InpTeclaToggleSL    = 82;      // Toggle SL vela: min/max depois OPEN (R)
input int    InpTeclaBuy         = 73;      // Buy market (I)
input int    InpTeclaSell        = 80;      // Sell market (P)
input int    InpTeclaFechar      = 79;      // Fechar posicoes + cancelar pendentes (O)
input int    InpTeclaToggleSetup = 86;      // Alternar perfil Normal/Volatil (V)

double Lote           = 0.20;
double StopLoss       = 1000;
double TakeProfit     = 1500;   // Alvo final em pontos
double TrailingStart  = 500;
double TrailingStep   = 100;

string GV_PREFIX    = "SP_";
string GV_OPS_COUNT   = "SP_OPS_COUNT";
string GV_OPS_LOCK    = "SP_OPS_LOCK";
string GV_OPS_LOCK_DAY = "SP_OPS_LOCK_DAY";
string GV_LIMIT_REASON = "SP_LIMIT_REASON";
string GV_LIM_MAX_OPS  = "SP_LIM_MAX_OPS";
string GV_LIM_PTS_POS  = "SP_LIM_PTS_POS";
string GV_LIM_PTS_NEG  = "SP_LIM_PTS_NEG";
string GV_PIN_HASH     = "SP_PIN_HASH";
string GV_SCHED_ON     = "SP_SCHED_ON";
string GV_SCHED_HHMM   = "SP_SCHED_HHMM";
string GV_SCHED_DAYS   = "SP_SCHED_DAYS";
string GV_SCHED_FIRE   = "SP_SCHED_FIRE_DAY";

const int   PIN_DIGITOS        = 6;
const int   PIN_MAX_FALHAS     = 3;
const int   PIN_COOLDOWN_SEG   = 30;

#define LIMIT_MOTIVO_NENHUM    0
#define LIMIT_MOTIVO_OPERACOES 1
#define LIMIT_MOTIVO_PTS_MAX   2
#define LIMIT_MOTIVO_PTS_MIN   3
string GV_DAY_DATE    = "SP_DAY_DATE";
string GV_DAY_PTS     = "SP_DAY_PTS";
string GV_DAY_OPS     = "SP_DAY_OPS";

const int    SP_STATE_MAGIC   = 0x53504332;
const int    SP_STATE_VERSION = 1;
datetime     g_ultimaReconStats = 0;

const int PANEL_X = 5, PANEL_Y = 3, PANEL_W = 332, PANEL_H = 336, PANEL_H_MIN = 130;
const int PANEL_COLAPSE_Y_OFFSET = 1200;
const int PANEL_Y_MAX_NORMAL     = 900;
const int PANEL_HEADER_H = 34;
const int PANEL_ACCENT_H = 2;
const int PANEL_PAD      = 12;
const int BOX_GAP        = 8;
const int PARAM_LBL_W    = 38;   // coluna do rotulo (Trail = maior)
const int PARAM_FLD_W    = 112;  // largura maxima do campo numerico
const int PARAM_LBL_GAP  = 5;    // espaco rotulo → campo
const int PARAM_LBL_FS_H = 11;   // altura visual do rotulo (fs 8)
const int EXEC_BTN_H     = 46;
const int EXEC_BTN_GAP   = 4;
const int SEC_AUX_BTN_H  = 30;
const int SEC_AUX_ROW_GAP = 6;
const int METRICS_H      = 46;
const int STAT_LBL_FS    = 6;
const int STAT_VAL_FS    = 11;
const int STAT_LBL_Y_OFFSET   = 8;
const int STAT_VAL_BOTTOM_PAD = 3;
const int STAT_MSG_FS    = 9;
const int STAT_MSG_Y_NUDGE = 0;
const int STAT_ROW_H     = 22;
const int STAT_STATUS_GAP = 4;
const int ROW_H          = 26;
const int PARAM_LBL_H    = 13;
const int PARAM_FLD_H    = 24;
const int PARAM_ROW_GAP  = 6;
const int PANEL_EDIT_ZORDER = 100;
const int SP_ROTULO_LARGURA = 80;
const int SP_ROTULO_MARGEM  = 12;

// Tema claro "Paper" (opcao A, v5.94) — BGR 0xBBGGRR
const color C_BG_COLOR       = 0xF9F6F4;   // #0D1117
const color C_BORDER_COLOR   = 0xE8E1DC;   // #30363D
const color C_HEADER_COLOR   = 0xFFFFFF;   // #12151C
const color C_HEADER_ACCENT  = 0xEFE9E5;   // #2DD4BF teal
const color C_GLASS_BG       = 0xFFFFFF;   // #161B22
const color C_GLASS_BORDER   = 0xEFE9E5;   // #30363D
const color C_NOME_COLOR     = 0x271811;   // titulo
const color C_ACCENT_COLOR   = 0xD84E1D;   // teal interativo
const color C_TP_ACCENT      = 0x477606;   // T.P. teal
const color C_LABEL_COLOR    = 0x72645B;   // labels secundarios
const color C_LABEL_BRIGHT   = 0x544034;   // labels principais
const color C_DIVIDER_COLOR  = 0xEFE9E5;
const color C_DIVIDER_LIGHT  = 0xE8E1DC;   // linha secao
const color C_SETUP_NORM_BG   = 0x477606;   // perfil NORMAL (status)
const color C_SETUP_VOL_BG    = 0x0847B5;   // perfil VOLATIL (status)
const color C_AUX_SETUP_NORM_BG    = 0x232E1A;
const color C_AUX_SETUP_NORM_BRD   = 0x346516;
const color C_AUX_SETUP_NORM_PRESS = 0x1A2418;
const color C_AUX_SETUP_VOL_BG     = 0x10222A;
const color C_AUX_SETUP_VOL_BRD    = 0x24BFFB;
const color C_AUX_SETUP_VOL_PRESS  = 0x0C181E;
const color C_AUX_SYNC_BG          = 0xFFFFFF;
const color C_AUX_SYNC_BRD         = 0xE8E1DC;
const color C_AUX_SYNC_PRESS       = 0xF5F1EE;
const color C_AUX_LIMITS_BG        = 0xFFFFFF;
const color C_AUX_LIMITS_BRD       = 0xE8E1DC;
const color C_AUX_LIMITS_PRESS     = 0xF5F1EE;
const color C_INPUT_BG       = 0xFFFFFF;   // campos
const color C_INPUT_BORDER   = 0xDCD2CB;
const color C_INPUT_TEXT     = 0x271811;
const color C_SEC_PARAMS     = 0x544034;   // teal secoes
const color C_SEC_STATUS     = 0x544034;
const color C_SPREAD_VAL     = 0x271811;   // teal spread
const color C_CLOSE_BTN_BG   = 0xF5F1EE;   // slate fechar painel
const color C_BUY_COLOR        = 0x346516;   // verde compra (referencia)
const color C_BUY_STATUS_TEXT  = 0x477606;   // compra — legivel no fundo escuro
const color C_SELL_COLOR       = 0x1D1D7F;   // vinho venda (referencia)
const color C_SELL_STATUS_TEXT = 0x1823B4;   // venda — legivel no fundo escuro
const color C_CLOSE_COLOR    = 0x72645B;
const color C_EXEC_BUY_BG    = 0x559407;   // COMPRA
const color C_EXEC_BUY_PRESS = 0x477606;
const color C_EXEC_CLOSE_BG  = 0xFFFFFF;   // FECHA cinza
const color C_EXEC_CLOSE_PRESS = 0xF5F1EE;
const color C_EXEC_SELL_BG   = 0x202DD9;   // VENDA
const color C_EXEC_SELL_PRESS = 0x1823B4;
const color C_EXEC_SYNC_BG   = 0xFFFFFF;
const color C_EXEC_SYNC_PRESS = 0xF5F1EE;
const color C_EXEC_SYNC_TXT  = 0xD84E1D;
const color C_EXEC_SYNC_BRD  = 0xE8E1DC;
const color C_STATUS_OK      = 0x477606;
const color C_STATUS_WARN    = 0x0847B5;
const color C_STATUS_ERR     = 0x1823B4;   // S.L. vermelho suave
const color C_STATUS_STRIP_BG = 0xFBFAF9;
const double STATUS_TINT_ALPHA = 0.10;
const color C_EXEC_TEXT_ON   = 0xFFFFFF;   // texto sobre COMPRA/VENDA
const color C_SEG_BG         = 0xF5F1EE;   // #EEF1F5 fundo do seletor de perfil
const color C_TINT_OK_BG     = 0xF3FDEC;   // #ECFDF3 bloco LIBERADO
const color C_TINT_ERR_BG    = 0xF2F3FE;   // #FEF3F2 bloco BLOQUEADO
const color C_MUTED          = 0x80726B;
const color C_STEP_ROTULO    = 0xD84E1D;   // ciano Step
const color C_TRAIL_FIXO_ACCENT = 0x0847B5;   // rotulo Trail quando modo fixo
const color C_TP_LINHA       = 0x346516;
const color C_TRAIL_LINHA    = 0xD84E1D;   // linha do trailing: azul (#1D4ED8), continua
const color C_PARC_LINHA     = 0x202DD9;   // linhas P1/P2: vermelho (#D92D20), pontilhadas
const color C_PEND_LINE_COLOR = 0xDC78F0;  // lilas pendente J/L — RGB(240,120,220), compra e venda
const int   C_PEND_LINE_LARGURA = 2;
const int   C_TRAIL_LARGURA  = 1;
const color C_BTN_TEXT           = 0x271811;
const color C_BTN_BG             = 0xFFFFFF;
const color C_BTN_BORDER         = 0xDCD2CB;
const color C_BTN_BG_PRESS       = 0xF5F1EE;
const color C_BTN_BORDER_PRESS   = 0xB3A298;
const int   BTN_PRESS_MIN_MS     = 150;        // tempo minimo do destaque ao clique (ms)
const int   ROTULOS_LIMPEZA_ORFAOS_SEC = 5;    // intervalo minimo para varrer rotulos orfaos
const int   BTN_EXEC_FONT_SIZE   = 9;
const int   BTN_LIMITS_ICON_SIZE = 16;
const int   BTN_LIMITS_H         = 28;
const int   BTN_SETUP_W          = 56;
const int   BTN_SETUP_H          = 22;
const int   SEC_TITLE_GAP        = 10;
const int   SEC_EXEC_GAP         = 12;
const int   SEC_EXEC_METRICS_GAP = 12;
const int   SEC_STATUS_GAP       = 10;

const string UI_FONT       = "Segoe UI";
const string UI_FONT_BOLD  = "Segoe UI Semibold";
const string UI_FONT_SYMBOL = "Segoe UI Symbol";
const string UI_FONT_LOCK   = "Webdings";        // glifo "6" = cadeado (MT5/Windows)

string OBJ_BG           = "SP_BG";
string OBJ_BORDER       = "SP_BORDER";
string OBJ_HEADER       = "SP_HEADER";
string OBJ_HEADER_LINE  = "SP_HEADER_LINE";
string OBJ_SUBTITLE     = "SP_SUBTITLE";
string OBJ_BTN_CLOSE    = "SP_CLOSE";
string OBJ_BTN_BUY      = "SP_BUY";
string OBJ_BTN_SELL     = "SP_SELL";
string OBJ_BTN_CLOSEALL = "SP_CLOSEALL";
string OBJ_BTN_SYNC_HL  = "SP_SYNC_HL";
string OBJ_BTN_LIMITS   = "SP_BTN_LIMITS";
string OBJ_BTN_SETUP    = "SP_BTN_SETUP";
string OBJ_BTN_LINHAS   = "SP_BTN_LINHAS";
string OBJ_BTN_PERF_N   = "SP_PERF_N";      // seletor de perfil (cartao PARAMETROS)
string OBJ_BTN_PERF_V   = "SP_PERF_V";
string OBJ_BTN_LOTE_DN  = "SP_LOTE_DN";     // passo do lote
string OBJ_BTN_LOTE_UP  = "SP_LOTE_UP";
string OBJ_BTN_TP_DN    = "SP_TP_DN";       // passo de 100 pts no T.P. e no S.L.
string OBJ_BTN_TP_UP    = "SP_TP_UP";
string OBJ_BTN_SL_DN    = "SP_SL_DN";
string OBJ_BTN_SL_UP    = "SP_SL_UP";
const string PARC_LINHA_PREFIX = "SPPARC_";   // linhas P1/P2 no grafico (fora do prefixo do painel)
const double PASSO_PONTOS_PAINEL = 100;

// Linhas do dia: arquivo em Common\Files (vale para todos os terminais) e objetos com prefixo proprio
// (fora do "SP_" do painel, para nao serem tratados como objetos do painel nem apagados pelo SYNC).
const string LIN_ARQ    = "SP_Linhas.txt";
const string LIN_PREFIX = "SPDIA_";
long   g_linArqData = -1;
long   g_linArqTam  = -1;

// --- Parciais (valores do painel; os inputs valem na 1a vez e quando forem alterados)
double   Partial1_Points  = 500;
double   Partial1_Close   = 50.0;
double   Partial2_Points  = 1000;
double   Partial2_Close   = 30.0;
bool     g_parciaisLigado = true;
datetime g_parciaisResetEm = 0;

enum ENUM_PARTIAL_STATE
{
   PARTIAL_WAITING   = 0,
   PARTIAL_TRIGGERED = 1,
   PARTIAL_INFLIGHT  = 2,
   PARTIAL_DONE      = 3
};

const int   PARTIAL_COUNT        = 2;
const int   PARTIAL_LOCK_SEC     = 15;
const int   PARTIAL_UI_RESET_SEC = 15;

const int   PARC_TITULO_H = 20;
// titulo + P1/P2 + linha separadora (no meio do espaco antes dos botoes).
// O residuo (100% - P1 - P2) segue ate o TP/SL/trailing e nao aparece no painel.
const int   PARC_SEC_H    = PARC_TITULO_H + (PARAM_FLD_H + PARAM_ROW_GAP) + PARAM_FLD_H + SEC_EXEC_GAP;
const int   BTN_PARC_W    = 44;
const int   BTN_PARC_H    = 18;
const int   PARC_X_PTS    = 30;    // colunas da linha P1/P2 (relativas a borda interna do cartao)
const int   PARC_W_PTS    = 96;
const int   PARC_X_PCT    = 134;
const int   PARC_W_PCT    = 54;
const int   PARC_X_ST     = 196;
const int   PARC_ROW_H    = 26;

// Layout da opcao A (v5.94): cartoes PARAMETROS e PARCIAIS, execucao, acoes, estado do dia
const int   CARD_PAD      = 10;
const int   CARD_PAR_H    = 136;
const int   CARD_PARC_H   = 112;
const int   PFLD_H        = 28;    // altura dos campos de PARAMETROS
const int   GAP_CARD      = 10;
const int   GAP_CARD_EXEC = 12;
const int   GAP_EXEC_AUX  = 8;
const int   GAP_AUX_MET   = 10;
const int   GAP_MET_STAT  = 8;
const int   MET_STATE_W   = 92;    // bloco LIBERADO/BLOQUEADO

const color C_P1_ACCENT       = 0xD84E1D;
const color C_P2_ACCENT       = 0x0847B5;
const color C_PARCIAIS_ON_BG  = 0x6AB712;
const color C_PARCIAIS_OFF_BG = 0xDCD2CB;

string OBJ_BTN_PARCIAIS = "SP_BTN_PARCIAIS";
string OBJ_P1_STATUS    = "SP_P1_STATUS";
string OBJ_P2_STATUS    = "SP_P2_STATUS";
string OBJ_P1_STATUS_BG = "SP_P1_STATUS_BG";
string OBJ_P2_STATUS_BG = "SP_P2_STATUS_BG";
string OBJ_PARC_SEP     = "SP_D2_SEP";
string OBJ_EDIT_P1_PTS  = "SP_EDIT_P1_PTS";
string OBJ_EDIT_P1_PCT  = "SP_EDIT_P1_CLOSE";
string OBJ_EDIT_P2_PTS  = "SP_EDIT_P2_PTS";
string OBJ_EDIT_P2_PCT  = "SP_EDIT_P2_CLOSE";
string OBJ_BTN_MINIMIZE = "SP_BTN_MINIMIZE";
int      g_setupAtivo = PERFIL_NORMAL;
ENUM_MODO_TRAIL g_modoTrail = TRAIL_FIXO;
bool     g_painelMinimizado = false;
int      g_statY_status = 0;
int      g_statY_metrics = 0;
const string SPL_PREFIX       = "SPL_";
string SPL_BG           = "SPL_BG";
string SPL_TITLE        = "SPL_TITLE";
string SPL_EDIT_OPS     = "SPL_EDIT_OPS";
string SPL_EDIT_POS     = "SPL_EDIT_POS";
string SPL_EDIT_NEG     = "SPL_EDIT_NEG";
string SPL_EDIT_PIN     = "SPL_EDIT_PIN";
string SPL_EDIT_PIN_ATUAL = "SPL_EDIT_PIN_ATUAL";
string SPL_EDIT_PIN_NOVO  = "SPL_EDIT_PIN_NOVO";
string SPL_EDIT_PIN_CONF  = "SPL_EDIT_PIN_CONF";
string SPL_BTN_OK       = "SPL_BTN_OK";
string SPL_BTN_CANCEL   = "SPL_BTN_CANCEL";
string SPL_BTN_TROCAR_PIN = "SPL_BTN_TROCAR_PIN";
string SPL_BTN_PIN_SALVAR = "SPL_BTN_PIN_SALVAR";
string SPL_BTN_VOLTAR   = "SPL_BTN_VOLTAR";
string SPL_EDIT_SCHED_HHMM = "SPL_EDIT_SCHED_HHMM";
string SPL_BTN_SCHED_ON    = "SPL_BTN_SCHED_ON";
const string SPL_BTN_DOW_PFX = "SPL_BTN_DOW_";

#define SPL_VIEW_LIMITES 0
#define SPL_VIEW_PIN     1
string OBJ_TXT_STATUS   = "SP_STATUS";
const string SP_STATUS_PRONTO   = "PRONTO";
const string SP_MSG_COMPRA      = "COMPRA";
const string SP_MSG_VENDA       = "VENDA";
const string SP_MSG_ERRO_ENT    = "Erro entrada";
const string SP_MSG_1OP_BARRA   = "Aguarde prox. barra";
const string SP_MSG_LOTE_INV    = "Lote invalido";
const string SP_MSG_EM_OP       = "Em operacao";
const string SP_MSG_FECHADO     = "Fechado";
const string SP_MSG_CANCELADO   = "Cancelado";
const string SP_MSG_J_ARMADO    = "Compra pendente";
const string SP_MSG_L_ARMADO    = "Venda pendente";
const string SP_MSG_ERRO_JL     = "Erro J/L";
const string SP_MSG_AUTO_TRADE  = "AutoTrading OFF";
const string SP_MSG_EA_TRADE    = "Permita trade no EA";
const string SP_MSG_CONTA_TRADE = "Conta sem trade";
const string SP_MSG_SYM_TRADE   = "Ativo sem trade";
const string SP_MSG_PENDENTE    = "Pendente";
const string SP_MSG_BLOQUEADO   = "BLOQUEADO";
const string SP_MSG_FECHANDO    = "Fechando...";
const string SP_MSG_TRAIL_FIXO  = "Trail fixo";
const string SP_MSG_TRAIL_DIN   = "Trail dinamico";
const string SP_MSG_TRAIL_DIST  = "Trail > Step";
const string SP_MSG_SYNC_OK     = "Sync OK";
const string SP_MSG_SEM_LINHAS  = "Sem linhas";
const string SP_MSG_SYNC_ATIVO  = "Ativo invalido";
const string SP_MSG_SYNC_GRAF   = "Grafico N/A";
const string SP_MSG_SL_OK       = "SL OK";
const string SP_MSG_EDITANDO    = "Editando";
const string SP_MSG_PIN_CAD     = "Cadastre PIN";
const string SP_MSG_PIN_ERR     = "PIN incorreto";
const string SP_MSG_PIN_BLOQ    = "PIN bloqueado";
const string SP_MSG_PIN_6       = "PIN: 6 digitos";
const string SP_MSG_PIN_DIFF    = "PIN diverge";
const string SP_MSG_PIN_OK      = "PIN OK";
const string SP_MSG_HORARIO     = "Horario invalido";
const string SP_MSG_DIAS        = "Selecione dias";
const string SP_MSG_LIM_BLOQ    = "Ainda no limite";
const string SP_MSG_LIM_OK      = "Limites OK";
string OBJ_TXT_SPREAD   = "SP_SPREAD";
string OBJ_TXT_OPS      = "SP_OPS";
string OBJ_TXT_PTS      = "SP_PTS_SESSAO";
string OBJ_MSG_OVERLAY_BG  = "SPM_BG";
string OBJ_MSG_OVERLAY_TXT = "SPM_TXT";
string OBJ_MSG_OVERLAY_CNT = "SPM_CNT";
const string OBJ_MSG_OVERLAY_LINHA = "SPM_TXT_L";
const int    MSG_OVERLAY_MAX_LINHAS = 8;
string OBJ_EDIT_LOTE         = "SP_EDIT_LOTE";
string OBJ_EDIT_SL           = "SP_EDIT_SL";
string OBJ_EDIT_TP           = "SP_EDIT_TP";
string OBJ_EDIT_TRAIL_START  = "SP_EDIT_TRAIL_START";

string OBJ_EDIT_TRAIL_STEP   = "SP_EDIT_TRAIL_STEP";
string OBJ_LIMITS_ICON  = "SP_LIMITS_ICON";
string OBJ_METRICS_BG   = "SP_METRICS_BG";
string OBJ_LIM_STATE    = "SP_LIM_STATE";
string OBJ_STATUS_STRIP  = "SP_STATUS_STRIP";
string OBJ_CANDLE_TIMER = "SP_TIMER";

ulong    ultimoCliqueMs = 0;   // anti-duplo-clique (GetTickCount64: anda mesmo sem ticks)
datetime lastOrderBar  = 0;

ulong g_pendBuyJ       = 0;
ulong g_pendSellL      = 0;
bool  g_jLinhaArmada   = false;
double g_jLinhaPreco   = 0;
double g_jBidNaArmacao = 0;
bool  g_lLinhaArmada   = false;
double g_lLinhaPreco   = 0;
double g_lBidNaArmacao = 0;
bool  g_jProximoNoHigh = false;
bool  g_lProximoNoLow  = false;
bool  g_jLinhaNoOpen   = false;
bool  g_lLinhaNoOpen   = false;
const string OBJ_PEND_LINE_BUY  = "SP_PEND_BUY_LINE";
const string OBJ_PEND_LINE_SELL = "SP_PEND_LINE_SELL";
const string OBJ_PEND_SL_BUY    = "SP_PEND_SL_BUY";
const string OBJ_PEND_SL_SELL   = "SP_PEND_SL_SELL";
const string OBJ_PEND_TP_BUY    = "SP_PEND_TP_BUY";
const string OBJ_PEND_TP_SELL   = "SP_PEND_TP_SELL";
datetime g_ultimaBarraJL = 0;
datetime g_ultimaBarraCampos = 0;
int      g_ultimoOpsPainel = -1;
double   g_ultimoPtsPainel = -999999.0;
int      g_ultimoSpreadPainel = -1;
datetime g_ptsOperacaoAte  = 0;
double   g_ptsUltimaOperacao = 0;
string   g_campoEditAtivo  = "";
string   g_bufferEdicao    = "";
string   g_bufferEdicaoOriginal = "";
bool     g_substituirBufferEdicao = false;

int g_contadorOperacoes = 0;
long g_chartOneClickPrev   = 0;
long g_chartDragLevelsPrev = 0;
long g_chartForegroundPrev = 0;
long g_chartKeyboardPrev   = 0;
bool g_chartOneClickSaved  = false;
bool g_chartKeyboardSaved  = false;
bool g_eaRevertendoSL      = false;
bool g_eaAtualizandoNiveis = false;
bool g_painelBloqueado     = false;
bool g_limiteBloqueadoDia  = false;
bool g_fechamentoAgendado  = false;
datetime g_fechamentoHora  = 0;
datetime g_statusResetEm   = 0;
int      g_limMaxOperacoes = 0;
double   g_limPtsPos       = 0;
double   g_limPtsNeg       = 0;
bool     g_popupLimitesAberto = false;
int      g_popupView         = SPL_VIEW_LIMITES;
bool     g_popupPinCadastro  = false;
int      g_pinFalhas       = 0;
datetime g_pinBloqueadoAte = 0;
bool     g_schedEnabled    = false;
int      g_schedHour       = 18;
int      g_schedMin        = 0;
int      g_schedDaysMask   = 0;
ulong    g_rotulosPendenteTkt    = 0;
ulong    g_rotulosPendenteNoTick = 0;
ulong    g_onTickSeq             = 0;
double   g_tickBid               = 0.0;
double   g_tickAsk               = 0.0;
ulong    g_tickCacheSeq          = 0;
ulong    g_entradaProcTkt        = 0;
bool     g_entradaProcCompra     = false;
bool     g_entradaProcCancelJl   = false;
bool     g_entradaProcNiveisOk   = false;
ulong    g_trailPendenteTkt      = 0;
bool     g_trailAgendaRemover     = false;
bool     g_trailAgendaAtualizar   = false;
ulong    g_statusEntradaTkt       = 0;
bool     g_jlRemoverCompra         = false;
bool     g_jlRemoverVenda          = false;
bool     g_cancelJlAgendado        = false;
bool     g_cancelJlCompra          = false;
bool     g_configSalvarPendente    = false;
bool     g_statusAgPendente        = false;
string   g_statusAgTxt             = "";
color    g_statusAgCor             = clrNONE;
bool     g_statusAgEvt             = false;
bool     g_statusAgImp             = false;
bool     g_jlVisCompra           = false;
bool     g_jlVisVenda            = false;
double   g_jlVisPrecoCompra      = 0;
double   g_jlVisPrecoVenda       = 0;

const int    STATUS_UI_RESET_SEC  = 15;
const double VOL_EPSILON = 1e-8;

// --- Copiador MT5 (estado) ---
struct SCopyPosMae
{
   ulong  id;
   bool   compra;
   double vol;
   double open;
   double sl;
   double tp;
   long   idadeSeg;
};

struct SCopyTentativa
{
   ulong idMae;
   int   n;
   ulong ultMs;
};

struct SCopyModify
{
   ulong tkt;
   ulong ultMs;
};

CTrade         g_copyTrade;
ENUM_COPY_MODO g_copyModoEf        = COPY_DESLIGADO;
string         g_copyCanal         = "";
string         g_copyArquivo       = "";
string         g_copyGv            = "";
ulong          g_copyTimerLegadoMs = 0;
// mae
string         g_copyMaeUltEstado  = "";
ulong          g_copyMaeUltEnvioMs = 0;
long           g_copyMaeSeq        = 0;
// filha
SCopyPosMae    g_copyMaePos[];
int            g_copyMaeN          = 0;
bool           g_copyMaeValida     = false;
ulong          g_copyMaeTickMs     = 0;     // GetTickCount64 da mae na ultima gravacao lida
long           g_copyMaeSeqLida    = -1;
long           g_copyMaeLogin      = 0;
string         g_copyMaeSimbolo    = "";
double         g_copyMaeBid        = 0;
double         g_copyMaeAsk        = 0;
double         g_copyMaeContrato   = 0;
SCopyTentativa g_copyTent[];
SCopyModify    g_copyMod[];
SCopyModify    g_copyFechadas[];      // copias fechadas com sucesso (tkt, ms)
ulong          g_copyUltLimpezaMs  = 0;
bool           g_copyOfflineFechou = false;
bool           g_copyMaeOnline     = false;
ulong          g_copyAckUltMs      = 0;
// mae: confirmacao das filhas / erro de gravacao
bool           g_copyMaeErroGrav   = false;
int            g_copyFilhasN       = 0;
int            g_copyFilhasProntas = 0;
ulong          g_copyFilhasLidoMs  = 0;
//+------------------------------------------------------------------+
//| Central de Controle (SPCentral) - integracao                     |
//| A central (programa Windows) grava em Common\Files:              |
//|  SP_Central_Ativa.txt  -> existe = este EA obedece a central     |
//|  SP_Central_Cmd.txt    -> CMD|1|tickMs|ESTADO|motivo|ate         |
//|                           Z|<conta>  (zerar so esta conta)       |
//|  ESTADO: LIVRE / BLOQ (sem novas entradas) / ZERAR (fecha tudo)  |
//| Com a marca presente e o comando ausente ou parado ha mais de    |
//| 10 s (central fechada), o EA bloqueia novas entradas.            |
//| Este EA grava para a central:                                    |
//|  SP_Central_St_<conta>_<simbolo>.txt  (estado a cada 1 s)        |
//|  SP_Central_Tr_<conta>.txt            (uma linha por operacao)   |
//+------------------------------------------------------------------+
const string CENTRAL_MARCA      = "SP_Central_Ativa.txt";
const string CENTRAL_CMD        = "SP_Central_Cmd.txt";
const int    CENTRAL_VELHA_MS   = 10000;
const int    CENTRAL_LEITURA_MS = 250;

#define CENTRAL_LIVRE 0
#define CENTRAL_BLOQ  1
#define CENTRAL_ZERAR 2

int    g_centralEstado      = CENTRAL_LIVRE;
int    g_centralEstadoAnt   = CENTRAL_LIVRE;
string g_centralMotivo      = "";
ulong  g_centralLidoMs      = 0;
ulong  g_centralUltOkMs     = 0;
ulong  g_centralStatusMs    = 0;
ulong  g_centralZerarMs     = 0;

// indicador no painel
const string   OBJ_COPY_STATUS     = "SP_COPY_ST";
const string   OBJ_COPY_STRIP      = "SP_COPY_STRIP";
string         g_copyStatusTxt     = "";
color          g_copyStatusCor     = clrNONE;

void     Status(string texto, color cor, bool eventoImportante = false, bool impedimento = false);
void     AplicarTextoStatusUI(const string texto, const color cor);
bool     ObterStatusImpedimento(string &texto, color &cor);
void     SincronizarStatusImpedimento();
void     StatusEntradaRealizada(ulong posTkt);
void     StatusComAutoReset(const string texto, color cor, bool eventoImportante = true);
void     RestaurarStatusPronto();
void     ProcessarResetStatusGeralAgendado();
void     LimparGVs(ulong posTkt);
void     AtualizarCampos();
void     ToggleModoTrail();
bool     TrailDinamicoAtivo();
double   DistanciaTrailDinamico();
void     AtualizarBotaoSetup();
void     AlternarPerfilSetup();
void     AplicarPerfilAoPainel();
string   GvCfgKey(const string sufixo);
bool     ConfigPainelSalvaExiste(const int perfil);
void     SalvarConfigPainelPerfil(const int perfil);
void     CarregarConfigPainelPerfil(const int perfil);
void     ReconciliarLinhasNiveisPosicao();
void     LimparGraficoPosicaoFechada(const ulong posId, const ulong posTktHint, const ulong posTktTrans);
void     DefinirVisibilidadeObjeto(const string name, const bool visivel);
void     ExibirObjetoPainel(const string name);
void     ReposicionarObjetoXY(const string name, const int x, const int y);
void     RestaurarLayoutSecoesColapsaveis();
void     ReposicionarBotoesExec(const int lx, const int divW, const int yExec);
void     ReposicionarBotoesAux(const int lx, const int divW, const int yAux);
bool     ObjetoPainelRestauravel(const string name);
bool     ObjetoPainelColapsavel(const string name);
void     OcultarSecoesPainelColapsadas(const bool ocultar);
void     AplicarAlturaPainel(const int altura);
int      YTextoStatusPainel(const int yStat);
int      XCentroTextoStatusPainel(const int lx, const int divW);
color    CorFaixaStatusFundo(const color cor);
void     ReposicionarSecaoStatus(const bool minimizado);
void     AplicarLayoutTextoStatus(const int yStat, const int lx, const int divW);
void     AplicarEstiloFaixaStatus(const color cor);
void     CriarFaixaStatus(const int lx, const int y, const int divW);
void     ReposicionarFaixaStatus(const int yStat, const int lx, const int divW);
void     AtualizarBotaoMinimizarPainel();
void     AplicarEstadoMinimizadoPainel();
void     ToggleMinimizarPainel();
void     EscreverValorCampoEdit(const string editName);
double   NormalizeVol(double vol);
double   NormalizeVolPainel(double vol);
void     AplicarEstiloBotaoExec(const string name, const bool press);
void     AplicarEstiloBotaoAux(const string name, const bool press);
void     GarantirBotaoLimites();
void     AtualizarEstadoLimitesUI();
void     CreateGlassRect(const string name, const int x, const int y, const int w, const int h);
void     CreateParamRowHoriz(const string lblName, const string editName, const int x, const int y,
                             const int fldW, const string label, const string value);
color    CorRotuloParametro(const string lblName);
string   TextoRotuloParametro(const string lblName);
void     AplicarEstiloRotuloParametro(const string lblName);
color    CorRotuloMetricaStatus(const string lblName);
color    CorValorPtsPainel(const double pts);
void     AplicarEstiloRotuloMetricaStatus(const string lblName);
bool     EhCampoEditavelPainel(const string name);
bool     EhCampoParametroPainel(const string name);
void     CreateEditCampoParam(const string name, const int x, const int y, const string text,
                              const int width, const int height);
void     GarantirPainelNaFrente();
void     RestaurarVisibilidadeCamposPainel();
void     ConfigurarCampoEditavel(const string name);
void     AplicarLabelMetrica(const string name);
void     GarantirMetricasStatusNaFrente();
void     GarantirCamposEditaveisPainel();
void     IniciarEdicaoCampo(const string nomeCampo);
void     FinalizarEdicaoCampo(const bool salvar);
void     ProcessarTeclaEdicaoCampo(const int key);
void     AplicarDestaqueCampoEdit(const string nomeCampo, const bool editando);
void     AtivarTecladoEdicaoCampo(const bool ativo);
void     CancelarEdicaoCampoAtiva();
void     ProcessarCliqueBotaoPainel(const string btn);
bool     EA_EstaBloqueado();
void     CarregarContadorOperacoes();
void     RegistrarOperacaoAberta(ulong posTkt, string origem);
void     TentarContarOperacaoFechada(ulong posTkt);
void     RegistrarNovaOperacao();
void     ReconciliarOperacoesAbertas();
void     ConfigurarGrafico();
void     RestaurarGrafico();
void     AtualizarArrasteSLNoGrafico(bool temPosicao);
void     ProcessarNiveisManuaisGrafico();
bool     CopyFilha_GerenciaSelecionada();
bool     CopyFilha_GerenciaTicket(const ulong t);
bool     CopyFilha_GerenciaDeal(const ulong dealTkt);
void     CopyMae_Publicar(const bool forcar);
bool     Central_BloqueiaNovas();
string   Central_TextoStatus();
void     Central_RegistrarTrade(const ulong posId, const double pts);
void     InicializarReferenciasNiveis(ulong posTkt);
void     GravarReferenciasNiveisEA(ulong posTkt, double sl, double tp);
bool     ModificarNiveisPosicaoEA(ulong posTkt, double sl, double tp);
bool     CalcularSLTPPorPontos(bool compra, double precoRef, double &sl, double &tp);
void     ValidarSLTPBroker(bool compra, double &sl, double &tp);
bool     AplicarSLTPPrecoEntrada(ulong posTkt, bool forcar = false, bool niveisJaEnviados = false);
void     FinalizarEntradaPosicao(ulong posTkt, bool compra, bool cancelarPendenteJl, bool niveisJaEnviados = false);
bool     CalcularSLTPMercado(bool compra, double &sl, double &tp);
bool     SLManualReduzPerda(long tipo, double slRef, double slNovo, double tol);
double   ToleranciaNivelPreco();
bool     PrecoNivelMudou(double a, double b, double tol);
ulong    PosIdDaPosicao(ulong posTkt);
void     CriarLinhaTrailingNaEntrada(ulong posTkt);
bool     TrailLinhaDeveSerExibida(ulong posTkt);
void     AtualizarLinhaTrailing(ulong posTkt);
void     RemoverLinhaTrailing(ulong posTkt);
void     ReconciliarLinhasTrailing();
void     AtualizarRotulosSLTP(ulong posTkt = 0);
void     AgendarRotulosSLTPPosicao(ulong posTkt);
void     ProcessarRotulosSLTPAgendados();
void     RemoverRotulosSLTP(ulong posTkt);
void     GerenciarTPVirtual(ulong posTkt = 0);
bool     AplicarTPBrokerSeAusente(ulong posTkt);
void     TrailingStop(ulong posTkt = 0);
void     DefinirLinhaPreview(const string nome, double preco, color cor,
                             const string legenda, ENUM_LINE_STYLE estilo);
ulong    TicketPosicaoSimbolo();
bool     TemPosicaoNoSimbolo();
double   DistanciaMinimaStops();
ulong    TicketPosicaoPorId(ulong posId);
bool     PodeOperarRapido();
bool     TradingPermitido();
int      MotivoTradeBloqueado();
string   TextoMotivoTradeBloqueado(const int motivo);
void     AgendarFalhaTrade(const string msgPadrao);
bool     PendenteBloqueandoEntradaRapido();
void     AtualizarCacheCotacao();
void     GarantirCacheCotacao();
void     AgendarStatus(string texto, color cor, bool eventoImportante = false, bool impedimento = false);
void     ProcessarStatusAgendado();
void     FinalizarEdicaoCampoParaExecucao();
void     ProcessarConfigSalvarAgendada();
void     CancelarPendenteLinhaBroker(bool compra);
void     AgendarRemoverVisuaisPendenteJL(bool compra);
void     ProcessarRemoverVisuaisPendenteJLAgendados();
void     AgendarCancelamentoJL(bool compra);
void     ProcessarCancelamentoJLAgendado();
bool     NiveisManuaisPrecisamSync(ulong posTkt);
void     AgendarProcessamentoEntrada(ulong posTkt, bool compra, bool cancelJl, bool niveisJaEnviados);
void     ProcessarEntradaAgendada();
void     AgendarLinhaTrailing(ulong posTkt, bool remover = false, bool atualizar = false);
void     ProcessarLinhaTrailingAgendada();
void     AgendarStatusEntradaRealizada(ulong posTkt);
void     ProcessarStatusEntradaAgendado();
void     AgendarVisuaisPendenteJL(bool compra, double preco);
void     ProcessarVisuaisPendenteJLAgendados();
bool     VerificarDesbloqueio();
void     BloquearPorLimite();
bool     LimiteOperacoesAtingido();
double   CalcularPontuacaoSessao();
void     AtualizarPainelEstatisticas(bool redesenhar = true);
bool     ExistePendenteAtiva(ulong ticketIgnorar = 0);
void     ReconstruirEstatisticasDia(bool forcar = false);
bool     EstatisticasDiaPersistidas();
void     SincronizarEstadoSeguranca();
void     GravarEstadoArquivoSeguranca();
void     VerificarIntegridadeEstadoSeguranca();
void     ProcessarEstatisticasFechamento(ulong posId, ulong dealFechamento = 0, double ptsCapturados = 0);
void     RegistrarFechamentoCompleto(ulong posId, ulong dealFechamento = 0, double ptsCapturados = 0);
ulong    ResolverTicketPosicao(ulong posId);
void     GravarTicketPosicao(ulong posTkt);
void     ZerarEstatisticasSeNovoDia();
ulong    ResolverPositionId(ulong ticketOuPosId);
bool     PosicaoFechadaPorId(ulong posId);
bool     SelecionarHistoricoDia();
bool     DealDoSimboloAtivo(ulong dealTkt);
double   PontosPosicaoHistorico(ulong positionId);
double   ObterPontoPreco();
double   PontosPorPrecosOperacao(double precoEntrada, double precoSaida, long direcao);
double   PontosPorEntradaSalva(ulong posId, ulong dealFechamento = 0);
double   PontosPorLucroDeal(ulong dealTkt);
void     AtualizarPontuacaoPainel();
bool     ExibindoPontosUltimaOperacao();
double   PontosParaExibirPainel();
void     IniciarExibicaoPontosOperacao(double pts);
void     ProcessarResetPontosOperacaoAgendado();
bool     ObterPrecosOperacao(ulong positionId, double &precoEntrada, double &precoSaida, long &direcao,
                             ulong dealSaidaPreferido = 0, datetime saidaAPartirDe = 0);
ulong    UltimoDealFechamentoPosicao(ulong positionId);
void     SalvarPrecoEntradaPosicao(ulong ticketOuPosId);
void     LimparPrecoEntradaPosicao(ulong posId);
string   GVStatsPosDone(ulong posId);
string   GVEntryOpen(ulong posId);
string   GVEntryDir(ulong posId);
bool     FechamentoPorPontosAtivo();
bool     LimitePontuacaoAtingido(double &pontuacao, int &motivo);
int      MotivoLimiteAtingidoAgora();
string   MensagemBloqueioLimite(int motivo);
void     AplicarBloqueioLimiteDia(int motivo);
bool     RestaurarBloqueioLimiteDia();
void     BloquearPainelUI(bool bloquear);
void     InicializarLimitesEfetivos();
void     SalvarLimitesEfetivos();
bool     PinJaCadastrado();
void     GravarPinHash(const string pin);
bool     PinFormatoValido(const string pin);
string   NormalizarPin(const string pin);
uint     HashPin(const string pin);
bool     ValidarPinEntrada(const string pin);
bool     PinBloqueadoPorTentativas();
void     RegistrarFalhaPin();
void     SanitizarEditPin(const string nomeEdit);
void     AbrirPopupLimites();
void     AbrirPopupPin(bool cadastro);
void     FecharPopupLimites();
void     ConfirmarPopupLimites();
void     SalvarPopupPin();
void     DesbloquearOperacoesAposLimites();
bool     EhObjetoPopupLimites(const string name);
bool     ResolverCliquePopupLimites(const string sparam, string &acao);
void     InicializarAgendaFechamento();
void     SalvarAgendaFechamento();
void     LerAgendaCamposPopup();
bool     ParseHorarioHHMM(const string texto, int &hora, int &minuto);
string   FormatarHorarioHHMM(int hora, int minuto);
datetime DiaCalendarioLocal();
void     VerificarFechamentoHorario();
bool     EhCliqueAgendaPopup(const string sparam);
void     AtualizarBotoesDiasPopup();
void     AtualizarBotaoSchedOnPopup();
string   NomeBotaoDiaPopup(int dow);
void     MontarAgendaNoPopup(int bx, int by, int lx, int ex, int ew, int &y);
void     MostrarQuadroMensagem(const string msg, int segundosRestantes);
void     AtualizarQuadroMensagem(int segundosRestantes);
void     RemoverLinhasQuadroMensagem();
void     RemoverQuadroMensagem();
void     IniciarFechamentoMT5(const string msg, bool registrarBloqueioOperacoes);
void     ProcessarFechamentoAgendado();
void     VerificarLimitePontuacao();
datetime DiaCalendarioAtual();
void     LimparBloqueioOperacoes(bool zerarContador);
void     LimparGVsOrfas();
double   LucroPontosPosicao(ulong posTkt);
bool     EhLinhaHorizontalNoGrafico(const long chartId, const string nome);
bool     EhLinhaVerticalNoGrafico(const long chartId, const string nome);
void     LimparLinhasHorizontaisAntesSync(const long chartId);
void     LinhasCriarModelo();
void     LinhasCarregar(const bool avisar);
void     LinhasVerificarArquivo();
void     SincronizarLinhasHorizontais();

string GVOpCounted(ulong dealTkt)  { return GV_PREFIX + "OC_" + IntegerToString(dealTkt); }
string GVOpOpen(ulong posTkt)      { return GV_PREFIX + "OPO_" + IntegerToString(posTkt); }
string GVOpOrigin(ulong posTkt)    { return GV_PREFIX + "OPR_" + IntegerToString(posTkt); }
string GVOpDone(ulong posTkt)      { return GV_PREFIX + "OPD_" + IntegerToString(posTkt); }

//+------------------------------------------------------------------+
//| Grafico: arraste SL (so reduz perda); TP manual bloqueado         |
//+------------------------------------------------------------------+
string GVSlManualRef(ulong posTkt) { return GV_PREFIX + "SLM_" + IntegerToString(posTkt); }
string GVTPManualRef(ulong posTkt) { return GV_PREFIX + "TPM_" + IntegerToString(posTkt); }

double ToleranciaNivelPreco()
{
   double tol = ObterPontoPreco() * 0.5;
   if(tol <= 0.0) tol = _Point * 0.5;
   return tol;
}

bool PrecoNivelMudou(const double a, const double b, const double tol)
{
   return (MathAbs(a - b) > tol);
}

bool SLManualReduzPerda(const long tipo, const double slRef, const double slNovo, const double tol)
{
   if(slNovo <= 0.0)
      return false;
   if(slRef <= 0.0)
      return true;
   if(tipo == POSITION_TYPE_BUY)
      return (slNovo >= slRef - tol);
   return (slNovo <= slRef + tol);
}

void InicializarReferenciasNiveis(ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;
   GlobalVariableSet(GVSlManualRef(posTkt),
                     NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits));
   GlobalVariableSet(GVTPManualRef(posTkt),
                     NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits));
}

void GravarReferenciasNiveisEA(ulong posTkt, const double sl, const double tp)
{
   GlobalVariableSet(GVSlManualRef(posTkt), NormalizeDouble(sl, _Digits));
   GlobalVariableSet(GVTPManualRef(posTkt), NormalizeDouble(tp, _Digits));
}

bool ModificarNiveisPosicaoEA(ulong posTkt, double sl, double tp)
{
   g_eaAtualizandoNiveis = true;
   bool ok = trade.PositionModify(posTkt, sl, tp);
   g_eaAtualizandoNiveis = false;
   if(ok)
      GravarReferenciasNiveisEA(posTkt, sl, tp);
   return ok;
}

bool CalcularSLTPPorPontos(bool compra, double precoRef, double &sl, double &tp)
{
   sl = 0;
   tp = 0;
   if(precoRef <= 0) return false;

   if(StopLoss > 0)
   {
      if(compra)
         sl = NormalizeDouble(precoRef - PontosPainelParaPreco(StopLoss), _Digits);
      else
         sl = NormalizeDouble(precoRef + PontosPainelParaPreco(StopLoss), _Digits);
   }

   if(!InpTPVirtual && TakeProfit > 0)
   {
      if(compra)
         tp = NormalizeDouble(precoRef + PontosPainelParaPreco(TakeProfit), _Digits);
      else
         tp = NormalizeDouble(precoRef - PontosPainelParaPreco(TakeProfit), _Digits);
   }

   return (sl > 0 || tp > 0);
}

bool CalcularSLTPMercado(bool compra, double &sl, double &tp)
{
   sl = 0;
   tp = 0;
   GarantirCacheCotacao();
   double preco = compra ? g_tickAsk : g_tickBid;
   if(preco <= 0) return false;
   if(!CalcularSLTPPorPontos(compra, preco, sl, tp)) return false;
   ValidarSLTPBroker(compra, sl, tp);
   return true;
}

void ValidarSLTPBroker(bool compra, double &sl, double &tp)
{
   double minDist = DistanciaMinimaStops();
   GarantirCacheCotacao();
   double bid = g_tickBid;
   double ask = g_tickAsk;

   if(compra)
   {
      if(sl > 0)
      {
         double maxSl = NormalizeDouble(bid - minDist, _Digits);
         if(sl > maxSl) sl = maxSl;
      }
      if(tp > 0)
      {
         double minTp = NormalizeDouble(ask + minDist, _Digits);
         if(tp < minTp) tp = minTp;
      }
   }
   else
   {
      if(sl > 0)
      {
         double minSl = NormalizeDouble(ask + minDist, _Digits);
         if(sl < minSl) sl = minSl;
      }
      if(tp > 0)
      {
         double maxTp = NormalizeDouble(bid - minDist, _Digits);
         if(tp > maxTp) tp = maxTp;
      }
   }
}

bool AplicarSLTPPrecoEntrada(ulong posTkt, bool forcar, bool niveisJaEnviados = false)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return false;

   if(niveisJaEnviados)
   {
      InicializarReferenciasNiveis(posTkt);
      if(!InpTPVirtual && TakeProfit > 0 && PositionGetDouble(POSITION_TP) <= 0)
         AplicarTPBrokerSeAusente(posTkt);
      return true;
   }

   long tipo = PositionGetInteger(POSITION_TYPE);
   bool compra = (tipo == POSITION_TYPE_BUY);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl = 0, tp = 0;

   if(!CalcularSLTPPorPontos(compra, open, sl, tp))
   {
      InicializarReferenciasNiveis(posTkt);
      return true;
   }

   double slAtual = PositionGetDouble(POSITION_SL);
   double tpAtual = PositionGetDouble(POSITION_TP);
   ValidarSLTPBroker(compra, sl, tp);

   double tol = ToleranciaNivelPreco();
   bool precisa = forcar
                 || ((sl > 0 || slAtual > 0) && PrecoNivelMudou(sl, slAtual, tol))
                 || ((tp > 0 || tpAtual > 0) && PrecoNivelMudou(tp, tpAtual, tol));

   if(!precisa)
   {
      InicializarReferenciasNiveis(posTkt);
      return true;
   }

   if(sl <= 0) sl = slAtual;
   if(tp <= 0) tp = tpAtual;

   bool ok = ModificarNiveisPosicaoEA(posTkt, sl, tp);
   if(!ok && InpLogDetalhado)
      Print("SP SL/TP entrada: falha modify ticket=", posTkt, " err=", GetLastError());

   if(ok)
      GravarReferenciasNiveisEA(posTkt, sl, tp);
   else
      InicializarReferenciasNiveis(posTkt);

   return ok;
}

void StatusEntradaRealizada(ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;
   long tipo = PositionGetInteger(POSITION_TYPE);
   if(tipo == POSITION_TYPE_BUY)
      Status(SP_MSG_COMPRA, C_BUY_STATUS_TEXT, true);
   else if(tipo == POSITION_TYPE_SELL)
      Status(SP_MSG_VENDA, C_SELL_STATUS_TEXT, true);
}

void ProcessarNiveisManuaisGrafico()
{
   if(g_eaRevertendoSL || g_eaAtualizandoNiveis) return;

   double tol = ToleranciaNivelPreco();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong posTkt = PositionGetTicket(i);
      if(posTkt == 0 || !PositionSelectByTicket(posTkt)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(CopyFilha_GerenciaSelecionada()) continue;

      long   tipo    = PositionGetInteger(POSITION_TYPE);
      double slAtual = NormalizeDouble(PositionGetDouble(POSITION_SL), _Digits);
      double tpAtual = NormalizeDouble(PositionGetDouble(POSITION_TP), _Digits);

      if(!GlobalVariableCheck(GVSlManualRef(posTkt)) || !GlobalVariableCheck(GVTPManualRef(posTkt)))
      {
         double slIni = PositionGetDouble(POSITION_SL);
         double tpIni = PositionGetDouble(POSITION_TP);
         if(slIni <= 0 && tpIni <= 0)
            continue;
         InicializarReferenciasNiveis(posTkt);
         continue;
      }

      double slRef = NormalizeDouble(GlobalVariableGet(GVSlManualRef(posTkt)), _Digits);
      double tpRef = NormalizeDouble(GlobalVariableGet(GVTPManualRef(posTkt)), _Digits);

      if(SLManualReduzPerda(tipo, slRef, slAtual, tol))
         GlobalVariableSet(GVSlManualRef(posTkt), slAtual);

      bool slMudou = PrecoNivelMudou(slAtual, slRef, tol);
      bool tpMudou = PrecoNivelMudou(tpAtual, tpRef, tol);
      if(!slMudou && !tpMudou) continue;

      double slFix = slAtual;
      double tpFix = tpAtual;
      bool   reverter = false;
      bool   msgSL    = false;
      bool   msgTP    = false;

      if(slMudou)
      {
         if(SLManualReduzPerda(tipo, slRef, slAtual, tol))
            GlobalVariableSet(GVSlManualRef(posTkt), slAtual);
         else
         {
            slFix = slRef;
            reverter = true;
            msgSL = true;
         }
      }

      if(tpMudou)
      {
         tpFix = tpRef;
         reverter = true;
         msgTP = true;
      }

      if(!reverter) continue;

      g_eaRevertendoSL = true;
      trade.PositionModify(posTkt, slFix, tpFix);
      g_eaRevertendoSL = false;
   }
}

void AtualizarArrasteSLNoGrafico(bool temPosicao)
{
   long cid = ChartID();
   if((bool)ChartGetInteger(cid, CHART_DRAG_TRADE_LEVELS) != temPosicao)
      ChartSetInteger(cid, CHART_DRAG_TRADE_LEVELS, temPosicao);
}

void ConfigurarGrafico()
{
   long cid = ChartID();
   if(!g_chartOneClickSaved)
   {
      g_chartOneClickPrev     = ChartGetInteger(cid, CHART_SHOW_ONE_CLICK);
      g_chartDragLevelsPrev   = ChartGetInteger(cid, CHART_DRAG_TRADE_LEVELS);
      g_chartForegroundPrev   = ChartGetInteger(cid, CHART_FOREGROUND);
      g_chartOneClickSaved    = true;
   }
   ChartSetInteger(cid, CHART_SHOW_ONE_CLICK, false);
   ChartSetInteger(cid, CHART_FOREGROUND, false);
   AtualizarArrasteSLNoGrafico(TemPosicaoNoSimbolo());
   ChartRedraw(cid);
}

void RestaurarGrafico()
{
   long cid = ChartID();
   if(g_chartKeyboardSaved)
   {
      ChartSetInteger(cid, CHART_KEYBOARD_CONTROL, g_chartKeyboardPrev);
      g_chartKeyboardSaved = false;
   }
   if(!g_chartOneClickSaved) return;
   ChartSetInteger(cid, CHART_SHOW_ONE_CLICK, g_chartOneClickPrev);
   ChartSetInteger(cid, CHART_DRAG_TRADE_LEVELS, g_chartDragLevelsPrev);
   ChartSetInteger(cid, CHART_FOREGROUND, g_chartForegroundPrev);
   ChartRedraw(cid);
   g_chartOneClickSaved = false;
}

//+------------------------------------------------------------------+
//| Limite de operacoes                                              |
//+------------------------------------------------------------------+
bool EA_EstaBloqueado()
{
   if(g_limiteBloqueadoDia)
      return true;
   return GlobalVariableCheck(GV_OPS_LOCK) && GlobalVariableGet(GV_OPS_LOCK) > 0;
}

void CarregarContadorOperacoes()
{
   ZerarEstatisticasSeNovoDia();
   g_contadorOperacoes = GlobalVariableCheck(GV_OPS_COUNT)
                       ? (int)GlobalVariableGet(GV_OPS_COUNT) : 0;
   if(g_contadorOperacoes < 0) g_contadorOperacoes = 0;
}

void IncrementarContadorLimiteOperacoes()
{
   ZerarEstatisticasSeNovoDia();
   int ops = g_contadorOperacoes;
   if(GlobalVariableCheck(GV_OPS_COUNT))
      ops = MathMax(ops, (int)GlobalVariableGet(GV_OPS_COUNT));
   ops++;
   g_contadorOperacoes = ops;
   GlobalVariableSet(GV_OPS_COUNT, (double)ops);
   GlobalVariableSet(GV_DAY_DATE, (double)DiaCalendarioAtual());
   g_ultimoOpsPainel = -1;
}

void AtualizarPainelEstatisticas(bool redesenhar = true)
{
   ZerarEstatisticasSeNovoDia();

   bool alterou = false;

   if(ObjectFind(0, OBJ_TXT_OPS) >= 0)
   {
      CarregarContadorOperacoes();

      if(g_contadorOperacoes != g_ultimoOpsPainel)
      {
         string txt = (g_limMaxOperacoes > 0)
                      ? StringFormat("%d/%d", g_contadorOperacoes, g_limMaxOperacoes)
                      : IntegerToString(g_contadorOperacoes);
         ObjectSetString(0, OBJ_TXT_OPS, OBJPROP_TEXT, txt);
         AplicarLabelMetrica(OBJ_TXT_OPS);
         g_ultimoOpsPainel = g_contadorOperacoes;
         alterou = true;
      }
   }

   if(ObjectFind(0, OBJ_TXT_PTS) >= 0)
   {
      double pts = PontosParaExibirPainel();
      string ptsTxt = DoubleToString(pts, 0);
      string atual  = ObjectGetString(0, OBJ_TXT_PTS, OBJPROP_TEXT);
      if(redesenhar || MathAbs(pts - g_ultimoPtsPainel) >= 0.01 || atual != ptsTxt)
      {
         AtualizarPontuacaoPainel();
         g_ultimoPtsPainel = pts;
         alterou = true;
      }
   }

   if(alterou && g_campoEditAtivo == "")
   {
      GarantirMetricasStatusNaFrente();
      ChartRedraw(0);
   }
}

bool LimiteOperacoesAtingido()
{
   return (g_limMaxOperacoes > 0 && g_contadorOperacoes >= g_limMaxOperacoes);
}

datetime DiaCalendarioAtual()
{
   MqlDateTime dt;
   TimeToStruct(TimeCurrent(), dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

void LimparBloqueioOperacoes(bool zerarContador)
{
   if(GlobalVariableCheck(GV_OPS_LOCK))      GlobalVariableDel(GV_OPS_LOCK);
   if(GlobalVariableCheck(GV_OPS_LOCK_DAY))   GlobalVariableDel(GV_OPS_LOCK_DAY);
   if(GlobalVariableCheck(GV_LIMIT_REASON))   GlobalVariableDel(GV_LIMIT_REASON);
   g_limiteBloqueadoDia = false;
   if(!g_fechamentoAgendado)
      RemoverQuadroMensagem();
   if(zerarContador)
   {
      GlobalVariableSet(GV_OPS_COUNT, 0);
      g_contadorOperacoes = 0;
      g_ultimoOpsPainel = -1;
      AtualizarPainelEstatisticas(true);
   }
   GravarEstadoArquivoSeguranca();
}

bool GVOperacoesPersistente(const string name)
{
   if(StringFind(name, "SP_CFG_") == 0) return true;
   return (name == GV_OPS_COUNT || name == GV_OPS_LOCK || name == GV_OPS_LOCK_DAY
        || name == GV_LIMIT_REASON
        || name == GV_DAY_DATE || name == GV_DAY_PTS || name == GV_DAY_OPS);
}

string GVStatsPosDone(ulong posId)
{
   return GV_PREFIX + "SD_" + IntegerToString(posId);
}

string GVEntryOpen(ulong posId)
{
   return GV_PREFIX + "EPO_" + IntegerToString(posId);
}

string GVEntryDir(ulong posId)
{
   return GV_PREFIX + "EDR_" + IntegerToString(posId);
}

string GVPosTicket(ulong posId)
{
   return GV_PREFIX + "PTK_" + IntegerToString(posId);
}

void GravarTicketPosicao(ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
   if(ident > 0)
      GlobalVariableSet(GVPosTicket(ident), (double)posTkt);
   GlobalVariableSet(GVPosTicket(posTkt), (double)posTkt);
}

ulong ResolverTicketPosicao(ulong posId)
{
   if(posId == 0) return 0;

   if(GlobalVariableCheck(GVPosTicket(posId)))
   {
      ulong tk = (ulong)GlobalVariableGet(GVPosTicket(posId));
      if(tk > 0) return tk;
   }

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(ident == posId)
         return t;
   }

   return posId;
}

double PontosPorPrecosOperacao(double precoEntrada, double precoSaida, long direcao)
{
   double pt = ObterPontoPreco();
   if(pt <= 0 || precoEntrada <= 0 || precoSaida <= 0) return 0;

   if(direcao == POSITION_TYPE_BUY)
      return (precoSaida - precoEntrada) / pt;
   if(direcao == POSITION_TYPE_SELL)
      return (precoEntrada - precoSaida) / pt;
   return 0;
}

double PontosPorEntradaSalva(ulong posId, ulong dealFechamento = 0)
{
   if(posId == 0) return 0;

   ulong id = posId;
   if(!GlobalVariableCheck(GVEntryOpen(id)))
      id = ResolverPositionId(posId);
   if(!GlobalVariableCheck(GVEntryOpen(id)))
      return 0;

   double precoIn = GlobalVariableGet(GVEntryOpen(id));
   long   dir     = (long)GlobalVariableGet(GVEntryDir(id));
   double precoOut = 0;

   if(dealFechamento > 0 && HistoryDealSelect(dealFechamento))
      precoOut = HistoryDealGetDouble(dealFechamento, DEAL_PRICE);
   if(precoOut <= 0)
   {
      ulong d = UltimoDealFechamentoPosicao(posId);
      if(d > 0 && HistoryDealSelect(d))
         precoOut = HistoryDealGetDouble(d, DEAL_PRICE);
   }

   return PontosPorPrecosOperacao(precoIn, precoOut, dir);
}

double PontosPorLucroDeal(ulong dealTkt)
{
   if(dealTkt == 0 || !HistoryDealSelect(dealTkt)) return 0;

   double profit = HistoryDealGetDouble(dealTkt, DEAL_PROFIT)
                 + HistoryDealGetDouble(dealTkt, DEAL_SWAP)
                 + HistoryDealGetDouble(dealTkt, DEAL_COMMISSION);
   double vol = HistoryDealGetDouble(dealTkt, DEAL_VOLUME);
   if(MathAbs(profit) < 0.0000001 || vol <= 0) return 0;

   double tickVal  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double pt       = ObterPontoPreco();
   if(tickVal <= 0 || tickSize <= 0 || pt <= 0) return 0;

   double lucroPorPonto = tickVal * (pt / tickSize) * vol;
   if(MathAbs(lucroPorPonto) < 0.0000001) return 0;
   return profit / lucroPorPonto;
}

bool ExibindoPontosUltimaOperacao()
{
   return (g_ptsOperacaoAte > 0 && TimeCurrent() < g_ptsOperacaoAte);
}

double PontosParaExibirPainel()
{
   if(ExibindoPontosUltimaOperacao())
      return g_ptsUltimaOperacao;
   return CalcularPontuacaoSessao();
}

void IniciarExibicaoPontosOperacao(double pts)
{
   g_ptsUltimaOperacao = pts;
   g_ptsOperacaoAte = TimeCurrent() + STATUS_UI_RESET_SEC;
   g_ultimoPtsPainel = -999999.0;
}

void ProcessarResetPontosOperacaoAgendado()
{
   if(g_ptsOperacaoAte <= 0) return;
   if(TimeCurrent() < g_ptsOperacaoAte) return;

   g_ptsOperacaoAte = 0;
   g_ptsUltimaOperacao = 0;
   g_ultimoPtsPainel = -999999.0;
   AtualizarPontuacaoPainel();
   ChartRedraw(0);
}

void AtualizarPontuacaoPainel()
{
   if(ObjectFind(0, OBJ_TXT_PTS) < 0) return;

   double pts = PontosParaExibirPainel();
   ObjectSetString(0, OBJ_TXT_PTS, OBJPROP_TEXT, DoubleToString(pts, 0));
   ObjectSetInteger(0, OBJ_TXT_PTS, OBJPROP_COLOR, CorValorPtsPainel(pts));
   AplicarLabelMetrica(OBJ_TXT_PTS);
}

bool ObterPrecosOperacao(ulong positionId, double &precoEntrada, double &precoSaida, long &direcao,
                         ulong dealSaidaPreferido = 0, datetime saidaAPartirDe = 0)
{
   precoEntrada = 0;
   precoSaida = 0;
   direcao = -1;
   if(positionId == 0) return false;

   if(!HistorySelectByPosition(positionId))
      HistorySelect(0, TimeCurrent() + 60);

   datetime tEntrada = D'2099.12.31';
   datetime tSaida = 0;
   double   somaPV = 0, somaV = 0;   // saidas ponderadas pelo volume (parciais)
   int      nSaidas = 0;

   int total = HistoryDealsTotal();
   for(int i = 0; i < total; i++)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || !HistoryDealSelect(d)) continue;
      if(!DealDoSimboloAtivo(d)) continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != positionId) continue;

      long   entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      long   dtype = HistoryDealGetInteger(d, DEAL_TYPE);
      double price = HistoryDealGetDouble(d, DEAL_PRICE);
      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);

      bool ehEntrada = (entry == DEAL_ENTRY_IN);
      bool ehSaida   = (entry == DEAL_ENTRY_OUT);

      if(entry == DEAL_ENTRY_INOUT)
      {
         if(precoEntrada <= 0 || t < tEntrada)
            ehEntrada = true;
         else
            ehSaida = true;
      }

      if(ehEntrada && t < tEntrada)
      {
         tEntrada = t;
         precoEntrada = price;
         if(dtype == DEAL_TYPE_BUY)       direcao = POSITION_TYPE_BUY;
         else if(dtype == DEAL_TYPE_SELL) direcao = POSITION_TYPE_SELL;
      }

      if(ehSaida)
      {
         if(saidaAPartirDe > 0 && t < saidaAPartirDe) continue;
         double v = HistoryDealGetDouble(d, DEAL_VOLUME);
         if(v > 0) { somaPV += price * v; somaV += v; nSaidas++; }
         if(t >= tSaida)
         {
            tSaida = t;
            precoSaida = price;
         }
      }
   }

   if(nSaidas > 1 && somaV > 0)
      precoSaida = somaPV / somaV;   // varias saidas (parciais): preco medio ponderado pelo volume
   else if(dealSaidaPreferido > 0 && HistoryDealSelect(dealSaidaPreferido))
      precoSaida = HistoryDealGetDouble(dealSaidaPreferido, DEAL_PRICE);

   return (precoEntrada > 0 && precoSaida > 0 && direcao >= 0);
}

void SalvarPrecoEntradaPosicao(ulong ticketOuPosId)
{
   if(ticketOuPosId == 0) return;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tkt = PositionGetTicket(i);
      if(tkt == 0 || !PositionSelectByTicket(tkt)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(ident != ticketOuPosId && tkt != ticketOuPosId
         && ident != ResolverPositionId(ticketOuPosId))
         continue;

      GlobalVariableSet(GVEntryOpen(ident), PositionGetDouble(POSITION_PRICE_OPEN));
      GlobalVariableSet(GVEntryDir(ident), (double)PositionGetInteger(POSITION_TYPE));
      GravarTicketPosicao(tkt);
      return;
   }
}

void LimparPrecoEntradaPosicao(ulong posId)
{
   if(posId == 0) return;
   if(GlobalVariableCheck(GVEntryOpen(posId))) GlobalVariableDel(GVEntryOpen(posId));
   if(GlobalVariableCheck(GVEntryDir(posId)))  GlobalVariableDel(GVEntryDir(posId));
   if(GlobalVariableCheck(GVPosTicket(posId))) GlobalVariableDel(GVPosTicket(posId));
}

// Unidade de pontos = menor passo da cotação (ex.: US100 com POINT=1.0 e 2 dígitos → 0.01).
double ObterPontoPreco()
{
   static string s_symCache = "";
   static int    s_digitsCache = -1;
   static double s_ptCache = 0.0;

   string sym = _Symbol;
   int digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   if(sym == s_symCache && digits == s_digitsCache && s_ptCache > 0.0)
      return s_ptCache;

   double pt = SymbolInfoDouble(sym, SYMBOL_POINT);
   if(pt <= 0) pt = _Point;

   if(digits > 0)
   {
      double ptCotacao = MathPow(10.0, -digits);
      if(ptCotacao > 0 && ptCotacao < pt)
         pt = ptCotacao;
   }

   double tick = SymbolInfoDouble(sym, SYMBOL_TRADE_TICK_SIZE);
   if(tick > 0 && tick < pt)
      pt = tick;

   s_symCache = sym;
   s_digitsCache = digits;
   s_ptCache = pt;
   return pt;
}

double PontosPainelParaPreco(double pontos)
{
   if(pontos <= 0) return 0;
   return pontos * ObterPontoPreco();
}

ulong TicketPosicaoSimbolo()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol) return t;
   }
   return 0;
}

bool TemPosicaoNoSimbolo()
{
   return (TicketPosicaoSimbolo() > 0);
}

void AtualizarCacheCotacao()
{
   g_tickBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   g_tickAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   g_tickCacheSeq = g_onTickSeq;
}

void GarantirCacheCotacao()
{
   if(g_tickCacheSeq != g_onTickSeq || g_tickBid <= 0.0 || g_tickAsk <= 0.0)
      AtualizarCacheCotacao();
}

double DistanciaMinimaStops()
{
   static ulong s_seq = 0;
   static double s_dist = 0.0;
   if(g_onTickSeq > 0 && s_seq == g_onTickSeq && s_dist > 0.0)
      return s_dist;

   long minStopsLevel = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   s_dist = (minStopsLevel > 0) ? minStopsLevel * _Point : _Point * 10;
   s_seq = g_onTickSeq;
   return s_dist;
}

ulong UltimoDealFechamentoPosicao(ulong positionId)
{
   if(positionId == 0) return 0;

   HistorySelect(0, TimeCurrent() + 60);
   ulong   melhor = 0;
   datetime tMelhor = 0;
   int total = HistoryDealsTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if(d == 0 || !HistoryDealSelect(d)) continue;
      if(!DealDoSimboloAtivo(d)) continue;
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != positionId) continue;

      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      datetime t = (datetime)HistoryDealGetInteger(d, DEAL_TIME);
      if(t >= tMelhor)
      {
         tMelhor = t;
         melhor = d;
      }
   }
   return melhor;
}

bool DealDoSimboloAtivo(ulong dealTkt)
{
   if(dealTkt == 0 || !HistoryDealSelect(dealTkt)) return false;

   string sym = HistoryDealGetString(dealTkt, DEAL_SYMBOL);
   if(sym == _Symbol) return true;

   int len = StringLen(_Symbol);
   if(len > 0 && StringFind(sym, _Symbol) == 0)
      return true;

   return false;
}

void ZerarEstatisticasSeNovoDia()
{
   datetime dia = DiaCalendarioAtual();

   if(GlobalVariableCheck(GV_DAY_DATE)
      && (datetime)GlobalVariableGet(GV_DAY_DATE) == dia)
      return;

   // Reinicio do terminal: estatisticas salvas sem data — mantem o dia atual
   if(!GlobalVariableCheck(GV_DAY_DATE))
   {
      bool temOps = (GlobalVariableCheck(GV_OPS_COUNT) && GlobalVariableGet(GV_OPS_COUNT) > 0.0);
      bool temPts = (GlobalVariableCheck(GV_DAY_PTS) && MathAbs(GlobalVariableGet(GV_DAY_PTS)) >= 0.01);
      bool temOpsDia = (GlobalVariableCheck(GV_DAY_OPS) && GlobalVariableGet(GV_DAY_OPS) > 0.0);
      if(temOps || temPts || temOpsDia)
      {
         GlobalVariableSet(GV_DAY_DATE, (double)dia);
         return;
      }
   }

   GlobalVariableSet(GV_DAY_DATE, (double)dia);
   GlobalVariableSet(GV_DAY_PTS, 0.0);
   GlobalVariableSet(GV_DAY_OPS, 0.0);
   GlobalVariableSet(GV_OPS_COUNT, 0.0);
   LimparBloqueioOperacoes(false);
   g_limiteBloqueadoDia = false;
   g_contadorOperacoes = 0;
   g_ultimoOpsPainel = -1;
   g_ultimoPtsPainel = -999999.0;
   g_ptsOperacaoAte = 0;
   g_ptsUltimaOperacao = 0;

   int gvTotal = GlobalVariablesTotal();
   for(int i = gvTotal - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, GV_PREFIX + "SD_") == 0)
         GlobalVariableDel(name);
   }
}

ulong TicketNoSufixoGV(const string name)
{
   int last = -1;
   for(int i = StringLen(name) - 1; i >= 0; i--)
   {
      if(StringGetCharacter(name, i) == '_')
      {
         last = i;
         break;
      }
   }
   if(last < 0 || last >= StringLen(name) - 1) return 0;

   string tail = StringSubstr(name, last + 1);
   if(StringLen(tail) == 0) return 0;
   for(int j = 0; j < StringLen(tail); j++)
   {
      ushort c = StringGetCharacter(tail, j);
      if(c < '0' || c > '9') return 0;
   }
   return (ulong)StringToInteger(tail);
}

bool PosicaoAtivaNoSimbolo(ulong ticket)
{
   if(ticket == 0) return false;
   if(!PositionSelectByTicket(ticket)) return false;
   return (PositionGetString(POSITION_SYMBOL) == _Symbol);
}

void LimparGVsOrfas()
{
   HistorySelect(0, TimeCurrent());

   int total = GlobalVariablesTotal();
   for(int i = total - 1; i >= 0; i--)
   {
      string name = GlobalVariableName(i);
      if(StringFind(name, GV_PREFIX) != 0) continue;
      if(GVOperacoesPersistente(name)) continue;

      if(StringFind(name, GV_PREFIX + "OC_") == 0)
      {
         ulong dealTkt = TicketNoSufixoGV(name);
         if(dealTkt == 0 || !HistoryDealSelect(dealTkt))
            GlobalVariableDel(name);
         continue;
      }

      ulong ticket = TicketNoSufixoGV(name);
      if(ticket == 0) continue;
      if(!PosicaoAtivaNoSimbolo(ticket))
         GlobalVariableDel(name);
   }
}

int DelayFechamentoSegundos()
{
   int s = InpFecharDelaySeg;
   if(s < 1)  s = 1;
   if(s > 60) s = 60;
   return s;
}

bool FechamentoPorPontosAtivo()
{
   return (g_limPtsPos > 0 || g_limPtsNeg > 0);
}

ulong ResolverPositionId(ulong ticketOuPosId)
{
   if(ticketOuPosId == 0) return 0;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tkt = PositionGetTicket(i);
      if(tkt == 0 || !PositionSelectByTicket(tkt)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(tkt == ticketOuPosId || ident == ticketOuPosId)
         return ident;
   }

   return ticketOuPosId;
}

bool PosicaoIdAindaAberta(ulong posId)
{
   if(posId == 0) return false;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong tkt = PositionGetTicket(i);
      if(tkt == 0 || !PositionSelectByTicket(tkt)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(ident == posId || tkt == posId)
         return true;
   }
   return false;
}

bool PosicaoFechadaPorId(ulong posId)
{
   return (posId > 0 && !PosicaoIdAindaAberta(posId));
}

bool SelecionarHistoricoDia()
{
   if(!HistorySelect(0, TimeCurrent()))
      return false;
   return true;
}

bool PosicaoIdNaLista(const ulong &ids[], int n, ulong posId)
{
   for(int i = 0; i < n; i++)
      if(ids[i] == posId) return true;
   return false;
}

double PontosPosicaoHistorico(ulong positionId)
{
   if(positionId == 0) return 0;

   double precoIn = 0, precoOut = 0;
   long   dir = -1;
   if(!ObterPrecosOperacao(positionId, precoIn, precoOut, dir, 0, 0))
      return 0;

   return PontosPorPrecosOperacao(precoIn, precoOut, dir);
}

double CalcularPontuacaoSessao()
{
   ZerarEstatisticasSeNovoDia();
   if(GlobalVariableCheck(GV_DAY_PTS))
      return GlobalVariableGet(GV_DAY_PTS);
   return 0.0;
}

bool EstatisticasDiaPersistidas()
{
   datetime dia = DiaCalendarioAtual();
   if(!GlobalVariableCheck(GV_DAY_DATE)) return false;
   return ((datetime)GlobalVariableGet(GV_DAY_DATE) == dia);
}

void ReconstruirEstatisticasDia(bool forcar = false)
{
   if(!forcar && g_ultimaReconStats > 0 && (TimeCurrent() - g_ultimaReconStats) < 2)
      return;

   ZerarEstatisticasSeNovoDia();

   if(!SelecionarHistoricoDia())
      return;

   datetime inicio = DiaCalendarioAtual();
   ulong posIds[];
   int nPos = 0;
   double totalPts = 0;

   for(int j = 0; j < HistoryDealsTotal(); j++)
   {
      ulong d = HistoryDealGetTicket(j);
      if(d == 0 || !HistoryDealSelect(d)) continue;
      if(!DealDoSimboloAtivo(d)) continue;
      if((datetime)HistoryDealGetInteger(d, DEAL_TIME) < inicio) continue;

      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;

      ulong posId = (ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID);
      if(posId == 0) continue;
      if(PosicaoIdAindaAberta(posId)) continue;
      if(PosicaoIdNaLista(posIds, nPos, posId)) continue;

      ArrayResize(posIds, nPos + 1);
      posIds[nPos++] = posId;
      HistorySelectByPosition(posId);
      double ptsPos = PontosPosicaoHistorico(posId);
      if(MathAbs(ptsPos) < 0.01)
         ptsPos = PontosFechamentoRapido(posId, d);
      if(MathAbs(ptsPos) < 0.01)
         ptsPos = PontosPorEntradaSalva(posId, d);
      if(MathAbs(ptsPos) < 0.01)
         ptsPos = PontosPorLucroDeal(d);
      if(MathAbs(ptsPos) >= 0.01)
      {
         totalPts += ptsPos;
         GlobalVariableSet(GVStatsPosDone(posId), 1.0);
      }
      else if(GlobalVariableCheck(GVStatsPosDone(posId)))
         GlobalVariableDel(GVStatsPosDone(posId));
   }

   double ptsAtual = GlobalVariableCheck(GV_DAY_PTS) ? GlobalVariableGet(GV_DAY_PTS) : 0.0;
   int    opsAtual = GlobalVariableCheck(GV_DAY_OPS) ? (int)GlobalVariableGet(GV_DAY_OPS) : 0;

   // Rebuild vazio nao pode apagar pontuacao ja acumulada (ex.: troca de timeframe).
   if(MathAbs(totalPts) >= 0.01)
      GlobalVariableSet(GV_DAY_PTS, totalPts);
   else if(MathAbs(ptsAtual) < 0.01)
      GlobalVariableSet(GV_DAY_PTS, totalPts);

   if(nPos > 0)
      GlobalVariableSet(GV_DAY_OPS, (double)nPos);
   else if(opsAtual <= 0)
      GlobalVariableSet(GV_DAY_OPS, (double)nPos);

   GlobalVariableSet(GV_DAY_DATE, (double)DiaCalendarioAtual());

   g_ultimoOpsPainel = -1;
   g_ultimoPtsPainel = -999999.0;
   g_ultimaReconStats = TimeCurrent();
}

double PontosFechamentoRapido(ulong posId, ulong dealFechamento)
{
   if(posId == 0) return 0;

   double precoIn = 0, precoOut = 0;
   long   dir = -1;
   if(!ObterPrecosOperacao(posId, precoIn, precoOut, dir, dealFechamento, 0))
      return 0;

   return PontosPorPrecosOperacao(precoIn, precoOut, dir);
}

void RegistrarFechamentoCompleto(ulong posId, ulong dealFechamento = 0, double ptsCapturados = 0)
{
   if(posId == 0) return;

   ulong idStats = ResolverPositionId(posId);
   if(idStats == 0) idStats = posId;

   ProcessarEstatisticasFechamento(idStats, dealFechamento, 0);
   TentarContarOperacaoFechada(idStats);
   VerificarLimitePontuacao();
}

void ProcessarEstatisticasFechamento(ulong posId, ulong dealFechamento = 0, double ptsCapturados = 0)
{
   if(posId == 0) return;
   ptsCapturados = 0;

   ZerarEstatisticasSeNovoDia();

   if(GlobalVariableCheck(GVStatsPosDone(posId))) return;

   for(int w = 0; PosicaoIdAindaAberta(posId) && w < 30; w++)
      Sleep(50);

   if(PosicaoIdAindaAberta(posId) && dealFechamento == 0) return;

   ulong  deal = dealFechamento;
   double pts  = 0;
   HistorySelect(0, TimeCurrent() + 60);

   for(int tent = 0; MathAbs(pts) < 0.01 && tent < 12; tent++)
   {
      if(deal == 0)
         deal = UltimoDealFechamentoPosicao(posId);
      if(deal > 0)
         pts = PontosFechamentoRapido(posId, deal);
      if(MathAbs(pts) < 0.01)
         pts = PontosPorEntradaSalva(posId, deal);
      if(MathAbs(pts) < 0.01)
         pts = PontosPosicaoHistorico(posId);
      if(MathAbs(pts) < 0.01)
         pts = PontosPosicaoHistorico(ResolverPositionId(posId));
      if(MathAbs(pts) < 0.01 && deal > 0)
         pts = PontosPorLucroDeal(deal);
      if(MathAbs(pts) >= 0.01) break;
      if(tent < 11) Sleep(100);
   }

   if(MathAbs(pts) < 0.01)
   {
      if(InpLogDetalhado)
         Print("SP stats: pos=", posId, " aguardando historico (pts nao calculados)");
      return;
   }
   double ptsDia = (GlobalVariableCheck(GV_DAY_PTS) ? GlobalVariableGet(GV_DAY_PTS) : 0) + pts;
   int    opsDia = (GlobalVariableCheck(GV_DAY_OPS) ? (int)GlobalVariableGet(GV_DAY_OPS) : 0) + 1;

   GlobalVariableSet(GV_DAY_PTS, ptsDia);
   GlobalVariableSet(GV_DAY_OPS, (double)opsDia);
   GlobalVariableSet(GV_DAY_DATE, (double)DiaCalendarioAtual());
   GlobalVariableSet(GVStatsPosDone(posId), 1.0);

   if(InpLogDetalhado)
   {
      double precoIn = 0, precoOut = 0;
      long   dir = -1;
      ObterPrecosOperacao(posId, precoIn, precoOut, dir, deal, 0);
      Print("SP stats: pos=", posId,
            " in=", DoubleToString(precoIn, _Digits),
            " out=", DoubleToString(precoOut, _Digits),
            " pts=", DoubleToString(pts, 0),
            " tot=", DoubleToString(ptsDia, 0), " oper=", opsDia);
   }

   Central_RegistrarTrade(posId, pts);
   LimparPrecoEntradaPosicao(posId);

   IniciarExibicaoPontosOperacao(pts);
   AtualizarPontuacaoPainel();
   AtualizarPainelEstatisticas(true);
}

bool LimitePontuacaoAtingido(double &pontuacao, int &motivo)
{
   pontuacao = CalcularPontuacaoSessao();
   motivo    = LIMIT_MOTIVO_NENHUM;

   if(g_limPtsPos > 0 && pontuacao >= g_limPtsPos)
   {
      motivo = LIMIT_MOTIVO_PTS_MAX;
      return true;
   }
   if(g_limPtsNeg > 0 && pontuacao <= -g_limPtsNeg)
   {
      motivo = LIMIT_MOTIVO_PTS_MIN;
      return true;
   }

   return false;
}

int MotivoLimiteAtingidoAgora()
{
   CarregarContadorOperacoes();

   if(g_limMaxOperacoes > 0 && LimiteOperacoesAtingido())
      return LIMIT_MOTIVO_OPERACOES;

   if(FechamentoPorPontosAtivo())
   {
      double pts = CalcularPontuacaoSessao();
      int    motivoPts = LIMIT_MOTIVO_NENHUM;
      if(g_limPtsPos > 0 && pts >= g_limPtsPos)
         motivoPts = LIMIT_MOTIVO_PTS_MAX;
      else if(g_limPtsNeg > 0 && pts <= -g_limPtsNeg)
         motivoPts = LIMIT_MOTIVO_PTS_MIN;
      if(motivoPts > LIMIT_MOTIVO_NENHUM)
         return motivoPts;
   }

   return LIMIT_MOTIVO_NENHUM;
}

string MensagemBloqueioLimite(int motivo)
{
   switch(motivo)
   {
      case LIMIT_MOTIVO_OPERACOES:
         return "Limite de operacoes atingido.";
      case LIMIT_MOTIVO_PTS_MAX:
         return "Meta de pontos atingida.";
      case LIMIT_MOTIVO_PTS_MIN:
         return "Perda maxima atingida.";
   }
   return "Operacoes bloqueadas.";
}

void AplicarBloqueioLimiteDia(int motivo)
{
   if(motivo <= LIMIT_MOTIVO_NENHUM) return;

   GlobalVariableSet(GV_OPS_LOCK, 1.0);
   GlobalVariableSet(GV_OPS_LOCK_DAY, (double)DiaCalendarioAtual());
   GlobalVariableSet(GV_LIMIT_REASON, (double)motivo);

   g_limiteBloqueadoDia = true;
   MostrarQuadroMensagem(MensagemBloqueioLimite(motivo), -1);
   Status(SP_MSG_BLOQUEADO, C_STATUS_ERR, true, true);
   GravarEstadoArquivoSeguranca();
}

bool RestaurarBloqueioLimiteDia()
{
   CarregarContadorOperacoes();

   int motivo = LIMIT_MOTIVO_NENHUM;

   if(EA_EstaBloqueado())
   {
      datetime diaBloqueio = GlobalVariableCheck(GV_OPS_LOCK_DAY)
                           ? (datetime)GlobalVariableGet(GV_OPS_LOCK_DAY) : 0;
      if(diaBloqueio == DiaCalendarioAtual())
      {
         motivo = GlobalVariableCheck(GV_LIMIT_REASON)
                  ? (int)GlobalVariableGet(GV_LIMIT_REASON) : LIMIT_MOTIVO_OPERACOES;
         if(motivo <= LIMIT_MOTIVO_NENHUM)
            motivo = LIMIT_MOTIVO_OPERACOES;
      }
      else
         LimparBloqueioOperacoes(false);
   }

   if(motivo <= LIMIT_MOTIVO_NENHUM)
      motivo = MotivoLimiteAtingidoAgora();

   if(motivo <= LIMIT_MOTIVO_NENHUM)
      return false;

   AplicarBloqueioLimiteDia(motivo);
   return true;
}

//+------------------------------------------------------------------+
//| Persistencia redundante (arquivo + GV) e stats pelo historico     |
//+------------------------------------------------------------------+
string ArquivoEstadoSegurancaSP()
{
   string sym = _Symbol;
   StringReplace(sym, ".", "_");
   StringReplace(sym, ":", "_");
   StringReplace(sym, "/", "_");
   StringReplace(sym, "\\", "_");
   return StringFormat("SP_sec_%d_%s.dat", (long)AccountInfoInteger(ACCOUNT_LOGIN), sym);
}

uint ChecksumEstadoSeguranca(const long conta, const string sym, const int lockActive,
                               const datetime lockDay, const int limitReason,
                               const int limMaxOps, const double limPtsPos, const double limPtsNeg,
                               const uint pinHash, const int schedOn, const int schedHHMM,
                               const int schedDays, const datetime schedFireDay)
{
   uint h = 2166136261U ^ (uint)conta;
   h = (h ^ (uint)SP_STATE_MAGIC) * 16777619U;
   h = (h ^ (uint)SP_STATE_VERSION) * 16777619U;
   h = (h ^ (uint)StringLen(sym)) * 16777619U;
   for(int i = 0; i < StringLen(sym); i++)
      h = (h ^ (uint)StringGetCharacter(sym, i)) * 16777619U;
   h = (h ^ (uint)lockActive) * 16777619U;
   h = (h ^ (uint)lockDay) * 16777619U;
   h = (h ^ (uint)limitReason) * 16777619U;
   h = (h ^ (uint)limMaxOps) * 16777619U;
   uint ptsPosBits = (uint)MathRound(limPtsPos * 100.0);
   uint ptsNegBits = (uint)MathRound(limPtsNeg * 100.0);
   h = (h ^ ptsPosBits) * 16777619U;
   h = (h ^ ptsNegBits) * 16777619U;
   h = (h ^ pinHash) * 16777619U;
   h = (h ^ (uint)schedOn) * 16777619U;
   h = (h ^ (uint)schedHHMM) * 16777619U;
   h = (h ^ (uint)schedDays) * 16777619U;
   h = (h ^ (uint)schedFireDay) * 16777619U;
   return h;
}

bool LerEstadoArquivoSeguranca(int &lockActive, datetime &lockDay, int &limitReason,
                               int &limMaxOps, double &limPtsPos, double &limPtsNeg,
                               uint &pinHash, int &schedOn, int &schedHHMM, int &schedDays,
                               datetime &schedFireDay)
{
   lockActive = 0;
   lockDay = 0;
   limitReason = 0;
   limMaxOps = 0;
   limPtsPos = 0;
   limPtsNeg = 0;
   pinHash = 0;
   schedOn = 0;
   schedHHMM = 0;
   schedDays = 0;
   schedFireDay = 0;

   string arq = ArquivoEstadoSegurancaSP();
   if(!FileIsExist(arq, FILE_COMMON))
      return false;

   int h = FileOpen(arq, FILE_READ | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return false;

   int magic = FileReadInteger(h, INT_VALUE);
   int version = FileReadInteger(h, INT_VALUE);
   long conta = FileReadLong(h);
   string sym = FileReadString(h);
   int lockAct = FileReadInteger(h, INT_VALUE);
   datetime lockD = (datetime)FileReadLong(h);
   int limReason = FileReadInteger(h, INT_VALUE);
   int maxOps = FileReadInteger(h, INT_VALUE);
   double ptsPos = FileReadDouble(h);
   double ptsNeg = FileReadDouble(h);
   uint pin = (uint)FileReadInteger(h, INT_VALUE);
   int schOn = FileReadInteger(h, INT_VALUE);
   int schHHMM = FileReadInteger(h, INT_VALUE);
   int schDays = FileReadInteger(h, INT_VALUE);
   datetime schFire = (datetime)FileReadLong(h);
   uint chkLido = (uint)FileReadInteger(h, INT_VALUE);
   FileClose(h);

   if(magic != SP_STATE_MAGIC || version != SP_STATE_VERSION)
      return false;
   if(conta != AccountInfoInteger(ACCOUNT_LOGIN))
      return false;
   if(sym != _Symbol)
      return false;

   uint chkCalc = ChecksumEstadoSeguranca(conta, sym, lockAct, lockD, limReason,
                                            maxOps, ptsPos, ptsNeg, pin, schOn, schHHMM,
                                            schDays, schFire);
   if(chkCalc != chkLido)
      return false;

   lockActive = lockAct;
   lockDay = lockD;
   limitReason = limReason;
   limMaxOps = maxOps;
   limPtsPos = ptsPos;
   limPtsNeg = ptsNeg;
   pinHash = pin;
   schedOn = schOn;
   schedHHMM = schHHMM;
   schedDays = schDays;
   schedFireDay = schFire;
   return true;
}

void GravarEstadoArquivoSeguranca()
{
   int lockActive = (EA_EstaBloqueado() || g_limiteBloqueadoDia) ? 1 : 0;
   datetime lockDay = GlobalVariableCheck(GV_OPS_LOCK_DAY)
                    ? (datetime)GlobalVariableGet(GV_OPS_LOCK_DAY) : 0;
   int limitReason = GlobalVariableCheck(GV_LIMIT_REASON)
                   ? (int)GlobalVariableGet(GV_LIMIT_REASON) : 0;
   uint pinHash = GlobalVariableCheck(GV_PIN_HASH) ? (uint)GlobalVariableGet(GV_PIN_HASH) : 0;
   datetime schedFire = GlobalVariableCheck(GV_SCHED_FIRE)
                      ? (datetime)GlobalVariableGet(GV_SCHED_FIRE) : 0;
   int schedHHMM = g_schedHour * 100 + g_schedMin;

   long conta = AccountInfoInteger(ACCOUNT_LOGIN);
   uint chk = ChecksumEstadoSeguranca(conta, _Symbol, lockActive, lockDay, limitReason,
                                      g_limMaxOperacoes, g_limPtsPos, g_limPtsNeg, pinHash,
                                      g_schedEnabled ? 1 : 0, schedHHMM, g_schedDaysMask, schedFire);

   string arq = ArquivoEstadoSegurancaSP();
   int h = FileOpen(arq, FILE_WRITE | FILE_BIN | FILE_COMMON);
   if(h == INVALID_HANDLE)
      return;

   FileWriteInteger(h, SP_STATE_MAGIC, INT_VALUE);
   FileWriteInteger(h, SP_STATE_VERSION, INT_VALUE);
   FileWriteLong(h, conta);
   FileWriteString(h, _Symbol);
   FileWriteInteger(h, lockActive, INT_VALUE);
   FileWriteLong(h, (long)lockDay);
   FileWriteInteger(h, limitReason, INT_VALUE);
   FileWriteInteger(h, g_limMaxOperacoes, INT_VALUE);
   FileWriteDouble(h, g_limPtsPos);
   FileWriteDouble(h, g_limPtsNeg);
   FileWriteInteger(h, (int)pinHash, INT_VALUE);
   FileWriteInteger(h, g_schedEnabled ? 1 : 0, INT_VALUE);
   FileWriteInteger(h, schedHHMM, INT_VALUE);
   FileWriteInteger(h, g_schedDaysMask, INT_VALUE);
   FileWriteLong(h, (long)schedFire);
   FileWriteInteger(h, (int)chk, INT_VALUE);
   FileFlush(h);
   FileClose(h);
}

void AplicarLimitesDoArquivo(int limMaxOps, double limPtsPos, double limPtsNeg)
{
   if(limMaxOps < 0) limMaxOps = 0;
   if(limPtsPos < 0) limPtsPos = 0;
   if(limPtsNeg < 0) limPtsNeg = 0;

   g_limMaxOperacoes = limMaxOps;
   g_limPtsPos = limPtsPos;
   g_limPtsNeg = limPtsNeg;
   GlobalVariableSet(GV_LIM_MAX_OPS, (double)g_limMaxOperacoes);
   GlobalVariableSet(GV_LIM_PTS_POS, g_limPtsPos);
   GlobalVariableSet(GV_LIM_PTS_NEG, g_limPtsNeg);
}

void AplicarAgendaDoArquivo(int schedOn, int schedHHMM, int schedDays, datetime schedFireDay)
{
   g_schedEnabled = (schedOn > 0);
   g_schedHour = schedHHMM / 100;
   g_schedMin  = schedHHMM % 100;
   if(g_schedHour < 0 || g_schedHour > 23) g_schedHour = 18;
   if(g_schedMin < 0 || g_schedMin > 59) g_schedMin = 0;
   g_schedDaysMask = schedDays;
   if(g_schedDaysMask < 0) g_schedDaysMask = 0;
   if(g_schedDaysMask > 127) g_schedDaysMask = 127;

   GlobalVariableSet(GV_SCHED_ON, g_schedEnabled ? 1.0 : 0.0);
   GlobalVariableSet(GV_SCHED_HHMM, (double)(g_schedHour * 100 + g_schedMin));
   GlobalVariableSet(GV_SCHED_DAYS, (double)g_schedDaysMask);
   if(schedFireDay > 0)
      GlobalVariableSet(GV_SCHED_FIRE, (double)schedFireDay);
}

void SincronizarEstadoSeguranca()
{
   int lockActive = 0, limitReason = 0, limMaxOps = 0, schedOn = 0, schedHHMM = 0, schedDays = 0;
   datetime lockDay = 0, schedFireDay = 0;
   double limPtsPos = 0, limPtsNeg = 0;
   uint pinHash = 0;

   bool temArquivo = LerEstadoArquivoSeguranca(lockActive, lockDay, limitReason, limMaxOps,
                                               limPtsPos, limPtsNeg, pinHash, schedOn, schedHHMM,
                                               schedDays, schedFireDay);

   bool gvTemLimites = GlobalVariableCheck(GV_LIM_MAX_OPS)
                    || GlobalVariableCheck(GV_LIM_PTS_POS)
                    || GlobalVariableCheck(GV_LIM_PTS_NEG);
   bool arqTemLimites = (limMaxOps > 0 || limPtsPos > 0.0 || limPtsNeg > 0.0);

   if(temArquivo && (!gvTemLimites || arqTemLimites))
   {
      if(!gvTemLimites || arqTemLimites)
         AplicarLimitesDoArquivo(limMaxOps, limPtsPos, limPtsNeg);
   }

   if(temArquivo && pinHash != 0 && !GlobalVariableCheck(GV_PIN_HASH))
      GlobalVariableSet(GV_PIN_HASH, (double)pinHash);

   if(temArquivo && (!GlobalVariableCheck(GV_SCHED_ON) || schedOn > 0 || schedDays > 0))
      AplicarAgendaDoArquivo(schedOn, schedHHMM, schedDays, schedFireDay);

   if(temArquivo && lockActive > 0 && lockDay == DiaCalendarioAtual())
   {
      if(!GlobalVariableCheck(GV_OPS_LOCK))
      {
         GlobalVariableSet(GV_OPS_LOCK, 1.0);
         GlobalVariableSet(GV_OPS_LOCK_DAY, (double)lockDay);
         if(limitReason > LIMIT_MOTIVO_NENHUM)
            GlobalVariableSet(GV_LIMIT_REASON, (double)limitReason);
         g_limiteBloqueadoDia = true;
      }
   }

   GravarEstadoArquivoSeguranca();
}

void VerificarIntegridadeEstadoSeguranca()
{
   static datetime ultima = 0;
   datetime agora = TimeCurrent();
   if(ultima > 0 && (agora - ultima) < 3)
      return;
   ultima = agora;

   int lockActive = 0, limitReason = 0, limMaxOps = 0, schedOn = 0, schedHHMM = 0, schedDays = 0;
   datetime lockDay = 0, schedFireDay = 0;
   double limPtsPos = 0, limPtsNeg = 0;
   uint pinHash = 0;

   if(LerEstadoArquivoSeguranca(lockActive, lockDay, limitReason, limMaxOps, limPtsPos, limPtsNeg,
                                pinHash, schedOn, schedHHMM, schedDays, schedFireDay))
   {
      bool gvSemLimites = !GlobalVariableCheck(GV_LIM_MAX_OPS)
                       && !GlobalVariableCheck(GV_LIM_PTS_POS)
                       && !GlobalVariableCheck(GV_LIM_PTS_NEG);
      bool arqComLimites = (limMaxOps > 0 || limPtsPos > 0.0 || limPtsNeg > 0.0);
      if(gvSemLimites && arqComLimites)
         AplicarLimitesDoArquivo(limMaxOps, limPtsPos, limPtsNeg);

      if(pinHash != 0 && !GlobalVariableCheck(GV_PIN_HASH))
         GlobalVariableSet(GV_PIN_HASH, (double)pinHash);

      if(lockActive > 0 && lockDay == DiaCalendarioAtual() && !EA_EstaBloqueado())
      {
         int motivo = (limitReason > LIMIT_MOTIVO_NENHUM) ? limitReason : MotivoLimiteAtingidoAgora();
         if(motivo <= LIMIT_MOTIVO_NENHUM)
            motivo = LIMIT_MOTIVO_OPERACOES;
         AplicarBloqueioLimiteDia(motivo);
      }
   }

   ReconstruirEstatisticasDia(false);

   int motivoAtual = MotivoLimiteAtingidoAgora();
   if(motivoAtual > LIMIT_MOTIVO_NENHUM && !g_limiteBloqueadoDia)
      AplicarBloqueioLimiteDia(motivoAtual);
}

//+------------------------------------------------------------------+
//| Limites em runtime + popup PIN 6 digitos                          |
//+------------------------------------------------------------------+
bool PinFormatoValido(const string pin)
{
   if(StringLen(pin) != PIN_DIGITOS) return false;
   for(int i = 0; i < PIN_DIGITOS; i++)
   {
      ushort ch = (ushort)StringGetCharacter(pin, i);
      if(ch < '0' || ch > '9') return false;
   }
   return true;
}

string NormalizarPin(const string pin)
{
   string out = "";
   for(int i = 0; i < StringLen(pin) && StringLen(out) < PIN_DIGITOS; i++)
   {
      ushort ch = (ushort)StringGetCharacter(pin, i);
      if(ch >= '0' && ch <= '9')
         out += ShortToString(ch);
   }
   while(StringLen(out) < PIN_DIGITOS)
      out = "0" + out;
   if(StringLen(out) > PIN_DIGITOS)
      out = StringSubstr(out, 0, PIN_DIGITOS);
   return out;
}

uint HashPin(const string pin)
{
   string p = NormalizarPin(pin);
   if(!PinFormatoValido(p)) return 0;

   ulong h = (ulong)StringToInteger(p);
   h = h * 1315423911ULL + (ulong)AccountInfoInteger(ACCOUNT_LOGIN);
   h = h * 1315423911ULL + (ulong)StringLen(_Symbol);
   return (uint)(h ^ (h >> 32));
}

bool PinJaCadastrado()
{
   if(GlobalVariableCheck(GV_PIN_HASH))
      return true;

   int lockActive = 0, limitReason = 0, limMaxOps = 0, schedOn = 0, schedHHMM = 0, schedDays = 0;
   datetime lockDay = 0, schedFireDay = 0;
   double limPtsPos = 0, limPtsNeg = 0;
   uint pinHash = 0;
   if(LerEstadoArquivoSeguranca(lockActive, lockDay, limitReason, limMaxOps, limPtsPos, limPtsNeg,
                                pinHash, schedOn, schedHHMM, schedDays, schedFireDay) && pinHash != 0)
   {
      GlobalVariableSet(GV_PIN_HASH, (double)pinHash);
      return true;
   }
   return false;
}

void GravarPinHash(const string pin)
{
   string p = NormalizarPin(pin);
   if(!PinFormatoValido(p)) return;
   GlobalVariableSet(GV_PIN_HASH, (double)HashPin(p));
   GravarEstadoArquivoSeguranca();
}

bool ValidarPinEntrada(const string pin)
{
   if(PinBloqueadoPorTentativas())
      return false;

   if(!PinJaCadastrado())
   {
      Status(SP_MSG_PIN_CAD, clrOrange, true);
      return false;
   }

   uint esperado = (uint)GlobalVariableGet(GV_PIN_HASH);
   uint informado = HashPin(pin);
   if(informado == 0 || informado != esperado)
   {
      RegistrarFalhaPin();
      return false;
   }

   g_pinFalhas = 0;
   g_pinBloqueadoAte = 0;
   return true;
}

bool PinBloqueadoPorTentativas()
{
   if(g_pinBloqueadoAte <= 0) return false;
   if(TimeCurrent() >= g_pinBloqueadoAte)
   {
      g_pinBloqueadoAte = 0;
      g_pinFalhas = 0;
      return false;
   }
   return true;
}

void RegistrarFalhaPin()
{
   g_pinFalhas++;
   if(g_pinFalhas >= PIN_MAX_FALHAS)
   {
      g_pinBloqueadoAte = TimeCurrent() + PIN_COOLDOWN_SEG;
      g_pinFalhas = 0;
      Status(SP_MSG_PIN_BLOQ, C_STATUS_WARN, true);
   }
   else
      Status(SP_MSG_PIN_ERR, C_STATUS_ERR, true);
}

void InicializarLimitesEfetivos()
{
   if(GlobalVariableCheck(GV_LIM_MAX_OPS))
      g_limMaxOperacoes = (int)GlobalVariableGet(GV_LIM_MAX_OPS);
   else
      g_limMaxOperacoes = 0;

   if(GlobalVariableCheck(GV_LIM_PTS_POS))
      g_limPtsPos = GlobalVariableGet(GV_LIM_PTS_POS);
   else
      g_limPtsPos = 0;

   if(GlobalVariableCheck(GV_LIM_PTS_NEG))
      g_limPtsNeg = GlobalVariableGet(GV_LIM_PTS_NEG);
   else
      g_limPtsNeg = 0;

   if(g_limMaxOperacoes < 0) g_limMaxOperacoes = 0;
   if(g_limPtsPos < 0) g_limPtsPos = 0;
   if(g_limPtsNeg < 0) g_limPtsNeg = 0;

   SalvarLimitesEfetivos();
}

void SalvarLimitesEfetivos()
{
   GlobalVariableSet(GV_LIM_MAX_OPS, (double)g_limMaxOperacoes);
   GlobalVariableSet(GV_LIM_PTS_POS, g_limPtsPos);
   GlobalVariableSet(GV_LIM_PTS_NEG, g_limPtsNeg);
   GravarEstadoArquivoSeguranca();
}

//+------------------------------------------------------------------+
//| Fechamento programado (hora local do PC + dias da semana)         |
//+------------------------------------------------------------------+
datetime DiaCalendarioLocal()
{
   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);
   dt.hour = 0;
   dt.min  = 0;
   dt.sec  = 0;
   return StructToTime(dt);
}

string FormatarHorarioHHMM(int hora, int minuto)
{
   if(hora < 0) hora = 0;
   if(hora > 23) hora = 23;
   if(minuto < 0) minuto = 0;
   if(minuto > 59) minuto = 59;
   return StringFormat("%02d:%02d", hora, minuto);
}

bool ParseHorarioHHMM(const string texto, int &hora, int &minuto)
{
   hora = 0;
   minuto = 0;
   string t = texto;
   StringReplace(t, " ", "");
   StringReplace(t, ".", ":");
   StringReplace(t, "-", ":");

   string partes[];
   int n = StringSplit(t, ':', partes);
   if(n < 1) return false;

   hora = (int)StringToInteger(partes[0]);
   if(n >= 2)
      minuto = (int)StringToInteger(partes[1]);

   if(hora < 0 || hora > 23 || minuto < 0 || minuto > 59)
      return false;

   return true;
}

void InicializarAgendaFechamento()
{
   g_schedEnabled = false;
   g_schedHour = 18;
   g_schedMin = 0;
   g_schedDaysMask = 0x7F;

   if(GlobalVariableCheck(GV_SCHED_ON))
      g_schedEnabled = (GlobalVariableGet(GV_SCHED_ON) > 0.5);

   if(GlobalVariableCheck(GV_SCHED_HHMM))
   {
      int packed = (int)GlobalVariableGet(GV_SCHED_HHMM);
      g_schedHour = packed / 100;
      g_schedMin  = packed % 100;
      if(g_schedHour < 0 || g_schedHour > 23) g_schedHour = 18;
      if(g_schedMin < 0 || g_schedMin > 59) g_schedMin = 0;
   }

   if(GlobalVariableCheck(GV_SCHED_DAYS))
   {
      g_schedDaysMask = (int)GlobalVariableGet(GV_SCHED_DAYS);
      if(g_schedDaysMask < 0) g_schedDaysMask = 0;
      if(g_schedDaysMask > 127) g_schedDaysMask = 127;
   }
}

void SalvarAgendaFechamento()
{
   GlobalVariableSet(GV_SCHED_ON, g_schedEnabled ? 1.0 : 0.0);
   GlobalVariableSet(GV_SCHED_HHMM, (double)(g_schedHour * 100 + g_schedMin));
   GlobalVariableSet(GV_SCHED_DAYS, (double)g_schedDaysMask);
   GravarEstadoArquivoSeguranca();
}

void LerAgendaCamposPopup()
{
   if(ObjectFind(0, SPL_EDIT_SCHED_HHMM) >= 0)
   {
      string hhmm = ObjectGetString(0, SPL_EDIT_SCHED_HHMM, OBJPROP_TEXT);
      int h = g_schedHour, m = g_schedMin;
      if(ParseHorarioHHMM(hhmm, h, m))
      {
         g_schedHour = h;
         g_schedMin = m;
      }
   }
}

string NomeBotaoDiaPopup(int dow)
{
   return SPL_BTN_DOW_PFX + IntegerToString(dow);
}

void AtualizarBotoesDiasPopup()
{
   const string nomes[7] = {"DOM","SEG","TER","QUA","QUI","SEX","SAB"};

   for(int d = 0; d < 7; d++)
   {
      string nome = NomeBotaoDiaPopup(d);
      if(ObjectFind(0, nome) < 0) continue;

      bool ativo = ((g_schedDaysMask & (1 << d)) != 0);
      ObjectSetString(0, nome, OBJPROP_TEXT, nomes[d]);
      ObjectSetInteger(0, nome, OBJPROP_BGCOLOR, ativo ? C_ACCENT_COLOR : C_BTN_BG);
      ObjectSetInteger(0, nome, OBJPROP_COLOR, ativo ? clrWhite : C_BTN_TEXT);
      ObjectSetInteger(0, nome, OBJPROP_STATE, false);
   }
}

void AtualizarBotaoSchedOnPopup()
{
   if(ObjectFind(0, SPL_BTN_SCHED_ON) < 0) return;

   ObjectSetString(0, SPL_BTN_SCHED_ON, OBJPROP_TEXT, g_schedEnabled ? "ON" : "OFF");
   ObjectSetInteger(0, SPL_BTN_SCHED_ON, OBJPROP_BGCOLOR, g_schedEnabled ? C_ACCENT_COLOR : C_BTN_BG);
   ObjectSetInteger(0, SPL_BTN_SCHED_ON, OBJPROP_COLOR, g_schedEnabled ? clrWhite : C_BTN_TEXT);
   ObjectSetInteger(0, SPL_BTN_SCHED_ON, OBJPROP_STATE, false);
}

void MontarAgendaNoPopup(int bx, int by, int lx, int ex, int ew, int &y)
{
   y += 12;
   CriarLabelPopup("SPL_LBL_SCHED", lx, y, "Fechar MT5 (hora PC)", 8);
   y += 26;

   CriarBotaoPopup(SPL_BTN_SCHED_ON, lx, y - 2, 40, 22, g_schedEnabled ? "ON" : "OFF");
   AtualizarBotaoSchedOnPopup();
   CriarEditPopup(SPL_EDIT_SCHED_HHMM, ex, y - 2, FormatarHorarioHHMM(g_schedHour, g_schedMin), 56, 22);
   y += 34;

   int dw = 32, dg = 2;
   for(int d = 0; d < 7; d++)
      CriarBotaoPopup(NomeBotaoDiaPopup(d), lx + d * (dw + dg), y, dw, 18, " ");
   AtualizarBotoesDiasPopup();
   y += 32;
}

bool EhCliqueAgendaPopup(const string sparam)
{
   if(!g_popupLimitesAberto || g_popupView != SPL_VIEW_LIMITES)
      return false;

   if(sparam == SPL_BTN_SCHED_ON || StringFind(sparam, SPL_BTN_SCHED_ON + "_") == 0)
   {
      g_schedEnabled = !g_schedEnabled;
      AtualizarBotaoSchedOnPopup();
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw(0);
      return true;
   }

   if(StringFind(sparam, SPL_BTN_DOW_PFX) == 0)
   {
      int dow = (int)StringToInteger(StringSubstr(sparam, StringLen(SPL_BTN_DOW_PFX)));
      if(dow >= 0 && dow <= 6)
      {
         int bit = (1 << dow);
         if((g_schedDaysMask & bit) != 0)
            g_schedDaysMask &= ~bit;
         else
            g_schedDaysMask |= bit;
         AtualizarBotoesDiasPopup();
      }
      ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
      ChartRedraw(0);
      return true;
   }

   return false;
}

void VerificarFechamentoHorario()
{
   if(!g_schedEnabled || g_fechamentoAgendado)
      return;

   if(g_schedDaysMask == 0)
      return;

   MqlDateTime dt;
   TimeToStruct(TimeLocal(), dt);

   if((g_schedDaysMask & (1 << dt.day_of_week)) == 0)
      return;

   if(dt.hour != g_schedHour || dt.min != g_schedMin)
      return;

   datetime diaLocal = DiaCalendarioLocal();
   if(GlobalVariableCheck(GV_SCHED_FIRE))
   {
      datetime ultimo = (datetime)GlobalVariableGet(GV_SCHED_FIRE);
      if(ultimo == diaLocal)
         return;
   }

   GlobalVariableSet(GV_SCHED_FIRE, (double)diaLocal);

   string msg = "Horario programado atingido.\nO MT5 sera fechado.";
   IniciarFechamentoMT5(msg, false);
   if(InpLogDetalhado)
      PrintFormat("SP fechamento programado %02d:%02d dow=%d", g_schedHour, g_schedMin, dt.day_of_week);
}

void SanitizarEditPin(const string nomeEdit)
{
   if(ObjectFind(0, nomeEdit) < 0) return;
   string t = ObjectGetString(0, nomeEdit, OBJPROP_TEXT);
   string out = "";
   for(int i = 0; i < StringLen(t) && StringLen(out) < PIN_DIGITOS; i++)
   {
      ushort ch = (ushort)StringGetCharacter(t, i);
      if(ch >= '0' && ch <= '9')
         out += ShortToString(ch);
   }
   if(out != t)
      ObjectSetString(0, nomeEdit, OBJPROP_TEXT, out);
}

bool EhObjetoPopupLimites(const string name)
{
   return (StringFind(name, SPL_PREFIX) == 0);
}

void FecharPopupLimites()
{
   ObjectsDeleteAll(0, SPL_PREFIX);
   g_popupLimitesAberto = false;
   g_popupView = SPL_VIEW_LIMITES;
   g_popupPinCadastro = false;
   ChartRedraw(0);
}

void CriarLabelPopup(string name, int x, int y, string text, int fs = 8)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_LABEL_BRIGHT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fs);
   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 210);
}

void CriarEditPopup(string name, int x, int y, string text, int w, int h)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C_INPUT_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_INPUT_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_INPUT_BORDER);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_CENTER);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 211);
}

void CriarBotaoPopup(string name, int x, int y, int w, int h, string text)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C_BTN_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_BTN_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_BTN_BORDER);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 212);
}

void CriarFundoPopupLimites(int bx, int by, int bw, int bh)
{
   if(ObjectCreate(0, SPL_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, SPL_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, SPL_BG, OBJPROP_XDISTANCE, bx);
      ObjectSetInteger(0, SPL_BG, OBJPROP_YDISTANCE, by);
      ObjectSetInteger(0, SPL_BG, OBJPROP_XSIZE, bw);
      ObjectSetInteger(0, SPL_BG, OBJPROP_YSIZE, bh);
      ObjectSetInteger(0, SPL_BG, OBJPROP_BGCOLOR, C_HEADER_COLOR);
      ObjectSetInteger(0, SPL_BG, OBJPROP_BORDER_COLOR, C_ACCENT_COLOR);
      ObjectSetInteger(0, SPL_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
      ObjectSetString(0, SPL_BG, OBJPROP_TEXT, " ");
      ObjectSetInteger(0, SPL_BG, OBJPROP_ZORDER, 208);
   }
}

void AbrirPopupPin(bool cadastro)
{
   if(g_fechamentoAgendado) return;

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(cw < 200) cw = 800;
   if(ch < 150) ch = 600;

   int bw = 270, bh = cadastro ? 220 : 248;
   int bx = (cw - bw) / 2;
   int by = (ch - bh) / 2;
   int lx = bx + 14;
   int ex = lx + 118;
   int ew = bw - 14 - 118 - 14;

   FecharPopupLimites();
   g_popupView = SPL_VIEW_PIN;
   g_popupPinCadastro = cadastro;
   g_popupLimitesAberto = true;

   CriarFundoPopupLimites(bx, by, bw, bh);
   string titulo = cadastro ? "CADASTRAR PIN" : "TROCAR PIN";
   CriarLabelPopup(SPL_TITLE, bx + 14, by + 10, titulo, 9);

   int y = by + 36;
   if(!cadastro)
   {
      CriarLabelPopup("SPL_LBL_PIN_ATUAL", lx, y, "PIN atual", 8);
      CriarEditPopup(SPL_EDIT_PIN_ATUAL, ex, y - 2, "", ew, 22);
      y += 30;
   }

   CriarLabelPopup("SPL_LBL_PIN_NOVO", lx, y, "PIN novo", 8);
   CriarEditPopup(SPL_EDIT_PIN_NOVO, ex, y - 2, "", ew, 22);
   y += 30;
   CriarLabelPopup("SPL_LBL_PIN_CONF", lx, y, "Confirmar PIN", 8);
   CriarEditPopup(SPL_EDIT_PIN_CONF, ex, y - 2, "", ew, 22);
   y += 38;

   int btnW = 78, gap = 10;
   int btnX = bx + (bw - btnW * 2 - gap) / 2;
   CriarBotaoPopup(SPL_BTN_PIN_SALVAR, btnX, y, btnW, 24, "Salvar");
   CriarBotaoPopup(SPL_BTN_VOLTAR, btnX + btnW + gap, y, btnW, 24, "Voltar");

   ChartRedraw(0);
}

void AbrirPopupLimites()
{
   if(g_fechamentoAgendado) return;
   if(g_popupLimitesAberto && g_popupView == SPL_VIEW_LIMITES)
   {
      FecharPopupLimites();
      return;
   }

   if(!PinJaCadastrado())
   {
      AbrirPopupPin(true);
      return;
   }

   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(cw < 200) cw = 800;
   if(ch < 150) ch = 600;

   int bw = 270, bh = 455;
   int bx = (cw - bw) / 2;
   int by = (ch - bh) / 2;
   int lx = bx + 14;
   int ex = lx + 118;
   int ew = bw - 14 - 118 - 14;
   const int SPL_ROW_GAP = 36;

   FecharPopupLimites();
   g_popupView = SPL_VIEW_LIMITES;
   g_popupLimitesAberto = true;

   CriarFundoPopupLimites(bx, by, bw, bh);
   CriarLabelPopup(SPL_TITLE, bx + 14, by + 10, "LIMITES DO DIA", 9);

   int y = by + 36;
   CriarLabelPopup("SPL_LBL_OPS", lx, y, "Max operacoes", 8);
   CriarEditPopup(SPL_EDIT_OPS, ex, y - 2, IntegerToString(g_limMaxOperacoes), ew, 22);
   y += SPL_ROW_GAP;
   CriarLabelPopup("SPL_LBL_POS", lx, y, "Meta + (pts)", 8);
   CriarEditPopup(SPL_EDIT_POS, ex, y - 2, DoubleToString(g_limPtsPos, 0), ew, 22);
   y += SPL_ROW_GAP;
   CriarLabelPopup("SPL_LBL_NEG", lx, y, "Meta - (pts)", 8);
   CriarEditPopup(SPL_EDIT_NEG, ex, y - 2, DoubleToString(g_limPtsNeg, 0), ew, 22);
   y += SPL_ROW_GAP;
   MontarAgendaNoPopup(bx, by, lx, ex, ew, y);
   y += 10;
   CriarLabelPopup("SPL_LBL_PIN", lx, y, "PIN (6 digitos)", 8);
   CriarEditPopup(SPL_EDIT_PIN, ex, y - 2, "", ew, 22);
   y += 48;

   int btnW = 78, gap = 10;
   int btnX = bx + (bw - btnW * 2 - gap) / 2;
   CriarBotaoPopup(SPL_BTN_OK, btnX, y, btnW, 24, "OK");
   CriarBotaoPopup(SPL_BTN_CANCEL, btnX + btnW + gap, y, btnW, 24, "Cancelar");
   y += 30;
   CriarBotaoPopup(SPL_BTN_TROCAR_PIN, bx + 14, y, bw - 28, 22, "Trocar PIN");

   ChartRedraw(0);
}

void DesbloquearOperacoesAposLimites()
{
   if(EA_EstaBloqueado() || g_limiteBloqueadoDia)
      LimparBloqueioOperacoes(false);
}

void ConfirmarPopupLimites()
{
   if(PinBloqueadoPorTentativas())
   {
      Status(SP_MSG_PIN_BLOQ, C_STATUS_WARN, true);
      return;
   }

   if(!PinJaCadastrado())
   {
      Status(SP_MSG_PIN_CAD, clrOrange, true);
      AbrirPopupPin(true);
      return;
   }

   string pin = "";
   if(ObjectFind(0, SPL_EDIT_PIN) >= 0)
      pin = ObjectGetString(0, SPL_EDIT_PIN, OBJPROP_TEXT);
   pin = NormalizarPin(pin);

   if(!ValidarPinEntrada(pin))
      return;

   int opsAnt = g_limMaxOperacoes;
   double posAnt = g_limPtsPos, negAnt = g_limPtsNeg;

   int ops = opsAnt;
   double pos = posAnt, neg = negAnt;
   if(ObjectFind(0, SPL_EDIT_OPS) >= 0)
      ops = (int)StringToInteger(ObjectGetString(0, SPL_EDIT_OPS, OBJPROP_TEXT));
   if(ObjectFind(0, SPL_EDIT_POS) >= 0)
      pos = StringToDouble(ObjectGetString(0, SPL_EDIT_POS, OBJPROP_TEXT));
   if(ObjectFind(0, SPL_EDIT_NEG) >= 0)
      neg = StringToDouble(ObjectGetString(0, SPL_EDIT_NEG, OBJPROP_TEXT));

   if(ops < 0) ops = 0;
   if(pos < 0) pos = 0;
   if(neg < 0) neg = 0;

   g_limMaxOperacoes = ops;
   g_limPtsPos = pos;
   g_limPtsNeg = neg;
   SalvarLimitesEfetivos();

   if(g_schedEnabled && ObjectFind(0, SPL_EDIT_SCHED_HHMM) >= 0)
   {
      string hhmm = ObjectGetString(0, SPL_EDIT_SCHED_HHMM, OBJPROP_TEXT);
      int h = 0, m = 0;
      if(!ParseHorarioHHMM(hhmm, h, m))
      {
         Status(SP_MSG_HORARIO, C_STATUS_ERR, true);
         return;
      }
      g_schedHour = h;
      g_schedMin = m;
   }
   else
      LerAgendaCamposPopup();

   if(g_schedEnabled && g_schedDaysMask == 0)
   {
      Status(SP_MSG_DIAS, C_STATUS_WARN, true);
      return;
   }

   SalvarAgendaFechamento();

   DesbloquearOperacoesAposLimites();

   g_ultimoOpsPainel = -1;
   AtualizarPainelEstatisticas(true);

   FecharPopupLimites();

   int motivo = MotivoLimiteAtingidoAgora();
   if(motivo > LIMIT_MOTIVO_NENHUM)
   {
      Status(SP_MSG_LIM_BLOQ, C_STATUS_WARN, true);
      return;
   }

   StatusComAutoReset(SP_MSG_LIM_OK, C_STATUS_OK, true);
   if(InpLogDetalhado)
      PrintFormat("SP limites alterados: ops %d->%d pos %.0f->%.0f neg %.0f->%.0f",
                  opsAnt, ops, posAnt, pos, negAnt, neg);
}

void SalvarPopupPin()
{
   if(PinBloqueadoPorTentativas())
   {
      Status(SP_MSG_PIN_BLOQ, C_STATUS_WARN, true);
      return;
   }

   string pinNovo = "";
   string pinConf = "";
   if(ObjectFind(0, SPL_EDIT_PIN_NOVO) >= 0)
      pinNovo = ObjectGetString(0, SPL_EDIT_PIN_NOVO, OBJPROP_TEXT);
   if(ObjectFind(0, SPL_EDIT_PIN_CONF) >= 0)
      pinConf = ObjectGetString(0, SPL_EDIT_PIN_CONF, OBJPROP_TEXT);

   pinNovo = NormalizarPin(pinNovo);
   pinConf = NormalizarPin(pinConf);

   if(!PinFormatoValido(pinNovo))
   {
      Status(SP_MSG_PIN_6, C_STATUS_ERR, true);
      return;
   }
   if(pinNovo != pinConf)
   {
      Status(SP_MSG_PIN_DIFF, C_STATUS_ERR, true);
      return;
   }

   if(!g_popupPinCadastro)
   {
      string pinAtual = "";
      if(ObjectFind(0, SPL_EDIT_PIN_ATUAL) >= 0)
         pinAtual = ObjectGetString(0, SPL_EDIT_PIN_ATUAL, OBJPROP_TEXT);
      pinAtual = NormalizarPin(pinAtual);

      if(!ValidarPinEntrada(pinAtual))
         return;
   }

   GravarPinHash(pinNovo);
   g_pinFalhas = 0;
   g_pinBloqueadoAte = 0;

   StatusComAutoReset(SP_MSG_PIN_OK, C_STATUS_OK, true);
   AbrirPopupLimites();
}

bool ResolverCliquePopupLimites(const string sparam, string &acao)
{
   acao = "";
   if(!EhObjetoPopupLimites(sparam)) return false;

   if(sparam == SPL_BTN_OK || StringFind(sparam, SPL_BTN_OK + "_") == 0)
      acao = "ok";
   else if(sparam == SPL_BTN_CANCEL || StringFind(sparam, SPL_BTN_CANCEL + "_") == 0)
      acao = "cancel";
   else if(sparam == SPL_BTN_TROCAR_PIN || StringFind(sparam, SPL_BTN_TROCAR_PIN + "_") == 0)
      acao = "trocar_pin";
   else if(sparam == SPL_BTN_PIN_SALVAR || StringFind(sparam, SPL_BTN_PIN_SALVAR + "_") == 0)
      acao = "pin_salvar";
   else if(sparam == SPL_BTN_VOLTAR || StringFind(sparam, SPL_BTN_VOLTAR + "_") == 0)
      acao = "voltar";
   else
      return false;

   return true;
}

bool EhObjetoDecorativoPainel(const string name)
{
   if(StringFind(name, "_SPF") > 0 || StringFind(name, "_SPL") > 0
      || StringFind(name, "_SPU") > 0 || StringFind(name, "_SPD") > 0)
      return true;
   if(name == OBJ_BORDER || name == OBJ_BG || name == OBJ_HEADER || name == OBJ_HEADER_LINE)
      return true;
   if(name == OBJ_STATUS_STRIP || name == OBJ_METRICS_BG || name == OBJ_COPY_STRIP)
      return true;
   if(StringFind(name, "SP_MET_DIV") == 0)
      return true;
   if(name == "SP_D1" || name == "SP_D3")
      return true;
   return false;
}

void BloquearPainelUI(bool bloquear)
{
   g_painelBloqueado = bloquear;
   if(bloquear)
      CancelarEdicaoCampoAtiva();
   int n = ObjectsTotal(0, 0, -1);

   for(int i = 0; i < n; i++)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "SP_") != 0) continue;
      if(StringFind(name, "SPM_") == 0) continue;
      if(StringFind(name, SPL_PREFIX) == 0) continue;
      if(StringFind(name, "SP_PCT_SFX_") == 0) continue;

      long tipo = ObjectGetInteger(0, name, OBJPROP_TYPE);

      if(EhObjetoDecorativoPainel(name) || tipo == OBJ_LABEL)
      {
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
         continue;
      }

      if((tipo == OBJ_EDIT || tipo == OBJ_BUTTON) && EhCampoEditavelPainel(name))
      {
         ConfigurarCampoEditavel(name);
         continue;
      }

      if(tipo == OBJ_BUTTON && EhBotaoPainelSP(name))
      {
         ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !bloquear);
         AplicarEstiloBotao(name, false);
      }
   }

   AtualizarEstadoLimitesUI();
   ChartRedraw(0);
}


//+------------------------------------------------------------------+
//| Quadro mensagem (OBJ_LABEL nao suporta \\n — uma linha por objeto)|
//+------------------------------------------------------------------+
void RemoverLinhasQuadroMensagem()
{
   ObjectDelete(0, OBJ_MSG_OVERLAY_TXT);
   ObjectsDeleteAll(0, OBJ_MSG_OVERLAY_LINHA, 0, OBJ_LABEL);
}

void CriarFundoQuadroMensagem(int bx, int by, int bw, int bh)
{
   ObjectDelete(0, OBJ_MSG_OVERLAY_BG);
   if(!ObjectCreate(0, OBJ_MSG_OVERLAY_BG, OBJ_RECTANGLE_LABEL, 0, 0, 0))
      return;

   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_XDISTANCE, bx);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_YDISTANCE, by);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_XSIZE, bw);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_YSIZE, bh);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_BGCOLOR, C_HEADER_COLOR);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_BORDER_COLOR, C_STATUS_ERR);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   // Texto vazio exibe "Label" no MT5 — usar espaco com cor igual ao fundo
   ObjectSetString(0, OBJ_MSG_OVERLAY_BG, OBJPROP_TEXT, " ");
   ObjectSetString(0, OBJ_MSG_OVERLAY_BG, OBJPROP_FONT, UI_FONT);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_FONTSIZE, 1);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_COLOR, C_HEADER_COLOR);
   ObjectSetString(0, OBJ_MSG_OVERLAY_BG, OBJPROP_TOOLTIP, " ");
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_HIDDEN, true);
   ObjectSetInteger(0, OBJ_MSG_OVERLAY_BG, OBJPROP_ZORDER, 200);
}

void ObterLayoutQuadroMensagem(int cw, int ch, int &bx, int &by, int &bw, int &bh)
{
   int margem = 40;
   bw = (InpMsgBoxLargura > 0) ? InpMsgBoxLargura : 620;
   bh = (InpMsgBoxAltura > 0) ? InpMsgBoxAltura : 200;
   bw = MathMin(bw, MathMax(120, cw - margem));
   bh = MathMin(bh, MathMax(80, ch - margem));

   bx = (InpMsgBoxPosX < 0) ? (cw - bw) / 2 : InpMsgBoxPosX;
   by = (InpMsgBoxPosY < 0) ? (ch - bh) / 2 : InpMsgBoxPosY;

   if(bx < 0) bx = 0;
   if(by < 0) by = 0;
   if(bx + bw > cw) bx = MathMax(0, cw - bw);
   if(by + bh > ch) by = MathMax(0, ch - bh);
}

void MostrarQuadroMensagem(const string msg, int segundosRestantes)
{
   int cw = (int)ChartGetInteger(0, CHART_WIDTH_IN_PIXELS);
   int ch = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
   if(cw < 200) cw = 800;
   if(ch < 150) ch = 600;

   int bw = 0, bh = 0, bx = 0, by = 0;
   ObterLayoutQuadroMensagem(cw, ch, bx, by, bw, bh);

   int cx = bx + bw / 2;
   int fonteMsg = (InpMsgBoxFonte > 0) ? InpMsgBoxFonte : 10;

   RemoverLinhasQuadroMensagem();
   ObjectDelete(0, OBJ_MSG_OVERLAY_CNT);
   CriarFundoQuadroMensagem(bx, by, bw, bh);

   string texto = msg;
   StringReplace(texto, "\r\n", "\n");
   StringReplace(texto, "\r", "\n");

   string linhas[];
   int nLinhas = StringSplit(texto, '\n', linhas);
   if(nLinhas <= 0)
   {
      ArrayResize(linhas, 1);
      linhas[0] = texto;
      nLinhas = 1;
   }

   int linhasVisiveis = 0;
   for(int i = 0; i < nLinhas && i < MSG_OVERLAY_MAX_LINHAS; i++)
   {
      string linha = linhas[i];
      StringTrimLeft(linha);
      StringTrimRight(linha);
      if(StringLen(linha) == 0) continue;

      string nome = OBJ_MSG_OVERLAY_LINHA + IntegerToString(linhasVisiveis);
      ObjectDelete(0, nome);
      if(!ObjectCreate(0, nome, OBJ_LABEL, 0, 0, 0))
         continue;

      ObjectSetString(0, nome, OBJPROP_TEXT, linha);
      ObjectSetInteger(0, nome, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, nome, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, nome, OBJPROP_XDISTANCE, cx);
      ObjectSetInteger(0, nome, OBJPROP_COLOR, C_NOME_COLOR);
      ObjectSetInteger(0, nome, OBJPROP_FONTSIZE, fonteMsg);
      ObjectSetString(0, nome, OBJPROP_FONT, UI_FONT_BOLD);
      ObjectSetString(0, nome, OBJPROP_TOOLTIP, " ");
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, nome, OBJPROP_ZORDER, 201);
      linhasVisiveis++;
   }

   const int alturaLinha = 20;
   int areaTopo = by + 28;
   int areaBase = by + bh - (segundosRestantes >= 0 ? 44 : 28);
   int blocoH  = linhasVisiveis * alturaLinha;
   int ty0     = areaTopo + MathMax(0, (areaBase - areaTopo - blocoH) / 2);

   for(int i = 0; i < linhasVisiveis; i++)
   {
      string nome = OBJ_MSG_OVERLAY_LINHA + IntegerToString(i);
      ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, ty0 + i * alturaLinha);
   }

   if(segundosRestantes >= 0 && ObjectCreate(0, OBJ_MSG_OVERLAY_CNT, OBJ_LABEL, 0, 0, 0))
   {
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_ANCHOR, ANCHOR_CENTER);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_XDISTANCE, cx);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_YDISTANCE, by + bh - 36);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_COLOR, C_STATUS_WARN);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_FONTSIZE, 9);
      ObjectSetString(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_FONT, UI_FONT);
      ObjectSetString(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_TOOLTIP, " ");
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_HIDDEN, true);
      ObjectSetInteger(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_ZORDER, 201);
   }

   AtualizarQuadroMensagem(segundosRestantes);
   ChartRedraw(0);
}

void AtualizarQuadroMensagem(int segundosRestantes)
{
   if(ObjectFind(0, OBJ_MSG_OVERLAY_CNT) < 0) return;

   if(segundosRestantes < 0)
      return;

   if(ObjectFind(0, OBJ_MSG_OVERLAY_CNT) < 0)
      return;

   ObjectSetString(0, OBJ_MSG_OVERLAY_CNT, OBJPROP_TEXT,
                   StringFormat("Fechando em %ds...", segundosRestantes));
}

void RemoverQuadroMensagem()
{
   ObjectDelete(0, OBJ_MSG_OVERLAY_BG);
   RemoverLinhasQuadroMensagem();
   ObjectDelete(0, OBJ_MSG_OVERLAY_CNT);
}

void IniciarFechamentoMT5(const string msg, const bool registrarBloqueioOperacoes)
{
   if(g_fechamentoAgendado) return;

   string texto = msg;
   if(StringLen(texto) == 0)
      texto = "Fechando sistema.";

   if(registrarBloqueioOperacoes)
      AplicarBloqueioLimiteDia(LIMIT_MOTIVO_OPERACOES);

   int delay = DelayFechamentoSegundos();
   g_fechamentoAgendado = true;
   g_fechamentoHora     = TimeCurrent() + delay;

   BloquearPainelUI(true);
   MostrarQuadroMensagem(texto, delay);
   Status(SP_MSG_FECHANDO, C_STATUS_ERR, true, true);
}

void ProcessarFechamentoAgendado()
{
   if(!g_fechamentoAgendado) return;

   int rest = (int)(g_fechamentoHora - TimeCurrent());
   AtualizarQuadroMensagem(rest);

   if(TimeCurrent() < g_fechamentoHora) return;

   g_fechamentoAgendado = false;
   ExpertRemove();
   TerminalClose(0);
}

void VerificarLimitePontuacao()
{
   if(g_fechamentoAgendado || g_limiteBloqueadoDia) return;
   if(!FechamentoPorPontosAtivo()) return;

   double pts = 0;
   int    motivo = LIMIT_MOTIVO_NENHUM;
   if(!LimitePontuacaoAtingido(pts, motivo)) return;

   AplicarBloqueioLimiteDia(motivo);

   string msg = InpMsgFecharPontos;
   if(StringLen(msg) == 0)
      msg = "Meta de pontos atingida.";

   IniciarFechamentoMT5(msg, false);
}

void BloquearPorLimite()
{
   AplicarBloqueioLimiteDia(LIMIT_MOTIVO_OPERACOES);

   string msg = InpMsgFecharOper;
   if(StringLen(msg) == 0)
      msg = "Limite de operacoes atingido.";

   IniciarFechamentoMT5(msg, false);
}

bool VerificarDesbloqueio()
{
   if(!EA_EstaBloqueado())
      return true;

   datetime diaBloqueio = GlobalVariableCheck(GV_OPS_LOCK_DAY)
                        ? (datetime)GlobalVariableGet(GV_OPS_LOCK_DAY) : 0;
   datetime diaAtual    = DiaCalendarioAtual();

   if(diaBloqueio > 0 && diaAtual > diaBloqueio)
   {
      LimparBloqueioOperacoes(true);
      return true;
   }

   return true;
}

bool TrailDinamicoAtivo()
{
   return (g_modoTrail == TRAIL_DINAMICO);
}

double DistanciaTrailDinamico()
{
   return TrailingStart - TrailingStep;
}

void ToggleModoTrail()
{
   if(g_campoEditAtivo != "")
      FinalizarEdicaoCampo(true);
   AtualizarCampos();

   if(g_modoTrail == TRAIL_FIXO)
   {
      if(TrailingStart <= TrailingStep || DistanciaTrailDinamico() <= 0)
      {
         Status(SP_MSG_TRAIL_DIST, C_STATUS_ERR, true);
         return;
      }
      g_modoTrail = TRAIL_DINAMICO;
   }
   else
      g_modoTrail = TRAIL_FIXO;

   GlobalVariableSet(GvCfgKey("TRAIL_MODO"), (double)g_modoTrail);
   AplicarEstiloRotuloParametro("SP_TR");
   ReconciliarLinhasTrailing();
   Status(TrailDinamicoAtivo() ? SP_MSG_TRAIL_DIN : SP_MSG_TRAIL_FIXO,
          TrailDinamicoAtivo() ? C_STATUS_OK : C_STATUS_WARN, true);
   ChartRedraw(0);
}

bool SetupVolatilAtivo()
{
   return (g_setupAtivo == PERFIL_VOLATIL);
}

string NomeSetupAtivo()
{
   return SetupVolatilAtivo() ? "VOLATIL" : "NORMAL";
}

void AplicarValoresPerfil(double lote, double tp, double sl, double trail, double step)
{
   Lote            = NormalizeVolPainel(lote);
   if(Lote <= 0)
      Lote = NormalizeVolPainel(0.01);
   StopLoss        = MathMax(0, sl);
   TakeProfit      = MathMax(0, tp);
   TrailingStart   = MathMax(0, trail);
   TrailingStep    = MathMax(0, step);
}

string GvCfgKey(const string sufixo)
{
   return "SP_CFG_" + _Symbol + "_" + sufixo;
}

string PrefixoConfigPainelPerfil(const int perfil)
{
   return (perfil == PERFIL_VOLATIL) ? "V" : "N";
}

bool ConfigPainelSalvaExiste(const int perfil)
{
   return GlobalVariableCheck(GvCfgKey(PrefixoConfigPainelPerfil(perfil) + "_LOTE"));
}

string GvInpSnapKey(const int perfil, const string campo)
{
   return GvCfgKey(PrefixoConfigPainelPerfil(perfil) + "_ISNAP_" + campo);
}

bool SnapInputDiferente(const string key, const double valor)
{
   if(!GlobalVariableCheck(key)) return true;
   return (MathAbs(GlobalVariableGet(key) - valor) > 0.000000001);
}

bool InputsPerfilAlterados(const int perfil)
{
   if(perfil == PERFIL_VOLATIL)
   {
      if(SnapInputDiferente(GvInpSnapKey(perfil, "LOTE"), InpVol_Lote)) return true;
      if(SnapInputDiferente(GvInpSnapKey(perfil, "TP"), InpVol_TakeProfit)) return true;
      if(SnapInputDiferente(GvInpSnapKey(perfil, "SL"), InpVol_StopLoss)) return true;
      if(SnapInputDiferente(GvInpSnapKey(perfil, "TR"), InpVol_TrailingStart)) return true;
      if(SnapInputDiferente(GvInpSnapKey(perfil, "ST"), InpVol_TrailingStep)) return true;
      return false;
   }

   if(SnapInputDiferente(GvInpSnapKey(perfil, "LOTE"), InpNorm_Lote)) return true;
   if(SnapInputDiferente(GvInpSnapKey(perfil, "TP"), InpNorm_TakeProfit)) return true;
   if(SnapInputDiferente(GvInpSnapKey(perfil, "SL"), InpNorm_StopLoss)) return true;
   if(SnapInputDiferente(GvInpSnapKey(perfil, "TR"), InpNorm_TrailingStart)) return true;
   if(SnapInputDiferente(GvInpSnapKey(perfil, "ST"), InpNorm_TrailingStep)) return true;
   return false;
}

void GravarSnapshotInputsPerfil(const int perfil)
{
   if(perfil == PERFIL_VOLATIL)
   {
      GlobalVariableSet(GvInpSnapKey(perfil, "LOTE"), InpVol_Lote);
      GlobalVariableSet(GvInpSnapKey(perfil, "TP"), InpVol_TakeProfit);
      GlobalVariableSet(GvInpSnapKey(perfil, "SL"), InpVol_StopLoss);
      GlobalVariableSet(GvInpSnapKey(perfil, "TR"), InpVol_TrailingStart);
      GlobalVariableSet(GvInpSnapKey(perfil, "ST"), InpVol_TrailingStep);
      return;
   }

   GlobalVariableSet(GvInpSnapKey(perfil, "LOTE"), InpNorm_Lote);
   GlobalVariableSet(GvInpSnapKey(perfil, "TP"), InpNorm_TakeProfit);
   GlobalVariableSet(GvInpSnapKey(perfil, "SL"), InpNorm_StopLoss);
   GlobalVariableSet(GvInpSnapKey(perfil, "TR"), InpNorm_TrailingStart);
   GlobalVariableSet(GvInpSnapKey(perfil, "ST"), InpNorm_TrailingStep);
}

void AplicarValoresInputPerfil(const int perfil)
{
   if(perfil == PERFIL_VOLATIL)
      AplicarValoresPerfil(InpVol_Lote, InpVol_TakeProfit, InpVol_StopLoss,
                           InpVol_TrailingStart, InpVol_TrailingStep);
   else
      AplicarValoresPerfil(InpNorm_Lote, InpNorm_TakeProfit, InpNorm_StopLoss,
                           InpNorm_TrailingStart, InpNorm_TrailingStep);
}

bool ConfigPainelValida(const int perfil)
{
   if(!ConfigPainelSalvaExiste(perfil)) return false;

   string p = PrefixoConfigPainelPerfil(perfil);
   double lote = GlobalVariableGet(GvCfgKey(p + "_LOTE"));
   return (NormalizeVolPainel(lote) > 0);
}

void SalvarValoresPerfilNoGV(const int perfil, const double lote, const double tp, const double sl,
                             const double tr, const double st)
{
   string p = PrefixoConfigPainelPerfil(perfil);
   GlobalVariableSet(GvCfgKey(p + "_LOTE"), lote);
   GlobalVariableSet(GvCfgKey(p + "_TP"), tp);
   GlobalVariableSet(GvCfgKey(p + "_SL"), sl);
   GlobalVariableSet(GvCfgKey(p + "_TR"), tr);
   GlobalVariableSet(GvCfgKey(p + "_ST"), st);
}

void PersistirInputsPerfilNoGV(const int perfil)
{
   double lote = 0, tp = 0, sl = 0, tr = 0, st = 0;

   if(perfil == PERFIL_VOLATIL)
   {
      lote = InpVol_Lote;
      tp   = InpVol_TakeProfit;
      sl   = InpVol_StopLoss;
      tr   = InpVol_TrailingStart;
      st   = InpVol_TrailingStep;
   }
   else
   {
      lote = InpNorm_Lote;
      tp   = InpNorm_TakeProfit;
      sl   = InpNorm_StopLoss;
      tr   = InpNorm_TrailingStart;
      st   = InpNorm_TrailingStep;
   }

   lote = NormalizeVolPainel(lote);
   if(lote <= 0)
      lote = NormalizeVolPainel(0.01);
   tp   = MathMax(0, tp);
   sl   = MathMax(0, sl);
   tr   = MathMax(0, tr);
   st   = MathMax(0, st);

   SalvarValoresPerfilNoGV(perfil, lote, tp, sl, tr, st);
}

void SincronizarPerfisComInputs()
{
   for(int perfil = PERFIL_NORMAL; perfil <= PERFIL_VOLATIL; perfil++)
   {
      if(!ConfigPainelSalvaExiste(perfil) || !ConfigPainelValida(perfil) || InputsPerfilAlterados(perfil))
         PersistirInputsPerfilNoGV(perfil);
      GravarSnapshotInputsPerfil(perfil);
   }
}

void SalvarConfigPainelPerfil(const int perfil)
{
   if(perfil != PERFIL_NORMAL && perfil != PERFIL_VOLATIL) return;

   if(ObjectFind(0, OBJ_EDIT_LOTE) >= 0)
      AtualizarCampos();

   string p = PrefixoConfigPainelPerfil(perfil);
   double loteSalvar = Lote;
   if(loteSalvar <= 0 && GlobalVariableCheck(GvCfgKey(p + "_LOTE")))
      loteSalvar = GlobalVariableGet(GvCfgKey(p + "_LOTE"));
   if(loteSalvar <= 0)
   {
      if(perfil == PERFIL_VOLATIL)
         loteSalvar = NormalizeVolPainel(InpVol_Lote);
      else
         loteSalvar = NormalizeVolPainel(InpNorm_Lote);
   }
   GlobalVariableSet(GvCfgKey(p + "_LOTE"), loteSalvar);
   GlobalVariableSet(GvCfgKey(p + "_TP"), TakeProfit);
   GlobalVariableSet(GvCfgKey(p + "_SL"), StopLoss);
   GlobalVariableSet(GvCfgKey(p + "_TR"), TrailingStart);
   GlobalVariableSet(GvCfgKey(p + "_ST"), TrailingStep);
   GlobalVariableSet(GvCfgKey("SETUP"), (double)g_setupAtivo);
   GlobalVariableSet(GvCfgKey("TRAIL_MODO"), (double)g_modoTrail);
   SalvarConfigParciais();
}

void CarregarConfigPainelPerfil(const int perfil)
{
   if(perfil != PERFIL_NORMAL && perfil != PERFIL_VOLATIL) return;

   bool usarInputs = !ConfigPainelSalvaExiste(perfil) || !ConfigPainelValida(perfil) || InputsPerfilAlterados(perfil);

   if(usarInputs)
   {
      AplicarValoresInputPerfil(perfil);
      return;
   }

   string p = PrefixoConfigPainelPerfil(perfil);
   double cfgLote = GlobalVariableGet(GvCfgKey(p + "_LOTE"));
   double cfgTp   = GlobalVariableGet(GvCfgKey(p + "_TP"));
   double cfgSl   = GlobalVariableGet(GvCfgKey(p + "_SL"));
   double cfgTr   = GlobalVariableGet(GvCfgKey(p + "_TR"));
   double cfgSt   = GlobalVariableGet(GvCfgKey(p + "_ST"));
   AplicarValoresPerfil(cfgLote, cfgTp, cfgSl, cfgTr, cfgSt);
}

void CarregarPerfilAtivo()
{
   CarregarConfigPainelPerfil(g_setupAtivo);
}

void AplicarPerfilAoPainel()
{
   EscreverValorCampoEdit(OBJ_EDIT_LOTE);
   EscreverValorCampoEdit(OBJ_EDIT_TP);
   EscreverValorCampoEdit(OBJ_EDIT_SL);
   EscreverValorCampoEdit(OBJ_EDIT_TRAIL_START);
   EscreverValorCampoEdit(OBJ_EDIT_TRAIL_STEP);
   AplicarEstiloRotuloParametro("SP_TR");
   AtualizarBotaoSetup();
}

void AtualizarBotaoSetup()
{
   AtualizarSegmentoPerfil();
   if(ObjectFind(0, OBJ_BTN_SETUP) < 0) return;

   AplicarEstiloBotaoAux(OBJ_BTN_SETUP, false);
   ObjectSetString(0, OBJ_BTN_SETUP, OBJPROP_TOOLTIP,
                   SetupVolatilAtivo() ? "Perfil VOLATIL (clique p/ NORMAL)"
                                       : "Perfil NORMAL (clique p/ VOLATIL)");
}

void AlternarPerfilSetup()
{
   SalvarConfigPainelPerfil(g_setupAtivo);
   g_setupAtivo = SetupVolatilAtivo() ? PERFIL_NORMAL : PERFIL_VOLATIL;
   CarregarPerfilAtivo();
   AplicarPerfilAoPainel();
   ReconciliarLinhasTrailing();
   AtualizarRotulosSLTP();
   if(TemPosicaoNoSimbolo())
      ProcessarNiveisManuaisGrafico();
   Status(NomeSetupAtivo(), SetupVolatilAtivo() ? C_SETUP_VOL_BG : C_STATUS_OK, true);
   ChartRedraw(0);
}

void RegistrarOperacaoAberta(ulong ticketOuPosId, string origem)
{
   if(ticketOuPosId == 0 || origem == "") return;

   ulong posId = ResolverPositionId(ticketOuPosId);
   GlobalVariableSet(GVOpOpen(posId), 1.0);
   GlobalVariableSet(GVOpOrigin(posId), (StringCompare(origem, "PENDENTE") == 0) ? 2.0 : 1.0);
   SalvarPrecoEntradaPosicao(ticketOuPosId);

   ulong tkt = ticketOuPosId;
   if(!PositionSelectByTicket(tkt) && posId > 0)
   {
      for(int i = 0; i < PositionsTotal(); i++)
      {
         ulong t = PositionGetTicket(i);
         if(t == 0 || !PositionSelectByTicket(t)) continue;
         if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId)
         {
            tkt = t;
            break;
         }
      }
   }
   if(tkt > 0)
   {
      if(GlobalVariableCheck(GVSlRStep(tkt))) GlobalVariableDel(GVSlRStep(tkt));
      if(GlobalVariableCheck(GVSlRBar(tkt)))  GlobalVariableDel(GVSlRBar(tkt));
      InicializarReferenciasNiveis(tkt);
   }
}

void TentarContarOperacaoFechada(ulong ticketOuPosId)
{
   if(ticketOuPosId == 0) return;

   ulong posId = ResolverPositionId(ticketOuPosId);
   if(PosicaoIdAindaAberta(posId)) return;
   if(GlobalVariableCheck(GVOpDone(posId))) return;

   GlobalVariableSet(GVOpDone(posId), 1.0);

   string origem = "MARKET";
   if(GlobalVariableCheck(GVOpOrigin(posId)))
      origem = ((int)GlobalVariableGet(GVOpOrigin(posId)) == 2) ? "PENDENTE" : "MARKET";

   GlobalVariableDel(GVOpOpen(posId));
   GlobalVariableDel(GVOpOrigin(posId));

   IncrementarContadorLimiteOperacoes();
   AtualizarPainelEstatisticas(true);
   RegistrarNovaOperacao();
}

void RegistrarNovaOperacao()
{
   Status(SP_MSG_FECHADO, C_ACCENT_COLOR, true);
   if(g_limMaxOperacoes > 0 && LimiteOperacoesAtingido())
      BloquearPorLimite();
}

void ReconciliarOperacoesAbertas()
{
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ulong posId = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(!GlobalVariableCheck(GVOpOpen(posId)))
         RegistrarOperacaoAberta(t, "MARKET");
      else if(!GlobalVariableCheck(GVSlManualRef(t)) || !GlobalVariableCheck(GVTPManualRef(t)))
         InicializarReferenciasNiveis(t);
   }
}

bool PodeOperarRapido()
{
   if(g_fechamentoAgendado || g_limiteBloqueadoDia || g_painelBloqueado)
      return false;
   if(Central_BloqueiaNovas())
      return false;

   if(g_limMaxOperacoes <= 0 && g_limPtsPos <= 0 && g_limPtsNeg <= 0)
      return true;

   static ulong s_limiteSeq = 0;
   static bool  s_limiteOk  = true;
   if(g_onTickSeq != s_limiteSeq)
   {
      s_limiteSeq = g_onTickSeq;
      int motivo = MotivoLimiteAtingidoAgora();
      s_limiteOk = (motivo <= LIMIT_MOTIVO_NENHUM);
      if(!s_limiteOk)
         AplicarBloqueioLimiteDia(motivo);
   }
   return s_limiteOk;
}

int MotivoTradeBloqueado()
{
   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) return 1;
   if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) return 2;
   if(!AccountInfoInteger(ACCOUNT_TRADE_ALLOWED)) return 3;

   long modo = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_MODE);
   if(modo == SYMBOL_TRADE_MODE_DISABLED) return 4;
   if(modo == SYMBOL_TRADE_MODE_CLOSEONLY) return 5;

   return 0;
}

string TextoMotivoTradeBloqueado(const int motivo)
{
   if(motivo == 1) return SP_MSG_AUTO_TRADE;
   if(motivo == 2) return SP_MSG_EA_TRADE;
   if(motivo == 3) return SP_MSG_CONTA_TRADE;
   if(motivo == 4 || motivo == 5) return SP_MSG_SYM_TRADE;
   return "";
}

bool TradingPermitido()
{
   return (MotivoTradeBloqueado() == 0);
}

void AgendarFalhaTrade(const string msgPadrao)
{
   int motTrade = MotivoTradeBloqueado();
   if(motTrade > 0)
   {
      Status(TextoMotivoTradeBloqueado(motTrade), C_STATUS_WARN, true, true);
      return;
   }

   static datetime s_ultAvisoTrade = 0;
   if(TimeCurrent() - s_ultAvisoTrade < 2) return;
   s_ultAvisoTrade = TimeCurrent();
   AgendarStatus(msgPadrao, clrRed, true, true);
}

//+------------------------------------------------------------------+
double LotStep()
{
   double s = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
     return (s > 0) ? s : 0.01;
}

double NormalizeVol(double vol)
{
   double step   = LotStep();
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(vol <= VOL_EPSILON) return 0;
   if(maxLot > 0 && vol > maxLot) vol = maxLot;

   vol = MathFloor(vol / step + 1e-10) * step;
   int digits = 0;
   double tmp = step;
   while(tmp < 0.9999 && digits < 8) { tmp *= 10; digits++; }
   vol = NormalizeDouble(vol, digits);

   return (vol < minLot - VOL_EPSILON) ? 0 : vol;
}

double NormalizeVolPainel(double vol)
{
   if(vol <= 0) return 0;

   double step = LotStep();
   if(step <= 0) step = 0.01;

   vol = MathFloor(vol / step + 1e-10) * step;
   int digits = 0;
   double tmp = step;
   while(tmp < 0.9999 && digits < 8) { tmp *= 10; digits++; }
   return NormalizeDouble(vol, digits);
}

void ConfigurarTrade()
{
   trade.SetExpertMagicNumber(0);
   trade.SetDeviationInPoints(50);
   trade.SetAsyncMode(false);

   ENUM_ORDER_TYPE_FILLING fill = ORDER_FILLING_RETURN;
   long fm = (long)SymbolInfoInteger(_Symbol, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) fill = ORDER_FILLING_IOC;
   else if((fm & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) fill = ORDER_FILLING_FOK;
   trade.SetTypeFilling(fill);
}

ENUM_ORDER_TYPE_FILLING ObterFilling(const string sym)
{
   long fm = SymbolInfoInteger(sym, SYMBOL_FILLING_MODE);
   if((fm & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC) return ORDER_FILLING_IOC;
   if((fm & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK) return ORDER_FILLING_FOK;
   return ORDER_FILLING_RETURN;
}

string GVTrailFixo(ulong posTkt)     { return GV_PREFIX + "TF_" + IntegerToString(posTkt); }
string GVEntradaPronta(ulong posId)  { return GV_PREFIX + "EP_" + IntegerToString(posId); }
string GVSlRStep(ulong posTkt)       { return GV_PREFIX + "SR_" + IntegerToString(posTkt); }
string GVSlRBar(ulong posTkt)        { return GV_PREFIX + "SRB_" + IntegerToString(posTkt); }

//+------------------------------------------------------------------+
//| Parciais                                                         |
//+------------------------------------------------------------------+
double LucroPontosPosicao(ulong posTkt)
{
   if(!PositionSelectByTicket(posTkt)) return 0;

   long   tipo = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double pt   = ObterPontoPreco();
   if(pt <= 0) return 0;

   GarantirCacheCotacao();
   double lucro = 0;

   if(tipo == POSITION_TYPE_BUY)
   {
      lucro = (g_tickBid - open) / pt;
      if(MQLInfoInteger(MQL_TESTER))
      {
         double h = iHigh(_Symbol, PERIOD_CURRENT, 0);
         lucro = MathMax(lucro, (h - open) / pt);
      }
   }
   else
   {
      lucro = (open - g_tickAsk) / pt;
      if(MQLInfoInteger(MQL_TESTER))
      {
         double l = iLow(_Symbol, PERIOD_CURRENT, 0);
         lucro = MathMax(lucro, (open - l) / pt);
      }
   }
   return lucro;
}

void RegistrarVolumeInicial(ulong posTkt)
{
   if(PositionSelectByTicket(posTkt))
   {
      GravarTicketPosicao(posTkt);
      SalvarPrecoEntradaPosicao(posTkt);
      if(ParciaisNaPosicao(posTkt) && PositionSelectByTicket(posTkt))
      {
         double volIni = PositionGetDouble(POSITION_VOLUME);
         ResetStatusParciais();
         InicializarPlanoParciais(posTkt, volIni);
      }
   }
}

void LimparGVs(ulong posTkt)
{
   ulong posIdEp = PosIdDaPosicao(posTkt);
   if(posIdEp > 0 && GlobalVariableCheck(GVEntradaPronta(posIdEp)))
      GlobalVariableDel(GVEntradaPronta(posIdEp));

   RemoverLinhaTrailing(posTkt);
   if(GlobalVariableCheck(GVTrailFixo(posTkt))) GlobalVariableDel(GVTrailFixo(posTkt));
   if(GlobalVariableCheck(GVSlRStep(posTkt))) GlobalVariableDel(GVSlRStep(posTkt));
   if(GlobalVariableCheck(GVSlRBar(posTkt)))  GlobalVariableDel(GVSlRBar(posTkt));
   if(GlobalVariableCheck(GVSlManualRef(posTkt))) GlobalVariableDel(GVSlManualRef(posTkt));
   if(GlobalVariableCheck(GVTPManualRef(posTkt))) GlobalVariableDel(GVTPManualRef(posTkt));
   RemoverRotulosSLTP(posTkt);
   LimparGVsParciais(posTkt);
}

void GerenciarTPVirtual(ulong posTkt)
{
   if(!InpTPVirtual || TakeProfit <= 0) return;
   if(posTkt == 0) posTkt = TicketPosicaoSimbolo();
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;

   double lucroPts = LucroPontosPosicao(posTkt);
   if(lucroPts < TakeProfit) return;
   if(ParcialPendenteNoNivelTP(posTkt, lucroPts)) return;   // a parcial do mesmo nivel sai primeiro

   trade.PositionClose(posTkt);
}

bool AplicarTPBrokerSeAusente(const ulong posTkt)
{
   if(InpTPVirtual || TakeProfit <= 0) return false;
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return false;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return false;
   if(PositionGetDouble(POSITION_TP) > 0) return false;

   long   tipo  = PositionGetInteger(POSITION_TYPE);
   bool   compra = (tipo == POSITION_TYPE_BUY);
   double open  = PositionGetDouble(POSITION_PRICE_OPEN);
   double sl    = PositionGetDouble(POSITION_SL);
   double slIgn = 0, tp = 0;

   if(!CalcularSLTPPorPontos(compra, open, slIgn, tp) || tp <= 0)
      return false;

   ValidarSLTPBroker(compra, sl, tp);
   return ModificarNiveisPosicaoEA(posTkt, sl, tp);
}

//+------------------------------------------------------------------+
//| Trailing FIXO / DINAMICO + linha no grafico (criada na entrada)  |
//+------------------------------------------------------------------+
ulong PosIdDaPosicao(ulong posTkt)
{
   if(posTkt == 0) return 0;
   if(PositionSelectByTicket(posTkt))
   {
      ulong id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      return (id > 0) ? id : posTkt;
   }
   return posTkt;
}

string NomeLinhaTrail(ulong posTkt)
{
   return "SP_TRAIL_" + IntegerToString(PosIdDaPosicao(posTkt));
}

ulong TicketPosicaoPorId(ulong posId)
{
   if(posId == 0) return 0;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId || t == posId)
         return t;
   }
   return 0;
}

bool TrailLinhaDeveSerExibida(ulong posTkt)
{
   if(GlobalVariableCheck(GVSlP2(posTkt))) return false;   // apos P2 o SL ja esta no nivel do P1
   if(!TrailDinamicoAtivo() && GlobalVariableCheck(GVTrailFixo(posTkt))) return false;
   return true;
}

double PrecoLinhaTrailing(ulong posTkt, bool &linhaNoSL)
{
   linhaNoSL = false;
   if(TrailingStart <= 0 || TrailingStep <= 0 || !PositionSelectByTicket(posTkt)) return 0;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return 0;

   long   tipo = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double pt   = ObterPontoPreco();

   if(TrailDinamicoAtivo())
   {
      double dist = DistanciaTrailDinamico();
      if(dist <= 0) return 0;

      double lucroPts = LucroPontosPosicao(posTkt);
      if(lucroPts >= TrailingStart)
      {
         double slAtual = PositionGetDouble(POSITION_SL);
         if(slAtual > 0)
         {
            linhaNoSL = true;
            return NormalizeDouble(slAtual, _Digits);
         }
         GarantirCacheCotacao();
         if(tipo == POSITION_TYPE_BUY)
            return NormalizeDouble(g_tickBid - dist * pt, _Digits);
         if(tipo == POSITION_TYPE_SELL)
            return NormalizeDouble(g_tickAsk + dist * pt, _Digits);
         return 0;
      }
   }

   if(tipo == POSITION_TYPE_BUY)
      return NormalizeDouble(open + TrailingStart * pt, _Digits);
   if(tipo == POSITION_TYPE_SELL)
      return NormalizeDouble(open - TrailingStart * pt, _Digits);
   return 0;
}

void RemoverObjetosTrailChave(ulong chave)
{
   if(chave == 0) return;
   long chartId = ChartID();
   string nome = "SP_TRAIL_" + IntegerToString(chave);
   if(ObjectFind(chartId, nome) >= 0)
      ObjectDelete(chartId, nome);

   string legStart = "SP_TRAIL_START_" + IntegerToString(chave);
   string legStep  = "SP_TRAIL_STEP_" + IntegerToString(chave);
   if(ObjectFind(chartId, legStart) >= 0) ObjectDelete(chartId, legStart);
   if(ObjectFind(chartId, legStep) >= 0)  ObjectDelete(chartId, legStep);
}

void RemoverLinhaTrailing(ulong posTkt)
{
   if(posTkt == 0) return;
   ulong posId = PosIdDaPosicao(posTkt);
   RemoverObjetosTrailChave(posId);
   if(posId != posTkt)
      RemoverObjetosTrailChave(posTkt);
}

void AtualizarLinhaTrailing(ulong posTkt)
{
   if(TrailingStart <= 0 || TrailingStep <= 0 || !TrailLinhaDeveSerExibida(posTkt))
   {
      RemoverLinhaTrailing(posTkt);
      return;
   }

   if(TrailDinamicoAtivo() && DistanciaTrailDinamico() <= 0)
   {
      RemoverLinhaTrailing(posTkt);
      return;
   }

   bool linhaNoSL = false;
   double preco = PrecoLinhaTrailing(posTkt, linhaNoSL);
   if(preco <= 0) return;

   long chartId = ChartID();
   string nome = NomeLinhaTrail(posTkt);
   string legenda;
   if(TrailDinamicoAtivo() && linhaNoSL)
      legenda = StringFormat("Trail din (%d)", (int)DistanciaTrailDinamico());
   else if(TrailDinamicoAtivo())
      legenda = StringFormat("Trail start (%d)", (int)TrailingStart);
   else
      legenda = StringFormat("Trail start (%d)", (int)TrailingStart);

   if(ObjectFind(chartId, nome) < 0)
   {
      if(!ObjectCreate(chartId, nome, OBJ_HLINE, 0, 0, preco))
      {
         if(InpLogDetalhado)
            Print("SP trail: falha criar linha ticket=", posTkt, " err=", GetLastError());
         return;
      }
      ObjectSetInteger(chartId, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, nome, OBJPROP_BACK, true);
      ObjectSetInteger(chartId, nome, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(chartId, nome, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   // cor e estilo sempre atualizados (linhas criadas por versoes anteriores)
   ObjectSetInteger(chartId, nome, OBJPROP_COLOR, C_TRAIL_LINHA);
   ObjectSetInteger(chartId, nome, OBJPROP_STYLE, STYLE_SOLID);

   bool existe = (ObjectFind(chartId, nome) >= 0);
   if(existe)
   {
      double precoObj = ObjectGetDouble(chartId, nome, OBJPROP_PRICE);
      string legObj   = ObjectGetString(chartId, nome, OBJPROP_TEXT);
      double tolPt    = ObterPontoPreco() * 0.5;
      if(MathAbs(precoObj - preco) <= tolPt && legObj == legenda)
         return;
   }

   ObjectSetDouble(chartId, nome, OBJPROP_PRICE, preco);
   ObjectSetInteger(chartId, nome, OBJPROP_COLOR, C_TRAIL_LINHA);
   ObjectSetInteger(chartId, nome, OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(chartId, nome, OBJPROP_WIDTH, C_TRAIL_LARGURA);
   ObjectSetString(chartId, nome, OBJPROP_TEXT, legenda);
   ObjectSetString(chartId, nome, OBJPROP_TOOLTIP, legenda);
}

void CriarLinhaTrailingNaEntrada(ulong posTkt)
{
   AtualizarLinhaTrailing(posTkt);
}

string NomeRotuloSLPts(ulong posTkt) { return "SP_SLPTS_" + IntegerToString(posTkt); }
string NomeRotuloTPPts(ulong posTkt) { return "SP_TPPTS_" + IntegerToString(posTkt); }

double PrecoTPExibicao(ulong posTkt)
{
   if(!PositionSelectByTicket(posTkt)) return 0;

   double tpRef = 0;
   if(GlobalVariableCheck(GVTPManualRef(posTkt)))
      tpRef = NormalizeDouble(GlobalVariableGet(GVTPManualRef(posTkt)), _Digits);

   if(!InpTPVirtual && tpRef > 0)
      return tpRef;

   double tp = PositionGetDouble(POSITION_TP);
   if(tp > 0) return tp;

   if(!InpTPVirtual || TakeProfit <= 0) return 0;

   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   long   tipo = PositionGetInteger(POSITION_TYPE);
   double pt   = ObterPontoPreco();
   if(tipo == POSITION_TYPE_BUY)
      return NormalizeDouble(open + TakeProfit * pt, _Digits);
   return NormalizeDouble(open - TakeProfit * pt, _Digits);
}

string NomeLinhaSLPos(ulong posTkt) { return "SP_POS_SL_" + IntegerToString(posTkt); }
string NomeLinhaTPPos(ulong posTkt) { return "SP_POS_TP_" + IntegerToString(posTkt); }

void AtualizarLinhasNiveisPosicao(ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   double sl = PositionGetDouble(POSITION_SL);
   if(GlobalVariableCheck(GVSlManualRef(posTkt)))
   {
      double slRef = NormalizeDouble(GlobalVariableGet(GVSlManualRef(posTkt)), _Digits);
      if(slRef > 0) sl = slRef;
   }

   double tp = PrecoTPExibicao(posTkt);
   double tpReal = PositionGetDouble(POSITION_TP);
   string legTp = (InpTPVirtual && tpReal <= 0) ? "TPv" : "TP";

   DefinirLinhaPreview(NomeLinhaSLPos(posTkt), sl, C_STATUS_ERR, "SL", STYLE_SOLID);
   DefinirLinhaPreview(NomeLinhaTPPos(posTkt), tp, C_TP_LINHA, legTp, STYLE_SOLID);
}

void RemoverLinhasNiveisPosicao(ulong posTkt)
{
   if(posTkt == 0) return;
   ObjectDelete(0, NomeLinhaSLPos(posTkt));
   ObjectDelete(0, NomeLinhaTPPos(posTkt));
}

void ColetarPosicoesAbertasSimbolo(ulong &openTickets[], ulong &openIds[], int &nOpen)
{
   nOpen = 0;
   ArrayResize(openTickets, 0);
   ArrayResize(openIds, 0);

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      ulong id = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(id == 0) id = t;

      ArrayResize(openTickets, nOpen + 1);
      ArrayResize(openIds, nOpen + 1);
      openTickets[nOpen] = t;
      openIds[nOpen] = id;
      nOpen++;
   }
}

void ReconciliarLinhasNiveisPosicao()
{
   ulong openTickets[];
   ulong openIds[];
   int   nOpen = 0;
   ColetarPosicoesAbertasSimbolo(openTickets, openIds, nOpen);

   long chartId = ChartID();
   const string prefixes[2] = {"SP_POS_SL_", "SP_POS_TP_"};
   for(int p = 0; p < 2; p++)
   {
      string prefix = prefixes[p];
      for(int i = ObjectsTotal(chartId, -1, -1) - 1; i >= 0; i--)
      {
         string nome = ObjectName(chartId, i, -1, -1);
         if(StringFind(nome, prefix) != 0) continue;

         ulong tkt = (ulong)StringToInteger(StringSubstr(nome, StringLen(prefix)));
         if(!PosicaoIdNaLista(openTickets, nOpen, tkt) && !PosicaoIdNaLista(openIds, nOpen, tkt))
            ObjectDelete(chartId, nome);
      }
   }
}

void LimparGraficoPosicaoFechada(const ulong posId, const ulong posTktHint, const ulong posTktTrans)
{
   ulong chaves[3];
   int   nChaves = 0;

   if(posTktHint > 0) { chaves[nChaves++] = posTktHint; }
   if(posId > 0 && !PosicaoIdNaLista(chaves, nChaves, posId))
      chaves[nChaves++] = posId;
   if(posTktTrans > 0 && !PosicaoIdNaLista(chaves, nChaves, posTktTrans))
      chaves[nChaves++] = posTktTrans;

   for(int i = 0; i < nChaves; i++)
   {
      RemoverLinhaTrailing(chaves[i]);
      RemoverRotulosSLTP(chaves[i]);
   }

   ReconciliarLinhasNiveisPosicao();
}

int PontosEntradaAtePreco(ulong posTkt, double preco)
{
   if(preco <= 0 || !PositionSelectByTicket(posTkt)) return 0;
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double pt   = ObterPontoPreco();
   if(pt <= 0) return 0;
   return (int)MathRound(MathAbs(preco - open) / pt);
}

void PosicionarRotuloDireita(long chartId, const string name, double preco,
                             const string texto, color cor)
{
   if(preco <= 0 || texto == "")
   {
      if(ObjectFind(chartId, name) >= 0) ObjectDelete(chartId, name);
      return;
   }

   int cw = (int)ChartGetInteger(chartId, CHART_WIDTH_IN_PIXELS);
   if(cw < 40) cw = 800;

   datetime t = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(t == 0) t = TimeCurrent();

   int xPix = 0, yPix = 0;
   if(!ChartTimePriceToXY(chartId, 0, t, preco, xPix, yPix))
      return;

   int xDist = cw - SP_ROTULO_LARGURA - SP_ROTULO_MARGEM;
   if(xDist < 0) xDist = 0;
   int yDist = yPix - 8;
   if(yDist < 0) yDist = 0;

   if(ObjectFind(chartId, name) >= 0)
   {
      int xOld = (int)ObjectGetInteger(chartId, name, OBJPROP_XDISTANCE);
      int yOld = (int)ObjectGetInteger(chartId, name, OBJPROP_YDISTANCE);
      if(xOld == xDist && MathAbs(yOld - yDist) <= 1
         && ObjectGetString(chartId, name, OBJPROP_TEXT) == texto
         && (color)ObjectGetInteger(chartId, name, OBJPROP_COLOR) == cor)
         return;
   }

   if(ObjectFind(chartId, name) < 0)
   {
      ObjectCreate(chartId, name, OBJ_LABEL, 0, 0, 0);
      ObjectSetInteger(chartId, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
      ObjectSetInteger(chartId, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
      ObjectSetInteger(chartId, name, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(chartId, name, OBJPROP_BACK, false);
      ObjectSetInteger(chartId, name, OBJPROP_HIDDEN, true);
      ObjectSetInteger(chartId, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   ObjectSetInteger(chartId, name, OBJPROP_XDISTANCE, xDist);
   ObjectSetInteger(chartId, name, OBJPROP_YDISTANCE, yDist);
   ObjectSetInteger(chartId, name, OBJPROP_COLOR, cor);
   ObjectSetInteger(chartId, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(chartId, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetString(chartId, name, OBJPROP_TEXT, texto);
}

void RemoverRotulosSLTP(ulong posTkt)
{
   if(posTkt == 0) return;
   long chartId = ChartID();
   string sl = NomeRotuloSLPts(posTkt);
   string tp = NomeRotuloTPPts(posTkt);
   if(ObjectFind(chartId, sl) >= 0) ObjectDelete(chartId, sl);
   if(ObjectFind(chartId, tp) >= 0) ObjectDelete(chartId, tp);
   RemoverLinhasNiveisPosicao(posTkt);
}

void AtualizarRotulosSLTPPosicao(ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   long   chartId = ChartID();
   double sl      = PositionGetDouble(POSITION_SL);
   double tp      = PrecoTPExibicao(posTkt);
   double tpReal  = PositionGetDouble(POSITION_TP);

   if(sl > 0)
   {
      int pts = PontosEntradaAtePreco(posTkt, sl);
      PosicionarRotuloDireita(chartId, NomeRotuloSLPts(posTkt), sl,
                              StringFormat("SL %d pts", pts), C_STATUS_ERR);
   }
   else
   {
      string n = NomeRotuloSLPts(posTkt);
      if(ObjectFind(chartId, n) >= 0) ObjectDelete(chartId, n);
   }

   if(tp > 0)
   {
      int pts = PontosEntradaAtePreco(posTkt, tp);
      string lbl = (InpTPVirtual && tpReal <= 0)
                     ? StringFormat("TPv %d pts", pts)
                     : StringFormat("TP %d pts", pts);
      PosicionarRotuloDireita(chartId, NomeRotuloTPPts(posTkt), tp, lbl, C_STATUS_OK);
   }
   else
   {
      string n = NomeRotuloTPPts(posTkt);
      if(ObjectFind(chartId, n) >= 0) ObjectDelete(chartId, n);
   }

   AtualizarLinhasNiveisPosicao(posTkt);
}

void AgendarRotulosSLTPPosicao(const ulong posTkt)
{
   if(posTkt == 0) return;
   g_rotulosPendenteTkt = posTkt;
   g_rotulosPendenteNoTick = g_onTickSeq + 1;
}

void ProcessarRotulosSLTPAgendados()
{
   if(g_rotulosPendenteTkt == 0) return;
   if(g_onTickSeq < g_rotulosPendenteNoTick) return;

   ulong t = g_rotulosPendenteTkt;
   g_rotulosPendenteTkt = 0;
   g_rotulosPendenteNoTick = 0;

   if(PositionSelectByTicket(t) && PositionGetString(POSITION_SYMBOL) == _Symbol)
      AtualizarRotulosSLTPPosicao(t);
}

void AtualizarRotulosSLTP(ulong posTkt)
{
   ulong openTickets[];
   int nOpen = 0;
   ulong t = posTkt;
   if(t == 0) t = TicketPosicaoSimbolo();
   if(t > 0)
   {
      ArrayResize(openTickets, 1);
      openTickets[0] = t;
      nOpen = 1;
      AtualizarRotulosSLTPPosicao(t);
   }

   static datetime s_ultimaLimpezaOrfaos = 0;
   datetime agora = TimeCurrent();
   bool forcarLimpeza = (nOpen == 0);
   if(!forcarLimpeza && agora - s_ultimaLimpezaOrfaos < ROTULOS_LIMPEZA_ORFAOS_SEC)
      return;

   s_ultimaLimpezaOrfaos = agora;

   long chartId = ChartID();
   const string prefixSl = "SP_SLPTS_";
   const string prefixTp = "SP_TPPTS_";

   for(int i = ObjectsTotal(chartId, -1, -1) - 1; i >= 0; i--)
   {
      string nome = ObjectName(chartId, i, -1, -1);
      ulong  tkt  = 0;

      if(StringFind(nome, prefixSl) == 0)
         tkt = (ulong)StringToInteger(StringSubstr(nome, StringLen(prefixSl)));
      else if(StringFind(nome, prefixTp) == 0)
         tkt = (ulong)StringToInteger(StringSubstr(nome, StringLen(prefixTp)));
      else
         continue;

      if(!PosicaoIdNaLista(openTickets, nOpen, tkt))
         ObjectDelete(chartId, nome);
   }

   ReconciliarLinhasNiveisPosicao();
}

void ReconciliarLinhasTrailing()
{
   ulong openTickets[];
   ulong openIds[];
   int   nOpen = 0;
   ColetarPosicoesAbertasSimbolo(openTickets, openIds, nOpen);

   for(int i = 0; i < nOpen; i++)
      AtualizarLinhaTrailing(openTickets[i]);

   long chartId = ChartID();
   const string prefix = "SP_TRAIL_";
   for(int i = ObjectsTotal(chartId, -1, -1) - 1; i >= 0; i--)
   {
      string nome = ObjectName(chartId, i, -1, -1);
      if(StringFind(nome, prefix) != 0) continue;
      if(StringFind(nome, "SP_TRAIL_START_") == 0 || StringFind(nome, "SP_TRAIL_STEP_") == 0)
      {
         ObjectDelete(chartId, nome);
         continue;
      }
      ulong tkt = (ulong)StringToInteger(StringSubstr(nome, StringLen(prefix)));
      if(!PosicaoIdNaLista(openTickets, nOpen, tkt) && !PosicaoIdNaLista(openIds, nOpen, tkt))
         ObjectDelete(chartId, nome);
   }
}

void TrailingStop(ulong posTkt)
{
   if(TrailingStart <= 0 || TrailingStep <= 0) return;

   if(posTkt == 0) posTkt = TicketPosicaoSimbolo();
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return;

   if(!TrailDinamicoAtivo() && GlobalVariableCheck(GVTrailFixo(posTkt))) return;

   long   tipo     = PositionGetInteger(POSITION_TYPE);
   double open     = PositionGetDouble(POSITION_PRICE_OPEN);
   double slAtual  = PositionGetDouble(POSITION_SL);
   double tp       = PositionGetDouble(POSITION_TP);

   GarantirCacheCotacao();
   double pt = ObterPontoPreco();
   if(pt <= 0) return;

   double lucroPts;
   if(tipo == POSITION_TYPE_BUY)
      lucroPts = (g_tickBid - open) / pt;
   else
      lucroPts = (open - g_tickAsk) / pt;

   if(lucroPts < TrailingStart) return;

   double minDist  = DistanciaMinimaStops();
   double novoSL;
   double bid = g_tickBid;
   double ask = g_tickAsk;

   if(TrailDinamicoAtivo())
   {
      double dist = DistanciaTrailDinamico();
      if(dist <= 0) return;

      double passoMin = TrailingStep * pt;
      if(tipo == POSITION_TYPE_BUY)
      {
         novoSL = NormalizeDouble(bid - dist * pt, _Digits);
         double slMax = NormalizeDouble(bid - minDist, _Digits);
         if(novoSL > slMax) novoSL = slMax;
         if(slAtual > 0 && novoSL <= slAtual + pt * 0.5) return;
         if(slAtual > 0 && (novoSL - slAtual) + pt * 0.5 < passoMin) return;
      }
      else
      {
         novoSL = NormalizeDouble(ask + dist * pt, _Digits);
         double slMin = NormalizeDouble(ask + minDist, _Digits);
         if(novoSL < slMin) novoSL = slMin;
         if(slAtual > 0 && novoSL >= slAtual - pt * 0.5) return;
         if(slAtual > 0 && (slAtual - novoSL) + pt * 0.5 < passoMin) return;
      }

      if(MathAbs(novoSL - slAtual) <= pt * 0.5) return;

      if(ModificarNiveisPosicaoEA(posTkt, novoSL, tp))
      {
         AgendarLinhaTrailing(posTkt, false, true);
         AgendarRotulosSLTPPosicao(posTkt);
      }
      return;
   }

   if(tipo == POSITION_TYPE_BUY)
   {
      novoSL = NormalizeDouble(open + TrailingStep * pt, _Digits);
      double slMax = NormalizeDouble(bid - minDist, _Digits);
      if(novoSL > slMax) novoSL = slMax;
   }
   else
   {
      novoSL = NormalizeDouble(open - TrailingStep * pt, _Digits);
      double slMin = NormalizeDouble(ask + minDist, _Digits);
      if(novoSL < slMin) novoSL = slMin;
   }

   if(MathAbs(novoSL - slAtual) <= pt * 0.5) return;

   if(ModificarNiveisPosicaoEA(posTkt, novoSL, tp))
   {
      GlobalVariableSet(GVTrailFixo(posTkt), 1.0);
      AgendarLinhaTrailing(posTkt, true);
      AgendarRotulosSLTPPosicao(posTkt);
   }
}

//+------------------------------------------------------------------+
//| Ordens pendentes + J / L / K                                     |
//| J: 1a vez na barra = OPEN + offset; 2a = HIGH (cancela anterior); alterna
//| L: 1a vez na barra = OPEN - offset; 2a = LOW  (cancela anterior); alterna
//| J/L: modo OPEN = Buy/Sell Stop no broker; modo HIGH/LOW = disparo BID 1 tick antes
//| Modo OPEN: a cada abertura de candle reenvia stop no OPEN +/- offset (sem disparo antecipado)
//| K: cancela todas as pendentes do simbolo
//+------------------------------------------------------------------+
bool ResetarAlternanciaJLSeNovaBarra(datetime barAtual = 0)
{
   datetime bar = (barAtual != 0) ? barAtual : iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == 0 || bar == g_ultimaBarraJL) return false;
   g_ultimaBarraJL = bar;
   g_jProximoNoHigh = false;
   g_lProximoNoLow  = false;
   return true;
}

bool OrdemAindaPendente(ulong ticket)
{
   if(ticket == 0) return false;
   if(!OrderSelect(ticket)) return false;
   long st = OrderGetInteger(ORDER_STATE);
   return (st == ORDER_STATE_PLACED || st == ORDER_STATE_PARTIAL);
}

bool ExistePendenteAtiva(ulong ticketIgnorar = 0)
{
   if(g_jLinhaArmada || g_lLinhaArmada)
      return true;

   if(g_pendBuyJ > 0 && g_pendBuyJ != ticketIgnorar && OrdemAindaPendente(g_pendBuyJ))
      return true;
   if(g_pendSellL > 0 && g_pendSellL != ticketIgnorar && OrdemAindaPendente(g_pendSellL))
      return true;

   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(ticketIgnorar > 0 && t == ticketIgnorar) continue;

      long st = OrderGetInteger(ORDER_STATE);
      if(st == ORDER_STATE_PLACED || st == ORDER_STATE_PARTIAL)
         return true;
   }
   return false;
}

bool PendenteBloqueandoEntradaRapido()
{
   if(g_jLinhaArmada || g_lLinhaArmada)
      return true;

   if(g_pendBuyJ > 0 && OrdemAindaPendente(g_pendBuyJ))
      return true;
   if(g_pendSellL > 0 && OrdemAindaPendente(g_pendSellL))
      return true;

   return false;
}

void CancelarPendente(ulong &ticket)
{
   if(ticket == 0) return;
   if(OrdemAindaPendente(ticket))
      trade.OrderDelete(ticket);
   ticket = 0;
}

void CancelarPendentesPorComentario(const string comentario, ulong &ticketRef)
{
   CancelarPendente(ticketRef);
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      long st = OrderGetInteger(ORDER_STATE);
      if(st != ORDER_STATE_PLACED && st != ORDER_STATE_PARTIAL) continue;
      if(StringFind(OrderGetString(ORDER_COMMENT), comentario) < 0) continue;
      trade.OrderDelete(t);
   }
   ticketRef = 0;
}

void CriarOuAtualizarLinhaPendente(bool compra, double preco)
{
   string nome = compra ? OBJ_PEND_LINE_BUY : OBJ_PEND_LINE_SELL;
   double p = NormalizeDouble(preco, _Digits);
   if(ObjectFind(0, nome) < 0)
      ObjectCreate(0, nome, OBJ_HLINE, 0, 0, p);

   ObjectSetDouble(0, nome, OBJPROP_PRICE, p);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, C_PEND_LINE_COLOR);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, C_PEND_LINE_LARGURA);
   ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, nome, OBJPROP_BACK, true);
   ObjectSetInteger(0, nome, OBJPROP_RAY_RIGHT, true);
   ObjectSetString(0, nome, OBJPROP_TEXT, compra ? "J" : "L");
}

void AgendarVisuaisPendenteJL(const bool compra, const double preco)
{
   if(compra)
   {
      g_jlVisCompra = true;
      g_jlVisPrecoCompra = preco;
   }
   else
   {
      g_jlVisVenda = true;
      g_jlVisPrecoVenda = preco;
   }
}

void ProcessarVisuaisPendenteJLAgendados()
{
   bool redesenhar = false;

   if(g_jlVisCompra)
   {
      g_jlVisCompra = false;
      CriarOuAtualizarLinhaPendente(true, g_jlVisPrecoCompra);
      AtualizarLinhasSLTPPendente(true, g_jlVisPrecoCompra);
      redesenhar = true;
   }

   if(g_jlVisVenda)
   {
      g_jlVisVenda = false;
      CriarOuAtualizarLinhaPendente(false, g_jlVisPrecoVenda);
      AtualizarLinhasSLTPPendente(false, g_jlVisPrecoVenda);
      redesenhar = true;
   }

   if(redesenhar)
      ChartRedraw(0);
}

void RemoverLinhaPendente(bool compra)
{
   ObjectDelete(0, compra ? OBJ_PEND_LINE_BUY : OBJ_PEND_LINE_SELL);
}

void DefinirLinhaPreview(const string nome, double preco, color cor,
                         const string legenda, ENUM_LINE_STYLE estilo)
{
   if(preco <= 0)
   {
      ObjectDelete(0, nome);
      return;
   }

   double p = NormalizeDouble(preco, _Digits);
   if(ObjectFind(0, nome) < 0)
   {
      ObjectCreate(0, nome, OBJ_HLINE, 0, 0, p);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, nome, OBJPROP_RAY_RIGHT, true);
      ObjectSetInteger(0, nome, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   }

   double pObj = ObjectGetDouble(0, nome, OBJPROP_PRICE);
   double tol  = ToleranciaNivelPreco();
   bool   mudou = (MathAbs(pObj - p) > tol || ObjectGetString(0, nome, OBJPROP_TEXT) != legenda);
   if(!mudou
      && ObjectGetInteger(0, nome, OBJPROP_BACK) == false
      && (color)ObjectGetInteger(0, nome, OBJPROP_COLOR) == cor
      && (int)ObjectGetInteger(0, nome, OBJPROP_STYLE) == (int)estilo)
      return;

   ObjectSetDouble(0, nome, OBJPROP_PRICE, p);
   ObjectSetInteger(0, nome, OBJPROP_COLOR, cor);
   ObjectSetInteger(0, nome, OBJPROP_STYLE, estilo);
   ObjectSetInteger(0, nome, OBJPROP_WIDTH, 1);
   ObjectSetInteger(0, nome, OBJPROP_BACK, false);
   ObjectSetString(0, nome, OBJPROP_TEXT, legenda);
}

void RemoverLinhasSLTPPendente(bool compra)
{
   if(compra)
   {
      ObjectDelete(0, OBJ_PEND_SL_BUY);
      ObjectDelete(0, OBJ_PEND_TP_BUY);
   }
   else
   {
      ObjectDelete(0, OBJ_PEND_SL_SELL);
      ObjectDelete(0, OBJ_PEND_TP_SELL);
   }
}

void AtualizarLinhasSLTPPendente(bool compra, double precoEntrada)
{
   if(precoEntrada <= 0) return;

   double sl = 0, tp = 0;
   CalcularSLTPPorPontos(compra, precoEntrada, sl, tp);

   double tpExibir = tp;
   if(tpExibir <= 0 && InpTPVirtual && TakeProfit > 0)
   {
      double pt = ObterPontoPreco();
      if(compra)
         tpExibir = NormalizeDouble(precoEntrada + TakeProfit * pt, _Digits);
      else
         tpExibir = NormalizeDouble(precoEntrada - TakeProfit * pt, _Digits);
   }

   string nomeSl = compra ? OBJ_PEND_SL_BUY : OBJ_PEND_SL_SELL;
   string nomeTp = compra ? OBJ_PEND_TP_BUY : OBJ_PEND_TP_SELL;
   string legTp  = (InpTPVirtual && tp <= 0) ? "TPv prev" : "TP prev";

   DefinirLinhaPreview(nomeSl, sl, C_STATUS_ERR, "SL prev", STYLE_DOT);
   DefinirLinhaPreview(nomeTp, tpExibir, C_TP_LINHA, legTp, STYLE_DOT);
}

void AtualizarVisuaisPendentesJL()
{
   if(g_jLinhaArmada)
      AgendarVisuaisPendenteJL(true, g_jLinhaPreco);
   if(g_lLinhaArmada)
      AgendarVisuaisPendenteJL(false, g_lLinhaPreco);
}

void CancelarPendenteLinhaBroker(const bool compra)
{
   if(compra)
   {
      CancelarPendentesPorComentario("SP_PendBuy", g_pendBuyJ);
      g_jLinhaArmada = false;
      g_jLinhaPreco = 0;
      g_jBidNaArmacao = 0;
      g_jLinhaNoOpen = false;
   }
   else
   {
      CancelarPendentesPorComentario("SP_PendSell", g_pendSellL);
      g_lLinhaArmada = false;
      g_lLinhaPreco = 0;
      g_lBidNaArmacao = 0;
      g_lLinhaNoOpen = false;
   }
}

void AgendarRemoverVisuaisPendenteJL(const bool compra)
{
   if(compra)
      g_jlRemoverCompra = true;
   else
      g_jlRemoverVenda = true;
}

void ProcessarRemoverVisuaisPendenteJLAgendados()
{
   if(g_jlRemoverCompra)
   {
      g_jlRemoverCompra = false;
      RemoverLinhaPendente(true);
      RemoverLinhasSLTPPendente(true);
   }
   if(g_jlRemoverVenda)
   {
      g_jlRemoverVenda = false;
      RemoverLinhaPendente(false);
      RemoverLinhasSLTPPendente(false);
   }
}

void CancelarPendenteLinha(const bool compra)
{
   CancelarPendenteLinhaBroker(compra);
   AgendarRemoverVisuaisPendenteJL(compra);
}

void AgendarCancelamentoJL(const bool compra)
{
   g_cancelJlCompra = compra;
   g_cancelJlAgendado = true;
}

void ProcessarCancelamentoJLAgendado()
{
   if(!g_cancelJlAgendado) return;
   g_cancelJlAgendado = false;
   CancelarPendenteLinhaBroker(g_cancelJlCompra);
   AgendarRemoverVisuaisPendenteJL(g_cancelJlCompra);
}

void AgendarStatus(const string texto, const color cor,
                   const bool eventoImportante, const bool impedimento)
{
   g_statusAgTxt = texto;
   g_statusAgCor = cor;
   g_statusAgEvt = eventoImportante;
   g_statusAgImp = impedimento;
   g_statusAgPendente = true;
}

void ProcessarStatusAgendado()
{
   if(!g_statusAgPendente) return;
   g_statusAgPendente = false;
   Status(g_statusAgTxt, g_statusAgCor, g_statusAgEvt, g_statusAgImp);
}

bool NiveisManuaisPrecisamSync(const ulong posTkt)
{
   if(posTkt == 0 || !PositionSelectByTicket(posTkt)) return false;
   if(!GlobalVariableCheck(GVSlManualRef(posTkt)) && !GlobalVariableCheck(GVTPManualRef(posTkt)))
      return false;

   static ulong  s_tkt = 0;
   static double s_sl  = -1.0;
   static double s_tp  = -1.0;
   double tol = ToleranciaNivelPreco();
   double sl  = PositionGetDouble(POSITION_SL);
   double tp  = PositionGetDouble(POSITION_TP);

   if(posTkt != s_tkt || MathAbs(sl - s_sl) > tol || MathAbs(tp - s_tp) > tol)
   {
      s_tkt = posTkt;
      s_sl  = sl;
      s_tp  = tp;
      return true;
   }
   return false;
}

bool EnviarPendenteBroker(bool compra, double precoLinha, bool cancelarAntes = true)
{
   if(!TradingPermitido()) return false;

   double lote = NormalizeVol(Lote);
   if(lote <= 0) return false;

   precoLinha = NormalizeDouble(precoLinha, _Digits);
   double sl = 0, tp = 0;
   CalcularSLTPPorPontos(compra, precoLinha, sl, tp);
   ValidarSLTPBroker(compra, sl, tp);

   double minDist = DistanciaMinimaStops();

   if(compra)
   {
      if(cancelarAntes)
         CancelarPendentesPorComentario("SP_PendBuy", g_pendBuyJ);

      GarantirCacheCotacao();
      if(precoLinha <= g_tickAsk + minDist)
         return false;

      if(!trade.BuyStop(lote, precoLinha, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SP_PendBuy"))
      {
         if(InpLogDetalhado)
            PrintFormat("SP BuyStop falhou err=%d ret=%d", GetLastError(), trade.ResultRetcode());
         return false;
      }

      g_pendBuyJ = trade.ResultOrder();
      return (g_pendBuyJ > 0);
   }

   if(cancelarAntes)
      CancelarPendentesPorComentario("SP_PendSell", g_pendSellL);

   GarantirCacheCotacao();
   if(precoLinha >= g_tickBid - minDist)
      return false;

   if(!trade.SellStop(lote, precoLinha, _Symbol, sl, tp, ORDER_TIME_GTC, 0, "SP_PendSell"))
   {
      if(InpLogDetalhado)
         PrintFormat("SP SellStop falhou err=%d ret=%d", GetLastError(), trade.ResultRetcode());
      return false;
   }

   g_pendSellL = trade.ResultOrder();
   return (g_pendSellL > 0);
}

void ProcessarPendentesAberturaCandle()
{
   if(g_fechamentoAgendado) return;
   if(!PodeOperarRapido() || TemPosicaoNoSimbolo()) return;

   if(g_jLinhaArmada && g_jLinhaNoOpen)
   {
      double o = iOpen(_Symbol, PERIOD_CURRENT, 0);
      double preco = NormalizeDouble(o + PontosPainelParaPreco(InpOffsetPendPts), _Digits);
      g_jLinhaPreco = preco;
      if(EnviarPendenteBroker(true, preco))
         AgendarVisuaisPendenteJL(true, preco);
   }

   if(g_lLinhaArmada && g_lLinhaNoOpen)
   {
      double o = iOpen(_Symbol, PERIOD_CURRENT, 0);
      double preco = NormalizeDouble(o - PontosPainelParaPreco(InpOffsetPendPts), _Digits);
      g_lLinhaPreco = preco;
      if(EnviarPendenteBroker(false, preco))
         AgendarVisuaisPendenteJL(false, preco);
   }
}

bool UsaStopBrokerJL(bool compra)
{
   return compra ? (g_jLinhaArmada && g_jLinhaNoOpen) : (g_lLinhaArmada && g_lLinhaNoOpen);
}

bool OrdemStopBrokerAtiva(bool compra)
{
   if(compra)
      return (g_pendBuyJ > 0 && OrdemAindaPendente(g_pendBuyJ));
   return (g_pendSellL > 0 && OrdemAindaPendente(g_pendSellL));
}

bool UsaDisparoAntecipadoJL(bool compra)
{
   if(compra)
   {
      if(!g_jLinhaArmada) return false;
      if(UsaStopBrokerJL(true) && OrdemStopBrokerAtiva(true)) return false;
      return true;
   }
   if(!g_lLinhaArmada) return false;
   if(UsaStopBrokerJL(false) && OrdemStopBrokerAtiva(false)) return false;
   return true;
}

void AgendarLinhaTrailing(const ulong posTkt, const bool remover, const bool atualizar)
{
   if(posTkt == 0) return;
   g_trailPendenteTkt = posTkt;
   g_trailAgendaRemover = remover;
   g_trailAgendaAtualizar = atualizar;
}

void ProcessarLinhaTrailingAgendada()
{
   if(g_trailPendenteTkt == 0) return;
   ulong t = g_trailPendenteTkt;
   bool remover = g_trailAgendaRemover;
   bool atualizar = g_trailAgendaAtualizar;
   g_trailPendenteTkt = 0;
   g_trailAgendaRemover = false;
   g_trailAgendaAtualizar = false;
   if(!PositionSelectByTicket(t) || PositionGetString(POSITION_SYMBOL) != _Symbol)
      return;
   if(remover)
      RemoverLinhaTrailing(t);
   else if(atualizar)
      AtualizarLinhaTrailing(t);
   else
      CriarLinhaTrailingNaEntrada(t);
}

void AgendarStatusEntradaRealizada(const ulong posTkt)
{
   if(posTkt == 0) return;
   g_statusEntradaTkt = posTkt;
}

void ProcessarStatusEntradaAgendado()
{
   if(g_statusEntradaTkt == 0) return;
   ulong t = g_statusEntradaTkt;
   g_statusEntradaTkt = 0;
   StatusEntradaRealizada(t);
}

void AgendarProcessamentoEntrada(const ulong posTkt, const bool compra,
                                 const bool cancelJl, const bool niveisJaEnviados)
{
   if(posTkt == 0) return;
   g_entradaProcTkt = posTkt;
   g_entradaProcCompra = compra;
   g_entradaProcCancelJl = cancelJl;
   g_entradaProcNiveisOk = niveisJaEnviados;
}

void ProcessarEntradaAgendada()
{
   if(g_entradaProcTkt == 0) return;

   ulong t = g_entradaProcTkt;
   bool compra = g_entradaProcCompra;
   bool cancelJl = g_entradaProcCancelJl;
   bool niveisOk = g_entradaProcNiveisOk;
   g_entradaProcTkt = 0;

   FinalizarEntradaPosicao(t, compra, cancelJl, niveisOk);
}

void FinalizarEntradaPosicao(ulong posTkt, bool compra, bool cancelarPendenteJl, bool niveisJaEnviados)
{
   if(posTkt == 0) return;

   ulong posId = PosIdDaPosicao(posTkt);
   if(posId == 0) posId = posTkt;

   if(GlobalVariableCheck(GVEntradaPronta(posId)))
   {
      if(cancelarPendenteJl)
         AgendarCancelamentoJL(compra);
      return;
   }

   ulong t = TicketPosicaoPorId(posId);
   if(t == 0) t = posTkt;
   if(!PositionSelectByTicket(t)) return;

   GlobalVariableSet(GVEntradaPronta(posId), 1.0);

   lastOrderBar = iTime(_Symbol, PERIOD_CURRENT, 0);

   CopyNT_EnviarAbertura(posId, compra, PositionGetDouble(POSITION_VOLUME), PositionGetDouble(POSITION_PRICE_OPEN));

   AplicarSLTPPrecoEntrada(t, false, niveisJaEnviados);
   RegistrarVolumeInicial(t);

   if(cancelarPendenteJl)
      AgendarCancelamentoJL(compra);

   AgendarLinhaTrailing(t);
   AgendarRotulosSLTPPosicao(t);
   AgendarStatusEntradaRealizada(t);
}

void VerificarPreenchimentoPendenteBroker()
{
   if(g_pendBuyJ > 0 && !OrdemAindaPendente(g_pendBuyJ))
      g_pendBuyJ = 0;

   if(g_pendSellL > 0 && !OrdemAindaPendente(g_pendSellL))
      g_pendSellL = 0;
}

bool DispararPendenteLinha(bool compra)
{
   GarantirCacheCotacao();
   double bid   = g_tickBid;
   double tol   = _Point * 0.5;
   double antec = ObterPontoPreco();

   if(compra)
   {
      if(!g_jLinhaArmada) return false;
      if(bid < g_jLinhaPreco - tol - antec) return false;
      return true;
   }

   if(!g_lLinhaArmada) return false;
   if(bid > g_lLinhaPreco + tol + antec) return false;
   return true;
}

void ExecutarEntradaPorLinha(bool compra)
{
   static bool s_enviandoJl = false;
   if(s_enviandoJl) return;
   if(!PodeOperarRapido()) return;
   if(!TradingPermitido()) return;
   if(TemPosicaoNoSimbolo())
   {
      CancelarPendenteLinha(compra);
      return;
   }

   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == lastOrderBar) return;

   double lote = NormalizeVol(Lote);
   if(lote <= 0) return;

   double sl = 0, tp = 0;
   CalcularSLTPMercado(compra, sl, tp);

   s_enviandoJl = true;
   bool ok = false;
   if(compra)
      ok = trade.Buy(lote, _Symbol, 0, sl, tp, "SP_PendBuy");
   else
      ok = trade.Sell(lote, _Symbol, 0, sl, tp, "SP_PendSell");
   s_enviandoJl = false;

   lastOrderBar = bar;
   if(!ok)
      AgendarFalhaTrade(SP_MSG_ERRO_JL);
}

void ProcessarPendentesPorLinha()
{
   if(g_fechamentoAgendado) return;
   if(!TradingPermitido()) return;
   if(TemPosicaoNoSimbolo())
   {
      if(g_jLinhaArmada) CancelarPendenteLinha(true);
      if(g_lLinhaArmada) CancelarPendenteLinha(false);
      return;
   }
   if(g_jLinhaArmada && UsaDisparoAntecipadoJL(true) && DispararPendenteLinha(true))
      ExecutarEntradaPorLinha(true);
   else if(g_lLinhaArmada && UsaDisparoAntecipadoJL(false) && DispararPendenteLinha(false))
      ExecutarEntradaPorLinha(false);
}

bool ArmarPendentePorLinha(bool compra, double preco)
{
   if(!PodeOperarRapido()) return false;
   if(!TradingPermitido())
   {
      AgendarFalhaTrade(SP_MSG_ERRO_JL);
      return false;
   }
   if(TemPosicaoNoSimbolo()) return false;

   preco = NormalizeDouble(preco, _Digits);
   GarantirCacheCotacao();
   double bid = g_tickBid;

   CancelarPendenteLinha(compra);

   if(compra)
   {
      g_jLinhaArmada = true;
      g_jLinhaPreco = preco;
      g_jBidNaArmacao = bid;
   }
   else
   {
      g_lLinhaArmada = true;
      g_lLinhaPreco = preco;
      g_lBidNaArmacao = bid;
   }

   if((compra && g_jLinhaNoOpen) || (!compra && g_lLinhaNoOpen))
      EnviarPendenteBroker(compra, preco, false);

   AgendarVisuaisPendenteJL(compra, preco);

   AgendarStatus(compra ? SP_MSG_J_ARMADO : SP_MSG_L_ARMADO,
                 compra ? C_BUY_STATUS_TEXT : C_SELL_STATUS_TEXT, true, true);
   return true;
}

void TeclaJ()
{
   if(!PodeOperarRapido()) return;

   ResetarAlternanciaJLSeNovaBarra();

   double o = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double h = iHigh(_Symbol, PERIOD_CURRENT, 0);

   double preco;
   if(!g_jProximoNoHigh)
   {
      preco = NormalizeDouble(o + PontosPainelParaPreco(InpOffsetPendPts), _Digits);
      g_jProximoNoHigh = true;
      g_jLinhaNoOpen = true;
   }
   else
   {
      preco = NormalizeDouble(h, _Digits);
      g_jProximoNoHigh = false;
      g_jLinhaNoOpen = false;
   }

   ArmarPendentePorLinha(true, preco);
}

void TeclaL()
{
   if(!PodeOperarRapido()) return;

   ResetarAlternanciaJLSeNovaBarra();

   double o = iOpen(_Symbol, PERIOD_CURRENT, 0);
   double l = iLow(_Symbol, PERIOD_CURRENT, 0);

   double preco;
   if(!g_lProximoNoLow)
   {
      preco = NormalizeDouble(o - PontosPainelParaPreco(InpOffsetPendPts), _Digits);
      g_lProximoNoLow = true;
      g_lLinhaNoOpen = true;
   }
   else
   {
      preco = NormalizeDouble(l, _Digits);
      g_lProximoNoLow = false;
      g_lLinhaNoOpen = false;
   }

   ArmarPendentePorLinha(false, preco);
}

int ExecutarCancelamentoPendentes()
{
   int n = 0;
   for(int i = OrdersTotal() - 1; i >= 0; i--)
   {
      ulong t = OrderGetTicket(i);
      if(t == 0 || !OrderSelect(t)) continue;
      if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
      if(trade.OrderDelete(t))
         n++;
   }

   g_pendBuyJ = 0;
   g_pendSellL = 0;
   g_jProximoNoHigh = false;
   g_lProximoNoLow  = false;
   g_jLinhaNoOpen   = false;
   g_lLinhaNoOpen   = false;
   CancelarPendenteLinha(true);
   CancelarPendenteLinha(false);

   return n;
}

void CancelarTodasPendentes()
{
   bool tinhaLinha = g_jLinhaArmada || g_lLinhaArmada;
   int  n = ExecutarCancelamentoPendentes();

   if(n > 0 || tinhaLinha)
      Status(SP_MSG_CANCELADO, clrOrange);
}

string NormalizarAtivo(const string ativo)
{
   string s = ativo;
   StringTrimLeft(s);
   StringTrimRight(s);
   StringToUpper(s);
   return s;
}

// Grafico de origem do SYNC: outro grafico do ativo indicado. Entre varios, prefere o que
// NAO tem EA (o grafico de estudo), para nao puxar de outro grafico de operacao.
long BuscarGraficoOrigemPorAtivo(const string ativoNormalizado, const long chartAtual)
{
   if(StringLen(ativoNormalizado) == 0) return -1;

   long melhor = -1;
   bool melhorSemEA = false;
   for(long cid = ChartFirst(); cid >= 0; cid = ChartNext(cid))
   {
      if(cid == chartAtual) continue;

      string sym = ChartSymbol(cid);
      StringToUpper(sym);
      if(sym != ativoNormalizado) continue;

      bool semEA = (ChartGetString(cid, CHART_EXPERT_NAME) == "");
      if(melhor < 0 || (semEA && !melhorSemEA))
      {
         melhor = cid;
         melhorSemEA = semEA;
      }
   }
   return melhor;
}

bool EhObjetoLinhaSLTPGrafico(const string nome)
{
   if(StringFind(nome, "SP_POS_SL_") == 0) return true;
   if(StringFind(nome, "SP_POS_TP_") == 0) return true;
   if(nome == OBJ_PEND_SL_BUY || nome == OBJ_PEND_SL_SELL
      || nome == OBJ_PEND_TP_BUY || nome == OBJ_PEND_TP_SELL)
      return true;
   return false;
}

bool EhHlineProtegidaDoEA(const string nome)
{
   if(StringFind(nome, PARC_LINHA_PREFIX) == 0) return true;   // linhas P1/P2
   if(StringFind(nome, LIN_PREFIX) == 0) return true;   // linhas do dia (arquivo)
   if(StringFind(nome, "SP_TRAIL_") == 0) return true;
   if(EhObjetoLinhaSLTPGrafico(nome)) return true;
   return false;
}

bool EhLinhaVerticalNoGrafico(const long chartId, const string nome)
{
   ENUM_OBJECT tipo = (ENUM_OBJECT)ObjectGetInteger(chartId, nome, OBJPROP_TYPE);
   if(tipo == OBJ_VLINE)
      return true;

   if(tipo == OBJ_TREND)
   {
      datetime t0 = (datetime)ObjectGetInteger(chartId, nome, OBJPROP_TIME, 0);
      datetime t1 = (datetime)ObjectGetInteger(chartId, nome, OBJPROP_TIME, 1);
      double   p0 = ObjectGetDouble(chartId, nome, OBJPROP_PRICE, 0);
      double   p1 = ObjectGetDouble(chartId, nome, OBJPROP_PRICE, 1);
      double   tolPreco = ObterPontoPreco() * 2.0;

      if(MathAbs(p0 - p1) <= tolPreco)
         return false;

      if(t0 == t1)
         return true;

      if(MathAbs((long)(t1 - t0)) <= 1)
         return true;
   }

   return false;
}

bool EhLinhaHorizontalNoGrafico(const long chartId, const string nome)
{
   ENUM_OBJECT tipo = (ENUM_OBJECT)ObjectGetInteger(chartId, nome, OBJPROP_TYPE);
   if(tipo == OBJ_HLINE)
      return true;

   if(tipo == OBJ_TREND)
   {
      double p0 = ObjectGetDouble(chartId, nome, OBJPROP_PRICE, 0);
      double p1 = ObjectGetDouble(chartId, nome, OBJPROP_PRICE, 1);
      return (MathAbs(p0 - p1) <= ObterPontoPreco() * 2.0);
   }

   return false;
}

// Linhas HLINE copiadas pelo SYNC (SP_SYNC_HL_1, SP_SYNC_HL_2, ...) — nao confundir com SP_SYNC_HL_LBL / _BG do botao.
bool EhObjetoLinhaSyncCopiada(const string nome)
{
   const string prefix = "SP_SYNC_HL_";
   if(StringFind(nome, prefix) != 0)
      return false;

   string suf = StringSubstr(nome, StringLen(prefix));
   int n = StringLen(suf);
   if(n == 0)
      return false;

   for(int i = 0; i < n; i++)
   {
      ushort ch = (ushort)StringGetCharacter(suf, i);
      if(ch < '0' || ch > '9')
         return false;
   }
   return true;
}

void LimparLinhasHorizontaisAntesSync(const long chartId)
{
   for(int i = ObjectsTotal(chartId, -1, -1) - 1; i >= 0; i--)
   {
      string nome = ObjectName(chartId, i, -1, -1);
      if(nome == "") continue;

      if(EhObjetoLinhaSyncCopiada(nome))
      {
         ObjectDelete(chartId, nome);
         continue;
      }

      if(EhHlineProtegidaDoEA(nome))
         continue;

      if(EhLinhaVerticalNoGrafico(chartId, nome))
         continue;

      if(EhLinhaHorizontalNoGrafico(chartId, nome))
         ObjectDelete(chartId, nome);
   }
}

void SincronizarLinhasHorizontais()
{
   const long chartAtual = ChartID();
   string ativo = NormalizarAtivo(InpAtivoCopiarLinhas);
   if(StringLen(ativo) == 0)
      ativo = NormalizarAtivo(_Symbol);   // grafico de estudo do mesmo ativo
   if(StringLen(ativo) == 0)
   {
      Status(SP_MSG_SYNC_ATIVO, clrOrange, true);
      return;
   }

   long chartOrigem = BuscarGraficoOrigemPorAtivo(ativo, chartAtual);
   if(chartOrigem < 0)
   {
      Status(SP_MSG_SYNC_GRAF, clrOrange, true);
      return;
   }

   LimparLinhasHorizontaisAntesSync(chartAtual);
   ChartRedraw(chartAtual);

   int copiadas = 0;
   for(int i = 0; i < ObjectsTotal(chartOrigem, -1, -1); i++)
   {
      string nomeOrigem = ObjectName(chartOrigem, i, -1, -1);
      if(nomeOrigem == "") continue;
      if(StringFind(nomeOrigem, "SP_") == 0) continue;          // objetos do Scalper Pro do outro grafico
      if(EhHlineProtegidaDoEA(nomeOrigem)) continue;
      // linha horizontal ou linha de tendencia horizontal (mesmo preco nas duas pontas)
      if(!EhLinhaHorizontalNoGrafico(chartOrigem, nomeOrigem)) continue;

      string nomeDestino = "SP_SYNC_HL_" + IntegerToString(copiadas + 1);
      double preco = ObjectGetDouble(chartOrigem, nomeOrigem, OBJPROP_PRICE, 0);
      color cor = (color)ObjectGetInteger(chartOrigem, nomeOrigem, OBJPROP_COLOR);
      int estilo = (int)ObjectGetInteger(chartOrigem, nomeOrigem, OBJPROP_STYLE);
      int largura = (int)ObjectGetInteger(chartOrigem, nomeOrigem, OBJPROP_WIDTH);

      if(!ObjectCreate(chartAtual, nomeDestino, OBJ_HLINE, 0, 0, preco))
         continue;

      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_COLOR, cor);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_STYLE, estilo);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_WIDTH, largura);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_SELECTED, false);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_BACK, true);
      ObjectSetInteger(chartAtual, nomeDestino, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      copiadas++;
   }

   ChartRedraw(chartAtual);
   GarantirTextoBotaoSync();

   if(copiadas > 0)
   {
      string tf = StringSubstr(EnumToString(ChartPeriod(chartOrigem)), 7);
      StatusComAutoReset(StringFormat("SYNC: %d linhas de %s %s", copiadas, ChartSymbol(chartOrigem), tf), C_STATUS_OK, true);
      PrintFormat("SP SYNC: %d linhas copiadas do grafico %s %s (id %I64d, %s)", copiadas, ChartSymbol(chartOrigem), tf,
                  chartOrigem, ChartGetString(chartOrigem, CHART_EXPERT_NAME) == "" ? "sem EA" : "com EA");
   }
   else
      Status(SP_MSG_SEM_LINHAS, clrOrange, true);
}

void LimparTicketsPendentesInvalidos()
{
   if(!g_jLinhaArmada && !g_lLinhaArmada && g_pendBuyJ == 0 && g_pendSellL == 0)
      return;

   if(g_pendBuyJ  > 0 && !OrdemAindaPendente(g_pendBuyJ))  g_pendBuyJ  = 0;
   if(g_pendSellL > 0 && !OrdemAindaPendente(g_pendSellL)) g_pendSellL = 0;
}

//+------------------------------------------------------------------+
//| Timer do candle no grafico                                       |
//+------------------------------------------------------------------+
void CriarObjetoTimer()
{
   if(ObjectFind(0, OBJ_CANDLE_TIMER) >= 0) return;
   ObjectCreate(0, OBJ_CANDLE_TIMER, OBJ_TEXT, 0, 0, 0);
   ObjectSetInteger(0, OBJ_CANDLE_TIMER, OBJPROP_COLOR, clrDarkViolet);
   ObjectSetInteger(0, OBJ_CANDLE_TIMER, OBJPROP_FONTSIZE, 12);
   ObjectSetInteger(0, OBJ_CANDLE_TIMER, OBJPROP_ANCHOR, ANCHOR_LEFT);
   ObjectSetString(0, OBJ_CANDLE_TIMER, OBJPROP_FONT, UI_FONT_BOLD);
}

void AtualizarTimerCandle(const ulong posTkt)
{
   static bool s_timerOk = false;
   if(!s_timerOk)
   {
      CriarObjetoTimer();
      s_timerOk = (ObjectFind(0, OBJ_CANDLE_TIMER) >= 0);
      if(!s_timerOk) return;
   }

   datetime t0      = iTime(_Symbol, PERIOD_CURRENT, 0);
   int      periodo = PeriodSeconds(PERIOD_CURRENT);
   if(periodo <= 0) periodo = PeriodSeconds(_Period);

   int rest = (int)((t0 + periodo) - TimeCurrent());
   if(rest < 0) rest = 0;

   GarantirCacheCotacao();
   double precoLinha = g_tickBid;
   if(posTkt > 0 && PositionSelectByTicket(posTkt))
   {
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY)
         precoLinha = g_tickBid;
      else
         precoLinha = g_tickAsk;
   }

   if(InpTimerDeslocPts != 0.0)
      precoLinha += InpTimerDeslocPts * _Point;

   static int      s_restTimer   = -1;
   static datetime s_barTimer    = 0;
   static double   s_precoTimer  = 0.0;
   double tolPreco = _Point * 0.5;
   bool mudouTxt   = (rest != s_restTimer);
   bool mudouBar   = (t0 != s_barTimer);
   bool mudouPreco = (MathAbs(precoLinha - s_precoTimer) > tolPreco);
   if(!mudouTxt && !mudouBar && !mudouPreco)
      return;

   double pctTimer = InpTimerPosPct;
   if(pctTimer < 0.0)    pctTimer = 1.00;
   if(pctTimer > 1.25)   pctTimer = 2.00;

   datetime tTimer = t0 + (datetime)(periodo * pctTimer);

   ObjectMove(0, OBJ_CANDLE_TIMER, 0, tTimer, precoLinha);
   if(mudouTxt)
      ObjectSetString(0, OBJ_CANDLE_TIMER, OBJPROP_TEXT, StringFormat("%02d", rest % 60));

   s_restTimer  = rest;
   s_barTimer   = t0;
   s_precoTimer = precoLinha;
}

//+------------------------------------------------------------------+
//| Tecla R: 1o toque min/max; 2o OPEN; reinicia em nova op ou nova vela |
//+------------------------------------------------------------------+
bool SlRProximoEhOpen(ulong posTkt, datetime barAtual)
{
   if(barAtual == 0) return false;
   if(!GlobalVariableCheck(GVSlRBar(posTkt))) return false;
   if((datetime)GlobalVariableGet(GVSlRBar(posTkt)) != barAtual) return false;
   return GlobalVariableCheck(GVSlRStep(posTkt)) && GlobalVariableGet(GVSlRStep(posTkt)) >= 1.0;
}

void ToggleSLPorTipo()
{
   double candleOpen = iOpen(_Symbol, PERIOD_CURRENT, 0);
   GarantirCacheCotacao();
   double bid = g_tickBid;
   double ask = g_tickAsk;
   double pt  = ObterPontoPreco();
   double candleLow  = iLow(_Symbol, PERIOD_CURRENT, 0);
   double candleHigh = iHigh(_Symbol, PERIOD_CURRENT, 0);
   if(candleOpen <= 0 || candleLow <= 0 || candleHigh <= 0) return;

   datetime barAtual = iTime(_Symbol, PERIOD_CURRENT, 0);

   double minDist = DistanciaMinimaStops();
   int modificados = 0;
   bool temPosicao   = false;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong tkt = PositionGetTicket(i);
      if(tkt == 0 || !PositionSelectByTicket(tkt)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(CopyFilha_GerenciaSelecionada()) continue;

      temPosicao = true;
      bool   paraOpen = SlRProximoEhOpen(tkt, barAtual);
      long   tipo     = PositionGetInteger(POSITION_TYPE);
      double tp       = PositionGetDouble(POSITION_TP);
      double slAtual  = PositionGetDouble(POSITION_SL);
      double novoSL;

      if(tipo == POSITION_TYPE_BUY)
      {
         novoSL = NormalizeDouble(paraOpen ? candleOpen : candleLow, _Digits);
         double slMax = NormalizeDouble(bid - minDist, _Digits);
         if(novoSL > slMax) novoSL = slMax;
      }
      else
      {
         novoSL = NormalizeDouble(paraOpen ? candleOpen : candleHigh, _Digits);
         double slMin = NormalizeDouble(ask + minDist, _Digits);
         if(novoSL < slMin) novoSL = slMin;
      }

      if(MathAbs(novoSL - slAtual) <= pt * 0.5) continue;

      if(ModificarNiveisPosicaoEA(tkt, novoSL, tp))
      {
         modificados++;
         GlobalVariableSet(GVSlRBar(tkt), (double)barAtual);
         GlobalVariableSet(GVSlRStep(tkt), paraOpen ? 0.0 : 1.0);
         AgendarRotulosSLTPPosicao(tkt);
      }
   }

   if(modificados > 0)
      StatusComAutoReset(SP_MSG_SL_OK, clrAqua);
}

//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   // Copiador: publica o novo estado antes de qualquer outro processamento
   if(g_copyModoEf == COPY_MAE)
      CopyMae_Publicar(false);

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

   ulong dealTkt = trans.deal;
   if(dealTkt == 0 || !HistoryDealSelect(dealTkt)) return;
   if(!DealDoSimboloAtivo(dealTkt)) return;

   long entry = HistoryDealGetInteger(dealTkt, DEAL_ENTRY);

   // Registra entrada aberta; contagem ocorre apos fechamento total da posicao
   if(entry == DEAL_ENTRY_IN || entry == DEAL_ENTRY_INOUT)
   {
      if(!GlobalVariableCheck(GVOpCounted(dealTkt)))
      {
         GlobalVariableSet(GVOpCounted(dealTkt), 1.0);

         string coment = HistoryDealGetString(dealTkt, DEAL_COMMENT);
         string origem = "";
         if(StringFind(coment, "SP_PendBuy") >= 0 || StringFind(coment, "SP_PendSell") >= 0)
            origem = "PENDENTE";
         else
            origem = "MARKET";

         ulong posId = (ulong)HistoryDealGetInteger(dealTkt, DEAL_POSITION_ID);
         if(posId > 0 && origem != "")
            RegistrarOperacaoAberta(posId, origem);

         if(posId > 0)
         {
            ulong posTktEntrada = TicketPosicaoPorId(posId);
            if(posTktEntrada == 0)
               posTktEntrada = ResolverPositionId(posId);
            if(posTktEntrada > 0 && origem != "" && !CopyFilha_GerenciaDeal(dealTkt))
            {
               bool compraEnt = (HistoryDealGetInteger(dealTkt, DEAL_TYPE) == DEAL_TYPE_BUY);
               AgendarProcessamentoEntrada(posTktEntrada, compraEnt, origem == "PENDENTE", true);
            }
         }
      }
      return;
   }

   if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) return;

   ulong posId = (ulong)HistoryDealGetInteger(dealTkt, DEAL_POSITION_ID);
   if(posId == 0) return;

   bool posFechada = PosicaoFechadaPorId(posId);
   if(!posFechada)
   {
      ConfirmarParcialPorDeal(posId, dealTkt);
      return;
   }

   CopyNT_EnviarFechamento(posId);

   ulong posTktTrans = (trans.position > 0) ? (ulong)trans.position : 0;
   ulong posTkt = ResolverTicketPosicao(posId);
   if(posTkt == 0) posTkt = posTktTrans;
   if(posTkt == 0) posTkt = posId;

   LimparGraficoPosicaoFechada(posId, posTkt, posTktTrans);
   ulong posTktParc = ResolverTicketParciais(posId);
   FinalizarParciaisPorFechamentoTotal(posTktParc);
   if(posTktParc != posTkt) LimparGVsParciais(posTktParc);
   LimparGVs(posTkt);

   ulong idStats = posId;
   if(idStats == 0 && trans.position > 0)
      idStats = (ulong)trans.position;
   RegistrarFechamentoCompleto(idStats, dealTkt, 0);
   AtualizarRotulosSLTP(0);
}

//+------------------------------------------------------------------+
//| UI                                                               |
//+------------------------------------------------------------------+
color MisturarCor(const color base, const color tint, const double alpha)
{
   if(alpha <= 0.0) return base;
   if(alpha >= 1.0) return tint;

   int bB = (int)(base & 0xFF), bG = (int)((base >> 8) & 0xFF), bR = (int)((base >> 16) & 0xFF);
   int tB = (int)(tint & 0xFF), tG = (int)((tint >> 8) & 0xFF), tR = (int)((tint >> 16) & 0xFF);
   int oB = (int)(bB + (tB - bB) * alpha);
   int oG = (int)(bG + (tG - bG) * alpha);
   int oR = (int)(bR + (tR - bR) * alpha);
   return (color)((oR << 16) | (oG << 8) | oB);
}

int TierCorStatus(const color cor)
{
   if(cor == C_STATUS_ERR || cor == clrRed || cor == C_SELL_STATUS_TEXT)
      return 2;
   if(cor == clrOrange || cor == C_STATUS_WARN || cor == C_SETUP_VOL_BG)
      return 1;
   if(cor == C_BUY_STATUS_TEXT || cor == C_STATUS_OK)
      return 0;
   return 0;
}

color CorFaixaStatusAccent(const color cor)
{
   int tier = TierCorStatus(cor);
   if(tier == 2) return C_STATUS_ERR;
   if(tier == 1) return C_STATUS_WARN;
   return C_STATUS_OK;
}

color CorFaixaStatusFundo(const color cor)
{
   return MisturarCor(C_STATUS_STRIP_BG, CorFaixaStatusAccent(cor), STATUS_TINT_ALPHA);
}

void AplicarEstiloFaixaStatus(const color cor)
{
   if(ObjectFind(0, OBJ_STATUS_STRIP) >= 0)
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_BGCOLOR, CorFaixaStatusFundo(cor));
}

// Cores vivas (clrLime, clrOrange...) somem no fundo claro: troca pelo tom escuro equivalente.
color CorTemaClaro(const color c)
{
   if(c == clrLime || c == clrGreen || c == clrLimeGreen || c == clrSpringGreen) return C_STATUS_OK;
   if(c == clrOrange || c == clrGold || c == clrYellow || c == clrDarkOrange)    return C_STATUS_WARN;
   if(c == clrRed || c == clrTomato || c == clrOrangeRed)                        return C_STATUS_ERR;
   if(c == clrGray || c == clrSilver || c == clrDarkGray)                        return C_MUTED;
   if(c == clrWhite)                                                             return C_NOME_COLOR;
   return c;
}

void AplicarTextoStatusUI(const string texto, const color cor)
{
   if(ObjectFind(0, OBJ_TXT_STATUS) >= 0)
   {
      ObjectSetString(0, OBJ_TXT_STATUS, OBJPROP_TEXT, texto);
      ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_COLOR, CorTemaClaro(cor));
   }
   AplicarEstiloFaixaStatus(cor);
}

bool ObterStatusImpedimento(string &texto, color &cor)
{
   if(g_centralEstado != CENTRAL_LIVRE)
   {
      texto = Central_TextoStatus();
      cor = C_STATUS_ERR;
      return true;
   }
   if(g_fechamentoAgendado)
   {
      texto = SP_MSG_FECHANDO;
      cor = C_STATUS_ERR;
      return true;
   }
   if(g_limiteBloqueadoDia || g_painelBloqueado)
   {
      texto = SP_MSG_BLOQUEADO;
      cor = C_STATUS_ERR;
      return true;
   }

   int motTrade = MotivoTradeBloqueado();
   if(motTrade > 0)
   {
      texto = TextoMotivoTradeBloqueado(motTrade);
      cor = C_STATUS_WARN;
      return true;
   }

   if(g_campoEditAtivo != "")
   {
      texto = SP_MSG_EDITANDO;
      cor = C_ACCENT_COLOR;
      return true;
   }

   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(!TemPosicaoNoSimbolo() && lastOrderBar > 0 && bar > 0 && bar == lastOrderBar)
   {
      texto = SP_MSG_1OP_BARRA;
      cor = clrOrange;
      return true;
   }
   if(g_jLinhaArmada)
   {
      texto = SP_MSG_J_ARMADO;
      cor = C_BUY_STATUS_TEXT;
      return true;
   }
   if(g_lLinhaArmada)
   {
      texto = SP_MSG_L_ARMADO;
      cor = C_SELL_STATUS_TEXT;
      return true;
   }
   if(ExistePendenteAtiva(0))
   {
      texto = SP_MSG_PENDENTE;
      cor = clrOrange;
      return true;
   }
   return false;
}

void RestaurarStatusPronto()
{
   string impTxt;
   color  impCor;
   if(ObterStatusImpedimento(impTxt, impCor))
   {
      AplicarTextoStatusUI(impTxt, impCor);
      g_statusResetEm = 0;
      return;
   }

   AplicarTextoStatusUI(SP_STATUS_PRONTO, C_STATUS_OK);
   g_statusResetEm = 0;
}

void SincronizarStatusImpedimento()
{
   int motTrade = MotivoTradeBloqueado();
   if(motTrade > 0)
   {
      g_statusResetEm = 0;
      string txtTrade = TextoMotivoTradeBloqueado(motTrade);
      string atualTrade = "";
      if(ObjectFind(0, OBJ_TXT_STATUS) >= 0)
         atualTrade = ObjectGetString(0, OBJ_TXT_STATUS, OBJPROP_TEXT);
      if(atualTrade != txtTrade)
         AplicarTextoStatusUI(txtTrade, C_STATUS_WARN);
      return;
   }

   if(g_statusResetEm > 0)
      return;

   string impTxt;
   color  impCor;
   bool   temImp = ObterStatusImpedimento(impTxt, impCor);

   string atual = "";
   if(ObjectFind(0, OBJ_TXT_STATUS) >= 0)
      atual = ObjectGetString(0, OBJ_TXT_STATUS, OBJPROP_TEXT);

   if(temImp)
   {
      if(atual != impTxt)
         AplicarTextoStatusUI(impTxt, impCor);
      return;
   }

   if(atual != SP_STATUS_PRONTO)
      RestaurarStatusPronto();
}

void ProcessarResetStatusGeralAgendado()
{
   if(g_statusResetEm <= 0) return;
   if(TimeCurrent() < g_statusResetEm) return;

   g_statusResetEm = 0;
   RestaurarStatusPronto();
   ChartRedraw(0);
}

void StatusComAutoReset(const string texto, color cor, bool eventoImportante = true)
{
   Status(texto, cor, eventoImportante, false);
}

void Status(string texto, color cor, bool eventoImportante = false, bool impedimento = false)
{
   AplicarTextoStatusUI(texto, cor);
   if(impedimento)
      g_statusResetEm = 0;
   else
      g_statusResetEm = TimeCurrent() + STATUS_UI_RESET_SEC;
   if(eventoImportante || InpLogDetalhado)
      Print("SP: ", texto);
}

void CreateLabel(string name, int x, int y, string text, color col, int fontsize, bool bold = false)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? UI_FONT_BOLD : UI_FONT);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void CreateLabelCentered(string name, int xCenter, int y, string text, color col, int fontsize, bool bold = false)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xCenter);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? UI_FONT_BOLD : UI_FONT);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

void CreateLabelMetricaValor(string name, int xCenter, int yBottom, string text, color col, int fontsize, bool bold = false)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, xCenter);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, yBottom);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LOWER);
   ObjectSetInteger(0, name, OBJPROP_COLOR, col);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontsize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? UI_FONT_BOLD : UI_FONT);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
}

bool EhCampoParametroPainel(const string name)
{
   return (name == OBJ_EDIT_LOTE || name == OBJ_EDIT_TP || name == OBJ_EDIT_SL
           || name == OBJ_EDIT_TRAIL_START || name == OBJ_EDIT_TRAIL_STEP
           || name == OBJ_EDIT_P1_PTS || name == OBJ_EDIT_P1_PCT
           || name == OBJ_EDIT_P2_PTS || name == OBJ_EDIT_P2_PCT);
}

void CreateEditCampoParam(const string name, const int x, const int y, const string text,
                          const int width, const int height)
{
   if(ObjectFind(0, name) >= 0)
   {
      if(ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_EDIT)
         ObjectDelete(0, name);
   }
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_EDIT, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C_INPUT_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_INPUT_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_INPUT_BORDER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ConfigurarCampoEditavel(name);
}

void CreateEdit(string name, int x, int y, string text, int width = 80, int height = 20,
                int align = ALIGN_CENTER)
{
   if(ObjectFind(0, name) >= 0)
   {
      if(ObjectGetInteger(0, name, OBJPROP_TYPE) != OBJ_BUTTON)
         ObjectDelete(0, name);
   }
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, C_INPUT_BG);
   ObjectSetInteger(0, name, OBJPROP_COLOR, C_INPUT_TEXT);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, C_INPUT_BORDER);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_ALIGN, align);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   ConfigurarCampoEditavel(name);
}

void ConfigurarCampoEditavel(const string name)
{
   if(ObjectFind(0, name) < 0) return;
   if(!EhCampoEditavelPainel(name)) return;

   long tipo = ObjectGetInteger(0, name, OBJPROP_TYPE);
   bool bloq = g_painelBloqueado;

   if(tipo == OBJ_BUTTON)
   {
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, !bloq);
      ObjectSetInteger(0, name, OBJPROP_BACK, false);
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_EDIT_ZORDER);
      ObjectSetInteger(0, name, OBJPROP_STATE, false);
      return;
   }

   if(tipo != OBJ_EDIT) return;

   if(bloq)
   {
      ObjectSetInteger(0, name, OBJPROP_READONLY, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   }
   else
   {
      ObjectSetInteger(0, name, OBJPROP_READONLY, false);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   }
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, PANEL_EDIT_ZORDER);
   if(EhCampoParametroPainel(name))
      ObjectSetInteger(0, name, OBJPROP_ALIGN, ALIGN_LEFT);
}

void GarantirCamposEditaveisPainel()
{
   string edits[] = {OBJ_EDIT_LOTE, OBJ_EDIT_TP, OBJ_EDIT_SL, OBJ_EDIT_TRAIL_START, OBJ_EDIT_TRAIL_STEP,
                     OBJ_EDIT_P1_PTS, OBJ_EDIT_P1_PCT, OBJ_EDIT_P2_PTS, OBJ_EDIT_P2_PCT};
   for(int i = 0; i < ArraySize(edits); i++)
      ConfigurarCampoEditavel(edits[i]);
}

void AtivarTecladoEdicaoCampo(const bool ativo)
{
   long cid = ChartID();
   if(ativo)
   {
      if(!g_chartKeyboardSaved)
      {
         g_chartKeyboardPrev = ChartGetInteger(cid, CHART_KEYBOARD_CONTROL);
         g_chartKeyboardSaved = true;
      }
      ChartSetInteger(cid, CHART_KEYBOARD_CONTROL, true);
      return;
   }

   if(g_chartKeyboardSaved)
   {
      ChartSetInteger(cid, CHART_KEYBOARD_CONTROL, g_chartKeyboardPrev);
      g_chartKeyboardSaved = false;
   }
}

void AplicarDestaqueCampoEdit(const string nomeCampo, const bool editando)
{
   if(ObjectFind(0, nomeCampo) < 0) return;
   ObjectSetInteger(0, nomeCampo, OBJPROP_BORDER_COLOR, editando ? C_ACCENT_COLOR : C_INPUT_BORDER);
   ObjectSetInteger(0, nomeCampo, OBJPROP_COLOR, editando ? C_ACCENT_COLOR : C_INPUT_TEXT);
}

void AtualizarTextoCampoEditBuffer()
{
   if(g_campoEditAtivo == "" || ObjectFind(0, g_campoEditAtivo) < 0) return;
   ObjectSetString(0, g_campoEditAtivo, OBJPROP_TEXT, g_bufferEdicao);
   ChartRedraw(0);
}

bool TeclaDigitoEdicao(const int key, string &dig)
{
   dig = "";
   if(key >= 48 && key <= 57)
   {
      dig = CharToString((uchar)key);
      return true;
   }
   if(key >= 96 && key <= 105)
   {
      dig = IntegerToString(key - 96);
      return true;
   }
   return false;
}

void FinalizarEdicaoCampoParaExecucao()
{
   if(g_campoEditAtivo == "") return;

   string campo = g_campoEditAtivo;
   if(g_bufferEdicao == "")
      ObjectSetString(0, campo, OBJPROP_TEXT, g_bufferEdicaoOriginal);
   else
      ObjectSetString(0, campo, OBJPROP_TEXT, g_bufferEdicao);

   AtualizarCampos();
   EscreverValorCampoEdit(campo);

   AplicarDestaqueCampoEdit(campo, false);
   g_campoEditAtivo = "";
   g_bufferEdicao = "";
   g_bufferEdicaoOriginal = "";
   g_substituirBufferEdicao = false;
   AtivarTecladoEdicaoCampo(false);
   g_configSalvarPendente = true;
}

void ProcessarConfigSalvarAgendada()
{
   if(!g_configSalvarPendente) return;
   g_configSalvarPendente = false;
   SalvarConfigPainelPerfil(g_setupAtivo);
   ReconciliarLinhasTrailing();
   ulong posTkt = TicketPosicaoSimbolo();
   if(posTkt > 0)
      AgendarRotulosSLTPPosicao(posTkt);
}

void FinalizarEdicaoCampo(const bool salvar)
{
   if(g_campoEditAtivo == "") return;

   string campo = g_campoEditAtivo;
   if(salvar)
   {
      if(g_bufferEdicao == "")
         ObjectSetString(0, campo, OBJPROP_TEXT, g_bufferEdicaoOriginal);
      else
         ObjectSetString(0, campo, OBJPROP_TEXT, g_bufferEdicao);
      AtualizarCampos();
      EscreverValorCampoEdit(campo);   // ex.: lote "3" vira "3.00"
      SalvarConfigPainelPerfil(g_setupAtivo);
      ReconciliarLinhasTrailing();
      AtualizarRotulosSLTP();
   }
   else
      ObjectSetString(0, campo, OBJPROP_TEXT, g_bufferEdicaoOriginal);

   AplicarDestaqueCampoEdit(campo, false);
   g_campoEditAtivo = "";
   g_bufferEdicao = "";
   g_bufferEdicaoOriginal = "";
   g_substituirBufferEdicao = false;
   AtivarTecladoEdicaoCampo(false);
   RestaurarStatusPronto();
   ChartRedraw(0);
}

void CancelarEdicaoCampoAtiva()
{
   if(g_campoEditAtivo == "") return;
   FinalizarEdicaoCampo(false);
}

void IniciarEdicaoCampo(const string nomeCampo)
{
   if(!EhCampoEditavelPainel(nomeCampo) || g_painelBloqueado) return;
   if(ObjectFind(0, nomeCampo) < 0) return;

   if(g_campoEditAtivo != "" && g_campoEditAtivo != nomeCampo)
      FinalizarEdicaoCampo(true);

   ObjectSetInteger(0, nomeCampo, OBJPROP_STATE, false);

   g_campoEditAtivo = nomeCampo;
   g_bufferEdicaoOriginal = ObjectGetString(0, nomeCampo, OBJPROP_TEXT);
   g_bufferEdicao = g_bufferEdicaoOriginal;
   g_substituirBufferEdicao = true;
   AplicarDestaqueCampoEdit(nomeCampo, true);
   AtivarTecladoEdicaoCampo(true);
   ChartSetInteger(ChartID(), CHART_BRING_TO_TOP, true);
   Status(SP_MSG_EDITANDO, C_ACCENT_COLOR, false, true);
   ChartRedraw(0);
}

void ProcessarTeclaEdicaoCampo(const int key)
{
   if(g_campoEditAtivo == "") return;

   if(key == 13)
   {
      FinalizarEdicaoCampo(true);
      return;
   }
   if(key == 27)
   {
      FinalizarEdicaoCampo(false);
      return;
   }
   if(key == 8)
   {
      int len = StringLen(g_bufferEdicao);
      if(len > 0)
         g_bufferEdicao = StringSubstr(g_bufferEdicao, 0, len - 1);
      g_substituirBufferEdicao = false;
      AtualizarTextoCampoEditBuffer();
      return;
   }
   if(key == 46)
   {
      g_bufferEdicao = "";
      g_substituirBufferEdicao = false;
      AtualizarTextoCampoEditBuffer();
      return;
   }

   bool ehDecimal = (key == 190 || key == 110 || key == 188 || key == 44);
   if(ehDecimal)
   {
      if(g_campoEditAtivo != OBJ_EDIT_LOTE)
         return;
      if(StringFind(g_bufferEdicao, ".") >= 0 || StringFind(g_bufferEdicao, ",") >= 0)
         return;
      if(g_substituirBufferEdicao)
      {
         g_bufferEdicao = ".";
         g_substituirBufferEdicao = false;
      }
      else
         g_bufferEdicao += ".";
      AtualizarTextoCampoEditBuffer();
      return;
   }

   string dig = "";
   if(!TeclaDigitoEdicao(key, dig)) return;

   if(g_substituirBufferEdicao)
   {
      g_bufferEdicao = dig;
      g_substituirBufferEdicao = false;
   }
   else
      g_bufferEdicao += dig;

   AtualizarTextoCampoEditBuffer();
}

void RemoverDecorBotao(const string name)
{
   ObjectDelete(0, name + "_LBL");
   ObjectDelete(0, name + "_BG");
   ObjectDelete(0, name + "_TOP");
   ObjectDelete(0, name + "_BOT");
   ObjectDelete(0, name + "_C1");
   ObjectDelete(0, name + "_C2");
   ObjectDelete(0, name + "_C3");
   ObjectDelete(0, name + "_C4");
}

void AplicarEstiloBotaoExec(const string name, const bool press)
{
   if(ObjectFind(0, name) < 0) return;

   RemoverDecorBotao(name);

   color bg  = C_BTN_BG;
   color brd = C_BTN_BORDER;
   color txt = C_BTN_TEXT;

   if(name == OBJ_BTN_BUY)
   {
      bg  = press ? C_EXEC_BUY_PRESS : C_EXEC_BUY_BG;
      brd = bg;
      txt = C_EXEC_TEXT_ON;
   }
   else if(name == OBJ_BTN_CLOSEALL)
   {
      bg  = press ? C_EXEC_CLOSE_PRESS : C_EXEC_CLOSE_BG;
      brd = C_BTN_BORDER;
      txt = C_NOME_COLOR;
   }
   else if(name == OBJ_BTN_SELL)
   {
      bg  = press ? C_EXEC_SELL_PRESS : C_EXEC_SELL_BG;
      brd = bg;
      txt = C_EXEC_TEXT_ON;
   }
   if(g_painelBloqueado)
   {
      bg  = C_BTN_BG_PRESS;
      brd = C_BTN_BORDER;
      txt = C_MUTED;
   }

   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, BTN_EXEC_FONT_SIZE);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
   // rotulos sobrepostos (nome + tecla de atalho)
   if(ObjectFind(0, name + "_T1") >= 0) ObjectSetInteger(0, name + "_T1", OBJPROP_COLOR, txt);
   if(ObjectFind(0, name + "_T2") >= 0) ObjectSetInteger(0, name + "_T2", OBJPROP_COLOR, txt);

}

void AplicarEstiloBotaoAux(const string name, const bool press)
{
   if(ObjectFind(0, name) < 0) return;

   RemoverDecorBotao(name);

   if(name != OBJ_BTN_SETUP && name != OBJ_BTN_SYNC_HL && name != OBJ_BTN_LIMITS && name != OBJ_BTN_LINHAS)
      return;

   color bg  = press ? C_AUX_LIMITS_PRESS : C_AUX_LIMITS_BG;
   color brd = C_AUX_LIMITS_BRD;
   color txt = C_NOME_COLOR;

   if(name == OBJ_BTN_SETUP)
   {
      if(SetupVolatilAtivo())
         txt = C_SETUP_VOL_BG;
      ObjectSetString(0, name, OBJPROP_TEXT, NomeSetupAtivo());
   }
   else if(name == OBJ_BTN_SYNC_HL)
      ObjectSetString(0, name, OBJPROP_TEXT, "SYNC");
   else if(name == OBJ_BTN_LINHAS)
      ObjectSetString(0, name, OBJPROP_TEXT, "LINHAS");
   else
      ObjectSetString(0, name, OBJPROP_TEXT, "LIMITES");

   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

bool EhBotaoExecPainel(const string name)
{
   return (name == OBJ_BTN_BUY || name == OBJ_BTN_SELL || name == OBJ_BTN_CLOSEALL
           || name == OBJ_BTN_SYNC_HL || name == OBJ_BTN_LIMITS || name == OBJ_BTN_LINHAS
           || name == OBJ_BTN_SETUP || name == OBJ_BTN_MINIMIZE || name == OBJ_BTN_CLOSE);
}

void AplicarEstiloBotao(const string name, bool press)
{
   if(ObjectFind(0, name) < 0) return;
   if(name == OBJ_BTN_PARCIAIS) { AtualizarBotaoParciais(); return; }
   if(name == OBJ_BTN_PERF_N || name == OBJ_BTN_PERF_V) { AtualizarSegmentoPerfil(); return; }

   RemoverDecorBotao(name);

   color bg  = press ? C_BTN_BG_PRESS : C_BTN_BG;
   color brd = press ? C_BTN_BORDER_PRESS : C_BTN_BORDER;
   color txt = C_BTN_TEXT;
   if(g_painelBloqueado && EhBotaoExecPainel(name)
      && name != OBJ_BTN_CLOSE && name != OBJ_BTN_LIMITS && name != OBJ_BTN_LINHAS
      && name != OBJ_BTN_SETUP && name != OBJ_BTN_MINIMIZE)
      txt = C_MUTED;

   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, txt);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);

   if(name == OBJ_BTN_MINIMIZE)
   {
      ObjectSetString(0, name, OBJPROP_TEXT, g_painelMinimizado ? "+" : "-");
      return;
   }

   if(name == OBJ_BTN_SETUP || name == OBJ_BTN_SYNC_HL || name == OBJ_BTN_LIMITS || name == OBJ_BTN_LINHAS)
   {
      AplicarEstiloBotaoAux(name, press);
      return;
   }

   if(name == OBJ_BTN_BUY || name == OBJ_BTN_SELL || name == OBJ_BTN_CLOSEALL)
   {
      AplicarEstiloBotaoExec(name, press);
      return;
   }
}

void AtualizarEstadoLimitesUI()
{
   bool bloq = g_painelBloqueado || EA_EstaBloqueado();

   if(ObjectFind(0, OBJ_LIM_STATE) >= 0)
   {
      ObjectSetString(0, OBJ_LIM_STATE, OBJPROP_TEXT, bloq ? "BLOQUEADO" : "LIBERADO");
      ObjectSetInteger(0, OBJ_LIM_STATE, OBJPROP_COLOR, bloq ? C_STATUS_ERR : C_STATUS_OK);
   }
   if(ObjectFind(0, "SP_MET_STBG") >= 0)
   {
      ObjectSetInteger(0, "SP_MET_STBG", OBJPROP_BGCOLOR, bloq ? C_TINT_ERR_BG : C_TINT_OK_BG);
      ObjectSetInteger(0, "SP_MET_STBG", OBJPROP_COLOR, bloq ? C_TINT_ERR_BG : C_TINT_OK_BG);
      ObjectSetInteger(0, "SP_MET_STBG", OBJPROP_BORDER_COLOR, bloq ? C_TINT_ERR_BG : C_TINT_OK_BG);
   }

   if(ObjectFind(0, OBJ_BTN_LIMITS) >= 0)
      AplicarEstiloBotaoAux(OBJ_BTN_LIMITS, false);
}

void GarantirBotaoLimites()
{
   if(ObjectFind(0, OBJ_BTN_LIMITS) < 0) return;

   AplicarEstiloBotaoAux(OBJ_BTN_LIMITS, false);
   ObjectSetInteger(0, OBJ_BTN_LIMITS, OBJPROP_YSIZE, SEC_AUX_BTN_H);
   ObjectSetString(0, OBJ_BTN_LIMITS, OBJPROP_TOOLTIP, "Limites do dia (PIN)");
   ObjectSetInteger(0, OBJ_BTN_LIMITS, OBJPROP_ZORDER, 6);

   if(ObjectFind(0, OBJ_LIMITS_ICON) >= 0)
      ObjectDelete(0, OBJ_LIMITS_ICON);

   AtualizarEstadoLimitesUI();
}

bool EhCampoEditavelPainel(const string name)
{
   return EhCampoParametroPainel(name);
}

bool ObjetoPainelRestauravel(const string name)
{
   if(StringFind(name, "SP_") != 0) return false;
   if(StringFind(name, "SPM_") == 0) return false;
   if(StringFind(name, SPL_PREFIX) == 0) return false;
   if(name == OBJ_CANDLE_TIMER) return false;
   if(EhObjetoLinhaSyncCopiada(name)) return false;
   if(EhObjetoLinhaSLTPGrafico(name)) return false;
   if(StringFind(name, "SP_TRAIL_") == 0) return false;
   if(StringFind(name, "SP_SLPTS_") == 0) return false;
   if(StringFind(name, "SP_TPPTS_") == 0) return false;
   return true;
}

bool ObjetoPainelColapsavel(const string name)
{
   if(!ObjetoPainelRestauravel(name)) return false;
   if(ObjetoPainelSempreVisivel(name)) return false;
   return true;
}

// Exibir um objeto tambem o traz para a frente. Com cartoes por tras dos campos, a ordem
// importa: fundos primeiro, depois campos/botoes/rotulos, por ultimo os textos dos botoes.
int CamadaObjetoPainel(const string nome)
{
   if(nome == "SP_CARD_PAR" || nome == "SP_CARD_PARC" || nome == "SP_PERF_BG") return 0;
   if(nome == OBJ_P1_STATUS_BG || nome == OBJ_P2_STATUS_BG) return 1;
   int n = StringLen(nome);
   if(n > 3)
   {
      string suf = StringSubstr(nome, n - 3);
      if(suf == "_T1" || suf == "_T2") return 3;   // textos sobre COMPRA/FECHA/VENDA
   }
   return 2;
}

void ExibirSecoesPainelEmCamadas()
{
   for(int camada = 0; camada <= 3; camada++)
   {
      for(int i = 0; i < ObjectsTotal(0, -1, -1); i++)
      {
         string nome = ObjectName(0, i, -1, -1);
         if(!ObjetoPainelColapsavel(nome)) continue;
         if(CamadaObjetoPainel(nome) != camada) continue;
         ExibirObjetoPainel(nome);
         if(EhCampoEditavelPainel(nome))
            ConfigurarCampoEditavel(nome);
      }
   }
}

void RestaurarVisibilidadeCamposPainel()
{
   ExibirSecoesPainelEmCamadas();
}

void GarantirPainelNaFrente()
{
   ChartSetInteger(ChartID(), CHART_FOREGROUND, false);

   for(int i = 0; i < ObjectsTotal(0, 0, -1); i++)
   {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, "SP_") != 0) continue;
      if(StringFind(name, "SP_TRAIL_") == 0) continue;
      if(EhObjetoLinhaSLTPGrafico(name)) continue;
      if(StringFind(name, "SP_SLPTS_") == 0) continue;
      if(StringFind(name, "SP_TPPTS_") == 0) continue;
      if(EhObjetoLinhaSyncCopiada(name)) continue;

      long tipo = ObjectGetInteger(0, name, OBJPROP_TYPE);
      if(EhCampoEditavelPainel(name))
         ConfigurarCampoEditavel(name);
      else if(tipo == OBJ_BUTTON || tipo == OBJ_LABEL || tipo == OBJ_RECTANGLE_LABEL)
         ObjectSetInteger(0, name, OBJPROP_BACK, false);
   }
}

void CreateGlassRect(const string name, const int x, const int y, const int w, const int h)
{
   CreateRect(name, x, y, w, h, C_GLASS_BG, C_GLASS_BORDER);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void AplicarLabelMetrica(const string name)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 50);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

void GarantirMetricasStatusNaFrente()
{
   string metricas[] = {"SP_OPS_LBL", "SP_PTS_LBL", "SP_SPR_LBL",
                        OBJ_TXT_OPS, OBJ_TXT_PTS, OBJ_TXT_SPREAD, OBJ_LIM_STATE};
   for(int i = 0; i < ArraySize(metricas); i++)
      AplicarLabelMetrica(metricas[i]);

   if(ObjectFind(0, OBJ_STATUS_STRIP) >= 0)
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_ZORDER, 1);
   if(ObjectFind(0, OBJ_TXT_STATUS) >= 0)
      ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_ZORDER, 50);

   if(ObjectFind(0, OBJ_METRICS_BG) >= 0)
      ObjectSetInteger(0, OBJ_METRICS_BG, OBJPROP_ZORDER, 0);
   for(int d = 1; d <= 3; d++)
   {
      string dn = "SP_MET_DIV" + IntegerToString(d);
      if(ObjectFind(0, dn) >= 0)
         ObjectSetInteger(0, dn, OBJPROP_ZORDER, 2);
   }
}

color CorRotuloParametro(const string lblName)
{
   if(lblName == "SP_TR") return TrailDinamicoAtivo() ? C_STEP_ROTULO : C_TRAIL_FIXO_ACCENT;
   return C_LABEL_COLOR;
}

color CorRotuloMetricaStatus(const string lblName)
{
   return C_LABEL_COLOR;
}

color CorValorPtsPainel(const double pts)
{
   return C_NOME_COLOR;
}

void AplicarEstiloRotuloMetricaStatus(const string lblName)
{
   if(ObjectFind(0, lblName) < 0) return;
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, CorRotuloMetricaStatus(lblName));
   AplicarLabelMetrica(lblName);
}

string TextoRotuloParametro(const string lblName)
{
   if(lblName == "SP_LOTE") return "Lote";
   if(lblName == "SP_TP")   return "Take profit";
   if(lblName == "SP_SL")   return "Stop loss";
   if(lblName == "SP_TR")   return TrailDinamicoAtivo() ? "DINAMICO" : "FIXO";   // etiqueta clicavel do modo
   if(lblName == "SP_ST")   return "Trail / Step";
   return "";
}

void AplicarEstiloRotuloParametro(const string lblName)
{
   if(ObjectFind(0, lblName) < 0) return;
   ObjectSetString(0, lblName, OBJPROP_TEXT, TextoRotuloParametro(lblName));
   ObjectSetInteger(0, lblName, OBJPROP_COLOR, CorRotuloParametro(lblName));
   ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
   if(lblName == "SP_TR")
   {
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, true);
      ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 10);
      ObjectSetString(0, lblName, OBJPROP_TOOLTIP,
                     TrailDinamicoAtivo()
                     ? "Distancia = Trail - Step | avanca a cada Step pts (clique = fixo)"
                     : "Trail fixo (clique = dinamico)");
   }
   else
      ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
}

void CreateParamRowHoriz(const string lblName, const string editName, const int x, const int y,
                         const int fldW, const string label, const string value)
{
   int lblY  = y + (PARAM_FLD_H - PARAM_LBL_FS_H) / 2 + 1;
   int editX = x + PARAM_LBL_W + PARAM_LBL_GAP;
   CreateLabel(lblName, x, lblY, label, CorRotuloParametro(lblName), 8);
   AplicarEstiloRotuloParametro(lblName);
   CreateEditCampoParam(editName, editX, y, value, fldW, PARAM_FLD_H);
}

void GarantirTextoBotaoSync()
{
   if(ObjectFind(0, OBJ_BTN_LINHAS) >= 0)
      AplicarEstiloBotaoAux(OBJ_BTN_LINHAS, false);
   if(ObjectFind(0, OBJ_BTN_SYNC_HL) < 0) return;
   AplicarEstiloBotaoAux(OBJ_BTN_SYNC_HL, false);
}

void ProcessarCliqueBotaoPainel(const string btn)
{
   if(btn == "") return;

   bool execucao = (btn == OBJ_BTN_BUY || btn == OBJ_BTN_SELL || btn == OBJ_BTN_CLOSEALL);

   if(execucao)
   {
      if(g_campoEditAtivo != "")
         FinalizarEdicaoCampoParaExecucao();
   }
   else if(g_campoEditAtivo != "")
      FinalizarEdicaoCampo(true);

   if(g_painelBloqueado && btn != OBJ_BTN_MINIMIZE && btn != OBJ_BTN_CLOSE
      && btn != OBJ_BTN_LIMITS && btn != OBJ_BTN_SETUP && btn != OBJ_BTN_LINHAS
      && btn != OBJ_BTN_PERF_N && btn != OBJ_BTN_PERF_V)
      return;

   ulong agoraClique = GetTickCount64();
   if(agoraClique - ultimoCliqueMs < 250) return;
   ultimoCliqueMs = agoraClique;

   ObjectSetInteger(0, btn, OBJPROP_STATE, false);

   if(btn == OBJ_BTN_BUY) { BuyOrder(); ProcessarStatusAgendado(); EstiloBotaoNormal(btn); return; }
   if(btn == OBJ_BTN_SELL) { SellOrder(); ProcessarStatusAgendado(); EstiloBotaoNormal(btn); return; }
   if(btn == OBJ_BTN_CLOSEALL) { CloseAll(); ProcessarStatusAgendado(); EstiloBotaoNormal(btn); return; }

   FeedbackClickBotao(btn);
   ulong tPress = GetTickCount64();

   if(btn == OBJ_BTN_SYNC_HL) SincronizarLinhasHorizontais();
   else if(btn == OBJ_BTN_LINHAS) LinhasCarregar(true);
   else if(btn == OBJ_BTN_PARCIAIS) ToggleParciaisSistema();
   else if(btn == OBJ_BTN_PERF_N) { if(SetupVolatilAtivo())  AlternarPerfilSetup(); }
   else if(btn == OBJ_BTN_PERF_V) { if(!SetupVolatilAtivo()) AlternarPerfilSetup(); }
   else if(btn == OBJ_BTN_LOTE_DN) AjustarLotePasso(-1);
   else if(btn == OBJ_BTN_LOTE_UP) AjustarLotePasso(1);
   else if(btn == OBJ_BTN_TP_DN) AjustarPontosPasso(OBJ_EDIT_TP, -1);
   else if(btn == OBJ_BTN_TP_UP) AjustarPontosPasso(OBJ_EDIT_TP, 1);
   else if(btn == OBJ_BTN_SL_DN) AjustarPontosPasso(OBJ_EDIT_SL, -1);
   else if(btn == OBJ_BTN_SL_UP) AjustarPontosPasso(OBJ_EDIT_SL, 1);
   else if(btn == OBJ_BTN_LIMITS) AbrirPopupLimites();
   else if(btn == OBJ_BTN_SETUP)    AlternarPerfilSetup();
   else if(btn == OBJ_BTN_MINIMIZE) ToggleMinimizarPainel();
   else if(btn == OBJ_BTN_CLOSE) ObjectsDeleteAll(0, "SP_");

   if(btn != OBJ_BTN_CLOSE)
   {
      ulong elapsed = GetTickCount64() - tPress;
      if(elapsed < (ulong)BTN_PRESS_MIN_MS)
         Sleep((uint)(BTN_PRESS_MIN_MS - elapsed));
      EstiloBotaoNormal(btn);
   }
   ChartRedraw(0);
}

string ResolverCliqueBotaoPainel(const string sparam)
{
   if(sparam == OBJ_BTN_BUY || sparam == OBJ_BTN_SELL || sparam == OBJ_BTN_CLOSEALL
      || sparam == OBJ_BTN_SYNC_HL || sparam == OBJ_BTN_LIMITS || sparam == OBJ_BTN_LINHAS
      || sparam == OBJ_BTN_PARCIAIS || sparam == OBJ_BTN_PERF_N || sparam == OBJ_BTN_PERF_V
      || sparam == OBJ_BTN_LOTE_DN || sparam == OBJ_BTN_LOTE_UP
      || sparam == OBJ_BTN_TP_DN || sparam == OBJ_BTN_TP_UP || sparam == OBJ_BTN_SL_DN || sparam == OBJ_BTN_SL_UP
      || sparam == OBJ_BTN_SETUP || sparam == OBJ_BTN_MINIMIZE || sparam == OBJ_BTN_CLOSE)
      return sparam;

   if(StringFind(sparam, OBJ_BTN_BUY + "_") == 0) return OBJ_BTN_BUY;
   if(StringFind(sparam, OBJ_BTN_SELL + "_") == 0) return OBJ_BTN_SELL;
   if(StringFind(sparam, OBJ_BTN_CLOSEALL + "_") == 0) return OBJ_BTN_CLOSEALL;
   if(StringFind(sparam, OBJ_BTN_LIMITS + "_") == 0) return OBJ_BTN_LIMITS;
   if(StringFind(sparam, OBJ_BTN_LINHAS + "_") == 0) return OBJ_BTN_LINHAS;
   if(StringFind(sparam, OBJ_BTN_SETUP + "_") == 0) return OBJ_BTN_SETUP;
   if(StringFind(sparam, OBJ_BTN_MINIMIZE + "_") == 0) return OBJ_BTN_MINIMIZE;
   if(StringFind(sparam, OBJ_BTN_CLOSE + "_") == 0) return OBJ_BTN_CLOSE;

   if(StringFind(sparam, OBJ_BTN_SYNC_HL + "_") == 0)
   {
      if(EhObjetoLinhaSyncCopiada(sparam)) return "";
      return OBJ_BTN_SYNC_HL;
   }

   return "";
}

bool EhBotaoPainelSP(const string name)
{
   return (ResolverCliqueBotaoPainel(name) != "");
}

void EstiloBotaoNormal(const string name)
{
   AplicarEstiloBotao(name, false);
}

void FeedbackClickBotao(const string name)
{
   AplicarEstiloBotao(name, true);
   ChartRedraw(0);
}

void CreateButton(string name, int x, int y, int w, int h, string text, int fontSize)
{
   if(ObjectFind(0, name) < 0)
      ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);

   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetString(0, name, OBJPROP_FONT, "Arial");
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, false);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, 5);
   RemoverDecorBotao(name);
   AplicarEstiloBotao(name, false);
}

void CreateDivider(string name, int x, int y, int w, color lineColor)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, 1);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, lineColor);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateRect(string name, int x, int y, int w, int h, color bg, color border = clrNONE)
{
   if(ObjectFind(0, name) < 0) ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bg);
   color brd = (border != clrNONE) ? border : bg;
   ObjectSetInteger(0, name, OBJPROP_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, brd);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
}

void CreateSectionTitle(string divName, string bgName, string lblName,
                        int x, int y, int w, int titleCX, string text,
                        color secColor, int bgW, color lineColor, int lineStopX = 0)
{
   int lblPad  = 4;
   int lblFs   = 8;
   int lblH    = 12;
   int lblW    = (int)StringLen(text) * 8 + lblPad * 2;
   int lblY    = y;
   int divY    = lblY + lblH / 2;
   int lineEnd = (lineStopX > 0) ? lineStopX : (x + w);
   int lineX   = x + lblW + SEC_TITLE_GAP;
   int lineW   = lineEnd - lineX;

   if(ObjectFind(0, bgName) >= 0)
      ObjectDelete(0, bgName);

   if(lineW > 4)
      CreateDivider(divName, lineX, divY, lineW, C_DIVIDER_LIGHT);

   CreateLabel(lblName, x + lblPad, lblY, text, secColor, lblFs, true);
   ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 3);
   ObjectSetInteger(0, lblName, OBJPROP_BACK, false);
   ObjectSetInteger(0, lblName, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
}

void ExibirObjetoPainel(const string name)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, WRONG_VALUE);
   ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);
}

void ReposicionarObjetoXY(const string name, const int x, const int y)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
}

void DefinirVisibilidadeObjeto(const string name, const bool visivel)
{
   if(ObjectFind(0, name) < 0) return;
   if(visivel)
      ExibirObjetoPainel(name);
   else
      ObjectSetInteger(0, name, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
}

void ReposicionarParamRowLayout(const string lblName, const string editName,
                                const int x, const int y, const int fldW)
{
   int lblY  = y + (PARAM_FLD_H - PARAM_LBL_FS_H) / 2 + 1;
   int editX = x + PARAM_LBL_W + PARAM_LBL_GAP;
   ReposicionarObjetoXY(lblName, x, lblY);
   ReposicionarObjetoXY(editName, editX, y);
   if(ObjectFind(0, editName) >= 0)
   {
      ObjectSetInteger(0, editName, OBJPROP_XSIZE, fldW);
      if(EhCampoParametroPainel(editName))
         ObjectSetInteger(0, editName, OBJPROP_ALIGN, ALIGN_LEFT);
   }
   AplicarEstiloRotuloParametro(lblName);
   ExibirObjetoPainel(lblName);
   ExibirObjetoPainel(editName);
}

void ReposicionarTituloSecaoLayout(const string divName, const string lblName,
                                   const int x, const int y, const int w,
                                   const string text, const int lineStopX = 0)
{
   int lblPad  = 4;
   int lblH    = 12;
   int lblW    = (int)StringLen(text) * 8 + lblPad * 2;
   int divY    = y + lblH / 2;
   int lineEnd = (lineStopX > 0) ? lineStopX : (x + w);
   int lineX   = x + lblW + SEC_TITLE_GAP;
   int lineW   = lineEnd - lineX;

   ReposicionarObjetoXY(lblName, x + lblPad, y);
   if(ObjectFind(0, divName) >= 0 && lineW > 4)
   {
      ObjectSetInteger(0, divName, OBJPROP_XDISTANCE, lineX);
      ObjectSetInteger(0, divName, OBJPROP_YDISTANCE, divY);
      ObjectSetInteger(0, divName, OBJPROP_XSIZE, lineW);
   }
   ExibirObjetoPainel(lblName);
   ExibirObjetoPainel(divName);
}

void ReposicionarGlassBoxLayout(const string name, const int x, const int y,
                                const int w, const int h, const int zorder = 1)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
   ObjectSetInteger(0, name, OBJPROP_ZORDER, zorder);
   ExibirObjetoPainel(name);
}

void ReposicionarBotoesExec(const int lx, const int divW, const int yExec)
{
   int btnW = (divW - EXEC_BTN_GAP * 2) / 3;
   int ex   = lx;

   string botoesExec[] = {OBJ_BTN_BUY, OBJ_BTN_CLOSEALL, OBJ_BTN_SELL};
   for(int i = 0; i < ArraySize(botoesExec); i++)
   {
      if(ObjectFind(0, botoesExec[i]) >= 0)
      {
         ObjectSetInteger(0, botoesExec[i], OBJPROP_XDISTANCE, ex);
         ObjectSetInteger(0, botoesExec[i], OBJPROP_YDISTANCE, yExec);
         ObjectSetInteger(0, botoesExec[i], OBJPROP_XSIZE, btnW);
         ObjectSetInteger(0, botoesExec[i], OBJPROP_YSIZE, EXEC_BTN_H);
         ExibirObjetoPainel(botoesExec[i]);
      }
      ex += btnW + EXEC_BTN_GAP;
   }
}

void ReposicionarBotoesAux(const int lx, const int divW, const int yAux)
{
   string b[3];
   b[0] = OBJ_BTN_SYNC_HL; b[1] = OBJ_BTN_LINHAS; b[2] = OBJ_BTN_LIMITS;
   int w = (divW - 16) / 3;
   for(int i = 0; i < 3; i++)
   {
      if(ObjectFind(0, b[i]) < 0) continue;
      int x  = lx + i * (w + 8);
      int wi = (i == 2) ? divW - 2 * (w + 8) : w;
      ObjectSetInteger(0, b[i], OBJPROP_XDISTANCE, x);
      ObjectSetInteger(0, b[i], OBJPROP_YDISTANCE, yAux);
      ObjectSetInteger(0, b[i], OBJPROP_XSIZE, wi);
      ObjectSetInteger(0, b[i], OBJPROP_YSIZE, SEC_AUX_BTN_H);
      ExibirObjetoPainel(b[i]);
      AplicarEstiloBotaoAux(b[i], false);
   }
   if(ObjectFind(0, OBJ_BTN_LINHAS) >= 0)
      ObjectSetString(0, OBJ_BTN_LINHAS, OBJPROP_TOOLTIP, "Carregar as linhas do arquivo Common\\Files\\SP_Linhas.txt");
   if(ObjectFind(0, OBJ_BTN_SYNC_HL) >= 0)
      ObjectSetString(0, OBJ_BTN_SYNC_HL, OBJPROP_TOOLTIP, "Copiar as linhas do grafico de estudo");
   GarantirBotaoLimites();
}

void RestaurarLayoutSecoesColapsaveis()
{
   int lx   = PANEL_X + PANEL_PAD;
   int divW = PANEL_W - PANEL_PAD * 2;
   DesenharSecoesPainel(lx, divW, false);   // reposiciona sem mexer no texto dos campos
   ExibirSecoesPainelEmCamadas();
}

bool ObjetoPainelSempreVisivel(const string name)
{
   if(name == OBJ_BORDER || name == OBJ_BG || name == OBJ_HEADER || name == OBJ_HEADER_LINE)
      return true;
   if(name == OBJ_SUBTITLE || name == "SP_VER")
      return true;
   if(name == OBJ_COPY_STATUS || name == OBJ_COPY_STRIP)
      return true;
   if(name == OBJ_BTN_MINIMIZE || name == OBJ_BTN_CLOSE)
      return true;
   if(name == OBJ_TXT_STATUS || name == OBJ_STATUS_STRIP)
      return true;
   if(name == OBJ_METRICS_BG || name == OBJ_LIM_STATE || name == "SP_MET_STBG")
      return true;
   if(name == OBJ_TXT_OPS || name == OBJ_TXT_PTS || name == OBJ_TXT_SPREAD)
      return true;
   if(name == "SP_OPS_LBL" || name == "SP_PTS_LBL" || name == "SP_SPR_LBL")
      return true;
   if(StringFind(name, "SP_MET_DIV") == 0)
      return true;
   return false;
}

void OcultarSecoesPainelColapsadas(const bool ocultar)
{
   if(ocultar)
   {
      for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
      {
         string nome = ObjectName(0, i, -1, -1);
         if(!ObjetoPainelColapsavel(nome)) continue;
         int y = (int)ObjectGetInteger(0, nome, OBJPROP_YDISTANCE);
         if(y < PANEL_Y_MAX_NORMAL)
            ObjectSetInteger(0, nome, OBJPROP_YDISTANCE, y + PANEL_COLAPSE_Y_OFFSET);
         ObjectSetInteger(0, nome, OBJPROP_TIMEFRAMES, OBJ_NO_PERIODS);
      }
      return;
   }

   RestaurarLayoutSecoesColapsaveis();
   RestaurarVisibilidadeCamposPainel();
   GarantirTextoBotaoSync();
}

// Faixa do copiador (abaixo da barra de status): sempre visivel. Com o copiador desligado
// mostra "COPY: DESLIGADO", para um terminal desligado por engano nao passar despercebido.
int AlturaExtraCopia()
{
   return STAT_ROW_H + STAT_STATUS_GAP;
}

int AlturaPainelNormal()
{
   int h = PANEL_HEADER_H + PANEL_ACCENT_H + 10
         + CARD_PAR_H + GAP_CARD + CARD_PARC_H + GAP_CARD_EXEC
         + EXEC_BTN_H + GAP_EXEC_AUX + SEC_AUX_BTN_H + GAP_AUX_MET
         + METRICS_H + GAP_MET_STAT + STAT_ROW_H + 10;
   return h + AlturaExtraCopia();
}
int AlturaPainelMin()    { return PANEL_H_MIN + AlturaExtraCopia(); }

void CriarFaixaCopia(const int lx, const int y, const int divW)
{
   g_copyStatusTxt = "";
   g_copyStatusCor = clrNONE;

   CreateRect(OBJ_COPY_STRIP, lx, y, divW, STAT_ROW_H, CorFaixaStatusFundo(C_LABEL_COLOR), C_GLASS_BORDER);
   ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_SELECTABLE, false);

   // Texto/cor definidos pelo timer do copiador (CopyAtualizarStatusPainel)
   CreateLabelCentered(OBJ_COPY_STATUS, XCentroTextoStatusPainel(lx, divW), YTextoStatusPainel(y),
                       ShortToString(0x25CF) + " COPY", C_LABEL_COLOR, STAT_MSG_FS - 1, true);
   ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_ZORDER, 50);

   if(g_copyModoEf == COPY_DESLIGADO)
   {
      // texto fixo: o timer do copiador nao roda com ele desligado
      bool invalido = (InpCopyModo != COPY_DESLIGADO && !MQLInfoInteger(MQL_TESTER));
      string txt  = ShortToString(0x25CF) + (invalido ? " COPY: CONFIG INVALIDA (VER EXPERTS)" : " COPY: DESLIGADO");
      string dica = invalido ? "O copiador nao iniciou: veja a mensagem na aba Experts"
                             : "Copiador desligado: ajuste 'Modo do copiador' (Mae/Filha) nos parametros do EA";
      ObjectSetString(0, OBJ_COPY_STATUS, OBJPROP_TEXT, txt);
      ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_COLOR, C_STATUS_WARN);
      ObjectSetString(0, OBJ_COPY_STATUS, OBJPROP_TOOLTIP, dica);
      ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_BGCOLOR, CorFaixaStatusFundo(C_STATUS_WARN));
      ObjectSetString(0, OBJ_COPY_STRIP, OBJPROP_TOOLTIP, dica);
   }
}

void ReposicionarFaixaCopia(const int y, const int lx, const int divW)
{
   if(ObjectFind(0, OBJ_COPY_STRIP) >= 0)
   {
      ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_XDISTANCE, lx);
      ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_YDISTANCE, y);
   }
   if(ObjectFind(0, OBJ_COPY_STATUS) >= 0)
   {
      ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_XDISTANCE, XCentroTextoStatusPainel(lx, divW));
      ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_YDISTANCE, YTextoStatusPainel(y));
   }
}

void AplicarAlturaPainel(const int altura)
{
   if(ObjectFind(0, OBJ_BORDER) >= 0)
      ObjectSetInteger(0, OBJ_BORDER, OBJPROP_YSIZE, altura);
   if(ObjectFind(0, OBJ_BG) >= 0)
      ObjectSetInteger(0, OBJ_BG, OBJPROP_YSIZE, altura - 2);
}

void ReposicionarObjetoY(const string name, const int y)
{
   if(ObjectFind(0, name) >= 0)
      ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
}

int YTextoStatusPainel(const int yStat)
{
   return yStat + STAT_ROW_H / 2 + STAT_MSG_Y_NUDGE;
}

int XCentroTextoStatusPainel(const int lx, const int divW)
{
   return lx + divW / 2;
}

void AplicarLayoutTextoStatus(const int yStat, const int lx, const int divW)
{
   if(ObjectFind(0, OBJ_TXT_STATUS) < 0) return;
   ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_XDISTANCE, XCentroTextoStatusPainel(lx, divW));
   ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_YDISTANCE, YTextoStatusPainel(yStat));
   ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_ANCHOR, ANCHOR_CENTER);
   ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_BACK, false);
   ObjectSetInteger(0, OBJ_TXT_STATUS, OBJPROP_ZORDER, 50);
}

void ReposicionarFaixaStatus(const int yStat, const int lx, const int divW)
{
   if(ObjectFind(0, OBJ_STATUS_STRIP) >= 0)
   {
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_XDISTANCE, lx);
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_YDISTANCE, yStat);
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_XSIZE, divW);
      ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_YSIZE, STAT_ROW_H);
   }
}

void CriarFaixaStatus(const int lx, const int y, const int divW)
{
   if(ObjectFind(0, "SP_STATUS_CARD") >= 0)
      ObjectDelete(0, "SP_STATUS_CARD");
   if(ObjectFind(0, "SP_STATUS_DOT") >= 0)
      ObjectDelete(0, "SP_STATUS_DOT");
   if(ObjectFind(0, "SP_STATUS_ACCENT") >= 0)
      ObjectDelete(0, "SP_STATUS_ACCENT");

   CreateRect(OBJ_STATUS_STRIP, lx, y, divW, STAT_ROW_H, C_STATUS_STRIP_BG, C_GLASS_BORDER);
   ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_ZORDER, 1);
   ObjectSetInteger(0, OBJ_STATUS_STRIP, OBJPROP_SELECTABLE, false);

   CreateLabelCentered(OBJ_TXT_STATUS, XCentroTextoStatusPainel(lx, divW), YTextoStatusPainel(y),
                       SP_STATUS_PRONTO, C_STATUS_OK, STAT_MSG_FS, true);
   AplicarLayoutTextoStatus(y, lx, divW);
   AplicarEstiloFaixaStatus(C_STATUS_OK);
}

void PosicionarRotuloMetrica(const string name, const int x, const int y, const ENUM_ANCHOR_POINT anc)
{
   if(ObjectFind(0, name) < 0) return;
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, anc);
}

void ReposicionarSecaoStatus(const bool minimizado)
{
   int lx    = PANEL_X + PANEL_PAD;
   int divW  = PANEL_W - PANEL_PAD * 2;
   int yMet  = minimizado ? (PANEL_Y + PANEL_HEADER_H + PANEL_ACCENT_H + 8) : g_statY_metrics;
   int yStat = yMet + METRICS_H + GAP_MET_STAT;

   ReposicionarFaixaStatus(yStat, lx, divW);
   AplicarLayoutTextoStatus(yStat, lx, divW);
   ReposicionarFaixaCopia(yStat + STAT_ROW_H + STAT_STATUS_GAP, lx, divW);

   ReposicionarObjetoXY(OBJ_METRICS_BG, lx, yMet);
   ReposicionarObjetoXY("SP_MET_STBG", lx + 1, yMet + 1);

   int x0   = lx + MET_STATE_W;
   int colW = (divW - MET_STATE_W) / 3;
   for(int d = 1; d <= 3; d++)
      ReposicionarObjetoXY("SP_MET_DIV" + IntegerToString(d), x0 + colW * (d - 1), yMet + 6);

   int lblY = yMet + 13;
   int valY = yMet + METRICS_H - 5;
   PosicionarRotuloMetrica("SP_OPS_LBL", x0 + colW / 2, lblY, ANCHOR_CENTER);
   PosicionarRotuloMetrica(OBJ_TXT_OPS,  x0 + colW / 2, valY, ANCHOR_LOWER);
   PosicionarRotuloMetrica("SP_PTS_LBL", x0 + colW + colW / 2, lblY, ANCHOR_CENTER);
   PosicionarRotuloMetrica(OBJ_TXT_PTS,  x0 + colW + colW / 2, valY, ANCHOR_LOWER);
   PosicionarRotuloMetrica("SP_SPR_LBL", x0 + colW * 2 + colW / 2, lblY, ANCHOR_CENTER);
   PosicionarRotuloMetrica(OBJ_TXT_SPREAD, x0 + colW * 2 + colW / 2, valY, ANCHOR_LOWER);
   if(ObjectFind(0, "SP_PTS_LBL") >= 0)
      ObjectSetInteger(0, "SP_PTS_LBL", OBJPROP_COLOR, C_LABEL_COLOR);
   PosicionarRotuloMetrica(OBJ_LIM_STATE, lx + MET_STATE_W / 2, yMet + METRICS_H / 2, ANCHOR_CENTER);
}

void AtualizarBotaoMinimizarPainel()
{
   if(ObjectFind(0, OBJ_BTN_MINIMIZE) < 0) return;

   AplicarEstiloBotao(OBJ_BTN_MINIMIZE, false);
   ObjectSetString(0, OBJ_BTN_MINIMIZE, OBJPROP_TEXT, g_painelMinimizado ? "+" : "-");
   ObjectSetString(0, OBJ_BTN_MINIMIZE, OBJPROP_TOOLTIP,
                   g_painelMinimizado ? "Restaurar painel" : "Minimizar painel");
}

void AplicarEstadoMinimizadoPainel()
{
   OcultarSecoesPainelColapsadas(g_painelMinimizado);
   ReposicionarSecaoStatus(g_painelMinimizado);
   AplicarAlturaPainel(g_painelMinimizado ? AlturaPainelMin() : AlturaPainelNormal());
   AtualizarBotaoMinimizarPainel();
   if(ObjectFind(0, OBJ_CANDLE_TIMER) >= 0)
      ExibirObjetoPainel(OBJ_CANDLE_TIMER);
   if(!g_painelMinimizado)
   {
      RestaurarVisibilidadeCamposPainel();
      GarantirCamposEditaveisPainel();
      GarantirMetricasStatusNaFrente();
      GarantirPainelNaFrente();
      GarantirTextoBotaoSync();
      ChartRedraw(0);
   }
}

void ToggleMinimizarPainel()
{
   g_painelMinimizado = !g_painelMinimizado;
   AplicarEstadoMinimizadoPainel();
   ChartRedraw(0);
}

void CriarPainel()
{
   FecharPopupLimites();

   // Em reinits (ex.: troca de timeframe), preserva linhas de trabalho.
   for(int i = ObjectsTotal(0, -1, -1) - 1; i >= 0; i--)
   {
      string nome = ObjectName(0, i, -1, -1);
      if(StringFind(nome, "SP_") != 0) continue;
      if(EhObjetoLinhaSyncCopiada(nome)) continue;
      if(StringFind(nome, "SP_TRAIL_") == 0) continue;
      if(StringFind(nome, "SP_SLPTS_") == 0) continue;
      if(StringFind(nome, "SP_TPPTS_") == 0) continue;
      ObjectDelete(0, nome);
   }

   CreateRect(OBJ_BORDER, PANEL_X, PANEL_Y, PANEL_W, AlturaPainelNormal(), C_BG_COLOR, C_BORDER_COLOR);
   CreateRect(OBJ_BG, PANEL_X + 1, PANEL_Y + 1, PANEL_W - 2, AlturaPainelNormal() - 2, C_BG_COLOR);
   CreateRect(OBJ_HEADER, PANEL_X + 1, PANEL_Y + 1, PANEL_W - 2, PANEL_HEADER_H, C_HEADER_COLOR);
   CreateRect(OBJ_HEADER_LINE, PANEL_X + 1, PANEL_Y + PANEL_HEADER_H,
              PANEL_W - 2, PANEL_ACCENT_H, C_HEADER_ACCENT);

   CreateLabel(OBJ_SUBTITLE, PANEL_X + 12, PANEL_Y + 11, "Scalper Pro", C_NOME_COLOR, 10, true);
   CreateLabel("SP_VER", PANEL_X + 104, PANEL_Y + 14, "v" + SP_EA_VERSAO + "  |  " + _Symbol, C_LABEL_COLOR, 7);
   CreateButton(OBJ_BTN_MINIMIZE, PANEL_X + PANEL_W - 58, PANEL_Y + 8, 22, 20, "-", 9);
   AtualizarBotaoMinimizarPainel();
   CreateButton(OBJ_BTN_CLOSE, PANEL_X + PANEL_W - 30, PANEL_Y + 8, 22, 20, "X", 8);
   ObjectSetInteger(0, OBJ_BTN_CLOSE, OBJPROP_BGCOLOR, C_CLOSE_BTN_BG);
   ObjectSetInteger(0, OBJ_BTN_CLOSE, OBJPROP_BORDER_COLOR, C_CLOSE_BTN_BG);
   ObjectSetInteger(0, OBJ_BTN_CLOSE, OBJPROP_COLOR, C_BTN_TEXT);

   int lx     = PANEL_X + PANEL_PAD;
   int divW   = PANEL_W - PANEL_PAD * 2;

   // --- Cartoes PARAMETROS e PARCIAIS, execucao e acoes (opcao A) ---
   int metY = DesenharSecoesPainel(lx, divW, true);

   // --- ESTADO DO DIA + METRICAS (abaixo das acoes): LIBERADO | Oper | Pontos | Spread ---
   g_statY_metrics = metY;
   CreateGlassRect(OBJ_METRICS_BG, lx, metY, divW, METRICS_H);
   CreateRect("SP_MET_STBG", lx + 1, metY + 1, MET_STATE_W - 1, METRICS_H - 2, C_TINT_OK_BG);
   for(int d = 1; d <= 3; d++)
      CreateRect("SP_MET_DIV" + IntegerToString(d), lx, metY + 6, 1, METRICS_H - 12, C_GLASS_BORDER);

   CreateLabelCentered("SP_OPS_LBL", lx, metY, "Oper", C_LABEL_COLOR, 7);
   AplicarLabelMetrica("SP_OPS_LBL");
   CreateLabelMetricaValor(OBJ_TXT_OPS, lx, metY, "0", C_NOME_COLOR, 11, true);
   AplicarLabelMetrica(OBJ_TXT_OPS);
   CreateLabelCentered("SP_PTS_LBL", lx, metY, "Pontos", C_LABEL_COLOR, 7);
   AplicarLabelMetrica("SP_PTS_LBL");
   if(ObjectFind(0, OBJ_TXT_PTS) >= 0) ObjectDelete(0, OBJ_TXT_PTS);
   CreateLabelMetricaValor(OBJ_TXT_PTS, lx, metY, "0", C_NOME_COLOR, 11, true);
   AplicarLabelMetrica(OBJ_TXT_PTS);
   CreateLabelCentered("SP_SPR_LBL", lx, metY, "Spread", C_LABEL_COLOR, 7);
   AplicarLabelMetrica("SP_SPR_LBL");
   CreateLabelMetricaValor(OBJ_TXT_SPREAD, lx, metY, "0", C_SPREAD_VAL, 11, true);
   AplicarLabelMetrica(OBJ_TXT_SPREAD);
   CreateLabelCentered(OBJ_LIM_STATE, lx, metY, "LIBERADO", C_STATUS_OK, 8, true);
   AplicarLabelMetrica(OBJ_LIM_STATE);

   // --- BARRA DE STATUS (abaixo das metricas) ---
   int statY = metY + METRICS_H + GAP_MET_STAT;
   g_statY_status = statY;
   CriarFaixaStatus(lx, statY, divW);
   CriarFaixaCopia(lx, statY + STAT_ROW_H + STAT_STATUS_GAP, divW);
   if(ObjectFind(0, "SP_D3") >= 0) ObjectDelete(0, "SP_D3");
   if(ObjectFind(0, "SP_SEC_STATUS") >= 0) ObjectDelete(0, "SP_SEC_STATUS");

   GarantirBotaoLimites();

   GarantirCamposEditaveisPainel();
   GarantirMetricasStatusNaFrente();
   GarantirPainelNaFrente();
   AplicarEstadoMinimizadoPainel();
   ChartRedraw(0);
}

void EscreverValorCampoEdit(const string editName)
{
   if(ObjectFind(0, editName) < 0) return;

   if(editName == OBJ_EDIT_LOTE)
      ObjectSetString(0, editName, OBJPROP_TEXT, TextoLote());
   else if(editName == OBJ_EDIT_TP)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(TakeProfit, 0));
   else if(editName == OBJ_EDIT_SL)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(StopLoss, 0));
   else if(editName == OBJ_EDIT_TRAIL_START)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(TrailingStart, 0));
   else if(editName == OBJ_EDIT_TRAIL_STEP)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(TrailingStep, 0));
   else if(editName == OBJ_EDIT_P1_PTS)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(Partial1_Points, 0));
   else if(editName == OBJ_EDIT_P1_PCT)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(Partial1_Close, 0));
   else if(editName == OBJ_EDIT_P2_PTS)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(Partial2_Points, 0));
   else if(editName == OBJ_EDIT_P2_PCT)
      ObjectSetString(0, editName, OBJPROP_TEXT, DoubleToString(Partial2_Close, 0));
}

void AtualizarCampos()
{
   if(ObjectFind(0, OBJ_EDIT_LOTE) >= 0)
   {
      double loteLido = NormalizeVolPainel(StringToDouble(ObjectGetString(0, OBJ_EDIT_LOTE, OBJPROP_TEXT)));
      if(loteLido > 0)
         Lote = loteLido;
   }
   if(ObjectFind(0, OBJ_EDIT_SL) >= 0)
      StopLoss = StringToDouble(ObjectGetString(0, OBJ_EDIT_SL, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_TP) >= 0)
      TakeProfit = StringToDouble(ObjectGetString(0, OBJ_EDIT_TP, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_TRAIL_START) >= 0)
      TrailingStart = StringToDouble(ObjectGetString(0, OBJ_EDIT_TRAIL_START, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_TRAIL_STEP) >= 0)
      TrailingStep = StringToDouble(ObjectGetString(0, OBJ_EDIT_TRAIL_STEP, OBJPROP_TEXT));
   LerCamposParciais();
}

double SpreadEmPips()
{
   GarantirCacheCotacao();
   double spPts = (g_tickAsk - g_tickBid) / _Point;
   int    pipMul = (_Digits == 3 || _Digits == 5) ? 10 : 1;
   return spPts / (double)pipMul;
}

void AtualizarSpread()
{
   if(ObjectFind(0, OBJ_TXT_SPREAD) < 0) return;

   int spread = (int)MathRound(SpreadEmPips());
   if(spread == g_ultimoSpreadPainel) return;

   g_ultimoSpreadPainel = spread;
   ObjectSetString(0, OBJ_TXT_SPREAD, OBJPROP_TEXT, IntegerToString(spread));
   ObjectSetInteger(0, OBJ_TXT_SPREAD, OBJPROP_COLOR, C_SPREAD_VAL);
   AplicarLabelMetrica(OBJ_TXT_SPREAD);
}

//+------------------------------------------------------------------+
//| Copiador NinjaTrader - grava sinais de abertura/fechamento para  |
//| a ponte (bridge) externa ler e replicar no NT8 via ATI.          |
//| Formato da linha: ACAO|TICKET|DIRECAO|VOLUME|PRECO|TIMESTAMP_GMT |
//+------------------------------------------------------------------+
const string SP_COPY_NT_ARQUIVO = "SP_NT_Copy_Signal.txt";

string CopyNT_MontarLinha(const string acao, const ulong ticket, const string direcao,
                          const double volume, const double preco)
{
   return acao + "|" + IntegerToString((long)ticket) + "|" + direcao + "|"
        + DoubleToString(volume, 2) + "|" + DoubleToString(preco, _Digits) + "|"
        + IntegerToString((long)TimeGMT());
}

void CopyNT_GravarSinal(const string linha)
{
   int h = FileOpen(SP_COPY_NT_ARQUIVO, FILE_READ|FILE_WRITE|FILE_TXT|FILE_COMMON|FILE_SHARE_READ|FILE_ANSI);
   if(h == INVALID_HANDLE)
   {
      if(InpLogDetalhado)
         PrintFormat("Scalper Pro: CopyNT falha ao abrir arquivo de sinal, err=%d", GetLastError());
      return;
   }
   FileSeek(h, 0, SEEK_END);
   FileWriteString(h, linha + "\r\n");
   FileClose(h);
}

void CopyNT_EnviarAbertura(const ulong posId, const bool compra, const double volume, const double preco)
{
   if(!InpCopyNT_Ativo || posId == 0) return;
   CopyNT_GravarSinal(CopyNT_MontarLinha("OPEN", posId, compra ? "BUY" : "SELL", volume, preco));
}

void CopyNT_EnviarFechamento(const ulong posId)
{
   if(!InpCopyNT_Ativo || posId == 0) return;
   CopyNT_GravarSinal(CopyNT_MontarLinha("CLOSE", posId, "", 0, 0));
}

void BuyOrder()
{
   if(!PodeOperarRapido()) return;
   if(!TradingPermitido()) { AgendarFalhaTrade(SP_MSG_ERRO_ENT); return; }
   if(TemPosicaoNoSimbolo()) { AgendarStatus(SP_MSG_EM_OP, clrOrange, true); return; }
   if(PendenteBloqueandoEntradaRapido()) { AgendarStatus(SP_MSG_PENDENTE, clrOrange, true, true); return; }

   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == lastOrderBar) { AgendarStatus(SP_MSG_1OP_BARRA, clrOrange, false, true); return; }

   double lote = NormalizeVol(Lote);
   if(lote <= 0) { AgendarStatus(SP_MSG_LOTE_INV, clrRed, true); return; }

   double sl = 0, tp = 0;
   CalcularSLTPMercado(true, sl, tp);

   if(trade.Buy(lote, _Symbol, 0, sl, tp, "SP_Market"))
      lastOrderBar = bar;
   else if(!TradingPermitido())
      AgendarFalhaTrade(SP_MSG_ERRO_ENT);
   else
      Status(SP_MSG_ERRO_ENT, clrRed, true, true);
}

void SellOrder()
{
   if(!PodeOperarRapido()) return;
   if(!TradingPermitido()) { AgendarFalhaTrade(SP_MSG_ERRO_ENT); return; }
   if(TemPosicaoNoSimbolo()) { AgendarStatus(SP_MSG_EM_OP, clrOrange, true); return; }
   if(PendenteBloqueandoEntradaRapido()) { AgendarStatus(SP_MSG_PENDENTE, clrOrange, true, true); return; }

   datetime bar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(bar == lastOrderBar) { AgendarStatus(SP_MSG_1OP_BARRA, clrOrange, false, true); return; }

   double lote = NormalizeVol(Lote);
   if(lote <= 0) { AgendarStatus(SP_MSG_LOTE_INV, clrRed, true); return; }

   double sl = 0, tp = 0;
   CalcularSLTPMercado(false, sl, tp);

   if(trade.Sell(lote, _Symbol, 0, sl, tp, "SP_Market"))
      lastOrderBar = bar;
   else if(!TradingPermitido())
      AgendarFalhaTrade(SP_MSG_ERRO_ENT);
   else
      Status(SP_MSG_ERRO_ENT, clrRed, true, true);
}

void CloseAll()
{
   int nPos = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      if(trade.PositionClose(t))
         nPos++;
   }

   bool tinhaLinha = g_jLinhaArmada || g_lLinhaArmada;
   int  nPend = ExecutarCancelamentoPendentes();

   if(nPos == 0 && (nPend > 0 || tinhaLinha))
      Status(SP_MSG_CANCELADO, clrOrange, true);
}

void CarregarParametrosEntrada()
{
   if(GlobalVariableCheck(GvCfgKey("SETUP")))
      g_setupAtivo = (int)GlobalVariableGet(GvCfgKey("SETUP"));
   else
      g_setupAtivo = (int)InpSetupInicial;

   if(g_setupAtivo != PERFIL_NORMAL && g_setupAtivo != PERFIL_VOLATIL)
      g_setupAtivo = PERFIL_NORMAL;

   if(GlobalVariableCheck(GvCfgKey("TRAIL_MODO")))
   {
      int modo = (int)GlobalVariableGet(GvCfgKey("TRAIL_MODO"));
      g_modoTrail = (modo == (int)TRAIL_DINAMICO) ? TRAIL_DINAMICO : TRAIL_FIXO;
   }
   else
      g_modoTrail = TRAIL_FIXO;

   SincronizarPerfisComInputs();
   CarregarPerfilAtivo();
}

//+------------------------------------------------------------------+
//| Copiador MT5 - contas em terminais da mesma maquina              |
//| A mae grava em Terminal\Common\Files o estado das posicoes do    |
//| simbolo do grafico. A filha le o arquivo a cada                  |
//| InpCopyIntervaloMs e corrige as diferencas: abre, fecha, reduz   |
//| (parcial) e ajusta SL/TP. Copia posicoes, nao sinais: apos um    |
//| reinicio de qualquer lado o estado e reconciliado sozinho.       |
//| Mapeamento de simbolo: cada lado usa o simbolo do proprio        |
//| grafico (ex.: mae em US100, filha em US100.cash).                |
//| Formato do arquivo:                                              |
//|  SPCOPY|1|seq|tickMs|horaServ|login|simbolo|bid|ask|contrato|n   |
//|  P|posId|B/S|volume|entrada|sl|tp|horaAbertura   (n linhas)      |
//|  END|seq                                                         |
//| Cada filha grava SP_CopyAck_<canal>_<conta>.txt a cada 500 ms:   |
//|  ACK|canal|tickMs|login|simbolo|pronta(1/0)                      |
//| para a mae saber quantas filhas estao prontas (indicador painel).|
//+------------------------------------------------------------------+
const int COPY_ACK_MS           = 500;
const int COPY_HEARTBEAT_MS     = 250;    // mae regrava mesmo sem mudanca
const int COPY_MAE_VELHA_MS     = 3000;   // filha nao abre com arquivo mais velho que isso
const int COPY_TENT_MAX         = 3;      // tentativas de abertura por posicao da mae
const int COPY_TENT_INTERV_MS   = 500;
const int COPY_FALHA_INTERV_MS  = 500;    // espera apos falha de modify/close
const int COPY_LIMPEZA_MS       = 2000;

string CopySanitizarCanal(const string c)
{
   string r = "";
   int n = StringLen(c);
   for(int i = 0; i < n && StringLen(r) < 16; i++)
   {
      ushort ch = StringGetCharacter(c, i);
      if((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_' || ch == '-')
         r += ShortToString(ch);
   }
   return (r == "") ? "SP1" : r;
}

string CopyGvX(const ulong idMae) { return g_copyGv + "X_"  + IntegerToString((long)idMae); }
string CopyGvM(const ulong tkt)   { return g_copyGv + "M_"  + IntegerToString((long)tkt); }
string CopyGvMV(const ulong tkt)  { return g_copyGv + "MV_" + IntegerToString((long)tkt); }
string CopyGvSV(const ulong tkt)  { return g_copyGv + "SV_" + IntegerToString((long)tkt); }
string CopyGvOF(const ulong tkt)  { return g_copyGv + "OF_" + IntegerToString((long)tkt); }
string CopyComentario(const ulong idMae) { return "SPC|" + IntegerToString((long)idMae); }


double CopyArredondarVol(const double vol)
{
   double step = LotStep();
   double v = MathRound(vol / step) * step;
   int digits = 0;
   double tmp = step;
   while(tmp < 0.9999 && digits < 8) { tmp *= 10; digits++; }
   return NormalizeDouble(v, digits);
}

//--- Posicao selecionada (PositionSelect*) e copia gerida pelo copiador?
//    No modo LOCAL a copia e gerida pelo proprio EA (SL/TP/trailing do perfil).
bool CopyFilha_GerenciaSelecionada()
{
   return g_copyModoEf == COPY_FILHA && InpCopySLTPModo != COPY_SLTP_LOCAL
          && PositionGetInteger(POSITION_MAGIC) == InpCopyMagic;
}

bool CopyFilha_GerenciaTicket(const ulong t)
{
   if(g_copyModoEf != COPY_FILHA || InpCopySLTPModo == COPY_SLTP_LOCAL) return false;
   if(t == 0 || !PositionSelectByTicket(t)) return false;
   return PositionGetInteger(POSITION_MAGIC) == InpCopyMagic;
}

bool CopyFilha_GerenciaDeal(const ulong dealTkt)
{
   if(g_copyModoEf != COPY_FILHA || InpCopySLTPModo == COPY_SLTP_LOCAL) return false;
   if(dealTkt == 0 || !HistoryDealSelect(dealTkt)) return false;
   return HistoryDealGetInteger(dealTkt, DEAL_MAGIC) == InpCopyMagic;
}

//+------------------------------------------------------------------+
//| Mae                                                              |
//+------------------------------------------------------------------+
string CopyMae_EstadoPosicoes(int &n, string &resumo)
{
   string s = "";
   n = 0;
   resumo = "";
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

      bool compra = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
      s += "P|" + IntegerToString(PositionGetInteger(POSITION_IDENTIFIER)) + "|" + (compra ? "B" : "S") + "|"
         + DoubleToString(PositionGetDouble(POSITION_VOLUME), 8) + "|"
         + DoubleToString(PositionGetDouble(POSITION_PRICE_OPEN), _Digits) + "|"
         + DoubleToString(PositionGetDouble(POSITION_SL), _Digits) + "|"
         + DoubleToString(PositionGetDouble(POSITION_TP), _Digits) + "|"
         + IntegerToString((long)PositionGetInteger(POSITION_TIME)) + "\r\n";
      resumo += (resumo == "" ? "" : "; ") + (compra ? "BUY " : "SELL ")
              + DoubleToString(PositionGetDouble(POSITION_VOLUME), 2)
              + " #" + IntegerToString(PositionGetInteger(POSITION_IDENTIFIER))
              + " SL=" + DoubleToString(PositionGetDouble(POSITION_SL), _Digits)
              + " TP=" + DoubleToString(PositionGetDouble(POSITION_TP), _Digits);
      n++;
   }
   return s;
}

// Grava o estado se mudou ou se o heartbeat venceu. Chamado no OnTradeTransaction
// (antes de qualquer outro processamento da entrada) e no timer.
void CopyMae_Publicar(const bool forcar)
{
   if(g_copyModoEf != COPY_MAE) return;

   int n = 0;
   string resumo = "";
   string estado = CopyMae_EstadoPosicoes(n, resumo);
   ulong agora = GetTickCount64();
   if(!forcar && estado == g_copyMaeUltEstado && agora - g_copyMaeUltEnvioMs < (ulong)COPY_HEARTBEAT_MS)
      return;

   int h = FileOpen(g_copyArquivo, FILE_WRITE|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
   {
      static ulong s_ultErro = 0;
      if(agora - s_ultErro > 5000)
      {
         PrintFormat("Scalper Pro copiador MAE: falha ao gravar %s, err=%d", g_copyArquivo, GetLastError());
         s_ultErro = agora;
      }
      g_copyMaeErroGrav = true;
      return;
   }

   g_copyMaeSeq++;
   string seq = IntegerToString(g_copyMaeSeq);
   string cab = "SPCOPY|1|" + seq + "|" + IntegerToString((long)agora) + "|"
              + IntegerToString((long)TimeCurrent()) + "|"
              + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "|" + _Symbol + "|"
              + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), _Digits) + "|"
              + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_ASK), _Digits) + "|"
              + DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE), 8) + "|"
              + IntegerToString(n) + "\r\n";
   string txt = cab + estado + "END|" + seq + "\r\n";
   FileWriteString(h, txt, StringLen(txt));
   FileClose(h);

   // O horario desta linha no log e o instante da gravacao: compare com
   // "desde gravacao da mae" no log da filha para medir a cadeia completa.
   if(estado != g_copyMaeUltEstado)
      PrintFormat("Scalper Pro copiador MAE: publicado seq=%s | %d posicao(oes)%s | filhas prontas %d/%d",
                  seq, n, (n > 0 ? " | " + resumo : ""), g_copyFilhasProntas, g_copyFilhasN);
   g_copyMaeErroGrav = false;

   g_copyMaeUltEstado  = estado;
   g_copyMaeUltEnvioMs = agora;
}

void CopyMae_LerFilhas()
{
   ulong agora = GetTickCount64();
   if(agora - g_copyFilhasLidoMs < 1000) return;
   g_copyFilhasLidoMs = agora;

   // Ultima leitura valida de cada filha: uma leitura que cai no meio da
   // regravacao do ACK (arquivo vazio/parcial) usa o valor anterior.
   static string s_nome[];
   static ulong  s_tick[];
   static bool   s_pronta[];

   string nome = "";
   string diag = "";   // motivo de cada ACK ignorado (diagnostico de "0 filhas")
   long hf = FileFindFirst("SP_CopyAck_" + g_copyCanal + "_*.txt", nome, FILE_COMMON);
   if(hf == INVALID_HANDLE)
      diag = StringFormat("nenhum arquivo SP_CopyAck_%s_*.txt em %s\\Files (filha parada, canal diferente ou outra pasta Common)",
                          g_copyCanal, TerminalInfoString(TERMINAL_COMMONDATA_PATH));
   if(hf != INVALID_HANDLE)
   {
      do
      {
         int h = FileOpen(nome, FILE_READ|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
         if(h == INVALID_HANDLE) continue;
         int sz = (int)FileSize(h);
         string txt = (sz > 0) ? FileReadString(h, sz) : "";
         FileClose(h);
         StringTrimRight(txt);
         string a[];
         if(StringSplit(txt, '|', a) < 6 || a[0] != "ACK" || a[1] != g_copyCanal)
         {
            diag += (diag == "" ? "" : " | ") + nome + ": conteudo invalido";
            continue;
         }
         ulong tk = (ulong)StringToInteger(a[2]);
         if(tk == 0) continue;
         if(agora > tk && agora - tk > (ulong)COPY_MAE_VELHA_MS)
            diag += (diag == "" ? "" : " | ") + StringFormat("%s: sem atualizacao ha %I64u s (filha parada%s)",
                    nome, (agora - tk) / 1000, (agora - tk) > 86400000 ? " ou em outro computador" : "");

         int k = -1;
         for(int i = 0; i < ArraySize(s_nome); i++)
            if(s_nome[i] == nome) { k = i; break; }
         if(k < 0)
         {
            k = ArraySize(s_nome);
            ArrayResize(s_nome, k + 1);
            ArrayResize(s_tick, k + 1);
            ArrayResize(s_pronta, k + 1);
            s_nome[k] = nome;
         }
         s_tick[k]   = tk;
         s_pronta[k] = (a[5] == "1");
      }
      while(FileFindNext(hf, nome));
      FileFindClose(hf);
   }

   int n = 0, prontas = 0;
   for(int i = 0; i < ArraySize(s_nome); i++)
   {
      if(agora > s_tick[i] && agora - s_tick[i] > (ulong)COPY_MAE_VELHA_MS) continue;
      n++;
      if(s_pronta[i]) prontas++;
   }

   if(n != g_copyFilhasN || prontas != g_copyFilhasProntas)
      PrintFormat("Scalper Pro copiador MAE: filhas conectadas=%d prontas=%d", n, prontas);
   // sem filha conectada: diz o motivo (no maximo a cada 30 s)
   static ulong s_diagMs = 0;
   if(n == 0 && diag != "" && agora - s_diagMs > 30000)
   {
      PrintFormat("Scalper Pro copiador MAE: 0 filhas | %s", diag);
      s_diagMs = agora;
   }
   g_copyFilhasN       = n;
   g_copyFilhasProntas = prontas;
}

//+------------------------------------------------------------------+
//| Filha                                                            |
//+------------------------------------------------------------------+
bool CopyFilha_Pronta()
{
   return TradingPermitido() && PodeOperarRapido();
}

void CopyFilha_GravarAck()
{
   ulong agora = GetTickCount64();
   if(agora - g_copyAckUltMs < (ulong)COPY_ACK_MS) return;
   g_copyAckUltMs = agora;

   string arq = "SP_CopyAck_" + g_copyCanal + "_" + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + ".txt";
   int h = FileOpen(arq, FILE_WRITE|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   string txt = "ACK|" + g_copyCanal + "|" + IntegerToString((long)agora) + "|"
              + IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)) + "|" + _Symbol + "|"
              + (CopyFilha_Pronta() ? "1" : "0") + "\r\n";
   FileWriteString(h, txt, StringLen(txt));
   FileClose(h);
}

// Registra por que uma posicao da mae nao foi copiada (sem repetir a cada ciclo).
void CopyFilha_LogPulo(const ulong idMae, const string motivo)
{
   static ulong  s_id = 0;
   static string s_motivo = "";
   static ulong  s_ms = 0;
   ulong agora = GetTickCount64();
   if(idMae == s_id && motivo == s_motivo && agora - s_ms < 5000) return;
   s_id = idMae;
   s_motivo = motivo;
   s_ms = agora;
   PrintFormat("Scalper Pro copiador FILHA: mae #%I64u nao copiada agora: %s", idMae, motivo);
}

ulong CopyFilha_MsDesdeMae()
{
   ulong agora = GetTickCount64();
   return (agora > g_copyMaeTickMs) ? agora - g_copyMaeTickMs : 0;
}
string CopyLinha(const string &linhas[], const int i)
{
   string l = linhas[i];
   StringTrimRight(l);
   StringTrimLeft(l);
   return l;
}

// Le o arquivo da mae. Retorna false se ausente ou incompleto (gravacao em
// andamento); nesse caso o ultimo estado valido continua em uso.
bool CopyFilha_LerArquivo()
{
   int h = FileOpen(g_copyArquivo, FILE_READ|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return false;
   int sz = (int)FileSize(h);
   string txt = (sz > 0) ? FileReadString(h, sz) : "";
   FileClose(h);
   if(sz <= 0) return false;

   string linhas[];
   int nl = StringSplit(txt, '\n', linhas);
   if(nl < 2) return false;

   string c[];
   if(StringSplit(CopyLinha(linhas, 0), '|', c) < 11 || c[0] != "SPCOPY") return false;
   long seq = StringToInteger(c[2]);
   int  n   = (int)StringToInteger(c[10]);
   if(n < 0 || n > 200 || nl < n + 2) return false;
   if(CopyLinha(linhas, n + 1) != "END|" + c[2]) return false;

   if(seq == g_copyMaeSeqLida && (ulong)StringToInteger(c[3]) == g_copyMaeTickMs)
      return true;   // nada novo

   long srvMae = StringToInteger(c[4]);
   SCopyPosMae tmp[];
   ArrayResize(tmp, n);
   for(int k = 0; k < n; k++)
   {
      string p[];
      if(StringSplit(CopyLinha(linhas, k + 1), '|', p) < 8 || p[0] != "P") return false;
      tmp[k].id       = (ulong)StringToInteger(p[1]);
      tmp[k].compra   = (p[2] == "B");
      tmp[k].vol      = StringToDouble(p[3]);
      tmp[k].open     = StringToDouble(p[4]);
      tmp[k].sl       = StringToDouble(p[5]);
      tmp[k].tp       = StringToDouble(p[6]);
      tmp[k].idadeSeg = srvMae - StringToInteger(p[7]);
   }

   ArrayResize(g_copyMaePos, n);
   for(int k = 0; k < n; k++)
      g_copyMaePos[k] = tmp[k];
   g_copyMaeN        = n;
   g_copyMaeSeqLida  = seq;
   g_copyMaeTickMs   = (ulong)StringToInteger(c[3]);
   g_copyMaeLogin    = StringToInteger(c[5]);
   g_copyMaeSimbolo  = c[6];
   g_copyMaeBid      = StringToDouble(c[7]);
   g_copyMaeAsk      = StringToDouble(c[8]);
   g_copyMaeContrato = StringToDouble(c[9]);
   g_copyMaeValida   = true;
   return true;
}

int CopyFilha_IndiceMae(const ulong idMae)
{
   for(int k = 0; k < g_copyMaeN; k++)
      if(g_copyMaePos[k].id == idMae) return k;
   return -1;
}

// Id da posicao da mae para a posicao selecionada (0 = nao e copia).
ulong CopyFilha_IdMaeSelecionada(const ulong tkt)
{
   if(PositionGetInteger(POSITION_MAGIC) != InpCopyMagic) return 0;
   if(GlobalVariableCheck(CopyGvM(tkt))) return (ulong)GlobalVariableGet(CopyGvM(tkt));
   string cm = PositionGetString(POSITION_COMMENT);
   if(StringFind(cm, "SPC|") == 0) return (ulong)StringToInteger(StringSubstr(cm, 4));
   return 0;
}

// Em conta netting a posicao pode seguir listada por alguns ms apos o
// fechamento confirmado; evita uma segunda ordem de fechamento (ret 10036).
bool CopyFilha_FechadaRecente(const ulong tkt)
{
   ulong agora = GetTickCount64();
   for(int i = ArraySize(g_copyFechadas) - 1; i >= 0; i--)
   {
      if(agora - g_copyFechadas[i].ultMs > 5000) { ArrayRemove(g_copyFechadas, i, 1); continue; }
      if(g_copyFechadas[i].tkt == tkt) return true;
   }
   return false;
}

void CopyFilha_RegistrarFechada(const ulong tkt)
{
   int n = ArraySize(g_copyFechadas);
   ArrayResize(g_copyFechadas, n + 1);
   g_copyFechadas[n].tkt   = tkt;
   g_copyFechadas[n].ultMs = GetTickCount64();
}

bool CopyFilha_FalhaRecente(const ulong tkt)
{
   ulong agora = GetTickCount64();
   for(int i = 0; i < ArraySize(g_copyMod); i++)
      if(g_copyMod[i].tkt == tkt)
         return (agora - g_copyMod[i].ultMs < (ulong)COPY_FALHA_INTERV_MS);
   return false;
}

void CopyFilha_RegistrarFalha(const ulong tkt)
{
   ulong agora = GetTickCount64();
   int n = ArraySize(g_copyMod);
   for(int i = 0; i < n; i++)
      if(g_copyMod[i].tkt == tkt) { g_copyMod[i].ultMs = agora; return; }
   ArrayResize(g_copyMod, n + 1);
   g_copyMod[n].tkt = tkt;
   g_copyMod[n].ultMs = agora;
}

bool CopyFilha_TentativaLiberada(const ulong idMae)
{
   for(int i = 0; i < ArraySize(g_copyTent); i++)
      if(g_copyTent[i].idMae == idMae)
         return (g_copyTent[i].n < COPY_TENT_MAX
                 && GetTickCount64() - g_copyTent[i].ultMs >= (ulong)COPY_TENT_INTERV_MS);
   return true;
}

void CopyFilha_RegistrarTentativa(const ulong idMae)
{
   int n = ArraySize(g_copyTent);
   int k = -1;
   for(int i = 0; i < n; i++)
      if(g_copyTent[i].idMae == idMae) { k = i; break; }
   if(k < 0)
   {
      ArrayResize(g_copyTent, n + 1);
      k = n;
      g_copyTent[k].idMae = idMae;
      g_copyTent[k].n = 0;
   }
   g_copyTent[k].n++;
   g_copyTent[k].ultMs = GetTickCount64();
   if(g_copyTent[k].n >= COPY_TENT_MAX)
   {
      GlobalVariableSet(CopyGvX(idMae), 1.0);
      PrintFormat("Scalper Pro copiador FILHA: desistiu de copiar mae #%I64u apos %d tentativas", idMae, COPY_TENT_MAX);
   }
}

double CopyFilha_Lote(const SCopyPosMae &m, const bool compraF, const double slF)
{
   double v = 0;
   switch(InpCopyLoteModo)
   {
      case COPY_LOTE_BOLETA:
         v = Lote;
         break;
      case COPY_LOTE_FIXO:
         v = InpCopyLoteValor;
         break;
      case COPY_LOTE_NOCIONAL:
      {
         double cF = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_CONTRACT_SIZE);
         if(cF > 0 && g_copyMaeContrato > 0)
            v = m.vol * g_copyMaeContrato / cF * InpCopyLoteValor;
         else
            v = m.vol * InpCopyLoteValor;
         break;
      }
      case COPY_LOTE_RISCO:
      {
         double preco = compraF ? g_tickAsk : g_tickBid;
         double perda = 0;
         if(slF > 0 && OrderCalcProfit(compraF ? ORDER_TYPE_BUY : ORDER_TYPE_SELL, _Symbol, 1.0, preco, slF, perda) && perda < 0)
            v = AccountInfoDouble(ACCOUNT_BALANCE) * InpCopyLoteValor / 100.0 / (-perda);
         else
         {
            v = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
            PrintFormat("Scalper Pro copiador FILHA: lote por risco sem SL valido, usando lote minimo %.2f", v);
         }
         break;
      }
      default:
         v = m.vol * InpCopyLoteValor;
   }

   if(InpCopyLoteMax > 0 && v > InpCopyLoteMax) v = InpCopyLoteMax;
   double nv = NormalizeVol(v);
   if(nv <= 0) nv = NormalizeVol(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   return nv;
}

// SL/TP que a copia deve ter. offset = bid filha - bid mae no momento da copia.
void CopyFilha_NiveisDesejados(const SCopyPosMae &m, const bool compraF, const double openF,
                               const double offset, double &sl, double &tp)
{
   sl = 0;
   tp = 0;
   double mSL = m.sl, mTP = m.tp;
   if(InpCopyInverter) { double x = mSL; mSL = mTP; mTP = x; }

   if(InpCopySLTPModo == COPY_SLTP_PRECO_AJUST)
   {
      if(mSL > 0) sl = mSL + offset;
      if(mTP > 0) tp = mTP + offset;
   }
   else if(InpCopySLTPModo == COPY_SLTP_DISTANCIA)
   {
      if(mSL > 0) sl = openF + (mSL - m.open);
      if(mTP > 0) tp = openF + (mTP - m.open);
   }

   if(sl <= 0 && InpCopySLEmergPts > 0 && InpCopySLTPModo != COPY_SLTP_LOCAL)
   {
      double d = InpCopySLEmergPts * ObterPontoPreco();
      sl = compraF ? openF - d : openF + d;
   }

   sl = (sl > 0) ? NormalizeDouble(sl, _Digits) : 0;
   tp = (tp > 0) ? NormalizeDouble(tp, _Digits) : 0;
}

bool CopyFilha_NivelAtingido(const bool compraF, const double sl, const double tp)
{
   double px = compraF ? g_tickBid : g_tickAsk;
   if(px <= 0) return false;
   if(sl > 0 && (compraF ? px <= sl : px >= sl)) return true;
   if(tp > 0 && (compraF ? px >= tp : px <= tp)) return true;
   return false;
}

void CopyFilha_Fechar(const ulong tkt, const string motivo)
{
   if(CopyFilha_FalhaRecente(tkt) || CopyFilha_FechadaRecente(tkt)) return;
   ulong t0 = GetTickCount64();
   bool ok = g_copyTrade.PositionClose(tkt);
   uint rc = g_copyTrade.ResultRetcode();
   if(ok || rc == TRADE_RETCODE_POSITION_CLOSED)
      CopyFilha_RegistrarFechada(tkt);
   if(ok)
      PrintFormat("Scalper Pro copiador FILHA: copia #%I64u fechada (%s) | execucao %I64u ms | desde gravacao da mae %I64u ms",
                  tkt, motivo, GetTickCount64() - t0, CopyFilha_MsDesdeMae());
   else if(rc != TRADE_RETCODE_POSITION_CLOSED)
   {
      CopyFilha_RegistrarFalha(tkt);
      PrintFormat("Scalper Pro copiador FILHA: falha ao fechar #%I64u (%s) ret=%u", tkt, motivo, rc);
   }
}

void CopyFilha_FecharTodas(const string motivo)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(CopyFilha_IdMaeSelecionada(t) == 0) continue;
      CopyFilha_Fechar(t, motivo);
   }
}

// Confere uma copia existente contra a posicao da mae: direcao, volume e SL/TP.
void CopyFilha_Sincronizar(const ulong t, const SCopyPosMae &m)
{
   if(!PositionSelectByTicket(t)) return;

   bool   compraF = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY);
   double volF    = PositionGetDouble(POSITION_VOLUME);
   double openF   = PositionGetDouble(POSITION_PRICE_OPEN);
   double slAtual = PositionGetDouble(POSITION_SL);
   double tpAtual = PositionGetDouble(POSITION_TP);

   bool compraEsperada = InpCopyInverter ? !m.compra : m.compra;
   if(compraF != compraEsperada)
   {
      // Conta netting: a mae virou a mao. Fecha e libera a nova copia.
      CopyFilha_Fechar(t, "mae inverteu a posicao");
      GlobalVariableDel(CopyGvX(m.id));
      return;
   }

   // Referencias ausentes (ex.: ticket nao resolvido na abertura, EA reiniciado)
   if(!GlobalVariableCheck(CopyGvM(t)))  GlobalVariableSet(CopyGvM(t), (double)m.id);
   if(!GlobalVariableCheck(CopyGvMV(t))) GlobalVariableSet(CopyGvMV(t), m.vol);
   if(!GlobalVariableCheck(CopyGvSV(t))) GlobalVariableSet(CopyGvSV(t), volF);
   if(!GlobalVariableCheck(CopyGvOF(t)))
      GlobalVariableSet(CopyGvOF(t), (g_copyMaeBid > 0 && g_tickBid > 0) ? g_tickBid - g_copyMaeBid : 0.0);

   // Parcial na mae -> reduz a copia na mesma proporcao
   double mv0 = GlobalVariableGet(CopyGvMV(t));
   double sv0 = GlobalVariableGet(CopyGvSV(t));
   if(mv0 > 0 && m.vol < mv0 - VOL_EPSILON)
   {
      double alvo   = CopyArredondarVol(sv0 * m.vol / mv0);
      double fechar = CopyArredondarVol(volF - alvo);
      if(fechar >= LotStep() - VOL_EPSILON)
      {
         if(alvo < SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN) - VOL_EPSILON)
            CopyFilha_Fechar(t, "parcial da mae abaixo do lote minimo");
         else if(!CopyFilha_FalhaRecente(t))
         {
            ulong tp0 = GetTickCount64();
            if(g_copyTrade.PositionClosePartial(t, fechar))
               PrintFormat("Scalper Pro copiador FILHA: parcial #%I64u -%.2f (mae %.2f/%.2f) | execucao %I64u ms | desde gravacao da mae %I64u ms",
                           t, fechar, m.vol, mv0, GetTickCount64() - tp0, CopyFilha_MsDesdeMae());
            else
            {
               CopyFilha_RegistrarFalha(t);
               PrintFormat("Scalper Pro copiador FILHA: falha parcial #%I64u ret=%u", t, g_copyTrade.ResultRetcode());
            }
         }
         return;
      }
   }

   if(InpCopySLTPModo == COPY_SLTP_LOCAL) return;

   double sl = 0, tp = 0;
   CopyFilha_NiveisDesejados(m, compraF, openF, GlobalVariableGet(CopyGvOF(t)), sl, tp);

   // Nivel da mae ja atingido no preco da filha: a filha sai junto.
   if(CopyFilha_NivelAtingido(compraF, sl, tp))
   {
      CopyFilha_Fechar(t, "nivel de SL/TP da mae atingido");
      return;
   }

   double tol = _Point * 0.5;
   if(MathAbs(sl - slAtual) <= tol && MathAbs(tp - tpAtual) <= tol) return;

   double slV = sl, tpV = tp;
   ValidarSLTPBroker(compraF, slV, tpV);
   if(MathAbs(slV - slAtual) <= tol && MathAbs(tpV - tpAtual) <= tol) return;
   if(CopyFilha_FalhaRecente(t)) return;

   g_eaAtualizandoNiveis = true;
   bool ok = g_copyTrade.PositionModify(t, slV, tpV);
   g_eaAtualizandoNiveis = false;
   if(ok)
   {
      GravarReferenciasNiveisEA(t, slV, tpV);
      if(InpLogDetalhado)
         PrintFormat("Scalper Pro copiador FILHA: #%I64u SL=%s TP=%s", t,
                     DoubleToString(slV, _Digits), DoubleToString(tpV, _Digits));
   }
   else
   {
      CopyFilha_RegistrarFalha(t);
      PrintFormat("Scalper Pro copiador FILHA: falha SL/TP #%I64u ret=%u", t, g_copyTrade.ResultRetcode());
   }
}

ulong CopyFilha_TicketAberto(const ulong ordem, const ulong idMae)
{
   if(ordem > 0 && PositionSelectByTicket(ordem)) return ordem;
   string cm = CopyComentario(idMae);
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(PositionGetInteger(POSITION_MAGIC) != InpCopyMagic) continue;
      if(PositionGetString(POSITION_COMMENT) == cm) return t;
   }
   return 0;
}

// Ordem a mercado ja com SL/TP; o ajuste fino pelo preco real de entrada
// acontece no proximo ciclo (CopyFilha_Sincronizar).
void CopyFilha_Abrir(const SCopyPosMae &m)
{
   bool   compraF = InpCopyInverter ? !m.compra : m.compra;
   double precoF  = compraF ? g_tickAsk : g_tickBid;
   if(precoF <= 0) return;
   double offset  = (g_copyMaeBid > 0) ? g_tickBid - g_copyMaeBid : 0.0;

   double sl = 0, tp = 0;
   if(InpCopySLTPModo == COPY_SLTP_LOCAL)
      CalcularSLTPMercado(compraF, sl, tp);
   else
   {
      CopyFilha_NiveisDesejados(m, compraF, precoF, offset, sl, tp);
      if(CopyFilha_NivelAtingido(compraF, sl, tp))
      {
         GlobalVariableSet(CopyGvX(m.id), 1.0);
         PrintFormat("Scalper Pro copiador FILHA: mae #%I64u nao copiada, SL/TP ja atingido no preco da filha", m.id);
         return;
      }
   }
   ValidarSLTPBroker(compraF, sl, tp);

   double lote = CopyFilha_Lote(m, compraF, sl);
   if(lote <= 0)
   {
      GlobalVariableSet(CopyGvX(m.id), 1.0);
      PrintFormat("Scalper Pro copiador FILHA: mae #%I64u nao copiada, lote invalido", m.id);
      return;
   }

   string cm = CopyComentario(m.id);
   ulong  t0 = GetTickCount64();
   bool ok = compraF ? g_copyTrade.Buy(lote, _Symbol, 0, sl, tp, cm)
                     : g_copyTrade.Sell(lote, _Symbol, 0, sl, tp, cm);
   uint rc = g_copyTrade.ResultRetcode();
   ulong t1 = GetTickCount64();

   if(!ok || (rc != TRADE_RETCODE_DONE && rc != TRADE_RETCODE_DONE_PARTIAL && rc != TRADE_RETCODE_PLACED))
   {
      PrintFormat("Scalper Pro copiador FILHA: falha ao copiar mae #%I64u ret=%u %s", m.id, rc, g_copyTrade.ResultRetcodeDescription());
      CopyFilha_RegistrarTentativa(m.id);
      return;
   }

   GlobalVariableSet(CopyGvX(m.id), 1.0);
   ulong tkt = CopyFilha_TicketAberto(g_copyTrade.ResultOrder(), m.id);
   if(tkt > 0)
   {
      GlobalVariableSet(CopyGvM(tkt), (double)m.id);
      GlobalVariableSet(CopyGvMV(tkt), m.vol);
      GlobalVariableSet(CopyGvSV(tkt), lote);
      GlobalVariableSet(CopyGvOF(tkt), offset);
   }

   PrintFormat("Scalper Pro copiador FILHA: %s %.2f %s copiando mae #%I64u (%s %.2f) | execucao %I64u ms | desde gravacao da mae %I64u ms | dif. cotacao %s",
               compraF ? "BUY" : "SELL", lote, _Symbol, m.id, g_copyMaeSimbolo, m.vol,
               t1 - t0, (t1 > g_copyMaeTickMs) ? t1 - g_copyMaeTickMs : 0,
               DoubleToString(offset, _Digits));
}

void CopyFilha_LimparGVs()
{
   int total = GlobalVariablesTotal();
   int lenPref = StringLen(g_copyGv);
   for(int i = total - 1; i >= 0; i--)
   {
      string nm = GlobalVariableName(i);
      if(StringFind(nm, g_copyGv) != 0) continue;
      string resto = StringSubstr(nm, lenPref);
      int p = StringFind(resto, "_");
      if(p <= 0) continue;
      string tipo = StringSubstr(resto, 0, p);
      ulong  id   = (ulong)StringToInteger(StringSubstr(resto, p + 1));
      if(tipo == "X")
      {
         if(CopyFilha_IndiceMae(id) < 0) GlobalVariableDel(nm);
      }
      else if(!PositionSelectByTicket(id))
         GlobalVariableDel(nm);
   }

   // Tentativas / falhas de posicoes que nao existem mais
   for(int i = ArraySize(g_copyTent) - 1; i >= 0; i--)
      if(CopyFilha_IndiceMae(g_copyTent[i].idMae) < 0)
         ArrayRemove(g_copyTent, i, 1);
   for(int i = ArraySize(g_copyMod) - 1; i >= 0; i--)
      if(!PositionSelectByTicket(g_copyMod[i].tkt))
         ArrayRemove(g_copyMod, i, 1);
}

void CopyFilha_Processar()
{
   if(g_copyModoEf != COPY_FILHA) return;

   bool leu = CopyFilha_LerArquivo();
   CopyFilha_GravarAck();
   if(!g_copyMaeValida)
   {
      static ulong s_ultAvisoArq = 0;
      ulong agoraAv = GetTickCount64();
      if(s_ultAvisoArq == 0 || agoraAv - s_ultAvisoArq > 60000)
      {
         PrintFormat("Scalper Pro copiador FILHA: aguardando arquivo da mae (Common\\Files\\%s)", g_copyArquivo);
         s_ultAvisoArq = agoraAv;
      }
      return;
   }

   if(g_copyMaeLogin == AccountInfoInteger(ACCOUNT_LOGIN))
   {
      static bool s_avisou = false;
      if(!s_avisou)
         Print("Scalper Pro copiador FILHA: o arquivo do canal e desta mesma conta; copia ignorada. Use outro canal.");
      s_avisou = true;
      return;
   }

   ulong agora = GetTickCount64();
   ulong idadeArqMs = (agora > g_copyMaeTickMs) ? agora - g_copyMaeTickMs : 0;

   bool maeOnline = (idadeArqMs <= (ulong)COPY_MAE_VELHA_MS);
   if(maeOnline != g_copyMaeOnline)
   {
      if(maeOnline)
         PrintFormat("Scalper Pro copiador FILHA: conectada a mae (conta %I64d, %s) | arquivo com %I64u ms",
                     g_copyMaeLogin, g_copyMaeSimbolo, idadeArqMs);
      else
         PrintFormat("Scalper Pro copiador FILHA: arquivo da mae sem atualizacao ha %I64u ms (mae offline ou EA parado). Novas entradas suspensas.",
                     idadeArqMs);
      g_copyMaeOnline = maeOnline;
   }

   if(InpCopyMaeOfflineSeg > 0 && idadeArqMs > (ulong)InpCopyMaeOfflineSeg * 1000)
   {
      if(!g_copyOfflineFechou)
      {
         PrintFormat("Scalper Pro copiador FILHA: mae sem sinal ha %I64u ms, fechando copias", idadeArqMs);
         g_copyOfflineFechou = true;
      }
      CopyFilha_FecharTodas("mae offline");
      return;
   }
   g_copyOfflineFechou = false;

   AtualizarCacheCotacao();

   // 1) Copias existentes: fecha as orfas, sincroniza as demais
   bool copiado[];
   ArrayResize(copiado, g_copyMaeN);
   for(int k = 0; k < g_copyMaeN; k++) copiado[k] = false;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ulong idMae = CopyFilha_IdMaeSelecionada(t);
      if(idMae == 0) continue;
      if(CopyFilha_FechadaRecente(t)) continue;

      int k = CopyFilha_IndiceMae(idMae);
      if(k < 0)
      {
         CopyFilha_Fechar(t, "mae fechou");
         continue;
      }
      copiado[k] = true;
      CopyFilha_Sincronizar(t, g_copyMaePos[k]);
   }

   // 2) Posicoes da mae ainda nao copiadas (X = ja tratada; nao reabre apos stop na filha)
   for(int k = 0; k < g_copyMaeN; k++)
   {
      if(copiado[k]) continue;
      ulong idMae = g_copyMaePos[k].id;
      if(GlobalVariableCheck(CopyGvX(idMae))) continue;
      if(!maeOnline)
      {
         CopyFilha_LogPulo(idMae, "arquivo da mae desatualizado ha " + IntegerToString((long)idadeArqMs) + " ms");
         continue;
      }

      if(InpCopyIdadeMaxSeg > 0 && g_copyMaePos[k].idadeSeg > InpCopyIdadeMaxSeg)
      {
         GlobalVariableSet(CopyGvX(idMae), 1.0);
         PrintFormat("Scalper Pro copiador FILHA: mae #%I64u aberta ha %I64d s, nao copiada (limite %d s)",
                     idMae, g_copyMaePos[k].idadeSeg, InpCopyIdadeMaxSeg);
         continue;
      }

      if(!TradingPermitido())
      {
         CopyFilha_LogPulo(idMae, "trading bloqueado na filha (" + TextoMotivoTradeBloqueado(MotivoTradeBloqueado()) + ")");
         continue;
      }
      if(!PodeOperarRapido())
      {
         CopyFilha_LogPulo(idMae, "filha bloqueada (limite do dia / painel bloqueado)");
         continue;
      }

      if(!CopyFilha_TentativaLiberada(idMae))
      {
         CopyFilha_LogPulo(idMae, "aguardando nova tentativa apos falha");
         continue;
      }
      CopyFilha_Abrir(g_copyMaePos[k]);
   }

   // 3) Limpeza das referencias
   if(leu && agora - g_copyUltLimpezaMs > (ulong)COPY_LIMPEZA_MS)
   {
      CopyFilha_LimparGVs();
      g_copyUltLimpezaMs = agora;
   }
}

//+------------------------------------------------------------------+
//| Integracao                                                       |
//+------------------------------------------------------------------+
bool CopyInit()
{
   g_copyModoEf = InpCopyModo;
   if(MQLInfoInteger(MQL_TESTER)) g_copyModoEf = COPY_DESLIGADO;
   if(g_copyModoEf == COPY_DESLIGADO) return true;

   if(g_copyModoEf == COPY_FILHA && InpCopyMagic <= 0)
   {
      Print("Scalper Pro copiador: magic das ordens copiadas deve ser maior que 0 (o EA usa magic 0 nas ordens proprias).");
      g_copyModoEf = COPY_DESLIGADO;
      return false;
   }

   g_copyCanal         = CopySanitizarCanal(InpCopyCanal);
   g_copyArquivo       = "SP_Copy_" + g_copyCanal + ".txt";
   g_copyGv            = "SPCPY_" + g_copyCanal + "_";
   g_copyMaeUltEstado  = "";
   g_copyMaeUltEnvioMs = 0;
   g_copyMaeSeqLida    = -1;
   g_copyMaeTickMs     = 0;
   g_copyMaeValida     = false;
   g_copyMaeN          = 0;
   g_copyOfflineFechou = false;
   g_copyTimerLegadoMs = 0;
   g_copyMaeOnline     = false;
   g_copyAckUltMs      = 0;
   g_copyMaeErroGrav   = false;
   g_copyFilhasN       = 0;
   g_copyFilhasProntas = 0;
   g_copyFilhasLidoMs  = 0;
   g_copyStatusTxt     = "";

   g_copyTrade.SetExpertMagicNumber((ulong)InpCopyMagic);
   g_copyTrade.SetDeviationInPoints((ulong)MathMax(0, InpCopyDesvioPts));
   g_copyTrade.SetAsyncMode(false);
   g_copyTrade.SetTypeFilling(ObterFilling(_Symbol));
   g_copyTrade.LogLevel(LOG_LEVEL_ERRORS);

   if(g_copyModoEf == COPY_MAE)
   {
      PrintFormat("Scalper Pro copiador: MAE ativa | canal=%s | arquivo=Common\\Files\\%s | simbolo=%s | conta=%I64d",
                  g_copyCanal, g_copyArquivo, _Symbol, AccountInfoInteger(ACCOUNT_LOGIN));
      CopyMae_Publicar(true);
   }
   else
   {
      string loteTxt = (InpCopyLoteModo == COPY_LOTE_BOLETA)
                     ? "boleta " + DoubleToString(Lote, 2)
                     : EnumToString(InpCopyLoteModo) + " " + DoubleToString(InpCopyLoteValor, 2);
      string sltpTxt = (InpCopySLTPModo == COPY_SLTP_LOCAL)
                     ? "boleta SL=" + DoubleToString(StopLoss, 0) + " TP=" + DoubleToString(TakeProfit, 0) + " pts"
                     : EnumToString(InpCopySLTPModo);
      PrintFormat("Scalper Pro copiador: FILHA ativa | canal=%s | simbolo=%s | magic=%I64d | lote=%s | SL/TP=%s",
                  g_copyCanal, _Symbol, InpCopyMagic, loteTxt, sltpTxt);
   }
   return true;
}

// Indicador no cabecalho do painel: verde = pronta para enviar/receber.
void CopyStatusCalcular(string &txt, color &cor, string &dica)
{
   string bola = ShortToString(0x25CF) + " COPY ";
   if(g_copyModoEf == COPY_MAE)
   {
      dica = "Copiador MAE | canal " + g_copyCanal + " | filhas prontas "
           + IntegerToString(g_copyFilhasProntas) + "/" + IntegerToString(g_copyFilhasN);
      if(g_copyMaeErroGrav)  { txt = bola + "MAE: ERRO AO GRAVAR ARQUIVO"; cor = C_STATUS_ERR;  return; }
      if(g_copyFilhasN == 0) { txt = bola + "MAE: AGUARDANDO FILHA";       cor = C_STATUS_WARN; return; }
      if(g_copyFilhasProntas < g_copyFilhasN)
      {
         txt = bola + "MAE: FILHAS PRONTAS " + IntegerToString(g_copyFilhasProntas) + "/" + IntegerToString(g_copyFilhasN);
         cor = C_STATUS_WARN;
         return;
      }
      txt = bola + "MAE PRONTA | " + IntegerToString(g_copyFilhasN)
          + (g_copyFilhasN == 1 ? " FILHA CONECTADA" : " FILHAS CONECTADAS");
      cor = C_STATUS_OK;
      return;
   }

   dica = "Copiador FILHA | canal " + g_copyCanal;
   if(!g_copyMaeValida) { txt = bola + "FILHA: AGUARDANDO MAE"; cor = C_STATUS_ERR; return; }
   dica += " | mae conta " + IntegerToString(g_copyMaeLogin) + " " + g_copyMaeSimbolo;
   if(g_copyMaeLogin == AccountInfoInteger(ACCOUNT_LOGIN))
                        { txt = bola + "FILHA: CANAL DA PROPRIA CONTA"; cor = C_STATUS_ERR;  return; }
   if(!g_copyMaeOnline) { txt = bola + "FILHA: MAE OFFLINE";            cor = C_STATUS_ERR;  return; }
   if(!CopyFilha_Pronta())
                        { txt = bola + "FILHA BLOQUEADA (AUTOTRADING/LIMITE)"; cor = C_STATUS_WARN; return; }
   txt = bola + "FILHA PRONTA | MAE " + IntegerToString(g_copyMaeLogin);
   cor = C_STATUS_OK;
}

void CopyAtualizarStatusPainel()
{
   if(g_copyModoEf == COPY_DESLIGADO || ObjectFind(0, OBJ_COPY_STATUS) < 0) return;
   string txt = "", dica = "";
   color  cor = C_LABEL_COLOR;
   CopyStatusCalcular(txt, cor, dica);
   if(txt == g_copyStatusTxt && cor == g_copyStatusCor) return;
   g_copyStatusTxt = txt;
   g_copyStatusCor = cor;
   ObjectSetString(0, OBJ_COPY_STATUS, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, OBJ_COPY_STATUS, OBJPROP_COLOR, cor);
   ObjectSetString(0, OBJ_COPY_STATUS, OBJPROP_TOOLTIP, dica);
   if(ObjectFind(0, OBJ_COPY_STRIP) >= 0)
   {
      ObjectSetInteger(0, OBJ_COPY_STRIP, OBJPROP_BGCOLOR, CorFaixaStatusFundo(cor));
      ObjectSetString(0, OBJ_COPY_STRIP, OBJPROP_TOOLTIP, dica);
   }
   ChartRedraw(0);
}

void CopyTimer()
{
   if(g_copyModoEf == COPY_MAE)
   {
      CopyMae_Publicar(false);
      CopyMae_LerFilhas();
   }
   else if(g_copyModoEf == COPY_FILHA)
      CopyFilha_Processar();
   CopyAtualizarStatusPainel();
}

//+------------------------------------------------------------------+
//| Central de Controle - funcoes                                    |
//+------------------------------------------------------------------+
string CentralIdConta() { return IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN)); }

void Central_Ler()
{
   ulong agora = GetTickCount64();
   if(g_centralLidoMs > 0 && agora - g_centralLidoMs < (ulong)CENTRAL_LEITURA_MS) return;
   g_centralLidoMs = agora;

   if(MQLInfoInteger(MQL_TESTER) || !FileIsExist(CENTRAL_MARCA, FILE_COMMON))
   {
      g_centralEstado = CENTRAL_LIVRE;
      g_centralMotivo = "";
      return;
   }

   int    estado = CENTRAL_BLOQ;
   string motivo = "central offline";
   bool   lido   = false;
   int h = FileOpen(CENTRAL_CMD, FILE_READ|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h != INVALID_HANDLE)
   {
      int sz = (int)FileSize(h);
      string txt = (sz > 0) ? FileReadString(h, sz) : "";
      FileClose(h);
      string linhas[];
      int nl = StringSplit(txt, '\n', linhas);
      string c[];
      if(nl > 0)
      {
         string l0 = linhas[0];
         StringTrimRight(l0);
         if(StringSplit(l0, '|', c) >= 5 && c[0] == "CMD")
         {
            lido = true;
            ulong tk = (ulong)StringToInteger(c[2]);
            if(tk > 0 && (agora <= tk || agora - tk <= (ulong)CENTRAL_VELHA_MS))
            {
               g_centralUltOkMs = agora;
               motivo = c[4];
               if(c[3] == "LIVRE")      estado = CENTRAL_LIVRE;
               else if(c[3] == "ZERAR") estado = CENTRAL_ZERAR;
               else                     estado = CENTRAL_BLOQ;

               string meu = "Z|" + CentralIdConta();
               for(int i = 1; i < nl; i++)
               {
                  string l = linhas[i];
                  StringTrimRight(l);
                  if(l == meu) { estado = CENTRAL_ZERAR; motivo = "divergencia com a conta mae"; }
               }
            }
         }
      }
   }
   // Leitura falhou ou pegou o arquivo no meio da regravacao: mantem o ultimo estado
   // enquanto a ultima leitura valida for recente.
   if(!lido && g_centralUltOkMs > 0 && agora - g_centralUltOkMs < (ulong)CENTRAL_VELHA_MS)
      return;
   g_centralEstado = estado;
   g_centralMotivo = (estado == CENTRAL_LIVRE) ? "" : motivo;
}

bool Central_BloqueiaNovas()
{
   Central_Ler();
   return g_centralEstado != CENTRAL_LIVRE;
}

string Central_TextoStatus()
{
   if(g_centralEstado == CENTRAL_ZERAR) return "CENTRAL: ZERANDO (" + g_centralMotivo + ")";
   return "CENTRAL: BLOQUEADO (" + g_centralMotivo + ")";
}

// Uma linha por operacao encerrada; a central soma as do dia da conta mae.
void Central_RegistrarTrade(const ulong posId, const double pts)
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   string arq = "SP_Central_Tr_" + CentralIdConta() + ".txt";
   int h = FileOpen(arq, FILE_READ|FILE_WRITE|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileSeek(h, 0, SEEK_END);
   string l = "T|" + IntegerToString((long)posId) + "|" + IntegerToString((long)TimeLocal()) + "|"
            + DoubleToString(pts, 1) + "|" + _Symbol + "\r\n";
   FileWriteString(h, l, StringLen(l));
   FileClose(h);
}

void Central_GravarStatus()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   ulong agora = GetTickCount64();
   if(g_centralStatusMs > 0 && agora - g_centralStatusMs < 1000) return;
   g_centralStatusMs = agora;

   int    nPos = 0;
   double flut = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      nPos++;
      flut += LucroPontosPosicao(t);
   }
   string modo = (g_copyModoEf == COPY_MAE) ? "MAE" : (g_copyModoEf == COPY_FILHA ? "FILHA" : "SOLO");
   string txt = "ST|1|" + IntegerToString((long)agora) + "|" + CentralIdConta() + "|" + _Symbol + "|" + modo + "|"
              + IntegerToString(nPos) + "|" + DoubleToString(flut, 1) + "|"
              + IntegerToString((long)TimeLocal()) + "\r\n";
   int h = FileOpen("SP_Central_St_" + CentralIdConta() + "_" + _Symbol + ".txt",
                    FILE_WRITE|FILE_BIN|FILE_ANSI|FILE_COMMON|FILE_SHARE_READ|FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE) return;
   FileWriteString(h, txt, StringLen(txt));
   FileClose(h);
}

// Chamado no timer e no OnTick: aplica o comando da central.
void Central_Processar()
{
   if(MQLInfoInteger(MQL_TESTER)) return;
   Central_Ler();
   Central_GravarStatus();

   if(g_centralEstado != g_centralEstadoAnt)
   {
      if(g_centralEstado == CENTRAL_LIVRE)
         Print("Scalper Pro CENTRAL: liberado");
      else
      {
         PrintFormat("Scalper Pro CENTRAL: %s | %s", g_centralEstado == CENTRAL_ZERAR ? "ZERAR" : "BLOQUEADO", g_centralMotivo);
         // nenhuma entrada nova: desarma J/L e cancela pendentes na corretora
         if(g_jLinhaArmada) CancelarPendenteLinha(true);
         if(g_lLinhaArmada) CancelarPendenteLinha(false);
         ExecutarCancelamentoPendentes();
      }
      g_centralEstadoAnt = g_centralEstado;
      SincronizarStatusImpedimento();
   }

   if(g_centralEstado == CENTRAL_ZERAR && TemPosicaoNoSimbolo())
   {
      ulong agora = GetTickCount64();
      if(g_centralZerarMs == 0 || agora - g_centralZerarMs >= 1000)
      {
         g_centralZerarMs = agora;
         for(int i = PositionsTotal() - 1; i >= 0; i--)
         {
            ulong t = PositionGetTicket(i);
            if(t == 0 || !PositionSelectByTicket(t)) continue;
            if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
            if(trade.PositionClose(t))
               PrintFormat("Scalper Pro CENTRAL: posicao #%I64u zerada (%s)", t, g_centralMotivo);
         }
      }
   }
}

//+------------------------------------------------------------------+
int OnInit()
{
   ConfigurarTrade();
   CarregarParametrosEntrada();
   CarregarConfigParciais();
   if(!CopyInit())
      return INIT_PARAMETERS_INCORRECT;

   RemoverQuadroMensagem();

   VerificarDesbloqueio();

   ConfigurarGrafico();
   LimparGVsOrfas();
   SincronizarEstadoSeguranca();
   ChartSetInteger(0, CHART_EVENT_MOUSE_MOVE, false);
   ChartSetInteger(0, CHART_EVENT_OBJECT_CREATE, true);
   InicializarLimitesEfetivos();
   InicializarAgendaFechamento();
   CancelarEdicaoCampoAtiva();
   CriarPainel();
   if(ObjectFind(0, "SP_VER") >= 0)
      ObjectSetString(0, "SP_VER", OBJPROP_TEXT, "v" + SP_EA_VERSAO + "  |  " + _Symbol);
   AplicarPerfilAoPainel();
   CriarObjetoTimer();
   CarregarContadorOperacoes();
   ReconstruirEstatisticasDia(!EstatisticasDiaPersistidas());
   ReconciliarOperacoesAbertas();
   ReanexarPlanosParciais();
   {
      ulong tParc = TicketPosicaoSimbolo();
      if(tParc > 0) { AtualizarStatusParciaisPosicao(tParc); AtualizarLinhasParciais(tParc); }
      else          { ResetStatusParciais(); RemoverLinhasParciais(); }
   }
   ReconciliarLinhasTrailing();
   AtualizarRotulosSLTP();
   g_ultimaBarraJL = iTime(_Symbol, PERIOD_CURRENT, 0);
   g_ultimoOpsPainel = -1;
   g_ultimoPtsPainel = -999999.0;
   g_ultimoSpreadPainel = -1;
   AtualizarPainelEstatisticas(true);
   LinhasCriarModelo();
   if(InpLinhasArquivo)
      LinhasCarregar(false);
   ChartRedraw(0);

   if(RestaurarBloqueioLimiteDia())
      Status(SP_MSG_BLOQUEADO, C_STATUS_ERR, true, true);
   else
      SincronizarStatusImpedimento();
   // Copiador ativo: timer em ms; as rotinas de 1 s continuam a cada 1 s (OnTimer).
   if(g_copyModoEf != COPY_DESLIGADO)
      EventSetMillisecondTimer(MathMax(10, InpCopyIntervaloMs));
   else
      EventSetTimer(1);
   AtualizarSpread();
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   EventKillTimer();
   CancelarEdicaoCampoAtiva();
   FecharPopupLimites();
   if(reason == REASON_CHARTCHANGE || reason == REASON_RECOMPILE)
      SalvarConfigPainelPerfil(g_setupAtivo);
   RestaurarGrafico();
   // Em troca de timeframe/parametros/recompile, preserva objetos SP_ (inclui linhas sincronizadas/trailing).
   if(reason != REASON_CHARTCHANGE && reason != REASON_PARAMETERS && reason != REASON_RECOMPILE)
   {
      ObjectsDeleteAll(0, "SP_");
      ObjectsDeleteAll(0, PARC_LINHA_PREFIX);
      // as linhas do dia (LIN_PREFIX) ficam no grafico: podem ter sido ajustadas a mao
   }
   ObjectDelete(0, OBJ_CANDLE_TIMER);
   if(reason != REASON_INITFAILED)
      RemoverQuadroMensagem();
}

void OnTick()
{
   static datetime perfUltimoLog = 0;
   static ulong perfN = 0;
   static ulong perfUsExec = 0;
   static ulong perfUsCampos = 0;
   static ulong perfUsProtecao = 0;
   static ulong perfUsTimer = 0;
   static ulong perfUsTPVirtual = 0;
   static ulong perfUsTrail = 0;
   static ulong perfUsRotulos = 0;
   static ulong s_statusSyncTick = 0;

   ulong t0 = 0;
   ulong t1 = 0;
   bool perfAtivo = (InpLogDetalhado && InpPerfLogSeg > 0);
   if(perfAtivo) t0 = GetMicrosecondCount();

   g_onTickSeq++;
   AtualizarCacheCotacao();
   Central_Processar();

   // --- P0: execucao (mercado, pendentes J/L, SL/TP no broker) ---
   ProcessarEntradaAgendada();
   ProcessarCancelamentoJLAgendado();

   if(g_fechamentoAgendado)
   {
      ProcessarFechamentoAgendado();
      return;
   }

   if(g_jLinhaArmada || g_lLinhaArmada)
      ProcessarPendentesPorLinha();

   ulong posTkt = TicketPosicaoSimbolo();
   bool  temPos = (posTkt > 0);

   if(temPos && !CopyFilha_GerenciaTicket(posTkt))
   {
      ExecutarParciais(posTkt);
      TrailingStop(posTkt);
      if(perfAtivo)
      {
         t1 = GetMicrosecondCount();
         perfUsTrail += (t1 - t0);
         t0 = t1;
      }
      AplicarTPBrokerSeAusente(posTkt);
      GerenciarTPVirtual(posTkt);
      if(perfAtivo)
      {
         t1 = GetMicrosecondCount();
         perfUsTPVirtual += (t1 - t0);
         t0 = t1;
      }
   }

   datetime barAtual = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(ResetarAlternanciaJLSeNovaBarra(barAtual))
      ProcessarPendentesAberturaCandle();

   if(g_jLinhaArmada || g_lLinhaArmada || g_pendBuyJ > 0 || g_pendSellL > 0)
   {
      VerificarPreenchimentoPendenteBroker();
      LimparTicketsPendentesInvalidos();
   }

   if(perfAtivo)
   {
      t1 = GetMicrosecondCount();
      perfUsExec += (t1 - t0);
      t0 = t1;
   }

   // --- P1: pos-exec agendada (grafico, nao bloqueia broker) ---
   ProcessarLinhaTrailingAgendada();
   ProcessarRemoverVisuaisPendenteJLAgendados();
   ProcessarVisuaisPendenteJLAgendados();
   ProcessarRotulosSLTPAgendados();
   ProcessarStatusEntradaAgendado();
   ProcessarStatusAgendado();
   // Status de impedimento: a cada 5 ticks no OnTick; sync completo no OnTimer
   if((g_onTickSeq - s_statusSyncTick) >= 5)
   {
      SincronizarStatusImpedimento();
      s_statusSyncTick = g_onTickSeq;
   }

   // --- P2: UI / baixa prioridade ---
   if(barAtual != g_ultimaBarraCampos)
   {
      AtualizarCampos();
      g_ultimaBarraCampos = barAtual;
      if(g_jLinhaArmada || g_lLinhaArmada)
         AtualizarVisuaisPendentesJL();
   }
   if(perfAtivo)
   {
      t1 = GetMicrosecondCount();
      perfUsCampos += (t1 - t0);
      t0 = t1;
   }

   AtualizarArrasteSLNoGrafico(temPos);
   if(perfAtivo)
   {
      t1 = GetMicrosecondCount();
      perfUsProtecao += (t1 - t0);
      t0 = t1;
   }

   AtualizarTimerCandle(posTkt);
   if(perfAtivo)
   {
      t1 = GetMicrosecondCount();
      perfUsTimer += (t1 - t0);
      t0 = t1;
   }

   ProcessarConfigSalvarAgendada();

   if(temPos)
   {
      if(NiveisManuaisPrecisamSync(posTkt))
         ProcessarNiveisManuaisGrafico();
   }

   if(perfAtivo)
   {
      t1 = GetMicrosecondCount();
      perfUsRotulos += (t1 - t0);
      perfN++;

      datetime agora = TimeCurrent();
      if(perfUltimoLog == 0) perfUltimoLog = agora;
      if(agora - perfUltimoLog >= InpPerfLogSeg && perfN > 0)
      {
         ulong perfUsTotal = perfUsExec + perfUsCampos + perfUsProtecao
                           + perfUsTimer + perfUsTPVirtual
                           + perfUsTrail + perfUsRotulos;
         PrintFormat("SP perf OnTick avg(us): total=%I64u exec=%I64u trail=%I64u tpV=%I64u campos=%I64u ui=%I64u timer=%I64u rot=%I64u n=%I64u",
                     perfUsTotal / perfN,
                     perfUsExec / perfN,
                     perfUsTrail / perfN,
                     perfUsTPVirtual / perfN,
                     perfUsCampos / perfN,
                     perfUsProtecao / perfN,
                     perfUsTimer / perfN,
                     perfUsRotulos / perfN,
                     perfN);

         perfN = 0;
         perfUsExec = 0;
         perfUsCampos = 0;
         perfUsProtecao = 0;
         perfUsTimer = 0;
         perfUsTPVirtual = 0;
         perfUsTrail = 0;
         perfUsRotulos = 0;
         perfUltimoLog = agora;
      }
   }
}

void OnTimer()
{
   Central_Processar();
   if(g_copyModoEf != COPY_DESLIGADO)
   {
      CopyTimer();
      ulong agoraMs = GetTickCount64();
      if(agoraMs - g_copyTimerLegadoMs < 1000) return;
      g_copyTimerLegadoMs = agoraMs;
   }

   ProcessarResetStatusGeralAgendado();
   ProcessarResetStatusParciaisAgendado();
   SincronizarStatusImpedimento();
   if(InpLinhasAutoRecarga)
      LinhasVerificarArquivo();
   ProcessarResetPontosOperacaoAgendado();
   AtualizarPainelEstatisticas(false);
   AtualizarSpread();
   VerificarFechamentoHorario();
   VerificarIntegridadeEstadoSeguranca();
   if(g_fechamentoAgendado)
      ProcessarFechamentoAgendado();
}

void OnChartEvent(const int id, const long &lparam,
                  const double &dparam, const string &sparam)
{
   if(id == CHARTEVENT_CHART_CHANGE)
   {
      AtualizarRotulosSLTP();
      if(TemPosicaoNoSimbolo())
         ProcessarNiveisManuaisGrafico();
      if(!g_painelMinimizado)
      {
         AplicarAlturaPainel(AlturaPainelNormal());
         RestaurarLayoutSecoesColapsaveis();
         RestaurarVisibilidadeCamposPainel();
         GarantirCamposEditaveisPainel();
         GarantirMetricasStatusNaFrente();
         GarantirPainelNaFrente();
         GarantirTextoBotaoSync();
         ChartRedraw(0);
      }
      else
         AplicarEstadoMinimizadoPainel();
      return;
   }

   if(g_fechamentoAgendado) return;

   // clique no grafico fora do painel com um campo em edicao: confirma o valor
   if(id == CHARTEVENT_CLICK)
   {
      if(g_campoEditAtivo != "")
      {
         int cx = (int)lparam, cy = (int)dparam;
         int alt = g_painelMinimizado ? AlturaPainelMin() : AlturaPainelNormal();
         bool dentro = (cx >= PANEL_X && cx <= PANEL_X + PANEL_W && cy >= PANEL_Y && cy <= PANEL_Y + alt);
         if(!dentro) FinalizarEdicaoCampo(true);
      }
      return;
   }

   if(id == CHARTEVENT_OBJECT_CLICK)
   {
      if(EhCliqueAgendaPopup(sparam))
         return;

      if(StringFind(sparam, SPL_PREFIX) == 0)
      {
         string acaoPopup = "";
         if(ResolverCliquePopupLimites(sparam, acaoPopup))
         {
            ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
            if(acaoPopup == "ok") ConfirmarPopupLimites();
            else if(acaoPopup == "cancel") FecharPopupLimites();
            else if(acaoPopup == "trocar_pin") AbrirPopupPin(false);
            else if(acaoPopup == "pin_salvar") SalvarPopupPin();
            else if(acaoPopup == "voltar")
            {
               if(PinJaCadastrado()) AbrirPopupLimites();
               else FecharPopupLimites();
            }
            ChartRedraw(0);
         }
         return;
      }

      string btn = ResolverCliqueBotaoPainel(sparam);
      if(btn != "")
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         ProcessarCliqueBotaoPainel(btn);
         return;
      }

      if(sparam == "SP_TR")
      {
         if(!g_painelBloqueado)
            ToggleModoTrail();
         return;
      }

      if(EhCampoEditavelPainel(sparam))
      {
         ObjectSetInteger(0, sparam, OBJPROP_STATE, false);
         IniciarEdicaoCampo(sparam);
         return;
      }

      if(g_campoEditAtivo != "")
         FinalizarEdicaoCampo(true);   // clicar fora do campo confirma o valor

      if(StringFind(sparam, "SP_") == 0)
         return;
   }
   else if(id == CHARTEVENT_OBJECT_ENDEDIT)
   {
      if(EhCampoEditavelPainel(sparam))
      {
         if(g_campoEditAtivo == "")
         {
            AtualizarCampos();
            EscreverValorCampoEdit(sparam);
            ReconciliarLinhasTrailing();
            AtualizarRotulosSLTP();
         }
         return;
      }

      if(sparam == SPL_EDIT_PIN || sparam == SPL_EDIT_PIN_ATUAL
         || sparam == SPL_EDIT_PIN_NOVO || sparam == SPL_EDIT_PIN_CONF)
         SanitizarEditPin(sparam);
      else if(sparam == SPL_EDIT_SCHED_HHMM)
      {
         LerAgendaCamposPopup();
         if(ObjectFind(0, SPL_EDIT_SCHED_HHMM) >= 0)
            ObjectSetString(0, SPL_EDIT_SCHED_HHMM, OBJPROP_TEXT,
                            FormatarHorarioHHMM(g_schedHour, g_schedMin));
      }
      else if(g_popupLimitesAberto && EhObjetoPopupLimites(sparam))
      {
         if(sparam == SPL_EDIT_OPS || sparam == SPL_EDIT_POS || sparam == SPL_EDIT_NEG)
         { /* valores lidos no OK */ }
      }
      else
      {
         AtualizarCampos();
         ReconciliarLinhasTrailing();
         AtualizarRotulosSLTP();
      }
   }
   else if(id == CHARTEVENT_KEYDOWN)
   {
      int key = (int)lparam;

      if(g_campoEditAtivo != "")
      {
         bool teclaExec = (key == InpTeclaCompPend || key == InpTeclaVendPend || key == InpTeclaCancPend ||
                           key == InpTeclaToggleSL || key == InpTeclaBuy || key == InpTeclaSell ||
                           key == InpTeclaFechar || key == InpTeclaToggleSetup);
         if(teclaExec)
            FinalizarEdicaoCampoParaExecucao();
         else
         {
            ProcessarTeclaEdicaoCampo(key);
            return;
         }
      }

      if(key == InpTeclaCompPend)       TeclaJ();
      else if(key == InpTeclaVendPend) TeclaL();
      else if(key == InpTeclaCancPend) CancelarTodasPendentes();
      else if(key == InpTeclaToggleSL) ToggleSLPorTipo();
      else if(key == InpTeclaBuy)      BuyOrder();
      else if(key == InpTeclaSell)     SellOrder();
      else if(key == InpTeclaFechar)   CloseAll();
      else if(key == InpTeclaToggleSetup) AlternarPerfilSetup();

      ProcessarStatusAgendado();
   }
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LINHAS DO DIA: arquivo Common\Files\SP_Linhas.txt                |
//|   TIPO <NOME> = <cor>, <espessura>, <estilo>                      |
//|   <NOME>: preco; preco; preco      (virgula ou ponto decimal)     |
//+------------------------------------------------------------------+
string g_linTipoNome[];
color  g_linTipoCor[];
int    g_linTipoLarg[];
int    g_linTipoEstilo[];

void LinhasTiposPadrao()
{
   ArrayResize(g_linTipoNome, 0);
   ArrayResize(g_linTipoCor, 0);
   ArrayResize(g_linTipoLarg, 0);
   ArrayResize(g_linTipoEstilo, 0);
   LinhasDefinirTipo("NIVEL1",    clrBlack,     3, STYLE_SOLID);
   LinhasDefinirTipo("NIVEL2",    clrBlack,     1, STYLE_SOLID);
   LinhasDefinirTipo("TRACEJADA", clrDimGray,   1, STYLE_DASH);
   LinhasDefinirTipo("DESTAQUE",  clrRoyalBlue, 3, STYLE_SOLID);
}

int LinhasIndiceTipo(const string nome)
{
   for(int i = 0; i < ArraySize(g_linTipoNome); i++)
      if(g_linTipoNome[i] == nome) return i;
   return -1;
}

void LinhasDefinirTipo(const string nome, const color cor, const int larg, const int estilo)
{
   int i = LinhasIndiceTipo(nome);
   if(i < 0)
   {
      i = ArraySize(g_linTipoNome);
      ArrayResize(g_linTipoNome, i + 1);
      ArrayResize(g_linTipoCor, i + 1);
      ArrayResize(g_linTipoLarg, i + 1);
      ArrayResize(g_linTipoEstilo, i + 1);
   }
   g_linTipoNome[i]   = nome;
   g_linTipoCor[i]    = cor;
   g_linTipoLarg[i]   = MathMax(1, MathMin(5, larg));
   g_linTipoEstilo[i] = estilo;
}

string LinhasLimpar(string t)
{
   // remove BOM/caracteres invisiveis do inicio (arquivo salvo em UTF-8 pelo Bloco de Notas)
   while(StringLen(t) > 0 && (StringGetCharacter(t, 0) > 126 || StringGetCharacter(t, 0) < 32))
      t = StringSubstr(t, 1);
   StringTrimLeft(t);
   StringTrimRight(t);
   return t;
}

color LinhasCor(string c, bool &ok)
{
   ok = true;
   c = LinhasLimpar(c);
   StringToUpper(c);
   if(c == "PRETO" || c == "BLACK")                       return clrBlack;
   if(c == "AZUL" || c == "BLUE")                         return clrRoyalBlue;
   if(c == "AZULESCURO" || c == "NAVY")                   return clrNavy;
   if(c == "VERMELHO" || c == "RED")                      return clrRed;
   if(c == "VERDE" || c == "GREEN")                       return clrGreen;
   if(c == "CINZA" || c == "GRAY" || c == "GREY")         return clrDimGray;
   if(c == "CINZACLARO" || c == "SILVER")                 return clrSilver;
   if(c == "LARANJA" || c == "ORANGE")                    return clrDarkOrange;
   if(c == "AMARELO" || c == "YELLOW" || c == "GOLD")     return clrGold;
   if(c == "ROXO" || c == "PURPLE" || c == "MAGENTA")     return clrMagenta;
   if(c == "BRANCO" || c == "WHITE")                      return clrWhite;
   ok = false;
   return clrBlack;
}

int LinhasEstilo(string e)
{
   e = LinhasLimpar(e);
   StringToUpper(e);
   if(e == "TRACEJADA" || e == "DASH")       return STYLE_DASH;
   if(e == "PONTILHADA" || e == "DOT")       return STYLE_DOT;
   if(e == "TRACO_PONTO" || e == "DASHDOT")  return STYLE_DASHDOT;
   return STYLE_SOLID;
}

// Converte "29465,08" / "29465.08" / "29.465,08" em preco. false se nao for um numero valido.
bool LinhasPreco(string t, double &preco)
{
   t = LinhasLimpar(t);
   if(StringLen(t) == 0) return false;
   bool temVirg = (StringFind(t, ",") >= 0), temPonto = (StringFind(t, ".") >= 0);
   if(temVirg && temPonto) StringReplace(t, ".", "");   // ponto de milhar
   StringReplace(t, ",", ".");
   int pontos = 0;
   for(int i = 0; i < StringLen(t); i++)
   {
      ushort ch = StringGetCharacter(t, i);
      if(ch == '.') { pontos++; continue; }
      if(ch < '0' || ch > '9') return false;
   }
   if(pontos > 1) return false;
   preco = StringToDouble(t);
   return (preco > 0);
}

void LinhasCriarModelo()
{
   if(FileIsExist(LIN_ARQ, FILE_COMMON)) return;
   int h = FileOpen(LIN_ARQ, FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_COMMON);
   if(h == INVALID_HANDLE)
   {
      PrintFormat("SP LINHAS: nao foi possivel criar %s (erro %d)", LIN_ARQ, GetLastError());
      return;
   }
   FileWriteString(h, "# LINHAS DO DIA - Scalper Pro\r\n");
   FileWriteString(h, "# Cole os precos depois dos dois pontos, separados por ponto e virgula, e SALVE.\r\n");
   FileWriteString(h, "# Depois clique no botao LINHAS do painel do Scalper Pro.\r\n");
   FileWriteString(h, "# Virgula ou ponto decimal: 29465,08 ou 29465.08. Linhas com # sao ignoradas.\r\n");
   FileWriteString(h, "#\r\n");
   FileWriteString(h, "# Aparencia de cada tipo: cor, espessura (1 a 5), estilo\r\n");
   FileWriteString(h, "# Cores: PRETO AZUL AZULESCURO VERMELHO VERDE CINZA CINZACLARO LARANJA AMARELO ROXO BRANCO\r\n");
   FileWriteString(h, "# Estilos: SOLIDA TRACEJADA PONTILHADA TRACO_PONTO\r\n");
   FileWriteString(h, "TIPO NIVEL1    = PRETO, 3, SOLIDA\r\n");
   FileWriteString(h, "TIPO NIVEL2    = PRETO, 1, SOLIDA\r\n");
   FileWriteString(h, "TIPO TRACEJADA = CINZA, 1, TRACEJADA\r\n");
   FileWriteString(h, "TIPO DESTAQUE  = AZUL, 3, SOLIDA\r\n");
   FileWriteString(h, "\r\n");
   FileWriteString(h, "# Exemplo: NIVEL1: 29465,08; 29361,12; 29323,97\r\n");
   FileWriteString(h, "NIVEL1:\r\n");
   FileWriteString(h, "NIVEL2:\r\n");
   FileWriteString(h, "TRACEJADA:\r\n");
   FileWriteString(h, "DESTAQUE:\r\n");
   FileClose(h);
   PrintFormat("SP LINHAS: modelo criado em %s\\Files\\%s",
               TerminalInfoString(TERMINAL_COMMONDATA_PATH), LIN_ARQ);
}

// Confere a data/tamanho do arquivo (1x por segundo) e redesenha quando ele for salvo.
void LinhasVerificarArquivo()
{
   if(!FileIsExist(LIN_ARQ, FILE_COMMON)) return;
   long data = FileGetInteger(LIN_ARQ, FILE_MODIFY_DATE, true);
   long tam  = FileGetInteger(LIN_ARQ, FILE_SIZE, true);
   if(data < 0) return;
   if(data == g_linArqData && tam == g_linArqTam) return;
   LinhasCarregar(true);
}

// Le o arquivo e redesenha as linhas. avisar = mostra o resultado na barra de status.
void LinhasCarregar(const bool avisar)
{
   if(!FileIsExist(LIN_ARQ, FILE_COMMON))
   {
      LinhasCriarModelo();
      if(avisar) Status("LINHAS: arquivo criado em Common\\Files\\" + LIN_ARQ, clrOrange, true);
      g_linArqData = FileGetInteger(LIN_ARQ, FILE_MODIFY_DATE, true);
      g_linArqTam  = FileGetInteger(LIN_ARQ, FILE_SIZE, true);
      return;
   }

   int h = FileOpen(LIN_ARQ, FILE_READ | FILE_TXT | FILE_ANSI | FILE_COMMON | FILE_SHARE_READ | FILE_SHARE_WRITE);
   if(h == INVALID_HANDLE)
   {
      // o editor pode estar gravando neste instante: tenta de novo no proximo segundo
      if(avisar) Status("LINHAS: arquivo em uso, tentando de novo", clrOrange, true);
      return;
   }
   g_linArqData = FileGetInteger(LIN_ARQ, FILE_MODIFY_DATE, true);
   g_linArqTam  = FileGetInteger(LIN_ARQ, FILE_SIZE, true);

   LinhasTiposPadrao();
   string tipoLinha[];
   double precoLinha[];
   int    nInval = 0, nFora = 0, numLinha = 0;
   string primeiroErro = "";
   double ref = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ref <= 0) ref = iClose(_Symbol, PERIOD_CURRENT, 0);

   while(!FileIsEnding(h))
   {
      string lin = LinhasLimpar(FileReadString(h));
      numLinha++;
      if(StringLen(lin) == 0 || StringGetCharacter(lin, 0) == '#') continue;

      string up = lin;
      StringToUpper(up);

      // TIPO NOME = cor, espessura, estilo
      if(StringFind(up, "TIPO ") == 0)
      {
         int eq = StringFind(up, "=");
         if(eq < 0) { nInval++; if(primeiroErro == "") primeiroErro = "linha " + IntegerToString(numLinha); continue; }
         string nome = LinhasLimpar(StringSubstr(up, 5, eq - 5));
         string partes[];
         int np = StringSplit(StringSubstr(up, eq + 1), ',', partes);
         bool okCor = false;
         color cor = (np >= 1) ? LinhasCor(partes[0], okCor) : clrBlack;
         int larg  = (np >= 2) ? (int)StringToInteger(LinhasLimpar(partes[1])) : 1;
         int est   = (np >= 3) ? LinhasEstilo(partes[2]) : STYLE_SOLID;
         if(StringLen(nome) == 0 || !okCor)
         {
            nInval++;
            if(primeiroErro == "") primeiroErro = "linha " + IntegerToString(numLinha);
            PrintFormat("SP LINHAS: linha %d ignorada (tipo/cor invalidos): %s", numLinha, lin);
            continue;
         }
         LinhasDefinirTipo(nome, cor, larg, est);
         continue;
      }

      // NOME: preco; preco; ...
      int dp = StringFind(lin, ":");
      if(dp < 0)
      {
         nInval++;
         if(primeiroErro == "") primeiroErro = "linha " + IntegerToString(numLinha);
         PrintFormat("SP LINHAS: linha %d ignorada (falta ':'): %s", numLinha, lin);
         continue;
      }
      string tipo = LinhasLimpar(StringSubstr(up, 0, dp));
      string lista = StringSubstr(lin, dp + 1);
      StringReplace(lista, "|", ";");
      string itens[];
      int ni = StringSplit(lista, ';', itens);
      for(int k = 0; k < ni; k++)
      {
         string it = LinhasLimpar(itens[k]);
         if(StringLen(it) == 0) continue;
         double p;
         if(!LinhasPreco(it, p))
         {
            nInval++;
            if(primeiroErro == "") primeiroErro = it;
            PrintFormat("SP LINHAS: preco invalido '%s' (%s, linha %d)", it, tipo, numLinha);
            continue;
         }
         if(InpLinhasFaixaPct > 0 && ref > 0 && MathAbs(p - ref) > ref * InpLinhasFaixaPct / 100.0)
         {
            nFora++;
            if(primeiroErro == "") primeiroErro = it;
            PrintFormat("SP LINHAS: preco %s ignorado: mais de %.0f%% longe do preco atual (%s)", it, InpLinhasFaixaPct,
                        DoubleToString(ref, _Digits));
            continue;
         }
         int n = ArraySize(precoLinha);
         ArrayResize(precoLinha, n + 1);
         ArrayResize(tipoLinha, n + 1);
         precoLinha[n] = NormalizeDouble(p, _Digits);
         tipoLinha[n]  = tipo;
      }
   }
   FileClose(h);

   // redesenha: apaga so as linhas do arquivo, inclusive ajustes feitos nelas (as linhas manuais e as do SYNC ficam)
   ObjectsDeleteAll(0, LIN_PREFIX);
   int desenhadas = 0;
   for(int i = 0; i < ArraySize(precoLinha); i++)
   {
      int t = LinhasIndiceTipo(tipoLinha[i]);
      if(t < 0)
      {
         // tipo sem "TIPO ... =": usa a aparencia do NIVEL2
         LinhasDefinirTipo(tipoLinha[i], clrBlack, 1, STYLE_SOLID);
         t = LinhasIndiceTipo(tipoLinha[i]);
      }
      string nome = LIN_PREFIX + tipoLinha[i] + "_" + IntegerToString(i + 1);
      if(!ObjectCreate(0, nome, OBJ_HLINE, 0, 0, precoLinha[i])) continue;
      ObjectSetInteger(0, nome, OBJPROP_COLOR, g_linTipoCor[t]);
      ObjectSetInteger(0, nome, OBJPROP_WIDTH, g_linTipoLarg[t]);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, g_linTipoEstilo[t]);
      ObjectSetInteger(0, nome, OBJPROP_BACK, true);
      ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, true);    // permite ajustar com o mouse
      ObjectSetInteger(0, nome, OBJPROP_SELECTED, false);
      ObjectSetInteger(0, nome, OBJPROP_HIDDEN, false);
      ObjectSetInteger(0, nome, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
      ObjectSetString(0, nome, OBJPROP_TOOLTIP, tipoLinha[i] + " " + DoubleToString(precoLinha[i], _Digits));
      desenhadas++;
   }
   ChartRedraw(0);

   string msg;
   if(nInval + nFora == 0)
      msg = StringFormat("LINHAS: %d carregadas", desenhadas);
   else
      msg = StringFormat("LINHAS: %d ok, %d ignorada(s) (%s)", desenhadas, nInval + nFora, primeiroErro);
   PrintFormat("SP %s | arquivo %s", msg, LIN_ARQ);
   if(avisar || nInval + nFora > 0)
   {
      if(nInval + nFora == 0) StatusComAutoReset(msg, C_STATUS_OK, true);
      else                    Status(msg, clrOrange, true);
   }
}

//+------------------------------------------------------------------+
//| PARCIAIS (portado do Scalper Pro v5.38)                          |
//| P1/P2: fecham % do lote inicial ao atingir X pontos de lucro.    |
//| Estado por posicao em GlobalVariables (sobrevive a reinicios).   |
//+------------------------------------------------------------------+
string GVInitVol(ulong posTkt)       { return GV_PREFIX + "IV_" + IntegerToString(posTkt); }
string GVTarget(ulong posTkt, int p) { return GV_PREFIX + "TG" + IntegerToString(p) + "_" + IntegerToString(posTkt); }
string GVClosed(ulong posTkt, int p) { return GV_PREFIX + "CL" + IntegerToString(p) + "_" + IntegerToString(posTkt); }
string GVState(ulong posTkt, int p)  { return GV_PREFIX + "ST" + IntegerToString(p) + "_" + IntegerToString(posTkt); }
string GVLock(ulong posTkt)          { return GV_PREFIX + "LK_" + IntegerToString(posTkt); }
string GVLockPartial(ulong posTkt)   { return GV_PREFIX + "LP_" + IntegerToString(posTkt); }
string GVLockTime(ulong posTkt)      { return GV_PREFIX + "LT_" + IntegerToString(posTkt); }
string GVLastDeal(ulong posTkt)      { return GV_PREFIX + "LD_" + IntegerToString(posTkt); }
string GVSlP1(ulong posTkt)          { return GV_PREFIX + "S1_" + IntegerToString(posTkt); }
string GVSlP2(ulong posTkt)          { return GV_PREFIX + "S2_" + IntegerToString(posTkt); }
string GVUltimaTentativa(ulong t, int p) { return GV_PREFIX + "UT" + IntegerToString(p) + "_" + IntegerToString(t); }

bool ParciaisAtivas()
{
   return g_parciaisLigado;
}

// Copias da filha nao fazem parcial propria: a parcial da mae ja reduz a copia na mesma proporcao.
bool ParciaisNaPosicao(const ulong posTkt)
{
   if(!ParciaisAtivas()) return false;
   if(g_copyModoEf == COPY_FILHA && posTkt > 0 && PositionSelectByTicket(posTkt)
      && PositionGetInteger(POSITION_MAGIC) == InpCopyMagic)
      return false;
   return true;
}

//--- configuracao (inputs na 1a vez ou quando os inputs mudam; depois, o que foi editado no painel)
void SanitizarConfigParciais()
{
   Partial1_Points = MathMax(0, Partial1_Points);
   Partial2_Points = MathMax(0, Partial2_Points);
   Partial1_Close  = MathMax(0, MathMin(100, Partial1_Close));
   Partial2_Close  = MathMax(0, MathMin(100, Partial2_Close));
   if(Partial1_Close + Partial2_Close > 100.0)
      Partial2_Close = MathMax(0.0, 100.0 - Partial1_Close);
}

void SalvarConfigParciais()
{
   GlobalVariableSet(GvCfgKey("P1_PTS"), Partial1_Points);
   GlobalVariableSet(GvCfgKey("P1_PCT"), Partial1_Close);
   GlobalVariableSet(GvCfgKey("P2_PTS"), Partial2_Points);
   GlobalVariableSet(GvCfgKey("P2_PCT"), Partial2_Close);
   GlobalVariableSet(GvCfgKey("PARC_ON"), g_parciaisLigado ? 1.0 : 0.0);
}

bool InputsParciaisAlterados()
{
   if(!GlobalVariableCheck(GvCfgKey("PIN_P1P"))) return true;
   return (GlobalVariableGet(GvCfgKey("PIN_P1P")) != InpP1_Pontos
        || GlobalVariableGet(GvCfgKey("PIN_P1C")) != InpP1_Pct
        || GlobalVariableGet(GvCfgKey("PIN_P2P")) != InpP2_Pontos
        || GlobalVariableGet(GvCfgKey("PIN_P2C")) != InpP2_Pct
        || GlobalVariableGet(GvCfgKey("PIN_ON"))  != (InpUsarParciais ? 1.0 : 0.0));
}

void CarregarConfigParciais()
{
   if(InputsParciaisAlterados() || !GlobalVariableCheck(GvCfgKey("P1_PTS")))
   {
      Partial1_Points  = InpP1_Pontos;
      Partial1_Close   = InpP1_Pct;
      Partial2_Points  = InpP2_Pontos;
      Partial2_Close   = InpP2_Pct;
      g_parciaisLigado = InpUsarParciais;
      SanitizarConfigParciais();
      SalvarConfigParciais();
      GlobalVariableSet(GvCfgKey("PIN_P1P"), InpP1_Pontos);
      GlobalVariableSet(GvCfgKey("PIN_P1C"), InpP1_Pct);
      GlobalVariableSet(GvCfgKey("PIN_P2P"), InpP2_Pontos);
      GlobalVariableSet(GvCfgKey("PIN_P2C"), InpP2_Pct);
      GlobalVariableSet(GvCfgKey("PIN_ON"),  InpUsarParciais ? 1.0 : 0.0);
      return;
   }
   Partial1_Points  = GlobalVariableGet(GvCfgKey("P1_PTS"));
   Partial1_Close   = GlobalVariableGet(GvCfgKey("P1_PCT"));
   Partial2_Points  = GlobalVariableGet(GvCfgKey("P2_PTS"));
   Partial2_Close   = GlobalVariableGet(GvCfgKey("P2_PCT"));
   g_parciaisLigado = !GlobalVariableCheck(GvCfgKey("PARC_ON")) || GlobalVariableGet(GvCfgKey("PARC_ON")) > 0.5;
   SanitizarConfigParciais();
}

//--- botao ON/OFF e caixas de status
void AtualizarBotaoParciais()
{
   if(ObjectFind(0, OBJ_BTN_PARCIAIS) < 0) return;

   bool on = ParciaisAtivas();
   RemoverDecorBotao(OBJ_BTN_PARCIAIS);
   ObjectSetString(0, OBJ_BTN_PARCIAIS, OBJPROP_TEXT, on ? "ON" : "OFF");
   ObjectSetString(0, OBJ_BTN_PARCIAIS, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_FONTSIZE, 7);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_COLOR, on ? C_EXEC_TEXT_ON : C_NOME_COLOR);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_BGCOLOR, on ? C_PARCIAIS_ON_BG : C_PARCIAIS_OFF_BG);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_BORDER_COLOR, on ? C_PARCIAIS_ON_BG : C_BTN_BORDER);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, OBJ_BTN_PARCIAIS, OBJPROP_STATE, false);
   ObjectSetString(0, OBJ_BTN_PARCIAIS, OBJPROP_TOOLTIP,
                   on ? "Parciais ligadas (clique p/ desligar)" : "Parciais desligadas (clique p/ ligar)");
}

void ToggleParciaisSistema()
{
   g_parciaisLigado = !g_parciaisLigado;
   SalvarConfigParciais();
   AtualizarBotaoParciais();
   if(g_parciaisLigado)
   {
      ReanexarPlanosParciais();
      ulong t = TicketPosicaoSimbolo();
      if(t > 0) AtualizarStatusParciaisPosicao(t);
      else      ResetStatusParciais();
   }
   else
   {
      AtualizarStatusParciaisDesabilitadas();
      RemoverLinhasParciais();
   }
   Status(g_parciaisLigado ? "Parciais ligadas" : "Parciais desligadas",
          g_parciaisLigado ? C_STATUS_OK : C_STATUS_WARN, true);
   ChartRedraw(0);
}

void AtualizarStatusParciaisDesabilitadas()
{
   if(!ParciaisAtivas())
   {
      SetParcialLabel(1, "OFF", C_MUTED);
      SetParcialLabel(2, "OFF", C_MUTED);
   }
}

void ResetStatusParciais()
{
   g_parciaisResetEm = 0;
   if(!ParciaisAtivas())
   {
      AtualizarStatusParciaisDesabilitadas();
      return;
   }
   SetParcialLabel(1, "ATIVO", C_STATUS_OK);
   SetParcialLabel(2, "ATIVO", C_STATUS_OK);
}

string PartialStatusObject(int partialId)
{
   if(partialId == 1) return OBJ_P1_STATUS;
   if(partialId == 2) return OBJ_P2_STATUS;
   return "";
}

string PartialStatusBox(int partialId)
{
   if(partialId == 1) return OBJ_P1_STATUS_BG;
   if(partialId == 2) return OBJ_P2_STATUS_BG;
   return "";
}

color PartialStatusColor(int partialId)
{
   if(partialId == 1) return C_P1_ACCENT;
   if(partialId == 2) return C_P2_ACCENT;
   return C_LABEL_BRIGHT;
}

void SetParcialLabel(int partialId, string txt, color c)
{
   c = CorTemaClaro(c);
   string obj = PartialStatusObject(partialId);
   if(obj == "" || ObjectFind(0, obj) < 0) return;

   string box = PartialStatusBox(partialId);
   if(box != "" && ObjectFind(0, box) >= 0)
   {
      ObjectSetInteger(0, box, OBJPROP_BORDER_COLOR, c);
      ObjectSetInteger(0, box, OBJPROP_COLOR, c);
   }

   if(ObjectGetString(0, obj, OBJPROP_TEXT) == txt
      && (color)ObjectGetInteger(0, obj, OBJPROP_COLOR) == c)
      return;
   ObjectSetString(0, obj, OBJPROP_TEXT, txt);
   ObjectSetInteger(0, obj, OBJPROP_COLOR, c);
}

void AtualizarStatusParcialUI(ulong posTkt, int partialId)
{
   if(!ParciaisAtivas())
   {
      AtualizarStatusParciaisDesabilitadas();
      return;
   }

   string gvSt = GVState(posTkt, partialId);
   if(!GlobalVariableCheck(gvSt)) return;

   int    st      = (int)GlobalVariableGet(gvSt);
   double alvo    = GlobalVariableGet(GVTarget(posTkt, partialId));
   double fechado = GlobalVariableGet(GVClosed(posTkt, partialId));
   double tol     = VolTolerance();

   if(st == PARTIAL_DONE || (alvo > 0 && fechado >= alvo - tol))
      SetParcialLabel(partialId, "Executada", clrLime);
   else if(st == PARTIAL_INFLIGHT)
      SetParcialLabel(partialId, "Enviando...", clrOrange);
   else if(st == PARTIAL_TRIGGERED)
   {
      double pct = (alvo > 0) ? (fechado / alvo) * 100.0 : 0;
      SetParcialLabel(partialId, DoubleToString(pct, 0) + "%", PartialStatusColor(partialId));
   }
   else
      SetParcialLabel(partialId, "ATIVO", C_STATUS_OK);
}

void AtualizarStatusParciaisPosicao(ulong posTkt)
{
   if(!ParciaisAtivas()) { AtualizarStatusParciaisDesabilitadas(); return; }
   for(int p = 1; p <= PARTIAL_COUNT; p++)
      AtualizarStatusParcialUI(posTkt, p);
}

//--- volumes
double VolTolerance()
{
   return MathMax(LotStep() * 0.5, VOL_EPSILON);
}

bool AjustarVolumeParcial(double volAtual, double &volClose)
{
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double tol    = VolTolerance();

   volClose = NormalizeVol(volClose);
   if(volClose <= 0) return false;

   if(volClose >= volAtual - tol)
   {
      volClose = NormalizeVol(volAtual);
      return (volClose >= minLot - tol);
   }

   double resto = NormalizeVol(volAtual - volClose);
   if(resto > tol && resto < minLot - tol)
   {
      volClose = NormalizeVol(volAtual - minLot);
      if(volClose < minLot - tol) return false;
   }

   volClose = NormalizeVol(volClose);
   if(volClose < minLot - tol) return false;

   resto = NormalizeVol(volAtual - volClose);
   if(resto > tol && resto < minLot - tol) return false;

   return true;
}

bool GatilhoParcialAtingidoPts(double lucroPts, double pontosAlvo)
{
   if(pontosAlvo <= 0) return false;
   return (lucroPts >= pontosAlvo - 0.5);
}

bool PartialConfig(int partialId, double &pontos, double &pct)
{
   switch(partialId)
   {
      case 1: pontos = Partial1_Points; pct = Partial1_Close; return true;
      case 2: pontos = Partial2_Points; pct = Partial2_Close; return true;
      default: return false;
   }
}

void CalcularAlvosParciais(double volInicial, double &t1, double &t2)
{
   t1 = NormalizeVol(volInicial * (Partial1_Close / 100.0));
   t2 = NormalizeVol(volInicial * (Partial2_Close / 100.0));

   double soma = NormalizeVol(t1 + t2);
   double tol  = VolTolerance();
   // P1 + P2 = 100%: nao existe residuo, o P2 fecha TUDO o que sobrou depois do P1.
   // (Cada % arredondado para baixo separadamente deixaria sobra, ex.: lote 0.25 com 50/50
   //  daria 0.12 + 0.12 e 0.01 ficaria aberto.)
   if(soma > volInicial - tol || Partial1_Close + Partial2_Close >= 100.0 - 1e-6)
      t2 = NormalizeVol(MathMax(0, volInicial - t1));
}

//--- trava durante o envio
void DestravarPosicao(ulong posTkt)
{
   if(GlobalVariableCheck(GVLock(posTkt)))        GlobalVariableDel(GVLock(posTkt));
   if(GlobalVariableCheck(GVLockPartial(posTkt))) GlobalVariableDel(GVLockPartial(posTkt));
   if(GlobalVariableCheck(GVLockTime(posTkt)))    GlobalVariableDel(GVLockTime(posTkt));
}

void TravarPosicao(ulong posTkt, int partialId)
{
   GlobalVariableSet(GVLock(posTkt), 1.0);
   GlobalVariableSet(GVLockPartial(posTkt), (double)partialId);
   GlobalVariableSet(GVLockTime(posTkt), (double)TimeCurrent());
}

bool DealJaProcessado(ulong posTkt, ulong dealTkt)
{
   if(!GlobalVariableCheck(GVLastDeal(posTkt))) return false;
   return ((ulong)GlobalVariableGet(GVLastDeal(posTkt)) == dealTkt);
}

void MarcarDealProcessado(ulong posTkt, ulong dealTkt)
{
   GlobalVariableSet(GVLastDeal(posTkt), (double)dealTkt);
}

bool PosicaoComLock(ulong posTkt)
{
   if(!GlobalVariableCheck(GVLock(posTkt))) return false;
   if(!GlobalVariableCheck(GVLockTime(posTkt))) return true;

   datetime t0 = (datetime)GlobalVariableGet(GVLockTime(posTkt));
   if(TimeCurrent() - t0 <= PARTIAL_LOCK_SEC) return true;

   int lp = 0;
   if(GlobalVariableCheck(GVLockPartial(posTkt)))
      lp = (int)GlobalVariableGet(GVLockPartial(posTkt));

   if(lp >= 1 && lp <= PARTIAL_COUNT)
   {
      string gvSt = GVState(posTkt, lp);
      if(GlobalVariableCheck(gvSt) && (int)GlobalVariableGet(gvSt) == PARTIAL_INFLIGHT)
         GlobalVariableSet(gvSt, (double)PARTIAL_WAITING);
   }

   DestravarPosicao(posTkt);
   return false;
}

//--- plano da posicao
void InicializarPlanoParciais(ulong posTkt, double volInicial)
{
   if(!ParciaisNaPosicao(posTkt)) return;
   if(posTkt == 0 || volInicial <= 0) return;
   volInicial = NormalizeVol(volInicial);
   if(volInicial <= 0 || GlobalVariableCheck(GVInitVol(posTkt))) return;

   GlobalVariableSet(GVInitVol(posTkt), volInicial);

   double t1, t2;
   CalcularAlvosParciais(volInicial, t1, t2);
   double alvos[2];
   alvos[0] = t1; alvos[1] = t2;

   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      GlobalVariableSet(GVTarget(posTkt, p), alvos[p - 1]);
      GlobalVariableSet(GVClosed(posTkt, p), 0.0);
      GlobalVariableSet(GVState(posTkt, p),
         (double)((alvos[p - 1] <= 0) ? PARTIAL_DONE : PARTIAL_WAITING));
   }

   DestravarPosicao(posTkt);
   if(GlobalVariableCheck(GVLastDeal(posTkt))) GlobalVariableDel(GVLastDeal(posTkt));
   if(InpLogDetalhado)
      PrintFormat("Scalper Pro: plano de parciais #%I64u vol=%.2f P1=%.2f@%.0fpts P2=%.2f@%.0fpts",
                  posTkt, volInicial, t1, Partial1_Points, t2, Partial2_Points);
}

void ReanexarPlanosParciais()
{
   if(!ParciaisAtivas()) return;
   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if(!GlobalVariableCheck(GVInitVol(t)))
      {
         double v = PositionGetDouble(POSITION_VOLUME);
         if(v > 0) InicializarPlanoParciais(t, v);
      }
   }
}

void LimparGVsParciais(ulong posTkt)
{
   if(posTkt == 0) return;
   if(GlobalVariableCheck(GVInitVol(posTkt)))  GlobalVariableDel(GVInitVol(posTkt));
   if(GlobalVariableCheck(GVLastDeal(posTkt))) GlobalVariableDel(GVLastDeal(posTkt));
   if(GlobalVariableCheck(GVSlP1(posTkt)))     GlobalVariableDel(GVSlP1(posTkt));
   if(GlobalVariableCheck(GVSlP2(posTkt)))     GlobalVariableDel(GVSlP2(posTkt));
   DestravarPosicao(posTkt);
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      if(GlobalVariableCheck(GVTarget(posTkt, p))) GlobalVariableDel(GVTarget(posTkt, p));
      if(GlobalVariableCheck(GVClosed(posTkt, p))) GlobalVariableDel(GVClosed(posTkt, p));
      if(GlobalVariableCheck(GVState(posTkt, p)))  GlobalVariableDel(GVState(posTkt, p));
      if(GlobalVariableCheck(GVUltimaTentativa(posTkt, p))) GlobalVariableDel(GVUltimaTentativa(posTkt, p));
   }
}

ulong ResolverTicketParciais(ulong posId)
{
   if(posId == 0) return 0;

   if(GlobalVariableCheck(GVPosTicket(posId)))
   {
      ulong tk = (ulong)GlobalVariableGet(GVPosTicket(posId));
      if(tk > 0 && GlobalVariableCheck(GVInitVol(tk)))
         return tk;
   }

   if(GlobalVariableCheck(GVInitVol(posId)))
      return posId;

   for(int i = 0; i < PositionsTotal(); i++)
   {
      ulong t = PositionGetTicket(i);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      ulong ident = (ulong)PositionGetInteger(POSITION_IDENTIFIER);
      if(ident == posId && GlobalVariableCheck(GVInitVol(t)))
         return t;
   }
   return posId;
}

//--- confirmacao do fechamento parcial
bool BuscarDealSaidaRecente(ulong posTkt, double volAntes, double &dealVol, ulong &dealTkt)
{
   dealVol = 0;
   dealTkt = 0;
   if(!HistorySelect(TimeCurrent() - 120, TimeCurrent() + 60)) return false;

   ulong posId = ResolverPositionId(posTkt);
   if(posId == 0) posId = posTkt;

   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
   {
      ulong d = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(d, DEAL_POSITION_ID) != posId) continue;
      if(HistoryDealGetString(d, DEAL_SYMBOL) != _Symbol) continue;
      long entry = HistoryDealGetInteger(d, DEAL_ENTRY);
      if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_INOUT) continue;
      if(DealJaProcessado(posTkt, d)) continue;
      dealVol = HistoryDealGetDouble(d, DEAL_VOLUME);
      dealTkt = d;
      return (dealVol > 0 && dealVol <= volAntes + VolTolerance());
   }
   return false;
}

void ConfirmarFechamentoParcial(ulong posTkt, int partialId, double dealVol, ulong dealTkt)
{
   if(!ParciaisAtivas()) return;
   if(partialId < 1 || partialId > PARTIAL_COUNT || dealVol <= 0) return;
   if(!GlobalVariableCheck(GVInitVol(posTkt))) return;
   if(dealTkt > 0 && DealJaProcessado(posTkt, dealTkt)) return;

   dealVol = NormalizeVol(dealVol);
   if(dealVol <= 0) return;

   string gvSt = GVState(posTkt, partialId);
   if(GlobalVariableCheck(gvSt) && (int)GlobalVariableGet(gvSt) == PARTIAL_DONE)
      return;

   double alvo    = GlobalVariableGet(GVTarget(posTkt, partialId));
   double fechado = GlobalVariableGet(GVClosed(posTkt, partialId));
   double tol     = VolTolerance();
   if(alvo > 0 && fechado >= alvo - tol)
      return;

   fechado = NormalizeVol(fechado + dealVol);
   if(alvo > 0 && fechado > alvo) fechado = alvo;
   GlobalVariableSet(GVClosed(posTkt, partialId), fechado);

   if(alvo <= 0 || fechado >= alvo - tol)
   {
      GlobalVariableSet(gvSt, (double)PARTIAL_DONE);
      if(alvo > 0) GlobalVariableSet(GVClosed(posTkt, partialId), alvo);
      SetParcialLabel(partialId, "Executada", clrLime);
      Status(StringFormat("Parcial P%d executada (%.2f)", partialId, alvo), C_STATUS_OK, true);
      if(partialId == 1)
         AvancarSLTrailAposP1(posTkt);
      else if(partialId == 2)
         AvancarSLParaPontosP1(posTkt);
   }
   else
   {
      GlobalVariableSet(gvSt, (double)PARTIAL_TRIGGERED);
      double pct = (alvo > 0) ? (fechado / alvo) * 100.0 : 0;
      SetParcialLabel(partialId, DoubleToString(pct, 0) + "%", PartialStatusColor(partialId));
   }

   if(dealTkt > 0)
      MarcarDealProcessado(posTkt, dealTkt);
   DestravarPosicao(posTkt);
}

// Chamado pelo OnTradeTransaction para deals de saida que NAO fecharam a posicao.
void ConfirmarParcialPorDeal(ulong posId, ulong dealTkt)
{
   if(!ParciaisAtivas() || posId == 0 || dealTkt == 0) return;

   ulong posTkt = 0;
   for(int pi = 0; pi < PositionsTotal(); pi++)
   {
      ulong t = PositionGetTicket(pi);
      if(t == 0 || !PositionSelectByTicket(t)) continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
      if((ulong)PositionGetInteger(POSITION_IDENTIFIER) == posId) { posTkt = t; break; }
   }
   if(posTkt == 0 || !GlobalVariableCheck(GVInitVol(posTkt)))
      posTkt = ResolverTicketParciais(posId);
   if(!GlobalVariableCheck(GVInitVol(posTkt)) || DealJaProcessado(posTkt, dealTkt)) return;
   if(!HistoryDealSelect(dealTkt)) return;

   double dealVol = HistoryDealGetDouble(dealTkt, DEAL_VOLUME);
   if(dealVol <= 0) return;

   int partialId = ObterParcialAtiva(posTkt);
   if(partialId < 1) return;
   string gvSt = GVState(posTkt, partialId);
   if(GlobalVariableCheck(gvSt) && (int)GlobalVariableGet(gvSt) == PARTIAL_INFLIGHT)
      ConfirmarFechamentoParcial(posTkt, partialId, dealVol, dealTkt);
}

//--- SL apos as parciais
void AvancarSLTrailAposP1(ulong posTkt)
{
   if(!InpTrailAvancaAposP1 || InpTrailAvancaPtsP1 <= 0) return;
   if(GlobalVariableCheck(GVSlP1(posTkt))) return;
   if(!PositionSelectByTicket(posTkt)) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   double minDist = DistanciaMinimaStops();
   double pt      = ObterPontoPreco();
   double pts     = (double)InpTrailAvancaPtsP1;

   long   tipo    = PositionGetInteger(POSITION_TYPE);
   double open    = PositionGetDouble(POSITION_PRICE_OPEN);
   double slAtual = PositionGetDouble(POSITION_SL);
   double tp      = PositionGetDouble(POSITION_TP);
   double novoSL;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(tipo == POSITION_TYPE_BUY)
   {
      novoSL = NormalizeDouble(open + pts * pt, _Digits);
      double slMax = NormalizeDouble(bid - minDist, _Digits);
      if(novoSL > slMax) novoSL = slMax;
      if(slAtual > 0 && novoSL <= slAtual + pt * 0.5)
      {
         GlobalVariableSet(GVSlP1(posTkt), 1.0);
         return;
      }
   }
   else
   {
      novoSL = NormalizeDouble(open - pts * pt, _Digits);
      double slMin = NormalizeDouble(ask + minDist, _Digits);
      if(novoSL < slMin) novoSL = slMin;
      if(slAtual > 0 && novoSL >= slAtual - pt * 0.5)
      {
         GlobalVariableSet(GVSlP1(posTkt), 1.0);
         return;
      }
   }

   if(MathAbs(novoSL - slAtual) <= pt * 0.5)
   {
      GlobalVariableSet(GVSlP1(posTkt), 1.0);
      return;
   }

   if(ModificarNiveisPosicaoEA(posTkt, novoSL, tp))
   {
      GlobalVariableSet(GVSlP1(posTkt), 1.0);
      double lucroPts = LucroPontosPosicao(posTkt);
      if(TrailingStart > 0 && TrailingStep > 0 && lucroPts >= TrailingStart)
      {
         double slTrailBuy  = NormalizeDouble(open + TrailingStep * pt, _Digits);
         double slTrailSell = NormalizeDouble(open - TrailingStep * pt, _Digits);
         if(tipo == POSITION_TYPE_BUY && novoSL >= slTrailBuy - pt * 0.5)
            GlobalVariableSet(GVTrailFixo(posTkt), 1.0);
         else if(tipo == POSITION_TYPE_SELL && novoSL <= slTrailSell + pt * 0.5)
            GlobalVariableSet(GVTrailFixo(posTkt), 1.0);
      }
      if(GlobalVariableCheck(GVTrailFixo(posTkt)))
         RemoverLinhaTrailing(posTkt);
      else
         AtualizarLinhaTrailing(posTkt);
      AgendarRotulosSLTPPosicao(posTkt);
      if(InpLogDetalhado)
         PrintFormat("Scalper Pro: SL apos P1 ticket=%I64u novoSL=%.5f pts=%d",
                     posTkt, novoSL, InpTrailAvancaPtsP1);
   }
}

void AvancarSLParaPontosP1(ulong posTkt)
{
   if(!InpSlAvancaAposP2 || GlobalVariableCheck(GVSlP2(posTkt))) return;
   if(!PositionSelectByTicket(posTkt)) return;
   if(PositionGetString(POSITION_SYMBOL) != _Symbol) return;

   if(Partial1_Points <= 0) return;

   double minDist = DistanciaMinimaStops();

   long   tipo    = PositionGetInteger(POSITION_TYPE);
   double open    = PositionGetDouble(POSITION_PRICE_OPEN);
   double slAtual = PositionGetDouble(POSITION_SL);
   double tp      = PositionGetDouble(POSITION_TP);
   double pt      = ObterPontoPreco();
   double pts     = Partial1_Points;
   double novoSL;
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   if(tipo == POSITION_TYPE_BUY)
   {
      novoSL = NormalizeDouble(open + pts * pt, _Digits);
      double slMax = NormalizeDouble(bid - minDist, _Digits);
      if(novoSL > slMax) novoSL = slMax;
      if(slAtual > 0 && novoSL <= slAtual + pt * 0.5) return;
   }
   else
   {
      novoSL = NormalizeDouble(open - pts * pt, _Digits);
      double slMin = NormalizeDouble(ask + minDist, _Digits);
      if(novoSL < slMin) novoSL = slMin;
      if(slAtual > 0 && novoSL >= slAtual - pt * 0.5) return;
   }

   if(MathAbs(novoSL - slAtual) <= pt) return;

   if(ModificarNiveisPosicaoEA(posTkt, novoSL, tp))
   {
      GlobalVariableSet(GVSlP2(posTkt), 1.0);
      if(TrailingStart > 0 && TrailingStep > 0 && LucroPontosPosicao(posTkt) >= TrailingStart)
         GlobalVariableSet(GVTrailFixo(posTkt), 1.0);
      RemoverLinhaTrailing(posTkt);
      AgendarRotulosSLTPPosicao(posTkt);
   }
}

//--- envio
bool FecharVolumePorDeal(ulong posTkt, double volume, bool &fechouTotal, string &erro)
{
   fechouTotal = false;
   erro = "";
   if(!PositionSelectByTicket(posTkt)) { erro = "Posicao nao encontrada"; return false; }

   string sym    = PositionGetString(POSITION_SYMBOL);
   long   tipo   = PositionGetInteger(POSITION_TYPE);
   double volPos = PositionGetDouble(POSITION_VOLUME);

   volume = NormalizeVol(volume);
   if(volume <= 0) { erro = "Volume zero"; return false; }

   if(volume >= volPos - VolTolerance())
   {
      volume = NormalizeVol(volPos);
      fechouTotal = true;
   }

   if(!AjustarVolumeParcial(volPos, volume))
   {
      erro = "Volume invalido";
      return false;
   }

   MqlTradeRequest req;
   MqlTradeResult  res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action       = TRADE_ACTION_DEAL;
   req.position     = posTkt;
   req.symbol       = sym;
   req.volume       = volume;
   req.deviation    = 50;
   req.magic        = 0;
   req.type_filling = ObterFilling(sym);
   req.comment      = "SP_Partial";

   MqlTick tick;
   if(SymbolInfoTick(sym, tick))
   {
      if(tipo == POSITION_TYPE_BUY) { req.type = ORDER_TYPE_SELL; req.price = tick.bid; }
      else                          { req.type = ORDER_TYPE_BUY;  req.price = tick.ask; }
   }
   else
   {
      if(tipo == POSITION_TYPE_BUY) { req.type = ORDER_TYPE_SELL; req.price = SymbolInfoDouble(sym, SYMBOL_BID); }
      else                          { req.type = ORDER_TYPE_BUY;  req.price = SymbolInfoDouble(sym, SYMBOL_ASK); }
   }

   if(!OrderSend(req, res))
   {
      erro = StringFormat("OrderSend err=%d ret=%u", GetLastError(), res.retcode);
      return false;
   }

   if(res.retcode != TRADE_RETCODE_DONE &&
      res.retcode != TRADE_RETCODE_PLACED &&
      res.retcode != TRADE_RETCODE_DONE_PARTIAL)
   {
      erro = StringFormat("ret=%u %s", res.retcode, res.comment);
      return false;
   }

   // Copiador: as filhas reduzem na mesma proporcao assim que a mae publica o novo volume
   if(g_copyModoEf == COPY_MAE)
      CopyMae_Publicar(false);
   return true;
}

bool ConfirmarVolumeReduzido(ulong posTkt, double volAntes, int partialId)
{
   for(int i = 0; i < 16; i++)
   {
      double dv = 0;
      ulong  dt = 0;
      if(BuscarDealSaidaRecente(posTkt, volAntes, dv, dt))
      {
         ConfirmarFechamentoParcial(posTkt, partialId, dv, dt);
         return true;
      }

      if(!PositionSelectByTicket(posTkt))
      {
         ConfirmarFechamentoParcial(posTkt, partialId, volAntes, 0);
         return true;
      }

      double volAgora = PositionGetDouble(POSITION_VOLUME);
      if(volAgora < volAntes - VolTolerance())
      {
         ConfirmarFechamentoParcial(posTkt, partialId, NormalizeVol(volAntes - volAgora), 0);
         return true;
      }

      if(i < 15)
         Sleep(50);
   }
   return false;
}

bool ExecutarFechamentoVolume(ulong posTkt, double volEnvia, double volAntes, int partialId, bool &aguardandoConfirm)
{
   aguardandoConfirm = false;
   string erro = "";
   bool fechouTotal = false;

   if(!FecharVolumePorDeal(posTkt, volEnvia, fechouTotal, erro))
   {
      Status("Erro parcial P" + IntegerToString(partialId) + ": " + erro, clrRed, true);
      SetParcialLabel(partialId, "Erro", clrRed);
      PrintFormat("Scalper Pro: erro na parcial P%d #%I64u vol=%.2f: %s", partialId, posTkt, volEnvia, erro);
      return false;
   }

   if(ConfirmarVolumeReduzido(posTkt, volAntes, partialId))
      return true;

   aguardandoConfirm = true;
   return true;
}

bool EnviarParcial(ulong posTkt, int partialId)
{
   if(!ParciaisAtivas()) return false;
   if(!PositionSelectByTicket(posTkt)) return false;

   string gvUT = GVUltimaTentativa(posTkt, partialId);
   if(InpCooldownMs > 0 && GlobalVariableCheck(gvUT))
   {
      ulong elapsed = GetTickCount64() - (ulong)GlobalVariableGet(gvUT);
      if(elapsed < (ulong)InpCooldownMs)
         return false;
   }
   GlobalVariableSet(gvUT, (double)GetTickCount64());

   double alvo     = GlobalVariableGet(GVTarget(posTkt, partialId));
   double fechado  = GlobalVariableGet(GVClosed(posTkt, partialId));
   double volAtual = PositionGetDouble(POSITION_VOLUME);
   double volAntes = volAtual;
   double tol      = VolTolerance();
   string gvSt     = GVState(posTkt, partialId);

   if(alvo <= 0)
   {
      GlobalVariableSet(gvSt, (double)PARTIAL_DONE);
      SetParcialLabel(partialId, "Executada", clrLime);
      return true;
   }

   double falta = NormalizeVol(alvo - fechado);
   if(falta <= tol)
   {
      GlobalVariableSet(gvSt, (double)PARTIAL_DONE);
      GlobalVariableSet(GVClosed(posTkt, partialId), alvo);
      SetParcialLabel(partialId, "Executada", clrLime);
      return true;
   }

   double volEnvia = NormalizeVol(MathMin(falta, volAtual));
   if(volEnvia <= 0) return false;

   SetParcialLabel(partialId, "Enviando...", clrOrange);

   TravarPosicao(posTkt, partialId);
   GlobalVariableSet(gvSt, (double)PARTIAL_INFLIGHT);

   bool aguardando = false;
   bool ok = ExecutarFechamentoVolume(posTkt, volEnvia, volAntes, partialId, aguardando);
   DestravarPosicao(posTkt);

   if(!ok)
   {
      GlobalVariableSet(gvSt, (double)PARTIAL_WAITING);
      if(ObjectGetString(0, PartialStatusObject(partialId), OBJPROP_TEXT) == "Enviando...")
         SetParcialLabel(partialId, "Falhou", clrRed);
      return false;
   }

   if(aguardando)
      SetParcialLabel(partialId, "Aguardando...", clrOrange);

   return true;
}

void ProcessarParciaisPosicao(ulong posTkt)
{
   if(!ParciaisNaPosicao(posTkt)) return;

   if(!GlobalVariableCheck(GVInitVol(posTkt)))
   {
      if(!PositionSelectByTicket(posTkt)) return;
      double vol = PositionGetDouble(POSITION_VOLUME);
      if(vol > 0) InicializarPlanoParciais(posTkt, vol);
      else return;
   }

   if(PosicaoComLock(posTkt))
   {
      AtualizarStatusParciaisPosicao(posTkt);
      return;
   }

   if(!PositionSelectByTicket(posTkt)) return;

   double lucroPts = LucroPontosPosicao(posTkt);
   double tol      = VolTolerance();
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string gvSt = GVState(posTkt, p);
      if(!GlobalVariableCheck(gvSt)) continue;

      int st = (int)GlobalVariableGet(gvSt);
      if(st == PARTIAL_DONE) continue;

      double pontos, pct;
      if(!PartialConfig(p, pontos, pct)) continue;

      if(!GatilhoParcialAtingidoPts(lucroPts, pontos))
      {
         AtualizarStatusParcialUI(posTkt, p);
         continue;
      }

      double alvo    = GlobalVariableGet(GVTarget(posTkt, p));
      double fechado = GlobalVariableGet(GVClosed(posTkt, p));
      if(alvo > 0 && fechado >= alvo - tol)
      {
         GlobalVariableSet(gvSt, (double)PARTIAL_DONE);
         SetParcialLabel(p, "Executada", clrLime);
         if(p == 1)
            AvancarSLTrailAposP1(posTkt);
         else if(p == 2)
            AvancarSLParaPontosP1(posTkt);
         continue;
      }

      if(st == PARTIAL_WAITING || st == PARTIAL_TRIGGERED)
      {
         for(int t = 0; t < InpTentativasEnvio; t++)
         {
            if(EnviarParcial(posTkt, p)) break;
            Sleep(100);
            if(!PositionSelectByTicket(posTkt)) return;
         }
         return;
      }
      if(st == PARTIAL_INFLIGHT)
         AtualizarStatusParcialUI(posTkt, p);
   }
}

void ExecutarParciais(ulong posTkt)
{
   if(!ParciaisAtivas()) { RemoverLinhasParciais(); return; }
   if(posTkt == 0) posTkt = TicketPosicaoSimbolo();
   if(posTkt > 0)
   {
      ProcessarParciaisPosicao(posTkt);
      AtualizarLinhasParciais(posTkt);
   }
}

//--- linhas finas pontilhadas no preco de P1 e P2 (somem quando a parcial sai)
string NomeLinhaParcial(const int p) { return PARC_LINHA_PREFIX + "P" + IntegerToString(p); }

void RemoverLinhasParciais()
{
   ObjectsDeleteAll(0, PARC_LINHA_PREFIX);
}

void AtualizarLinhasParciais(const ulong posTkt)
{
   if(!ParciaisNaPosicao(posTkt) || !GlobalVariableCheck(GVInitVol(posTkt)) || !PositionSelectByTicket(posTkt))
   {
      RemoverLinhasParciais();
      return;
   }
   long   tipo = PositionGetInteger(POSITION_TYPE);
   double open = PositionGetDouble(POSITION_PRICE_OPEN);
   double pt   = ObterPontoPreco();

   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string nome = NomeLinhaParcial(p);
      double pts, pct;
      PartialConfig(p, pts, pct);
      string gvSt = GVState(posTkt, p);
      bool feita = !GlobalVariableCheck(gvSt) || (int)GlobalVariableGet(gvSt) == PARTIAL_DONE
                   || pts <= 0 || GlobalVariableGet(GVTarget(posTkt, p)) <= 0;
      if(feita)
      {
         if(ObjectFind(0, nome) >= 0) ObjectDelete(0, nome);
         continue;
      }
      double preco = NormalizeDouble(tipo == POSITION_TYPE_BUY ? open + pts * pt : open - pts * pt, _Digits);
      if(ObjectFind(0, nome) < 0)
      {
         if(!ObjectCreate(0, nome, OBJ_HLINE, 0, 0, preco)) continue;
         ObjectSetInteger(0, nome, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, nome, OBJPROP_BACK, true);
         ObjectSetInteger(0, nome, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, nome, OBJPROP_HIDDEN, true);
         ObjectSetInteger(0, nome, OBJPROP_TIMEFRAMES, OBJ_ALL_PERIODS);
         ObjectSetString(0, nome, OBJPROP_TEXT, "P" + IntegerToString(p));
      }
      ObjectSetInteger(0, nome, OBJPROP_COLOR, C_PARC_LINHA);
      ObjectSetInteger(0, nome, OBJPROP_STYLE, STYLE_DOT);
      if(MathAbs(ObjectGetDouble(0, nome, OBJPROP_PRICE) - preco) > pt * 0.5)
         ObjectSetDouble(0, nome, OBJPROP_PRICE, preco);
      ObjectSetString(0, nome, OBJPROP_TOOLTIP,
                      StringFormat("P%d: %.0f pts, %.0f%% do lote", p, pts, pct));
   }
}

int ObterParcialAtiva(ulong posTkt)
{
   if(GlobalVariableCheck(GVLockPartial(posTkt)))
   {
      int lp = (int)GlobalVariableGet(GVLockPartial(posTkt));
      if(lp >= 1 && lp <= PARTIAL_COUNT) return lp;
   }
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string gvSt = GVState(posTkt, p);
      if(!GlobalVariableCheck(gvSt)) continue;
      int st = (int)GlobalVariableGet(gvSt);
      if(st == PARTIAL_INFLIGHT || st == PARTIAL_TRIGGERED) return p;
   }
   return 0;
}

// TP virtual: nao fecha tudo se uma parcial ainda pendente esta no mesmo nivel (ela sai primeiro).
bool ParcialPendenteNoNivelTP(ulong posTkt, double lucroPts)
{
   if(!ParciaisAtivas() || !GlobalVariableCheck(GVInitVol(posTkt))) return false;
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string gvSt = GVState(posTkt, p);
      if(!GlobalVariableCheck(gvSt)) continue;
      if((int)GlobalVariableGet(gvSt) == PARTIAL_DONE) continue;
      if(GlobalVariableGet(GVTarget(posTkt, p)) <= 0) continue;
      double pts, pct;
      if(!PartialConfig(p, pts, pct)) continue;
      if(pts > 0 && TakeProfit >= pts - 0.5 && GatilhoParcialAtingidoPts(lucroPts, pts))
         return true;
   }
   return false;
}

void AgendarResetStatusParciais()
{
   g_parciaisResetEm = TimeCurrent() + PARTIAL_UI_RESET_SEC;
}

void ProcessarResetStatusParciaisAgendado()
{
   if(g_parciaisResetEm <= 0) return;

   if(TemPosicaoNoSimbolo())
   {
      g_parciaisResetEm = 0;
      return;
   }

   if(TimeCurrent() < g_parciaisResetEm) return;

   g_parciaisResetEm = 0;
   ResetStatusParciais();
   ChartRedraw(0);
}

// Posicao fechada por completo: mostra o resultado de cada parcial por alguns segundos.
void FinalizarParciaisPorFechamentoTotal(ulong posTkt)
{
   if(posTkt == 0) return;
   bool tinhaPlano = false;
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string gvSt = GVState(posTkt, p);
      if(!GlobalVariableCheck(gvSt)) continue;
      tinhaPlano = true;
      double alvo = GlobalVariableGet(GVTarget(posTkt, p));
      double fech = GlobalVariableGet(GVClosed(posTkt, p));
      bool ok = (alvo > 0 && fech >= alvo - VolTolerance());
      GlobalVariableSet(gvSt, (double)PARTIAL_DONE);
      if(!ParciaisAtivas())
         SetParcialLabel(p, "OFF", C_MUTED);
      else
         SetParcialLabel(p, ok ? "Executada" : "Nao exec.", ok ? clrLime : clrGray);
   }
   RemoverLinhasParciais();
   if(tinhaPlano)
      AgendarResetStatusParciais();
}

//--- painel: secao PARCIAIS (titulo + botao ON/OFF + linhas P1 e P2)
// Cria/reposiciona a caixa de status; numa reposicao mantem o texto e a cor atuais.
void CriarCaixaStatusParcial(const string boxName, const string lblName, const int x, const int y,
                             const int w, const string txt, const color c)
{
   string t  = txt;
   color  cc = c;
   if(ObjectFind(0, lblName) >= 0)
   {
      t  = ObjectGetString(0, lblName, OBJPROP_TEXT);
      cc = (color)ObjectGetInteger(0, lblName, OBJPROP_COLOR);
   }
   CreateRect(boxName, x, y, w, PARC_ROW_H, C_GLASS_BG, cc);
   ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, boxName, OBJPROP_BACK, false);
   ObjectSetInteger(0, boxName, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, boxName, OBJPROP_ZORDER, 5);
   CreateLabelCentered(lblName, x + w / 2, y + PARC_ROW_H / 2, t, cc, 8, true);
   ObjectSetInteger(0, lblName, OBJPROP_ZORDER, 6);
   ObjectSetInteger(0, lblName, OBJPROP_SELECTABLE, false);
}

string EditPontosParcial(const int p) { return (p == 1) ? OBJ_EDIT_P1_PTS : OBJ_EDIT_P2_PTS; }
string EditPctParcial(const int p)    { return (p == 1) ? OBJ_EDIT_P1_PCT : OBJ_EDIT_P2_PCT; }

// Campo editavel: criar = cria e escreve o valor; reposicionar = so posicao e tamanho
// (nao apaga o que esta sendo digitado).
void PosicionarCampo(const string name, const int x, const int y, const int w, const int h,
                     const bool criar, const string texto)
{
   if(criar || ObjectFind(0, name) < 0)
   {
      CreateEditCampoParam(name, x, y, texto, w, h);
      return;
   }
   ReposicionarObjetoXY(name, x, y);
   ObjectSetInteger(0, name, OBJPROP_XSIZE, w);
   ObjectSetInteger(0, name, OBJPROP_YSIZE, h);
}

void CriarSecaoParciais(const int lx, const int y, const int divW, const bool criar)
{
   int x0  = lx + CARD_PAD;
   int inW = divW - CARD_PAD * 2;
   CreateGlassRect("SP_CARD_PARC", lx, y, divW, CARD_PARC_H);
   CreateLabel("SP_SEC_PARTIAL", x0, y + 10, "PARCIAIS", C_SEC_PARAMS, 8, true);
   CreateButton(OBJ_BTN_PARCIAIS, x0 + inW - BTN_PARC_W, y + 7, BTN_PARC_W, BTN_PARC_H + 2,
                ParciaisAtivas() ? "ON" : "OFF", 7);
   AtualizarBotaoParciais();

   int hy = y + 31;
   CreateLabel("SP_PH1", x0 + PARC_X_PTS, hy, "Gatilho (pts)", C_LABEL_COLOR, 7);
   CreateLabel("SP_PH2", x0 + PARC_X_PCT, hy, "% do lote", C_LABEL_COLOR, 7);
   CreateLabel("SP_PH3", x0 + PARC_X_ST, hy, "Status", C_LABEL_COLOR, 7);

   string st = ParciaisAtivas() ? "ATIVO" : "OFF";
   color  cs = ParciaisAtivas() ? C_STATUS_OK : C_MUTED;
   for(int p = 1; p <= PARTIAL_COUNT; p++)
   {
      string sp   = IntegerToString(p);
      int    rowY = y + 46 + (p - 1) * (PARC_ROW_H + 6);
      double pts  = (p == 1) ? Partial1_Points : Partial2_Points;
      double pct  = (p == 1) ? Partial1_Close : Partial2_Close;
      CreateLabel("SP_PRL" + sp, x0, rowY + 5, "P" + sp, PartialStatusColor(p), 10, true);
      PosicionarCampo(EditPontosParcial(p), x0 + PARC_X_PTS, rowY, PARC_W_PTS, PARC_ROW_H, criar, DoubleToString(pts, 0));
      PosicionarCampo(EditPctParcial(p), x0 + PARC_X_PCT, rowY, PARC_W_PCT, PARC_ROW_H, criar, DoubleToString(pct, 0));
      CriarCaixaStatusParcial(PartialStatusBox(p), PartialStatusObject(p),
                              x0 + PARC_X_ST, rowY, inW - PARC_X_ST, st, cs);
   }
}

void ReposicionarSecaoParciais(const int lx, const int y, const int divW)
{
   CriarSecaoParciais(lx, y, divW, false);
}

//--- Painel (opcao A): PARAMETROS (com o perfil) -> PARCIAIS -> COMPRA/FECHA/VENDA -> SYNC/LINHAS/LIMITES.
//    Devolve o Y do bloco de estado do dia (metricas).
int DigitosLote()
{
   double st = LotStep();
   int d = 0;
   while(st < 0.9999 && d < 8) { st *= 10; d++; }
   return MathMax(2, d);
}

string TextoLote()
{
   return DoubleToString(Lote, DigitosLote());
}

// -/+ do lote: uma unidade inteira por clique (0.20 -> 1.20 -> 2.20; 3.00 -> 2.00)
void AjustarLotePasso(const int dir)
{
   AtualizarCampos();
   double novo = NormalizeVolPainel(Lote + dir * 1.0);
   if(novo <= 0)
      novo = NormalizeVolPainel(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN));
   if(novo > 0)
      Lote = novo;
   EscreverValorCampoEdit(OBJ_EDIT_LOTE);
   SalvarConfigPainelPerfil(g_setupAtivo);
   ChartRedraw(0);
}

// -/+ do T.P. e do S.L.: 100 pts por clique (1000 -> 1100 -> 1200)
void AjustarPontosPasso(const string campo, const int dir)
{
   AtualizarCampos();
   if(campo == OBJ_EDIT_TP)
      TakeProfit = MathMax(0, TakeProfit + dir * PASSO_PONTOS_PAINEL);
   else if(campo == OBJ_EDIT_SL)
      StopLoss = MathMax(0, StopLoss + dir * PASSO_PONTOS_PAINEL);
   else
      return;
   EscreverValorCampoEdit(campo);
   SalvarConfigPainelPerfil(g_setupAtivo);
   ReconciliarLinhasTrailing();
   AtualizarRotulosSLTP();
   ChartRedraw(0);
}

void EstiloSegmentoPerfil(const string name, const bool ativo, const color corAtivo)
{
   if(ObjectFind(0, name) < 0) return;
   RemoverDecorBotao(name);
   ObjectSetString(0, name, OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 8);
   ObjectSetInteger(0, name, OBJPROP_BGCOLOR, ativo ? C_INPUT_BG : C_SEG_BG);
   ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, ativo ? C_BTN_BORDER : C_SEG_BG);
   ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, name, OBJPROP_COLOR, ativo ? corAtivo : C_LABEL_COLOR);
   ObjectSetInteger(0, name, OBJPROP_STATE, false);
}

void AtualizarSegmentoPerfil()
{
   bool vol = SetupVolatilAtivo();
   EstiloSegmentoPerfil(OBJ_BTN_PERF_N, !vol, C_NOME_COLOR);
   EstiloSegmentoPerfil(OBJ_BTN_PERF_V, vol, C_STATUS_WARN);
   if(ObjectFind(0, OBJ_BTN_PERF_N) >= 0)
      ObjectSetString(0, OBJ_BTN_PERF_N, OBJPROP_TOOLTIP, vol ? "Mudar para o perfil NORMAL" : "Perfil NORMAL ativo");
   if(ObjectFind(0, OBJ_BTN_PERF_V) >= 0)
      ObjectSetString(0, OBJ_BTN_PERF_V, OBJPROP_TOOLTIP, vol ? "Perfil VOLATIL ativo" : "Mudar para o perfil VOLATIL");
}

void RotuloCampo(const string name, const int x, const int y)
{
   CreateLabel(name, x, y, TextoRotuloParametro(name), CorRotuloParametro(name), 8);
   AplicarEstiloRotuloParametro(name);
}

void RotuloDireita(const string name, const int xDireita, const int y, const string texto, const color c)
{
   CreateLabel(name, xDireita, y, texto, c, 8);
   ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

void BotaoExecucao(const string name, const int x, const int y, const int w, const string titulo, const int tecla)
{
   CreateButton(name, x, y, w, EXEC_BTN_H, "", BTN_EXEC_FONT_SIZE);
   CreateLabelCentered(name + "_T1", x + w / 2, y + EXEC_BTN_H / 2 - 6, titulo, C_EXEC_TEXT_ON, 10, true);
   CreateLabelCentered(name + "_T2", x + w / 2, y + EXEC_BTN_H / 2 + 10, "tecla " + CharToString((uchar)tecla), C_EXEC_TEXT_ON, 7);
   string t[2];
   t[0] = name + "_T1"; t[1] = name + "_T2";
   for(int i = 0; i < 2; i++)
   {
      ObjectSetInteger(0, t[i], OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, t[i], OBJPROP_BACK, false);
      ObjectSetInteger(0, t[i], OBJPROP_ZORDER, 6);   // clique no rotulo = clique no botao
   }
   AplicarEstiloBotaoExec(name, false);
}

int DesenharSecoesPainel(const int lx, const int divW, const bool criar)
{
   int x0   = lx + CARD_PAD;
   int inW  = divW - CARD_PAD * 2;
   int colW = (inW - 10) / 2;
   int c1   = x0;
   int c2   = x0 + colW + 10;

   // PARAMETROS (o perfil fica no cartao: e ele que define os valores abaixo)
   int cy = PANEL_Y + PANEL_HEADER_H + PANEL_ACCENT_H + 10;
   CreateGlassRect("SP_CARD_PAR", lx, cy, divW, CARD_PAR_H);
   CreateLabel("SP_SEC_PARAMS", x0, cy + 10, "PARAMETROS", C_SEC_PARAMS, 8, true);
   int segW = 58;
   int segX = x0 + inW - (segW * 2 + 6);
   CreateRect("SP_PERF_BG", segX, cy + 6, segW * 2 + 6, 24, C_SEG_BG);
   CreateButton(OBJ_BTN_PERF_N, segX + 2, cy + 8, segW, 20, "Normal", 8);
   CreateButton(OBJ_BTN_PERF_V, segX + 4 + segW, cy + 8, segW, 20, "Volatil", 8);
   AtualizarSegmentoPerfil();

   int l1 = cy + 34, f1 = cy + 49, l2 = cy + 85, f2 = cy + 100;
   RotuloCampo("SP_LOTE", c1, l1);
   CreateButton(OBJ_BTN_LOTE_DN, c1, f1, 26, PFLD_H, "-", 11);
   PosicionarCampo(OBJ_EDIT_LOTE, c1 + 28, f1, colW - 56, PFLD_H, criar, TextoLote());
   CreateButton(OBJ_BTN_LOTE_UP, c1 + colW - 26, f1, 26, PFLD_H, "+", 11);

   RotuloCampo("SP_TP", c2, l1);
   RotuloDireita("SP_TPU", c2 + colW, l1, "pts", C_MUTED);
   CreateButton(OBJ_BTN_TP_DN, c2, f1, 26, PFLD_H, "-", 11);
   PosicionarCampo(OBJ_EDIT_TP, c2 + 28, f1, colW - 56, PFLD_H, criar, DoubleToString(TakeProfit, 0));
   CreateButton(OBJ_BTN_TP_UP, c2 + colW - 26, f1, 26, PFLD_H, "+", 11);

   RotuloCampo("SP_SL", c1, l2);
   RotuloDireita("SP_SLU", c1 + colW, l2, "pts", C_MUTED);
   CreateButton(OBJ_BTN_SL_DN, c1, f2, 26, PFLD_H, "-", 11);
   PosicionarCampo(OBJ_EDIT_SL, c1 + 28, f2, colW - 56, PFLD_H, criar, DoubleToString(StopLoss, 0));
   CreateButton(OBJ_BTN_SL_UP, c1 + colW - 26, f2, 26, PFLD_H, "+", 11);

   RotuloCampo("SP_ST", c2, l2);
   CreateLabel("SP_TR", c2 + colW, l2, TextoRotuloParametro("SP_TR"), CorRotuloParametro("SP_TR"), 7, true);
   ObjectSetInteger(0, "SP_TR", OBJPROP_ANCHOR, ANCHOR_RIGHT_UPPER);
   AplicarEstiloRotuloParametro("SP_TR");
   ObjectSetString(0, "SP_TR", OBJPROP_FONT, UI_FONT_BOLD);
   ObjectSetInteger(0, "SP_TR", OBJPROP_FONTSIZE, 7);
   int hw = (colW - 6) / 2;
   PosicionarCampo(OBJ_EDIT_TRAIL_START, c2, f2, hw, PFLD_H, criar, DoubleToString(TrailingStart, 0));
   PosicionarCampo(OBJ_EDIT_TRAIL_STEP, c2 + colW - hw, f2, hw, PFLD_H, criar, DoubleToString(TrailingStep, 0));

   // PARCIAIS
   int py = cy + CARD_PAR_H + GAP_CARD;
   CriarSecaoParciais(lx, py, divW, criar);

   // EXECUCAO: botoes grandes com a tecla de atalho
   int ye = py + CARD_PARC_H + GAP_CARD_EXEC;
   int bw = (divW - 16) / 3;
   BotaoExecucao(OBJ_BTN_BUY,      lx,                ye, bw,                    "COMPRA", InpTeclaBuy);
   BotaoExecucao(OBJ_BTN_CLOSEALL, lx + bw + 8,       ye, bw,                    "FECHA",  InpTeclaFechar);
   BotaoExecucao(OBJ_BTN_SELL,     lx + (bw + 8) * 2, ye, divW - (bw + 8) * 2,   "VENDA",  InpTeclaSell);

   // ACOES SECUNDARIAS
   int ya = ye + EXEC_BTN_H + GAP_EXEC_AUX;
   CreateButton(OBJ_BTN_SYNC_HL, lx, ya, 10, SEC_AUX_BTN_H, "SYNC", 7);
   CreateButton(OBJ_BTN_LINHAS, lx, ya, 10, SEC_AUX_BTN_H, "LINHAS", 7);
   CreateButton(OBJ_BTN_LIMITS, lx, ya, 10, SEC_AUX_BTN_H, "LIMITES", 7);
   ReposicionarBotoesAux(lx, divW, ya);

   return ya + SEC_AUX_BTN_H + GAP_AUX_MET;
}

// Le os campos P1/P2 do painel (chamado por AtualizarCampos).
void LerCamposParciais()
{
   if(ObjectFind(0, OBJ_EDIT_P1_PTS) >= 0)
      Partial1_Points = StringToDouble(ObjectGetString(0, OBJ_EDIT_P1_PTS, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_P1_PCT) >= 0)
      Partial1_Close = StringToDouble(ObjectGetString(0, OBJ_EDIT_P1_PCT, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_P2_PTS) >= 0)
      Partial2_Points = StringToDouble(ObjectGetString(0, OBJ_EDIT_P2_PTS, OBJPROP_TEXT));
   if(ObjectFind(0, OBJ_EDIT_P2_PCT) >= 0)
      Partial2_Close = StringToDouble(ObjectGetString(0, OBJ_EDIT_P2_PCT, OBJPROP_TEXT));

   double p1c = Partial1_Close, p2c = Partial2_Close;
   SanitizarConfigParciais();
   // corrige o que foi digitado (ex.: P1 60% + P2 50% vira P2 40%), fora de uma edicao em andamento
   if(g_campoEditAtivo == "" && (p1c != Partial1_Close || p2c != Partial2_Close))
   {
      EscreverValorCampoEdit(OBJ_EDIT_P1_PCT);
      EscreverValorCampoEdit(OBJ_EDIT_P2_PCT);
   }
}
