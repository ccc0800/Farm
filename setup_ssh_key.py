import os
import subprocess

TARGET = "cc@192.168.10.222"
KEY_PATH = os.path.expanduser("~/.ssh/id_ed25519")
PUB_KEY_PATH = KEY_PATH + ".pub"

def run(cmd):
    return subprocess.run(cmd, shell=True).returncode

def main():
    print("=== SSH Key 部署工具 ===\n")

    # 1. 產生金鑰
    if os.path.exists(KEY_PATH):
        print(f"[略過] 金鑰已存在：{KEY_PATH}")
    else:
        print("[1/3] 產生 ed25519 金鑰...")
        code = run(f"ssh-keygen -t ed25519 -N '' -f {KEY_PATH} -q")
        if code != 0:
            print("[錯誤] 金鑰產生失敗")
            return
        print("      完成")

    # 2. 部署公鑰（會要求輸入一次密碼）
    print(f"\n[2/3] 部署公鑰到 {TARGET}")
    print("      → 這步需要輸入對方密碼，輸入一次就好")
    code = run(f"ssh-copy-id -i {PUB_KEY_PATH} {TARGET}")
    if code != 0:
        print("[錯誤] 公鑰部署失敗，請確認網路或密碼")
        return
    print("      完成")

    # 3. 測試連線
    print(f"\n[3/3] 測試免密碼連線...")
    code = run(f"ssh -i {KEY_PATH} -o BatchMode=yes {TARGET} 'echo 連線成功'")
    if code == 0:
        print("\n[OK] SSH 高速公路建立完成")
        print(f"     之後登入：ssh -i {KEY_PATH} {TARGET}")
    else:
        print("[錯誤] 測試連線失敗")

if __name__ == "__main__":
    main()
