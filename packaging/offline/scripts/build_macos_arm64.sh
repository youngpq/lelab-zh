#!/bin/bash
# LeLab-zh macOS Apple Silicon 离线包构建脚本
# 必须在 Apple Silicon Mac 上运行，需要：Git + LFS + uv + shell + >=20GB 磁盘

set -euo pipefail

# ============================================================
# 配置
# ============================================================
VERSION="0.1.0"
TAG="v${VERSION}-zh.1"
LEROBOT_VERSION="0.6.0"
LEROBOT_GIT="https://github.com/huggingface/lerobot.git"
PYTHON_VERSION="3.12"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"
BUILD_DIR="$PROJECT_ROOT/build/macos-arm64"
DIST_DIR="$PROJECT_ROOT/dist/offline/LeLab-zh-macOS-Apple-Silicon-$TAG"
WHEELS_DIR="$DIST_DIR/wheels"
RUNTIME_DIR="$DIST_DIR/runtime"
UV_DIR="$DIST_DIR/uv"
SCRIPTS_SRC="$PROJECT_ROOT/packaging/offline/scripts"
LOCKS_DIR="$PROJECT_ROOT/packaging/offline/locks"

echo "============================================================"
echo "  LeLab-zh macOS Apple Silicon 离线包构建"
echo "============================================================"
echo ""

# ============================================================
# 0. 检查架构
# ============================================================
ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
    echo "[错误] 此构建脚本仅支持 Apple Silicon (arm64)。当前架构: $ARCH"
    exit 1
fi

# ============================================================
# 1. 清理并创建目录
# ============================================================
rm -rf "$BUILD_DIR" "$DIST_DIR"
mkdir -p "$WHEELS_DIR" "$BUILD_DIR"

# ============================================================
# 2. Checkout LeLab-zh（含 LFS）
# ============================================================
echo "[构建] Checkout LeLab-zh 源码..."
LAB_SRC="$BUILD_DIR/lelab-zh"
git clone --depth 1 --branch main "$PROJECT_ROOT" "$LAB_SRC" 2>/dev/null || \
    cp -R "$PROJECT_ROOT" "$LAB_SRC"
cd "$LAB_SRC"
git lfs install 2>/dev/null || true
git lfs pull 2>/dev/null || true
cd "$PROJECT_ROOT"

# ============================================================
# 3. Clone 并构建 LeRobot wheel
# ============================================================
echo "[构建] Clone LeRobot v$LEROBOT_VERSION..."
LEROBOT_SRC="$BUILD_DIR/lerobot"
rm -rf "$LEROBOT_SRC"
git clone --depth 1 --branch "v$LEROBOT_VERSION" "$LEROBOT_GIT" "$LEROBOT_SRC"

echo "[构建] 构建 lerobot wheel..."
cd "$LEROBOT_SRC"
uv build --wheel
LEROBOT_WHEEL=$(ls dist/*.whl | head -1)
cp "$LEROBOT_WHEEL" "$WHEELS_DIR/"
echo "[构建] lerobot wheel: $(basename "$LEROBOT_WHEEL")"
cd "$PROJECT_ROOT"

# ============================================================
# 4. 构建 lelab-zh wheel（临时 staging pyproject.toml）
# ============================================================
echo "[构建] 构建 lelab-zh wheel..."
cd "$LAB_SRC"

# 创建 staging pyproject.toml
sed "s|lerobot\[core_scripts,feetech,training\] @ git+https://github.com/huggingface/lerobot.git@v0.6.0|lerobot[core_scripts,feetech,training]==$LEROBOT_VERSION|g" pyproject.toml > pyproject.staging.toml

SETUPTOOLS_SCM_PRETEND_VERSION=$VERSION uv build --wheel

LELAB_WHEEL=$(ls dist/*.whl | head -1)
cp "$LELAB_WHEEL" "$WHEELS_DIR/"
echo "[构建] lelab-zh wheel: $(basename "$LELAB_WHEEL")"

# 检查 wheel METADATA 不残留 git URL
if unzip -p "$LELAB_WHEEL" "*.METADATA" 2>/dev/null | grep -qE "git\+|github\.com/huggingface/lerobot"; then
    echo "[警告] wheel METADATA 中残留 git URL！"
fi

rm -f pyproject.staging.toml
cd "$PROJECT_ROOT"

# ============================================================
# 5. 下载便携 uv 二进制
# ============================================================
echo "[构建] 下载便携 uv..."
mkdir -p "$UV_DIR"
curl -L -o "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz" \
    "https://github.com/astral-sh/uv/releases/download/0.11.29/uv-aarch64-apple-darwin.tar.gz"
tar -xzf "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz" -C "$UV_DIR"
chmod +x "$UV_DIR/uv"
rm "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz"

# ============================================================
# 6. 安装便携 Python 3.12
# ============================================================
echo "[构建] 安装便携 Python..."
uv python install "$PYTHON_VERSION" --python-install-dir "$RUNTIME_DIR"

# ============================================================
# 7. 下载所有依赖 wheel
# ============================================================
echo "[构建] 下载第三方依赖 wheel..."
LOCK_FILE="$LOCKS_DIR/macos-arm64.requirements.txt"
uv pip download \
    --only-binary :all: \
    --find-links "$WHEELS_DIR" \
    --requirement "$LOCK_FILE" \
    --dest "$WHEELS_DIR"

# ============================================================
# 8. 验证 macOS torch（无 CUDA，MPS 可用）
# ============================================================
echo "[构建] 验证 macOS torch..."
VENV_DIR="$BUILD_DIR/verify-venv"
"$UV_DIR/uv" venv "$VENV_DIR" --python "$RUNTIME_DIR/bin/python3.12"
"$UV_DIR/uv" pip install --python "$VENV_DIR/bin/python" --offline --no-index --find-links "$WHEELS_DIR" torch
"$VENV_DIR/bin/python" -c "
import torch
assert torch.version.cuda is None, 'CUDA should not be present on macOS'
print(f'torch={torch.__version__}')
print(f'mps_built={torch.backends.mps.is_built()}')
"
rm -rf "$VENV_DIR"

# 验证文件名无 CUDA 相关
echo "[构建] 验证 wheels 文件名无 CUDA 相关..."
if ls "$WHEELS_DIR"/*nvidia* "$WHEELS_DIR"/*triton* "$WHEELS_DIR"/*cu11* "$WHEELS_DIR"/*cu12* "$WHEELS_DIR"/*cu13* "$WHEELS_DIR"/*win_amd64* 2>/dev/null | grep -q .; then
    echo "[错误] wheels 目录中发现 CUDA 相关文件！"
    ls "$WHEELS_DIR"/*nvidia* "$WHEELS_DIR"/*triton* "$WHEELS_DIR"/*cu1* "$WHEELS_DIR"/*win_amd64* 2>/dev/null
    exit 1
fi
echo "[构建] wheels 文件名验证通过。"

# ============================================================
# 9. 复制安装脚本
# ============================================================
echo "[构建] 复制安装脚本..."
cp "$SCRIPTS_SRC/install_macos.command" "$DIST_DIR/"
cp "$SCRIPTS_SRC/start_macos.command" "$DIST_DIR/"
cp "$SCRIPTS_SRC/stop_macos.command" "$DIST_DIR/"
cp "$SCRIPTS_SRC/repair_macos.command" "$DIST_DIR/"
cp "$SCRIPTS_SRC/uninstall_macos.command" "$DIST_DIR/"
chmod +x "$DIST_DIR"/*.command

# ============================================================
# 10. 生成 requirements-offline.txt
# ============================================================
echo "[构建] 生成 requirements-offline.txt..."
REQ_FILE="$DIST_DIR/requirements-offline.txt"
cp "$LOCK_FILE" "$REQ_FILE"

# 添加本地 wheel hash
for WH in "$WHEELS_DIR"/*.whl; do
    HASH="$(shasum -a 256 "$WH" | awk '{print $1}')"
    echo "" >> "$REQ_FILE"
    echo "$(basename "$WH") \\" >> "$REQ_FILE"
    echo "    --hash=sha256:$HASH" >> "$REQ_FILE"
done

# ============================================================
# 11. 生成 SHA256SUMS.txt
# ============================================================
echo "[构建] 生成 SHA256SUMS.txt..."
SUMS_FILE="$DIST_DIR/SHA256SUMS.txt"
> "$SUMS_FILE"
find "$DIST_DIR" -type f ! -name "SHA256SUMS.txt" | while read -r FILE; do
    HASH="$(shasum -a 256 "$FILE" | awk '{print $1}')"
    REL="${FILE#$DIST_DIR/}"
    echo "$HASH  $REL" >> "$SUMS_FILE"
done

# ============================================================
# 12. 复制 README 模板
# ============================================================
README_TEMPLATE="$PROJECT_ROOT/packaging/offline/README-离线安装模板.txt"
if [ -f "$README_TEMPLATE" ]; then
    cp "$README_TEMPLATE" "$DIST_DIR/README-离线安装.txt"
fi

# ============================================================
# 完成
# ============================================================
echo ""
echo "============================================================"
echo "  构建完成: $DIST_DIR"
echo "============================================================"
echo ""
echo "打包命令（保留可执行权限）："
echo "  chmod +x $DIST_DIR/*.command $DIST_DIR/uv/uv"
echo "  ditto -c -k --sequesterRsrc --keepParent \\"
echo "    $DIST_DIR \\"
echo "    $PROJECT_ROOT/dist/offline/LeLab-zh-macOS-Apple-Silicon-$TAG.zip"
