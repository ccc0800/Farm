#!/usr/bin/env bash
MODEL="/models/gemma-4-12b-it-qat-q4_0.gguf"
NGL=999
CTX=65536
export HSA_OVERRIDE_GFX_VERSION=10.3.0

exec podman run --rm \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add keep-groups \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -p 8080:8080 \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/app:Z \
  -e HSA_OVERRIDE_GFX_VERSION=10.3.0 \
  -e LD_LIBRARY_PATH=/app \
  rocm/dev-ubuntu-24.04:7.2.4-complete \
  /app/llama-server \
    -m "$MODEL" \
    --mmproj /models/mmproj-gemma-4-12b-it-qat-q4_0.gguf \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --batch-size 1024 \
    --ubatch-size 512 \
    --parallel 1 \
    --flash-attn on \
    --jinja \
    --cache-type-k q4_0 \
    --cache-type-v q4_0 \
    --no-warmup \
    --reasoning off \
    -ngl "$NGL" --fit on
