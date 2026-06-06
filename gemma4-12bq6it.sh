#!/usr/bin/env bash
MODEL="/models/gemma-4-12B-it-Q6_K.gguf"
MMPROJ="/models/mmproj-gemma-4-12B-it-bf16.gguf"
NGL=999
CTX=65536
echo "[v4.1-Fixed] ctx=$CTX ngl=$NGL"

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
    --mmproj "$MMPROJ" \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --batch-size 4096 \
    --ubatch-size 512 \
    --parallel 1 \
    --flash-attn on \
    --jinja \
    --no-mmap \
    --reasoning-budget 0 \
    --reasoning off \
    --spec-type none \
    -ngl "$NGL"
