#!/bin/bash

# 創建一個臨時文件來保存結果
temp_file=$(mktemp)

for file in /proc/[0-9]*/status; do
    pid=$(echo "$file" | grep -oE '[0-9]+')
    swap=$(grep VmSwap "$file" | awk '{print $2}')
    if [ -n "$swap" ] && [ "$swap" -gt 0 ]; then
        swap_mb=$(echo "scale=2; $swap/1024" | bc)
        process=$(ps -p "$pid" -o comm=)
        # 將結果寫入臨時文件
        echo "$swap_mb MB $pid $process" >> "$temp_file"
    fi
done

# 根據 swap 大小進行排序並輸出
sort -nrk 1 "$temp_file"

# 刪除臨時文件
rm "$temp_file"
