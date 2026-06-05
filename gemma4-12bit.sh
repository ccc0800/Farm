#!/usr/bin/env bash

# [精算結論] Q5_K_M (約 8.5GB) + SWA 優化後的 64K KV Cache (約 1.08GB) + mmproj (175MB) 
# 總 VRAM 佔用約 10.75 GB，在 16GB 顯卡上留有超過 5GB 的安全餘裕。
MODEL="/models/gemma-4-12B-it-Q5_K_M.gguf"
NGL=99
CTX=65536

echo "[v3.3-Fixed] ctx=$CTX ngl=$NGL"
exec podman run --rm \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add keep-groups \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -p 8080:8080 \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/app:Z \
  -e LD_LIBRARY_PATH=/app \
  -e GPU_MAX_ALLOC_PERCENT=95 \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  /app/llama-server \
    -m "$MODEL" \
    --mmproj /models/mmproj-gemma-4-12B-it-bf16.gguf \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --parallel 1 \
    --batch-size 4096 \
    --ubatch-size 512 \
    --flash-attn on \
    -ctk q4_0 \
    -ctv q4_0 \
    --jinja \
    --reasoning off \
    --no-mmap \
    -ngl "$NGL"