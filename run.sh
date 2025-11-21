#!/bin/bash
#  2020/5/20 13:50 create by Ray
#  
#  用  ps -eLF | grep ecp  | wc -l 取得 ecp帳號的執行續數量, 並記錄在檔案以觀察其變化, 可以使用croontab 每分鐘執行一次
#  若超過告警值, 嘗試呼叫 jcmd <pid> GC.run 去清除thread
#
#####Script Configuration#####
#_Script_Directory=`pwd`
_Script_Directory="/home/ecp/logThreadCount"
_Script_Logs_Directory=$_Script_Directory/log
_Script_Tmp=$_Script_Directory/tmp
_Script_Logs_File=check.log
# 一般user應該只有 1024 , 可以使用ulimit -a 查詢 max user processes
# 目前觀察到每分鐘可能會增加60個thread , _Script_Threshold 可以設定 max user processes 的70~80%
_Script_Threshold=1500
_Script_Csv=thread_count.txt
_Script_Thread_list=threads.txt
_IsSaveJstack=N
_JdkBinPath=/home/ecp/java-1.8.0-open/

#echo "[`date +%Y%m%d%H%M%S`] The script start..." >> $_Script_Logs_Directory/`date +%Y%m%d`-$_Script_Logs_File

#Create folder and checking folder
if [ ! -d $_Script_Directory ];then
        mkdir -p $_Script_Directory
fi
if [ ! -d $_Script_Logs_Directory ];then
        mkdir -p $_Script_Logs_Directory
fi
if [ ! -d $_Script_Tmp ];then
        mkdir -p $_Script_Tmp
fi
_threadcnt=`ps -eLF | grep ecp/cbm | grep -v grep | wc -l`
echo "`date '+%Y-%m-%d,%H:%M:%S'`,$_threadcnt" >> $_Script_Logs_Directory/`date +%Y%m%d`-$_Script_Csv

if [ $_threadcnt -gt $_Script_Threshold ];then
	#get ecp pid
        pid=`ps aux | grep "ecp/cbm" | grep -v grep | awk '{print $2}'`

	if [ "$_IsSaveJstack" == "Y" ];then
		$_JdkBinPath/jstack $pid > $_Script_Logs_Directory/$pid-jstack.`date +%Y%m%d`.txt
	fi
	echo "[`date +%Y%m%d%H%M%S`] run jcmd $pid GC.run" >> $_Script_Logs_Directory/`date +%Y%m%d`-$_Script_Logs_File

        $_JdkBinPath/jcmd $pid GC.run
	_threadcnt2=`ps -eLF | grep ecp/cbm | grep -v grep | wc -l`
	echo "[`date +%Y%m%d%H%M%S`] threadcnt from $_threadcnt to $_threadcnt2  " >> $_Script_Logs_Directory/`date +%Y%m%d`-$_Script_Logs_File
        
fi;

