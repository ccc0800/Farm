#!/bin/bash

CONTAINER_NAME="gemma4"
# 這裡請替換為你自己編譯、針對 gfx1201 優化的本機端執行檔路徑
# 因為你是自編譯版，可能直接跑實體檔案會比跑 podman 容器效能更好更穩定

MODEL_PATH="/models/gemma-4-26B-A4B-it-Q3_K_M.gguf"
MM_PROJ="/models/mmproj-gemma-4-26B-A4B-it-bf16.gguf"
PORT=8080

echo "🏆 終極完全體啟動！RX 9070 XT 黃金甜蜜點 (65K Context / 77 t/s)"

# 假設你直接執行自編譯的 llama-server
./llama-server \
  --model "$MODEL_PATH" \
  --mmproj "$MM_PROJ" \
  --host 0.0.0.0 \
  --port $PORT \
  --ctx-size 65536 \
  --parallel 1 \
  --threads 16 \
  --threads-batch 16 \
  --n-gpu-layers -1 \
  --flash-attn \
  -ctk q8_0 \
  -ctv q8_0 \
  --no-warmup \
  --no-mmap \
  --reasoning off
