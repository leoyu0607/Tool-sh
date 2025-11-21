#!/bin/bash

#設定安裝目錄位置
dir="/home/ecp/"
#執行前磁碟大小
disk_before=$(df -k "$dir" | awk 'NR==2 {print $3}')

#備份服務
mkdir -p ${dir}backup
tar czvf ${dir}backup/ecp_$(date +"%Y%m%d")_bak.tar.gz --exclude=${dir}/ecp/apache-tomcat/logs/* --exclude=${dir}/ecp/apache-tomcat/extension/ecp/log/* --exclude=${dir}/ecp/tool/sql ${dir}/ecp/

#清除超過半年的備份
find ${dir}backup -type f -mtime +180 -exec rm -f {} \;
#清除超過三個月的log
find ${dir}/ecp/apache-tomcat/extension/ecp/log -type d -mtime +90 -exec rm -rf {} \;

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
touch ${dir}/ecp/maintain.log
: > ${dir}/ecp/maintain.log
echo "=== Disk Usage ===" >> ${dir}/ecp/maintain.log
df -h >> ${dir}/ecp/maintain.log
echo "=== Memory Usage ===" >> ${dir}/ecp/maintain.log
free -h >> ${dir}/ecp/maintain.log
echo "=== Top Processes ===" >> ${dir}/ecp/maintain.log
top -b -n 1 | head -n 5 >> ${dir}/ecp/maintain.log
echo "=== Clean Disk ===" >> ${dir}/ecp/maintain.log
echo "Freed up space: ${freed} ${unit}" >> ${dir}/ecp/maintain.log
clear
cat ${dir}/ecp/maintain.log