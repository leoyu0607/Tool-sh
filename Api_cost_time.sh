#!/bin/bash

url="http://gump.taiiwanlife.com/GumpTsapiInfo/GetFreeAgent"
logFile="/home/ecp/GumpTech_FreeAgent.log"

while true; do
    timestamp=$(date +"%Y-%m-%d %H:%M:%S")
    response=$(curl -s -w "%{http_code} %{time_total}" -o /dev/null "$url")
    http_code=$(awk '{print $1}' <<< "$response")
    time_spent=$(awk '{print $2}' <<< "$response")
    
    if [ "$http_code" -eq 200 ]; then
        echo "[$timestamp] Success: Received HTTP 200 from $url in $time_spent seconds" >> "$logFile"
    else
        echo "[$timestamp] Error: Received HTTP $http_code from $url in $time_spent seconds" >> "$logFile"
    fi
    
    sleep 0.1  # Wait for 0.1 seconds before the next check
done
exit 0