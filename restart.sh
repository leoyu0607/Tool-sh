#!/bin/bash

name="ecp"

# Tomcat 的目錄
ECP_HOME="/home/ecp/$name/apache-tomcat"

# 尋找並殺死 Tomcat 的執行緒
TOMCAT_PID=$(ps aux | grep "$ECP_HOME" | grep -v grep | awk '{print $2}')

if [ -n "$TOMCAT_PID" ]; then
    echo "Killing $name process with PID: $TOMCAT_PID"
    kill -9 $TOMCAT_PID
else
    echo "$name is not running."
fi

sleep 10

# 啟動 Tomcat
echo "Starting Tomcat..."
cd /home/ecp/$name/ ; nohup ./server.sh >/dev/null 2>&1 &
TOMCAT_PID=$(ps aux | grep "$ECP_HOME" | grep -v grep | awk '{print $2}')
echo "$name is running with PID:$TOMCAT_PID"

echo "$name started."
