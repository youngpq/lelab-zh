@echo off
chcp 65001 >nul
title LeLab-zh 启动
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"

if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" goto :start
echo [错误] LeLab-zh 未安装或安装不完整。
echo        请先运行「一键安装」。
pause
exit /b 1

:start
echo [启动] 正在启动 LeLab-zh...
echo [提示] 如果浏览器没有自动打开，请手动访问：http://127.0.0.1:8000
echo.
"%INSTALL_DIR%\venv\Scripts\lelab-zh.exe"
exit /b %errorlevel%
