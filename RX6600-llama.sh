#!/usr/bin/env bash
MODEL="/models/gemma-4-12b-it-qat-q4_0.gguf"
NGL=999
CTX=8192
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
  rocm/dev-ubuntu-24.04:7.2.4-complete \
  /app/llama-server \
    -m "$MODEL" \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --batch-size 512 \
    --ubatch-size 512 \
    --parallel 1 \
    --flash-attn on \
    --jinja \
    --cache-type-k q4_0 \
    --cache-type-v q4_0 \
    -ngl "$NGL"
