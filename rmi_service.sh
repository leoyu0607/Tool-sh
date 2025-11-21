#!/bin/bash

#儲存rmi服務pid
cc_server_home="/home/rmi/apache-tomcat/bin/"
rmi_pid="./rmi.pid"

#使用rmi帳號
[ $(whoami) == "rmi" ] || su - rmi

#背景啟動服務
start_service() {
	if pgrep -f "$cc_server_home" >/dev/null ; then
        echo "cc-server service is running (PID: $(pgrep -f "$cc_server_home"))"
        return
    fi
    if [[ -f "$rmi_pid" ]] && kill -0 "$(cat "$rmi_pid")" 2>/dev/null; then
        echo "rmi service is running (PID: $(cat "$rmi_pid"))"
        return
    fi
	#啟動cc-server
	nohup ./cc-server.sh start >/dev/null 2>&1 &
	#echo $! > "$cc_server_pid"
    sleep 5
	echo "cc-server service start successful (PID: $(pgrep -f "$cc_server_home"))"
	#啟動rmi服務
	nohup ./rmi >/dev/null 2>&1 &
	echo $! > "$rmi_pid"
	echo "rmi service start successful (PID: $(cat "$rmi_pid"))"
}

#關閉服務
stop_service() {
	local pid
	#cc-server
	if pgrep -f "$cc_server_home" >/dev/null ; then
        #kill -9 "$pid"
        #rm -f "$cc_server_pid"
        ./cc-server.sh stop >/dev/null
        echo "cc-server service stop"
    else
    	echo "cc-server service is not running"
    fi
    #rmi
	if [[ -f "$rmi_pid" ]] ; then
		pid=$(<"$rmi_pid")
		if kill -0 "$pid" 2>/dev/null; then
        	kill -9 "$pid"
        	rm -f "$rmi_pid"
        	echo "rmi service stop"
    	else
    		echo "rmi service is not running"
    		rm -f "$rmi_pid"
    	fi
    else
        echo "rmi pid file not found"
    fi
}

#確認狀態
status_service() {
	#cc-server
    #if [[ -f "$cc_server_pid" ]] && kill -0 "$(cat "$cc_server_pid")" 2>/dev/null; then
    #    echo "cc-server service is running (PID: $(cat "$cc_server_pid"))"
    #else
    #    echo "cc-server service is not running"
    #fi
    if pgrep -f "$cc_server_home" >/dev/null ; then
        echo "cc-server service is running (PID: $(pgrep -f "$cc_server_home"))"
    else
        echo "cc-server service is not running"
    fi
    #rmi
    if [[ -f "$rmi_pid" ]] && kill -0 "$(cat "$rmi_pid")" 2>/dev/null; then
        echo "rmi service is running (PID: $(cat "$rmi_pid"))"
    else
        echo "rmi service is not running"
    fi
}

#main
case "$1" in
  start) start_service ;;
  stop) stop_service ;;
  status) status_service ;;
  *)
    echo "Example: $0 {start|stop|status}"
    ;;
esac