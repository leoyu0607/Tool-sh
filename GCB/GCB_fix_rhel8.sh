#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260210

flag="./.GCBflag"
source "$flag"
log="./GCB_fix_rhel8.log"
> "$log"

log_append() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" | tee -a "$log"
}

set_flag() {
    sed -i "s/$1=0/$1=1/g" "$flag"
}

# ======================================
# TWGCB-01-008-0001
# cramfs檔案系統需設定為停用
if [ $flag_001 -eq 0 ]; then
    echo "install cramfs /bin/true" | sudo tee /etc/modprobe.d/cramfs.conf
    echo "blacklist cramfs" | sudo tee -a /etc/modprobe.d/cramfs.conf
    sudo dracut -f
    set_flag flag_001
    log_append "[TWGCB-01-008-0001][FIX] disable the cramfs"
fi
# ======================================
# TWGCB-01-008-0002
# squashfs檔案系統需設定為停用
if [ $flag_002 -eq 0 ]; then
    SQUASHFS_CONF="/etc/modprobe.d/squashfs.conf"
    echo "install squashfs /bin/true" | sudo tee "$SQUASHFS_CONF"
    echo "blacklist squashfs" | sudo tee -a "$SQUASHFS_CONF"
    sudo dracut -f
    set_flag flag_002
    log_append "[TWGCB-01-008-0002][FIX] disable the squashfs"
fi
# ======================================
# TWGCB-01-008-0003
# udf檔案系統需設定為停用
if [ $flag_003 -eq 0 ]; then
    UDF_CONF="/etc/modprobe.d/udf.conf"
    echo "install udf /bin/true" | sudo tee "$UDF_CONF"
    echo "blacklist udf" | sudo tee -a "$UDF_CONF"
    sudo dracut -f
    set_flag flag_003
    log_append "[TWGCB-01-008-0003][FIX] disable the udf"
fi
# ======================================
# TWGCB-01-008-0004
# 設定/tmp目錄需為tmpfs
if [ $flag_004 -eq 0 ]; then
    systemctl enable --now tmp.mount
    log_append "[TWGCB-01-008-0004][FIX] set /tmp mounted as tmpfs"
fi
# ======================================
# TWGCB-01-008-0005
# /tmp目錄之nodev選項須設定為啟用
if [ $flag_005 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    log_append "[TWGCB-01-008-0005][FIX] set /tmp option as nodev"
fi
# ======================================
# TWGCB-01-008-0006
# /tmp目錄之nosuid選項須設定為啟用
if [ $flag_006 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    log_append "[TWGCB-01-008-0006][FIX] set /tmp option as nosuid"
fi
# ======================================
# TWGCB-01-008-0007
# /tmp目錄之noexec選項須設定為啟用
if [ $flag_007 -eq 0 ]; then
    #sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev,noexec/" /usr/lib/systemd/system/tmp.mount
    #sudo systemctl daemon-reload
    #sudo systemctl restart tmp.mount
    #log_append "[TWGCB-01-008-0007][FIX] set /tmp option as noexec"
    log_append "[TWGCB-01-008-0007][IGNORE] 設定後影響服務使用"
fi
# ======================================
# TWGCB-01-008-0008
# 需為/var配置獨立之分割磁區或邏輯磁區
if [ $flag_008 -eq 0 ]; then
    log_append "[TWGCB-01-008-0008][IGNORE] 需要重建VM"
fi
# ======================================
# TWGCB-01-008-0009
# 需為/var配置獨立之分割磁區或邏輯磁區
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-008-0009][IGNORE] 需要重建VM"
fi
# ======================================
