#!/bin/bash

BASE_DIR="/home/admin_ai3/cbm/apache-tomcat/extension/cbm/attachment/SmartQA"
LOG=/home/admin_ai3/cbm/clean_model.log

# 對每個 SmartQA 子目錄進行處理
for case_dir in "$BASE_DIR"/*/; do
    echo "$(date +"%Y/%m/%d %H:%M:%S ")處理：$case_dir" >> "$LOG"

    # 處理 model 目錄中的 .zip
    if [ -d "${case_dir}model" ]; then
        mapfile -t zips < <(find "${case_dir}model" -maxdepth 1 -type f -name '*.zip' -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
        if [ "${#zips[@]}" -gt 2 ]; then
	        for ((i=2; i<${#zips[@]}; i++)); do
        		to_delete+=("${zips[i]}")
    		done  # 排除前兩個(保留前2個元素，從第3個開始加入陣列to_delete)
	        for file in "${to_delete[@]}"; do
	            if [ -f "$file" ] && find "$file" -mtime +7 -print -quit | grep -q .; then
	                echo "$(date +"%Y/%m/%d %H:%M:%S ")刪除 zip: $file" >> "$LOG"
	                rm -f "$file"
	            fi
	        done
	    fi
    fi

    # 處理 train 目錄中的 .json
    if [ -d "${case_dir}train" ]; then
        mapfile -t jsons < <(find "${case_dir}train" -maxdepth 1 -type f -name '*.json' -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
        if [ "${#jsons[@]}" -gt 2 ]; then
	        for ((i=2; i<${#jsons[@]}; i++)); do
        		to_delete+=("${jsons[i]}")
    		done
	        for file in "${to_delete[@]}"; do
	            if [ -f "$file" ] && find "$file" -mtime +7 -print -quit | grep -q .; then
	                echo "$(date +"%Y/%m/%d %H:%M:%S ")刪除 json: $file" >> "$LOG"
	                rm -f "$file"
	            fi
	        done
	    fi
    fi

    # 處理 report 目錄中的子資料夾
    if [ -d "${case_dir}report" ]; then
        mapfile -t reports < <(find "${case_dir}report" -mindepth 2 -maxdepth 2 -type d -printf "%T@ %p\n" | sort -nr | cut -d' ' -f2-)
        if [ "${#reports[@]}" -gt 2 ]; then
	        for ((i=2; i<${#reports[@]}; i++)); do
        		to_delete+=("${reports[i]}")
    		done
	        for dir in "${to_delete[@]}"; do
	            if [ -d "$dir" ] && find "$dir" -mtime +7 -print -quit | grep -q .; then
	                echo "$(date +"%Y/%m/%d %H:%M:%S ")刪除 report 目錄: $dir" >> "$LOG"
	                rm -rf "$dir"
	            fi
	        done
	    fi
    fi
done