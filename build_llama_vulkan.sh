#!/bin/bash
set -e
mkdir -p /home/cc/models
mkdir -p /home/cc/llama-build-vulkan
podman run --rm -it \
  --device /dev/dri \
  --group-add keep-groups \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build-vulkan:/output:Z \
  ubuntu:24.04 \
  bash -c "
    apt-get update -q && apt-get install -y \
      cmake git build-essential python3 python3-pip \
      libvulkan-dev vulkan-tools glslc glslang-tools spirv-tools \
      mesa-vulkan-drivers &&
    git clone https://github.com/ggml-org/llama.cpp /tmp/llama &&
    cd /tmp/llama &&
    cmake -B build \
      -DGGML_VULKAN=ON \
      -DCMAKE_BUILD_TYPE=Release &&
    cmake --build build --target \
      llama-server \
      llama-bench \
      llama-quantize \
      llama-export-lora \
      llama-gguf \
      llama-gguf-split \
      llama-imatrix \
      llama-cli \
      -j\$(nproc --ignore=2) &&
    # 複製所有工具到輸出目錄
    cp build/bin/llama-server \
       build/bin/llama-bench \
       build/bin/llama-quantize \
       build/bin/llama-export-lora \
       build/bin/llama-gguf \
       build/bin/llama-gguf-split \
       build/bin/llama-imatrix \
       build/bin/llama-cli \
       /output/ &&
    # 共享函式庫
    find build -name '*.so*' | xargs -I{} cp -P {} /output/ &&
    echo '=== 完成 ===' && ls /output/
  "
