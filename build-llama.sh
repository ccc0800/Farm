#!/bin/bash
podman run --rm -it \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add keep-groups \
  -v /home/cc/models:/models:Z \
  -v /home/cc/llama-build:/output:Z \
  rocm/dev-ubuntu-24.04:7.2.3-complete \
  bash -c "
    apt-get update -q && apt-get install -y cmake git build-essential &&
    git clone https://github.com/ggml-org/llama.cpp /tmp/llama &&
    cd /tmp/llama &&
    cmake -B build \
      -DGGML_HIP=ON \
      -DAMDGPU_TARGETS=gfx1201 \
      -DCMAKE_BUILD_TYPE=Release &&
    # [修改點 1] 增加編譯 llama-quantize 量化工具
    cmake --build build --target llama-server --target llama-bench --target llama-quantize -j\$(nproc) &&
    # [修改點 2] 將 llama-quantize 複製到輸出目錄
    cp build/bin/llama-server build/bin/llama-bench build/bin/llama-quantize /output/ &&
    # [修改點 3] 將 Python 轉檔腳本、依賴清單以及核心 gguf-py 資料夾複製到輸出目錄
    cp convert_hf_to_gguf.py requirements.txt /output/ &&
    cp -r gguf-py /output/ &&
    find build -name '*.so*' | xargs -I{} cp -P {} /output/ &&
    echo '=== 完成 ===' && ls /output/
  "
