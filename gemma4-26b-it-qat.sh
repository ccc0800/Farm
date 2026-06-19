
MODEL="/models/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf"
MTP="/models/mtp-gemma-4-26B-A4B-it.gguf"
NGL=999
CTX=65536
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
  rocm/dev-ubuntu-24.04:7.2.4-complete \
  /app/llama-server \
    -m "$MODEL" \
    --model-draft "$MTP" \
    --spec-type draft-mtp \
    --spec-draft-n-max 2 \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --parallel 1 \
    --batch-size 2048 \
    --ubatch-size 512 \
    --flash-attn on \
    -ctk q4_0 \
    -ctv q4_0 \
    --jinja \
    --no-mmap \
    --reasoning off \
    -ngl "$NGL" \
    --alias Gemma4-26B \
    --tools all
