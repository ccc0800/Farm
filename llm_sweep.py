#!/usr/bin/env python3
import subprocess, time, statistics, requests, json, itertools
from datetime import datetime

CONTAINER_NAME = "llama_sweep"
IMAGE          = "ghcr.io/ggml-org/llama.cpp:server"
MODEL_DIR      = "/home/cc/llm_sweep/models"
MODEL_FILE     = "gemma-4-E4B-it-Q4_K_M.gguf"
HOST_PORT      = 8085
API_URL        = f"http://127.0.0.1:{HOST_PORT}/v1/chat/completions"

BENCHMARK_PAYLOAD = {
    "messages": [
        {"role": "system", "content": "You are a helpful assistant."},
        {"role": "user",   "content": "Explain quantum computing in one sentence."}
    ],
    "max_tokens": 64,
    "temperature": 0.7
}

NUM_REQUESTS = 6

PARAM_GRID = {
    "threads":    [4, 6],
    "batch_size": [128, 256, 512],
    "ctx_size":   [1024, 2048, 4096],
    "n_parallel": [1, 2, 4],
}

def run(cmd, check=True):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)

def stop_container():
    run(f"docker stop {CONTAINER_NAME}", check=False)
    run(f"docker rm   {CONTAINER_NAME}", check=False)

def start_container(threads, batch_size, ctx_size, n_parallel):
    cmd = (
        f"docker run -d --name {CONTAINER_NAME} "
        f"-p {HOST_PORT}:{HOST_PORT} "
        f"-v {MODEL_DIR}:/models "
        f"{IMAGE} "
        f"-m /models/{MODEL_FILE} "
        f"--host 0.0.0.0 --port {HOST_PORT} "
        f"-t {threads} "
        f"-b {batch_size} "
        f"--ctx-size {ctx_size} "
        f"--n-parallel {n_parallel} "
        f"--no-warmup"
    )
    run(cmd)

def wait_for_server(timeout=120):
    deadline = time.time() + timeout
    while time.time() < deadline:
        try:
            r = requests.get(f"http://127.0.0.1:{HOST_PORT}/health", timeout=3)
            if r.status_code == 200:
                return True
        except Exception:
            pass
        time.sleep(3)
    return False

def benchmark(n=NUM_REQUESTS):
    latencies = []
    for _ in range(n):
        t0 = time.time()
        try:
            r = requests.post(API_URL, json=BENCHMARK_PAYLOAD, timeout=60)
            r.raise_for_status()
            latencies.append(time.time() - t0)
        except Exception as e:
            print(f"      [!] {e}")
    if not latencies:
        return None
    return {
        "avg":    statistics.mean(latencies),
        "min":    min(latencies),
        "max":    max(latencies),
        "stddev": statistics.stdev(latencies) if len(latencies) > 1 else 0,
    }

def main():
    combos = list(itertools.product(
        PARAM_GRID["threads"],
        PARAM_GRID["batch_size"],
        PARAM_GRID["ctx_size"],
        PARAM_GRID["n_parallel"],
    ))
    total = len(combos)
    print(f"[sweep] 共 {total} 組參數\n")
    results = []

    for idx, (t, b, c, p) in enumerate(combos, 1):
        label = f"t={t} b={b} ctx={c} np={p}"
        print(f"[{idx:02d}/{total}] {label}")
        stop_container()
        start_container(t, b, c, p)
        if not wait_for_server():
            print("         ✗ 啟動逾時，跳過\n")
            results.append({"params": label, "avg": None})
            continue
        try:
            requests.post(API_URL, json=BENCHMARK_PAYLOAD, timeout=60)
        except Exception:
            pass
        metrics = benchmark()
        if metrics:
            print(f"         avg={metrics['avg']:.3f}s min={metrics['min']:.3f}s max={metrics['max']:.3f}s std={metrics['stddev']:.3f}s")
            results.append({"params": label, **metrics})
        else:
            print("         ✗ 全部失敗")
            results.append({"params": label, "avg": None})
        print()

    stop_container()

    valid = sorted([r for r in results if r.get("avg")], key=lambda r: r["avg"])
    print("=" * 60)
    print("RESULT — 由快到慢")
    print("=" * 60)
    print(f"{'#':<4} {'params':<30} {'avg':>7} {'min':>7} {'max':>7} {'std':>7}")
    print("-" * 60)
    for rank, r in enumerate(valid, 1):
        print(f"{rank:<4} {r['params']:<30} {r['avg']:>7.3f} {r['min']:>7.3f} {r['max']:>7.3f} {r['stddev']:>7.3f}")
    print("=" * 60)
    if valid:
        best = valid[0]
        print(f"\n✓ 最佳：{best['params']}  avg={best['avg']:.3f}s")

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = f"sweep_result_{ts}.json"
    with open(out, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"[*] 結果存至 {out}")

if __name__ == "__main__":
    main()
