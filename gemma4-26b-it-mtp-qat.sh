#!/usr/bin/env bash
MODEL="/models/gemma-4-26B-A4B-it-qat-UD-Q4_K_XL.gguf"
MTP="/models/mtp-gemma-4-26B-A4B-it.gguf"
MMPROJ="/models/mmproj-F16.gguf"

# --- 關鍵參數設定（滿血烤機版） ---
NGL=28           # 降到 20 層，釋放 VRAM 給 256k 極限上下文與圖片使用
CTX=65536       # 256K！直接填滿 Gemma 4 的原生訓練極限（n_ctx_train）
BATCH_SIZE=1024  # 維持 1024
UBATCH_SIZE=512  # 維持 512，防止 Prefill 階段瞬間爆 VRAM
# ------------------

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
    --mmproj "$MMPROJ" \
    --model-draft "$MTP" \
    --spec-type draft-mtp \
    --spec-draft-n-max 3 \
    --host 0.0.0.0 \
    --port 8080 \
    --ctx-size "$CTX" \
    --parallel 1 \
    --batch-size $BATCH_SIZE \
    --ubatch-size $UBATCH_SIZE \
    --flash-attn on \
    -ctk q4_0 \
    -ctv q4_0 \
    --jinja \
    --no-mmap \
    --reasoning off \
    --numa isolate \
    -ngl "$NGL"
