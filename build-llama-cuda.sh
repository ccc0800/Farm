#!/bin/bash
podman run --rm -it \
  --device nvidia.com/gpu=all \
  --security-opt=label=disable \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/output:Z \
  nvidia/cuda:13.3.0-devel-ubuntu24.04 \
  bash -c "
    apt-get update -q && apt-get install -y cmake git build-essential python3 python3-pip &&
    git clone https://github.com/ggml-org/llama.cpp /tmp/llama &&
    cd /tmp/llama &&
    cmake -B build \
      -DGGML_CUDA=ON \
      -DCMAKE_CUDA_ARCHITECTURES=120 \
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
      -j\$(nproc) &&

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
