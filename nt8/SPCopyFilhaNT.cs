// ============================================================================
//  SP Copy Filha NT8  -  filha NinjaTrader 8 do copiador do Scalper Pro (MT5)
// ----------------------------------------------------------------------------
//  Le o arquivo de estado que a MAE (Scalper Pro, modo Mae) grava em
//  %APPDATA%\MetaQuotes\Terminal\Common\Files\SP_Copy_<canal>.txt e replica
//  na conta selecionada desta estrategia (ex.: conta Tradovate) usando o
//  instrumento desta estrategia (ex.: MNQ 12-26, NQ, MGC, GC).
//
//  Mesma logica da filha MT5: copia POSICOES, nao sinais.
//   - posicao nova na mae      -> abre a mercado com SL/TP obrigatorio
//                                 (template ATM ou bracket SL/TP em ticks)
//   - posicao some da mae      -> zera o instrumento na conta (Flatten)
//   - filha saiu por SL/TP     -> nao reabre enquanto a posicao da mae existir
//   - reinicio de qualquer lado-> estado reconciliado pelo arquivo
//  Grava SP_CopyAck_<canal>_NT-<conta>.txt para a faixa da mae contar esta
//  filha como conectada/pronta.
//
//  Instalacao: copiar para Documentos\NinjaTrader 8\bin\Custom\Strategies,
//  compilar (F5 no NinjaScript Editor) e adicionar na aba Estrategias com a
//  conta e o contrato da filha. Detalhes em nt8/LEIAME.md.
// ============================================================================
#region Using declarations
using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.ComponentModel.DataAnnotations;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Text;
using System.Threading;
using NinjaTrader.Cbi;
using NinjaTrader.NinjaScript;
#endregion

namespace NinjaTrader.NinjaScript.Strategies
{
    public class SPCopyFilhaNT : Strategy
    {
        [DllImport("kernel32.dll")]
        private static extern ulong GetTickCount64();   // mesmo relogio do MT5 (GetTickCount64)

        private const int MAE_VELHA_MS    = 3000;   // arquivo mais velho que isso: nao abre
        private const int ACK_MS          = 500;
        private const int TENT_MAX        = 3;
        private const int TENT_INTERV_MS  = 1000;
        private const int ESPERA_FILL_MS  = 10000;   // tempo maximo aguardando a posicao aparecer

        private class PosMae
        {
            public ulong  Id;
            public bool   Compra;
            public double Vol;
            public long   IdadeSeg;
        }

        // --- estado da mae (ultimo arquivo valido)
        private readonly List<PosMae> maePos = new List<PosMae>();
        private bool   maeValida;
        private ulong  maeTickMs;
        private long   maeSeq = -1;
        private long   maeLogin;
        private string maeSimbolo = "";
        private bool   maeOnline;

        // --- estado da copia (um instrumento = uma posicao na conta)
        private ulong  copiaIdMae;          // posicao da mae que esta copia segue (0 = nenhuma)
        private bool   copiaCompra;
        private bool   entradaPendente;
        private ulong  entradaEnvioMs;
        private ulong  entradaGravMaeMs;    // tick da mae quando a entrada foi enviada
        private bool   bracketEnviado;
        private string atmId = "";
        private ulong  fechamentoEnvioMs;
        private bool   logEntrada;          // proxima execucao do instrumento = entrada da copia
        private bool   logSaida;            // proxima execucao do instrumento = saida enviada pelo copiador
        private ulong  saidaEnvioMs;
        private readonly HashSet<ulong> tratados = new HashSet<ulong>();   // ids da mae ja copiados/ignorados
        private readonly Dictionary<ulong, int>   tentN  = new Dictionary<ulong, int>();
        private readonly Dictionary<ulong, ulong> tentMs = new Dictionary<ulong, ulong>();

        private System.Threading.Timer timer;
        private int    emCiclo;
        private ulong  ackUltMs;
        private string pastaCommon = "";
        private string arqEstado   = "";
        private string ultimoAviso = "";
        private ulong  ultimoAvisoMs;
        private bool   configOk;

        #region Parametros
        [NinjaScriptProperty]
        [Display(Name = "Canal", Description = "Mesmo canal configurado na mae (Scalper Pro)", GroupName = "1. Copiador", Order = 1)]
        public string Canal { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Simbolo da mae", Description = "Simbolo do grafico da mae aceito (ex.: US100, XAUUSD). Vazio = qualquer", GroupName = "1. Copiador", Order = 2)]
        public string SimboloMae { get; set; }

        [NinjaScriptProperty]
        [Range(5, 1000)]
        [Display(Name = "Intervalo de leitura (ms)", GroupName = "1. Copiador", Order = 3)]
        public int IntervaloMs { get; set; }

        [NinjaScriptProperty]
        [Range(0, 3600)]
        [Display(Name = "Idade maxima da posicao da mae (s)", Description = "Nao copia posicao aberta na mae ha mais tempo que isso. 0 = sem limite", GroupName = "1. Copiador", Order = 4)]
        public int IdadeMaxSeg { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Inverter direcao", GroupName = "1. Copiador", Order = 5)]
        public bool Inverter { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Pasta Common\\Files do MT5", Description = "Vazio = %APPDATA%\\MetaQuotes\\Terminal\\Common\\Files", GroupName = "1. Copiador", Order = 6)]
        public string PastaCommonFiles { get; set; }

        [NinjaScriptProperty]
        [Display(Name = "Template ATM", Description = "Nome do template ATM (quantidade, SL, TP, trailing). Vazio = usa contratos + SL/TP em ticks abaixo", GroupName = "2. Ordem / SL-TP", Order = 1)]
        public string TemplateAtm { get; set; }

        [NinjaScriptProperty]
        [Range(1, 1000)]
        [Display(Name = "Contratos (sem ATM)", GroupName = "2. Ordem / SL-TP", Order = 2)]
        public int Contratos { get; set; }

        [NinjaScriptProperty]
        [Range(0, 100000)]
        [Display(Name = "Stop loss (ticks, sem ATM)", Description = "Obrigatorio sem ATM. Pode ser distante: a filha fecha junto com a mae", GroupName = "2. Ordem / SL-TP", Order = 3)]
        public int StopTicks { get; set; }

        [NinjaScriptProperty]
        [Range(0, 100000)]
        [Display(Name = "Take profit (ticks, sem ATM)", Description = "Obrigatorio sem ATM. Pode ser distante: a filha fecha junto com a mae", GroupName = "2. Ordem / SL-TP", Order = 4)]
        public int AlvoTicks { get; set; }
        #endregion

        protected override void OnStateChange()
        {
            if (State == State.SetDefaults)
            {
                Name                         = "SPCopyFilhaNT";
                Description                  = "Filha NT8 do copiador Scalper Pro (MT5). Copia as posicoes da mae para esta conta/instrumento.";
                Calculate                    = Calculate.OnEachTick;
                EntriesPerDirection          = 1;
                IsExitOnSessionCloseStrategy = false;
                BarsRequiredToTrade          = 0;
                StartBehavior                = StartBehavior.ImmediatelySubmit;
                RealtimeErrorHandling        = RealtimeErrorHandling.IgnoreAllErrors;
                TraceOrders                  = false;

                Canal            = "SP1";
                SimboloMae       = "";
                IntervaloMs      = 10;
                IdadeMaxSeg      = 5;
                Inverter         = false;
                PastaCommonFiles = "";
                TemplateAtm      = "";
                Contratos        = 1;
                StopTicks        = 400;
                AlvoTicks        = 800;
            }
            else if (State == State.DataLoaded)
            {
                Canal = SanitizarCanal(Canal);
                pastaCommon = string.IsNullOrWhiteSpace(PastaCommonFiles)
                    ? Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MetaQuotes", "Terminal", "Common", "Files")
                    : PastaCommonFiles.Trim();

                string pastaEstado = Path.Combine(NinjaTrader.Core.Globals.UserDataDir, "SPCopy");
                Directory.CreateDirectory(pastaEstado);
                arqEstado = Path.Combine(pastaEstado, string.Format("estado_{0}_{1}_{2}.txt",
                    Canal, SanitizarNome(Account.Name), SanitizarNome(Instrument.FullName)));

                bool usaAtm = !string.IsNullOrWhiteSpace(TemplateAtm);
                configOk = usaAtm || (StopTicks > 0 && AlvoTicks > 0);
                if (!configOk)
                    Log("SPCopyFilhaNT: configure um Template ATM ou Stop/Take profit em ticks (> 0). Nenhuma entrada sera copiada.", LogLevel.Error);

                CarregarEstado();
            }
            else if (State == State.Realtime)
            {
                Account.ExecutionUpdate += OnExecucaoConta;
                Imprimir(string.Format("FILHA NT8 ativa | canal={0} | conta={1} | instrumento={2} | {3} | arquivo={4}",
                    Canal, Account.Name, Instrument.FullName,
                    string.IsNullOrWhiteSpace(TemplateAtm)
                        ? string.Format("{0} contrato(s) SL={1} TP={2} ticks", Contratos, StopTicks, AlvoTicks)
                        : "ATM '" + TemplateAtm + "'",
                    Path.Combine(pastaCommon, ArquivoMae())));
                timer = new System.Threading.Timer(OnTimer, null, IntervaloMs, IntervaloMs);
            }
            else if (State == State.Terminated)
            {
                if (timer != null)
                {
                    timer.Dispose();
                    timer = null;
                }
                if (Account != null)
                    Account.ExecutionUpdate -= OnExecucaoConta;
                SalvarEstado();
            }
        }

        protected override void OnBarUpdate()
        {
            // Toda a logica roda no timer (independe de ticks do instrumento).
        }

        private void OnTimer(object state)
        {
            if (Interlocked.CompareExchange(ref emCiclo, 1, 0) != 0) return;
            try
            {
                if (State == State.Realtime)
                    TriggerCustomEvent(o => Ciclo(), null);
            }
            catch (Exception ex)
            {
                Avisar("erro no timer: " + ex.Message);
            }
            finally
            {
                Interlocked.Exchange(ref emCiclo, 0);
            }
        }

        // ------------------------------------------------------------------
        //  Ciclo principal
        // ------------------------------------------------------------------
        private void Ciclo()
        {
            bool leu = LerArquivoMae();
            GravarAck();
            if (!maeValida)
            {
                Avisar("aguardando arquivo da mae " + Path.Combine(pastaCommon, ArquivoMae()));
                return;
            }
            if (!leu && maeSeq < 0) return;

            if (!string.IsNullOrWhiteSpace(SimboloMae) && !string.Equals(maeSimbolo, SimboloMae.Trim(), StringComparison.OrdinalIgnoreCase))
            {
                Avisar(string.Format("mae publica {0}, esperado {1}: copia ignorada", maeSimbolo, SimboloMae));
                return;
            }

            ulong agora = GetTickCount64();
            ulong idadeArq = agora > maeTickMs ? agora - maeTickMs : 0;
            bool online = idadeArq <= MAE_VELHA_MS;
            if (online != maeOnline)
            {
                Imprimir(online
                    ? string.Format("conectada a mae (conta {0}, {1}) | arquivo com {2} ms", maeLogin, maeSimbolo, idadeArq)
                    : string.Format("arquivo da mae sem atualizacao ha {0} ms (mae offline ou EA parado). Novas entradas suspensas.", idadeArq));
                maeOnline = online;
            }

            int    qtdFilha;
            bool   compraFilha;
            bool   temPos = PosicaoFilha(out qtdFilha, out compraFilha);

            // 1) Copia em andamento
            if (copiaIdMae != 0)
            {
                PosMae m = BuscarMae(copiaIdMae);
                bool direcaoMae = m != null && (Inverter ? !m.Compra : m.Compra);

                if (entradaPendente)
                {
                    if (temPos)
                    {
                        entradaPendente = false;
                        copiaCompra = compraFilha;
                    }
                    else if (agora - entradaEnvioMs > ESPERA_FILL_MS)
                    {
                        Imprimir(string.Format("entrada da copia de #{0} nao confirmada em {1} ms (rejeitada? mercado fechado?)", copiaIdMae, ESPERA_FILL_MS));
                        tratados.Remove(copiaIdMae);   // permite nova tentativa (limite TENT_MAX)
                        LimparCopia();
                        return;
                    }
                    else
                        return;
                }

                if (!temPos)
                {
                    if (fechamentoEnvioMs == 0)
                        Imprimir(string.Format("copia de #{0} encerrada na filha (SL/TP ou manual); nao sera reaberta", copiaIdMae));
                    LimparCopia();
                }
                else if (m == null)
                    Fechar("mae fechou");
                else if (compraFilha != direcaoMae)
                    Fechar("mae inverteu a posicao");
                else if (string.IsNullOrWhiteSpace(TemplateAtm) && !bracketEnviado)
                {
                    if (ExisteOrdemSaida())
                        bracketEnviado = true;   // ex.: NT8 reiniciado com SL/TP ja na corretora
                    else
                        EnviarBracket(compraFilha, qtdFilha);
                }
                return;
            }

            // 2) Nova posicao da mae
            foreach (PosMae m in maePos)
            {
                if (tratados.Contains(m.Id)) continue;

                if (!online)
                {
                    Avisar(string.Format("mae #{0} nao copiada agora: arquivo da mae desatualizado ha {1} ms", m.Id, idadeArq));
                    break;
                }
                if (IdadeMaxSeg > 0 && m.IdadeSeg > IdadeMaxSeg)
                {
                    MarcarTratado(m.Id);
                    Imprimir(string.Format("mae #{0} aberta ha {1} s, nao copiada (limite {2} s)", m.Id, m.IdadeSeg, IdadeMaxSeg));
                    continue;
                }
                if (!configOk)
                {
                    Avisar(string.Format("mae #{0} nao copiada: SL/TP nao configurado (Template ATM ou ticks)", m.Id));
                    break;
                }
                string motivo;
                if (!Pronta(out motivo))
                {
                    Avisar(string.Format("mae #{0} nao copiada agora: {1}", m.Id, motivo));
                    break;
                }
                if (temPos)
                {
                    MarcarTratado(m.Id);
                    Imprimir(string.Format("mae #{0} nao copiada: a conta ja tem posicao em {1} (manual?)", m.Id, Instrument.FullName));
                    continue;
                }
                if (!TentativaLiberada(m.Id)) break;

                Abrir(m, agora);
                break;   // uma posicao por instrumento
            }

            // 3) Ids tratados que a mae ja nao tem
            if (leu && tratados.Count > 0)
            {
                List<ulong> remover = new List<ulong>();
                foreach (ulong id in tratados)
                    if (BuscarMae(id) == null && id != copiaIdMae) remover.Add(id);
                if (remover.Count > 0)
                {
                    foreach (ulong id in remover) { tratados.Remove(id); tentN.Remove(id); tentMs.Remove(id); }
                    SalvarEstado();
                }
            }
        }

        // ------------------------------------------------------------------
        //  Ordens
        // ------------------------------------------------------------------
        private void Abrir(PosMae m, ulong agora)
        {
            bool compra = Inverter ? !m.Compra : m.Compra;
            OrderAction acao = compra ? OrderAction.Buy : OrderAction.SellShort;

            RegistrarTentativa(m.Id);
            copiaIdMae       = m.Id;
            copiaCompra      = compra;
            entradaPendente  = true;
            entradaEnvioMs   = agora;
            entradaGravMaeMs = maeTickMs;
            logEntrada       = true;
            bracketEnviado   = false;
            fechamentoEnvioMs = 0;

            try
            {
                if (!string.IsNullOrWhiteSpace(TemplateAtm))
                {
                    atmId = GetAtmStrategyUniqueId();
                    string ordemId = GetAtmStrategyUniqueId();
                    ulong idMae = m.Id;
                    AtmStrategyCreate(acao, OrderType.Market, 0, 0, TimeInForce.Day, ordemId, TemplateAtm.Trim(), atmId,
                        (erro, id) =>
                        {
                            if (erro == ErrorCode.NoError) return;
                            Imprimir(string.Format("falha ATM ao copiar mae #{0}: {1} (template '{2}' existe?)", idMae, erro, TemplateAtm));
                            if (copiaIdMae == idMae)
                            {
                                tratados.Remove(idMae);
                                LimparCopia();
                            }
                        });
                }
                else
                {
                    Order o = Account.CreateOrder(Instrument, compra ? OrderAction.Buy : OrderAction.Sell, OrderType.Market,
                        OrderEntry.Automated, TimeInForce.Day, Contratos, 0, 0, "", "SPC_" + m.Id, Core.Globals.MaxDate, null);
                    Account.Submit(new[] { o });
                }
                MarcarTratado(m.Id);
                Imprimir(string.Format("{0} {1} copiando mae #{2} ({3} {4}) | ordem enviada {5} ms apos a gravacao da mae",
                    compra ? "BUY" : "SELL",
                    string.IsNullOrWhiteSpace(TemplateAtm) ? Contratos + " contrato(s)" : "ATM '" + TemplateAtm + "'",
                    m.Id, maeSimbolo, m.Vol.ToString("0.00", CultureInfo.InvariantCulture),
                    agora > maeTickMs ? agora - maeTickMs : 0));
            }
            catch (Exception ex)
            {
                Imprimir(string.Format("falha ao copiar mae #{0}: {1}", m.Id, ex.Message));
                LimparCopia();
            }
        }

        private void EnviarBracket(bool compra, int qtd)
        {
            double medio = PrecoMedioFilha();
            if (medio <= 0) return;
            double tick = Instrument.MasterInstrument.TickSize;
            double sl = Instrument.MasterInstrument.RoundToTickSize(compra ? medio - StopTicks * tick : medio + StopTicks * tick);
            double tp = Instrument.MasterInstrument.RoundToTickSize(compra ? medio + AlvoTicks * tick : medio - AlvoTicks * tick);
            string oco = "SPC_OCO_" + copiaIdMae + "_" + DateTime.Now.Ticks;
            OrderAction saida = compra ? OrderAction.Sell : OrderAction.BuyToCover;

            Order stop = Account.CreateOrder(Instrument, saida, OrderType.StopMarket, OrderEntry.Automated, TimeInForce.Gtc,
                qtd, 0, sl, oco, "SPC_SL", Core.Globals.MaxDate, null);
            Order alvo = Account.CreateOrder(Instrument, saida, OrderType.Limit, OrderEntry.Automated, TimeInForce.Gtc,
                qtd, tp, 0, oco, "SPC_TP", Core.Globals.MaxDate, null);
            Account.Submit(new[] { stop, alvo });
            bracketEnviado = true;
            Imprimir(string.Format("SL/TP enviados: SL={0} TP={1} ({2}/{3} ticks, {4} contrato(s))",
                sl.ToString(CultureInfo.InvariantCulture), tp.ToString(CultureInfo.InvariantCulture), StopTicks, AlvoTicks, qtd));
        }

        private void Fechar(string motivo)
        {
            ulong agora = GetTickCount64();
            if (fechamentoEnvioMs != 0 && agora - fechamentoEnvioMs < 1000) return;   // aguarda o flatten anterior
            fechamentoEnvioMs = agora;
            saidaEnvioMs = agora;
            logSaida = true;
            Account.Flatten(new[] { Instrument });   // fecha a posicao e cancela SL/TP/ATM do instrumento
            Imprimir(string.Format("fechando copia de #{0} ({1}) | {2} ms desde a gravacao da mae",
                copiaIdMae, motivo, agora > maeTickMs ? agora - maeTickMs : 0));
        }

        private void OnExecucaoConta(object sender, ExecutionEventArgs e)
        {
            if (e == null || e.Execution == null || e.Execution.Instrument == null) return;
            if (e.Execution.Instrument.FullName != Instrument.FullName) return;
            ulong agora = GetTickCount64();

            if (logEntrada)
            {
                logEntrada = false;   // loga so a primeira execucao da entrada
                Imprimir(string.Format("execucao entrada {0} @ {1} | execucao {2} ms | desde gravacao da mae {3} ms",
                    e.Quantity, e.Price.ToString(CultureInfo.InvariantCulture),
                    agora - entradaEnvioMs, agora > entradaGravMaeMs ? agora - entradaGravMaeMs : 0));
            }
            else if (logSaida)
            {
                logSaida = false;
                Imprimir(string.Format("execucao saida {0} @ {1} | execucao {2} ms | desde gravacao da mae {3} ms",
                    e.Quantity, e.Price.ToString(CultureInfo.InvariantCulture),
                    agora - saidaEnvioMs, agora > maeTickMs ? agora - maeTickMs : 0));
            }
        }

        // ------------------------------------------------------------------
        //  Conta / posicao
        // ------------------------------------------------------------------
        private bool PosicaoFilha(out int qtd, out bool compra)
        {
            qtd = 0;
            compra = false;
            lock (Account.Positions)
            {
                foreach (NinjaTrader.Cbi.Position p in Account.Positions)
                {
                    if (p.Instrument.FullName != Instrument.FullName) continue;
                    if (p.MarketPosition == MarketPosition.Flat || p.Quantity == 0) continue;
                    qtd = p.Quantity;
                    compra = p.MarketPosition == MarketPosition.Long;
                    return true;
                }
            }
            return false;
        }

        // Ordens de saida ja ativas no instrumento (SL/TP enviados antes de um reinicio).
        private bool ExisteOrdemSaida()
        {
            lock (Account.Orders)
            {
                foreach (Order o in Account.Orders)
                {
                    if (o.Instrument.FullName != Instrument.FullName) continue;
                    if (o.OrderType != OrderType.StopMarket && o.OrderType != OrderType.StopLimit && o.OrderType != OrderType.Limit) continue;
                    if (o.OrderState == OrderState.Working || o.OrderState == OrderState.Accepted
                        || o.OrderState == OrderState.Submitted || o.OrderState == OrderState.ChangePending
                        || o.OrderState == OrderState.ChangeSubmitted)
                        return true;
                }
            }
            return false;
        }

        private double PrecoMedioFilha()
        {
            lock (Account.Positions)
            {
                foreach (NinjaTrader.Cbi.Position p in Account.Positions)
                    if (p.Instrument.FullName == Instrument.FullName && p.MarketPosition != MarketPosition.Flat)
                        return p.AveragePrice;
            }
            return 0;
        }

        private bool Pronta(out string motivo)
        {
            motivo = "";
            if (State != State.Realtime) { motivo = "estrategia fora do tempo real"; return false; }
            if (Account.Connection == null || Account.Connection.Status != ConnectionStatus.Connected)
            {
                motivo = "conta desconectada";
                return false;
            }
            if (!configOk) { motivo = "SL/TP nao configurado"; return false; }
            return true;
        }

        private void LimparCopia()
        {
            copiaIdMae        = 0;
            entradaPendente   = false;
            entradaEnvioMs    = 0;
            logEntrada        = false;
            bracketEnviado    = false;
            fechamentoEnvioMs = 0;
            atmId             = "";
            SalvarEstado();
        }

        private PosMae BuscarMae(ulong id)
        {
            foreach (PosMae m in maePos)
                if (m.Id == id) return m;
            return null;
        }

        private void MarcarTratado(ulong id)
        {
            tratados.Add(id);
            SalvarEstado();
        }

        private bool TentativaLiberada(ulong id)
        {
            int n;
            if (!tentN.TryGetValue(id, out n)) return true;
            if (n >= TENT_MAX)
            {
                MarcarTratado(id);
                Imprimir(string.Format("desistiu de copiar mae #{0} apos {1} tentativas", id, TENT_MAX));
                return false;
            }
            return GetTickCount64() - tentMs[id] >= (ulong)TENT_INTERV_MS;
        }

        private void RegistrarTentativa(ulong id)
        {
            int n;
            tentN.TryGetValue(id, out n);
            tentN[id]  = n + 1;
            tentMs[id] = GetTickCount64();
        }

        // ------------------------------------------------------------------
        //  Arquivos
        // ------------------------------------------------------------------
        private string ArquivoMae() { return "SP_Copy_" + Canal + ".txt"; }

        private static string LerTexto(string caminho)
        {
            using (FileStream fs = new FileStream(caminho, FileMode.Open, FileAccess.Read, FileShare.ReadWrite | FileShare.Delete))
            {
                byte[] buf = new byte[fs.Length];
                int lidos = 0;
                while (lidos < buf.Length)
                {
                    int r = fs.Read(buf, lidos, buf.Length - lidos);
                    if (r <= 0) break;
                    lidos += r;
                }
                return Encoding.ASCII.GetString(buf, 0, lidos);
            }
        }

        // Mesmo formato lido pela filha MT5. Retorna false se ausente ou incompleto.
        private bool LerArquivoMae()
        {
            string txt;
            try
            {
                string caminho = Path.Combine(pastaCommon, ArquivoMae());
                if (!File.Exists(caminho)) return false;
                txt = LerTexto(caminho);
            }
            catch (IOException) { return false; }
            catch (UnauthorizedAccessException) { return false; }

            string[] linhas = txt.Split('\n');
            if (linhas.Length < 2) return false;
            string[] c = linhas[0].Trim().Split('|');
            if (c.Length < 11 || c[0] != "SPCOPY") return false;
            int n;
            if (!int.TryParse(c[10], NumberStyles.Integer, CultureInfo.InvariantCulture, out n) || n < 0 || n > 200) return false;
            if (linhas.Length < n + 2 || linhas[n + 1].Trim() != "END|" + c[2]) return false;

            long seq = ParseLong(c[2]);
            ulong tick = (ulong)ParseLong(c[3]);
            if (seq == maeSeq && tick == maeTickMs) return true;

            long srvMae = ParseLong(c[4]);
            List<PosMae> tmp = new List<PosMae>();
            for (int k = 0; k < n; k++)
            {
                string[] p = linhas[k + 1].Trim().Split('|');
                if (p.Length < 8 || p[0] != "P") return false;
                tmp.Add(new PosMae
                {
                    Id       = (ulong)ParseLong(p[1]),
                    Compra   = p[2] == "B",
                    Vol      = ParseDouble(p[3]),
                    IdadeSeg = srvMae - ParseLong(p[7])
                });
            }

            maePos.Clear();
            maePos.AddRange(tmp);
            maeSeq     = seq;
            maeTickMs  = tick;
            maeLogin   = ParseLong(c[5]);
            maeSimbolo = c[6];
            maeValida  = true;
            return true;
        }

        // Confirmacao de presenca lida pela mae (faixa "MAE PRONTA | n FILHAS").
        private void GravarAck()
        {
            ulong agora = GetTickCount64();
            if (agora - ackUltMs < ACK_MS) return;
            ackUltMs = agora;
            string motivo;
            string txt = string.Format("ACK|{0}|{1}|NT-{2}|{3}|{4}\r\n", Canal, agora, SanitizarNome(Account.Name),
                Instrument.FullName, Pronta(out motivo) ? "1" : "0");
            try
            {
                string caminho = Path.Combine(pastaCommon, "SP_CopyAck_" + Canal + "_NT-" + SanitizarNome(Account.Name) + ".txt");
                using (FileStream fs = new FileStream(caminho, FileMode.Create, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete))
                {
                    byte[] b = Encoding.ASCII.GetBytes(txt);
                    fs.Write(b, 0, b.Length);
                }
            }
            catch (Exception) { /* proxima tentativa em ACK_MS */ }
        }

        // Estado local: copia atual e ids da mae ja tratados (sobrevive a reinicio do NT8).
        private void SalvarEstado()
        {
            if (string.IsNullOrEmpty(arqEstado)) return;
            try
            {
                StringBuilder sb = new StringBuilder();
                sb.Append(copiaIdMae).Append('|').Append(copiaCompra ? "B" : "S").Append('|');
                bool primeiro = true;
                foreach (ulong id in tratados)
                {
                    if (!primeiro) sb.Append(',');
                    sb.Append(id);
                    primeiro = false;
                }
                File.WriteAllText(arqEstado, sb.ToString());
            }
            catch (Exception) { }
        }

        private void CarregarEstado()
        {
            try
            {
                if (!File.Exists(arqEstado)) return;
                string[] p = File.ReadAllText(arqEstado).Trim().Split('|');
                if (p.Length < 3) return;
                copiaIdMae  = (ulong)ParseLong(p[0]);
                copiaCompra = p[1] == "B";
                foreach (string s in p[2].Split(','))
                    if (s.Trim().Length > 0) tratados.Add((ulong)ParseLong(s));
            }
            catch (Exception) { }
        }

        // ------------------------------------------------------------------
        //  Utilitarios
        // ------------------------------------------------------------------
        private void Imprimir(string msg)
        {
            Print(string.Format("{0:HH:mm:ss.fff} SPCopy FILHA NT8 [{1}]: {2}", DateTime.Now, Account != null ? Account.Name : "?", msg));
        }

        // Mensagem repetitiva: imprime no maximo a cada 5 s se for igual a anterior.
        private void Avisar(string msg)
        {
            ulong agora = GetTickCount64();
            if (msg == ultimoAviso && agora - ultimoAvisoMs < 5000) return;
            ultimoAviso = msg;
            ultimoAvisoMs = agora;
            Imprimir(msg);
        }

        private static long ParseLong(string s)
        {
            long v;
            return long.TryParse(s.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out v) ? v : 0;
        }

        private static double ParseDouble(string s)
        {
            double v;
            return double.TryParse(s.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out v) ? v : 0;
        }

        private static string SanitizarCanal(string c)
        {
            StringBuilder sb = new StringBuilder();
            foreach (char ch in (c ?? ""))
            {
                if (sb.Length >= 16) break;
                if ((ch >= '0' && ch <= '9') || (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '_' || ch == '-')
                    sb.Append(ch);
            }
            return sb.Length == 0 ? "SP1" : sb.ToString();
        }

        private static string SanitizarNome(string s)
        {
            StringBuilder sb = new StringBuilder();
            foreach (char ch in (s ?? ""))
                sb.Append(char.IsLetterOrDigit(ch) || ch == '-' || ch == '_' ? ch : '_');
            return sb.ToString();
        }
    }
}
