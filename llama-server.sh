podman run --rm \
  --device /dev/kfd --device /dev/dri \
  --group-add keep-groups \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -p 8080:8080 \
  -v /home/cc/model:/models:Z \
  -v /home/cc/llama-build:/app:Z \
  -e HSA_OVERRIDE_GFX_VERSION=12.0.1 \
  -e LD_LIBRARY_PATH=/app \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  /app/llama-server \
    -m /models/google_gemma-4-26B-A4B-it-Q3_K_M.gguf \
    --mmproj /models/mmproj-gemma-4-26B-A4B-it-bf16.gguf \
    --host 0.0.0.0 --port 8080 \
    --ctx-size 65536 \
    --parallel 1 \
    --cache-ram 0 \
    --no-mmap \
    --flash-attn on \
    -ctk q8_0 -ctv q8_0 \
    --reasoning off
