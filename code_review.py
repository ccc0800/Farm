import subprocess
import json
import requests
from pathlib import Path

# 配置參數
LLMCPP_URL = "http://192.168.1.100:8080/v1/chat/completions"
MAX_CODE_CHARS = 8000
MAX_STATIC_CHARS = 2000 
TIMEOUT_RUFF = 10     # 靜態分析超時限制 (秒)
TIMEOUT_LLM = 120     # LLM 推理超時限制 (秒)

def run_real_static_analysis(file_path: Path, source_code: str) -> str:
    """
    使用 stdin 模式執行 ruff，並截斷過長的輸出。
    此層負責過濾「語法與結構性錯誤」，作為 LLM 審查的基礎事實。
    """
    try:
        result = subprocess.run(
            ["ruff", "check", "--stdin-filename", str(file_path), "-"],
            input=source_code,
            capture_output=True,
            text=True,
            check=False,
            timeout=TIMEOUT_RUFF
        )
        output = result.stdout.strip()
        error = result.stderr.strip()

        if not output and error:
            return f"⚠️ ruff 無法解析此檔案:\n{error[:500]}"

        if not output:
            return "✅ 靜態分析未發現硬性語法錯誤。"
        
        if len(output) > MAX_STATIC_CHARS:
            return output[:MAX_STATIC_CHARS] + "\n⚠️ 靜態分析結果過長，已截斷..."
        return output
        
    except FileNotFoundError:
        return "⚠️ 系統未安裝 ruff，略過靜態分析。"
    except subprocess.TimeoutExpired:
        return "⚠️ ruff 執行逾時，略過靜態分析。"
    except Exception as e:
        return f"⚠️ 靜態分析執行異常: {e}"

def secure_code_review(file_path_str: str) -> str:
    # 1. 路徑與檔案安全驗證 (防 Path Traversal)
    file_path = Path(file_path_str).resolve()
    if not file_path.exists() or not file_path.is_file():
        return "⚠️ 指定路徑不存在或非檔案"
    if file_path.suffix not in {'.py'}:
        return "⚠️ 目前僅支援 .py 檔案審查"

    # 2. 函數內部自讀，確保一致性
    try:
        source_code = file_path.read_text(encoding='utf-8')
    except Exception as e:
        return f"⚠️ 讀檔失敗: {e}"

    # 3. 輸入長度守門 (防 Context Window 溢出)
    if len(source_code) > MAX_CODE_CHARS:
        return f"⚠️ 原始碼超過 {MAX_CODE_CHARS} 字元限制，請拆分後分批審查。"

    # 4. 執行客觀事實分析
    static_result = run_real_static_analysis(file_path, source_code)

    # 5. 建構 Prompt
    # 這裡明確指示：靜態分析是事實，但 LLM 需自行判斷邏輯漏洞
    system_prompt = (
        "你是一位極端嚴苛的資深工程師。你的任務是審查程式碼。\n"
        "1. 首先解釋靜態分析工具發現的問題（這是客觀事實）。\n"
        "2. 接著，請跳脫工具的限制，深入審查『邏輯漏洞』、『業務邏輯缺陷』與『設計合理性』。\n"
        "不要讚美，直接指出最致命的問題。"
    )
    user_prompt = f"[原始碼]\n{source_code}\n\n[靜態分析結果]\n{static_result}"

    payload = {
        "messages": [{"role": "system", "content": system_prompt}, {"role": "user", "content": user_prompt}],
        "temperature": 0.6,
        "max_tokens": 1500
    }

    # 6. 執行請求與防禦性錯誤處理
    try:
        response = requests.post(LLMCPP_URL, json=payload, timeout=TIMEOUT_LLM)
        response.raise_for_status()
        result = response.json()
        
        # 檢查 choices 是否有效
        choices = result.get('choices', [])
        if not choices:
            return "⚠️ 模型回傳空的 choices，伺服器可能發生推理異常"
        
        choice = choices[0]
        if choice.get('finish_reason') == 'length':
            return "⚠️ 模型輸出被截斷，請調整 max_tokens。"
        
        # 使用 .get 鏈防禦 KeyError
        return choice.get('message', {}).get('content', '⚠️ 模型回傳內容為空')

    except json.JSONDecodeError:
        return "⚠️ llama.cpp 回傳格式錯誤 (非 JSON)，伺服器可能處於錯誤狀態。"
    except requests.exceptions.Timeout:
        return "⚠️ 連線超時，請檢查伺服器負載。"
    except requests.exceptions.HTTPError as e:
        return f"⚠️ HTTP 錯誤: {e.response.status_code}"
    except Exception as e:
        return f"⚠️ 未知異常: {e}"
