# LeLab-zh Windows CUDA 离线包构建脚本
# 必须在 Windows x64 机器上运行，需要：Git + LFS + uv + PowerShell + >=50GB 磁盘

$ErrorActionPreference = "Stop"

# ============================================================
# 配置
# ============================================================
$VERSION = "0.1.0"
$TAG = "v$VERSION-zh.1"
$LEROBOT_VERSION = "0.6.0"
$LEROBOT_GIT = "https://github.com/huggingface/lerobot.git"
$PYTORCH_CUDA_INDEX = "https://download.pytorch.org/whl/cu128"
$PYTHON_VERSION = "3.12"

$SCRIPT_DIR = Split-Path -Parent $MyInvocation.MyCommand.Path
$PROJECT_ROOT = Split-Path -Parent $SCRIPT_DIR
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
git clone --depth 1 --branch main "$PROJECT_ROOT" $LAB_SRC 2>$null
if ($LASTEXITCODE -ne 0) {
    # 如果已经在本地，直接复制
    Copy-Item -Recurse $PROJECT_ROOT $LAB_SRC -Exclude @(".git", "build", "dist", "__pycache__")
}
Push-Location $LAB_SRC
git lfs install 2>$null
git lfs pull 2>$null
Pop-Location

# ============================================================
# 3. Clone 并构建 LeRobot wheel
# ============================================================
Write-Host "[构建] Clone LeRobot v$LEROBOT_VERSION..." -ForegroundColor Yellow
$LEROBOT_SRC = Join-Path $BUILD_DIR "lerobot"
if (Test-Path $LEROBOT_SRC) { Remove-Item -Recurse -Force $LEROBOT_SRC }
git clone --depth 1 --branch "v$LEROBOT_VERSION" $LEROBOT_GIT $LEROBOT_SRC

Write-Host "[构建] 构建 lerobot wheel..." -ForegroundColor Yellow
Push-Location $LEROBOT_SRC
uv build --wheel
$LEROBOT_WHEEL = Get-ChildItem dist\*.whl | Select-Object -First 1
Copy-Item $LEROBOT_WHEEL.FullName $WHEELS_DIR
Write-Host "[构建] lerobot wheel: $($LEROBOT_WHEEL.Name)" -ForegroundColor Green
Pop-Location

# ============================================================
# 4. 构建 lelab-zh wheel（临时 staging pyproject.toml）
# ============================================================
Write-Host "[构建] 构建 lelab-zh wheel..." -ForegroundColor Yellow
Push-Location $LAB_SRC

# 创建 staging pyproject.toml：替换 lerobot git 依赖为版本锁定
$PYPROJECT = Get-Content pyproject.toml -Raw
$PYPROJECT = $PYPROJECT -replace 'lerobot\[core_scripts,feetech,training\] @ git\+https://github\.com/huggingface/lerobot\.git@v0\.6\.0', "lerobot[core_scripts,feetech,training]==$LEROBOT_VERSION"
# uv build 只读 pyproject.toml，必须临时替换
Copy-Item pyproject.toml pyproject.toml.bak
Set-Content pyproject.toml $PYPROJECT

# 用替换后的 pyproject.toml 构建
$env:SETUPTOOLS_SCM_PRETEND_VERSION = $VERSION
uv build --wheel

$LELAB_WHEEL = Get-ChildItem dist\*.whl | Select-Object -First 1
Copy-Item $LELAB_WHEEL.FullName $WHEELS_DIR
Write-Host "[构建] lelab-zh wheel: $($LELAB_WHEEL.Name)" -ForegroundColor Green

# 恢复原始 pyproject.toml
Copy-Item pyproject.toml.bak pyproject.toml -Force
Remove-Item pyproject.toml.bak -Force

# 检查 wheel METADATA 不残留 git URL
Add-Type -AssemblyName System.IO.Compression.FileSystem
$ZIP = [System.IO.Compression.ZipFile]::OpenRead($LELAB_WHEEL.FullName)
$META = $ZIP.Entries | Where-Object { $_.FullName -like "*.METADATA" } | Select-Object -First 1
if ($META) {
    $STREAM = $META.Open()
    $READER = New-Object System.IO.StreamReader($STREAM)
    $CONTENT = $READER.ReadToEnd()
    $READER.Close()
    $STREAM.Close()
    if ($CONTENT -match "git\+" -or $CONTENT -match "github\.com/huggingface/lerobot") {
        Write-Host "[警告] wheel METADATA 中残留 git URL！" -ForegroundColor Red
    }
}
$ZIP.Dispose()

Pop-Location

# ============================================================
# 5. 下载便携 uv 二进制
# ============================================================
Write-Host "[构建] 下载便携 uv..." -ForegroundColor Yellow
$UV_URL = "https://astral.sh/uv/0.11.29/install.ps1"
Invoke-WebRequest -Uri "https://github.com/astral-sh/uv/releases/download/0.11.29/uv-x86_64-pc-windows-msvc.zip" -OutFile (Join-Path $BUILD_DIR "uv.zip")
Expand-Archive -Path (Join-Path $BUILD_DIR "uv.zip") -DestinationPath $UV_DIR -Force
Remove-Item (Join-Path $BUILD_DIR "uv.zip") -Force

# ============================================================
# 6. 安装便携 Python 3.12
# ============================================================
Write-Host "[构建] 安装便携 Python..." -ForegroundColor Yellow
uv python install $PYTHON_VERSION --python-install-dir $RUNTIME_DIR

# ============================================================
# 7. 下载所有依赖 wheel
# ============================================================
# uv 0.11+ 已移除 uv pip download，改用 pip download
Write-Host "[构建] 下载第三方依赖 wheel..." -ForegroundColor Yellow
$LOCK_FILE = Join-Path $LOCKS_DIR "windows-cuda.requirements.txt"

# 用系统 pip 下载（确保平台 wheel 匹配）
python -m pip download `
  --only-binary=:all: `
  --require-hashes `
  --find-links $WHEELS_DIR `
  --extra-index-url $PYTORCH_CUDA_INDEX `
  --requirement $LOCK_FILE `
  --dest $WHEELS_DIR `
  --no-cache-dir

# ============================================================
# 8. 验证 CUDA torch
# ============================================================
Write-Host "[构建] 验证 CUDA torch..." -ForegroundColor Yellow
$VENV_DIR = Join-Path $BUILD_DIR "verify-venv"
& "$UV_DIR\uv.exe" venv $VENV_DIR --python "$RUNTIME_DIR\python.exe"
& "$UV_DIR\uv.exe" pip install --python "$VENV_DIR\Scripts\python.exe" --offline --no-index --find-links $WHEELS_DIR torch
& "$VENV_DIR\Scripts\python.exe" -c "import torch; assert torch.version.cuda is not None, 'CUDA not found'; print(f'torch={torch.__version__} cuda={torch.version.cuda}')"
Remove-Item -Recurse -Force $VENV_DIR

# ============================================================
# 9. 复制安装脚本
# ============================================================
Write-Host "[构建] 复制安装脚本..." -ForegroundColor Yellow
Copy-Item (Join-Path $SCRIPTS_SRC "install_windows.bat") $DIST_DIR
Copy-Item (Join-Path $SCRIPTS_SRC "start_windows.bat") $DIST_DIR
Copy-Item (Join-Path $SCRIPTS_SRC "stop_windows.bat") $DIST_DIR
Copy-Item (Join-Path $SCRIPTS_SRC "repair_windows.bat") $DIST_DIR
Copy-Item (Join-Path $SCRIPTS_SRC "uninstall_windows.bat") $DIST_DIR

# ============================================================
# 10. 生成 requirements-offline.txt（合并锁 + 本地 wheel hash）
# ============================================================
Write-Host "[构建] 生成 requirements-offline.txt..." -ForegroundColor Yellow
$REQ_FILE = Join-Path $DIST_DIR "requirements-offline.txt"
Copy-Item $LOCK_FILE $REQ_FILE

# 添加本地 wheel hash
foreach ($WH in (Get-ChildItem $WHEELS_DIR -Filter "*.whl")) {
    $HASH = (Get-FileHash $WH.FullName -Algorithm SHA256).Hash.ToLower()
    $NAME_VER = $WH.Name -replace '-.*$', ''
    # 简单追加（实际应解析包名和版本）
    Add-Content $REQ_FILE ""
    Add-Content $REQ_FILE "$($WH.Name) \"
    Add-Content $REQ_FILE "    --hash=sha256:$HASH"
}

# ============================================================
# 11. 生成 SHA256SUMS.txt
# ============================================================
Write-Host "[构建] 生成 SHA256SUMS.txt..." -ForegroundColor Yellow
$SUMS_FILE = Join-Path $DIST_DIR "SHA256SUMS.txt"
Get-ChildItem $DIST_DIR -Recurse -File | Where-Object { $_.Name -ne "SHA256SUMS.txt" } | ForEach-Object {
    $HASH = (Get-FileHash $_.FullName -Algorithm SHA256).Hash.ToLower()
    $REL = $_.FullName.Substring($DIST_DIR.Length + 1)
    "$HASH  $REL" | Out-File -Append -FilePath $SUMS_FILE -Encoding utf8
}

# ============================================================
# 12. 复制 README 模板
# ============================================================
$README_TEMPLATE = Join-Path $PROJECT_ROOT "packaging\offline\README-离线安装模板.txt"
if (Test-Path $README_TEMPLATE) {
    Copy-Item $README_TEMPLATE (Join-Path $DIST_DIR "README-离线安装.txt")
}

# ============================================================
# 完成
# ============================================================
Write-Host ""
Write-Host "============================================================" -ForegroundColor Green
Write-Host "  构建完成: $DIST_DIR" -ForegroundColor Green
Write-Host "============================================================" -ForegroundColor Green
Write-Host ""
Write-Host "下一步: 手动压缩为 zip 并复制到 U 盘"
