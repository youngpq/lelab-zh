@echo off
chcp 65001 >nul
title LeLab-zh 一键安装
set "PACKAGE_ROOT=%~dp0"
if "%PACKAGE_ROOT:~-1%"=="\" set "PACKAGE_ROOT=%PACKAGE_ROOT:~0,-1%"
set "INSTALL_DIR=%LOCALAPPDATA%\LeLab-zh"

echo ============================================================
echo   LeLab-zh 离线安装程序
echo ============================================================
echo.

if "%PROCESSOR_ARCHITECTURE%"=="AMD64" goto :check_space
if "%PROCESSOR_ARCHITEW6432%"=="AMD64" goto :check_space
echo [错误] 此安装包仅支持 Windows 64 位系统。
pause
exit /b 1

:check_space
powershell -NoProfile -Command "$drive=($env:LOCALAPPDATA).Substring(0,1); if ((Get-PSDrive -Name $drive).Free -lt 30GB) { exit 1 }"
if errorlevel 1 goto :space_fail
echo [检查] 磁盘空间检查通过

if not exist "%PACKAGE_ROOT%\wheels\" goto :package_incomplete
if not exist "%PACKAGE_ROOT%\runtime\" goto :package_incomplete
if not exist "%PACKAGE_ROOT%\uv\" goto :package_incomplete
if not exist "%PACKAGE_ROOT%\requirements-offline.txt" goto :package_incomplete
echo [检查] 安装文件完整性: 通过

nvidia-smi >nul 2>&1
if errorlevel 1 goto :no_nvidia
echo [信息] 检测到 NVIDIA 显卡，将启用 CUDA 加速。
goto :verify_hash

:no_nvidia
echo [警告] 未检测到 NVIDIA 显卡或驱动。
echo        将以 CPU 模式运行，安装包体积较大，训练会很慢。
choice /c YN /m "是否继续安装？"
if errorlevel 2 goto :cancel

:verify_hash
if not exist "%PACKAGE_ROOT%\SHA256SUMS.txt" goto :copy_runtime
echo [信息] 正在校验文件完整性...
powershell -NoProfile -ExecutionPolicy Bypass -Command "$root=$env:PACKAGE_ROOT; $ok=$true; Get-Content -Encoding UTF8 -LiteralPath (Join-Path $root 'SHA256SUMS.txt') | ForEach-Object { $parts=$_ -split '  ',2; if ($parts.Count -ne 2) { $ok=$false } else { $file=Join-Path $root $parts[1]; if (-not (Test-Path -LiteralPath $file)) { $ok=$false } elseif ((Get-FileHash -LiteralPath $file -Algorithm SHA256).Hash.ToLower() -ne $parts[0].ToLower()) { $ok=$false } } }; if (-not $ok) { exit 1 }"
if errorlevel 1 goto :hash_fail
echo [信息] 校验完成。

:copy_runtime
if exist "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe" --stop >nul 2>&1
mkdir "%INSTALL_DIR%" 2>nul
echo [安装] 正在复制运行时文件...
if exist "%INSTALL_DIR%\runtime" rmdir /s /q "%INSTALL_DIR%\runtime"
if exist "%INSTALL_DIR%\uv" rmdir /s /q "%INSTALL_DIR%\uv"
if exist "%INSTALL_DIR%\wheels" rmdir /s /q "%INSTALL_DIR%\wheels"
xcopy "%PACKAGE_ROOT%\runtime" "%INSTALL_DIR%\runtime\" /E /Y /Q >nul
xcopy "%PACKAGE_ROOT%\uv" "%INSTALL_DIR%\uv\" /E /Y /Q >nul
xcopy "%PACKAGE_ROOT%\wheels" "%INSTALL_DIR%\wheels\" /E /Y /Q >nul
copy /Y "%PACKAGE_ROOT%\requirements-offline.txt" "%INSTALL_DIR%\requirements-offline.txt" >nul
if not exist "%INSTALL_DIR%\runtime\python.exe" goto :copy_fail

echo [安装] 正在创建虚拟环境...
"%INSTALL_DIR%\uv\uv.exe" venv "%INSTALL_DIR%\venv" --python "%INSTALL_DIR%\runtime\python.exe"
if errorlevel 1 goto :venv_fail

echo [安装] 正在从本地安装依赖（此过程可能需要几分钟）...
"%INSTALL_DIR%\uv\uv.exe" pip install ^
  --python "%INSTALL_DIR%\venv\Scripts\python.exe" ^
  --offline ^
  --no-index ^
  --find-links "%INSTALL_DIR%\wheels" ^
  --require-hashes ^
  -r "%INSTALL_DIR%\requirements-offline.txt"
if errorlevel 1 goto :pip_fail

for /f "usebackq delims=" %%D in (`powershell -NoProfile -Command "[Environment]::GetFolderPath('Desktop')"`) do set "DESKTOP=%%D"
set "SHORTCUT=%DESKTOP%\Start LeLab.vbs"
(
echo Set WshShell = CreateObject("WScript.Shell"^)
echo Set oLink = WshShell.CreateShortcut("%DESKTOP%\Start LeLab.lnk"^)
echo oLink.TargetPath = "%INSTALL_DIR%\venv\Scripts\lelab-zh.exe"
echo oLink.WorkingDirectory = "%INSTALL_DIR%"
echo oLink.Description = "LeLab-zh"
echo oLink.Save
) > "%SHORTCUT%"
cscript //nologo "%SHORTCUT%"
del "%SHORTCUT%" 2>nul
echo v0.1.0 > "%INSTALL_DIR%\version.txt"
echo.
echo ============================================================
echo   LeLab-zh 已安装到电脑本地。
echo ============================================================
echo   现在可删除压缩包和解压文件夹，再从桌面的 Start LeLab 启动。
pause
exit /b 0

:space_fail
echo [错误] 安装盘可用空间不足 30GB，请清理空间后重试。
pause
exit /b 1

:package_incomplete
echo [错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。
pause
exit /b 1

:hash_fail
echo [错误] 安装包校验失败，请重新复制并完整解压安装包。
pause
exit /b 1

:copy_fail
echo [错误] 运行时文件复制失败。
pause
exit /b 1

:venv_fail
echo [错误] 创建虚拟环境失败。
pause
exit /b 1

:pip_fail
echo [错误] 依赖安装失败。请检查安装包是否完整。
pause
exit /b 1

:cancel
echo 安装已取消。
pause
exit /b 0
