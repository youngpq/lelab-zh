@echo off
setlocal
chcp 65001 >nul
REM 用 %SystemRoot% 定位 PowerShell，不依赖 PATH
set "PS_EXE=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
if not exist "%PS_EXE%" (
    for /f "delims=" %%i in ('where powershell.exe 2^>nul') do set "PS_EXE=%%i" & goto :found
    if exist "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe" set "PS_EXE=C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
)
:found
if not exist "%PS_EXE%" (
    echo [错误] 未找到 Windows PowerShell，无法运行此脚本。
    pause
    exit /b 1
)
"%PS_EXE%" -NoProfile -ExecutionPolicy Bypass -File "%~dp0lelab_windows.ps1" -Action stop
exit /b %ERRORLEVEL%
