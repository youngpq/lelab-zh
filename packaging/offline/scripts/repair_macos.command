#!/bin/bash
# LeLab-zh 修复安装 (macOS)
INSTALL_DIR="$HOME/Library/Application Support/LeLab-zh"

# 获取 PACKAGE_ROOT
PACKAGE_ROOT="$(cd "$(dirname "$0")" && pwd)"

echo "============================================================"
echo "  LeLab-zh 修复安装"
echo "============================================================"
echo ""

# 1. 先停止
echo "[修复] 正在停止 LeLab-zh..."
if [ -f "$INSTALL_DIR/venv/bin/lelab-zh" ]; then
    "$INSTALL_DIR/venv/bin/lelab-zh" --stop
fi

# 2. 备份旧 venv
echo "[修复] 备份旧环境..."
BACKUP_DIR="$INSTALL_DIR/venv.backup"
rm -rf "$BACKUP_DIR"
if [ -d "$INSTALL_DIR/venv" ]; then
    mv "$INSTALL_DIR/venv" "$BACKUP_DIR"
    echo "[修复] 旧环境已备份到 $BACKUP_DIR"
fi

# 3. 重建 venv
echo "[修复] 重建虚拟环境..."
rm -rf "$INSTALL_DIR/venv"
"$INSTALL_DIR/uv/uv" venv "$INSTALL_DIR/venv" --python "$INSTALL_DIR/runtime/bin/python3.12"
if [ $? -ne 0 ]; then
    echo "[错误] 创建虚拟环境失败。正在恢复旧环境..."
    rm -rf "$INSTALL_DIR/venv"
    if [ -d "$BACKUP_DIR" ]; then
        mv "$BACKUP_DIR" "$INSTALL_DIR/venv"
        echo "[恢复] 已恢复旧环境。"
    fi
    read -p "按回车键退出..."
    exit 1
fi

# 4. 重新安装依赖
echo "[修复] 重新安装依赖..."
"$INSTALL_DIR/uv/uv" pip install \
  --python "$INSTALL_DIR/venv/bin/python" \
  --offline \
  --no-index \
  --find-links "$PACKAGE_ROOT/wheels" \
  --require-hashes \
  -r "$PACKAGE_ROOT/requirements-offline.txt"
if [ $? -ne 0 ]; then
    echo "[错误] 依赖安装失败。正在恢复旧环境..."
    rm -rf "$INSTALL_DIR/venv"
    if [ -d "$BACKUP_DIR" ]; then
        mv "$BACKUP_DIR" "$INSTALL_DIR/venv"
        echo "[恢复] 已恢复旧环境。"
    fi
    read -p "按回车键退出..."
    exit 1
fi

# 5. 清理备份
rm -rf "$BACKUP_DIR"

echo ""
echo "============================================================"
echo "  修复安装完成。"
echo "============================================================"
echo ""
read -p "按回车键退出..."
