#!/bin/bash
# LeLab-zh 一键安装 (macOS Apple Silicon)
# 此文件必须保留可执行权限

set -e

echo "============================================================"
echo "  LeLab-zh 离线安装程序"
echo "============================================================"
echo ""

# ============================================================
# 1. 定位解压后本地目录
# ============================================================
PACKAGE_ROOT="$(cd "$(dirname "$0")" && pwd)"

# ============================================================
# 2. 检查操作系统和架构
# ============================================================
ARCH="$(uname -m)"
if [ "$ARCH" != "arm64" ]; then
    echo "[错误] 此安装包仅支持 Apple Silicon (M1/M2/M3/M4) Mac。"
    echo "       当前架构: $ARCH"
    echo "       不支持 Intel Mac。"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi

# ============================================================
# 3. 选择安装目录并检查可用磁盘空间（至少 8GB = 8589934592 字节）
# ============================================================
LOCATION_FILE="$HOME/.lelab-zh-install-dir"
DEFAULT_INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"
INSTALL_DIR="$DEFAULT_INSTALL_DIR"
if [ -f "$LOCATION_FILE" ]; then
    SAVED_INSTALL_DIR="$(cat "$LOCATION_FILE")"
    if [ -n "$SAVED_INSTALL_DIR" ]; then
        INSTALL_DIR="$SAVED_INSTALL_DIR"
    fi
fi
echo "[信息] 默认安装位置：$INSTALL_DIR"
read -r -p "如需安装到其他本地目录，请输入完整路径；直接按回车使用默认位置：" CUSTOM_INSTALL_DIR
if [ -n "$CUSTOM_INSTALL_DIR" ]; then
    INSTALL_DIR="$CUSTOM_INSTALL_DIR"
fi
case "$INSTALL_DIR" in
    ~/*) INSTALL_DIR="$HOME/${INSTALL_DIR#~/}" ;;
esac
case "$INSTALL_DIR" in
    /*) ;;
    *)
        echo "[错误] 安装位置必须是本机绝对路径。"
        read -p "按回车键退出..."
        exit 1
        ;;
esac
INSTALL_DIR="${INSTALL_DIR%/}"
case "$INSTALL_DIR" in
    ""|"$PACKAGE_ROOT"|"$PACKAGE_ROOT"/*)
        echo "[错误] 不能安装到解压后的安装包目录。"
        read -p "按回车键退出..."
        exit 1
        ;;
esac
if [ "$INSTALL_DIR" = "/" ]; then
    echo "[错误] 请选择一个具体的安装文件夹。"
    read -p "按回车键退出..."
    exit 1
fi
INSTALL_PARENT="$(dirname "$INSTALL_DIR")"
mkdir -p "$INSTALL_PARENT"
FREE_KB="$(df -k "$INSTALL_PARENT" | tail -1 | awk '{print $4}')"
if [ -n "$FREE_KB" ] && [ "$FREE_KB" -lt 8388608 ]; then
    echo "[警告] 可用磁盘空间不足 8GB。建议至少 8GB（推荐 12GB）。"
    read -p "是否继续安装？(y/N) " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "安装已取消。"
        exit 0
    fi
fi

# ============================================================
# 4. 检查完整性
# ============================================================
MISSING=0
for DIR in wheels runtime uv ffmpeg-dylibs; do
    if [ ! -d "$PACKAGE_ROOT/$DIR" ]; then
        echo "[错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。"
        echo "       禁止在压缩包预览界面直接双击此脚本。"
        echo ""
        read -p "按回车键退出..."
        exit 1
    fi
done
if [ ! -f "$PACKAGE_ROOT/requirements-offline.txt" ]; then
    echo "[错误] 安装文件不完整。请先将压缩包完整解压，再运行「一键安装」。"
    echo ""
    read -p "按回车键退出..."
    exit 1
fi
echo "[检查] 安装文件完整性: 通过"
echo ""

# ============================================================
# 5. 校验 SHA256SUMS.txt
# ============================================================
if [ -f "$PACKAGE_ROOT/SHA256SUMS.txt" ]; then
    echo "[信息] 正在校验文件完整性..."
    cd "$PACKAGE_ROOT"
    if command -v shasum >/dev/null 2>&1; then
        shasum -a 256 -c SHA256SUMS.txt
    elif command -v sha256sum >/dev/null 2>&1; then
        sha256sum -c SHA256SUMS.txt
    else
        echo "[错误] 系统缺少 SHA256 校验工具。"
        read -p "按回车键退出..."
        exit 1
    fi
    echo "[信息] 校验完成。"
fi
echo ""

# ============================================================
# 6. 创建安装目录
# ============================================================
if [ -d "$INSTALL_DIR" ]; then
    echo "[信息] 检测到已有安装: $INSTALL_DIR"
    echo "[信息] 将覆盖安装..."
    if [ -x "$INSTALL_DIR/venv/bin/lelab-zh" ]; then
        "$INSTALL_DIR/venv/bin/lelab-zh" --stop >/dev/null 2>&1 || true
    fi
fi
mkdir -p "$INSTALL_DIR"
echo "[安装] 安装目录: $INSTALL_DIR"

# ============================================================
# 7. 拷贝离线运行与修复所需文件（保留可执行权限）
# ============================================================
echo "[安装] 正在复制运行时文件..."
rm -rf "$INSTALL_DIR/runtime" "$INSTALL_DIR/uv" "$INSTALL_DIR/wheels"
rm -rf "$INSTALL_DIR/venv"
cp -R "$PACKAGE_ROOT/runtime" "$INSTALL_DIR/runtime"
cp -R "$PACKAGE_ROOT/uv" "$INSTALL_DIR/uv"
cp -R "$PACKAGE_ROOT/wheels" "$INSTALL_DIR/wheels"
cp -R "$PACKAGE_ROOT/ffmpeg-dylibs" "$INSTALL_DIR/ffmpeg-dylibs"
cp "$PACKAGE_ROOT/requirements-offline.txt" "$INSTALL_DIR/requirements-offline.txt"
chmod +x "$INSTALL_DIR/uv/uv"
chmod +x "$INSTALL_DIR/runtime/bin/python3.12"
echo "[安装] 运行时文件复制完成。"

# ============================================================
# 8. 创建 venv
# ============================================================
echo "[安装] 正在创建虚拟环境..."
"$INSTALL_DIR/uv/uv" venv "$INSTALL_DIR/venv" --python "$INSTALL_DIR/runtime/bin/python3.12"
if [ $? -ne 0 ]; then
    echo "[错误] 创建虚拟环境失败。"
    read -p "按回车键退出..."
    exit 1
fi
echo "[安装] 虚拟环境创建成功。"

# ============================================================
# 9. 安装依赖
# ============================================================
echo "[安装] 正在从本地安装依赖（此过程可能需要几分钟）..."
"$INSTALL_DIR/uv/uv" pip install \
  --python "$INSTALL_DIR/venv/bin/python" \
  --offline \
  --no-index \
  --find-links "$PACKAGE_ROOT/wheels" \
  --require-hashes \
  -r "$PACKAGE_ROOT/requirements-offline.txt"
if [ $? -ne 0 ]; then
    echo "[错误] 依赖安装失败。请检查安装包是否完整。"
    read -p "按回车键退出..."
    exit 1
fi
echo "[安装] 依赖安装完成。"

# ============================================================
# 10. 创建桌面快捷方式（Finder 启动器）
# ============================================================
echo "[安装] 正在创建启动器..."
mkdir -p "$HOME/Applications/LeLab-zh.app/Contents/MacOS"
cat > "$HOME/Applications/LeLab-zh.app/Contents/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>launch</string>
    <key>CFBundleName</key>
    <string>LeLab-zh</string>
    <key>CFBundleIdentifier</key>
    <string>com.lelab.zh</string>
</dict>
</plist>
PLIST
cat > "$HOME/Applications/LeLab-zh.app/Contents/MacOS/launch" << LAUNCH
#!/bin/bash
exec "$INSTALL_DIR/venv/bin/lelab-zh"
LAUNCH
chmod +x "$HOME/Applications/LeLab-zh.app/Contents/MacOS/launch"
ln -sfn "$HOME/Applications/LeLab-zh.app" "$HOME/Desktop/启动LeLab.app"
echo "[安装] 启动器已创建: $HOME/Applications/LeLab-zh.app"

# ============================================================
# 11. 写版本信息
# ============================================================
echo "v0.1.0" > "$INSTALL_DIR/version.txt"
printf '%s\n' "$INSTALL_DIR" > "$LOCATION_FILE"

# ============================================================
# 12. 完成提示
# ============================================================
echo ""
echo "============================================================"
echo "  LeLab-zh 已安装到电脑本地。"
echo "============================================================"
echo ""
echo "  现在可以："
echo "  1. 双击桌面的「启动LeLab」或从启动台打开 LeLab-zh；"
echo "  2. 删除下载的压缩包；"
echo "  3. 删除本次解压出的安装文件夹。"
echo ""
echo "  删除安装包不会影响已经安装的 LeLab-zh。"
echo "============================================================"
echo ""
read -p "是否立即启动 LeLab？(y/N) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    "$INSTALL_DIR/venv/bin/lelab-zh"
fi
