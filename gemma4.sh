# ========================================================================
# 步驟 0: 設定變數 (請務必檢查並修改以下兩個變數！)
# ========================================================================
SERVICE_NAME="gemma4-server.service"
SERVICE_USER="您的使用者名稱" # <-- *** 請修改為您本機帳號名稱 ***
SCRIPT_PATH="/home/cc/scripts/gemma4-run.sh" # <-- *** 請修改為您存放腳本的完整路徑 ***

# 創建必要的目錄結構 (如果不存在)
mkdir -p ~/.config/systemd/user/

echo "--- 正在建立 Systemd Service 檔案：${SERVICE_NAME} ---"

# 使用 tee 將內容寫入 Service 檔案
tee ~/.config/systemd/user/${SERVICE_NAME} > /dev/null <<EOF
[Unit]
Description=Gemma 4 LLM Server (Podman)
After=network.target

[Service]
# 這裡必須寫入您腳本的絕對路徑
ExecStart=${SCRIPT_PATH}
Restart=always
RestartSec=10s
# 確保服務以您的使用者身份運行
User=${SERVICE_USER}
Group=${SERVICE_USER}

[Install]
WantedBy=default.target
EOF

echo ""
echo "✅ Service 檔案已寫入至：~/.config/systemd/user/${SERVICE_NAME}"
echo "-----------------------------------------------------------------------"
echo "➡️ 接下來，需要啟用並啟動服務 (執行以下指令)："

# 步驟 1: 重新載入 systemd 配置
echo "--> 重新載入 systemd 配置..."
systemctl --user daemon-reload

# 步驟 2: 啟用服務 (讓開機時自動啟動)
echo "--> 啟用開機自啟動 (Enable)..."
systemctl --user enable ${SERVICE_NAME}

# 步驟 3: 立即啟動服務 (測試)
echo "--> 立即啟動服務 (Start) 進行測試..."
systemctl --user start ${SERVICE_NAME}

echo ""
echo "============================================================="
echo "✨ 設定完成！請執行以下指令檢查狀態："
echo "systemctl --user status ${SERVICE_NAME}"
echo "============================================================="
echo "如果看到 'Active: active (running)'，表示成功！"
