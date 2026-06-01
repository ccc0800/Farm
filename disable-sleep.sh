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
HandlePowerKey=ignore
CONF

# 重新載入 systemd-logind 設定
systemctl restart systemd-logind

# 抓取當前真正使用者的登入 ID
REAL_USER=${SUDO_USER:-$USER}

# 取得該使用者的 DBUS_SESSION_BUS_ADDRESS（Fedora 不需要 dbus-launch）
get_dbus_addr() {
    local user="$1"
    local uid
    uid=$(id -u "$user" 2>/dev/null) || return 1
    # 從 /run/user/<uid>/bus 取得 session bus（systemd user session 標準路徑）
    echo "unix:path=/run/user/${uid}/bus"
}

# 用 gsettings 設定指定使用者（不依賴 dbus-launch）
run_gsettings() {
    local user="$1"
    shift
    local dbus_addr
    dbus_addr=$(get_dbus_addr "$user")
    sudo -u "$user" env DBUS_SESSION_BUS_ADDRESS="$dbus_addr" gsettings "$@" 2>/dev/null
}

# 3. 關閉 GDM 登入畫面的自動睡眠設定（用系統層級 dconf，繞過 session bus 問題）
echo "[3/4] 正在封印 GDM 登入管理器電源設定..."
if id "gdm" &>/dev/null; then
    mkdir -p /etc/dconf/db/gdm.d/
    tee /etc/dconf/db/gdm.d/00-idle > /dev/null << 'DCONF'
[org/gnome/desktop/session]
idle-delay=uint32 0

[org/gnome/settings-daemon/plugins/power]
sleep-inactive-ac-type='nothing'
DCONF
    dconf update
    echo "     -> GDM 封印完成！"
else
    echo "     -> 未偵測到 GDM，跳過。"
fi

# 4. 關閉當前使用者的 GNOME 閒置計時器
echo "[4/4] 正在優化當前使用者桌面電源設定..."
if [ "$REAL_USER" != "root" ] && command -v gsettings &> /dev/null; then
    run_gsettings "$REAL_USER" set org.gnome.settings-daemon.plugins.power sleep-inactive-ac-type 'nothing'
    run_gsettings "$REAL_USER" set org.gnome.settings-daemon.plugins.power sleep-inactive-battery-type 'nothing'
    run_gsettings "$REAL_USER" set org.gnome.desktop.session idle-delay 0
    echo "     -> 使用者 ($REAL_USER) 桌面優化完成！"
else
    echo "     -> 未偵測到一般桌面環境或以純 root 執行，跳過使用者設定。"
fi

echo "=== 🎉 設定完成！你的伺服器現在會保持清醒，絕對不偷懶！ ==="
echo ""
echo "--- 驗證結果 ---"
echo -n "sleep.target:   " && systemctl show sleep.target --property=LoadState | cut -d= -f2
echo -n "suspend.target: " && systemctl show suspend.target --property=LoadState | cut -d= -f2

if [ "$REAL_USER" != "root" ] && command -v gsettings &> /dev/null; then
    echo -n "User idle-delay: " && run_gsettings "$REAL_USER" get org.gnome.desktop.session idle-delay
fi
echo -n "GDM  dconf db:   " && \
    grep -q "idle-delay=uint32 0" /etc/dconf/db/gdm.d/00-idle 2>/dev/null && \
    echo "uint32 0 ✅" || echo "未設定 ❌"
echo "--- 全部應顯示 masked / uint32 0 ---"
