#!/bin/bash
#  2020/5/20 13:50 create by Ray
#  
#  用  ps -eLF | grep ecp  | wc -l 取得 ecp帳號的執行續數量, 並記錄在檔案以觀察其變化, 可以使用croontab 每分鐘執行一次
#  若超過告警值, 嘗試呼叫 jcmd <pid> GC.run 去清除thread
#
#####Script Configuration#####
#_Script_Directory=`pwd`
_ScriptDirectory="/home/ecp/logThreadCount_ecp"
_ScriptLogs_Directory=$_ScriptDirectory/log
_ScriptTmp=$_ScriptDirectory/tmp
_ScriptLogs_File=check.log
# 一般user應該只有 1024 , 可以使用ulimit -a 查詢 max user processes
# 目前觀察到每分鐘可能會增加60個thread , _Script_Threshold 可以設定 max user processes 的70~80%
_ScriptThreshold=1500
_ScriptCsv=ecp_thread_count.txt
_ScriptThread_list=threads.txt
_IsSaveJstack=N
_JdkBinPath=/home/ecp/java-1.8.0-open/

#echo "[`date +%Y%m%d%H%M%S`] The script start..." >> $_Script_Logs_Directory/`date +%Y%m%d`-$_Script_Logs_File

#Create folder and checking folder
if [ ! -d $_ScriptDirectory ];then
        mkdir -p $_ScriptDirectory
fi
if [ ! -d $_ScriptLogs_Directory ];then
        mkdir -p $_ScriptLogs_Directory
fi
if [ ! -d $_ScriptTmp ];then
        mkdir -p $_ScriptTmp
fi
_thread_cnt=`ps -eLF | grep ecp/ | grep -v grep | wc -l`
echo "`date '+%Y-%m-%d,%H:%M:%S'`,$_thread_cnt" >> $_ScriptLogs_Directory/`date +%Y%m%d`-$_ScriptCsv
