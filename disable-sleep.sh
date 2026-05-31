
#!/usr/bin/env bash

# 確保是以 root 或 sudo 權限執行某些系統指令
echo "=== 🚀 開始停用系統自動休眠機制 ==="

# 1. 徹底封印 systemd 的休眠、暫停與混合睡眠目標（最底層、最有效）
echo "[1/3] 正在封印 systemd 休眠目標 (Masking targets)..."
sudo systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 2. 修改 logind.conf 確保蓋上筆電螢幕（如果是筆電）或按下電源鍵時不會強制休眠
echo "[2/3] 正在優化登入管理器設定 (logind.conf)..."
sudo mkdir -p /etc/systemd/logind.conf.d/
sudo tee /etc/systemd/logind.conf.d/ignore-sleep.conf > /dev/null << 'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
CONF

# 重新載入 systemd-logind 設定
sudo systemctl restart systemd-logind

# 3. 如果 Fedora 有安裝圖形桌面（GNOME），一併關閉桌面的自動睡眠設定
if command -v gsettings &> /dev/null; then
    echo "[3/3] 偵測到 GNOME 桌面環境，正在關閉桌面電源暫停設定..."
    # 接上電源時絕不自動休眠
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null
    # 使用電池時也絕不自動休眠（以防萬一）
    gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null
else
    echo "[3/3] 未偵測到桌面環境（純文字伺服器模式），跳過桌面設定。"
fi

echo "=== 🎉 設定完成！你的 AI 伺服器現在會保持清醒，絕對不偷懶！ ==="
echo "目前休眠狀態檢查（顯示 masked 代表已成功封印）："
systemctl status sleep.target suspend.target 2>&1 | grep -E "sleep.target|suspend.target|Loaded:"
