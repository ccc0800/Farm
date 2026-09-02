#!/usr/bin/env bash

# --- 執行檔與模型路徑設定 ---
LLAMA_SERVER="/home/cc/llama-b10757/build/bin/llama-server"
MODEL="/home/cc/models/gemma-4-26B_q4_0-it.gguf"
MMPROJ="/home/cc/models/gemma-4-26B-it-mmproj.gguf"

# --- 效能與記憶體參數設定 ---
NGL=99             # 99 已足夠將所有層卸載至 GPU
CTX=32768          # 上下文長度。若後續報錯 OOM (顯存不足)，可調降至 16384 或 8192
BATCH_SIZE=2048    # 實體 Batch Size
UBATCH_SIZE=1024   # 邏輯 Batch Size (Vulkan 處理長文本的最佳區間)
THREADS=8          # 限制 CPU 執行緒數 (建議設定為你的 CPU 實體核心數)
# ------------------

# 啟動 llama-server
exec "$LLAMA_SERVER" \
  -m "$MODEL" \
  --mmproj "$MMPROJ" \
  --host 0.0.0.0 \
  --port 8080 \
  -c "$CTX" \
  -t "$THREADS" \
  --parallel 1 \
  -b $BATCH_SIZE \
  -ub $UBATCH_SIZE \
  --flash-attn \
  -ctk q4_0 \
  -ctv q4_0 \
  --jinja \
  --load-mode no-mmap \
  --reasoning-budget 0 \
  -ngl "$NGL"