#!/usr/bin/env bash
#
# install-comfyui-rocm.sh
# 一鍵安裝 ComfyUI + ROCm 10.0.0 + PyTorch 2.13
# 目標硬體: AMD Radeon RX 9070 XT (RDNA4 / gfx1201)
# 目標系統: Fedora Server 44 (headless, 無 GUI)
#
# 用法:
#   chmod +x install-comfyui-rocm.sh
#   ./install-comfyui-rocm.sh
#
# 注意: 請用一般使用者身分執行(腳本內部會在需要時自動呼叫 sudo),
#       不要整支腳本用 root 執行,否則之後 pip venv 權限會很麻煩。

set -euo pipefail

# ---------- 可調整參數 ----------
GFX_TARGET="gfx1201"                 # RX 9070 / 9070 XT / AI PRO R9700
DEVICE_EXTRA="device-${GFX_TARGET}"
TORCH_VERSION="2.13"
TORCHVISION_VERSION="0.28"
TORCHAUDIO_VERSION="2.11"
ROCM_INDEX_URL="https://stable.repo.amd.com/rocm/whl-next/"
COMFYUI_REPO="https://github.com/comfyanonymous/ComfyUI.git"
COMFYUI_DIR="${HOME}/ComfyUI"
VENV_DIR="${COMFYUI_DIR}/venv"
SERVICE_PORT="8188"
PYTHON_BIN="python3.13"

# ---------- 小工具函式 ----------
c_green() { printf "\033[32m%s\033[0m\n" "$*"; }
c_yellow() { printf "\033[33m%s\033[0m\n" "$*"; }
c_red() { printf "\033[31m%s\033[0m\n" "$*"; }

if [[ "${EUID}" -eq 0 ]]; then
  c_red "請不要直接用 root 執行這支腳本,改用一般使用者(腳本會在需要時自己 sudo)。"
  exit 1
fi

# ---------- 0. 基本環境檢查 ----------
c_yellow "== 檢查系統與硬體 =="

if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  if [[ "${ID:-}" != "fedora" ]]; then
    c_yellow "警告: 偵測到的發行版是 ${PRETTY_NAME:-unknown},本腳本是為 Fedora Server 設計,其他發行版可能需要調整。"
  else
    c_green "偵測到 ${PRETTY_NAME}"
  fi
fi

PCI_INFO="$(lspci)"
if ! grep -qi 'amd/ati' <<<"${PCI_INFO}"; then
  c_yellow "警告: 沒有在 lspci 輸出中偵測到 AMD/ATI 顯示卡,請確認這台機器真的裝了 RX 9070 XT。"
fi
grep -i 'vga\|display\|3d' <<<"${PCI_INFO}" | grep -i amd || true

# ---------- 1. 系統套件 ----------
c_yellow "== 安裝系統相依套件 =="

sudo dnf -y update

# 啟用 RPM Fusion (完整版 ffmpeg 需要,Fedora 官方庫內建的是閹割版 ffmpeg-free,
# 缺 libx264/libx265 等編碼器,ComfyUI 存 mp4 時容易用到)
if ! rpm -q rpmfusion-free-release &>/dev/null; then
  sudo dnf -y install \
    "https://mirrors.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm" \
    "https://mirrors.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$(rpm -E %fedora).noarch.rpm"
fi

# Fedora 44 預設已安裝 ffmpeg-free,和 RPM Fusion 的完整版 ffmpeg 互相衝突,
# 必須用 dnf swap --allowerasing 把它換掉,不能跟其他套件塞在同一次 install 裡
# (混在一起會讓整個 transaction 因衝突而全部失敗,其他套件也裝不進去)。
if rpm -q ffmpeg-free &>/dev/null && ! rpm -q ffmpeg &>/dev/null; then
  sudo dnf -y swap ffmpeg-free ffmpeg --allowerasing
elif ! rpm -q ffmpeg &>/dev/null; then
  sudo dnf -y install ffmpeg --allowerasing
fi

sudo dnf -y install \
  git curl wget \
  gcc gcc-c++ make cmake \
  "${PYTHON_BIN}" "${PYTHON_BIN}-devel" python3-pip \
  mesa-libGL libglvnd-glx \
  libjpeg-turbo-devel zlib-devel openssl-devel \
  firewalld

# 確保 render/video 群組存在, 並把目前使用者加進去(操作 /dev/kfd, /dev/dri 需要)
sudo usermod -aG video,render "$(whoami)"

# ---------- 2. Python 虛擬環境 ----------
c_yellow "== 建立 Python 虛擬環境 =="

mkdir -p "${COMFYUI_DIR}"
if [[ ! -d "${VENV_DIR}" ]]; then
  "${PYTHON_BIN}" -m venv "${VENV_DIR}"
fi

# shellcheck disable=SC1091
source "${VENV_DIR}/bin/activate"
pip install --upgrade pip wheel setuptools

# ---------- 3. ROCm 10.0.0 + PyTorch 2.13 (RDNA4 / gfx1201) ----------
# 使用 AMD TheRock 專案的 multi-arch 穩定 channel,ROCm 以 Python 套件形式
# 安裝在 venv 內,不需要另外裝系統層級的 ROCm,升級/移除也比較乾淨。
c_yellow "== 安裝 ROCm ${ROCM_INDEX_URL} 與 PyTorch ${TORCH_VERSION} (${GFX_TARGET}) =="

pip install --index-url "${ROCM_INDEX_URL}" \
  "torch[${DEVICE_EXTRA}]==${TORCH_VERSION}" \
  "torchvision[${DEVICE_EXTRA}]==${TORCHVISION_VERSION}" \
  "torchaudio==${TORCHAUDIO_VERSION}"

c_yellow "== 驗證 PyTorch / ROCm 是否抓到 GPU =="
python - <<'PYEOF'
import torch
print("torch version:", torch.__version__)
print("cuda(ROCm) available:", torch.cuda.is_available())
if torch.cuda.is_available():
    print("device name:", torch.cuda.get_device_name(0))
else:
    print("!! 沒有偵測到 GPU,請檢查 /dev/kfd /dev/dri 權限、是否已重新登入以套用 video/render 群組。")
PYEOF

# ---------- 4. 下載 / 更新 ComfyUI ----------
c_yellow "== 取得 ComfyUI 原始碼 =="

if [[ -d "${COMFYUI_DIR}/.git" ]]; then
  git -C "${COMFYUI_DIR}" pull --ff-only
else
  # 用 init+fetch+checkout 而不是直接 clone,
  # 這樣即使資料夾裡已經有 venv/ (非空目錄) 也不會失敗,
  # 而且不會動到既有的 venv/。
  git -C "${COMFYUI_DIR}" init -q
  git -C "${COMFYUI_DIR}" remote add origin "${COMFYUI_REPO}"
  git -C "${COMFYUI_DIR}" fetch --depth=1 origin master
  git -C "${COMFYUI_DIR}" checkout -f master
fi

pip install -r "${COMFYUI_DIR}/requirements.txt"

deactivate

# ---------- 5. systemd 服務(headless 伺服器常駐) ----------
c_yellow "== 設定 systemd 服務,開機自動啟動 ComfyUI =="

SERVICE_FILE="/etc/systemd/system/comfyui.service"
CURRENT_USER="$(whoami)"

sudo tee "${SERVICE_FILE}" >/dev/null <<EOF
[Unit]
Description=ComfyUI (ROCm / RX 9070 XT)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${CURRENT_USER}
WorkingDirectory=${COMFYUI_DIR}
Environment=HSA_OVERRIDE_GFX_VERSION=
ExecStart=${VENV_DIR}/bin/python main.py --listen 0.0.0.0 --port ${SERVICE_PORT}
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable comfyui.service

# Fedora Server 預設 SELinux 是 Enforcing,systemd 系統服務執行
# 使用者家目錄底下的執行檔 (venv/bin/python) 預設會被擋下來
# (journalctl 會看到 status=203/EXEC / Permission denied)。
# 幫 venv/bin 貼上 bin_t 標籤讓它可以被系統服務執行。
if command -v getenforce &>/dev/null && [[ "$(getenforce)" == "Enforcing" ]]; then
  c_yellow "== 偵測到 SELinux Enforcing,調整 venv/bin 的 SELinux context =="
  if ! command -v semanage &>/dev/null; then
    sudo dnf -y install policycoreutils-python-utils
  fi
  sudo semanage fcontext -a -t bin_t "${VENV_DIR}/bin(/.*)?" 2>/dev/null || \
    sudo semanage fcontext -m -t bin_t "${VENV_DIR}/bin(/.*)?"
  sudo restorecon -Rv "${VENV_DIR}/bin"
fi

# ---------- 6. 防火牆開放 Port ----------
if systemctl is-active --quiet firewalld; then
  sudo firewall-cmd --permanent --add-port="${SERVICE_PORT}/tcp"
  sudo firewall-cmd --reload
fi

c_green "=================================================="
c_green " 安裝完成!"
c_green " - ComfyUI 目錄: ${COMFYUI_DIR}"
c_green " - 虛擬環境:     ${VENV_DIR}"
c_green " - 服務名稱:     comfyui.service"
c_green ""
c_yellow " 因為剛把使用者加入 video/render 群組,請先登出再登入"
c_yellow " (或直接重開機)一次,群組權限才會生效,再執行:"
c_green ""
c_green "   sudo systemctl start comfyui.service"
c_green "   sudo systemctl status comfyui.service"
c_green ""
c_green " 之後可用瀏覽器開啟 http://<這台伺服器的IP>:${SERVICE_PORT}"
c_green "=================================================="
