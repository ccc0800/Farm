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
    "temperature": 0.0  # 💡 壓到 0，確保字數一致，測時最準
}

NUM_REQUESTS = 6

PARAM_GRID = {
    "threads":    [4, 6],
    "batch_size": [512],
    "ctx_size":   [2048, 4096],
    "n_parallel": [1, 2, 4],
}

def run(cmd, check=True):
    return subprocess.run(cmd, shell=True, capture_output=True, text=True, check=check)

def stop_container():
    run(f"sudo docker stop {CONTAINER_NAME}", check=False)
    run(f"sudo docker rm   {CONTAINER_NAME}", check=False)

def start_container(threads, batch_size, ctx_size, n_parallel):
    cmd = (
        f"sudo docker run -d --name {CONTAINER_NAME} "
        f"-p {HOST_PORT}:{HOST_PORT} "
        f"-v {MODEL_DIR}:/models "
        f"{IMAGE} "
        f"-m /models/{MODEL_FILE} "
        f"--host 0.0.0.0 --port {HOST_PORT} "
        f"-t {threads} "
        f"-b {batch_size} "
        f"-ub {batch_size} " 
        f"--ctx-size {ctx_size} "
        f"-np {n_parallel} "  # 💡 修正這裡：改用最新版支援的 -np
        f"--no-warmup --no-mmap"
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
        "avg":   statistics.mean(latencies),
        "min":   min(latencies),
        "max":   max(latencies),
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
    print(f"[sweep] 🚀 壓測自動化啟動，共 {total} 組參數\n")
    results = []

    for idx, (t, b, c, p) in enumerate(combos, 1):
        label = f"t={t} b={b} ctx={c} np={p}"
        print(f"[{idx:02d}/{total}] 正在測試: {label}")
        stop_container()
        start_container(t, b, c, p)
        
        if not wait_for_server():
            print("         ✗ 啟動逾時或 Container 崩潰，跳過\n")
            err_log = run(f"sudo docker logs {CONTAINER_NAME}", check=False).stdout.splitlines()[-3:]
            if err_log:
                print(f"         [末尾日誌]: {' | '.join(err_log)}")
            results.append({"params": label, "avg": None})
            continue
            
        try:
            requests.post(API_URL, json=BENCHMARK_PAYLOAD, timeout=60)
        except Exception:
            pass
            
        metrics = benchmark()
        if metrics:
            print(f"         ✅ 成功! avg={metrics['avg']:.3f}s min={metrics['min']:.3f}s")
            results.append({"params": label, **metrics})
        else:
            print("         ✗ 全部推理失敗")
            results.append({"params": label, "avg": None})
        print()

    stop_container()

    valid = sorted([r for r in results if r.get("avg")], key=lambda r: r["avg"])
    print("=" * 65)
    print("📊 FINAL SWEEP REPORT (由快到慢排序)")
    print("=" * 65)
    print(f"{'名次':<4} {'參數組合 (Params)':<30} {'平均 (avg)':>9} {'最小 (min)':>9} {'標準差':>8}")
    print("-" * 65)
    for rank, r in enumerate(valid, 1):
        print(f"{rank:<4} {r['params']:<30} {r['avg']:>8.3f}s {r['min']:>8.3f}s {r['stddev']:>7.3f}")
    print("=" * 65)
    
    if valid:
        best = valid[0]
        print(f"\n🏆 最佳性能參數：{best['params']} (平均延遲: {best['avg']:.3f} 秒)")

    ts = datetime.now().strftime("%Y%m%d_%H%M%S")
    out = f"sweep_result_{ts}.json"
    with open(out, "w") as f:
        json.dump(results, f, indent=2, ensure_ascii=False)
    print(f"[*] 原始 JSON 報表已儲存至 {out}")

if __name__ == "__main__":
    main()
