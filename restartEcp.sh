#!/bin/bash

read -p "User name:" user
read -p "Service name:" name

# Tomcat 的目錄
ECP_HOME="/home/$user/$name/apache-tomcat"

# 尋找並殺死 Tomcat 的執行緒
TOMCAT_PID=$(ps aux | grep "$ECP_HOME" | grep -v grep | awk '{print $2}')

if [ -n "$TOMCAT_PID" ]; then
    echo "Killing $name process with PID: $TOMCAT_PID"
	if [ $(whoami) == "$user" ]; then
		kill -9 $TOMCAT_PID
	else
		su - $user -c "kill -9 ${TOMCAT_PID}"
	fi
	sleep 10
else
    echo "$name is not running."
	sleep 2
fi

# 啟動 Tomcat
echo "Starting Tomcat..."
if [ $(whoami) == "$user" ]; then
		cd /home/$user/$name/ ; nohup ./server.sh >/dev/null 2>&1 &
	else
		su - $user -c "cd /home/${user}/${name}/ ; nohup ./server.sh >/dev/null 2>&1 &"
fi

sleep 5

TOMCAT_PID=$(ps aux | grep "$ECP_HOME" | grep -v grep | awk '{print $2}')
echo "$name is running with PID:$TOMCAT_PID"

echo "$name started."
