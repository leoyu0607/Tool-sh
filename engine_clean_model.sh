#!/bin/bash

BASE_DIR="/home/ai3/AI_Engine/ic/server/model"
DIRS=($(find "$BASE_DIR" -mindepth 2 -maxdepth 2 -type d))
LOG_FILE=/home/ai3/model_delete.log
#> /home/ai3/rm.txt

for dir in "${DIRS[@]}"; do
    echo "處理資料夾: $dir"
    cd "$dir" || continue

    # 找出所有符合格式的檔案與目錄
    mapfile -t all_items < <(ls -1tr | grep -E '^[0-9]{17}(_model|_report|_model\.zip)$')

    # 擷取批次前綴（前 17 碼）
    batch_list=()
    for item in "${all_items[@]}"; do
        prefix="${item:0:17}"
        batch_list+=("$prefix")
    done

    # 保留最新兩組批次
    mapfile -t keep_batches < <(printf "%s\n" "${batch_list[@]}" | awk '!seen[$0]++' | tail -n 2)

    # 建立要保留的完整檔名列表
    keep_patterns=()
    for prefix in "${keep_batches[@]}"; do
        keep_patterns+=("${prefix}_model")
        keep_patterns+=("${prefix}_report")
        keep_patterns+=("${prefix}_model.zip")
    done

    # 逐一檢查是否該刪除
    for item in "${all_items[@]}"; do
        skip=false
        for keep in "${keep_patterns[@]}"; do
            [[ "$item" == "$keep" ]] && skip=true && break
        done

        if [ "$skip" = false ] && [ -e "$item" ] && [ $(find "$item" -mtime +7 | wc -l) -gt 0 ]; then
            echo "$(date +"%Y/%m/%d %H:%M:%S ")刪除：$dir/$item" >> $LOG_FILE
            rm -rf "$item"
        fi
    done
done
