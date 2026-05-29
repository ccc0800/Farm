#!/bin/bash
# ==============================================================================
# Hermes Agent 一鍵搬遷腳本
# 在來源端執行：192.168.10.250
# 目的端：192.168.10.218
# ==============================================================================

set -e

SRC_HERMES="$HOME/.hermes"
DEST="cc@192.168.10.218"
DEST_HERMES="/home/cc/.hermes"
DEST_HERMES_AGENT="$DEST_HERMES/hermes-agent"
DEST_VENV="$DEST_HERMES_AGENT/venv"

echo "======================================"
echo " Hermes Agent 一鍵搬遷"
echo " 來源：$(hostname) → 目的：$DEST"
echo "======================================"
echo ""

# --- 確認來源存在 ---
if [ ! -d "$SRC_HERMES" ]; then
    echo "❌ 找不到 $SRC_HERMES，請確認來源環境"
    exit 1
fi

# --- 第一階段：打包並傳送 ---
echo "📦 [1/4] 打包並傳送 ~/.hermes..."
echo "      (排除 venv 與暫存 DB 檔案)"
tar -czf - -C "$HOME" \
    --exclude=".hermes/hermes-agent/venv" \
    --exclude=".hermes/hermes-agent/__pycache__" \
    --exclude=".hermes/hermes-agent/node_modules" \
    .hermes | \
ssh "$DEST" "tar -xzf - -C \$HOME"
echo "      ✅ 傳送完成"

# --- 第二階段：目的端裝 uv ---
echo ""
echo "🔧 [2/4] 安裝 uv 與 Python 3.11..."
ssh "$DEST" bash << 'REMOTE'
if [ ! -f "$HOME/.local/bin/uv" ]; then
    echo "      安裝 uv..."
    curl -LsSf https://astral.sh/uv/install.sh | sh -s -- -q
else
    echo "      uv 已存在，略過"
fi

# 確認 python 3.11 存在
UV="$HOME/.local/bin/uv"
if ! $UV python list 2>/dev/null | grep -q "3.11"; then
    echo "      安裝 Python 3.11..."
    $UV python install 3.11 -q
else
    echo "      Python 3.11 已存在，略過"
fi
echo "      ✅ 完成"
REMOTE

# --- 第三階段：重建 venv ---
echo ""
echo "🐍 [3/4] 重建 venv..."
ssh "$DEST" bash << 'REMOTE'
HERMES_DIR="$HOME/.hermes/hermes-agent"
UV="$HOME/.local/bin/uv"

cd "$HERMES_DIR"
rm -rf venv

echo "      建立 venv (python 3.11)..."
$UV venv venv --python 3.11 -q

echo "      安裝 hermes..."
source venv/bin/activate
pip install -e . -q
echo "      ✅ 完成"
REMOTE

# --- 第四階段：設定 PATH ---
echo ""
echo "🔗 [4/4] 設定 PATH..."
ssh "$DEST" bash << 'REMOTE'
VENV_PATH='$HOME/.hermes/hermes-agent/venv/bin'
UV_PATH='$HOME/.local/bin'

if ! grep -q "hermes-agent/venv/bin" "$HOME/.bashrc"; then
    echo "export PATH=\"$HOME/.hermes/hermes-agent/venv/bin:$HOME/.local/bin:\$PATH\"" >> "$HOME/.bashrc"
    echo "      已寫入 ~/.bashrc"
else
    echo "      PATH 已存在，略過"
fi
REMOTE

# --- 驗收 ---
echo ""
echo "======================================"
echo "🔍 驗收"
echo "======================================"
ssh "$DEST" "$DEST_VENV/bin/hermes --version" && \
    echo "" && \
    echo "✅ 搬遷完成！" && \
    echo "" && \
    echo "👉 在目的端執行：" && \
    echo "   source ~/.bashrc && hermes" || \
    echo "❌ 驗收失敗，請檢查錯誤訊息"
