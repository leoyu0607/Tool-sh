#!/bin/bash

#設定安裝目錄位置
dir="/home/ecp/"
#執行前磁碟大小
disk_before=$(df -k "$dir" | awk 'NR==2 {print $3}')
#備份目錄位置
backup="/home/ecp/backup/"
#服務名稱
service_name="ecp"

#備份服務
mkdir -p $backup
tar --wildcards -czvf ${backup}${service_name}_$(date +"%Y%m%d")_bak.tar.gz --exclude=${dir}${service_name}/apache-tomcat/logs/* --exclude=${dir}${service_name}/apache-tomcat/extension/*/log/* --exclude=${dir}${service_name}/tool/sql ${dir}${service_name}/
#清除超過半年的備份
find ${backup} -type f -mtime +180 -exec rm -f {} \;
#清除超過三個月的log
find ${dir}${service_name}/apache-tomcat/extension/*/log -type d -mtime +90 -exec rm -rf {} \;
#執行後磁碟大小
disk_after=$(df -k "$dir" | awk 'NR==2 {print $3}')

freed_kb=$((disk_before - disk_after))
KB=1024
MB=$((KB * 1024))

if (( freed_kb > MB )); then
    freed=$(awk -v kb=$freed_kb -v MB="$MB" 'BEGIN {printf "%.2f", kb/MB}')
    unit="GB"
elif (( freed_kb > KB )); then
    freed=$(awk -v kb=$freed_kb -v KB="$KB" 'BEGIN {printf "%.2f", kb/KB}')
    unit="MB"
else
    freed=$freed_kb
    unit="KB"
fi

#將系統資訊寫入maintain.log
touch ${dir}${service_name}/maintain.log
: > ${dir}${service_name}/maintain.log
echo "=== Disk Usage ===" >> ${dir}${service_name}/maintain.log
df -h >> ${dir}${service_name}/maintain.log
echo "=== Memory Usage ===" >> ${dir}${service_name}/maintain.log
free -h >> ${dir}${service_name}/maintain.log
echo "=== Top Processes ===" >> ${dir}${service_name}/maintain.log
top -b -n 1 | head -n 5 >> ${dir}${service_name}/maintain.log
echo "=== Clean Disk ===" >> ${dir}${service_name}/maintain.log
echo "Freed up space: ${freed} ${unit}" >> ${dir}${service_name}/maintain.log
clear
cat ${dir}${service_name}/maintain.log