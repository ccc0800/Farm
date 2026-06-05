#!/usr/bin/env bash
MODEL="/models/google_gemma-4-26B-A4B-it-Q3_K_M.gguf"
NGL=40
CTX=65536
echo "[v3.2] ctx=$CTX ngl=$NGL"
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
  -e GPU_MAX_ALLOC_PERCENT=70 \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  /app/llama-server \
    -m "$MODEL" \
    --mmproj /models/mmproj-gemma-4-26B-A4B-it-bf16.gguf \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --parallel 1 \
    --batch-size 4096\
    --ubatch-size 512 \
    --flash-attn on \
    -ctk q4_0 \
    -ctv q4_0 \
    --jinja \
    --reasoning off \
    --no-mmap \
    -ngl "$NGL"
