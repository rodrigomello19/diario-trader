@echo off
rem Compila a Central de Controle com o compilador C# que ja vem no Windows (.NET Framework 4.x)
set CSC=%WINDIR%\Microsoft.NET\Framework64\v4.0.30319\csc.exe
if not exist "%CSC%" set CSC=%WINDIR%\Microsoft.NET\Framework\v4.0.30319\csc.exe
if not exist "%CSC%" (
  echo Compilador do .NET Framework 4 nao encontrado.
  pause
  exit /b 1
)
"%CSC%" /nologo /target:winexe /optimize+ /out:"%~dp0SPCentral.exe" /r:System.dll /r:System.Core.dll /r:System.Drawing.dll /r:System.Windows.Forms.dll "%~dp0SPCentral.cs"
if errorlevel 1 (
  echo.
  echo ERRO na compilacao. Envie as mensagens acima para correcao.
  pause
  exit /b 1
)
echo.
echo OK: SPCentral.exe gerado em %~dp0
pause
