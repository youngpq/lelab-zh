@echo off
chcp 65001 >nul
title LeLab-zh 停止
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"
set "LOCATION_FILE=%LOCALAPPDATA%\LeLab-zh-install-dir.txt"
if not exist "%LOCATION_FILE%" goto :location_ready
set /p "SAVED_INSTALL_DIR="<"%LOCATION_FILE%"
if not defined SAVED_INSTALL_DIR goto :location_ready
set "INSTALL_DIR=%SAVED_INSTALL_DIR%"

:location_ready

if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" goto :stop
echo [错误] LeLab-zh 未安装。
pause
exit /b 1

:stop
echo [停止] 正在停止 LeLab-zh...
"%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop
if errorlevel 1 goto :stop_warning
echo [完成] LeLab-zh 已停止。
pause
exit /b 0

:stop_warning
echo [警告] 停止命令返回非零退出码。
pause
exit /b 1
