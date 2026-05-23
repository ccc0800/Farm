podman run --rm -it \
  --device /dev/kfd \
  --device /dev/dri \
  --group-add keep-groups \
  -v /home/cc/model:/models:Z \
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
    cmake --build build --target llama-server --target llama-bench -j\$(nproc) &&
    cp build/bin/llama-server build/bin/llama-bench /output/ &&
    find build -name '*.so*' | xargs -I{} cp -P {} /output/ &&
    echo '=== 完成 ===' && ls /output/
  "
