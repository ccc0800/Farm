#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
Qwen 3.5 API 流式對話工具
功能：支援命令行輸入、檔案輸入，並以繁體中文簡潔回覆。
"""

import sys
import json
import requests
from requests.exceptions import Timeout, ConnectionError, RequestException

# 定義 API 配置常量
BASE_URL = "http://127.0.0.1:8080/v1/chat/completions"
SYSTEM_PROMPT = "你是一個專業的助理，請用繁體中文簡潔地回答。"
DEFAULT_TEMPERATURE = 0.3
TIMEOUT_SECONDS = 60

def get_user_input():
    """
    獲取使用者輸入。
    優先使用參數，若無參數則嘗試讀取 stdin (支援檔案輸入)，最後才使用 prompt()。
    """
    if len(sys.argv) > 1:
        return " ".join(sys.argv[1:])
    elif len(sys.argv) > 2 and sys.argv[1] == "-f" and len(sys.argv) > 2:
        # 支援 -f filename 讀取檔案
        with open(sys.argv[2], 'r', encoding='utf-8') as f:
            return f.read()
    else:
        try:
            # 嘗試從標準輸入讀取 (例如 piped input: echo "問題" | python api.py)
            return sys.stdin.read().strip()
        except KeyboardInterrupt:
            print("\n使用者已中斷執行。")
            sys.exit(0)
        except EOFError:
            return ""

def ask_qwen_stream(prompt):
    """
    發問並接收流式回覆。
    """
    url = BASE_URL

    # 準備請求參數
    headers = {
        "Content-Type": "application/json"
    }

    payload = {
        "messages": [
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": prompt}
        ],
        "stream": True,
        "temperature": DEFAULT_TEMPERATURE
    }

    print(f"\n> 正在連接到 Qwen 3.5...\n" + "-" * 40)

    try:
        # 使用 stream=True 和 timeout 設置
        response = requests.post(url, json=payload, headers=headers, stream=True, timeout=TIMEOUT_SECONDS)

        # 檢查初始狀態 (雖然 stream=True 有時不會立即回傳 [DONE])
        if response.status_code != 200:
            print(f"❌ 初始請求失敗：狀態碼 {response.status_code}")
            return

        print("-" * 40)
        print("Qwen 3.5 回覆：\n")

        # 解析流式數據
        for line in response.iter_lines():
            if line:
                decoded_line = line.decode('utf-8').lstrip('data: ')

                # 處理空行或純空字串
                if not decoded_line.strip():
                    continue

                if decoded_line == '[DONE]':
                    print("\n" + "-" * 40 + "\n")
                    print("對話結束。")
                    break

                try:
                    json_data = json.loads(decoded_line)
                    # 提取內容，處理可能為 null 的情況
                    content = json_data.get('choices', [{}])[0].get('delta', {}).get('content', '')
                    if content:
                        # 使用 flush=True 確保即時輸出
                        print(content, end='', flush=True)
                except json.JSONDecodeError:
                    # 如果遇到非 JSON 行 (偶爾發生)，忽略或打印警告
                    # print(f"警告：收到非標準 JSON 行: {decoded_line}", file=sys.stderr)
                    continue

    except Timeout:
        print("\n⏱️  伺服器響應過慢，已超時。")
    except ConnectionError:
        print("❌ 無法連接到伺服器，請檢查 IP 和端口是否正確。")
    except RequestException as e:
        print(f"❌ API 連線異常：{e}")
    except Exception as e:
        print(f"❌ 發生未知錯誤：{e}")
        import traceback
        traceback.print_exc()

def main():
    if __name__ == "__main__":
        # 檢查是否執行為模塊
        if __name__ != "__main__":
            return

        user_input = get_user_input()

        if not user_input.strip():
            print("⚠️  未輸入任何內容。")
            return

        ask_qwen_stream(user_input)

if __name__ == "__main__":
    main()

