#!/bin/bash

# 參數設定
CONTAINER_NAME="gemma4"
IMAGE="ghcr.io/ggml-org/llama.cpp:server"
MODEL_PATH="/models/gemma-4-E4B-it-Q4_K_M.gguf"
# 新增 MMProj 路徑
MM_PROJ="/models/mmproj-gemma-4-E4B-it-Q8_0.gguf"
MODEL_DIR="/home/cc/podman"
PORT=8080
THREADS=$(nproc)

exec podman run \
  --name $CONTAINER_NAME \
  --replace \
  --rm \
  -p $PORT:8080 \
  -v "$MODEL_DIR":/models:Z \
  $IMAGE \
  -m $MODEL_PATH \
  --mmproj $MM_PROJ \
  --host 0.0.0.0 \
  --port 8080 \
  --threads $THREADS \
  --reasoning off
