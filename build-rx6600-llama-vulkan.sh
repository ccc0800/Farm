#!/bin/bash
podman run --rm -it \
  --device /dev/dri \
  --group-add keep-groups \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/output:Z \
  ubuntu:24.04 \
  bash -c "
    apt-get update -q && apt-get install -y \
      cmake git build-essential python3 python3-pip pkg-config \
      libvulkan-dev glslc vulkan-tools mesa-vulkan-drivers &&

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

    echo '=== 編譯完成,確認 Vulkan 裝置 ===' &&
    (vulkaninfo --summary 2>/dev/null | grep -A2 'GPU id' || echo '(vulkaninfo 跳過,容器內無顯示環境屬正常現象)') &&
    ls /output/
  "
