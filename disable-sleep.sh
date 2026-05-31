#!/usr/bin/env bash

# 確保是以 root 或 sudo 權限執行某些系統指令
if [ "$EUID" -ne 0 ]; then
  echo "❌ 請使用 sudo 權限執行此腳本！"
  exit 1
fi

echo "=== 🚀 開始停用系統自動休眠機制 ==="

# 1. 徹底封印 systemd 的休眠、暫停與混合睡眠目標（最底層、最有效）
echo "[1/4] 正在封印 systemd 休眠目標 (Masking targets)..."
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target

# 2. 修改 logind.conf 確保蓋上筆電螢幕或按下電源鍵時不會強制休眠
echo "[2/4] 正在優化登入管理器設定 (logind.conf)..."
mkdir -p /etc/systemd/logind.conf.d/
tee /etc/systemd/logind.conf.d/ignore-sleep.conf > /dev/null << 'CONF'
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
HandleSuspendKey=ignore
HandleHibernateKey=ignore
CONF

# 重新載入 systemd-logind 設定
systemctl restart systemd-logind

# 3. 關閉系統 GDM 登入畫面的自動睡眠設定（防止剛才的 gdm-greeter 廣播）
echo "[3/4] 正在封印 GDM 登入管理器電源設定..."
if id "gdm" &>/dev/null; then
    sudo -u gdm dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null
    sudo -u gdm dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
    echo "     -> GDM 封印完成！"
fi

# 4. 如果有一般使用者桌面環境，關閉目前的 GNOME 閒置計時器
echo "[4/4] 正在優化當前使用者桌面電源設定..."
# 嘗試抓取當前真正使用者的登入 ID
REAL_USER=${SUDO_USER:-$USER}
if [ "$REAL_USER" != "root" ] && command -v gsettings &> /dev/null; then
    # 使用 sudo -u 確保設定寫入真正使用者的設定檔中
    sudo -u "$REAL_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing' 2>/dev/null
    sudo -u "$REAL_USER" dbus-launch gsettings set org.gnome.desktop.session idle-delay 0 2>/dev/null
    echo "     -> 使用者 ($REAL_USER) 桌面優化完成！"
else
    echo "     -> 未偵測到一般桌面環境或以純 root 執行，跳過使用者設定。"
fi

echo "=== 🎉 設定完成！你的 AI 伺服器現在會保持清醒，絕對不偷懶！ ==="
echo ""
echo "--- 驗證結果 ---"
echo -n "sleep.target:   " && systemctl show sleep.target --property=LoadState | cut -d= -f2
echo -n "suspend.target: " && systemctl show suspend.target --property=LoadState | cut -d= -f2

if [ "$REAL_USER" != "root" ] && command -v gsettings &> /dev/null; then
    echo -n "User idle-delay:" && sudo -u "$REAL_USER" dbus-launch gsettings get org.gnome.desktop.session idle-delay
    echo -n "GDM idle-delay: " && sudo -u gdm dbus-launch gsettings get org.gnome.desktop.session idle-delay
fi
echo "--- 全部應顯示 masked / uint32 0 ---"