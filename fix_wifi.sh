#!/bin/bash

# 檢查是否為 root 權限
if [[ $EUID -ne 0 ]]; then
   echo "此腳本需要 sudo 權限才能執行"
   exit 1
fi

echo "--- 開始修復 Mac Mini Wi-Fi 驅動 \---"

# 1. 強制清除舊有的、會報錯的 Broadcom 套件
echo "[1/4] 清除舊有的不相容驅動..."
apt-get purge -y broadcom-sta-dkms bcmwl-kernel-source 2>/dev/null
rm -f /var/crash/broadcom-sta-dkms.0.crash
dpkg --configure -a

# 2. 啟用 multiverse 儲存庫 (確保 firmware-b43-installer 可用)
echo "[2/4] 啟用 multiverse 軟體庫..."
add-apt-repository -y multiverse
apt-get update

# 3. 安裝正確的韌體安裝程式
# 注意：這一步必須確保已經連接乙太網路 (Ethernet)
echo "[3/4] 安裝 b43 韌體安裝程式..."
apt-get install -y firmware-b43-installer

# 4. 重載驅動模組
echo "[4/4] 重新載入 b43 驅動..."
modprobe -r b43
modprobe b43

echo "--- 修復完成！ \---"
echo "請檢查無線網路是否已出現。"
echo "若未出現，請嘗試重啟系統。"
