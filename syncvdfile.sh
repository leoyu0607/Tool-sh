#!/bin/bash

SOURCE_DIR="/vd/"
DEST_DIR="/home/gwdocker/gw/share_attachment/vd/"
OWNER="ai3:ai3"
INTERVAL=10  # 每 10 秒執行一次
LOG_FILE="/home/gwdocker/sync_vd.log"  # 記錄 log 檔案

# 確保 log 檔案存在
touch "$LOG_FILE"

while true; do
    TIMESTAMP=$(date "+%Y-%m-%d %H:%M:%S")
    echo "[$TIMESTAMP] 開始檢查資料夾..." | tee -a "$LOG_FILE"

    # 檢查是否有未完成的檔案傳輸
    if lsof +D "$SOURCE_DIR" > /dev/null 2>&1; then
        echo "[$TIMESTAMP] 檔案仍在傳輸中，等待中..." | tee -a "$LOG_FILE"
    else
        echo "[$TIMESTAMP] 開始同步檔案..." | tee -a "$LOG_FILE"
        rsync -avu --progress "$SOURCE_DIR/" "$DEST_DIR/" | tee -a "$LOG_FILE"

        echo "[$TIMESTAMP] 變更擁有者為 $OWNER..." | tee -a "$LOG_FILE"
        chown -R "$OWNER" "$DEST_DIR"

        echo "[$TIMESTAMP] 同步完成，已變更權限。" | tee -a "$LOG_FILE"
    fi
    
    echo "[$TIMESTAMP] 休眠 $INTERVAL 秒後繼續檢查..." | tee -a "$LOG_FILE"
    sleep "$INTERVAL"
done

