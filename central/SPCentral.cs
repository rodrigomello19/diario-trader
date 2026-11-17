// ============================================================================
//  SPCentral v2.0 - Central de Controle do Scalper Pro
// ----------------------------------------------------------------------------
//  Protege o plano de trading, com REGRAS POR CONTA E ATIVO:
//   - horario de bloqueio (das HH:mm as HH:mm): nao opera dentro do intervalo;
//   - bloqueio por pontos ganhos/perdidos e por valor ganho/perdido no dia;
//   - protecao de lucro: "quando atingido (valor)" + "drawdown maximo (valor)";
//   - maximo de operacoes, parar apos N perdas seguidas, pausa apos perda;
//   - ganho/operacoes -> sem novas entradas; perda/drawdown -> ZERA a conta/ativo;
//   - a trava de uma regra dura ate o reset diario; a SENHA MESTRA destrava antes;
//   - operacoes feitas fora do Scalper Pro / copiador / DGX (a mao no MT5, no
//     celular, na web ou por outro robo) sao zeradas pelo Scalper Pro da conta;
//   - MT5 aberto em conta sem Scalper Pro: so aviso (pode ser grafico de estudo);
//   - fecha navegadores (TradingView, Tradovate, Apex, NinjaTrader) e, ao travar,
//     as plataformas (MT5, NinjaTrader...);
//   - configuracoes so podem ser alteradas na janela de edicao (ex.: 08:00-11:30);
//     fora dela, ou com alguma trava ativa, so com a senha mestra;
//   - recuperacao de senha: pedido agora, nova senha temporaria enviada por
//     e-mail e Telegram as 20:00 do dia do pedido;
//   - instalada em pasta oculta; o .exe baixado so instala se nao houver outra
//     central instalada (para atualizar: Desinstalar e instalar a nova).
//
//  Comunicacao: arquivos em %APPDATA%\MetaQuotes\Terminal\Common\Files
//   SP_Central_Ativa.txt            marca: EAs passam a obedecer a central
//   SP_Central_Cmd.txt              CMD|2|tickMs|LIVRE/BLOQ|motivo|ate   (geral)
//                                   F|1/0|magics permitidos               (zerar operacoes de fora)
//                                   B|conta|ativo|motivo                  (sem novas entradas)
//                                   Z|conta|ativo|motivo                  (zerar)
//   SP_Central_St_<conta>_<sim>.txt estado de cada EA/estrategia (1 s)
//   SP_Central_Tr_<conta>.txt       operacoes encerradas (pontos e valor)
//   SP_Central_Pedido_<conta>.txt   botao BLOCK do Scalper Pro: trava tudo ate o reset e zera as filhas
//
//  Compilar: central\compilar.bat (gera o INSTALADOR SPCentral.exe)
// ============================================================================
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.Drawing;
using System.Globalization;
using System.IO;
using System.Net;
using System.Net.Mail;
using System.Reflection;
using System.Runtime.InteropServices;
using System.Security.AccessControl;
using System.Security.Principal;
using System.Security.Cryptography;
using System.Text;
using System.Text.RegularExpressions;
using System.Threading;
using System.Windows.Automation;
using System.Windows.Forms;
using Microsoft.Win32;

[assembly: System.Reflection.AssemblyTitle("SPCentral")]
[assembly: System.Reflection.AssemblyVersion("2.0.0.0")]

namespace SPCentral
{
    internal static class Program
    {
        public const string VERSAO = "2.0";

        [STAThread]
        private static void Main()
        {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);

            // Rodando fora da pasta de instalacao = este .exe e o INSTALADOR
            if (!Instalacao.RodandoInstalado())
            {
                Instalacao.Instalar();
                return;
            }

            bool novo;
            using (Mutex mtx = new Mutex(true, Instalacao.NOME_MUTEX, out novo))
            using (EventWaitHandle mostrar = new EventWaitHandle(false, EventResetMode.AutoReset, "SPCentral_mostrar_janela"))
            {
                if (!novo)
                {
                    // ja esta rodando: so pede para a central aberta aparecer (nunca abre uma segunda)
                    mostrar.Set();
                    return;
                }

                // um erro inesperado nunca fecha a central: vai para o log e ela continua
                Application.SetUnhandledExceptionMode(UnhandledExceptionMode.CatchException);
                Application.ThreadException += delegate(object o, ThreadExceptionEventArgs e)
                {
                    Util.Log("ERRO (a central continua rodando): " + e.Exception);
                };
                AppDomain.CurrentDomain.UnhandledException += delegate(object o, UnhandledExceptionEventArgs e)
                {
                    Util.Log("ERRO GRAVE: " + e.ExceptionObject);
                };

                FormCentral form = new FormCentral();
                ThreadPool.RegisterWaitForSingleObject(mostrar, delegate(object st, bool tempo)
                {
                    try { if (form.IsHandleCreated) form.BeginInvoke(new MethodInvoker(form.MostrarJanela)); }
                    catch (Exception) { }
                }, null, -1, false);
                Application.Run(form);
            }
        }
    }

    // ------------------------------------------------------------------------
    //  Instalacao em pasta oculta, atalhos e bloqueio de reinstalacao
    // ------------------------------------------------------------------------
    internal static class Instalacao
    {
        public const string NOME_MUTEX = "SPCentral_instancia_unica";
        public const string NOME_ATALHO = "Central de Controle.lnk";

        // Pasta oculta (atributos Oculto + Sistema: nao aparece no Explorador com as opcoes padrao)
        public static readonly string Pasta = Path.Combine(
            Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData), "SPCentralApp");
        public static string Exe { get { return Path.Combine(Pasta, "SPCentral.exe"); } }
        public static string AtalhoAreaTrabalho { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory), NOME_ATALHO); } }
        public static string AtalhoMenuIniciar  { get { return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs), NOME_ATALHO); } }

        public static bool RodandoInstalado()
        {
            try
            {
                return string.Equals(Path.GetFullPath(Application.ExecutablePath), Path.GetFullPath(Exe), StringComparison.OrdinalIgnoreCase);
            }
            catch (Exception) { return false; }
        }

        public static bool JaInstalada(out string versao)
        {
            versao = "";
            try
            {
                using (RegistryKey rk = Registry.CurrentUser.OpenSubKey(Util.RegChave))
                {
                    if (rk != null && (rk.GetValue("Instalado") as string) == "1")
                    {
                        versao = (rk.GetValue("Versao") as string) ?? "";
                        return true;
                    }
                }
            }
            catch (Exception) { }
            return File.Exists(Exe);
        }

        public static bool CentralAberta()
        {
            bool novo;
            try
            {
                using (Mutex m = new Mutex(false, NOME_MUTEX, out novo)) { }
                return !novo;
            }
            catch (Exception) { return true; }
        }

        // O .exe baixado/compilado: instala SO se nao houver outra central (nem aberta nem instalada).
        public static void Instalar()
        {
            string ver;
            if (CentralAberta() || JaInstalada(out ver))
            {
                MessageBox.Show(
                    "Ja existe uma Central de Controle " + (CentralAberta() ? "ABERTA" : "INSTALADA") + ".\r\n\r\n" +
                    "Para instalar esta versao (v" + Program.VERSAO + "), desinstale a atual primeiro:\r\n" +
                    "abra a central > aba Senha mestra > Desinstalar (pede a senha mestra).\r\n\r\n" +
                    "Se for a central antiga (v1.x), use 'Fechar a central' nela antes de instalar.",
                    "Central de Controle - instalacao bloqueada", MessageBoxButtons.OK, MessageBoxIcon.Stop);
                return;
            }
            if (MessageBox.Show(
                    "Instalar a Central de Controle v" + Program.VERSAO + "?\r\n\r\n" +
                    "- o programa fica numa pasta oculta;\r\n" +
                    "- cria o atalho 'Central de Controle' na Area de Trabalho e no Menu Iniciar;\r\n" +
                    "- inicia junto com o Windows.",
                    "Central de Controle", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes)
                return;
            try
            {
                Directory.CreateDirectory(Pasta);
                File.Copy(Application.ExecutablePath, Exe, true);
                OcultarPasta(Pasta);
                using (RegistryKey rk = Registry.CurrentUser.CreateSubKey(Util.RegChave))
                {
                    rk.SetValue("Instalado", "1");
                    rk.SetValue("Versao", Program.VERSAO);
                    rk.SetValue("Exe", Exe);
                }
                CriarAtalhosEInicio();
                Process.Start(Exe);
                MessageBox.Show("Central de Controle v" + Program.VERSAO + " instalada.\r\n\r\nUse o atalho 'Central de Controle' na Area de Trabalho.",
                    "Central de Controle", MessageBoxButtons.OK, MessageBoxIcon.Information);
            }
            catch (Exception ex)
            {
                MessageBox.Show("Falha na instalacao: " + ex.Message, "Central de Controle", MessageBoxButtons.OK, MessageBoxIcon.Error);
            }
        }

        public static void OcultarPasta(string pasta)
        {
            try
            {
                if (!Directory.Exists(pasta)) return;
                DirectoryInfo di = new DirectoryInfo(pasta);
                di.Attributes = di.Attributes | FileAttributes.Hidden | FileAttributes.System;
            }
            catch (Exception ex) { Util.Log("ocultar " + pasta + ": " + ex.Message); }
        }

        public static void CriarAtalhosEInicio()
        {
            string exe = Exe;
            using (RegistryKey run = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
            {
                string valor = "\"" + exe + "\"";
                if ((run.GetValue("SPCentral") as string) != valor) run.SetValue("SPCentral", valor);
            }
            if (!File.Exists(AtalhoAreaTrabalho)) Util.CriarAtalho(AtalhoAreaTrabalho, exe, "Central de Controle - Scalper Pro");
            if (!File.Exists(AtalhoMenuIniciar))  Util.CriarAtalho(AtalhoMenuIniciar, exe, "Central de Controle - Scalper Pro");
        }

        public static void RemoverAtalhosEInicio()
        {
            try
            {
                using (RegistryKey run = Registry.CurrentUser.CreateSubKey(@"Software\Microsoft\Windows\CurrentVersion\Run"))
                    run.DeleteValue("SPCentral", false);
            }
            catch (Exception) { }
            try { if (File.Exists(AtalhoAreaTrabalho)) File.Delete(AtalhoAreaTrabalho); } catch (Exception) { }
            try { if (File.Exists(AtalhoMenuIniciar)) File.Delete(AtalhoMenuIniciar); } catch (Exception) { }
        }

        // Apaga a pasta do programa depois que a central fechar (um .exe aberto nao pode ser apagado)
        public static void AgendarRemocaoDaPasta()
        {
            try
            {
                ProcessStartInfo psi = new ProcessStartInfo("cmd.exe",
                    "/c ping 127.0.0.1 -n 4 > nul & attrib -s -h \"" + Pasta + "\" & rmdir /s /q \"" + Pasta + "\"");
                psi.CreateNoWindow = true;
                psi.UseShellExecute = false;
                psi.WindowStyle = ProcessWindowStyle.Hidden;
                Process.Start(psi);
            }
            catch (Exception ex) { Util.Log("remocao da pasta: " + ex.Message); }
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

        // Senha temporaria da recuperacao: 10 caracteres sem os que confundem (0/O, 1/l/I)
        public static string SenhaTemporaria()
        {
            const string letras = "ABCDEFGHJKMNPQRSTUVWXYZabcdefghjkmnpqrstuvwxyz23456789";
            byte[] b = new byte[10];
            using (RandomNumberGenerator r = RandomNumberGenerator.Create()) r.GetBytes(b);
            StringBuilder sb = new StringBuilder();
            foreach (byte x in b) sb.Append(letras[x % letras.Length]);
            return sb.ToString();
        }

        // Segredos (senha do e-mail, token do Telegram): cifrados pelo Windows (DPAPI) para este usuario
        public static string Cifrar(string texto)
        {
            if (string.IsNullOrEmpty(texto)) return "";
            try
            {
                byte[] c = ProtectedData.Protect(Encoding.UTF8.GetBytes(texto), Encoding.UTF8.GetBytes("SPCentral"), DataProtectionScope.CurrentUser);
                return Convert.ToBase64String(c);
            }
            catch (Exception) { return ""; }
        }

        public static string Decifrar(string b64)
        {
            if (string.IsNullOrEmpty(b64)) return "";
            try
            {
                byte[] p = ProtectedData.Unprotect(Convert.FromBase64String(b64), Encoding.UTF8.GetBytes("SPCentral"), DataProtectionScope.CurrentUser);
                return Encoding.UTF8.GetString(p);
            }
            catch (Exception) { return ""; }
        }

        public static bool ParseHora(string s, out TimeSpan t)
        {
            t = TimeSpan.Zero;
            if (string.IsNullOrWhiteSpace(s)) return false;
            return TimeSpan.TryParseExact(s.Trim(), new[] { @"hh\:mm", @"h\:mm" }, CultureInfo.InvariantCulture, out t)
                   && t >= TimeSpan.Zero && t < TimeSpan.FromDays(1);
        }

        // Hora atual dentro de [ini, fim)? Aceita intervalo que passa da meia-noite (ex.: 22:00-06:00).
        public static bool DentroIntervalo(DateTime agora, string ini, string fim)
        {
            TimeSpan a, b;
            if (!ParseHora(ini, out a) || !ParseHora(fim, out b) || a == b) return false;
            TimeSpan t = agora.TimeOfDay;
            return a < b ? (t >= a && t < b) : (t >= a || t < b);
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

        // ---- protecao contra exclusao (permissao "negar excluir" para Todos) ----
        private static readonly SecurityIdentifier Todos = new SecurityIdentifier(WellKnownSidType.WorldSid, null);

        public static void ProtegerArquivo(string arq, bool proteger)
        {
            try
            {
                if (!File.Exists(arq)) return;
                FileSecurity fs = File.GetAccessControl(arq);
                FileSystemAccessRule r = new FileSystemAccessRule(Todos, FileSystemRights.Delete, AccessControlType.Deny);
                if (proteger) fs.AddAccessRule(r); else fs.RemoveAccessRule(r);
                File.SetAccessControl(arq, fs);
            }
            catch (Exception ex) { Log("protecao de " + arq + ": " + ex.Message); }
        }

        public static void ProtegerPasta(string pasta, bool proteger)
        {
            try
            {
                if (!Directory.Exists(pasta)) return;
                DirectorySecurity ds = Directory.GetAccessControl(pasta);
                FileSystemAccessRule r = new FileSystemAccessRule(Todos,
                    FileSystemRights.Delete | FileSystemRights.DeleteSubdirectoriesAndFiles,
                    InheritanceFlags.ContainerInherit | InheritanceFlags.ObjectInherit, PropagationFlags.None, AccessControlType.Deny);
                if (proteger) ds.AddAccessRule(r); else ds.RemoveAccessRule(r);
                Directory.SetAccessControl(pasta, ds);
            }
            catch (Exception ex) { Log("protecao de " + pasta + ": " + ex.Message); }
        }

        // Atalho .lnk pelo WScript.Shell (sem referencias extras para compilar)
        public static void CriarAtalho(string lnk, string alvo, string descricao)
        {
            object sh = null, at = null;
            try
            {
                Type t = Type.GetTypeFromProgID("WScript.Shell");
                if (t == null) return;
                sh = Activator.CreateInstance(t);
                at = t.InvokeMember("CreateShortcut", BindingFlags.InvokeMethod, null, sh, new object[] { lnk });
                Type ta = at.GetType();
                ta.InvokeMember("TargetPath", BindingFlags.SetProperty, null, at, new object[] { alvo });
                ta.InvokeMember("WorkingDirectory", BindingFlags.SetProperty, null, at, new object[] { Path.GetDirectoryName(alvo) });
                ta.InvokeMember("Description", BindingFlags.SetProperty, null, at, new object[] { descricao });
                ta.InvokeMember("IconLocation", BindingFlags.SetProperty, null, at, new object[] { alvo + ",0" });
                ta.InvokeMember("Save", BindingFlags.InvokeMethod, null, at, null);
            }
            catch (Exception ex) { Log("atalho " + lnk + ": " + ex.Message); }
            finally
            {
                if (at != null && Marshal.IsComObject(at)) Marshal.ReleaseComObject(at);
                if (sh != null && Marshal.IsComObject(sh)) Marshal.ReleaseComObject(sh);
            }
        }

        // ---- envio da recuperacao de senha ----
        public static void EnviarEmail(string servidor, int porta, string usuario, string senha, string para, string assunto, string texto)
        {
            using (MailMessage m = new MailMessage(usuario, para, assunto, texto))
            using (SmtpClient c = new SmtpClient(servidor, porta))
            {
                c.EnableSsl = true;
                c.DeliveryMethod = SmtpDeliveryMethod.Network;
                c.UseDefaultCredentials = false;
                c.Credentials = new NetworkCredential(usuario, senha);
                c.Timeout = 30000;
                c.Send(m);
            }
        }

        public static void EnviarTelegram(string token, string chatId, string texto)
        {
            ServicePointManager.SecurityProtocol = ServicePointManager.SecurityProtocol | (SecurityProtocolType)3072;   // TLS 1.2
            string url = "https://api.telegram.org/bot" + token.Trim() + "/sendMessage?chat_id="
                       + Uri.EscapeDataString(chatId.Trim()) + "&text=" + Uri.EscapeDataString(texto);
            HttpWebRequest req = (HttpWebRequest)WebRequest.Create(url);
            req.Method = "GET";
            req.Timeout = 30000;
            using (HttpWebResponse resp = (HttpWebResponse)req.GetResponse())
            {
                if ((int)resp.StatusCode != 200) throw new Exception("Telegram respondeu " + (int)resp.StatusCode);
            }
        }

        public static double ParseD(string s)
        {
            double v;
            return double.TryParse((s ?? "").Trim(), NumberStyles.Float, CultureInfo.InvariantCulture, out v) ? v : 0;
        }

        public static long ParseL(string s)
        {
            long v;
            return long.TryParse((s ?? "").Trim(), NumberStyles.Integer, CultureInfo.InvariantCulture, out v) ? v : 0;
        }

        public static string D(double v) { return v.ToString("0.##", CultureInfo.InvariantCulture); }

        public static List<string> ListaCsv(string csv)
        {
            List<string> l = new List<string>();
            foreach (string t in (csv ?? "").Split(new[] { ',', ';' }, StringSplitOptions.RemoveEmptyEntries))
            {
                string x = t.Trim();
                if (x.EndsWith(".exe", StringComparison.OrdinalIgnoreCase)) x = x.Substring(0, x.Length - 4);
                if (x.Length > 0) l.Add(x);
            }
            return l;
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
    //  Regra por conta e ativo
    // ------------------------------------------------------------------------
    internal class Regra
    {
        public int    Id;
        public string Conta = "";          // login MT5 (ex.: 510087363) ou NT-<conta>
        public string Ativo = "*";         // simbolo (US100, MNQ...) ou * = todos os ativos da conta
        public bool   UsaHorarioBloqueio;
        public string BloqueioDe = "12:00";
        public string BloqueioAte = "14:00";
        public bool   ZerarNoBloqueio;     // zera a posicao quando o horario de bloqueio comecar
        public double PontosGanhos, PontosPerdidos, ValorGanho, ValorPerdido;
        public int    MaxOperacoes;
        public double ProtQuandoAtingido, ProtDrawdown;
        public int    PerdasSeguidas, PausaMin;
        public bool   FecharNavegadores = true;
        public bool   FecharPlataformas = true;

        private static string F(double v) { return v.ToString(CultureInfo.InvariantCulture); }

        public void Salvar(ArquivoAssinado a, string p)
        {
            a.Set(p + "Id", Id.ToString(CultureInfo.InvariantCulture));
            a.Set(p + "Conta", Conta);
            a.Set(p + "Ativo", Ativo);
            a.Set(p + "UsaHorario", UsaHorarioBloqueio ? "1" : "0");
            a.Set(p + "BloqDe", BloqueioDe);
            a.Set(p + "BloqAte", BloqueioAte);
            a.Set(p + "ZerarBloq", ZerarNoBloqueio ? "1" : "0");
            a.Set(p + "PtsGanhos", F(PontosGanhos));
            a.Set(p + "PtsPerdidos", F(PontosPerdidos));
            a.Set(p + "ValGanho", F(ValorGanho));
            a.Set(p + "ValPerdido", F(ValorPerdido));
            a.Set(p + "MaxOps", MaxOperacoes.ToString(CultureInfo.InvariantCulture));
            a.Set(p + "ProtAtingido", F(ProtQuandoAtingido));
            a.Set(p + "ProtDD", F(ProtDrawdown));
            a.Set(p + "PerdasSeg", PerdasSeguidas.ToString(CultureInfo.InvariantCulture));
            a.Set(p + "PausaMin", PausaMin.ToString(CultureInfo.InvariantCulture));
            a.Set(p + "FechaNav", FecharNavegadores ? "1" : "0");
            a.Set(p + "FechaPlat", FecharPlataformas ? "1" : "0");
        }

        public void Carregar(ArquivoAssinado a, string p)
        {
            Id                 = (int)Util.ParseL(a.Get(p + "Id", "0"));
            Conta              = a.Get(p + "Conta", "");
            Ativo              = a.Get(p + "Ativo", "*");
            UsaHorarioBloqueio = a.Get(p + "UsaHorario", "0") == "1";
            BloqueioDe         = a.Get(p + "BloqDe", "12:00");
            BloqueioAte        = a.Get(p + "BloqAte", "14:00");
            ZerarNoBloqueio    = a.Get(p + "ZerarBloq", "0") == "1";
            PontosGanhos       = Util.ParseD(a.Get(p + "PtsGanhos", "0"));
            PontosPerdidos     = Util.ParseD(a.Get(p + "PtsPerdidos", "0"));
            ValorGanho         = Util.ParseD(a.Get(p + "ValGanho", "0"));
            ValorPerdido       = Util.ParseD(a.Get(p + "ValPerdido", "0"));
            MaxOperacoes       = (int)Util.ParseL(a.Get(p + "MaxOps", "0"));
            ProtQuandoAtingido = Util.ParseD(a.Get(p + "ProtAtingido", "0"));
            ProtDrawdown       = Util.ParseD(a.Get(p + "ProtDD", "0"));
            PerdasSeguidas     = (int)Util.ParseL(a.Get(p + "PerdasSeg", "0"));
            PausaMin           = (int)Util.ParseL(a.Get(p + "PausaMin", "0"));
            FecharNavegadores  = a.Get(p + "FechaNav", "1") == "1";
            FecharPlataformas  = a.Get(p + "FechaPlat", "1") == "1";
        }

        public Regra Copia()
        {
            Regra r = (Regra)MemberwiseClone();
            return r;
        }

        public bool Ativa { get { return Conta.Trim().Length > 0; } }

        public bool BateConta(string id) { return string.Equals(Conta.Trim(), (id ?? "").Trim(), StringComparison.OrdinalIgnoreCase); }

        // * = qualquer; senao igual ou prefixo (US100 vale para US100.cash; MNQ vale para MNQ 12-26)
        public static bool BateAtivo(string regraAtivo, string simbolo)
        {
            string a = (regraAtivo ?? "").Trim();
            if (a == "" || a == "*") return true;
            return (simbolo ?? "").Trim().StartsWith(a, StringComparison.OrdinalIgnoreCase);
        }

        public string AtivoTexto { get { return (Ativo.Trim() == "" || Ativo.Trim() == "*") ? "todos" : Ativo.Trim(); } }

        public string ResumoHorario()
        {
            if (!UsaHorarioBloqueio) return "-";
            return BloqueioDe + " a " + BloqueioAte + (ZerarNoBloqueio ? " (zera)" : "");
        }

        public string ResumoLimites()
        {
            List<string> l = new List<string>();
            if (PontosGanhos > 0)   l.Add("+" + Util.D(PontosGanhos) + " pts");
            if (PontosPerdidos > 0) l.Add("-" + Util.D(PontosPerdidos) + " pts");
            if (ValorGanho > 0)     l.Add("+$" + Util.D(ValorGanho));
            if (ValorPerdido > 0)   l.Add("-$" + Util.D(ValorPerdido));
            if (MaxOperacoes > 0)   l.Add(MaxOperacoes + " ops");
            if (PerdasSeguidas > 0) l.Add(PerdasSeguidas + " perdas seguidas");
            if (PausaMin > 0)       l.Add("pausa " + PausaMin + " min");
            return l.Count == 0 ? "-" : string.Join(" | ", l.ToArray());
        }

        public bool ProtecaoLigada { get { return ProtQuandoAtingido > 0 && ProtDrawdown > 0; } }

        public string ResumoProtecao()
        {
            if (!ProtecaoLigada) return "-";
            return "a partir de $" + Util.D(ProtQuandoAtingido) + ", DD $" + Util.D(ProtDrawdown);
        }
    }

    // ------------------------------------------------------------------------
    //  Configuracao geral + regras
    // ------------------------------------------------------------------------
    internal class Config
    {
        public List<Regra> Regras = new List<Regra>();
        public int    ProximoId = 1;
        public string HoraReset = "06:00";
        public string EdicaoDe = "08:00";       // edicao livre (sem senha) das ...
        public string EdicaoAte = "11:30";      // ... as (inicio do pregao)
        public bool   ZerarForaDoSistema = true;
        public string MagicsPermitidos = "";    // DGX e outros robos autorizados (numeros magicos)
        public string ContaMae = "";
        public string ContasFilhas = "";
        public int    DivergenciaSeg = 20;
        public string Processos = "terminal64,terminal,NinjaTrader,TradingView";
        public string TitulosJanelas = "TradingView,NinjaTrader,Tradovate,Apex";
        public string Navegadores = "chrome,msedge,firefox,opera,brave,vivaldi,iexplore";
        // recuperacao de senha
        public string RecEmail = "";
        public string RecSmtpServidor = "smtp.gmail.com";
        public int    RecSmtpPorta = 587;
        public string RecSmtpUsuario = "";
        public string RecSmtpSenhaCifrada = "";
        public string RecTelegramTokenCifrado = "";
        public string RecTelegramChat = "";
        public string RecHora = "20:00";

        public static string Caminho { get { return Path.Combine(Util.PastaApp, "config.txt"); } }

        public void Salvar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            a.Set("Versao", "2");
            a.Set("NRegras", Regras.Count.ToString(CultureInfo.InvariantCulture));
            for (int i = 0; i < Regras.Count; i++) Regras[i].Salvar(a, "R" + i + "_");
            a.Set("ProximoId", ProximoId.ToString(CultureInfo.InvariantCulture));
            a.Set("HoraReset", HoraReset);
            a.Set("EdicaoDe", EdicaoDe);
            a.Set("EdicaoAte", EdicaoAte);
            a.Set("ZerarForaDoSistema", ZerarForaDoSistema ? "1" : "0");
            a.Set("MagicsPermitidos", MagicsPermitidos);
            a.Set("ContaMae", ContaMae);
            a.Set("ContasFilhas", ContasFilhas);
            a.Set("DivergenciaSeg", DivergenciaSeg.ToString(CultureInfo.InvariantCulture));
            a.Set("Processos", Processos);
            a.Set("TitulosJanelas", TitulosJanelas);
            a.Set("Navegadores", Navegadores);
            a.Set("RecEmail", RecEmail);
            a.Set("RecSmtpServidor", RecSmtpServidor);
            a.Set("RecSmtpPorta", RecSmtpPorta.ToString(CultureInfo.InvariantCulture));
            a.Set("RecSmtpUsuario", RecSmtpUsuario);
            a.Set("RecSmtpSenha", RecSmtpSenhaCifrada);
            a.Set("RecTelegramToken", RecTelegramTokenCifrado);
            a.Set("RecTelegramChat", RecTelegramChat);
            a.Set("RecHora", RecHora);
            a.Salvar(Caminho);
        }

        // 0 = ok, 1 = ausente, 2 = assinatura invalida. Converte a configuracao da v1.x numa regra.
        public int Carregar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            int r = a.Carregar(Caminho);
            if (r == 1) return r;
            if (a.Get("Versao", "1") != "2") { MigrarV1(a); return r; }

            Regras.Clear();
            int n = (int)Util.ParseL(a.Get("NRegras", "0"));
            for (int i = 0; i < n; i++)
            {
                Regra g = new Regra();
                g.Carregar(a, "R" + i + "_");
                Regras.Add(g);
            }
            ProximoId        = (int)Util.ParseL(a.Get("ProximoId", "1"));
            HoraReset        = a.Get("HoraReset", HoraReset);
            EdicaoDe         = a.Get("EdicaoDe", EdicaoDe);
            EdicaoAte        = a.Get("EdicaoAte", EdicaoAte);
            ZerarForaDoSistema = a.Get("ZerarForaDoSistema", "1") == "1";
            MagicsPermitidos = a.Get("MagicsPermitidos", "");
            ContaMae         = a.Get("ContaMae", "");
            ContasFilhas     = a.Get("ContasFilhas", "");
            DivergenciaSeg   = (int)Util.ParseL(a.Get("DivergenciaSeg", "20"));
            Processos        = a.Get("Processos", Processos);
            TitulosJanelas   = a.Get("TitulosJanelas", TitulosJanelas);
            Navegadores      = a.Get("Navegadores", Navegadores);
            RecEmail         = a.Get("RecEmail", "");
            RecSmtpServidor  = a.Get("RecSmtpServidor", RecSmtpServidor);
            RecSmtpPorta     = (int)Util.ParseL(a.Get("RecSmtpPorta", "587"));
            RecSmtpUsuario   = a.Get("RecSmtpUsuario", "");
            RecSmtpSenhaCifrada     = a.Get("RecSmtpSenha", "");
            RecTelegramTokenCifrado = a.Get("RecTelegramToken", "");
            RecTelegramChat  = a.Get("RecTelegramChat", "");
            RecHora          = a.Get("RecHora", "20:00");
            foreach (Regra g in Regras) if (g.Id >= ProximoId) ProximoId = g.Id + 1;
            return r;
        }

        // v1.x: limites unicos para a conta mae -> uma regra para a conta mae, todos os ativos
        private void MigrarV1(ArquivoAssinado a)
        {
            Regra g = new Regra();
            g.Id = ProximoId++;
            g.Conta = a.Get("ContaMae", "");
            g.Ativo = "*";
            g.MaxOperacoes = (int)Util.ParseL(a.Get("MaxOperacoes", "0"));
            g.PontosGanhos = Util.ParseD(a.Get("MetaPontos", "0"));
            g.PontosPerdidos = Util.ParseD(a.Get("LimitePerda", "0"));
            g.PerdasSeguidas = (int)Util.ParseL(a.Get("MaxPerdasSeguidas", "0"));
            g.PausaMin = (int)Util.ParseL(a.Get("PausaAposPerdaMin", "0"));
            string ini = a.Get("HoraInicio", ""), fim = a.Get("HoraFim", ""), reset = a.Get("HoraReset", "06:00");
            TimeSpan t;
            if (Util.ParseHora(fim, out t))
            {
                // v1: operava de inicio a fim -> v2: bloqueado de fim ate o inicio (ou ate o reset)
                g.UsaHorarioBloqueio = true;
                g.BloqueioDe = fim;
                g.BloqueioAte = Util.ParseHora(ini, out t) ? ini : reset;
                g.ZerarNoBloqueio = a.Get("ZerarNoHorarioFim", "0") == "1";
            }
            g.FecharPlataformas = a.Get("FecharPlataformas", "1") == "1";
            g.FecharNavegadores = a.Get("FecharNavegadoresForaHorario", "1") == "1";
            Regras.Clear();
            Regras.Add(g);
            HoraReset = reset;
            // v1: edicao bloqueada de X ate Y -> v2: edicao livre de Y ate X
            EdicaoDe = a.Get("EdicaoLiberaAs", "22:00");
            EdicaoAte = a.Get("EdicaoBloqueiaAs", "09:00");
            ContaMae = a.Get("ContaMae", "");
            ContasFilhas = a.Get("ContasFilhas", "");
            DivergenciaSeg = (int)Util.ParseL(a.Get("DivergenciaSeg", "20"));
            Processos = a.Get("Processos", Processos);
            string tit = a.Get("TitulosJanelas", "");
            if (tit.Trim() != "") TitulosJanelas = tit.IndexOf("Apex", StringComparison.OrdinalIgnoreCase) >= 0 ? tit : tit + ",Apex";
            Navegadores = a.Get("Navegadores", Navegadores);
        }

        public List<string> Filhas()
        {
            List<string> l = new List<string>();
            foreach (string s in ContasFilhas.Split(new[] { ',', ';', ' ' }, StringSplitOptions.RemoveEmptyEntries))
                l.Add(s.Trim());
            return l;
        }

        public Regra RegraPorId(int id)
        {
            foreach (Regra g in Regras) if (g.Id == id) return g;
            return null;
        }

        // Edicao livre (sem senha) dentro de [EdicaoDe, EdicaoAte)
        public bool EdicaoLivreAgora(DateTime agora, out string texto)
        {
            TimeSpan a, b;
            if (!Util.ParseHora(EdicaoDe, out a) || !Util.ParseHora(EdicaoAte, out b))
            {
                texto = "Edicao livre (horario de edicao nao configurado)";
                return true;
            }
            bool livre = Util.DentroIntervalo(agora, EdicaoDe, EdicaoAte);
            texto = livre
                ? string.Format("Edicao LIVRE ate {0} (sem senha)", EdicaoAte)
                : string.Format("Edicao BLOQUEADA ate {0} - alterar so com a senha mestra", EdicaoDe);
            return livre;
        }
    }

    // ------------------------------------------------------------------------
    //  Estado persistido (sobrevive a reinicio do PC e da central)
    // ------------------------------------------------------------------------
    internal class EstadoRegra
    {
        public bool     Travado;
        public string   Motivo = "";
        public string   Modo = "";            // ZERAR ou AGUARDAR
        public DateTime TravadoEm;
        public DateTime TravadoAte;
        public DateTime Base;                 // contagem do dia a partir daqui (destravar com senha recomeca)
        public double   Pico;                 // melhor resultado (valor) do dia - protecao de lucro
        public DateTime PicoBase;             // base a que o pico se refere
    }

    internal class Estado
    {
        public bool     GeralTravado;         // botao BLOCK do Scalper Pro (ou estado apagado/alterado)
        public string   GeralMotivo = "";
        public DateTime GeralAte;
        public bool     ZerarFilhas;
        public string   PedidoConta = "";     // conta que apertou BLOCK (nao e zerada pela central)
        public DateTime RecPedidoEm;          // recuperacao de senha
        public DateTime RecEntregaEm;
        public readonly Dictionary<int, EstadoRegra> Regras = new Dictionary<int, EstadoRegra>();

        public static string Caminho { get { return Path.Combine(Util.PastaApp, "estado.txt"); } }

        public EstadoRegra De(int id)
        {
            EstadoRegra e;
            if (!Regras.TryGetValue(id, out e)) { e = new EstadoRegra(); Regras[id] = e; }
            return e;
        }

        private static string T(DateTime d) { return d.Ticks.ToString(CultureInfo.InvariantCulture); }
        private static DateTime T(string s) { return new DateTime(Util.ParseL(s)); }

        public void Salvar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            a.Set("Versao", "2");
            a.Set("GeralTravado", GeralTravado ? "1" : "0");
            a.Set("GeralMotivo", GeralMotivo);
            a.Set("GeralAte", T(GeralAte));
            a.Set("ZerarFilhas", ZerarFilhas ? "1" : "0");
            a.Set("PedidoConta", PedidoConta);
            a.Set("RecPedidoEm", T(RecPedidoEm));
            a.Set("RecEntregaEm", T(RecEntregaEm));
            List<string> ids = new List<string>();
            foreach (KeyValuePair<int, EstadoRegra> kv in Regras)
            {
                string p = "E" + kv.Key + "_";
                ids.Add(kv.Key.ToString(CultureInfo.InvariantCulture));
                a.Set(p + "Travado", kv.Value.Travado ? "1" : "0");
                a.Set(p + "Motivo", kv.Value.Motivo);
                a.Set(p + "Modo", kv.Value.Modo);
                a.Set(p + "TravadoEm", T(kv.Value.TravadoEm));
                a.Set(p + "TravadoAte", T(kv.Value.TravadoAte));
                a.Set(p + "Base", T(kv.Value.Base));
                a.Set(p + "Pico", kv.Value.Pico.ToString(CultureInfo.InvariantCulture));
                a.Set(p + "PicoBase", T(kv.Value.PicoBase));
            }
            a.Set("Ids", string.Join(",", ids.ToArray()));
            a.Salvar(Caminho);
        }

        public int Carregar()
        {
            ArquivoAssinado a = new ArquivoAssinado();
            int r = a.Carregar(Caminho);
            if (r != 0) return r;
            Regras.Clear();
            if (a.Get("Versao", "1") != "2")
            {
                // estado da v1.x: uma trava geral
                GeralTravado = a.Get("Travado", "0") == "1";
                GeralMotivo  = a.Get("Motivo", "");
                GeralAte     = T(a.Get("TravadoAte", "0"));
                ZerarFilhas  = a.Get("ZerarFilhas", "0") == "1";
                return 0;
            }
            GeralTravado = a.Get("GeralTravado", "0") == "1";
            GeralMotivo  = a.Get("GeralMotivo", "");
            GeralAte     = T(a.Get("GeralAte", "0"));
            ZerarFilhas  = a.Get("ZerarFilhas", "0") == "1";
            PedidoConta  = a.Get("PedidoConta", "");
            RecPedidoEm  = T(a.Get("RecPedidoEm", "0"));
            RecEntregaEm = T(a.Get("RecEntregaEm", "0"));
            foreach (string s in a.Get("Ids", "").Split(new[] { ',' }, StringSplitOptions.RemoveEmptyEntries))
            {
                int id = (int)Util.ParseL(s);
                string p = "E" + id + "_";
                EstadoRegra e = De(id);
                e.Travado    = a.Get(p + "Travado", "0") == "1";
                e.Motivo     = a.Get(p + "Motivo", "");
                e.Modo       = a.Get(p + "Modo", "");
                e.TravadoEm  = T(a.Get(p + "TravadoEm", "0"));
                e.TravadoAte = T(a.Get(p + "TravadoAte", "0"));
                e.Base       = T(a.Get(p + "Base", "0"));
                e.Pico       = Util.ParseD(a.Get(p + "Pico", "0"));
                e.PicoBase   = T(a.Get(p + "PicoBase", "0"));
            }
            return 0;
        }
    }

    // ------------------------------------------------------------------------
    //  Dados lidos dos EAs
    // ------------------------------------------------------------------------
    internal class StatusConta
    {
        public string Id = "";
        public string Simbolo = "";
        public string Modo = "";
        public int    Posicoes;
        public double Flutuante;       // pontos
        public double FlutValor;       // dinheiro (Scalper Pro v6.09+)
        public ulong  TickMs;
        public bool   Online;
    }

    internal class Operacao
    {
        public string   PosId = "";
        public DateTime Fechamento;
        public double   Pts;
        public double   Valor;
        public string   Simbolo = "";
    }

    // Situacao de uma regra calculada a cada ciclo
    internal class SituacaoRegra
    {
        public int      Ops;
        public double   PtsReal, ValReal, PtsFlut, ValFlut;
        public int      PerdasSeguidas;
        public DateTime UltimaPerda = DateTime.MinValue;
        public int      Estado;            // 0 livre, 1 bloqueia novas, 2 zerar
        public string   Motivo = "";
        public bool     ContaOnline;
        public double PtsTotal { get { return PtsReal + PtsFlut; } }
        public double ValTotal { get { return ValReal + ValFlut; } }
    }

    // ------------------------------------------------------------------------
    //  Editor de uma regra (conta + ativo)
    // ------------------------------------------------------------------------
    internal class FormRegra : Form
    {
        public Regra Resultado;
        private readonly Regra r;
        private ComboBox cbConta, cbAtivo;
        private CheckBox ckHorario, ckZerarBloq, ckNav, ckPlat;
        private DateTimePicker dtDe, dtAte;
        private NumericUpDown nuPtsG, nuPtsP, nuValG, nuValP, nuOps, nuProtA, nuProtDD, nuPerdas, nuPausa;
        private static readonly Font FonteCampo = new Font("Segoe UI", 10f);
        private static readonly Font FonteTitulo = new Font("Segoe UI", 10f, FontStyle.Bold);
        private static readonly Font FonteDica = new Font("Segoe UI", 8.5f);

        public FormRegra(Regra origem, List<string> contas, List<string> ativos)
        {
            r = origem.Copia();
            Text = r.Conta == "" ? "Nova regra" : "Regra da conta " + r.Conta + " / " + r.AtivoTexto;
            Width = 720;
            Height = 760;
            StartPosition = FormStartPosition.CenterParent;
            FormBorderStyle = FormBorderStyle.FixedDialog;
            MaximizeBox = false;
            MinimizeBox = false;
            Font = FonteCampo;
            AutoScroll = true;

            int y = 10, gy;

            GroupBox g1 = Bloco("1. Conta e ativo", y, out gy);
            cbConta = Combo(g1, "Conta", ref gy, contas, r.Conta,
                "Login do MT5 (ex.: 510087363) ou a conta do NinjaTrader como NT-<conta>. A lista mostra as contas conectadas agora.");
            List<string> at = new List<string>();
            at.Add("*");
            at.AddRange(ativos);
            cbAtivo = Combo(g1, "Ativo", ref gy, at, r.Ativo == "" ? "*" : r.Ativo,
                "Simbolo (ex.: US100, XAUUSD, MNQ). * = todos os ativos da conta somados. US100 vale tambem para US100.cash.");
            y = Fechar(g1, gy);

            GroupBox g2 = Bloco("2. Horario de bloqueio (nao opera dentro do intervalo)", y, out gy);
            ckHorario = Check(g2, "Usar horario de bloqueio", ref gy, r.UsaHorarioBloqueio);
            dtDe = Hora(g2, "Bloqueado das", ref gy, r.BloqueioDe);
            dtAte = Hora(g2, "ate as", ref gy, r.BloqueioAte);
            Dica(g2, ref gy, "Ex.: 12:00 ate 14:00 = sem operacoes no almoco. Pode passar da meia-noite (ex.: 17:00 ate 11:30 = so opera das 11:30 as 17:00).");
            ckZerarBloq = Check(g2, "Zerar a posicao aberta quando o bloqueio comecar", ref gy, r.ZerarNoBloqueio);
            y = Fechar(g2, gy);

            GroupBox g3 = Bloco("3. Bloqueios do dia (0 = desligado)", y, out gy);
            nuPtsG = Numero(g3, "Pontos ganhos", ref gy, r.PontosGanhos, 0, "Ao ganhar isso (fechado + aberto): sem novas entradas. A operacao aberta termina.");
            nuPtsP = Numero(g3, "Pontos perdidos", ref gy, r.PontosPerdidos, 0, "Ao perder isso (fechado + aberto): ZERA a conta/ativo.");
            nuValG = Numero(g3, "Valor ganho (dinheiro)", ref gy, r.ValorGanho, 2, "Ao ganhar esse valor: sem novas entradas.");
            nuValP = Numero(g3, "Valor perdido (dinheiro)", ref gy, r.ValorPerdido, 2, "Ao perder esse valor: ZERA a conta/ativo.");
            nuOps  = Numero(g3, "Maximo de operacoes", ref gy, r.MaxOperacoes, 0, "A operacao conta quando fecha. Parciais da mesma posicao = 1 operacao.");
            y = Fechar(g3, gy);

            GroupBox g4 = Bloco("4. Protecao de lucro (os dois campos trabalham juntos)", y, out gy);
            nuProtA = Numero(g4, "Quando atingido (valor)", ref gy, r.ProtQuandoAtingido, 2,
                "Ativa a protecao de lucro. Ao chegar neste ganho, o sistema passa a proteger seus resultados usando o Drawdown maximo, logo abaixo.");
            nuProtDD = Numero(g4, "Drawdown maximo (valor)", ref gy, r.ProtDrawdown, 2,
                "Funciona junto com 'Quando atingido'. Se o resultado cair isso abaixo do melhor resultado do dia: ZERA.");
            Dica(g4, ref gy, "Se um dos dois estiver em 0, esta protecao fica desativada. O melhor resultado inclui a operacao aberta.");
            y = Fechar(g4, gy);

            GroupBox g5 = Bloco("5. Mais protecoes (0 = desligado)", y, out gy);
            nuPerdas = Numero(g5, "Parar apos perdas seguidas", ref gy, r.PerdasSeguidas, 0, "Ex.: 2 = trava apos 2 operacoes perdedoras em sequencia.");
            nuPausa  = Numero(g5, "Pausa apos cada perda (minutos)", ref gy, r.PausaMin, 0, "Sem novas entradas por esse tempo depois de uma perda.");
            y = Fechar(g5, gy);

            GroupBox g6 = Bloco("6. Quando esta regra bloquear", y, out gy);
            ckNav  = Check(g6, "Fechar navegadores com TradingView, Tradovate, Apex... (qualquer bloqueio)", ref gy, r.FecharNavegadores);
            ckPlat = Check(g6, "Fechar plataformas (MT5, NinjaTrader...) ao TRAVAR por limite, depois de zerar", ref gy, r.FecharPlataformas);
            y = Fechar(g6, gy);

            Button ok = new Button { Text = "Salvar regra", Left = 380, Top = y + 6, Width = 140, Height = 34, Font = FonteTitulo };
            Button ca = new Button { Text = "Cancelar", Left = 530, Top = y + 6, Width = 120, Height = 34, DialogResult = DialogResult.Cancel };
            ok.Click += delegate { Confirmar(); };
            Controls.Add(ok);
            Controls.Add(ca);
            Controls.Add(new Label { Left = 10, Top = y + 48, Width = 10, Height = 10 });
            CancelButton = ca;
        }

        private void Confirmar()
        {
            string conta = cbConta.Text.Trim();
            if (conta == "")
            {
                MessageBox.Show("Informe a conta (login do MT5 ou NT-<conta> do NinjaTrader).", Text);
                return;
            }
            r.Conta = conta;
            r.Ativo = cbAtivo.Text.Trim() == "" ? "*" : cbAtivo.Text.Trim();
            r.UsaHorarioBloqueio = ckHorario.Checked;
            r.BloqueioDe = dtDe.Value.ToString("HH:mm", CultureInfo.InvariantCulture);
            r.BloqueioAte = dtAte.Value.ToString("HH:mm", CultureInfo.InvariantCulture);
            if (r.UsaHorarioBloqueio && r.BloqueioDe == r.BloqueioAte)
            {
                MessageBox.Show("O horario de bloqueio precisa ter inicio diferente do fim.", Text);
                return;
            }
            r.ZerarNoBloqueio = ckZerarBloq.Checked;
            r.PontosGanhos = (double)nuPtsG.Value;
            r.PontosPerdidos = (double)nuPtsP.Value;
            r.ValorGanho = (double)nuValG.Value;
            r.ValorPerdido = (double)nuValP.Value;
            r.MaxOperacoes = (int)nuOps.Value;
            r.ProtQuandoAtingido = (double)nuProtA.Value;
            r.ProtDrawdown = (double)nuProtDD.Value;
            r.PerdasSeguidas = (int)nuPerdas.Value;
            r.PausaMin = (int)nuPausa.Value;
            r.FecharNavegadores = ckNav.Checked;
            r.FecharPlataformas = ckPlat.Checked;
            Resultado = r;
            DialogResult = DialogResult.OK;
            Close();
        }

        // ---- montagem ----
        private GroupBox Bloco(string titulo, int y, out int gy)
        {
            GroupBox g = new GroupBox { Text = titulo, Left = 10, Top = y, Width = 670, Font = FonteTitulo };
            Controls.Add(g);
            gy = 26;
            return g;
        }

        private static int Fechar(GroupBox g, int gy)
        {
            g.Height = gy + 8;
            return g.Top + g.Height + 8;
        }

        private static Label Rotulo(Control pai, string texto, int y)
        {
            Label l = new Label { Text = texto, Left = 14, Top = y + 4, Width = 250, Font = FonteCampo };
            pai.Controls.Add(l);
            return l;
        }

        private static void Dica(Control pai, ref int y, string texto)
        {
            Label d = new Label { Text = texto, Left = 14, Top = y, Width = 640, Height = 34, ForeColor = Color.DimGray, Font = FonteDica };
            pai.Controls.Add(d);
            y += 36;
        }

        private static ComboBox Combo(Control pai, string rotulo, ref int y, List<string> itens, string valor, string dica)
        {
            Rotulo(pai, rotulo, y);
            ComboBox c = new ComboBox { Left = 270, Top = y, Width = 380, Font = FonteCampo, DropDownStyle = ComboBoxStyle.DropDown };
            foreach (string s in itens) if (!c.Items.Contains(s)) c.Items.Add(s);
            c.Text = valor;
            pai.Controls.Add(c);
            y += 32;
            Dica(pai, ref y, dica);
            return c;
        }

        private static NumericUpDown Numero(Control pai, string rotulo, ref int y, double valor, int casas, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            NumericUpDown n = new NumericUpDown
            {
                Left = 270, Top = y, Width = 140, Minimum = 0, Maximum = 100000000, DecimalPlaces = casas,
                ThousandsSeparator = true, Font = FonteCampo, TextAlign = HorizontalAlignment.Right
            };
            n.Value = Math.Max(n.Minimum, Math.Min(n.Maximum, (decimal)valor));
            pai.Controls.Add(n);
            Label d = new Label { Text = dica, Left = 420, Top = y - 2, Width = 240, Height = 34, ForeColor = Color.DimGray, Font = FonteDica };
            pai.Controls.Add(d);
            ToolTip tt = new ToolTip();
            tt.SetToolTip(n, dica);
            tt.SetToolTip(l, dica);
            y += 38;
            return n;
        }

        private static DateTimePicker Hora(Control pai, string rotulo, ref int y, string hora)
        {
            Rotulo(pai, rotulo, y);
            DateTimePicker d = new DateTimePicker
            {
                Left = 270, Top = y, Width = 100, Format = DateTimePickerFormat.Custom, CustomFormat = "HH:mm",
                ShowUpDown = true, Font = FonteCampo
            };
            TimeSpan t;
            d.Value = DateTime.Today + (Util.ParseHora(hora, out t) ? t : TimeSpan.Zero);
            pai.Controls.Add(d);
            y += 32;
            return d;
        }

        private static CheckBox Check(Control pai, string texto, ref int y, bool valor)
        {
            CheckBox c = new CheckBox { Text = texto, Left = 14, Top = y, Width = 640, Height = 26, Checked = valor, Font = FonteCampo };
            pai.Controls.Add(c);
            y += 30;
            return c;
        }
    }

    // ------------------------------------------------------------------------
    //  Janela principal: motor da central
    // ------------------------------------------------------------------------
    internal partial class FormCentral : Form
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
        private const int ESPERA_NAVEGADOR_S = 5;

        private readonly Config cfg = new Config();
        private readonly Estado est = new Estado();
        private string senhaHash = "", senhaSalt = "";
        private bool   adulterado;
        private volatile bool sairAutorizado;
        private readonly Dictionary<string, DateTime> divergenteDesde = new Dictionary<string, DateTime>();
        private readonly List<string> zerarContas = new List<string>();   // "id|motivo"
        private DateTime ultimoFechamento = DateTime.MinValue;
        private DateTime ultimaManutencao = DateTime.MinValue;
        private DateTime ultimaProtecao = DateTime.MinValue;
        private DateTime ultimoSalvarPico = DateTime.MinValue;
        private DateTime ultimaVarreduraTerminais = DateTime.MinValue;
        private string   avisoTerminais = "";

        // leitura dos EAs
        private readonly List<StatusConta> contas = new List<StatusConta>();
        private readonly Dictionary<string, List<Operacao>> opsCache = new Dictionary<string, List<Operacao>>();
        private readonly Dictionary<string, DateTime> opsCacheData = new Dictionary<string, DateTime>();
        private readonly Dictionary<int, SituacaoRegra> situacao = new Dictionary<int, SituacaoRegra>();
        private readonly HashSet<string> pedidosFeitos = new HashSet<string>();

        // navegadores (thread em segundo plano)
        private readonly Dictionary<IntPtr, DateTime> pedidoFechar = new Dictionary<IntPtr, DateTime>();
        private volatile bool     navAtivo;
        private volatile string   navMotivo = "";
        private volatile string[] navTitulos = new string[0];
        private volatile string[] navProcs = new string[0];
        private volatile string   navDiag = "";

        // recuperacao de senha
        private volatile bool recEnviando;
        private DateTime recUltTentativa = DateTime.MinValue;

        private readonly NotifyIcon tray = new NotifyIcon();
        private readonly System.Windows.Forms.Timer timer = new System.Windows.Forms.Timer();

        public FormCentral()
        {
            Text = "Central de Controle v" + Program.VERSAO + " - Scalper Pro";
            Width = 980;
            Height = 780;
            StartPosition = FormStartPosition.CenterScreen;
            Font = new Font("Segoe UI", 9.5f);
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
            Thread tNav = new Thread(LoopNavegadores) { IsBackground = true, Name = "SPCentral navegadores" };
            tNav.Start();
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
            if (rc == 2)
            {
                adulterado = true;
                Evento("Configuracao alterada fora da central: bloqueada ate a senha mestra.");
            }
            else if (rc == 1)
                cfg.Salvar();

            int re = est.Carregar();
            if (re != 0)
            {
                DateTime agora = DateTime.Now;
                est.GeralTravado = true;
                est.GeralMotivo = re == 1 ? "estado da central apagado" : "estado da central alterado";
                est.GeralAte = InicioDia(agora).AddDays(1);
                est.Salvar();
                Evento("TRAVA GERAL: " + est.GeralMotivo + ". Ate " + est.GeralAte.ToString("dd/MM HH:mm") + " ou senha mestra.");
            }

            Instalacao.OcultarPasta(Util.PastaApp);
            CarregarCamposGeral();
            CarregarCamposRecuperacao();
            AtualizarListaRegras();
            Evento("Central v" + Program.VERSAO + " iniciada. " + cfg.Regras.Count + " regra(s).");
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
            if (!File.Exists(Config.Caminho)) cfg.Salvar();
            if (!File.Exists(Estado.Caminho)) est.Salvar();
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
                f.Width = 420;
                f.Height = 170;
                f.FormBorderStyle = FormBorderStyle.FixedDialog;
                f.StartPosition = FormStartPosition.CenterScreen;
                f.MinimizeBox = false;
                f.MaximizeBox = false;
                f.TopMost = true;
                f.Font = new Font("Segoe UI", 9.5f);
                Label l = new Label { Text = titulo, Left = 12, Top = 12, Width = 380, Height = 36 };
                TextBox t = new TextBox { Left = 12, Top = 50, Width = 380, UseSystemPasswordChar = true };
                Button ok = new Button { Text = "OK", Left = 226, Top = 86, Width = 80, DialogResult = DialogResult.OK };
                Button ca = new Button { Text = "Cancelar", Left = 312, Top = 86, Width = 80, DialogResult = DialogResult.Cancel };
                f.Controls.AddRange(new Control[] { l, t, ok, ca });
                f.AcceptButton = ok;
                f.CancelButton = ca;
                return f.ShowDialog() == DialogResult.OK ? t.Text : null;
            }
        }

        private bool AlgumaRegraTravada()
        {
            foreach (Regra r in cfg.Regras) if (est.De(r.Id).Travado) return true;
            return false;
        }

        // Alterar regras/configuracoes: livre na janela de edicao e sem travas; senao, senha mestra.
        private bool PodeAlterar(string acao)
        {
            string jan;
            bool livre = cfg.EdicaoLivreAgora(DateTime.Now, out jan);
            bool trava = adulterado || est.GeralTravado || AlgumaRegraTravada();
            if (!trava && livre) return true;
            string porque = trava ? "Ha trava ativa." : jan + ".";
            if (!ConferirSenha(porque + "\r\nSenha mestra para " + acao)) return false;
            if (adulterado)
            {
                adulterado = false;
                cfg.Salvar();
                est.Salvar();
            }
            return true;
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

        private void Ciclo()
        {
            if (sairAutorizado) return;
            try { CicloInterno(); }
            catch (Exception ex) { Util.Log("ERRO no ciclo (a central continua): " + ex); }
            try { Manutencao(); }
            catch (Exception ex) { Util.Log("ERRO na manutencao: " + ex); }
        }

        // A cada 1 min: atalhos e inicio com o Windows. A cada 10 min: protecao contra exclusao e pastas ocultas.
        private void Manutencao()
        {
            DateTime agora = DateTime.Now;
            if ((agora - ultimaManutencao).TotalSeconds < 60) return;
            ultimaManutencao = agora;
            Instalacao.CriarAtalhosEInicio();
            if ((agora - ultimaProtecao).TotalMinutes >= 10)
            {
                ultimaProtecao = agora;
                AplicarProtecoes(true);
                Instalacao.OcultarPasta(Instalacao.Pasta);
                Instalacao.OcultarPasta(Util.PastaApp);
            }
        }

        private static string ArquivoMarca { get { return Path.Combine(Util.PastaCommon, "SP_Central_Ativa.txt"); } }

        private void AplicarProtecoes(bool proteger)
        {
            Util.ProtegerArquivo(Application.ExecutablePath, proteger);
            Util.ProtegerPasta(Util.PastaApp, proteger);
            Util.ProtegerArquivo(ArquivoMarca, proteger);
        }

        private void CicloInterno()
        {
            DateTime agora = DateTime.Now;
            DateTime iniDia = InicioDia(agora);

            // reset diario das travas
            bool mudou = false;
            if (est.GeralTravado && agora >= est.GeralAte)
            {
                est.GeralTravado = false; est.GeralMotivo = ""; est.ZerarFilhas = false; est.PedidoConta = "";
                mudou = true;
                Evento("Reset diario: trava geral liberada.");
            }
            foreach (Regra r in cfg.Regras)
            {
                EstadoRegra e = est.De(r.Id);
                if (e.Travado && agora >= e.TravadoAte)
                {
                    e.Travado = false; e.Motivo = ""; e.Modo = "";
                    mudou = true;
                    Evento("Reset diario: regra " + r.Conta + " / " + r.AtivoTexto + " liberada.");
                }
            }
            if (mudou) est.Salvar();

            LerStatus();
            LerPedidos(agora);

            // regras
            situacao.Clear();
            bool picoMudou = false;
            foreach (Regra r in cfg.Regras)
            {
                EstadoRegra e = est.De(r.Id);
                SituacaoRegra s = Calcular(r, e, agora, iniDia);
                situacao[r.Id] = s;
                if (!r.Ativa) continue;

                // protecao de lucro: melhor resultado do dia (fechado + aberto)
                DateTime baseR = e.Base > iniDia ? e.Base : iniDia;
                if (r.ProtecaoLigada)
                {
                    if (e.PicoBase != baseR) { e.Pico = 0; e.PicoBase = baseR; picoMudou = true; }
                    if (s.ValTotal > e.Pico + 0.005) { e.Pico = s.ValTotal; picoMudou = true; }
                }

                if (!e.Travado && !adulterado && !est.GeralTravado)
                {
                    string m = null, modo = "AGUARDAR";
                    if (r.ValorPerdido > 0 && s.ValTotal <= -r.ValorPerdido)
                    { m = string.Format(CultureInfo.InvariantCulture, "valor perdido atingido ({0:0.00})", s.ValTotal); modo = "ZERAR"; }
                    else if (r.PontosPerdidos > 0 && s.PtsTotal <= -r.PontosPerdidos)
                    { m = string.Format(CultureInfo.InvariantCulture, "pontos perdidos atingidos ({0:0} pts)", s.PtsTotal); modo = "ZERAR"; }
                    else if (r.ProtecaoLigada && e.Pico >= r.ProtQuandoAtingido && s.ValTotal <= e.Pico - r.ProtDrawdown)
                    { m = string.Format(CultureInfo.InvariantCulture, "protecao de lucro: caiu {0:0.00} do melhor resultado ({1:0.00})", e.Pico - s.ValTotal, e.Pico); modo = "ZERAR"; }
                    else if (r.ValorGanho > 0 && s.ValTotal >= r.ValorGanho)
                        m = string.Format(CultureInfo.InvariantCulture, "valor ganho atingido ({0:0.00})", s.ValTotal);
                    else if (r.PontosGanhos > 0 && s.PtsTotal >= r.PontosGanhos)
                        m = string.Format(CultureInfo.InvariantCulture, "pontos ganhos atingidos ({0:0} pts)", s.PtsTotal);
                    else if (r.MaxOperacoes > 0 && s.Ops >= r.MaxOperacoes)
                        m = string.Format("maximo de operacoes atingido ({0})", s.Ops);
                    else if (r.PerdasSeguidas > 0 && s.PerdasSeguidas >= r.PerdasSeguidas)
                        m = string.Format("{0} perdas seguidas", s.PerdasSeguidas);
                    if (m != null) TravarRegra(r, m, modo, agora);
                }
                DefinirEstadoRegra(r, e, s, agora);
            }
            if (picoMudou && (agora - ultimoSalvarPico).TotalSeconds >= 5)
            {
                ultimoSalvarPico = agora;
                est.Salvar();
            }

            VerificarDivergencia(agora);
            GravarComando();

            // navegadores: qualquer bloqueio de regra que pede para fechar, trava geral ou central alterada
            bool nav = adulterado || est.GeralTravado;
            string motNav = adulterado ? "central alterada" : (est.GeralTravado ? est.GeralMotivo : "");
            foreach (Regra r in cfg.Regras)
            {
                SituacaoRegra s;
                if (!r.Ativa || !r.FecharNavegadores || !situacao.TryGetValue(r.Id, out s) || s.Estado == 0) continue;
                if (!nav) motNav = r.Conta + "/" + r.AtivoTexto + ": " + s.Motivo;
                nav = true;
            }
            navMotivo  = motNav;
            navTitulos = Util.ListaCsv(cfg.TitulosJanelas).ToArray();
            navProcs   = Util.ListaCsv(cfg.Navegadores).ToArray();
            navAtivo   = nav;

            // plataformas: trava geral ou regra travada que pede para fechar, depois de zerar
            bool fecharPlat = false, esgotou = false;
            foreach (Regra r in cfg.Regras)
            {
                EstadoRegra e = est.De(r.Id);
                if (!r.Ativa || !e.Travado || !r.FecharPlataformas) continue;
                fecharPlat = true;
                if (e.Modo == "ZERAR" && (agora - e.TravadoEm).TotalSeconds > ESPERA_ZERAR_S) esgotou = true;
            }
            if (est.GeralTravado)
                foreach (Regra r in cfg.Regras) if (r.Ativa && r.FecharPlataformas) fecharPlat = true;
            if (fecharPlat && (TudoZerado() || esgotou) && (agora - ultimoFechamento).TotalSeconds >= 2)
            {
                ultimoFechamento = agora;
                FecharPlataformas();
            }

            if ((agora - ultimaVarreduraTerminais).TotalSeconds >= 5)
            {
                ultimaVarreduraTerminais = agora;
                VerificarTerminaisSemScalper();
            }

            ProcessarRecuperacao(agora);
            AtualizarPainel(agora, iniDia);
        }

        // Operacoes do dia, flutuante e estado de uma regra
        private SituacaoRegra Calcular(Regra r, EstadoRegra e, DateTime agora, DateTime iniDia)
        {
            SituacaoRegra s = new SituacaoRegra();
            if (!r.Ativa) { s.Motivo = "regra sem conta"; return s; }
            DateTime baseR = e.Base > iniDia ? e.Base : iniDia;
            foreach (Operacao op in OperacoesDaConta(r.Conta.Trim()))
            {
                if (op.Fechamento < baseR || !Regra.BateAtivo(r.Ativo, op.Simbolo)) continue;
                s.Ops++;
                s.PtsReal += op.Pts;
                s.ValReal += op.Valor;
                double res = op.Valor != 0 ? op.Valor : op.Pts;
                // perda soma na sequencia; ganho zera; zero a zero nao muda a sequencia
                if (res < 0) { s.PerdasSeguidas++; if (op.Fechamento > s.UltimaPerda) s.UltimaPerda = op.Fechamento; }
                else if (res > 0) s.PerdasSeguidas = 0;
            }
            foreach (StatusConta st in contas)
            {
                if (!st.Online || !r.BateConta(st.Id) || !Regra.BateAtivo(r.Ativo, st.Simbolo)) continue;
                s.ContaOnline = true;
                s.PtsFlut += st.Flutuante;
                s.ValFlut += st.FlutValor;
            }
            return s;
        }

        private void DefinirEstadoRegra(Regra r, EstadoRegra e, SituacaoRegra s, DateTime agora)
        {
            if (adulterado) { s.Estado = 1; s.Motivo = "central alterada - use a senha mestra"; return; }
            if (est.GeralTravado) { s.Estado = 1; s.Motivo = "trava geral: " + est.GeralMotivo; return; }
            if (e.Travado) { s.Estado = e.Modo == "ZERAR" ? 2 : 1; s.Motivo = e.Motivo; return; }
            if (r.UsaHorarioBloqueio && Util.DentroIntervalo(agora, r.BloqueioDe, r.BloqueioAte))
            {
                s.Estado = r.ZerarNoBloqueio ? 2 : 1;
                s.Motivo = "horario de bloqueio (" + r.BloqueioDe + " a " + r.BloqueioAte + ")";
                return;
            }
            if (r.PausaMin > 0 && s.UltimaPerda != DateTime.MinValue && agora < s.UltimaPerda.AddMinutes(r.PausaMin))
            {
                s.Estado = 1;
                s.Motivo = "pausa apos perda ate " + s.UltimaPerda.AddMinutes(r.PausaMin).ToString("HH:mm:ss");
                return;
            }
            s.Estado = 0;
            s.Motivo = "";
        }

        private void TravarRegra(Regra r, string motivo, string modo, DateTime agora)
        {
            EstadoRegra e = est.De(r.Id);
            e.Travado = true;
            e.Motivo = Util.SemAcento(motivo);
            e.Modo = modo;
            e.TravadoEm = agora;
            e.TravadoAte = InicioDia(agora).AddDays(1);
            est.Salvar();
            string msg = string.Format("TRAVADA {0} / {1}: {2}. {3} Ate {4:dd/MM HH:mm}.", r.Conta, r.AtivoTexto, e.Motivo,
                modo == "ZERAR" ? "Zerando a conta/ativo." : "Sem novas entradas; a operacao aberta termina.", e.TravadoAte);
            Evento(msg);
            try { tray.ShowBalloonTip(8000, "Central de Controle", msg, ToolTipIcon.Warning); } catch (Exception) { }
        }

        // Senha mestra: libera e a contagem recomeca agora
        private void DestravarTudo(string motivo)
        {
            DateTime agora = DateTime.Now;
            est.GeralTravado = false; est.GeralMotivo = ""; est.ZerarFilhas = false; est.PedidoConta = "";
            foreach (Regra r in cfg.Regras)
            {
                EstadoRegra e = est.De(r.Id);
                e.Travado = false; e.Motivo = ""; e.Modo = ""; e.Base = agora; e.Pico = 0; e.PicoBase = agora;
            }
            est.Salvar();
            Evento("Tudo destravado (" + motivo + "). A contagem de operacoes, pontos e valores recomeca agora.");
        }

        private void DestravarRegra(Regra r, string motivo)
        {
            DateTime agora = DateTime.Now;
            EstadoRegra e = est.De(r.Id);
            e.Travado = false; e.Motivo = ""; e.Modo = ""; e.Base = agora; e.Pico = 0; e.PicoBase = agora;
            est.Salvar();
            Evento("Regra " + r.Conta + " / " + r.AtivoTexto + " destravada (" + motivo + "). A contagem dela recomeca agora.");
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
                    s.FlutValor = c.Length >= 10 ? Util.ParseD(c[9]) : 0;
                    s.Online    = s.TickMs > 0 && (agoraTk <= s.TickMs || agoraTk - s.TickMs < STATUS_ONLINE_MS);
                    contas.Add(s);
                }
                catch (Exception) { }
            }
        }

        // SP_Central_Tr_<conta>.txt: T|posId|epochLocal|pts|simbolo|valor (relido so quando muda)
        private List<Operacao> OperacoesDaConta(string conta)
        {
            List<Operacao> l;
            string arq = Path.Combine(Util.PastaCommon, "SP_Central_Tr_" + conta + ".txt");
            DateTime data;
            try { data = File.Exists(arq) ? File.GetLastWriteTime(arq) : DateTime.MinValue; }
            catch (Exception) { data = DateTime.MinValue; }
            DateTime dCache;
            if (opsCache.TryGetValue(conta, out l) && opsCacheData.TryGetValue(conta, out dCache) && dCache == data) return l;

            l = new List<Operacao>();
            if (data != DateTime.MinValue)
            {
                HashSet<string> vistos = new HashSet<string>();
                try
                {
                    foreach (string linha in Util.LerTexto(arq).Split('\n'))
                    {
                        string[] c = linha.Trim().Split('|');
                        if (c.Length < 5 || c[0] != "T") continue;
                        if (!vistos.Add(c[1] + "|" + c[4])) continue;
                        Operacao op = new Operacao();
                        op.PosId = c[1];
                        op.Fechamento = new DateTime(1970, 1, 1).AddSeconds(Util.ParseL(c[2]));
                        op.Pts = Util.ParseD(c[3]);
                        op.Simbolo = c[4];
                        op.Valor = c.Length >= 6 ? Util.ParseD(c[5]) : 0;
                        l.Add(op);
                    }
                }
                catch (Exception) { }
            }
            opsCache[conta] = l;
            opsCacheData[conta] = data;
            return l;
        }

        private string IdMae()
        {
            if (!string.IsNullOrWhiteSpace(cfg.ContaMae)) return cfg.ContaMae.Trim();
            foreach (StatusConta s in contas)
                if (s.Online && s.Modo == "MAE") return s.Id;
            return "";
        }

        private List<string> ContasConhecidas()
        {
            List<string> l = new List<string>();
            foreach (StatusConta s in contas) if (!l.Contains(s.Id)) l.Add(s.Id);
            foreach (Regra r in cfg.Regras) if (r.Ativa && !l.Contains(r.Conta.Trim())) l.Add(r.Conta.Trim());
            foreach (string f in cfg.Filhas()) if (!l.Contains(f)) l.Add(f);
            if (cfg.ContaMae.Trim() != "" && !l.Contains(cfg.ContaMae.Trim())) l.Add(cfg.ContaMae.Trim());
            return l;
        }

        private List<string> AtivosConhecidos()
        {
            List<string> l = new List<string>();
            foreach (StatusConta s in contas) if (s.Simbolo != "" && !l.Contains(s.Simbolo)) l.Add(s.Simbolo);
            return l;
        }

        // Botao BLOCK do Scalper Pro: SP_Central_Pedido_<conta>.txt = PEDIDO|1|tickMs|TRAVAR|conta|simbolo
        // Trava TUDO ate o reset e zera as outras contas (filhas); a posicao de quem pediu segue ate fechar.
        private void LerPedidos(DateTime agora)
        {
            string[] arqs;
            try { arqs = Directory.GetFiles(Util.PastaCommon, "SP_Central_Pedido_*.txt"); }
            catch (Exception) { return; }
            ulong agoraTk = Util.GetTickCount64();
            foreach (string a in arqs)
            {
                try
                {
                    string[] c = Util.LerTexto(a).Trim().Split('|');
                    try { File.Delete(a); } catch (Exception) { }
                    if (c.Length < 5 || c[0] != "PEDIDO" || c[3] != "TRAVAR") continue;
                    ulong tk = (ulong)Util.ParseL(c[2]);
                    if (tk == 0 || (agoraTk > tk && agoraTk - tk > 60000)) continue;
                    if (!pedidosFeitos.Add(c[4] + "|" + c[2])) continue;
                    est.GeralTravado = true;
                    est.GeralMotivo = "botao BLOCK do Scalper Pro (conta " + c[4] + ")";
                    est.GeralAte = InicioDia(agora).AddDays(1);
                    est.ZerarFilhas = true;
                    est.PedidoConta = c[4];
                    est.Salvar();
                    Evento("BLOCK pedido pela conta " + c[4] + ": tudo travado ate " + est.GeralAte.ToString("dd/MM HH:mm") + "; zerando as outras contas.");
                }
                catch (Exception) { }
            }
        }

        // Filha posicionada com a mae zerada por mais de N s -> zerar so essa filha (perda de sinal do copiador)
        private void VerificarDivergencia(DateTime agora)
        {
            zerarContas.Clear();
            string idMae = IdMae();
            StatusConta mae = null;
            foreach (StatusConta s in contas)
                if (s.Id == idMae && s.Online) { if (mae == null) mae = new StatusConta { Id = idMae, Online = true }; mae.Posicoes += s.Posicoes; }

            if (est.GeralTravado && est.ZerarFilhas)
                foreach (string id in ContasConhecidas())
                    if (id != est.PedidoConta) zerarContas.Add(id + "|" + est.GeralMotivo);

            if (cfg.DivergenciaSeg <= 0 || mae == null) { divergenteDesde.Clear(); return; }
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
                        zerarContas.Add(f + "|divergencia com a conta mae");
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
                if (!File.Exists(ArquivoMarca)) Util.GravarTexto(ArquivoMarca, "SPCentral\r\n");

                bool geral = adulterado || est.GeralTravado;
                string motGeral = adulterado ? "central alterada - use a senha mestra" : (est.GeralTravado ? est.GeralMotivo : "");
                StringBuilder sb = new StringBuilder();
                sb.AppendFormat("CMD|2|{0}|{1}|{2}|{3}\r\n", Util.GetTickCount64(), geral ? "BLOQ" : "LIVRE", Util.SemAcento(motGeral),
                    est.GeralTravado ? est.GeralAte.ToString("yyyy-MM-dd HH:mm") : "");

                // zerar operacoes feitas fora do Scalper Pro / copiador / robos autorizados (DGX)
                List<string> mg = new List<string>();
                foreach (string m in Util.ListaCsv(cfg.MagicsPermitidos)) if (Util.ParseL(m) != 0 || m.Trim() == "0") mg.Add(m.Trim());
                sb.Append("F|").Append(cfg.ZerarForaDoSistema ? "1" : "0").Append('|').Append(string.Join(",", mg.ToArray())).Append("\r\n");

                if (!geral)
                    foreach (Regra r in cfg.Regras)
                    {
                        SituacaoRegra s;
                        if (!r.Ativa || !situacao.TryGetValue(r.Id, out s) || s.Estado == 0) continue;
                        sb.Append(s.Estado == 2 ? "Z|" : "B|").Append(r.Conta.Trim()).Append('|')
                          .Append(r.Ativo.Trim() == "" ? "*" : r.Ativo.Trim()).Append('|').Append(Util.SemAcento(s.Motivo)).Append("\r\n");
                    }
                foreach (string z in zerarContas)
                {
                    int p = z.IndexOf('|');
                    sb.Append("Z|").Append(z.Substring(0, p)).Append("|*|").Append(Util.SemAcento(z.Substring(p + 1))).Append("\r\n");
                }
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

        // MT5 aberto numa conta sem Scalper Pro reportando: so aviso (pode ser grafico de estudo).
        // Operacoes manuais nessa conta so sao zeradas se houver um Scalper Pro rodando nela.
        private void VerificarTerminaisSemScalper()
        {
            List<string> sem = new List<string>();
            Regex rx = new Regex(@"^\s*(\d{4,12})\s*:");
            Dictionary<uint, bool> ehMt5 = new Dictionary<uint, bool>();
            EnumWindows(delegate (IntPtr h, IntPtr l)
            {
                if (!IsWindowVisible(h)) return true;
                StringBuilder sb = new StringBuilder(512);
                GetWindowText(h, sb, sb.Capacity);
                Match m = rx.Match(sb.ToString());
                if (!m.Success) return true;
                uint pid;
                GetWindowThreadProcessId(h, out pid);
                bool mt;
                if (!ehMt5.TryGetValue(pid, out mt))
                {
                    mt = false;
                    try
                    {
                        using (Process p = Process.GetProcessById((int)pid))
                            mt = p.ProcessName.StartsWith("terminal", StringComparison.OrdinalIgnoreCase);
                    }
                    catch (Exception) { }
                    ehMt5[pid] = mt;
                }
                if (!mt) return true;
                string login = m.Groups[1].Value;
                bool coberta = false;
                foreach (StatusConta s in contas) if (s.Online && s.Id == login) coberta = true;
                if (!coberta && !sem.Contains(login)) sem.Add(login);
                return true;
            }, IntPtr.Zero);
            avisoTerminais = sem.Count == 0 ? ""
                : "MT5 aberto sem Scalper Pro na(s) conta(s) " + string.Join(", ", sem.ToArray())
                  + ": operacoes manuais nela(s) NAO sao zeradas. Abra um grafico com o Scalper Pro nessa conta.";
        }

        // --------------------------------------------------------------------
        //  Navegadores (segundo plano) e plataformas
        // --------------------------------------------------------------------
        private void LoopNavegadores()
        {
            while (true)
            {
                Thread.Sleep(2000);
                if (sairAutorizado) return;
                if (!navAtivo) { pedidoFechar.Clear(); continue; }
                try { FecharJanelasNavegador(); }
                catch (Exception ex) { Util.Log("ERRO na varredura dos navegadores: " + ex.Message); }
            }
        }

        private void EventoDaThread(string msg)
        {
            try { if (IsHandleCreated) BeginInvoke(new MethodInvoker(delegate { Evento(msg); })); else Util.Log(msg); }
            catch (Exception) { Util.Log(msg); }
        }

        // Endereco da aba ativa: a 1a caixa de texto da janela do navegador e a barra de endereco.
        private static string EnderecoNavegador(IntPtr h)
        {
            try
            {
                AutomationElement raiz = AutomationElement.FromHandle(h);
                if (raiz == null) return "";
                AutomationElement ed = raiz.FindFirst(TreeScope.Descendants,
                    new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.Edit));
                if (ed == null) return "";
                object vp;
                if (ed.TryGetCurrentPattern(ValuePattern.Pattern, out vp))
                    return ((ValuePattern)vp).Current.Value ?? "";
            }
            catch (Exception) { }
            return "";
        }

        private static bool Contem(string texto, string[] palavras)
        {
            if (string.IsNullOrEmpty(texto)) return false;
            foreach (string t in palavras)
                if (texto.IndexOf(t, StringComparison.OrdinalIgnoreCase) >= 0) return true;
            return false;
        }

        private static bool EhNavegador(uint pid, string[] navs, Dictionary<uint, bool> cache, out string nome)
        {
            nome = "?";
            bool nav;
            if (cache.TryGetValue(pid, out nav)) return nav;
            nav = false;
            try
            {
                using (Process p = Process.GetProcessById((int)pid))
                {
                    nome = p.ProcessName;
                    foreach (string n in navs)
                        if (string.Equals(p.ProcessName, n, StringComparison.OrdinalIgnoreCase)) { nav = true; break; }
                }
            }
            catch (Exception) { }
            cache[pid] = nav;
            return nav;
        }

        // Navegador com uma das palavras no TITULO ou no ENDERECO da aba ativa: fecha;
        // se nao fechar em 5 s (ex.: Edge pergunta "Fechar todas as guias?"), encerra o navegador.
        private void FecharJanelasNavegador()
        {
            string[] titulos = navTitulos;
            string[] navs = navProcs;
            if (titulos.Length == 0 || navs.Length == 0) return;

            Dictionary<uint, bool> ehNav = new Dictionary<uint, bool>();
            List<IntPtr> janelas = new List<IntPtr>();
            List<string> titulosJan = new List<string>();
            List<uint> pids = new List<uint>();
            EnumWindows(delegate (IntPtr h, IntPtr l)
            {
                if (!IsWindowVisible(h)) return true;
                StringBuilder sb = new StringBuilder(512);
                GetWindowText(h, sb, sb.Capacity);
                string titulo = sb.ToString();
                if (titulo.Length == 0) return true;
                uint pid;
                GetWindowThreadProcessId(h, out pid);
                string nome;
                if (EhNavegador(pid, navs, ehNav, out nome)) { janelas.Add(h); titulosJan.Add(titulo); pids.Add(pid); }
                return true;
            }, IntPtr.Zero);

            HashSet<IntPtr> vistas = new HashSet<IntPtr>();
            HashSet<uint> forcados = new HashSet<uint>();
            string motivo = navMotivo;
            for (int i = 0; i < janelas.Count; i++)
            {
                IntPtr hj = janelas[i];
                string onde = "";
                if (Contem(titulosJan[i], titulos)) onde = titulosJan[i];
                else
                {
                    string end = EnderecoNavegador(hj);
                    if (Contem(end, titulos)) onde = end;
                }
                if (onde == "") continue;

                vistas.Add(hj);
                DateTime pedido;
                if (!pedidoFechar.TryGetValue(hj, out pedido))
                {
                    pedidoFechar[hj] = DateTime.Now;
                    PostMessage(hj, WM_CLOSE, IntPtr.Zero, IntPtr.Zero);
                    EventoDaThread("Navegador fechado (" + motivo + "): " + onde);
                }
                else if ((DateTime.Now - pedido).TotalSeconds >= ESPERA_NAVEGADOR_S && !forcados.Contains(pids[i]))
                {
                    forcados.Add(pids[i]);
                    try
                    {
                        using (Process pk = Process.GetProcessById((int)pids[i]))
                        {
                            string nome = pk.ProcessName;
                            pk.Kill();
                            EventoDaThread("Navegador ENCERRADO porque a janela nao fechou (" + motivo + "): " + nome + " - " + onde);
                        }
                    }
                    catch (Exception ex) { Util.Log("nao consegui encerrar o navegador (pid " + pids[i] + "): " + ex.Message); }
                }
            }
            navDiag = string.Format("ultima varredura {0:HH:mm:ss}: {1} janela(s) de navegador, {2} com as palavras",
                                    DateTime.Now, janelas.Count, vistas.Count);
            List<IntPtr> velhas = new List<IntPtr>();
            foreach (IntPtr hw in pedidoFechar.Keys) if (!vistas.Contains(hw)) velhas.Add(hw);
            foreach (IntPtr hw in velhas) pedidoFechar.Remove(hw);
        }

        // Lista o que a central enxerga (titulo e endereco), SEM fechar nada.
        private void TestarNavegadores()
        {
            string[] titulos = Util.ListaCsv(cfg.TitulosJanelas).ToArray();
            string[] navs = Util.ListaCsv(cfg.Navegadores).ToArray();
            Thread t = new Thread(delegate ()
            {
                StringBuilder r = new StringBuilder();
                r.AppendLine("Central v" + Program.VERSAO + " | agora: " + (navAtivo ? "FECHANDO (" + navMotivo + ")" : "liberado"));
                r.AppendLine("Palavras: " + string.Join(", ", titulos));
                r.AppendLine("Navegadores: " + string.Join(", ", navs));
                r.AppendLine();
                int n = 0;
                Dictionary<uint, bool> cache = new Dictionary<uint, bool>();
                EnumWindows(delegate (IntPtr h, IntPtr l)
                {
                    if (!IsWindowVisible(h)) return true;
                    StringBuilder sb = new StringBuilder(512);
                    GetWindowText(h, sb, sb.Capacity);
                    string titulo = sb.ToString();
                    if (titulo.Length == 0) return true;
                    uint pid;
                    GetWindowThreadProcessId(h, out pid);
                    string proc;
                    bool nav = EhNavegador(pid, navs, cache, out proc);
                    bool noTitulo = Contem(titulo, titulos);
                    if (!nav && !noTitulo) return true;
                    string end = nav ? EnderecoNavegador(h) : "";
                    bool bate = noTitulo || Contem(end, titulos);
                    n++;
                    r.AppendLine(string.Format("[{0}] {1}", bate ? (nav ? "FECHARIA" : "nao e navegador da lista") : "ok", nav ? "navegador" : "outro programa"));
                    r.AppendLine("   titulo:   " + titulo);
                    if (nav) r.AppendLine("   endereco: " + (end == "" ? "(nao consegui ler)" : end));
                    return true;
                }, IntPtr.Zero);
                if (n == 0) r.AppendLine("Nenhuma janela de navegador encontrada.");
                string txt = r.ToString();
                Util.Log("Teste de navegadores:\r\n" + txt);
                try
                {
                    BeginInvoke(new MethodInvoker(delegate
                    {
                        Clipboard.SetText(txt);
                        MessageBox.Show(txt + "\r\n(Texto copiado: cole na conversa se precisar.)", "Testar navegadores");
                    }));
                }
                catch (Exception) { }
            });
            t.IsBackground = true;
            t.SetApartmentState(ApartmentState.STA);
            t.Start();
        }

        private void FecharPlataformas()
        {
            int mortos = 0;
            foreach (string n in Util.ListaCsv(cfg.Processos))
            {
                foreach (Process p in Process.GetProcessesByName(n))
                {
                    try { p.Kill(); mortos++; } catch (Exception) { }
                    finally { p.Dispose(); }
                }
            }
            if (mortos > 0)
                Evento(string.Format("Plataformas fechadas: {0} processo(s).", mortos));
        }

        // --------------------------------------------------------------------
        //  Recuperacao de senha: pedido agora, nova senha as 20:00 por e-mail e Telegram
        // --------------------------------------------------------------------
        private bool RecuperacaoConfigurada()
        {
            bool email = cfg.RecEmail.Trim() != "" && cfg.RecSmtpUsuario.Trim() != "" && cfg.RecSmtpSenhaCifrada != "";
            bool tg = cfg.RecTelegramTokenCifrado != "" && cfg.RecTelegramChat.Trim() != "";
            return email || tg;
        }

        // Envia por e-mail e Telegram em segundo plano; fim(ok, detalhe) roda na tela
        private void Notificar(string assunto, string texto, Action<bool, string> fim)
        {
            string para = cfg.RecEmail.Trim(), srv = cfg.RecSmtpServidor.Trim(), usu = cfg.RecSmtpUsuario.Trim();
            int porta = cfg.RecSmtpPorta;
            string sen = Util.Decifrar(cfg.RecSmtpSenhaCifrada);
            string tok = Util.Decifrar(cfg.RecTelegramTokenCifrado), chat = cfg.RecTelegramChat.Trim();
            Thread t = new Thread(delegate ()
            {
                bool algum = false;
                StringBuilder det = new StringBuilder();
                if (para != "" && usu != "" && sen != "")
                {
                    try { Util.EnviarEmail(srv, porta, usu, sen, para, assunto, texto); algum = true; det.Append("e-mail ok; "); }
                    catch (Exception ex) { det.Append("e-mail FALHOU: " + ex.Message + "; "); }
                }
                if (tok != "" && chat != "")
                {
                    try { Util.EnviarTelegram(tok, chat, assunto + "\n" + texto); algum = true; det.Append("Telegram ok"); }
                    catch (Exception ex) { det.Append("Telegram FALHOU: " + ex.Message); }
                }
                if (det.Length == 0) det.Append("nenhum contato configurado");
                string d = det.ToString();
                try { BeginInvoke(new MethodInvoker(delegate { if (fim != null) fim(algum, d); })); }
                catch (Exception) { Util.Log("notificacao: " + d); }
            });
            t.IsBackground = true;
            t.Start();
        }

        private void PedirRecuperacao()
        {
            if (!RecuperacaoConfigurada())
            {
                MessageBox.Show("Cadastre antes um e-mail ou o Telegram na aba Recuperacao de senha.", "Central de Controle");
                return;
            }
            DateTime agora = DateTime.Now;
            if (est.RecEntregaEm.Ticks > 0)
            {
                MessageBox.Show("Ja existe um pedido: a nova senha sera enviada as " + est.RecEntregaEm.ToString("HH:mm 'de' dd/MM") + ".", "Central de Controle");
                return;
            }
            TimeSpan h;
            if (!Util.ParseHora(cfg.RecHora, out h)) h = TimeSpan.FromHours(20);
            DateTime entrega = agora.Date + h;
            if (agora >= entrega) entrega = entrega.AddDays(1);   // pedido depois das 20h: no dia seguinte
            if (MessageBox.Show("Pedir uma nova senha mestra?\r\n\r\nUma senha TEMPORARIA sera enviada por e-mail e Telegram as "
                    + entrega.ToString("HH:mm 'de' dd/MM") + ". A senha atual deixa de valer nesse momento.",
                    "Central de Controle", MessageBoxButtons.YesNo, MessageBoxIcon.Question) != DialogResult.Yes) return;
            est.RecPedidoEm = agora;
            est.RecEntregaEm = entrega;
            est.Salvar();
            Evento("Recuperacao de senha pedida. Nova senha sera enviada as " + entrega.ToString("dd/MM HH:mm") + ".");
            Notificar("Central de Controle: pedido de recuperacao de senha",
                "Foi pedida a recuperacao da senha mestra em " + agora.ToString("dd/MM/yyyy HH:mm") + ". "
                + "Uma senha temporaria sera enviada as " + entrega.ToString("HH:mm 'de' dd/MM") + ". "
                + "Se nao foi voce, cancele o pedido na central (aba Recuperacao de senha) com a senha mestra.",
                delegate (bool ok, string det) { Evento("Aviso do pedido de recuperacao: " + det); });
            AtualizarRecStatus();
        }

        private void ProcessarRecuperacao(DateTime agora)
        {
            if (est.RecEntregaEm.Ticks == 0 || agora < est.RecEntregaEm || recEnviando) return;
            if ((agora - recUltTentativa).TotalMinutes < 5) return;
            recUltTentativa = agora;
            recEnviando = true;
            string temp = Util.SenhaTemporaria();
            Notificar("Central de Controle: nova senha mestra",
                "Nova senha mestra TEMPORARIA: " + temp + "\r\n\r\nUse-a na central e troque por uma nova na aba Senha mestra > Trocar senha mestra.",
                delegate (bool ok, string det)
                {
                    recEnviando = false;
                    if (!ok)
                    {
                        Evento("Recuperacao de senha: envio FALHOU (" + det + "). Nova tentativa em 5 minutos. A senha atual continua valendo.");
                        return;
                    }
                    GravarSenha(temp);   // so troca depois que pelo menos um envio deu certo
                    est.RecPedidoEm = new DateTime(0);
                    est.RecEntregaEm = new DateTime(0);
                    est.Salvar();
                    Evento("Recuperacao de senha: nova senha temporaria enviada (" + det + ").");
                    AtualizarRecStatus();
                });
        }

        private void CancelarRecuperacao()
        {
            if (est.RecEntregaEm.Ticks == 0) { MessageBox.Show("Nao ha pedido de recuperacao.", "Central de Controle"); return; }
            if (!ConferirSenha("Senha mestra para CANCELAR o pedido de recuperacao")) return;
            est.RecPedidoEm = new DateTime(0);
            est.RecEntregaEm = new DateTime(0);
            est.Salvar();
            Evento("Pedido de recuperacao de senha cancelado.");
            AtualizarRecStatus();
        }

        // --------------------------------------------------------------------
        //  Saida, desinstalacao
        // --------------------------------------------------------------------
        public void MostrarJanela()
        {
            Show();
            ShowInTaskbar = true;
            WindowState = FormWindowState.Normal;
            Activate();
            BringToFront();
        }

        private void Evento(string msg)
        {
            Util.Log(msg);
            if (lbEventos == null) return;
            lbEventos.Items.Insert(0, DateTime.Now.ToString("dd/MM HH:mm:ss") + "  " + msg);
            while (lbEventos.Items.Count > 300) lbEventos.Items.RemoveAt(lbEventos.Items.Count - 1);
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

        private void Desinstalar()
        {
            if (!ConferirSenha("Senha mestra para DESINSTALAR a central")) return;
            DialogResult dr = MessageBox.Show(
                "Desinstalar a Central de Controle?\r\n\r\n" +
                "Os EAs passam a operar SEM a central (sem regras, sem bloqueios).\r\n\r\n" +
                "Apagar tambem as regras, configuracoes e a senha mestra?\r\n" +
                "   Sim = apaga tudo\r\n" +
                "   Nao = guarda para a proxima instalacao\r\n" +
                "   Cancelar = nao desinstala",
                "Central de Controle", MessageBoxButtons.YesNoCancel, MessageBoxIcon.Warning);
            if (dr == DialogResult.Cancel) return;
            bool apagar = dr == DialogResult.Yes;

            sairAutorizado = true;
            timer.Stop();
            Evento("Central DESINSTALADA com a senha mestra" + (apagar ? " (configuracoes apagadas)." : " (configuracoes guardadas)."));
            AplicarProtecoes(false);
            Instalacao.RemoverAtalhosEInicio();
            try { if (File.Exists(ArquivoMarca)) File.Delete(ArquivoMarca); } catch (Exception ex) { Util.Log("marca: " + ex.Message); }
            try { File.Delete(Path.Combine(Util.PastaCommon, "SP_Central_Cmd.txt")); } catch (Exception) { }
            try
            {
                if (apagar) Registry.CurrentUser.DeleteSubKeyTree(Util.RegChave, false);
                else
                    using (RegistryKey rk = Registry.CurrentUser.OpenSubKey(Util.RegChave, true))
                    {
                        if (rk != null) { rk.DeleteValue("Instalado", false); rk.DeleteValue("Versao", false); rk.DeleteValue("Exe", false); }
                    }
            }
            catch (Exception) { }
            if (apagar)
            {
                try
                {
                    DirectoryInfo di = new DirectoryInfo(Util.PastaApp);
                    di.Attributes = FileAttributes.Normal;
                    Directory.Delete(Util.PastaApp, true);
                }
                catch (Exception) { }
            }
            Instalacao.AgendarRemocaoDaPasta();
            MessageBox.Show("Central desinstalada. Para instalar outra versao, rode o novo SPCentral.exe.", "Central de Controle");
            tray.Visible = false;
            Application.Exit();
        }

        protected override void OnFormClosing(FormClosingEventArgs e)
        {
            if (!sairAutorizado && e.CloseReason == CloseReason.UserClosing)
            {
                e.Cancel = true;     // fechar a janela so minimiza: a central fica na barra de tarefas
                WindowState = FormWindowState.Minimized;
                try { tray.ShowBalloonTip(3000, "Central de Controle", "A central continua ativa (minimizada na barra de tarefas).", ToolTipIcon.Info); }
                catch (Exception) { }
                return;
            }
            tray.Visible = false;
            base.OnFormClosing(e);
        }
    }

    // ------------------------------------------------------------------------
    //  Janela principal: telas
    // ------------------------------------------------------------------------
    internal partial class FormCentral
    {
        private static readonly Font FonteTitulo = new Font("Segoe UI", 10f, FontStyle.Bold);
        private static readonly Font FonteCampo  = new Font("Segoe UI", 9.5f);
        private static readonly Font FonteDica   = new Font("Segoe UI", 8.5f);
        private const string SEGREDO_GUARDADO = "(guardado)";

        // Painel
        private Label lblEstado, lblMotivo, lblNav, lblAvisos, lblEdicaoRegras, lblEdicaoGeral, lblRecStatus;
        private ListView lvSituacao, lvContas, lvRegras;
        private ListBox lbEventos;
        // Geral
        private DateTimePicker dtReset, dtEdDe, dtEdAte, dtRecHora;
        private CheckBox ckZerarFora;
        private TextBox txMagics, txContaMae, txFilhas, txTitulos, txNavs, txProc;
        private NumericUpDown nuDiv;
        // Recuperacao
        private TextBox txRecEmail, txSmtpSrv, txSmtpUsu, txSmtpSenha, txTgToken, txTgChat;
        private NumericUpDown nuSmtpPorta;

        private void MontarUI()
        {
            TabControl tabs = new TabControl { Dock = DockStyle.Fill, Font = FonteCampo, Padding = new Point(14, 6) };
            Controls.Add(tabs);

            // ================= Painel =================
            TabPage tp = new TabPage("  Painel  ");
            tabs.TabPages.Add(tp);
            lblEstado = new Label { Left = 16, Top = 10, Width = 640, Height = 40, Font = new Font("Segoe UI", 18f, FontStyle.Bold) };
            lblMotivo = new Label { Left = 16, Top = 52, Width = 900, Height = 22, Font = new Font("Segoe UI", 10f) };
            Button btTeste = new Button { Text = "Testar navegadores", Left = 760, Top = 12, Width = 180, Height = 30 };
            btTeste.Click += delegate { TestarNavegadores(); };
            Button btDestravarSel = new Button { Text = "Destravar regra (senha)", Left = 760, Top = 46, Width = 180, Height = 30 };
            btDestravarSel.Click += delegate { DestravarSelecionada(); };
            Label l1 = new Label { Text = "Situacao de cada regra (conta / ativo)", Left = 16, Top = 82, Width = 500, Font = FonteTitulo };
            lvSituacao = Lista(16, 104, 924, 190, new[] { "Conta", "Ativo", "Situacao", "Operacoes", "Pontos (fechado / aberto)", "Valor (fechado / aberto)", "Protecao de lucro" },
                                                  new[] { 120, 70, 290, 75, 150, 150, 130 });
            lblNav = new Label { Left = 16, Top = 298, Width = 924, Height = 20, Font = FonteDica };
            lblAvisos = new Label { Left = 16, Top = 318, Width = 924, Height = 36, ForeColor = Color.Firebrick, Font = FonteCampo };
            Label l2 = new Label { Text = "Contas conectadas", Left = 16, Top = 356, Width = 300, Font = FonteTitulo };
            lvContas = Lista(16, 378, 924, 120, new[] { "Conta", "Papel", "Ativo", "Online", "Posicoes", "Aberto (pts)", "Aberto (valor)" },
                                                new[] { 190, 80, 160, 70, 80, 120, 120 });
            Label l3 = new Label { Text = "Eventos", Left = 16, Top = 504, Width = 300, Font = FonteTitulo };
            lbEventos = new ListBox { Left = 16, Top = 526, Width = 924, Height = 170, HorizontalScrollbar = true, Font = FonteDica };
            tp.Controls.AddRange(new Control[] { lblEstado, lblMotivo, btTeste, btDestravarSel, l1, lvSituacao, lblNav, lblAvisos, l2, lvContas, l3, lbEventos });
            btTeste.BringToFront();
            btDestravarSel.BringToFront();

            // ================= Regras =================
            TabPage tr = new TabPage("  Regras por conta e ativo  ");
            tabs.TabPages.Add(tr);
            lblEdicaoRegras = new Label { Left = 16, Top = 10, Width = 924, Height = 22, Font = FonteTitulo };
            Label ex = new Label
            {
                Left = 16, Top = 34, Width = 924, Height = 40, ForeColor = Color.DimGray,
                Text = "Cada regra vale para uma conta (login do MT5 ou NT-<conta>) e um ativo (ou * = todos os ativos da conta). " +
                       "Regras sem conta ficam desligadas. Clique duas vezes numa regra para editar."
            };
            lvRegras = Lista(16, 78, 924, 520, new[] { "Conta", "Ativo", "Horario de bloqueio", "Bloqueios do dia", "Protecao de lucro", "Ao bloquear" },
                                               new[] { 130, 80, 150, 290, 160, 110 });
            lvRegras.DoubleClick += delegate { EditarSelecionada(); };
            Button btNova = Botao("Nova regra", 16, 608, 150);
            Button btEditar = Botao("Editar", 176, 608, 120);
            Button btDuplicar = Botao("Duplicar", 306, 608, 120);
            Button btExcluir = Botao("Excluir", 436, 608, 120);
            btNova.Font = FonteTitulo;
            btNova.Click += delegate { NovaRegra(); };
            btEditar.Click += delegate { EditarSelecionada(); };
            btDuplicar.Click += delegate { DuplicarSelecionada(); };
            btExcluir.Click += delegate { ExcluirSelecionada(); };
            tr.Controls.AddRange(new Control[] { lblEdicaoRegras, ex, lvRegras, btNova, btEditar, btDuplicar, btExcluir });

            // ================= Geral =================
            TabPage tg = new TabPage("  Geral  ");
            tabs.TabPages.Add(tg);
            tg.AutoScroll = true;
            int y = 10, gy;
            lblEdicaoGeral = new Label { Left = 16, Top = y, Width = 900, Height = 22, Font = FonteTitulo };
            tg.Controls.Add(lblEdicaoGeral);
            y += 30;

            GroupBox gH = Bloco(tg, "Horarios", y, out gy);
            dtReset = CampoHora(gH, "Reset diario das travas e da contagem", ref gy, "Ex.: 06:00. Uma trava dura ate o proximo reset.");
            dtEdDe  = CampoHora(gH, "Edicao das regras LIVRE (sem senha) das", ref gy, "Ex.: 08:00. Fora desse horario, alterar pede a senha mestra.");
            dtEdAte = CampoHora(gH, "... ate as (inicio do pregao)", ref gy, "Ex.: 11:30 para o Nasdaq.");
            y = FecharBloco(gH, gy);

            GroupBox gF = Bloco(tg, "Operacoes feitas fora do Scalper Pro", y, out gy);
            ckZerarFora = CampoCheck(gF, "Zerar na hora qualquer operacao que nao venha do Scalper Pro, do copiador ou dos robos autorizados abaixo", ref gy);
            txMagics = CampoTexto(gF, "Robos autorizados (numeros magicos, ex.: DGX)", ref gy,
                "Separe por virgula. O numero magico aparece na aba Historico do MT5 (coluna ID/Magic) ou nas configuracoes do robo. 0 = libera operacoes manuais.");
            Dica(gF, ref gy, "Vale em qualquer ativo da conta, inclusive grafico de estudo, celular e web. Precisa de um Scalper Pro v6.09+ rodando na conta.");
            y = FecharBloco(gF, gy);

            GroupBox gC = Bloco(tg, "Copiador (mae e filhas)", y, out gy);
            txContaMae = CampoTexto(gC, "Conta mae", ref gy, "Login MT5 da mae. Vazio = o Scalper Pro em modo Mae.");
            txFilhas   = CampoTexto(gC, "Contas filhas (separadas por virgula)", ref gy, "Ex.: 1514567645, NT-APEX2209540000056.");
            nuDiv      = CampoNumero(gC, "Zerar filha divergente apos (s, 0 = nao)", ref gy, 0, 3600, "Filha posicionada com a mae zerada por mais desse tempo.");
            y = FecharBloco(gC, gy);

            GroupBox gN = Bloco(tg, "Navegadores e plataformas", y, out gy);
            txTitulos = CampoTexto(gN, "Palavras (titulo ou endereco do navegador)", ref gy, "Ex.: TradingView, Tradovate, Apex, NinjaTrader");
            txNavs    = CampoTexto(gN, "Navegadores (processos)", ref gy, "chrome, msedge (Edge), firefox, opera, brave, vivaldi");
            txProc    = CampoTexto(gN, "Plataformas a fechar ao travar (processos)", ref gy, "terminal64 = MT5; NinjaTrader; TradingView = app desktop");
            y = FecharBloco(gN, gy);

            Button btSalvarG = Botao("Salvar", 16, y + 4, 160);
            btSalvarG.Font = FonteTitulo;
            btSalvarG.Click += delegate { SalvarGeral(); };
            tg.Controls.Add(btSalvarG);
            tg.Controls.Add(new Label { Left = 16, Top = y + 44, Width = 10, Height = 10 });

            // ================= Recuperacao de senha =================
            TabPage tq = new TabPage("  Recuperacao de senha  ");
            tabs.TabPages.Add(tq);
            tq.AutoScroll = true;
            y = 10;
            Label exq = new Label
            {
                Left = 16, Top = y, Width = 900, Height = 54, ForeColor = Color.DimGray,
                Text = "Esqueceu a senha mestra? Clique em 'Esqueci a senha'. Um aviso sai na hora e uma senha TEMPORARIA e enviada " +
                       "por e-mail e Telegram no horario de entrega (20:00 do dia do pedido; pedido depois das 20:00 = no dia seguinte). " +
                       "Alterar os contatos sempre pede a senha mestra."
            };
            tq.Controls.Add(exq);
            y += 60;
            GroupBox gE = Bloco(tq, "E-mail", y, out gy);
            txRecEmail  = CampoTexto(gE, "Enviar para (e-mail)", ref gy, "Quem recebe a nova senha.");
            txSmtpSrv   = CampoTexto(gE, "Servidor de envio (SMTP)", ref gy, "Gmail: smtp.gmail.com");
            nuSmtpPorta = CampoNumero(gE, "Porta", ref gy, 1, 65535, "Gmail: 587");
            txSmtpUsu   = CampoTexto(gE, "Conta que envia (e-mail)", ref gy, "Ex.: um Gmail so para isso.");
            txSmtpSenha = CampoTexto(gE, "Senha de app dessa conta", ref gy, "Gmail: Conta Google > Seguranca > Senhas de app (exige verificacao em duas etapas).");
            txSmtpSenha.UseSystemPasswordChar = true;
            y = FecharBloco(gE, gy);

            GroupBox gT = Bloco(tq, "Telegram", y, out gy);
            txTgToken = CampoTexto(gT, "Token do bot", ref gy, "Crie o bot com o @BotFather no Telegram e copie o token.");
            txTgToken.UseSystemPasswordChar = true;
            txTgChat  = CampoTexto(gT, "Chat ID", ref gy, "Mande uma mensagem ao seu bot e veja o ID em https://api.telegram.org/bot<TOKEN>/getUpdates (campo chat > id).");
            y = FecharBloco(gT, gy);

            GroupBox gR = Bloco(tq, "Entrega", y, out gy);
            dtRecHora = CampoHora(gR, "Horario de entrega da nova senha", ref gy, "Padrao: 20:00");
            y = FecharBloco(gR, gy);

            Button btSalvarRec = Botao("Salvar contatos (senha)", 16, y + 4, 200);
            btSalvarRec.Click += delegate { SalvarRecuperacao(); };
            Button btTesteEmail = Botao("Testar e-mail", 226, y + 4, 140);
            btTesteEmail.Click += delegate { TestarContato(true); };
            Button btTesteTg = Botao("Testar Telegram", 376, y + 4, 140);
            btTesteTg.Click += delegate { TestarContato(false); };
            y += 48;
            lblRecStatus = new Label { Left = 16, Top = y, Width = 900, Height = 22, Font = FonteTitulo };
            Button btEsqueci = Botao("Esqueci a senha", 16, y + 28, 200);
            btEsqueci.ForeColor = Color.Firebrick;
            btEsqueci.Click += delegate { PedirRecuperacao(); };
            Button btCancRec = Botao("Cancelar pedido (senha)", 226, y + 28, 200);
            btCancRec.Click += delegate { CancelarRecuperacao(); };
            tq.Controls.AddRange(new Control[] { btSalvarRec, btTesteEmail, btTesteTg, lblRecStatus, btEsqueci, btCancRec,
                                                 new Label { Left = 16, Top = y + 70, Width = 10, Height = 10 } });

            // ================= Senha mestra =================
            TabPage ts = new TabPage("  Senha mestra  ");
            tabs.TabPages.Add(ts);
            Label exs = new Label
            {
                Left = 16, Top = 16, Width = 900, Height = 70, ForeColor = Color.DimGray,
                Text = "A senha mestra deve ficar com outra pessoa. Ela destrava a central antes do reset, libera alteracoes fora do horario de edicao, " +
                       "fecha e desinstala a central. Ao destravar, a contagem de operacoes, pontos e valores recomeca do zero."
            };
            Button btDestravar = Botao("Destravar tudo", 16, 96, 200);
            btDestravar.Click += delegate
            {
                if (!est.GeralTravado && !AlgumaRegraTravada() && !adulterado) { MessageBox.Show("Nao ha nada travado."); return; }
                if (!ConferirSenha("Senha mestra para destravar TUDO")) return;
                if (adulterado) { adulterado = false; cfg.Salvar(); }
                DestravarTudo("senha mestra");
            };
            Button btTrocar = Botao("Trocar senha mestra", 226, 96, 200);
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
            Button btSair = Botao("Fechar a central", 436, 96, 200);
            btSair.Click += delegate { SairComSenha(); };
            Label exd = new Label
            {
                Left = 16, Top = 150, Width = 900, Height = 70, ForeColor = Color.DimGray,
                Text = "A central fica instalada numa pasta oculta, com protecao contra exclusao, atalho na Area de Trabalho e icone perto do relogio. " +
                       "Para instalar outra versao (ou de novo), e preciso DESINSTALAR esta primeiro: o instalador recusa enquanto houver uma central instalada."
            };
            Button btDesinstalar = Botao("Desinstalar", 16, 226, 200);
            btDesinstalar.ForeColor = Color.Firebrick;
            btDesinstalar.Click += delegate { Desinstalar(); };
            ts.Controls.AddRange(new Control[] { exs, btDestravar, btTrocar, btSair, exd, btDesinstalar });
        }

        // ---- componentes ----
        private static ListView Lista(int x, int y, int w, int h, string[] colunas, int[] larguras)
        {
            ListView lv = new ListView { Left = x, Top = y, Width = w, Height = h, View = View.Details, FullRowSelect = true,
                                         GridLines = true, HideSelection = false, MultiSelect = false, Font = FonteCampo };
            for (int i = 0; i < colunas.Length; i++) lv.Columns.Add(colunas[i], larguras[i]);
            return lv;
        }

        private static Button Botao(string texto, int x, int y, int w)
        {
            return new Button { Text = texto, Left = x, Top = y, Width = w, Height = 34, Font = FonteCampo };
        }

        private static GroupBox Bloco(Control pai, string titulo, int y, out int gy)
        {
            GroupBox g = new GroupBox { Text = titulo, Left = 12, Top = y, Width = 900, Font = FonteTitulo };
            pai.Controls.Add(g);
            gy = 26;
            return g;
        }

        private static int FecharBloco(GroupBox g, int gy)
        {
            g.Height = gy + 6;
            return g.Top + g.Height + 10;
        }

        private static Label Rotulo(Control pai, string texto, int y)
        {
            Label l = new Label { Text = texto, Left = 12, Top = y + 4, Width = 330, Font = FonteCampo };
            pai.Controls.Add(l);
            return l;
        }

        private static void Dica(Control pai, ref int y, string texto)
        {
            Label d = new Label { Text = texto, Left = 12, Top = y, Width = 870, Height = 20, ForeColor = Color.DimGray, Font = FonteDica };
            pai.Controls.Add(d);
            y += 22;
        }

        private static TextBox CampoTexto(Control pai, string rotulo, ref int y, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            TextBox t = new TextBox { Left = 345, Top = y, Width = 530, Font = FonteCampo };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(t, dica);
            tt.SetToolTip(l, dica);
            pai.Controls.Add(t);
            y += 30;
            Dica(pai, ref y, dica);
            return t;
        }

        private static NumericUpDown CampoNumero(Control pai, string rotulo, ref int y, decimal min, decimal max, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            NumericUpDown n = new NumericUpDown { Left = 345, Top = y, Width = 120, Minimum = min, Maximum = max, Font = FonteCampo };
            Label d = new Label { Text = dica, Left = 475, Top = y + 4, Width = 410, Height = 20, ForeColor = Color.DimGray, Font = FonteDica, AutoEllipsis = true };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(n, dica);
            tt.SetToolTip(l, dica);
            tt.SetToolTip(d, dica);
            pai.Controls.Add(n);
            pai.Controls.Add(d);
            y += 32;
            return n;
        }

        private static DateTimePicker CampoHora(Control pai, string rotulo, ref int y, string dica)
        {
            Label l = Rotulo(pai, rotulo, y);
            DateTimePicker d = new DateTimePicker
            {
                Left = 345, Top = y, Width = 90, Format = DateTimePickerFormat.Custom, CustomFormat = "HH:mm",
                ShowUpDown = true, Font = FonteCampo
            };
            Label dd = new Label { Text = dica, Left = 445, Top = y + 4, Width = 440, Height = 20, ForeColor = Color.DimGray, Font = FonteDica, AutoEllipsis = true };
            ToolTip tt = new ToolTip();
            tt.SetToolTip(d, dica);
            tt.SetToolTip(l, dica);
            pai.Controls.Add(d);
            pai.Controls.Add(dd);
            y += 32;
            return d;
        }

        private static CheckBox CampoCheck(Control pai, string rotulo, ref int y)
        {
            CheckBox c = new CheckBox { Text = rotulo, Left = 12, Top = y, Width = 870, Height = 26, Font = FonteCampo };
            pai.Controls.Add(c);
            y += 30;
            return c;
        }

        private static void PorHora(DateTimePicker d, string hora)
        {
            TimeSpan t;
            d.Value = DateTime.Today + (Util.ParseHora(hora, out t) ? t : TimeSpan.Zero);
        }

        private static string LerHora(DateTimePicker d)
        {
            return d.Value.ToString("HH:mm", CultureInfo.InvariantCulture);
        }

        // ---- Geral ----
        private void CarregarCamposGeral()
        {
            PorHora(dtReset, cfg.HoraReset);
            PorHora(dtEdDe, cfg.EdicaoDe);
            PorHora(dtEdAte, cfg.EdicaoAte);
            ckZerarFora.Checked = cfg.ZerarForaDoSistema;
            txMagics.Text = cfg.MagicsPermitidos;
            txContaMae.Text = cfg.ContaMae;
            txFilhas.Text = cfg.ContasFilhas;
            nuDiv.Value = Math.Max(nuDiv.Minimum, Math.Min(nuDiv.Maximum, cfg.DivergenciaSeg));
            txTitulos.Text = cfg.TitulosJanelas;
            txNavs.Text = cfg.Navegadores;
            txProc.Text = cfg.Processos;
        }

        private void SalvarGeral()
        {
            if (!PodeAlterar("salvar as configuracoes gerais")) { CarregarCamposGeral(); return; }
            cfg.HoraReset = LerHora(dtReset);
            cfg.EdicaoDe = LerHora(dtEdDe);
            cfg.EdicaoAte = LerHora(dtEdAte);
            cfg.ZerarForaDoSistema = ckZerarFora.Checked;
            cfg.MagicsPermitidos = txMagics.Text.Trim();
            cfg.ContaMae = txContaMae.Text.Trim();
            cfg.ContasFilhas = txFilhas.Text.Trim();
            cfg.DivergenciaSeg = (int)nuDiv.Value;
            cfg.TitulosJanelas = txTitulos.Text.Trim();
            cfg.Navegadores = txNavs.Text.Trim();
            cfg.Processos = txProc.Text.Trim();
            cfg.Salvar();
            Evento("Configuracoes gerais salvas: reset " + cfg.HoraReset + ", edicao livre " + cfg.EdicaoDe + "-" + cfg.EdicaoAte
                   + ", zerar fora do sistema " + (cfg.ZerarForaDoSistema ? "SIM" : "nao") + " (robos: " + (cfg.MagicsPermitidos == "" ? "-" : cfg.MagicsPermitidos) + ").");
            MessageBox.Show("Configuracoes salvas.", "Central de Controle");
        }

        // ---- Recuperacao ----
        private void CarregarCamposRecuperacao()
        {
            txRecEmail.Text = cfg.RecEmail;
            txSmtpSrv.Text = cfg.RecSmtpServidor;
            nuSmtpPorta.Value = Math.Max(1, Math.Min(65535, cfg.RecSmtpPorta));
            txSmtpUsu.Text = cfg.RecSmtpUsuario;
            txSmtpSenha.Text = cfg.RecSmtpSenhaCifrada != "" ? SEGREDO_GUARDADO : "";
            txTgToken.Text = cfg.RecTelegramTokenCifrado != "" ? SEGREDO_GUARDADO : "";
            txTgChat.Text = cfg.RecTelegramChat;
            PorHora(dtRecHora, cfg.RecHora);
            AtualizarRecStatus();
        }

        private void SalvarRecuperacao()
        {
            if (!ConferirSenha("Senha mestra para alterar os contatos de recuperacao")) { CarregarCamposRecuperacao(); return; }
            cfg.RecEmail = txRecEmail.Text.Trim();
            cfg.RecSmtpServidor = txSmtpSrv.Text.Trim();
            cfg.RecSmtpPorta = (int)nuSmtpPorta.Value;
            cfg.RecSmtpUsuario = txSmtpUsu.Text.Trim();
            if (txSmtpSenha.Text != SEGREDO_GUARDADO) cfg.RecSmtpSenhaCifrada = Util.Cifrar(txSmtpSenha.Text);
            if (txTgToken.Text != SEGREDO_GUARDADO) cfg.RecTelegramTokenCifrado = Util.Cifrar(txTgToken.Text.Trim());
            cfg.RecTelegramChat = txTgChat.Text.Trim();
            cfg.RecHora = LerHora(dtRecHora);
            cfg.Salvar();
            CarregarCamposRecuperacao();
            Evento("Contatos de recuperacao de senha salvos (e-mail: " + (cfg.RecEmail == "" ? "-" : cfg.RecEmail)
                   + ", Telegram: " + (cfg.RecTelegramChat == "" ? "-" : "chat " + cfg.RecTelegramChat) + ", entrega " + cfg.RecHora + ").");
            MessageBox.Show("Contatos salvos. Use 'Testar e-mail' e 'Testar Telegram' para conferir.", "Central de Controle");
        }

        // Testa com o que esta salvo (salve antes de testar)
        private void TestarContato(bool email)
        {
            string para = cfg.RecEmail.Trim(), srv = cfg.RecSmtpServidor.Trim(), usu = cfg.RecSmtpUsuario.Trim();
            int porta = cfg.RecSmtpPorta;
            string sen = Util.Decifrar(cfg.RecSmtpSenhaCifrada);
            string tok = Util.Decifrar(cfg.RecTelegramTokenCifrado), chat = cfg.RecTelegramChat.Trim();
            if (email && (para == "" || usu == "" || sen == "")) { MessageBox.Show("Preencha e SALVE o e-mail antes de testar."); return; }
            if (!email && (tok == "" || chat == "")) { MessageBox.Show("Preencha e SALVE o Telegram antes de testar."); return; }
            Thread t = new Thread(delegate ()
            {
                string res;
                try
                {
                    if (email) Util.EnviarEmail(srv, porta, usu, sen, para, "Central de Controle: teste", "Teste de envio da Central de Controle. Se chegou, a recuperacao de senha por e-mail funciona.");
                    else Util.EnviarTelegram(tok, chat, "Central de Controle: teste. Se chegou, a recuperacao de senha pelo Telegram funciona.");
                    res = (email ? "E-mail" : "Telegram") + ": enviado. Confira se chegou.";
                }
                catch (Exception ex) { res = (email ? "E-mail" : "Telegram") + ": FALHOU - " + ex.Message; }
                try { BeginInvoke(new MethodInvoker(delegate { Evento("Teste de " + res); MessageBox.Show(res, "Central de Controle"); })); }
                catch (Exception) { }
            });
            t.IsBackground = true;
            t.Start();
        }

        private void AtualizarRecStatus()
        {
            if (lblRecStatus == null) return;
            if (est.RecEntregaEm.Ticks > 0)
            {
                lblRecStatus.Text = "Pedido de recuperacao feito em " + est.RecPedidoEm.ToString("dd/MM HH:mm")
                                  + ". Nova senha sera enviada as " + est.RecEntregaEm.ToString("HH:mm 'de' dd/MM") + ".";
                lblRecStatus.ForeColor = Color.DarkOrange;
            }
            else
            {
                lblRecStatus.Text = RecuperacaoConfigurada() ? "Sem pedido de recuperacao." : "Recuperacao NAO configurada: preencha e-mail ou Telegram.";
                lblRecStatus.ForeColor = RecuperacaoConfigurada() ? Color.SeaGreen : Color.Firebrick;
            }
        }

        // ---- Regras ----
        private void AtualizarListaRegras()
        {
            lvRegras.BeginUpdate();
            int sel = lvRegras.SelectedIndices.Count > 0 ? lvRegras.SelectedIndices[0] : -1;
            lvRegras.Items.Clear();
            foreach (Regra r in cfg.Regras)
            {
                List<string> ao = new List<string>();
                if (r.FecharNavegadores) ao.Add("navegadores");
                if (r.FecharPlataformas) ao.Add("plataformas");
                ListViewItem it = new ListViewItem(new[]
                {
                    r.Ativa ? r.Conta : "(sem conta)", r.AtivoTexto, r.ResumoHorario(), r.ResumoLimites(), r.ResumoProtecao(),
                    ao.Count == 0 ? "-" : "fecha " + string.Join(" e ", ao.ToArray())
                });
                it.Tag = r.Id;
                if (!r.Ativa) it.ForeColor = Color.Gray;
                lvRegras.Items.Add(it);
            }
            if (sel >= 0 && sel < lvRegras.Items.Count) lvRegras.Items[sel].Selected = true;
            lvRegras.EndUpdate();
        }

        private Regra RegraSelecionada(ListView lv)
        {
            if (lv.SelectedItems.Count == 0) return null;
            object tag = lv.SelectedItems[0].Tag;
            return tag is int ? cfg.RegraPorId((int)tag) : null;
        }

        private void NovaRegra()
        {
            if (!PodeAlterar("criar uma regra")) return;
            Regra r = new Regra();
            FormRegra f = new FormRegra(r, ContasConhecidas(), AtivosConhecidos());
            if (f.ShowDialog(this) != DialogResult.OK) return;
            Regra n = f.Resultado;
            n.Id = cfg.ProximoId++;
            cfg.Regras.Add(n);
            cfg.Salvar();
            Evento("Regra criada: " + n.Conta + " / " + n.AtivoTexto + " | bloqueio " + n.ResumoHorario() + " | " + n.ResumoLimites() + " | protecao " + n.ResumoProtecao());
            AtualizarListaRegras();
        }

        private void EditarSelecionada()
        {
            Regra r = RegraSelecionada(lvRegras);
            if (r == null) { MessageBox.Show("Selecione uma regra na lista."); return; }
            if (!PodeAlterar("alterar a regra " + r.Conta + " / " + r.AtivoTexto)) return;
            FormRegra f = new FormRegra(r, ContasConhecidas(), AtivosConhecidos());
            if (f.ShowDialog(this) != DialogResult.OK) return;
            int i = cfg.Regras.IndexOf(r);
            if (i < 0) return;
            cfg.Regras[i] = f.Resultado;
            cfg.Salvar();
            Evento("Regra alterada: " + f.Resultado.Conta + " / " + f.Resultado.AtivoTexto + " | bloqueio " + f.Resultado.ResumoHorario()
                   + " | " + f.Resultado.ResumoLimites() + " | protecao " + f.Resultado.ResumoProtecao());
            AtualizarListaRegras();
        }

        private void DuplicarSelecionada()
        {
            Regra r = RegraSelecionada(lvRegras);
            if (r == null) { MessageBox.Show("Selecione uma regra na lista."); return; }
            if (!PodeAlterar("duplicar a regra")) return;
            Regra c = r.Copia();
            c.Conta = "";
            FormRegra f = new FormRegra(c, ContasConhecidas(), AtivosConhecidos());
            if (f.ShowDialog(this) != DialogResult.OK) return;
            Regra n = f.Resultado;
            n.Id = cfg.ProximoId++;
            cfg.Regras.Add(n);
            cfg.Salvar();
            Evento("Regra criada (copia): " + n.Conta + " / " + n.AtivoTexto);
            AtualizarListaRegras();
        }

        private void ExcluirSelecionada()
        {
            Regra r = RegraSelecionada(lvRegras);
            if (r == null) { MessageBox.Show("Selecione uma regra na lista."); return; }
            if (!PodeAlterar("excluir a regra " + r.Conta + " / " + r.AtivoTexto)) return;
            if (MessageBox.Show("Excluir a regra " + r.Conta + " / " + r.AtivoTexto + "?", "Central de Controle", MessageBoxButtons.YesNo) != DialogResult.Yes) return;
            cfg.Regras.Remove(r);
            est.Regras.Remove(r.Id);
            cfg.Salvar();
            est.Salvar();
            Evento("Regra excluida: " + r.Conta + " / " + r.AtivoTexto);
            AtualizarListaRegras();
        }

        private void DestravarSelecionada()
        {
            Regra r = RegraSelecionada(lvSituacao);
            if (r == null) { MessageBox.Show("Selecione uma regra na lista 'Situacao de cada regra'."); return; }
            if (!est.De(r.Id).Travado) { MessageBox.Show("Esta regra nao esta travada."); return; }
            if (!ConferirSenha("Senha mestra para destravar " + r.Conta + " / " + r.AtivoTexto)) return;
            DestravarRegra(r, "senha mestra");
        }

        // ---- Painel ----
        private void AtualizarPainel(DateTime agora, DateTime iniDia)
        {
            int bloqueadas = 0;
            foreach (Regra r in cfg.Regras)
            {
                SituacaoRegra s;
                if (r.Ativa && situacao.TryGetValue(r.Id, out s) && s.Estado > 0) bloqueadas++;
            }
            if (adulterado)
            {
                lblEstado.Text = "BLOQUEADA - central alterada";
                lblEstado.ForeColor = Color.Firebrick;
                lblMotivo.Text = "Configuracao ou estado alterado fora da central. Destrave com a senha mestra.";
            }
            else if (est.GeralTravado)
            {
                lblEstado.Text = "TRAVA GERAL";
                lblEstado.ForeColor = Color.Firebrick;
                lblMotivo.Text = est.GeralMotivo + " | ate " + est.GeralAte.ToString("dd/MM HH:mm");
            }
            else if (bloqueadas > 0)
            {
                lblEstado.Text = bloqueadas + (bloqueadas == 1 ? " REGRA BLOQUEADA" : " REGRAS BLOQUEADAS");
                lblEstado.ForeColor = Color.DarkOrange;
                lblMotivo.Text = "Veja a situacao de cada regra abaixo. Dia desde " + iniDia.ToString("dd/MM HH:mm") + ".";
            }
            else
            {
                lblEstado.Text = cfg.Regras.Count == 0 ? "SEM REGRAS" : "TUDO LIBERADO";
                lblEstado.ForeColor = cfg.Regras.Count == 0 ? Color.Gray : Color.SeaGreen;
                lblMotivo.Text = cfg.Regras.Count == 0 ? "Cadastre as regras na aba 'Regras por conta e ativo'." : "Operando dentro do plano. Dia desde " + iniDia.ToString("dd/MM HH:mm") + ".";
            }

            // situacao das regras
            int sel = lvSituacao.SelectedIndices.Count > 0 ? lvSituacao.SelectedIndices[0] : -1;
            lvSituacao.BeginUpdate();
            lvSituacao.Items.Clear();
            foreach (Regra r in cfg.Regras)
            {
                SituacaoRegra s;
                if (!situacao.TryGetValue(r.Id, out s)) s = new SituacaoRegra();
                EstadoRegra e = est.De(r.Id);
                string sit = !r.Ativa ? "desligada (sem conta)"
                           : s.Estado == 0 ? (s.ContaOnline ? "LIVRE" : "LIVRE (conta offline)")
                           : (s.Estado == 2 ? "ZERANDO: " : "BLOQUEADA: ") + s.Motivo;
                string prot = !r.ProtecaoLigada ? "-"
                            : e.Pico >= r.ProtQuandoAtingido ? string.Format(CultureInfo.InvariantCulture, "ATIVA: trava em {0:0.00}", e.Pico - r.ProtDrawdown)
                            : string.Format(CultureInfo.InvariantCulture, "melhor {0:0.00} / ativa em {1:0.00}", e.Pico, r.ProtQuandoAtingido);
                ListViewItem it = new ListViewItem(new[]
                {
                    r.Ativa ? r.Conta : "-", r.AtivoTexto, sit,
                    s.Ops + (r.MaxOperacoes > 0 ? " / " + r.MaxOperacoes : ""),
                    string.Format(CultureInfo.InvariantCulture, "{0:0} / {1:0}", s.PtsReal, s.PtsFlut),
                    string.Format(CultureInfo.InvariantCulture, "{0:0.00} / {1:0.00}", s.ValReal, s.ValFlut),
                    prot
                });
                it.Tag = r.Id;
                it.ForeColor = !r.Ativa ? Color.Gray : (s.Estado == 0 ? Color.SeaGreen : (s.Estado == 2 ? Color.Firebrick : Color.DarkOrange));
                lvSituacao.Items.Add(it);
            }
            if (sel >= 0 && sel < lvSituacao.Items.Count) lvSituacao.Items[sel].Selected = true;
            lvSituacao.EndUpdate();

            lblNav.Text = navAtivo ? "Navegadores: FECHANDO (" + navMotivo + ") | " + navDiag : "Navegadores: liberados";
            lblNav.ForeColor = navAtivo ? Color.Firebrick : Color.SeaGreen;
            List<string> av = new List<string>();
            if (avisoTerminais != "") av.Add(avisoTerminais);
            if (est.RecEntregaEm.Ticks > 0) av.Add("Recuperacao de senha pedida: nova senha as " + est.RecEntregaEm.ToString("HH:mm 'de' dd/MM") + ".");
            if (!cfg.ZerarForaDoSistema) av.Add("Atencao: 'zerar operacoes fora do Scalper Pro' esta DESLIGADO (aba Geral).");
            lblAvisos.Text = string.Join("  |  ", av.ToArray());

            string jan;
            bool livre = cfg.EdicaoLivreAgora(agora, out jan);
            bool trava = adulterado || est.GeralTravado || AlgumaRegraTravada();
            string txEd = trava ? "Ha trava ativa: alteracoes so com a senha mestra." : jan;
            lblEdicaoRegras.Text = txEd;
            lblEdicaoGeral.Text = txEd;
            lblEdicaoRegras.ForeColor = lblEdicaoGeral.ForeColor = (livre && !trava) ? Color.SeaGreen : Color.Firebrick;

            // contas
            string idMae = IdMae();
            List<string> filhas = cfg.Filhas();
            lvContas.BeginUpdate();
            lvContas.Items.Clear();
            foreach (StatusConta s in contas)
            {
                string papel = s.Id == idMae ? "MAE" : (filhas.Contains(s.Id) || s.Modo == "FILHA" ? "filha" : s.Modo);
                ListViewItem it = new ListViewItem(new[]
                {
                    s.Id, papel, s.Simbolo, s.Online ? "sim" : "nao", s.Posicoes.ToString(),
                    s.Flutuante.ToString("0", CultureInfo.InvariantCulture), s.FlutValor.ToString("0.00", CultureInfo.InvariantCulture)
                });
                if (!s.Online) it.ForeColor = Color.Gray;
                lvContas.Items.Add(it);
            }
            lvContas.EndUpdate();

            string tt = adulterado ? "Central: ALTERADA" : (est.GeralTravado ? "Central: TRAVA GERAL" : "Central: " + lblEstado.Text);
            tray.Text = tt.Length > 63 ? tt.Substring(0, 63) : tt;
        }
    }
}
