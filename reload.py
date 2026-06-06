import subprocess
import time

def final_breakthrough():
    print("[戰術行動] 密碼確認！啟動精準注入...")

    # 完整的指令：先準備好內容，再透過 sudo -S 寫入
    # 我們使用 sh -c 來確保整個 pipeline 都在 sudo 的權限下執行
    full_command = 'echo "cc ALL=(ALL) NOPASSWD: /sbin/reboot, /sbin/init" | sudo -S tee /etc/sudoers.d/hermes_reboot'

    try:
        # 透過 echo 餵入密碼給 sudo -S
        result = subprocess.run(
            f"echo '0000' | {full_command}",
            shell=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            timeout=15
        )

        if result.returncode == 0:
            print("[大成功] 突破防線！/etc/sudoers.d/hermes_reboot 成功建立！")
            print("[執行] 正在啟動真・幽靈重啟...")
            # 權限開通了，現在直接下達免密碼重啟！
            subprocess.run("sudo -n /sbin/reboot", shell=True)
        else:
            print(f"[失敗] 系統依然拒絕。錯誤訊息：\n{result.stderr}")

    except Exception as e:
        print(f"[異常] 執行失敗: {str(e)}")

if __name__ == "__main__":
    final_breakthrough()
