@echo off
rem Compila a Central de Controle com o compilador C# que ja vem no Windows (.NET Framework 4.x)
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo Compilador do .NET Framework 4 nao encontrado.
  pause
  exit /b 1
)
rem O SPCentral.exe desta pasta e o INSTALADOR. Se ele estiver aberto (central v1.x rodando daqui),
rem o compilador nao consegue substitui-lo.
if not exist "%~dp0SPCentral.exe" goto compilar
2>nul (call ) >>"%~dp0SPCentral.exe"
if errorlevel 1 (
  echo O SPCentral.exe desta pasta esta EM USO ^(central antiga rodando daqui^).
  echo Feche-a primeiro: aba Senha mestra ^> Fechar a central.
  pause
  exit /b 1
)
:compilar
echo Compilando %~dp0SPCentral.cs
findstr /C:"VERSAO = " "%~dp0SPCentral.cs"
rem a leitura do endereco do navegador usa a Automacao da Interface do Windows (pasta WPF do .NET)
for %%I in ("%CSC%") do set NETDIR=%%~dpI
"%CSC%" /nologo /target:winexe /optimize+ /out:"%~dp0SPCentral.exe" /lib:"%NETDIR%WPF" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll /r:System.Security.dll /r:UIAutomationClient.dll /r:UIAutomationTypes.dll /r:WindowsBase.dll "%~dp0SPCentral.cs"
if errorlevel 1 (
  echo.
  echo ERRO na compilacao. Envie as mensagens acima para correcao.
  pause
  exit /b 1
)
echo.
echo OK: SPCentral.exe gerado em %~dp0
echo Este SPCentral.exe e o INSTALADOR: de dois cliques nele para instalar.
echo Se ja houver uma central instalada, desinstale antes (aba Senha mestra ^> Desinstalar).
pause
