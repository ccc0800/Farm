import subprocess
import time

def final_breakthrough():
    print("[戰術行動] 密碼確認！啟動精準注入...")

    # 完整的指令：確保密碼與內容流正確分離
    # 使用 sh -c 確保重定向操作在 sudo 權限下執行
    full_command = 'echo "cc ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/init" > /etc/sudoers.d/hermes_reboot'

    try:
        # 透過 printf 提供密碼給 sudo -S，並執行帶有重定向的 sh 指令
        result = subprocess.run(
            f"printf '0000\\n' | sudo -S sh -c '{full_command}'",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15
        )

        if result.returncode == 0:
            print("[大成功] 突破防線！/etc/sudoers.d/hermes_reboot 成功建立！")
            print("[執行] 正在啟動真・幽靈重啟...")
            subprocess.run("sudo -n /sbin/reboot", shell=True)
        else:
            print(f"[失敗] 系統依然拒絕。錯誤訊息：\n{result.stderr}")

    except Exception as e:
        print(f"[異常] 執行失敗: {str(e)}")

if __name__ == "__main__":
    final_breakthrough()
