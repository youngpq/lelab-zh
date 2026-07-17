@echo off
chcp 65001 >nul
title LeLab-zh 修复安装
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"
set "BACKUP_DIR=%INSTALL_DIR%\venv.backup"

if exist "%INSTALL_DIR%\wheels" goto :repair
echo [错误] 本地修复文件不存在，请重新运行「一键安装」。
pause
exit /b 1

:repair
echo ============================================================
echo   LeLab-zh 修复安装
echo ============================================================
echo.
echo [修复] 正在停止 LeLab-zh...
if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop

echo [修复] 备份旧环境...
if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" 2>nul
if exist "%INSTALL_DIR%\venv" move "%INSTALL_DIR%\venv" "%BACKUP_DIR%"

echo [修复] 重建虚拟环境...
"%INSTALL_DIR%\uv\uv.exe" venv "%INSTALL_DIR%\venv" --python "%INSTALL_DIR%\runtime\python.exe"
if errorlevel 1 goto :restore_after_venv_failure

echo [修复] 重新安装依赖...
"%INSTALL_DIR%\uv\uv.exe" pip install ^
  --python "%INSTALL_DIR%\venv\Scripts\python.exe" ^
  --offline ^
  --no-index ^
  --find-links "%INSTALL_DIR%\wheels" ^
  --require-hashes ^
  -r "%INSTALL_DIR%\requirements-offline.txt"
if errorlevel 1 goto :restore_after_pip_failure

if exist "%BACKUP_DIR%" rmdir /s /q "%BACKUP_DIR%" 2>nul
echo.
echo ============================================================
echo   修复安装完成。
echo ============================================================
echo.
pause
exit /b 0

:restore_after_venv_failure
echo [错误] 创建虚拟环境失败。正在恢复旧环境...
if exist "%BACKUP_DIR%" move "%BACKUP_DIR%" "%INSTALL_DIR%\venv"
echo [恢复] 已恢复旧环境。
pause
exit /b 1

:restore_after_pip_failure
echo [错误] 依赖安装失败。正在恢复旧环境...
if exist "%INSTALL_DIR%\venv" rmdir /s /q "%INSTALL_DIR%\venv" 2>nul
if exist "%BACKUP_DIR%" move "%BACKUP_DIR%" "%INSTALL_DIR%\venv"
echo [恢复] 已恢复旧环境。
pause
exit /b 1
