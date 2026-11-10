// ============================================================================
//  SPCentral - Central de Controle do Scalper Pro
// ----------------------------------------------------------------------------
//  Protege o plano de trading definido previamente:
//   - maximo de operacoes no dia, meta de pontos, limite de perda,
//     horario de inicio e horario limite de operacao;
//   - protecoes extras: parar apos N perdas seguidas, pausa apos cada perda
//     e protecao do lucro (devolver no maximo X pts do melhor resultado fechado);
//   - ao atingir um limite trava TODOS os Scalper Pro (MT5) e as filhas NT8:
//       perda           -> ZERAR: fecha as posicoes e depois as plataformas
//       meta/operacoes/horario -> sem novas entradas; a operacao em andamento
//                          termina normalmente e depois as plataformas fecham
//   - enquanto travada, fecha MT5 / NinjaTrader / TradingView se forem abertos;
//   - a trava dura ate o reset diario configurado; a SENHA MESTRA destrava antes;
//   - configuracoes so podem ser alteradas na janela de edicao (ex.: ate 09:00
//     e depois das 22:00); fora dela, so com a senha mestra;
//   - com a central fechada, os EAs ficam bloqueados (sem novas entradas).
//
//  Comunicacao: arquivos em %APPDATA%\MetaQuotes\Terminal\Common\Files
//   SP_Central_Ativa.txt            marca: EAs passam a obedecer a central
//   SP_Central_Cmd.txt              comando (CMD|1|tickMs|LIVRE/BLOQ/ZERAR|motivo|ate)
//   SP_Central_St_<conta>_<sim>.txt estado de cada EA/estrategia (1 s)
//   SP_Central_Tr_<conta>.txt       operacoes encerradas (pontos)
//
//  Compilar: central\compilar.bat (usa o csc.exe do .NET Framework do Windows)
// ============================================================================
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Runtime.InteropServices;
using System.Security.Cryptography;
using System.Text;
using System.Threading;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("SPCentral")]
[assembly: System.Reflection.AssemblyVersion("1.1.0.0")]

namespace SPCentral
{
    internal static class Program
    {
        [STAThread]
        private static void Main()
        {
            bool novo;
            using (Mutex mtx = new Mutex(true, "SPCentral_instancia_unica", out novo))
            {
                if (!novo)
                {
                    MessageBox.Show("A Central de Controle ja esta aberta (icone do escudo perto do relogio).",
                        "Central de Controle", MessageBoxButtons.OK, MessageBoxIcon.Information);
                    return;
                }
                Application.EnableVisualStyles();
                Application.SetCompatibleTextRenderingDefault(false);
                Application.Run(new FormCentral());
            }
        }
    }

    // ------------------------------------------------------------------------
    //  Utilitarios
    // ------------------------------------------------------------------------
    internal static class Util
    {
        [DllImport("kernel32.dll")]
        public static extern ulong GetTickCount64();

        public static readonly string PastaApp = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SPCentral");

        public static readonly string PastaCommon = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.ApplicationData), "MetaQuotes", "Terminal", "Common", "Files");

        public const string RegChave = @"Software\SPCentral";

        private static readonly object lockLog = new object();

        public static string Hmac(string texto)
        {
            byte[] chave = Encoding.UTF8.GetBytes("SPCentral-v1|" + Environment.MachineName + "|" + Environment.UserName);
            using (HMACSHA256 h = new HMACSHA256(chave))
                return Convert.ToBase64String(h.ComputeHash(Encoding.UTF8.GetBytes(texto)));
        }

        public static string HashSenha(string senha, string saltB64)
        {
            byte[] salt = Convert.FromBase64String(saltB64);
            using (Rfc2898DeriveBytes k = new Rfc2898DeriveBytes(senha, salt, 100000))
                return Convert.ToBase64String(k.GetBytes(32));
        }

        public static string NovoSalt()
        {
            byte[] b = new byte[16];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(b);
            return Convert.ToBase64String(b);
        }

        public static bool ParseHora(string s, out TimeSpan t)
        {
            t = TimeSpan.Zero;
            if (string.IsNullOrWhiteSpace(s)) return false;
            return TimeSpan.TryParseExact(s.Trim(), new[] { @"hh\:mm", @"h\:mm" }, CultureInfo.InvariantCulture, out t)
                   && t >= TimeSpan.Zero && t < TimeSpan.FromDays(1);
        }

        public static string LerTexto(string caminho)
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

        public static void GravarTexto(string caminho, string texto)
        {
            using (FileStream fs = new FileStream(caminho, FileMode.Create, FileAccess.Write, FileShare.ReadWrite | FileShare.Delete))
            {
                byte[] b = Encoding.ASCII.GetBytes(texto);
                fs.Write(b, 0, b.Length);
            }
        }

        public static string SemAcento(string s)
        {
            string n = (s ?? "").Normalize(NormalizationForm.FormD);
            StringBuilder sb = new StringBuilder();
            foreach (char c in n)
                if (CharUnicodeInfo.GetUnicodeCategory(c) != UnicodeCategory.NonSpacingMark && c != '|' && c < 128)
                    sb.Append(c);
            return sb.ToString();
        }

        public static void Log(string msg)
        {
            try
            {
                lock (lockLog)
                {
                    Directory.CreateDirectory(PastaApp);
                    File.AppendAllText(Path.Combine(PastaApp, "log_" + DateTime.Now.ToString("yyyyMMdd") + ".txt"),
                        DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss") + "  " + msg + "\r\n");
                }
            }
            catch (Exception) { }
        }

        public static double ParseD(string s)
        {
            double v;
            return double.TryParse(s.Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out v) ? v : 0;
        }

        public static long ParseL(string s)
        {
            long v;
            return long.TryParse(s.Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out v) ? v : 0;
        }
    }

    // ------------------------------------------------------------------------
    //  Arquivo assinado (chave=valor + SIG), usado pela configuracao e pelo estado
    // ------------------------------------------------------------------------
    internal class ArquivoAssinado
    {
        public readonly Dictionary<string, string> V = new Dictionary<string, string>();

        public string Get(string k, string padrao)
        {
            string v;
            return V.TryGetValue(k, out v) ? v : padrao;
        }

        public void Set(string k, string v) { V[k] = (v ?? "").Replace("\r", " ").Replace("\n", " "); }

        private string Corpo()
        {
            List<string> chaves = new List<string>(V.Keys);
            chaves.Sort(StringComparer.Ordinal);
            StringBuilder sb = new StringBuilder();
            foreach (string k in chaves) sb.Append(k).Append('=').Append(V[k]).Append("\r\n");
            return sb.ToString();
        }

        public void Salvar(string caminho)
        {
            Directory.CreateDirectory(Path.GetDirectoryName(caminho));
            string corpo = Corpo();
            File.WriteAllText(caminho, corpo + "SIG=" + Util.Hmac(corpo) + "\r\n", Encoding.UTF8);
        }

        // 0 = ok, 1 = ausente, 2 = assinatura invalida (editado a mao)
        public int Carregar(string caminho)
        {
            V.Clear();
            if (!File.Exists(caminho)) return 1;
            string sig = "";
            foreach (string linha in File.ReadAllLines(caminho, Encoding.UTF8))
            {
                int p = linha.IndexOf('=');
                if (p <= 0) continue;
                string k = linha.Substring(0, p), v = linha.Substring(p + 1);
                if (k == "SIG") sig = v; else V[k] = v;
            }
            return Util.Hmac(Corpo()) == sig ? 0 : 2;
        }
    }

    // ------------------------------------------------------------------------
    //  Configuracao
    // ------------------------------------------------------------------------
    internal class Config
    {
        public string ContaMae = "";
        public string ContasFilhas = "";
        public int    MaxOperacoes = 3;
        public double MetaPontos = 1200;
        public double LimitePerda = 1500;
        public string HoraInicio = "";
        public string HoraFim = "10:30";
        public bool   ZerarNoHorarioFim = false;
        public string HoraReset = "06:00";
        public string EdicaoBloqueiaAs = "09:00";
        public string EdicaoLiberaAs = "22:00";
        public int    DivergenciaSeg = 20;
        public int    MaxPerdasSeguidas = 0;     // 0 = desligado
        public int    PausaAposPerdaMin = 0;     // 0 = desligado
        public double ProtecaoDevolverPts = 0;   // 0 = desligado
        public double ProtecaoAtivaPts = 300;    // protecao do lucro vale depois de fechar este resultado
        public bool   FecharPlataformas = true;
        public string Processos = "terminal64,terminal,NinjaTrader,TradingView";
        public string TitulosJanelas = "TradingView";

        public static string Caminho { get { return Path.Combine(Util.PastaApp, "config.txt"); } }

        public void Salvar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            a.Set("ContaMae", ContaMae);
            a.Set("ContasFilhas", ContasFilhas);
            a.Set("MaxOperacoes", MaxOperacoes.ToString(CultureInfo.InvariantCulture));
            a.Set("MetaPontos", MetaPontos.ToString(CultureInfo.InvariantCulture));
            a.Set("LimitePerda", LimitePerda.ToString(CultureInfo.InvariantCulture));
            a.Set("HoraInicio", HoraInicio);
            a.Set("HoraFim", HoraFim);
            a.Set("ZerarNoHorarioFim", ZerarNoHorarioFim ? "1" : "0");
            a.Set("HoraReset", HoraReset);
            a.Set("EdicaoBloqueiaAs", EdicaoBloqueiaAs);
            a.Set("EdicaoLiberaAs", EdicaoLiberaAs);
            a.Set("DivergenciaSeg", DivergenciaSeg.ToString(CultureInfo.InvariantCulture));
            a.Set("MaxPerdasSeguidas", MaxPerdasSeguidas.ToString(CultureInfo.InvariantCulture));
            a.Set("PausaAposPerdaMin", PausaAposPerdaMin.ToString(CultureInfo.InvariantCulture));
            a.Set("ProtecaoDevolverPts", ProtecaoDevolverPts.ToString(CultureInfo.InvariantCulture));
            a.Set("ProtecaoAtivaPts", ProtecaoAtivaPts.ToString(CultureInfo.InvariantCulture));
            a.Set("FecharPlataformas", FecharPlataformas ? "1" : "0");
            a.Set("Processos", Processos);
            a.Set("TitulosJanelas", TitulosJanelas);
            a.Salvar(Caminho);
        }

        public int Carregar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            int r = a.Carregar(Caminho);
            if (r == 1) return r;
            ContaMae          = a.Get("ContaMae", ContaMae);
            ContasFilhas      = a.Get("ContasFilhas", ContasFilhas);
            MaxOperacoes      = (int)Util.ParseL(a.Get("MaxOperacoes", MaxOperacoes.ToString(CultureInfo.InvariantCulture)));
            MetaPontos        = Util.ParseD(a.Get("MetaPontos", MetaPontos.ToString(CultureInfo.InvariantCulture)));
            LimitePerda       = Util.ParseD(a.Get("LimitePerda", LimitePerda.ToString(CultureInfo.InvariantCulture)));
            HoraInicio        = a.Get("HoraInicio", HoraInicio);
            HoraFim           = a.Get("HoraFim", HoraFim);
            ZerarNoHorarioFim = a.Get("ZerarNoHorarioFim", "0") == "1";
            HoraReset         = a.Get("HoraReset", HoraReset);
            EdicaoBloqueiaAs  = a.Get("EdicaoBloqueiaAs", EdicaoBloqueiaAs);
            EdicaoLiberaAs    = a.Get("EdicaoLiberaAs", EdicaoLiberaAs);
            DivergenciaSeg    = (int)Util.ParseL(a.Get("DivergenciaSeg", DivergenciaSeg.ToString(CultureInfo.InvariantCulture)));
            MaxPerdasSeguidas = (int)Util.ParseL(a.Get("MaxPerdasSeguidas", "0"));
            PausaAposPerdaMin = (int)Util.ParseL(a.Get("PausaAposPerdaMin", "0"));
            ProtecaoDevolverPts = Util.ParseD(a.Get("ProtecaoDevolverPts", "0"));
            ProtecaoAtivaPts  = Util.ParseD(a.Get("ProtecaoAtivaPts", ProtecaoAtivaPts.ToString(CultureInfo.InvariantCulture)));
            FecharPlataformas = a.Get("FecharPlataformas", "1") == "1";
            Processos         = a.Get("Processos", Processos);
            TitulosJanelas    = a.Get("TitulosJanelas", TitulosJanelas);
            return r;
        }

        public List<string> Filhas()
        {
            List<string> l = new List<string>();
            foreach (string s in ContasFilhas.Split(new[] { ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries))
                l.Add(s.Trim());
            return l;
        }

        // Fora da janela de edicao as alteracoes exigem a senha mestra.
        public bool EdicaoLivreAgora(DateTime agora, out string texto)
        {
            TimeSpan bloq, lib;
            if (!Util.ParseHora(EdicaoBloqueiaAs, out bloq) || !Util.ParseHora(EdicaoLiberaAs, out lib))
            {
                texto = "Edicao livre (janela de edicao nao configurada)";
                return true;
            }
            TimeSpan t = agora.TimeOfDay;
            bool livre = bloq < lib ? (t < bloq || t >= lib) : (t >= lib && t < bloq);
            texto = livre
                ? string.Format("Edicao LIVRE ate {0} (sem senha)", EdicaoBloqueiaAs)
                : string.Format("Edicao BLOQUEADA ate {0} - so com a senha mestra", EdicaoLiberaAs);
            return livre;
        }
    }

    // ------------------------------------------------------------------------
    //  Estado persistido (sobrevive a reinicio do PC e da central)
    // ------------------------------------------------------------------------
    internal class Estado
    {
        public bool     Travado;
        public string   Motivo = "";
        public string   Modo = "";            // ZERAR ou AGUARDAR
        public DateTime TravadoEm;
        public DateTime TravadoAte;
        public DateTime Base;                 // contagem do dia a partir daqui
        public DateTime HorarioIgnoradoAte;   // destravado com senha apos o horario limite

        public static string Caminho { get { return Path.Combine(Util.PastaApp, "estado.txt"); } }

        public void Salvar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            a.Set("Travado", Travado ? "1" : "0");
            a.Set("Motivo", Motivo);
            a.Set("Modo", Modo);
            a.Set("TravadoEm", TravadoEm.Ticks.ToString(CultureInfo.InvariantCulture));
            a.Set("TravadoAte", TravadoAte.Ticks.ToString(CultureInfo.InvariantCulture));
            a.Set("Base", Base.Ticks.ToString(CultureInfo.InvariantCulture));
            a.Set("HorarioIgnoradoAte", HorarioIgnoradoAte.Ticks.ToString(CultureInfo.InvariantCulture));
            a.Salvar(Caminho);
        }

        public int Carregar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            int r = a.Carregar(Caminho);
            if (r != 0) return r;
            Travado            = a.Get("Travado", "0") == "1";
            Motivo             = a.Get("Motivo", "");
            Modo               = a.Get("Modo", "");
            TravadoEm          = new DateTime(Util.ParseL(a.Get("TravadoEm", "0")));
            TravadoAte         = new DateTime(Util.ParseL(a.Get("TravadoAte", "0")));
            Base               = new DateTime(Util.ParseL(a.Get("Base", "0")));
            HorarioIgnoradoAte = new DateTime(Util.ParseL(a.Get("HorarioIgnoradoAte", "0")));
            return 0;
        }
    }

    internal class StatusConta
    {
        public string Id = "";
        public string Simbolo = "";
        public string Modo = "";
        public int    Posicoes;
        public double Flutuante;
        public ulong  TickMs;
        public bool   Online;
    }

    // ------------------------------------------------------------------------
    //  Janela principal
    // ------------------------------------------------------------------------
    internal class FormCentral : Form
    {
        [DllImport("user32.dll")] private static extern bool EnumWindows(EnumWindowsProc cb, IntPtr lParam);
        [DllImport("user32.dll")] private static extern bool IsWindowVisible(IntPtr hWnd);
        [DllImport("user32.dll", CharSet = CharSet.Unicode)] private static extern int GetWindowText(IntPtr hWnd, StringBuilder s, int max);
        [DllImport("user32.dll")] private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint pid);
        [DllImport("user32.dll")] private static extern bool PostMessage(IntPtr hWnd, uint msg, IntPtr w, IntPtr l);
        private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
        private const uint WM_CLOSE = 0x0010;

        private const int STATUS_ONLINE_MS = 5000;
        private const int ESPERA_ZERAR_S   = 30;

        private readonly Config cfg = new Config();
        private readonly Estado est = new Estado();
        private string senhaHash = "", senhaSalt = "";
        private bool   adulterado;            // config/estado alterado fora da central
        private bool   sairAutorizado;
        private readonly Dictionary<string, DateTime> divergenteDesde = new Dictionary<string, DateTime>();
        private readonly List<string> zerarContas = new List<string>();
        private DateTime ultimoFechamento = DateTime.MinValue;

        // indicadores do ciclo
        private int    opsDia;
        private double ptsReal, ptsFlut;
        private int    perdasSeguidas;                 // perdas seguidas no fim da lista de operacoes do dia
        private double picoFechado;                    // melhor resultado fechado do dia (soma acumulada)
        private DateTime ultimaPerdaEm = DateTime.MinValue;
        private bool   emPausa;
        private string estadoCmd = "LIVRE", motivoCmd = "";
        private readonly List<StatusConta> contas = new List<StatusConta>();

        // UI
        private readonly NotifyIcon tray = new NotifyIcon();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();
        private Label lblEstado, lblMotivo, lblOps, lblPts, lblHorario, lblEdicao;
        private ListView lvContas;
        private ListBox lbEventos;
        private TextBox txContaMae, txFilhas, txProc, txTitulos;
        private DateTimePicker dtInicio, dtFim, dtReset, dtEdBloq, dtEdLib;
        private NumericUpDown nuOps, nuMeta, nuPerda, nuDiv, nuPerdasSeg, nuPausa, nuDevolver, nuProtAtiva;
        private CheckBox ckZerarFim, ckFechar;
        private Label lblResumo;

        public FormCentral()
        {
            Text = "Central de Controle - Scalper Pro";
            Width = 820;
            Height = 720;
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 9f);
            Icon = SystemIcons.Shield;

            MontarUI();
            Inicializar();

            tray.Icon = SystemIcons.Shield;
            tray.Text = "Central de Controle";
            tray.Visible = true;
            tray.DoubleClick += delegate { MostrarJanela(); };
            ContextMenuStrip menu = new ContextMenuStrip();
            menu.Items.Add("Abrir", null, delegate { MostrarJanela(); });
            menu.Items.Add("Sair (senha mestra)", null, delegate { SairComSenha(); });
            tray.ContextMenuStrip = menu;

            timer.Interval = 500;
            timer.Tick += delegate { Ciclo(); };
            timer.Start();
            Ciclo();
        }

        // --------------------------------------------------------------------
        //  Inicializacao / senha
        // --------------------------------------------------------------------
        private void Inicializar()
        {
            Directory.CreateDirectory(Util.PastaApp);
            try { Directory.CreateDirectory(Util.PastaCommon); } catch (Exception) { }

            using (RegistryKey rk = Registry.CurrentUser.CreateSubKey(Util.RegChave))
            {
                senhaHash = (rk.GetValue("SenhaHash") as string) ?? "";
                senhaSalt = (rk.GetValue("SenhaSalt") as string) ?? "";
            }

            if (senhaHash == "")
            {
                if (!PrimeiraConfiguracao())
                {
                    sairAutorizado = true;
                    Load += delegate { Close(); };
                    return;
                }
            }

            int rc = cfg.Carregar();
            if (rc != 0)
            {
                adulterado = true;
                Evento(rc == 1 ? "Configuracao ausente: a central fica bloqueada ate a senha mestra."
                               : "Configuracao alterada fora da central: bloqueada ate a senha mestra.");
            }

            int re = est.Carregar();
            if (re != 0)
            {
                DateTime agora = DateTime.Now;
                est.Base = InicioDia(agora);
                Travar(re == 1 ? "estado da central apagado" : "estado da central alterado", "AGUARDAR", agora);
            }

            // inicia com o Windows
            try
            {
                using (RegistryKey run = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
                    run.SetValue("SPCentral", "\"" + Application.ExecutablePath + "\"");
            }
            catch (Exception) { }

            CarregarCamposConfig();
            Evento("Central iniciada.");
        }

        private bool PrimeiraConfiguracao()
        {
            MessageBox.Show(
                "Primeira configuracao da Central de Controle.\r\n\r\n" +
                "Agora sera definida a SENHA MESTRA. Ela destrava a central e libera alteracoes fora do horario.\r\n\r\n" +
                "Para a central proteger voce de voce mesmo, PECA PARA OUTRA PESSOA digitar a senha e guarda-la.",
                "Central de Controle", MessageBoxButtons.OK, MessageBoxIcon.Information);

            string s1 = PedirSenha("Nova senha mestra (minimo 6 caracteres)");
            if (s1 == null) return false;
            string s2 = PedirSenha("Confirme a senha mestra");
            if (s2 == null) return false;
            if (s1 != s2 || s1.Length < 6)
            {
                MessageBox.Show("As senhas nao conferem ou tem menos de 6 caracteres.", "Central de Controle");
                return false;
            }
            GravarSenha(s1);
            cfg.Salvar();
            est.Base = InicioDia(DateTime.Now);
            est.Salvar();
            return true;
        }

        private void GravarSenha(string senha)
        {
            senhaSalt = Util.NovoSalt();
            senhaHash = Util.HashSenha(senha, senhaSalt);
            using (RegistryKey rk = Registry.CurrentUser.CreateSubKey(Util.RegChave))
            {
                rk.SetValue("SenhaHash", senhaHash);
                rk.SetValue("SenhaSalt", senhaSalt);
            }
        }

        private bool ConferirSenha(string titulo)
        {
            string s = PedirSenha(titulo);
            if (s == null) return false;
            bool ok = senhaHash != "" && Util.HashSenha(s, senhaSalt) == senhaHash;
            if (!ok)
            {
                Evento("Senha mestra incorreta.");
                MessageBox.Show("Senha mestra incorreta.", "Central de Controle", MessageBoxButtons.OK, MessageBoxIcon.Warning);
                Thread.Sleep(1500);
            }
            return ok;
        }

        private static string PedirSenha(string titulo)
        {
            using (Form f = new Form())
            {
                f.Text = "Central de Controle";
                f.Width = 380;
                f.Height = 160;
                f.FormBorderStyle = FormBorderStyle.FixedDialog;
                f.StartPosition = FormStartPosition.CenterScreen;
                f.MinimizeBox = false;
                f.MaximizeBox = false;
                f.TopMost = true;
                Label l = new Label { Text = titulo, Left = 12, Top = 12, Width = 340 };
                TextBox t = new TextBox { Left = 12, Top = 36, Width = 340, UseSystemPasswordChar = true };
                Button ok = new Button { Text = "OK", Left = 196, Top = 72, Width = 75, DialogResult = DialogResult.OK };
                Button ca = new Button { Text = "Cancelar", Left = 277, Top = 72, Width = 75, DialogResult = DialogResult.Cancel };
                f.Controls.AddRange(new Control[] { l, t, ok, ca });
                f.AcceptButton = ok;
                f.CancelButton = ca;
                return f.ShowDialog() == DialogResult.OK ? t.Text : null;
            }
        }

        // --------------------------------------------------------------------
        //  Ciclo (500 ms)
        // --------------------------------------------------------------------
        private static DateTime InicioDiaCom(DateTime agora, string horaReset)
        {
            TimeSpan r;
            if (!Util.ParseHora(horaReset, out r)) r = TimeSpan.FromHours(6);
            DateTime ini = agora.Date + r;
            return agora >= ini ? ini : ini.AddDays(-1);
        }

        private DateTime InicioDia(DateTime agora) { return InicioDiaCom(agora, cfg.HoraReset); }

        // Momento de um horario HH:mm dentro do "dia" que comeca no reset.
        private static DateTime MomentoNoDia(DateTime iniDia, TimeSpan hora)
        {
            DateTime m = iniDia.Date + hora;
            return m < iniDia ? m.AddDays(1) : m;
        }

        private void Ciclo()
        {
            if (sairAutorizado) return;
            DateTime agora = DateTime.Now;
            DateTime iniDia = InicioDia(agora);
            DateTime fimDia = iniDia.AddDays(1);

            // reset diario
            if (est.Travado && agora >= est.TravadoAte)
                Destravar("reset diario", agora, false);

            DateTime baseCont = est.Base > iniDia ? est.Base : iniDia;
            LerStatus();
            LerOperacoes(baseCont);

            StatusConta mae = StatusMae();
            ptsFlut = (mae != null && mae.Online) ? mae.Flutuante : 0;
            double total = ptsReal + ptsFlut;

            // limites
            if (!est.Travado && !adulterado)
            {
                TimeSpan hf;
                if (cfg.LimitePerda > 0 && total <= -cfg.LimitePerda)
                    Travar(string.Format(CultureInfo.InvariantCulture, "limite de perda atingido ({0:0} pts)", total), "ZERAR", agora);
                else if (ProtecaoLucroAtingida(total))
                    Travar(string.Format(CultureInfo.InvariantCulture, "protecao do lucro: devolveu {0:0} pts do melhor resultado ({1:0} pts)",
                        picoFechado - total, picoFechado), "ZERAR", agora);
                else if (cfg.MetaPontos > 0 && total >= cfg.MetaPontos)
                    Travar(string.Format(CultureInfo.InvariantCulture, "meta de pontos atingida ({0:0} pts)", total), "AGUARDAR", agora);
                else if (cfg.MaxOperacoes > 0 && opsDia >= cfg.MaxOperacoes)
                    Travar(string.Format("maximo de operacoes atingido ({0})", opsDia), "AGUARDAR", agora);
                else if (cfg.MaxPerdasSeguidas > 0 && perdasSeguidas >= cfg.MaxPerdasSeguidas)
                    Travar(string.Format("{0} perdas seguidas", perdasSeguidas), "AGUARDAR", agora);
                else if (Util.ParseHora(cfg.HoraFim, out hf) && agora >= MomentoNoDia(iniDia, hf) && agora >= est.HorarioIgnoradoAte)
                    Travar("horario limite de operacao (" + cfg.HoraFim + ")", cfg.ZerarNoHorarioFim ? "ZERAR" : "AGUARDAR", agora);
            }

            // comando para os EAs
            TimeSpan hi;
            DateTime pausaAte = PausaAte();
            emPausa = false;
            if (adulterado)                  { estadoCmd = "BLOQ"; motivoCmd = "central alterada - use a senha mestra"; }
            else if (est.Travado)            { estadoCmd = est.Modo == "ZERAR" ? "ZERAR" : "BLOQ"; motivoCmd = est.Motivo; }
            else if (Util.ParseHora(cfg.HoraInicio, out hi) && agora < MomentoNoDia(iniDia, hi) && agora < fimDia)
                                             { estadoCmd = "BLOQ"; motivoCmd = "antes do horario de inicio (" + cfg.HoraInicio + ")"; }
            else if (agora < pausaAte)
            {
                // pausa apos perda: so bloqueia novas entradas; nao trava e nao fecha as plataformas
                estadoCmd = "BLOQ";
                motivoCmd = string.Format("pausa apos perda ate {0:HH:mm:ss}", pausaAte);
                emPausa = true;
            }
            else                             { estadoCmd = "LIVRE"; motivoCmd = ""; }

            VerificarDivergencia(agora, mae);
            GravarComando();

            // fecha as plataformas depois que as posicoes terminaram
            if (est.Travado && cfg.FecharPlataformas)
            {
                bool zerado = TudoZerado();
                bool esgotou = est.Modo == "ZERAR" && (agora - est.TravadoEm).TotalSeconds > ESPERA_ZERAR_S;
                if (zerado || esgotou)
                {
                    if ((agora - ultimoFechamento).TotalSeconds >= 2)
                    {
                        ultimoFechamento = agora;
                        FecharPlataformas();
                    }
                }
            }

            AtualizarPainel(agora, iniDia, total);
        }

        // Protecao do lucro: depois de o resultado FECHADO do dia chegar a ProtecaoAtivaPts, o total
        // (fechado + flutuante) nao pode cair mais que ProtecaoDevolverPts abaixo do melhor fechado.
        private bool ProtecaoLucroAtingida(double total)
        {
            if (cfg.ProtecaoDevolverPts <= 0) return false;
            double ativa = Math.Max(1, cfg.ProtecaoAtivaPts);
            if (picoFechado < ativa) return false;
            return total <= picoFechado - cfg.ProtecaoDevolverPts;
        }

        // Fim da pausa depois da ultima perda (MinValue = sem pausa)
        private DateTime PausaAte()
        {
            if (cfg.PausaAposPerdaMin <= 0 || ultimaPerdaEm == DateTime.MinValue) return DateTime.MinValue;
            return ultimaPerdaEm.AddMinutes(cfg.PausaAposPerdaMin);
        }

        private void Travar(string motivo, string modo, DateTime agora)
        {
            est.Travado = true;
            est.Motivo = Util.SemAcento(motivo);
            est.Modo = modo;
            est.TravadoEm = agora;
            est.TravadoAte = InicioDia(agora).AddDays(1);
            est.Salvar();
            string msg = string.Format("TRAVADA: {0}. {1} Travada ate {2:dd/MM HH:mm}.", est.Motivo,
                modo == "ZERAR" ? "Zerando posicoes e fechando as plataformas." : "Sem novas entradas; a operacao em andamento termina e as plataformas fecham.",
                est.TravadoAte);
            Evento(msg);
            try { tray.ShowBalloonTip(8000, "Central de Controle TRAVADA", msg, ToolTipIcon.Warning); } catch (Exception) { }
        }

        private void Destravar(string motivo, DateTime agora, bool comSenha)
        {
            est.Travado = false;
            est.Motivo = "";
            est.Modo = "";
            est.Base = agora;   // contagem recomeca
            if (comSenha) est.HorarioIgnoradoAte = InicioDia(agora).AddDays(1);
            est.Salvar();
            Evento("Central destravada (" + motivo + "). A contagem de operacoes e pontos recomeca agora.");
        }

        // --------------------------------------------------------------------
        //  Arquivos dos EAs
        // --------------------------------------------------------------------
        private void LerStatus()
        {
            contas.Clear();
            ulong agoraTk = Util.GetTickCount64();
            string[] arqs;
            try { arqs = Directory.GetFiles(Util.PastaCommon, "SP_Central_St_*.txt"); }
            catch (Exception) { return; }
            foreach (string a in arqs)
            {
                try
                {
                    string[] c = Util.LerTexto(a).Trim().Split('|');
                    if (c.Length < 8 || c[0] != "ST") continue;
                    StatusConta s = new StatusConta();
                    s.TickMs    = (ulong)Util.ParseL(c[2]);
                    s.Id        = c[3];
                    s.Simbolo   = c[4];
                    s.Modo      = c[5];
                    s.Posicoes  = (int)Util.ParseL(c[6]);
                    s.Flutuante = Util.ParseD(c[7]);
                    s.Online    = s.TickMs > 0 && (agoraTk <= s.TickMs || agoraTk - s.TickMs < STATUS_ONLINE_MS);
                    contas.Add(s);
                }
                catch (Exception) { }
            }
        }

        private string IdMae()
        {
            if (!string.IsNullOrWhiteSpace(cfg.ContaMae)) return cfg.ContaMae.Trim();
            foreach (StatusConta s in contas)
                if (s.Online && s.Modo == "MAE") return s.Id;
            return "";
        }

        // Soma das contas/simbolos da mae (normalmente um grafico).
        private StatusConta StatusMae()
        {
            string id = IdMae();
            if (id == "") return null;
            StatusConta r = null;
            foreach (StatusConta s in contas)
            {
                if (s.Id != id || !s.Online) continue;
                if (r == null) r = new StatusConta { Id = id, Online = true, Simbolo = s.Simbolo, Modo = s.Modo };
                else r.Simbolo += "," + s.Simbolo;
                r.Posicoes += s.Posicoes;
                r.Flutuante += s.Flutuante;
            }
            return r;
        }

        private void LerOperacoes(DateTime desde)
        {
            opsDia = 0;
            ptsReal = 0;
            perdasSeguidas = 0;
            picoFechado = 0;
            ultimaPerdaEm = DateTime.MinValue;
            string id = IdMae();
            if (id == "") return;
            string arq = Path.Combine(Util.PastaCommon, "SP_Central_Tr_" + id + ".txt");
            if (!File.Exists(arq)) return;
            HashSet<string> vistos = new HashSet<string>();
            try
            {
                foreach (string linha in Util.LerTexto(arq).Split('\n'))
                {
                    string[] c = linha.Trim().Split('|');
                    if (c.Length < 5 || c[0] != "T") continue;
                    DateTime fech = new DateTime(1970, 1, 1).AddSeconds(Util.ParseL(c[2]));
                    if (fech < desde) continue;
                    if (!vistos.Add(c[1] + "|" + c[4])) continue;
                    double pts = Util.ParseD(c[3]);
                    opsDia++;
                    ptsReal += pts;
                    if (ptsReal > picoFechado) picoFechado = ptsReal;
                    // perda soma na sequencia; ganho zera; zero a zero nao muda a sequencia
                    if (pts < 0) { perdasSeguidas++; if (fech > ultimaPerdaEm) ultimaPerdaEm = fech; }
                    else if (pts > 0) perdasSeguidas = 0;
                }
            }
            catch (Exception) { }
        }

        // Filha posicionada com a mae zerada por mais de N s -> zerar so essa filha
        // (perda de sinal do copiador).
        private void VerificarDivergencia(DateTime agora, StatusConta mae)
        {
            zerarContas.Clear();
            if (cfg.DivergenciaSeg <= 0 || mae == null || !mae.Online) { divergenteDesde.Clear(); return; }
            foreach (string f in cfg.Filhas())
            {
                bool filhaPos = false;
                foreach (StatusConta s in contas)
                    if (s.Id == f && s.Online && s.Posicoes > 0) filhaPos = true;

                if (filhaPos && mae.Posicoes == 0)
                {
                    DateTime desde;
                    if (!divergenteDesde.TryGetValue(f, out desde)) { divergenteDesde[f] = agora; continue; }
                    if ((agora - desde).TotalSeconds >= cfg.DivergenciaSeg)
                    {
                        if (!zerarContas.Contains(f)) zerarContas.Add(f);
                        if ((agora - desde).TotalSeconds < cfg.DivergenciaSeg + 1)
                            Evento("Divergencia: conta " + f + " posicionada com a mae zerada ha " + cfg.DivergenciaSeg + " s. Zerando essa conta.");
                    }
                }
                else
                    divergenteDesde.Remove(f);
            }
        }

        private void GravarComando()
        {
            try
            {
                Directory.CreateDirectory(Util.PastaCommon);
                string marca = Path.Combine(Util.PastaCommon, "SP_Central_Ativa.txt");
                if (!File.Exists(marca)) Util.GravarTexto(marca, "SPCentral\r\n");

                StringBuilder sb = new StringBuilder();
                sb.AppendFormat("CMD|1|{0}|{1}|{2}|{3}\r\n", Util.GetTickCount64(), estadoCmd, Util.SemAcento(motivoCmd),
                    est.Travado ? est.TravadoAte.ToString("yyyy-MM-dd HH:mm") : "");
                foreach (string z in zerarContas) sb.Append("Z|").Append(z).Append("\r\n");
                Util.GravarTexto(Path.Combine(Util.PastaCommon, "SP_Central_Cmd.txt"), sb.ToString());
            }
            catch (Exception) { /* proximo ciclo */ }
        }

        private bool TudoZerado()
        {
            foreach (StatusConta s in contas)
                if (s.Online && s.Posicoes > 0) return false;
            return true;
        }

        // --------------------------------------------------------------------
        //  Fechar plataformas
        // --------------------------------------------------------------------
        private void FecharPlataformas()
        {
            int mortos = 0;
            foreach (string nome in cfg.Processos.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string n = nome.Trim();
                if (n.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) n = n.Substring(0, n.Length - 4);
                if (n.Length == 0) continue;
                foreach (Process p in Process.GetProcessesByName(n))
                {
                    try { p.Kill(); mortos++; } catch (Exception) { }
                    finally { p.Dispose(); }
                }
            }

            List<string> titulos = new List<string>();
            foreach (string t in cfg.TitulosJanelas.Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries))
                if (t.Trim().Length > 0) titulos.Add(t.Trim());
            int fechadas = 0;
            if (titulos.Count > 0)
            {
                uint meuPid = (uint)Process.GetCurrentProcess().Id;
                EnumWindows(delegate (IntPtr h, IntPtr l)
                {
                    if (!IsWindowVisible(h)) return true;
                    uint pid;
                    GetWindowThreadProcessId(h, out pid);
                    if (pid == meuPid) return true;
                    StringBuilder sb = new StringBuilder(512);
                    GetWindowText(h, sb, sb.Capacity);
                    string titulo = sb.ToString();
                    foreach (string t in titulos)
                        if (titulo.IndexOf(t, StringComparison.OrdinalIgnoreCase) >= 0)
                        {
                            PostMessage(h, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                            fechadas++;
                            break;
                        }
                    return true;
                }, IntPtr.Zero);
            }
            if (mortos + fechadas > 0)
                Evento(string.Format("Plataformas fechadas: {0} processo(s), {1} janela(s).", mortos, fechadas));
        }

        // --------------------------------------------------------------------
        //  UI
        // --------------------------------------------------------------------
        private void MontarUI()
        {
            TabControl tabs = new TabControl { Dock = DockStyle.Fill };
            Controls.Add(tabs);

            // --- Painel
            TabPage tpPainel = new TabPage("Painel");
            tabs.TabPages.Add(tpPainel);
            lblEstado = new Label { Left = 16, Top = 12, Width = 760, Height = 40, Font = new Font("Segoe UI", 18f, FontStyle.Bold) };
            lblMotivo = new Label { Left = 16, Top = 54, Width = 760, Height = 22, Font = new Font("Segoe UI", 10f) };
            lblOps = new Label { Left = 16, Top = 84, Width = 760, Height = 22, Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
            lblPts = new Label { Left = 16, Top = 108, Width = 760, Height = 22, Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
            lblHorario = new Label { Left = 16, Top = 132, Width = 760, Height = 22, Font = new Font("Segoe UI", 10f) };
            lvContas = new ListView { Left = 16, Top = 162, Width = 770, Height = 180, View = View.Details, FullRowSelect = true, GridLines = true };
            lvContas.Columns.Add("Conta", 190);
            lvContas.Columns.Add("Papel", 90);
            lvContas.Columns.Add("Modo", 70);
            lvContas.Columns.Add("Simbolo", 130);
            lvContas.Columns.Add("Online", 70);
            lvContas.Columns.Add("Posicoes", 70);
            lvContas.Columns.Add("Flutuante (pts)", 110);
            Label lbe = new Label { Text = "Eventos", Left = 16, Top = 350, Width = 200 };
            lbEventos = new ListBox { Left = 16, Top = 370, Width = 770, Height = 200, HorizontalScrollbar = true };
            tpPainel.Controls.AddRange(new Control[] { lblEstado, lblMotivo, lblOps, lblPts, lblHorario, lvContas, lbe, lbEventos });

            // --- Configuracao (em blocos)
            TabPage tpCfg = new TabPage("Configuracao");
            tabs.TabPages.Add(tpCfg);
            tpCfg.AutoScroll = true;
            int y = 10;
            lblEdicao = new Label { Left = 16, Top = y, Width = 760, Height = 22, Font = new Font("Segoe UI", 10f, FontStyle.Bold) };
            tpCfg.Controls.Add(lblEdicao);
            y += 26;
            lblResumo = new Label { Left = 16, Top = y, Width = 760, Height = 38, ForeColor = Color.DimGray };
            tpCfg.Controls.Add(lblResumo);
            y += 44;

            int gy;
            GroupBox gLim = Bloco(tpCfg, "Limites do dia (0 = sem limite)", y, out gy);
            nuOps   = CampoNumero(gLim, "Maximo de operacoes", ref gy, 0, 1000, "A operacao conta quando fecha. Parciais da mesma posicao = 1 operacao.");
            nuMeta  = CampoNumero(gLim, "Meta de pontos", ref gy, 0, 10000000, "Fechado + flutuante. Sem novas entradas; a operacao aberta termina.");
            nuPerda = CampoNumero(gLim, "Limite de perda (pts)", ref gy, 0, 10000000, "Ex.: 1500 = -1500. Fechado + flutuante. ZERA tudo.");
            y = FecharBloco(gLim, gy);

            GroupBox gProt = Bloco(tpCfg, "Protecao extra (0 = desligado)", y, out gy);
            nuPerdasSeg = CampoNumero(gProt, "Parar apos perdas seguidas", ref gy, 0, 100,
                "Ex.: 2 = trava depois de 2 operacoes perdedoras em sequencia. Um ganho zera a sequencia; zero a zero nao muda.");
            nuPausa     = CampoNumero(gProt, "Pausa apos cada perda (minutos)", ref gy, 0, 600,
                "Depois de uma operacao perdedora, sem novas entradas por esse tempo. Nao trava e nao fecha as plataformas.");
            nuDevolver  = CampoNumero(gProt, "Proteger lucro: devolver no maximo (pts)", ref gy, 0, 10000000,
                "Trava e ZERA se o total (fechado + flutuante) cair essa quantidade abaixo do melhor resultado FECHADO do dia.");
            nuProtAtiva = CampoNumero(gProt, "   ...ativa quando o resultado fechado chegar a (pts)", ref gy, 0, 10000000,
                "Abaixo desse resultado a protecao do lucro nao age (o limite de perda continua valendo).");
            y = FecharBloco(gProt, gy);

            GroupBox gHor = Bloco(tpCfg, "Horarios", y, out gy);
            dtInicio  = CampoHora(gHor, "Horario de inicio (marque para usar)", ref gy, true, "Antes desse horario nenhuma entrada e permitida.");
            dtFim     = CampoHora(gHor, "Horario limite de operacao (marque para usar)", ref gy, true, "A partir desse horario a central trava ate o reset.");
            ckZerarFim = CampoCheck(gHor, "Zerar a posicao aberta no horario limite (desmarcado = deixa a operacao terminar)", ref gy);
            dtReset   = CampoHora(gHor, "Reset diario da trava e da contagem", ref gy, false, "Ex.: 06:00. A trava dura ate o proximo reset.");
            y = FecharBloco(gHor, gy);

            GroupBox gEd = Bloco(tpCfg, "Janela de edicao (fora dela, alterar exige a senha mestra)", y, out gy);
            dtEdBloq = CampoHora(gEd, "Edicao bloqueada a partir de", ref gy, false, "Ex.: 09:00");
            dtEdLib  = CampoHora(gEd, "Edicao liberada novamente a partir de", ref gy, false, "Ex.: 22:00");
            y = FecharBloco(gEd, gy);

            GroupBox gCont = Bloco(tpCfg, "Contas", y, out gy);
            txContaMae = CampoTexto(gCont, "Conta mae (referencia da contagem)", ref gy, "Login MT5 da conta mae. Vazio = detecta o Scalper em modo Mae.");
            txFilhas   = CampoTexto(gCont, "Contas filhas (separadas por virgula)", ref gy, "Ex.: 1514567645, NT-APEX2209540000056. Usadas na verificacao de divergencia.");
            nuDiv      = CampoNumero(gCont, "Zerar filha divergente apos (s)", ref gy, 0, 3600, "Filha posicionada com a mae zerada por mais desse tempo: zera so essa filha.");
            y = FecharBloco(gCont, gy);

            GroupBox gPlat = Bloco(tpCfg, "Ao travar", y, out gy);
            ckFechar  = CampoCheck(gPlat, "Fechar MT5 / NinjaTrader / TradingView quando travar", ref gy);
            txProc    = CampoTexto(gPlat, "Processos a fechar (separados por virgula)", ref gy, "terminal64 = MT5; NinjaTrader; TradingView = app desktop");
            txTitulos = CampoTexto(gPlat, "Janelas a fechar pelo titulo", ref gy, "Ex.: TradingView (fecha abas/janelas do navegador com esse titulo)");
            y = FecharBloco(gPlat, gy);

            Button btSalvar = new Button { Text = "Salvar configuracao", Left = 300, Top = y + 4, Width = 180, Height = 30 };
            btSalvar.Click += delegate { SalvarConfiguracao(); };
            tpCfg.Controls.Add(btSalvar);
            tpCfg.Controls.Add(new Label { Left = 16, Top = y + 40, Width = 10, Height = 10 });   // margem no fim da rolagem

            // --- Senha mestra
            TabPage tpSenha = new TabPage("Senha mestra");
            tabs.TabPages.Add(tpSenha);
            Label exp = new Label
            {
                Left = 16, Top = 16, Width = 760, Height = 90,
                Text = "A senha mestra deve ficar com outra pessoa.\r\n" +
                       "Ela destrava a central antes do reset, libera alteracoes fora da janela de edicao e permite fechar a central.\r\n" +
                       "Ao destravar, a contagem de operacoes e pontos recomeca do zero."
            };
            Button btDestravar = new Button { Text = "Destravar agora", Left = 16, Top = 112, Width = 200, Height = 32 };
            btDestravar.Click += delegate
            {
                if (!est.Travado && !adulterado) { MessageBox.Show("A central nao esta travada."); return; }
                if (!ConferirSenha("Senha mestra para destravar")) return;
                if (adulterado) { adulterado = false; cfg.Salvar(); }
                Destravar("senha mestra", DateTime.Now, true);
            };
            Button btTrocar = new Button { Text = "Trocar senha mestra", Left = 230, Top = 112, Width = 200, Height = 32 };
            btTrocar.Click += delegate
            {
                if (!ConferirSenha("Senha mestra ATUAL")) return;
                string s1 = PedirSenha("Nova senha mestra (minimo 6 caracteres)");
                if (s1 == null) return;
                string s2 = PedirSenha("Confirme a nova senha mestra");
                if (s2 == null || s1 != s2 || s1.Length < 6) { MessageBox.Show("Senhas nao conferem ou muito curtas."); return; }
                GravarSenha(s1);
                Evento("Senha mestra alterada.");
            };
            Button btSair = new Button { Text = "Fechar a central", Left = 444, Top = 112, Width = 200, Height = 32 };
            btSair.Click += delegate { SairComSenha(); };
            tpSenha.Controls.AddRange(new Control[] { exp, btDestravar, btTrocar, btSair });
        }

        // Bloco com titulo; os campos entram a partir de gy (coordenadas dentro do bloco).
        private static GroupBox Bloco(Control pai, string titulo, int y, out int gy)
        {
            GroupBox g = new GroupBox { Text = titulo, Left = 12, Top = y, Width = 765, Font = new Font("Segoe UI", 9f, FontStyle.Bold) };
            pai.Controls.Add(g);
            gy = 22;
            return g;
        }

        private static int FecharBloco(GroupBox g, int gy)
        {
            g.Height = gy + 6;
            return g.Top + g.Height + 8;
        }

        private static Label Rotulo(Control pai, string texto, int y)
        {
            Label l = new Label { Text = texto, Left = 12, Top = y + 3, Width = 380, Font = new Font("Segoe UI", 9f) };
            pai.Controls.Add(l);
            return l;
        }

        private static TextBox CampoTexto(Control pai, string rotulo, ref int y, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            TextBox t = new TextBox { Left = 400, Top = y, Width = 350, Font = new Font("Segoe UI", 9f) };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(t, dica);
            tt.SetToolTip(l, dica);
            pai.Controls.Add(t);
            y += 28;
            return t;
        }

        private static NumericUpDown CampoNumero(Control pai, string rotulo, ref int y, decimal min, decimal max, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            NumericUpDown n = new NumericUpDown { Left = 400, Top = y, Width = 120, Minimum = min, Maximum = max, DecimalPlaces = 0,
                                                  ThousandsSeparator = true, Font = new Font("Segoe UI", 9f) };
            Label d = new Label { Text = dica, Left = 530, Top = y + 3, Width = 225, Height = 18, ForeColor = Color.Gray,
                                  Font = new Font("Segoe UI", 8f), AutoEllipsis = true };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(n, dica);
            tt.SetToolTip(l, dica);
            tt.SetToolTip(d, dica);
            pai.Controls.Add(n);
            pai.Controls.Add(d);
            y += 28;
            return n;
        }

        // Seletor de hora HH:mm. opcional = caixa de marcar no proprio seletor (desmarcado = sem horario).
        private static DateTimePicker CampoHora(Control pai, string rotulo, ref int y, bool opcional, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            DateTimePicker d = new DateTimePicker
            {
                Left = 400, Top = y, Width = 90, Format = DateTimePickerFormat.Custom, CustomFormat = "HH:mm",
                ShowUpDown = true, ShowCheckBox = opcional, Font = new Font("Segoe UI", 9f)
            };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(d, dica);
            tt.SetToolTip(l, dica);
            pai.Controls.Add(d);
            y += 28;
            return d;
        }

        private static CheckBox CampoCheck(Control pai, string rotulo, ref int y)
        {
            CheckBox c = new CheckBox { Text = rotulo, Left = 12, Top = y, Width = 740, Font = new Font("Segoe UI", 9f) };
            pai.Controls.Add(c);
            y += 28;
            return c;
        }

        private static void PorHora(DateTimePicker d, string hora)
        {
            TimeSpan t;
            bool ok = Util.ParseHora(hora, out t);
            d.Value = DateTime.Today + (ok ? t : TimeSpan.Zero);
            if (d.ShowCheckBox) d.Checked = ok;
        }

        private static string LerHora(DateTimePicker d)
        {
            if (d.ShowCheckBox && !d.Checked) return "";
            return d.Value.ToString("HH:mm", CultureInfo.InvariantCulture);
        }

        private static decimal Limitar(NumericUpDown n, double v)
        {
            return Math.Max(n.Minimum, Math.Min(n.Maximum, (decimal)v));
        }

        // Resumo do plano salvo, no topo da aba
        private string ResumoPlano()
        {
            List<string> p = new List<string>();
            p.Add(cfg.MaxOperacoes > 0 ? "ate " + cfg.MaxOperacoes + " operacoes" : "operacoes sem limite");
            p.Add(cfg.MetaPontos > 0 ? "meta +" + cfg.MetaPontos.ToString("0", CultureInfo.InvariantCulture) : "sem meta");
            p.Add(cfg.LimitePerda > 0 ? "perda -" + cfg.LimitePerda.ToString("0", CultureInfo.InvariantCulture) : "sem limite de perda");
            if (cfg.MaxPerdasSeguidas > 0) p.Add("para apos " + cfg.MaxPerdasSeguidas + " perda(s) seguida(s)");
            if (cfg.PausaAposPerdaMin > 0) p.Add("pausa de " + cfg.PausaAposPerdaMin + " min apos perda");
            if (cfg.ProtecaoDevolverPts > 0)
                p.Add(string.Format(CultureInfo.InvariantCulture, "devolve no maximo {0:0} pts (a partir de +{1:0})",
                      cfg.ProtecaoDevolverPts, Math.Max(1, cfg.ProtecaoAtivaPts)));
            string hor = (cfg.HoraInicio == "" ? "" : "de " + cfg.HoraInicio + " ") + (cfg.HoraFim == "" ? "sem horario limite" : "ate " + cfg.HoraFim);
            p.Add(hor + (cfg.ZerarNoHorarioFim && cfg.HoraFim != "" ? " (zera)" : ""));
            p.Add("reset " + cfg.HoraReset);
            return "Plano salvo: " + string.Join("  |  ", p.ToArray());
        }

        private void CarregarCamposConfig()
        {
            txContaMae.Text = cfg.ContaMae;
            txFilhas.Text   = cfg.ContasFilhas;
            nuOps.Value     = Limitar(nuOps, cfg.MaxOperacoes);
            nuMeta.Value    = Limitar(nuMeta, cfg.MetaPontos);
            nuPerda.Value   = Limitar(nuPerda, cfg.LimitePerda);
            nuPerdasSeg.Value = Limitar(nuPerdasSeg, cfg.MaxPerdasSeguidas);
            nuPausa.Value     = Limitar(nuPausa, cfg.PausaAposPerdaMin);
            nuDevolver.Value  = Limitar(nuDevolver, cfg.ProtecaoDevolverPts);
            nuProtAtiva.Value = Limitar(nuProtAtiva, cfg.ProtecaoAtivaPts);
            PorHora(dtInicio, cfg.HoraInicio);
            PorHora(dtFim, cfg.HoraFim);
            ckZerarFim.Checked = cfg.ZerarNoHorarioFim;
            PorHora(dtReset, cfg.HoraReset);
            PorHora(dtEdBloq, cfg.EdicaoBloqueiaAs);
            PorHora(dtEdLib, cfg.EdicaoLiberaAs);
            nuDiv.Value     = Limitar(nuDiv, cfg.DivergenciaSeg);
            ckFechar.Checked = cfg.FecharPlataformas;
            txProc.Text     = cfg.Processos;
            txTitulos.Text  = cfg.TitulosJanelas;
            lblResumo.Text  = ResumoPlano();
        }

        private void SalvarConfiguracao()
        {
            string janela;
            bool livre = cfg.EdicaoLivreAgora(DateTime.Now, out janela);
            if (est.Travado || adulterado || !livre)
            {
                string porque = est.Travado ? "A central esta travada." : (adulterado ? "A central foi alterada." : janela + ".");
                if (!ConferirSenha(porque + " Senha mestra para salvar")) { CarregarCamposConfig(); return; }
                adulterado = false;
            }

            cfg.ContaMae          = txContaMae.Text.Trim();
            cfg.ContasFilhas      = txFilhas.Text.Trim();
            cfg.MaxOperacoes      = (int)nuOps.Value;
            cfg.MetaPontos        = (double)nuMeta.Value;
            cfg.LimitePerda       = (double)nuPerda.Value;
            cfg.MaxPerdasSeguidas = (int)nuPerdasSeg.Value;
            cfg.PausaAposPerdaMin = (int)nuPausa.Value;
            cfg.ProtecaoDevolverPts = (double)nuDevolver.Value;
            cfg.ProtecaoAtivaPts  = (double)nuProtAtiva.Value;
            cfg.HoraInicio        = LerHora(dtInicio);
            cfg.HoraFim           = LerHora(dtFim);
            cfg.ZerarNoHorarioFim = ckZerarFim.Checked;
            cfg.HoraReset         = LerHora(dtReset);
            cfg.EdicaoBloqueiaAs  = LerHora(dtEdBloq);
            cfg.EdicaoLiberaAs    = LerHora(dtEdLib);
            cfg.DivergenciaSeg    = (int)nuDiv.Value;
            cfg.FecharPlataformas = ckFechar.Checked;
            cfg.Processos         = txProc.Text.Trim();
            cfg.TitulosJanelas    = txTitulos.Text.Trim();
            cfg.Salvar();
            lblResumo.Text = ResumoPlano();
            Evento(string.Format(CultureInfo.InvariantCulture,
                "Configuracao salva: max ops={0}, meta={1}, perda=-{2}, perdas seguidas={8}, pausa={9} min, devolver={10} (a partir de {11}), inicio={3}, limite={4}, reset={5}, edicao bloqueada {6}-{7}.",
                cfg.MaxOperacoes, cfg.MetaPontos, cfg.LimitePerda, cfg.HoraInicio == "" ? "-" : cfg.HoraInicio,
                cfg.HoraFim == "" ? "-" : cfg.HoraFim, cfg.HoraReset, cfg.EdicaoBloqueiaAs, cfg.EdicaoLiberaAs,
                cfg.MaxPerdasSeguidas, cfg.PausaAposPerdaMin, cfg.ProtecaoDevolverPts, cfg.ProtecaoAtivaPts));
            MessageBox.Show("Configuracao salva.", "Central de Controle");
        }

        private void AtualizarPainel(DateTime agora, DateTime iniDia, double total)
        {
            if (adulterado)
            {
                lblEstado.Text = "BLOQUEADA - central alterada";
                lblEstado.ForeColor = Color.Firebrick;
                lblMotivo.Text = "Configuracao ou estado alterado fora da central. Destrave com a senha mestra.";
            }
            else if (est.Travado)
            {
                bool aguardando = est.Modo != "ZERAR" && !TudoZerado();
                lblEstado.Text = aguardando ? "TRAVADA - aguardando a operacao terminar" : "TRAVADA";
                lblEstado.ForeColor = Color.Firebrick;
                lblMotivo.Text = string.Format("{0} | ate {1:dd/MM HH:mm}", est.Motivo, est.TravadoAte);
            }
            else if (estadoCmd == "BLOQ")
            {
                lblEstado.Text = emPausa ? "PAUSA APOS PERDA" : "AGUARDANDO HORARIO";
                lblEstado.ForeColor = Color.DarkOrange;
                lblMotivo.Text = motivoCmd;
            }
            else
            {
                lblEstado.Text = "LIBERADA";
                lblEstado.ForeColor = Color.SeaGreen;
                lblMotivo.Text = "Operando dentro do plano.";
            }

            lblOps.Text = string.Format("Operacoes: {0} / {1}", opsDia, cfg.MaxOperacoes > 0 ? cfg.MaxOperacoes.ToString() : "sem limite")
                        + (cfg.MaxPerdasSeguidas > 0 ? string.Format("   |   perdas seguidas: {0} / {1}", perdasSeguidas, cfg.MaxPerdasSeguidas) : "")
                        + (cfg.ProtecaoDevolverPts > 0
                           ? string.Format(CultureInfo.InvariantCulture, "   |   melhor fechado: {0:0} pts{1}", picoFechado,
                                 picoFechado >= Math.Max(1, cfg.ProtecaoAtivaPts)
                                 ? string.Format(CultureInfo.InvariantCulture, " (protegido: trava em {0:0})", picoFechado - cfg.ProtecaoDevolverPts)
                                 : " (protecao ainda nao ativa)")
                           : "");
            lblPts.Text = string.Format(CultureInfo.InvariantCulture,
                "Pontos: realizado {0:0} | flutuante {1:0} | total {2:0}   (meta {3}, limite de perda {4})",
                ptsReal, ptsFlut, total,
                cfg.MetaPontos > 0 ? "+" + cfg.MetaPontos.ToString("0", CultureInfo.InvariantCulture) : "-",
                cfg.LimitePerda > 0 ? "-" + cfg.LimitePerda.ToString("0", CultureInfo.InvariantCulture) : "-");
            lblHorario.Text = string.Format("Inicio {0} | limite {1} | reset {2} | conta mae {3} | dia desde {4:dd/MM HH:mm}",
                cfg.HoraInicio == "" ? "-" : cfg.HoraInicio, cfg.HoraFim == "" ? "-" : cfg.HoraFim, cfg.HoraReset,
                IdMae() == "" ? "(nao encontrada)" : IdMae(), iniDia);

            string jan;
            bool livre = cfg.EdicaoLivreAgora(agora, out jan);
            lblEdicao.Text = (est.Travado ? "Central TRAVADA: alteracoes so com a senha mestra." : jan);
            lblEdicao.ForeColor = (livre && !est.Travado) ? Color.SeaGreen : Color.Firebrick;

            string idMae = IdMae();
            List<string> filhas = cfg.Filhas();
            lvContas.BeginUpdate();
            lvContas.Items.Clear();
            foreach (StatusConta s in contas)
            {
                string papel = s.Id == idMae ? "MAE" : (filhas.Contains(s.Id) ? "filha" : "-");
                ListViewItem it = new ListViewItem(new[]
                {
                    s.Id, papel, s.Modo, s.Simbolo, s.Online ? "sim" : "nao", s.Posicoes.ToString(),
                    s.Flutuante.ToString("0", CultureInfo.InvariantCulture)
                });
                if (!s.Online) it.ForeColor = Color.Gray;
                lvContas.Items.Add(it);
            }
            lvContas.EndUpdate();

            tray.Text = est.Travado ? "Central: TRAVADA" : "Central: " + lblEstado.Text;
        }

        private void Evento(string msg)
        {
            Util.Log(msg);
            if (lbEventos == null) return;
            lbEventos.Items.Insert(0, DateTime.Now.ToString("dd/MM HH:mm:ss") + "  " + msg);
            while (lbEventos.Items.Count > 300) lbEventos.Items.RemoveAt(lbEventos.Items.Count - 1);
        }

        private void MostrarJanela()
        {
            Show();
            WindowState = FormWindowState.Normal;
            Activate();
        }

        private void SairComSenha()
        {
            if (!ConferirSenha("Senha mestra para FECHAR a central (os EAs ficarao bloqueados)")) return;
            Evento("Central fechada com a senha mestra.");
            sairAutorizado = true;
            timer.Stop();
            tray.Visible = false;
            Application.Exit();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!sairAutorizado && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;     // fechar a janela so esconde; a central continua rodando
                Hide();
                try { tray.ShowBalloonTip(3000, "Central de Controle", "A central continua ativa (icone do escudo).", ToolTipIcon.Info); }
                catch (Exception) { }
                return;
            }
            tray.Visible = false;
            base.OnFormClosing(e);
        }
    }
}
