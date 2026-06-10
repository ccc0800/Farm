#!/bin/bash
podman run --rm -it \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add keep-groups \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/output:Z \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  bash -c "
    apt-get update -q && apt-get install -y cmake git build-essential python3 python3-pip &&
    git clone https://github.com/ggml-org/llama.cpp /tmp/llama &&
    cd /tmp/llama &&
    cmake -B build \
      -DGGML_HIP=ON \
      -DAMDGPU_TARGETS=gfx1201 \
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

    # Python 轉檔工具
    cp convert_hf_to_gguf.py \
       convert_lora_to_gguf.py \
       requirements.txt \
       /output/ &&
    cp -r gguf-py /output/ &&

    # 共享函式庫
    find build -name '*.so*' | xargs -I{} cp -P {} /output/ &&

    echo '=== 完成 ===' && ls /output/
  "
