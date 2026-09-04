#!/usr/bin/env bash

# --- 執行檔與模型路徑設定 ---
LLAMA_SERVER="/home/cc/llama-b10757/build/bin/llama-server"
MODEL="/home/cc/models/Qwen3.8-27B-UD-IQ4_XS.gguf"
MMPROJ="/home/cc/models/Qwen3.8-mmproj-F16.gguf"

# --- 效能與記憶體參數設定 ---
NGL=99
CTX=65536
BATCH_SIZE=2048
UBATCH_SIZE=1024
THREADS=16
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
  --flash-attn on \
  -ctk q4_0 \
  -ctv q4_0 \
  --jinja \
  --load-mode none \
  --reasoning off \
  --image-min-tokens 1024 \
  -ngl "$NGL" \
  --alias Qwen-3.8-27B
