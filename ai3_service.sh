#!/bin/bash

## Ai3 QS Service Management Script For Apache-Tomcat/JBOSS Based Services by LeoYu
#變數宣告
User="ai3"
ServiceDir="/home/$User/"
AppServerType=""
service=()
count=1

#change user via command line argument
while getopts "u:" opt; do
    case $opt in
        u)
            User="$OPTARG"
            ServiceDir="/home/$User/"
            ;;
        *)
            echo "Invalid option: -$OPTARG" >&2
            exit 1
            ;;
    esac
done

# spinner characters used for start/stop animation
sp="|/-\\"

# Only change ownership when running as root (avoid failures for non-root users)
if [ "$(id -u)" -eq 0 ]; then
    chown "$User":"$User" "$0"
    chmod 755 "$0"
fi
# Ensure running as ai3 user(or any defined user)
if [ "$(whoami)" != "$User" ]; then
    exec sudo su - "$User" -c "$0"
fi
# Detect available services
if [ -d "$ServiceDir" ]; then
    for d in "$ServiceDir"/* ; do
        ServiceName=$(basename "$d")
        if [[ "$ServiceName" =~ (ecp|gateway|cbe|cbm|[Mm]edia[Pp]roxy) ]]; then
            service+=("$ServiceName")
        fi
    done
else
    echo "Any Ai3 service does not exist."
    exit 1
fi

# check Application Server Type=JBOSS/Apache-tomcat
if [  ${#service[@]} -eq 0 ]; then
    echo "No Ai3 service found in $ServiceDir"
    exit 1
else
    shopt -s nullglob
    for d in "$ServiceDir${service[0]}"/* ; do
        ServerType=$(basename "$d")
        if [[ "$ServerType" =~ (apache-tomcat|jboss) ]]; then
            AppServerType="$ServerType"
        fi
    done

    shopt -u nullglob
    echo "Server Type=$AppServerType"
fi

#qs_status function to check service status
qs_status() {
    local service_name=$1
    local pids
    # pgrep returns non-zero when no process is found; capture safely
    pids=$(pgrep -f "$ServiceDir$service_name/$AppServerType" || true)
    if [ -n "$pids" ]; then
        echo "$service_name service is running (PIDs: $pids)"
    else
        echo "$service_name service is not running"
    fi
}
#qs_start function to start service
qs_start() {
    local service_name=$1
    local pids
    local timeout=10
    local elapsed=0
    local idx=0
    pids=$(pgrep -f "$ServiceDir$service_name/$AppServerType" || true)
    if [ -n "$pids" ]; then
        echo "$service_name service is already running (PIDs: $pids)"
    else
        if [ ! -f "${ServiceDir}${service_name}/server.sh" ]; then
        echo "Can not find file: ${ServiceDir}${service_name}/server.sh"
        exit 1
        fi
        echo "$ServiceDir$service_name/server.sh"
        cd "${ServiceDir}${service_name}/" && echo "change directory to ${ServiceDir}${service_name}/" || return 1
        echo "Now Path: $(pwd)"
        nohup "${ServiceDir}${service_name}/server.sh" >/dev/null 2>&1 &
        echo "Starting $service_name service..."
        while [ $elapsed -lt $timeout ] && [ -z "$pids" ]; do
            printf "\r %s Starting..." "${sp:idx:1}"
            sleep 0.5
            idx=$(( (idx + 1) % ${#sp} ))
            elapsed=$((elapsed + 1))
            pids=$(pgrep -f "$ServiceDir$service_name/$AppServerType" || true)
        done
        if qs_status "$service_name" | grep -q "is not running"; then
            echo "$service_name service failed to start"
            return 1
        else
            pids=$(pgrep -f "$ServiceDir$service_name/$AppServerType" || true)
            if [ -n "$pids" ]; then
                echo "$service_name service started successfully (PIDs: $pids)"
                return 0
            fi
            sleep 1
            waited=$((waited + 1))
        fi
        if [ -z "$pids" ]; then
            echo "$service_name service failed to start after ${max_wait}s; check ${ServiceDir}${service_name}/nohup.out for details"
            return 1
        fi
    fi
}
#qs_stop function to stop service
qs_stop() {
    local service_name=$1
    local pids
    local timeout=10
    local elapsed=0
    local idx=0
    pids=$(pgrep -f "$ServiceDir$service_name/$AppServerType" || true)
    if [ -n "$pids" ]; then
        echo "Stopping $service_name service (PIDs: $pids)..."
        # Try graceful termination first
        kill $pids 2>/dev/null || true
        # Wait for process to exit, show spinner
        while [ $elapsed -lt $timeout ] && pgrep -f "$ServiceDir$service_name/$AppServerType" >/dev/null 2>&1; do
            printf "\r %s Stopping..." "${sp:idx:1}"
            sleep 0.5
            idx=$(( (idx + 1) % ${#sp} ))
            elapsed=$((elapsed + 1))
        done
        # If still running after timeout, force kill
        if pgrep -f "$ServiceDir$service_name/$AppServerType" >/dev/null 2>&1; then
            echo
            echo "Graceful stop timed out; sending SIGKILL..."
            for pid in $pids; do
                kill -9 "$pid" 2>/dev/null || true
            done
            sleep 1
        fi
        if qs_status "$service_name" | grep -q "is running"; then
            echo "Failed to stop $service_name service"
        else
            echo
            echo "$service_name service stopped successfully"
        fi
    else
        echo "$service_name service is not running"
    fi
}
while true; do
    clear
    echo "=============================="
    # Display status of all services
    for svc in "${service[@]}"; do
        qs_status "$svc"
    done
    echo "=============================="
    echo "請選擇要操作的服務："
    printf "[%s] %s " "0" "Exit"
    for svc in "${service[@]}"; do
        printf "[%s] %s " "$count" "$svc"
        ((count++))
    done
    count=1
    echo
    read -rp "輸入服務編號: " svc_index
    if [ "$svc_index" -eq 0 ]; then
        exit 0
    fi
    selected_service=${service[$svc_index-1]}
    if [ -z "$selected_service" ]; then
        echo "無效的服務編號。"
        exit 1
    fi
    clear
    echo "您選擇的服務是: $selected_service"
    echo "請選擇操作："
    echo "[0] 退出"
    echo "[1] 啟動服務"
    echo "[2] 停止服務"
    echo "[3] 確認服務狀態"
    read -rp "輸入操作編號: " action_index
    case $action_index in
        1)
            qs_start "$selected_service"
            read -rp "Press Enter to continue..."
            ;;
        2)
            qs_stop "$selected_service"
            read -rp "Press Enter to continue..."
            ;;
        3)
            qs_status "$selected_service"
            read -rp "Press Enter to continue..."
            ;;
        0)
            exit 0
            ;;
        *)
            echo "無效的操作編號。"
            exit 1
            ;;
    esac
done
exit 0