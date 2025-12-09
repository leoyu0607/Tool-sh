#!/bin/bash

# for twlife cbm&pm2

LOG="/home/ecp/ai3_resource_monitor.log"
INTERVAL=10 # 執行間隔per second
MAX_LOG_SIZE=$((100 * 1024 * 1024)) # 100MB
MAX_LOG_ARCHIVES=5 #Log檔數量上限
touch $LOG
chmod 664 $LOG

#Log輪轉
rotate_logs() {
    if [[ -f "${LOG}.${MAX_LOG_ARCHIVES}.gz" ]]; then
        rm -f "${LOG}.${MAX_LOG_ARCHIVES}.gz"
    fi

    local i
    for ((i = MAX_LOG_ARCHIVES - 1; i >= 1; i--)); do
        if [[ -f "${LOG}.${i}.gz" ]]; then
            mv "${LOG}.${i}.gz" "${LOG}.$((i + 1)).gz"
        fi
    done

    if [[ -f "$LOG" ]]; then
        gzip -c "$LOG" > "${LOG}.1.gz"
        : > "$LOG"
    fi
}

#判斷是否輪轉
maybe_rotate_logs() {
    if [[ -f "$LOG" ]]; then
        local size
        size=$(stat -c%s "$LOG")
        if (( size >= MAX_LOG_SIZE )); then
            rotate_logs
        fi
    fi
}

#Log寫入，等同echo，但可視需求增加在每次Log寫入時的執行的動作
log_append() {
    #maybe_rotate_logs
    printf "%s\n" "$1" >> "$LOG"
}

#監控PM2資源使用狀況
pm2_resource_monitor() {
    log_append "$timestamp [PM2] resource usage by PM2:"
    pm2 jlist | jq -r '
        .[] |
        "\(.name) : CPU=\(.monit.cpu)% , RAM=\(((.monit.memory/1024/1024) * 100 | round) / 100 | tostring)MB"
    '
}
cpu_top5_processes() {
    log_append "$timestamp [CPU] Top 5 processes by CPU:"
    ps -eo pid,comm,%cpu --sort=-%cpu | head -n 6 | tail -n 5 | awk '{printf("PID: %s, Command: %s, CPU: %s%%\n", $1, $2, $3)}'
}
ram_top5_processes() {
    log_append "$timestamp [RAM] Top 5 processes by RAM:"
    ps -eo pid,comm,rss --sort=-rss | head -n 6 | tail -n 5 | awk '{printf("PID: %s, Command: %s, RAM: %.2f MB\n", $1, $2, $3/1024)}'
}
#記錄當下可用記憶體
log_available_memory() {
    local available
    available=$(awk '/MemAvailable/ { printf("%.2f MB", $2 / 1024) }' /proc/meminfo)
    log_append "$timestamp [RAM] Available memory: $available"
}

while true; do
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    # 抓取所有 PM2 APP 的 CPU / RAM
    pm2_resource_monitor | while read -r line; do
        log_append "$timestamp [PM2] $line"
    done
    # 抓取 CPU Top 5
    cpu_top5_processes | while read -r line; do
        log_append "$timestamp [CPU] $line"
    done
    # 抓取 RAM Top 5
    ram_top5_processes | while read -r line; do
        log_append "$timestamp [RAM] $line"
    done
    log_available_memory
    log_append "----------------------------------------"
    maybe_rotate_logs
    sleep $INTERVAL
done
