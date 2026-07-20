#!/bin/bash
# LeLab-zh macOS Apple Silicon 离线包构建脚本
# 必须在 Apple Silicon Mac 上运行，需要：Git + LFS + uv + shell + >=20GB 磁盘

set -euo pipefail

# ============================================================
# 配置
# ============================================================
VERSION="0.1.0"
APP_VERSION="0.1.0.post1"
TAG="v${VERSION}-zh.1"
LEROBOT_VERSION="0.6.0"
LEROBOT_GIT="https://github.com/huggingface/lerobot.git"
PYTHON_VERSION="3.12"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
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
# Force a non-local clone so staging edits cannot modify the source checkout through hardlinks.
git clone --no-local --depth 1 --branch main "$PROJECT_ROOT" "$LAB_SRC"
cd "$LAB_SRC"
git lfs install 2>/dev/null || true
if [ "${LELAB_SKIP_LFS:-0}" != "1" ]; then
    git lfs pull
fi
cd "$PROJECT_ROOT"

# Keep the calibration tutorial video inside the built frontend so the
# offline package does not depend on the remote Hugging Face URL.
VIDEO_SOURCE="$LAB_SRC/frontend/public/videos/calibrate_so101_2.mp4"
VIDEO_DEST="$LAB_SRC/frontend/dist/videos/calibrate_so101_2.mp4"
[ -f "$VIDEO_SOURCE" ] || { echo "[错误] 校准视频缺失: $VIDEO_SOURCE"; exit 1; }
mkdir -p "$(dirname "$VIDEO_DEST")"
cp "$VIDEO_SOURCE" "$VIDEO_DEST"
REMOTE_VIDEO_URL="https://huggingface.co/datasets/huggingface/documentation-images/resolve/main/lerobot/calibrate_so101_2.mp4"
FRONTEND_JS="$LAB_SRC/frontend/dist/assets"
grep -R -F "/videos/calibrate_so101_2.mp4" "$FRONTEND_JS" >/dev/null || {
    echo "[错误] frontend/dist 未引用本地校准视频路径"
    exit 1
}
if grep -R -F "$REMOTE_VIDEO_URL" "$FRONTEND_JS" >/dev/null; then
    echo "[错误] frontend/dist 仍引用远程校准视频 URL"
    exit 1
fi
echo "[构建] 已将校准视频加入 frontend/dist"

# ============================================================
# 3. Clone 并构建 LeRobot wheel
# ============================================================
echo "[构建] Clone LeRobot v$LEROBOT_VERSION..."
LEROBOT_SRC="$BUILD_DIR/lerobot"
if [ -n "${LELAB_LEROBOT_WHEEL:-}" ] && [ -f "$LELAB_LEROBOT_WHEEL" ]; then
    cp "$LELAB_LEROBOT_WHEEL" "$WHEELS_DIR/"
    echo "[构建] 使用已构建 lerobot wheel: $(basename "$LELAB_LEROBOT_WHEEL")"
else
    rm -rf "$LEROBOT_SRC"
    git clone --depth 1 --branch "v$LEROBOT_VERSION" "$LEROBOT_GIT" "$LEROBOT_SRC"

    echo "[构建] 构建 lerobot wheel..."
    cd "$LEROBOT_SRC"
    uv build --wheel
    LEROBOT_WHEEL=$(find dist -maxdepth 1 -name 'lerobot-*.whl' -print -quit)
    [ -n "$LEROBOT_WHEEL" ] || { echo "[错误] 未生成 lerobot wheel"; exit 1; }
    cp "$LEROBOT_WHEEL" "$WHEELS_DIR/"
    echo "[构建] lerobot wheel: $(basename "$LEROBOT_WHEEL")"
    cd "$PROJECT_ROOT"
fi

# ============================================================
# 4. 构建 lelab-zh wheel（临时 staging pyproject.toml）
# ============================================================
echo "[构建] 构建 lelab-zh wheel..."
cd "$LAB_SRC"

# 创建 staging pyproject.toml 并临时替换（uv build 只读 pyproject.toml）
cp pyproject.toml pyproject.toml.bak
restore_pyproject() {
    if [ -f "$LAB_SRC/pyproject.toml.bak" ]; then
        mv -f "$LAB_SRC/pyproject.toml.bak" "$LAB_SRC/pyproject.toml"
    fi
}
trap restore_pyproject EXIT
sed -E "s|^([[:space:]]*)\"lerobot\[core_scripts,feetech,training\].*\",|\\1\"lerobot[core_scripts,feetech,training]==$LEROBOT_VERSION\",|" pyproject.toml.bak > pyproject.toml
grep -q "lerobot\[core_scripts,feetech,training\]==$LEROBOT_VERSION" pyproject.toml || {
    echo "[错误] 未能将 lelab-zh 的 lerobot 依赖替换为本地 wheel 版本"
    exit 1
}

# setuptools 会复用已有 egg-info 中的依赖元数据；必须清除它，
# 否则 staging 的 lerobot 替换不会反映到最终 wheel 的 METADATA。
rm -rf lelab_zh.egg-info build
SETUPTOOLS_SCM_PRETEND_VERSION=$APP_VERSION uv build --wheel

LELAB_WHEEL=$(find dist -maxdepth 1 -name "lelab_zh-${APP_VERSION}-*.whl" -print -quit)
[ -n "$LELAB_WHEEL" ] || { echo "[错误] 未生成 lelab-zh wheel"; exit 1; }
cp "$LELAB_WHEEL" "$WHEELS_DIR/"
echo "[构建] lelab-zh wheel: $(basename "$LELAB_WHEEL")"

# 检查 wheel METADATA 不残留 git URL。
# 不使用 grep -q：本脚本启用了 pipefail，grep 提前退出会让 unzip 收到 SIGPIPE，造成误报。
METADATA_LIST="$BUILD_DIR/lelab-wheel-metadata.list"
unzip -Z1 "$LELAB_WHEEL" > "$METADATA_LIST"
if ! grep -E '/METADATA$' "$METADATA_LIST" >/dev/null; then
    echo "[错误] lelab-zh wheel 缺少 METADATA！"
    exit 1
fi
METADATA_FILE=$(grep -E '/METADATA$' "$METADATA_LIST" | head -n 1)
unzip -p "$LELAB_WHEEL" "$METADATA_FILE" > "$BUILD_DIR/lelab-wheel-METADATA"
if grep '^Requires-Dist:' "$BUILD_DIR/lelab-wheel-METADATA" | grep -E "git\+|github\.com/huggingface/lerobot" >/dev/null; then
    echo "[错误] wheel METADATA 中残留 git URL！"
    exit 1
fi

# 恢复原始 pyproject.toml
restore_pyproject
trap - EXIT
cd "$PROJECT_ROOT"

# ============================================================
# 5. 下载便携 uv 二进制
# ============================================================
echo "[构建] 下载便携 uv..."
mkdir -p "$UV_DIR"
if [ -n "${LELAB_UV_BINARY:-}" ] && [ -f "$LELAB_UV_BINARY" ]; then
    cp "$LELAB_UV_BINARY" "$UV_DIR/uv"
else
    curl -fL -o "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz" \
        "https://github.com/astral-sh/uv/releases/download/0.11.29/uv-aarch64-apple-darwin.tar.gz"
    tar -xzf "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz" -C "$BUILD_DIR"
    cp "$BUILD_DIR/uv-aarch64-apple-darwin/uv" "$UV_DIR/uv"
    rm -rf "$BUILD_DIR/uv-aarch64-apple-darwin" "$BUILD_DIR/uv-aarch64-apple-darwin.tar.gz"
fi
chmod +x "$UV_DIR/uv"

# ============================================================
# 6. 安装便携 Python 3.12
# ============================================================
echo "[构建] 安装便携 Python..."
uv python install "$PYTHON_VERSION" --install-dir "$RUNTIME_DIR"
RUNTIME_PYTHON=$(find "$RUNTIME_DIR" -type f -path '*/bin/python3.12' -print -quit)
[ -n "$RUNTIME_PYTHON" ] || { echo "[错误] 未找到便携 Python"; exit 1; }
PYTHON_HOME=$(dirname "$(dirname "$RUNTIME_PYTHON")")
if [ "$PYTHON_HOME" != "$RUNTIME_DIR" ]; then
    cp -R "$PYTHON_HOME/." "$RUNTIME_DIR/"
    rm -rf "$PYTHON_HOME"
fi
find "$RUNTIME_DIR" -maxdepth 1 -type l -delete
rm -rf "$RUNTIME_DIR/.temp"
RUNTIME_PYTHON="$RUNTIME_DIR/bin/python3.12"

# ============================================================
# 7. 下载所有依赖 wheel
# ============================================================
# uv 0.11+ 已移除 uv pip download，改用 pip download
echo "[构建] 下载第三方依赖 wheel..."
LOCK_FILE="$LOCKS_DIR/macos-arm64.requirements.txt"
DOWNLOAD_LOCK="$BUILD_DIR/macos-arm64.download.requirements.txt"

# feetech-servo-sdk 仅发布 sdist，先在打包机上构建 wheel；最终清单使用构建后 hash。
perl -0pe 's/^feetech-servo-sdk==1\.0\.0.*?(?=^[A-Za-z0-9][A-Za-z0-9_.-]*==|\z)//gms' "$LOCK_FILE" > "$DOWNLOAD_LOCK"

DOWNLOAD_VENV="$BUILD_DIR/download-venv"
"$UV_DIR/uv" venv "$DOWNLOAD_VENV" --python "$RUNTIME_PYTHON" --seed
DOWNLOAD_PYTHON="$DOWNLOAD_VENV/bin/python"
"$DOWNLOAD_PYTHON" -m pip wheel "feetech-servo-sdk==1.0.0" \
    --no-deps \
    --wheel-dir "$WHEELS_DIR" \
    --no-cache-dir

"$DOWNLOAD_PYTHON" -m pip download \
    --only-binary=:all: \
    --require-hashes \
    --find-links "$WHEELS_DIR" \
    --requirement "$DOWNLOAD_LOCK" \
    --dest "$WHEELS_DIR" \
    --no-cache-dir
rm -rf "$DOWNLOAD_VENV"

# ============================================================
# 8. 验证 macOS torch（无 CUDA，MPS 可用）
# ============================================================
echo "[构建] 验证 macOS torch..."
VENV_DIR="$BUILD_DIR/verify-venv"
"$UV_DIR/uv" venv "$VENV_DIR" --python "$RUNTIME_PYTHON"
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
cp "$SCRIPTS_SRC/install_macos.command" "$DIST_DIR/一键安装.command"
cp "$SCRIPTS_SRC/start_macos.command" "$DIST_DIR/启动LeLab.command"
cp "$SCRIPTS_SRC/stop_macos.command" "$DIST_DIR/停止LeLab.command"
cp "$SCRIPTS_SRC/repair_macos.command" "$DIST_DIR/修复安装.command"
cp "$SCRIPTS_SRC/uninstall_macos.command" "$DIST_DIR/卸载LeLab.command"
chmod +x "$DIST_DIR"/*.command

# ============================================================
# 10. 生成 requirements-offline.txt
# ============================================================
echo "[构建] 生成 requirements-offline.txt..."
REQ_FILE="$DIST_DIR/requirements-offline.txt"
cp "$DOWNLOAD_LOCK" "$REQ_FILE"

# 添加本地 wheel hash
for SPEC in "feetech-servo-sdk:1.0.0:feetech_servo_sdk" "lelab-zh:$APP_VERSION:lelab_zh" "lerobot:$LEROBOT_VERSION:lerobot"; do
    PACKAGE_NAME="${SPEC%%:*}"
    REST="${SPEC#*:}"
    PACKAGE_VERSION="${REST%%:*}"
    WHEEL_PREFIX="${REST#*:}"
    WH=$(find "$WHEELS_DIR" -maxdepth 1 -name "${WHEEL_PREFIX}-${PACKAGE_VERSION}-*.whl" -print -quit)
    [ -n "$WH" ] || { echo "[错误] 未找到本地 wheel: $PACKAGE_NAME $PACKAGE_VERSION"; exit 1; }
    HASH="$(shasum -a 256 "$WH" | awk '{print $1}')"
    echo "" >> "$REQ_FILE"
    echo "$PACKAGE_NAME==$PACKAGE_VERSION \\" >> "$REQ_FILE"
    echo "    --hash=sha256:$HASH" >> "$REQ_FILE"
done

# 在全新环境中按最终 requirements 做一次完整离线安装，防止只验证 torch 而漏包。
echo "[构建] 验证完整离线安装..."
FULL_VERIFY_VENV="$BUILD_DIR/full-verify-venv"
"$UV_DIR/uv" venv "$FULL_VERIFY_VENV" --python "$RUNTIME_PYTHON"
"$UV_DIR/uv" pip install \
    --python "$FULL_VERIFY_VENV/bin/python" \
    --offline \
    --no-index \
    --find-links "$WHEELS_DIR" \
    --require-hashes \
    --requirement "$REQ_FILE"
"$FULL_VERIFY_VENV/bin/python" -c "import torch, lelab, lerobot; assert torch.version.cuda is None; print('full offline import check: OK')"
rm -rf "$FULL_VERIFY_VENV"

# README 必须在 SHA256 清单生成前复制
README_TEMPLATE="$PROJECT_ROOT/packaging/offline/README-离线安装模板.txt"
if [ -f "$README_TEMPLATE" ]; then
    cp "$README_TEMPLATE" "$DIST_DIR/README-离线安装.txt"
fi

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
# 12. 生成最终 zip（保留可执行权限）
# ============================================================
echo "[构建] 正在生成最终 zip..."
ZIP_PATH="$PROJECT_ROOT/dist/offline/LeLab-zh-macOS-Apple-Silicon-$TAG.zip"
rm -f "$ZIP_PATH"
ditto -c -k --sequesterRsrc --keepParent "$DIST_DIR" "$ZIP_PATH"

# ============================================================
# 完成
# ============================================================
echo ""
echo "============================================================"
echo "  构建完成: $DIST_DIR"
echo "  压缩包: $ZIP_PATH"
echo "============================================================"
echo ""
echo "下一步: 在干净 Apple Silicon Mac 上断网验收，再复制到 U 盘"
