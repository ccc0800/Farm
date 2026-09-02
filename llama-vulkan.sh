#!/bin/bash
# 自動建置支援 Vulkan 的 llama-server (動態取得簡短版本號)
set -e

echo "=== [1/5] 安裝系統依賴與 Vulkan / SPIRV 開發套件 ==="
sudo dnf install -y \
    mesa-vulkan-drivers \
    vulkan-tools \
    vulkan-headers \
    vulkan-loader-devel \
    spirv-headers-devel \
    spirv-tools-devel \
    glslang \
    /usr/bin/glslc \
    cmake \
    gcc-c++ \
    git

echo "=== [2/5] 檢查 Vulkan GPU 裝置狀態 ==="
if vulkaninfo | grep -i "deviceName"; then
    echo "-> Vulkan GPU 識別成功！"
else
    echo "-> 警告：未找到 Vulkan 裝置，請確認驅動狀態。"
fi

echo "=== [3/5] 更新原始碼並獲取最新版本號 ==="
# 使用隱藏資料夾作為快取，避免每次都重新下載
CACHE_DIR="$HOME/.cache/llama.cpp-repo"

if [ ! -d "$CACHE_DIR" ]; then
    echo "-> 首次下載原始碼至快取 ($CACHE_DIR)..."
    git clone https://github.com/ggml-org/llama.cpp.git "$CACHE_DIR"
else
    echo "-> 更新原始碼快取..."
    cd "$CACHE_DIR"
    git fetch && git reset --hard origin/master
fi

# 加上 --abbrev=0 參數，只提取純淨的標籤號（例如 b10757）
cd "$CACHE_DIR"
LLAMA_VER=$(git describe --tags --abbrev=0 2>/dev/null || echo "latest")
# 簡化資料夾名稱為 /home/cc/llama-b10757 格式
TARGET_DIR="$HOME/llama-${LLAMA_VER}"

echo "-> 抓取到最新版本為: $LLAMA_VER"
echo "-> 準備部署至目錄: $TARGET_DIR"

if [ ! -d "$TARGET_DIR" ]; then
    echo "-> 複製程式碼至目標資料夾..."
    cp -r "$CACHE_DIR" "$TARGET_DIR"
else
    echo "-> 目標版本資料夾已存在，將重新執行編譯..."
fi

echo "=== [4/5] 清理舊環境並設定 CMake (Vulkan) ==="
cd "$TARGET_DIR"
rm -rf build
cmake -B build -DGGML_VULKAN=ON -DCMAKE_BUILD_TYPE=Release

echo "=== [5/5] 開始多核心並行編譯 llama-server ==="
cmake --build build --config Release -j$(nproc) --target llama-server

echo ""
echo "=========================================================="
echo "  編譯完成！ (${LLAMA_VER})"
echo "  專案路徑: $TARGET_DIR"
echo ""
echo "  測試啟動範例指令:"
echo "  $TARGET_DIR/build/bin/llama-server -m /path/to/model.gguf -ngl 99"
echo "=========================================================="
