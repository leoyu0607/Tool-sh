# ai3_service.sh — Ai3 QS Service Management Script

> 適用於 **Apache Tomcat / JBoss** 應用伺服器的 Ai3 QuickSilver 服務管理腳本  
> 作者：LeoYu

---

## 功能概覽

| 功能 | 說明 |
|------|------|
| 互動式選單 | 以文字選單選擇服務與操作 |
| CLI 直接操作 | 支援 `start / stop / status / restart` 命令列操作 |
| 自動偵測服務 | 掃描 home 目錄，自動列出符合命名規則的服務實例 |
| 自動偵測 App Server | 辨識目錄下的 `apache-tomcat` 或 `jboss` |
| Spinner 動畫 | 啟動 / 停止時顯示進度旋轉動畫 |
| 郵件告警 | 服務異常時透過 SMTPS 發送通知信 |
| 自動安裝 PATH | 建立 `~/.local/bin/ai3-service` 捷徑，方便全域呼叫 |
| 使用者安全切換 | 以 root 執行時自動 `sudo su` 切換至指定使用者 |

---

## 需求環境

- OS：Linux（RHEL / Rocky Linux 建議）
- Shell：Bash 4+
- 工具：`pgrep`、`curl`（郵件告警用）、`nohup`
- 服務目錄結構（預設 `/home/ai3/`）：

```
/home/ai3/
├── ecp/
│   ├── apache-tomcat/     ← App Server 目錄
│   └── server.sh          ← 服務啟動腳本（必要）
├── gateway/
│   ├── apache-tomcat/
│   └── server.sh
└── ...
```

---

## 支援的服務命名規則

腳本自動偵測目錄名稱符合以下 regex 的服務：

```
ecp | gateway | gw | GW | cbe | cbm | MediaProxy | MP | mp
```

---

## 安裝

```bash
# 複製腳本至服務機器
cp ai3_service.sh /home/ai3/

# 賦予執行權限（root 執行時腳本會自動設定）
chmod 755 /home/ai3/ai3_service.sh

# 首次執行後會自動建立捷徑
~/.local/bin/ai3-service
```

---

## 使用方式

### 互動式選單（預設）

```bash
./ai3_service.sh
# 或（安裝捷徑後）
ai3-service
```

執行後顯示所有服務狀態，並提供選單選擇服務與操作。

### CLI 命令列模式

```bash
# 語法
./ai3_service.sh {start|stop|status|restart} {服務名稱|all}

# 範例
./ai3_service.sh status all          # 查看所有服務狀態
./ai3_service.sh start ecp           # 啟動 ecp 服務
./ai3_service.sh stop gateway        # 停止 gateway 服務
./ai3_service.sh restart ecp         # 重啟 ecp 服務
./ai3_service.sh start all           # 啟動所有服務
```

### 監控模式（-m 參數）

```bash
./ai3_service.sh -m ecp              # 直接查詢單一服務狀態後退出
```

### 指定使用者（-u 參數）

```bash
./ai3_service.sh -u qs6user          # 以其他使用者身份執行
```

---

## 命令參數說明

| 參數 | 說明 | 預設值 |
|------|------|--------|
| `-u <user>` | 指定執行使用者，同時調整 ServiceDir | `ai3` |
| `-m <service>` | 監控指定服務狀態，輸出後立即退出 | — |
| `start \| stop \| status \| restart` | 直接操作命令 | — |
| `{service_name} \| all` | 指定服務實例或全部 | — |

---

## 郵件告警設定

腳本內建 `mail()` 函式，服務停止時可觸發告警信。  
需修改腳本中以下設定（建議改為讀取環境變數或外部設定檔）：

```bash
# 位於腳本 mail() 函式內
--url      "smtps://your.mailserver.com:465"   # SMTP 伺服器
--user     "user@example.com:password"          # 寄件帳密
--mail-from "sender@example.com"               # 寄件人
--mail-rcpt "admin@example.com"                # 收件人
```

> ⚠️ **注意**：預設 `alert_flag=false`，告警功能未啟用。  
> 若需啟用，請在腳本頂部將 `alert_flag=false` 改為 `alert_flag=true`。

---

## 腳本行為說明

### 啟動流程（`qs_start`）
1. 以 `pgrep` 確認服務是否已在執行
2. 確認 `server.sh` 存在
3. `cd` 至服務目錄後以 `nohup` 背景啟動
4. Spinner 動畫等待最多 10 秒，確認 PID 出現
5. 逾時則提示查看 `nohup.out`

### 停止流程（`qs_stop`）
1. 取得 PID，發送 `SIGTERM`（優雅終止）
2. Spinner 動畫等待最多 10 秒
3. 若 10 秒後仍在執行，改發 `SIGKILL`

---

## 注意事項

- 腳本以 root 執行時會自動 `chown` 並 `chmod 755` 自身，接著切換至目標使用者。
- 服務目錄名稱須符合命名 regex，否則不會被偵測。
- 每個服務目錄下必須存在 `server.sh`，否則啟動失敗。
- 郵件告警的帳號密碼目前寫死在腳本中，正式環境建議改為讀取 `.env` 或 Vault。

---

## 版本資訊

| 項目 | 內容 |
|------|------|
| 腳本名稱 | `ai3_service.sh` |
| 維護者 | LeoYu |
| 適用平台 | RHEL / Rocky Linux |
| App Server | Apache Tomcat / JBoss |
