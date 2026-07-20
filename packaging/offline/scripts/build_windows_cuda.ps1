# LeLab-zh Windows CUDA 离线包构建脚本
# 必须在 Windows x64 机器上运行，需要：Git + LFS + uv + PowerShell + >=50GB 磁盘

$ErrorActionPreference = "Stop"

# ============================================================
# 配置
# ============================================================
$VERSION = "0.1.0"
$APP_VERSION = "0.1.0.post1"
$TAG = "v$VERSION-zh.1"
$LEROBOT_VERSION = "0.6.0"
$LEROBOT_GIT = "https://github.com/huggingface/lerobot.git"
$PYTORCH_CUDA_INDEX = "https://download.pytorch.org/whl/cu128"
$PYTHON_VERSION = "3.12"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
$PROJECT_ROOT = Split-Path -Parent $PROJECT_ROOT
$PROJECT_ROOT = Split-Path -Parent $PROJECT_ROOT
$BUILD_DIR = Join-Path $PROJECT_ROOT "build\windows-cuda"
$DIST_DIR = Join-Path $PROJECT_ROOT "dist\offline\LeLab-zh-Windows-CUDA-$TAG"
$WHEELS_DIR = Join-Path $DIST_DIR "wheels"
$RUNTIME_DIR = Join-Path $DIST_DIR "runtime"
$UV_DIR = Join-Path $DIST_DIR "uv"
$SCRIPTS_SRC = Join-Path $PROJECT_ROOT "packaging\offline\scripts"
$LOCKS_DIR = Join-Path $PROJECT_ROOT "packaging\offline\locks"

Write-Host "============================================================" -ForegroundColor Cyan
Write-Host "  LeLab-zh Windows CUDA 离线包构建" -ForegroundColor Cyan
Write-Host "============================================================" -ForegroundColor Cyan
Write-Host ""

# ============================================================
# 1. 清理并创建目录
# ============================================================
if (Test-Path $BUILD_DIR) { Remove-Item -Recurse -Force $BUILD_DIR }
if (Test-Path $DIST_DIR) { Remove-Item -Recurse -Force $DIST_DIR }
New-Item -ItemType Directory -Force -Path $WHEELS_DIR | Out-Null
New-Item -ItemType Directory -Force -Path $BUILD_DIR | Out-Null

# ============================================================
# 2. Checkout LeLab-zh（含 LFS）
# ============================================================
Write-Host "[构建] Checkout LeLab-zh 源码..." -ForegroundColor Yellow
$LAB_SRC = Join-Path $BUILD_DIR "lelab-zh"
# Force a non-local clone so staging edits cannot modify the source checkout through hardlinks.
$PROJECT_URI = "file:///" + ((Resolve-Path $PROJECT_ROOT).Path -replace '\\', '/')
$clone = Start-Process -FilePath "git" -ArgumentList @("clone", "--no-local", "--depth", "1", "--branch", "main", $PROJECT_URI, $LAB_SRC) -NoNewWindow -Wait -PassThru
if ($clone.ExitCode -ne 0) {
    throw "无法创建 LeLab-zh 构建副本"
}
Push-Location $LAB_SRC
git lfs install 2>$null
if ($env:LELAB_SKIP_LFS -ne "1") {
    git lfs pull 2>$null
    if ($LASTEXITCODE -ne 0) { throw "Git LFS 资源拉取失败" }
}
Pop-Location

# Keep the calibration tutorial video inside the built frontend so the
# offline package does not depend on the remote Hugging Face URL.
$VIDEO_SOURCE = Join-Path $LAB_SRC "frontend\public\videos\calibrate_so101_2.mp4"
$VIDEO_DEST = Join-Path $LAB_SRC "frontend\dist\videos\calibrate_so101_2.mp4"
if (-not (Test-Path -LiteralPath $VIDEO_SOURCE)) { throw "校准视频缺失：$VIDEO_SOURCE" }
New-Item -ItemType Directory -Force -Path (Split-Path -Parent $VIDEO_DEST) | Out-Null
Copy-Item -LiteralPath $VIDEO_SOURCE -Destination $VIDEO_DEST -Force
$REMOTE_VIDEO_URL = "https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/lerobot/calibrate_so101_2.mp4"
$FRONTEND_JS = Get-ChildItem -LiteralPath (Join-Path $LAB_SRC "frontend\dist\assets") -Filter "*.js" -File -ErrorAction SilentlyContinue
if (-not $FRONTEND_JS -or -not (Select-String -LiteralPath $FRONTEND_JS.FullName -SimpleMatch "/videos/calibrate_so101_2.mp4" -Quiet)) { throw "frontend/dist 未引用本地校准视频路径" }
if (Select-String -LiteralPath $FRONTEND_JS.FullName -SimpleMatch $REMOTE_VIDEO_URL -Quiet) { throw "frontend/dist 仍引用远程校准视频 URL" }
Write-Host "[构建] 已将校准视频加入 frontend/dist" -ForegroundColor Green

# ============================================================
# 3. Clone 并构建 LeRobot wheel
# ============================================================
Write-Host "[构建] Clone LeRobot v$LEROBOT_VERSION..." -ForegroundColor Yellow
$LEROBOT_SRC = Join-Path $BUILD_DIR "lerobot"
$LEROBOT_WHEEL_OVERRIDE = $env:LELAB_LEROBOT_WHEEL
if ($LEROBOT_WHEEL_OVERRIDE -and (Test-Path $LEROBOT_WHEEL_OVERRIDE)) {
    Copy-Item $LEROBOT_WHEEL_OVERRIDE $WHEELS_DIR
    Write-Host "[构建] 使用已构建 lerobot wheel: $([System.IO.Path]::GetFileName($LEROBOT_WHEEL_OVERRIDE))" -ForegroundColor Green
} else {
    if (Test-Path $LEROBOT_SRC) { Remove-Item -Recurse -Force $LEROBOT_SRC }
    git clone --depth 1 --branch "v$LEROBOT_VERSION" $LEROBOT_GIT $LEROBOT_SRC

    Write-Host "[构建] 构建 lerobot wheel..." -ForegroundColor Yellow
    Push-Location $LEROBOT_SRC
    uv build --wheel
    $LEROBOT_WHEEL = Get-ChildItem dist\*.whl | Select-Object -First 1
    Copy-Item $LEROBOT_WHEEL.FullName $WHEELS_DIR
    Write-Host "[构建] lerobot wheel: $($LEROBOT_WHEEL.Name)" -ForegroundColor Green
    Pop-Location
}

# ============================================================
# 4. 构建 lelab-zh wheel（临时 staging pyproject.toml）
# ============================================================
Write-Host "[构建] 构建 lelab-zh wheel..." -ForegroundColor Yellow
Push-Location $LAB_SRC
if ((Resolve-Path (Get-Location).Path).Path -ne (Resolve-Path $LAB_SRC).Path) {
    throw "无法进入 LeLab-zh 构建目录：$LAB_SRC"
}

# 创建 staging pyproject.toml：逐行替换 lerobot Git 依赖，避免正则跨行匹配或换行差异导致替换失效。
$STAGING_PYPROJECT = Join-Path $LAB_SRC "pyproject.toml"
$STAGING_BACKUP = Join-Path $LAB_SRC "pyproject.toml.bak"
$PYPROJECT_LINES = Get-Content -LiteralPath $STAGING_PYPROJECT -Encoding UTF8
$LEROBOT_REPLACED = $false
$PYPROJECT_LINES = $PYPROJECT_LINES | ForEach-Object {
    if (-not $LEROBOT_REPLACED -and $_ -match '^\s*"lerobot\[core_scripts,feetech,training\]\s*@\s*git\+') {
        $LEROBOT_REPLACED = $true
        '    "lerobot[core_scripts,feetech,training]==' + $LEROBOT_VERSION + '",'
    } else {
        $_
    }
}
if (-not $LEROBOT_REPLACED) {
    throw "未能将 lelab-zh 的 lerobot Git 依赖替换为本地 wheel 版本"
}
$PYPROJECT = $PYPROJECT_LINES -join "`n"
# uv build 只读 pyproject.toml，必须临时替换
Copy-Item -LiteralPath $STAGING_PYPROJECT -Destination $STAGING_BACKUP -Force
[System.IO.File]::WriteAllText($STAGING_PYPROJECT, $PYPROJECT, (New-Object System.Text.UTF8Encoding($false)))

# 用替换后的 pyproject.toml 构建
$env:SETUPTOOLS_SCM_PRETEND_VERSION = $APP_VERSION
$LELAB_WHEEL = $null
try {
    if (-not (Select-String -LiteralPath $STAGING_PYPROJECT -SimpleMatch "lerobot[core_scripts,feetech,training]==$LEROBOT_VERSION" -Quiet)) {
        throw "staging pyproject.toml 未写入锁定的 lerobot 版本"
    }
    # setuptools 会复用已有 egg-info 中的依赖元数据；必须清除它，
    # 否则 staging 的 lerobot 替换不会反映到最终 wheel 的 METADATA。
    Remove-Item (Join-Path $LAB_SRC "lelab_zh.egg-info") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $LAB_SRC "build") -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item (Join-Path $LAB_SRC "dist") -Recurse -Force -ErrorAction SilentlyContinue
    uv build --wheel --no-cache
    $LELAB_WHEEL = Get-ChildItem (Join-Path $LAB_SRC "dist\lelab_zh-$APP_VERSION-*.whl") | Select-Object -First 1
} finally {
    if (Test-Path -LiteralPath $STAGING_BACKUP) {
        Copy-Item -LiteralPath $STAGING_BACKUP -Destination $STAGING_PYPROJECT -Force
        Remove-Item -LiteralPath $STAGING_BACKUP -Force
    }
}

if (-not $LELAB_WHEEL) { throw "未生成 lelab-zh wheel" }
Copy-Item $LELAB_WHEEL.FullName $WHEELS_DIR
Write-Host "[构建] lelab-zh wheel: $($LELAB_WHEEL.Name)" -ForegroundColor Green

# 检查 wheel METADATA 不残留 git URL
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ZIP = [System.IO.Compression.ZipFile]::OpenRead($LELAB_WHEEL.FullName)
$META = $ZIP.Entries | Where-Object { $_.FullName -like "*/METADATA" } | Select-Object -First 1
if (-not $META) { throw "lelab-zh wheel 缺少 METADATA" }
if ($META) {
    $STREAM = $META.Open()
    $READER = New-Object System.IO.StreamReader($STREAM)
    $CONTENT = $READER.ReadToEnd()
    $READER.Close()
    $STREAM.Close()
    $DEPENDENCY_METADATA = $CONTENT -split "`r?`n" | Where-Object { $_ -like "Requires-Dist:*" }
    if ($DEPENDENCY_METADATA -match "git\+" -or $DEPENDENCY_METADATA -match "github\.com/huggingface/lerobot") {
        throw "wheel METADATA 中残留 git URL"
    }
}
$ZIP.Dispose()

Pop-Location

# ============================================================
# 5. 下载便携 uv 二进制
# ============================================================
Write-Host "[构建] 下载便携 uv..." -ForegroundColor Yellow
$UV_URL = "https://astral.sh/uv/0.11.29/install.ps1"
$UV_OVERRIDE = $env:LELAB_UV_BINARY
if ($UV_OVERRIDE -and (Test-Path $UV_OVERRIDE)) {
    New-Item -ItemType Directory -Force -Path $UV_DIR | Out-Null
    Copy-Item $UV_OVERRIDE (Join-Path $UV_DIR "uv.exe") -Force
} else {
    Invoke-WebRequest -Uri "https://github.com/astral-sh/uv/releases/download/0.11.29/uv-x86_64-pc-windows-msvc.zip" -OutFile (Join-Path $BUILD_DIR "uv.zip")
    $UV_EXTRACT_DIR = Join-Path $BUILD_DIR "uv-extracted"
    Expand-Archive -Path (Join-Path $BUILD_DIR "uv.zip") -DestinationPath $UV_EXTRACT_DIR -Force
    $UV_EXE = Get-ChildItem $UV_EXTRACT_DIR -Recurse -Filter "uv.exe" | Select-Object -First 1
    if (-not $UV_EXE) { throw "下载的 uv 压缩包中没有 uv.exe" }
    New-Item -ItemType Directory -Force -Path $UV_DIR | Out-Null
    Copy-Item $UV_EXE.FullName (Join-Path $UV_DIR "uv.exe") -Force
    Remove-Item $UV_EXTRACT_DIR -Recurse -Force
    Remove-Item (Join-Path $BUILD_DIR "uv.zip") -Force
}

# ============================================================
# 6. 安装便携 Python 3.12
# ============================================================
Write-Host "[构建] 安装便携 Python..." -ForegroundColor Yellow
uv python install $PYTHON_VERSION --install-dir $RUNTIME_DIR
$RUNTIME_PYTHON = (Get-ChildItem $RUNTIME_DIR -Recurse -Filter "python.exe" | Select-Object -First 1).FullName
if (-not $RUNTIME_PYTHON) { throw "未找到便携 Python 可执行文件" }
$PYTHON_HOME = Split-Path -Parent $RUNTIME_PYTHON
if ($PYTHON_HOME -ne $RUNTIME_DIR) {
    Copy-Item (Join-Path $PYTHON_HOME "*") $RUNTIME_DIR -Recurse -Force
    $RUNTIME_PYTHON = Join-Path $RUNTIME_DIR "python.exe"
    Remove-Item $PYTHON_HOME -Recurse -Force
}
# uv 会创建指向版本目录的别名 junction；扁平化后必须删除，避免压缩时出现失效链接。
Get-ChildItem $RUNTIME_DIR -Force | Where-Object { $_.Attributes -band [System.IO.FileAttributes]::ReparsePoint } | Remove-Item -Force
if (Test-Path (Join-Path $RUNTIME_DIR ".temp")) { Remove-Item (Join-Path $RUNTIME_DIR ".temp") -Recurse -Force }

# ============================================================
# 7. 下载所有依赖 wheel
# ============================================================
# uv 0.11+ 已移除 uv pip download，改用 pip download
Write-Host "[构建] 下载第三方依赖 wheel..." -ForegroundColor Yellow
$LOCK_FILE = Join-Path $LOCKS_DIR "windows-cuda.requirements.txt"
$DOWNLOAD_LOCK = Join-Path $BUILD_DIR "windows-cuda.download.requirements.txt"

# feetech-servo-sdk 仅发布 sdist，先在打包机上构建 wheel；最终清单使用构建后 hash。
$LOCK_CONTENT = Get-Content $LOCK_FILE -Raw
$LOCK_CONTENT = $LOCK_CONTENT -replace '(?ms)^feetech-servo-sdk==1\.0\.0.*?(?=^[A-Za-z0-9][A-Za-z0-9_.-]*==|\z)', ''
[System.IO.File]::WriteAllText($DOWNLOAD_LOCK, $LOCK_CONTENT, (New-Object System.Text.UTF8Encoding($false)))

# 在临时 venv 中使用 pip，避免修改受 PEP 668 保护的便携 Python。
$DOWNLOAD_VENV = Join-Path $BUILD_DIR "download-venv"
& "$UV_DIR\uv.exe" venv $DOWNLOAD_VENV --python $RUNTIME_PYTHON --seed
if ($LASTEXITCODE -ne 0) { throw "下载环境创建失败" }
$DOWNLOAD_PYTHON = Join-Path $DOWNLOAD_VENV "Scripts\python.exe"

& $DOWNLOAD_PYTHON -m pip wheel "feetech-servo-sdk==1.0.0" --no-deps --wheel-dir $WHEELS_DIR --no-cache-dir
if ($LASTEXITCODE -ne 0) { throw "feetech-servo-sdk wheel 构建失败" }

& $DOWNLOAD_PYTHON -m pip download `
  --only-binary=:all: `
  --require-hashes `
  --find-links $WHEELS_DIR `
  --extra-index-url $PYTORCH_CUDA_INDEX `
  --requirement $DOWNLOAD_LOCK `
  --dest $WHEELS_DIR `
  --no-cache-dir
if ($LASTEXITCODE -ne 0) { throw "第三方 wheel 下载失败" }
Remove-Item $DOWNLOAD_VENV -Recurse -Force

# ============================================================
# 8. 验证 CUDA torch
# ============================================================
Write-Host "[构建] 验证 CUDA torch..." -ForegroundColor Yellow
$VENV_DIR = Join-Path $BUILD_DIR "verify-venv"
& "$UV_DIR\uv.exe" venv $VENV_DIR --python $RUNTIME_PYTHON
if ($LASTEXITCODE -ne 0) { throw "CUDA 验证环境创建失败" }
& "$UV_DIR\uv.exe" pip install --python "$VENV_DIR\Scripts\python.exe" --offline --no-index --find-links $WHEELS_DIR torch
if ($LASTEXITCODE -ne 0) { throw "CUDA torch 离线安装失败" }
& "$VENV_DIR\Scripts\python.exe" -c "import torch; assert torch.version.cuda is not None, 'CUDA not found'; print(f'torch={torch.__version__} cuda={torch.version.cuda}')"
if ($LASTEXITCODE -ne 0) { throw "CUDA torch 验证失败" }
Remove-Item -Recurse -Force $VENV_DIR

# ============================================================
# 9. 复制安装脚本
# ============================================================
Write-Host "[构建] 复制安装脚本..." -ForegroundColor Yellow
Copy-Item (Join-Path $SCRIPTS_SRC "install_windows.bat") (Join-Path $DIST_DIR "一键安装.bat")
Copy-Item (Join-Path $SCRIPTS_SRC "start_windows.bat") (Join-Path $DIST_DIR "启动LeLab.bat")
Copy-Item (Join-Path $SCRIPTS_SRC "stop_windows.bat") (Join-Path $DIST_DIR "停止LeLab.bat")
Copy-Item (Join-Path $SCRIPTS_SRC "repair_windows.bat") (Join-Path $DIST_DIR "修复安装.bat")
Copy-Item (Join-Path $SCRIPTS_SRC "uninstall_windows.bat") (Join-Path $DIST_DIR "卸载LeLab.bat")
Copy-Item (Join-Path $SCRIPTS_SRC "lelab_windows.ps1") (Join-Path $DIST_DIR "lelab_windows.ps1")

# ============================================================
# 10. 生成 requirements-offline.txt（合并锁 + 本地 wheel hash）
# ============================================================
Write-Host "[构建] 生成 requirements-offline.txt..." -ForegroundColor Yellow
$REQ_FILE = Join-Path $DIST_DIR "requirements-offline.txt"
Copy-Item $DOWNLOAD_LOCK $REQ_FILE

# 添加打包阶段构建的 wheel hash（requirements 中必须使用包名和版本）。
foreach ($SPEC in @(@("feetech-servo-sdk", "1.0.0"), @("lelab-zh", $APP_VERSION), @("lerobot", $LEROBOT_VERSION))) {
    $WH = Get-ChildItem $WHEELS_DIR -Filter "$($SPEC[0].Replace('-', '_'))-$($SPEC[1])-*.whl" | Select-Object -First 1
    if (-not $WH) { throw "未找到本地 wheel: $($SPEC[0]) $($SPEC[1])" }
    $HASH = (Get-FileHash $WH.FullName -Algorithm SHA256).Hash.ToLower()
    Add-Content $REQ_FILE ""
    Add-Content $REQ_FILE "$($SPEC[0])==$($SPEC[1]) \"
    Add-Content $REQ_FILE "    --hash=sha256:$HASH"
}

# 在全新环境中按最终 requirements 做一次完整离线安装，防止只验证 torch 而漏包。
Write-Host "[构建] 验证完整离线安装..." -ForegroundColor Yellow
$FULL_VERIFY_VENV = Join-Path $BUILD_DIR "full-verify-venv"
& "$UV_DIR\uv.exe" venv $FULL_VERIFY_VENV --python $RUNTIME_PYTHON
if ($LASTEXITCODE -ne 0) { throw "完整验证环境创建失败" }
& "$UV_DIR\uv.exe" pip install `
  --python "$FULL_VERIFY_VENV\Scripts\python.exe" `
  --offline --no-index `
  --find-links $WHEELS_DIR `
  --require-hashes `
  --requirement $REQ_FILE
if ($LASTEXITCODE -ne 0) { throw "完整离线安装验证失败" }
& "$FULL_VERIFY_VENV\Scripts\python.exe" -c "import torch, lelab, lerobot; assert torch.version.cuda is not None; print('full offline import check: OK')"
if ($LASTEXITCODE -ne 0) { throw "完整离线导入验证失败" }
Remove-Item $FULL_VERIFY_VENV -Recurse -Force

# README 必须在 SHA256 清单生成前复制
$README_TEMPLATE = Join-Path $PROJECT_ROOT "packaging\offline\README-离线安装模板.txt"
if (Test-Path $README_TEMPLATE) {
    Copy-Item $README_TEMPLATE (Join-Path $DIST_DIR "README-离线安装.txt")
}

# ============================================================
# 11. 生成 SHA256SUMS.txt
# ============================================================
Write-Host "[构建] 生成 SHA256SUMS.txt..." -ForegroundColor Yellow
$SUMS_FILE = Join-Path $DIST_DIR "SHA256SUMS.txt"
$SUM_LINES = Get-ChildItem $DIST_DIR -Recurse -File | Where-Object { $_.Name -ne "SHA256SUMS.txt" } | ForEach-Object {
    $HASH = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    $REL = $_.FullName.Substring($DIST_DIR.Length + 1)
    "$HASH  $REL"
}
[System.IO.File]::WriteAllLines($SUMS_FILE, [string[]]$SUM_LINES, (New-Object System.Text.UTF8Encoding($true)))

# ============================================================
# 12. 生成最终 zip（Windows 自带 bsdtar 支持大文件）
# ============================================================
Write-Host "[构建] 正在生成最终 zip..." -ForegroundColor Yellow
$ZIP_PATH = "$DIST_DIR.zip"
if (Test-Path $ZIP_PATH) { Remove-Item $ZIP_PATH -Force }
$DIST_PARENT = Split-Path -Parent $DIST_DIR
$DIST_NAME = Split-Path -Leaf $DIST_DIR
& tar.exe -a -c -f $ZIP_PATH -C $DIST_PARENT $DIST_NAME
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $ZIP_PATH)) { throw "最终 zip 生成失败" }

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  构建完成: $DIST_DIR" -ForegroundColor Green
Write-Host "  压缩包: $ZIP_PATH" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步: 在干净 Windows 电脑上断网验收，再复制到 U 盘"
