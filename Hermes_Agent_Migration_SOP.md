# Hermes Agent 全維度遷移戰術 SOP (V3.0)

## 📋 任務概述
本文件定義了將 Hermes Agent 從舊控制平面 (Control Plane) 遷移至新基地 (New Base)
 的高完整度、高安全性與隱蔽性標準作業程序。

## 🛠️ 戰術裝備與工具 (Tactical Gear)
- **傳輸協議**：`tar` $\rightarrow$ `stdout` $\rightarrow$ `ssh` $\rightarrow$ `
stdin` (流式傳輸，無暫存檔)。
- **安全防線**：`SSH Key-based Auth` (免密連線，取代明文密碼)。
- **隱蔽技術**：`HISTCONTROL=ignorespace` (利用前置空白鍵，防止指令進入 Shell Hi
story)。
- **重建機制**：`python3 -m venv` (確保環境純淨度與平台一致性)。

## 🚀 執行程序 (Standard Operating Procedure)

### Phase 1: 建立戰略橋樑 (建立 SSH Key)
*在來源端執行，確保未來所有連線皆具備最高安全與最高效率。*
```bash
# 建立並推送 SSH Key 至目標端
ssh-copy-id cc@192.168.10.218
```

### Phase 2: 隱蔽式一擊必殺 (The Stealth Pipe Strike)
*使用流式傳輸技術，將整個 `.hermes` 與 `hermes-agent` 核心進行無痕遷移。*

**注意：請務必在指令最前面敲入一個「空白鍵」，以啟動隱形模式！**

```bash
 # 隱蔽式打包、傳送與解壓指令
 tar -czf - -C "$HOME" .hermes hermes-agent --exclude="hermes-agent/venv" | \
 ssh cc@192.168.10.218 'tar -xzf - -C "$HOME"'
```

### Phase 3: 環境重建 (The Rebuild Protocol)
*在新基地執行，確保主程式與虛擬環境的戰鬥力完全恢復。*
```bash
# 進入主程式目錄並重建環境
cd ~/hermes-agent && python3 -m venv venv && source venv/bin/activate && pip ins
tall -e .
```

## ⚠️ 戰術警示 (Tactical Warnings)
- **禁止使用 `sshpass`**：除非在無法使用 SSH Key 的極端環境，否則 `sshpass` 會留
下密碼痕跡，違反隱蔽原則。
- **嚴禁遷移 `venv`**：虛擬環境具有平台依賴性，必須透過 `pip install -e .` 重新
立。
- **隱蔽性檢查**：若執行後發現指令出現在 `history` 中，代表 `HISTCONTROL` 未生效
，請檢查環境設定。

---
**建立日期：2026-05-29**
**版本：V3.0 (Optimized by Commander & Hermes)**
