podman run --rm \
  --device /dev/kfd --device /dev/dri \
  --group-add keep-groups \
  --security-opt seccomp=unconfined \
  --ipc=host \
  -v /home/cc/model:/models:Z \
  -v /home/cc/llama-build:/app:Z \
  -e HSA_OVERRIDE_GFX_VERSION=12.0.1 \
  -e LD_LIBRARY_PATH=/app \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  /app/llama-bench \
    -m /models/gemma-4-26B-A4B-it-Q4_K_M.gguf \
    -fitt 512 \
    -b 512 -ub 512 \
    -p 512 -n 128
