#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260210

# flag=0代表未通過;1代表通過
flag="./.GCBflag"
> "$flag"
log="./GCB_check_rhel8.log"
> "$log"

log_append() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" | tee -a "$log"
}

set_flag() {
    echo "$1=$2" >> "$flag"
}

# ======================================
# TWGCB-01-008-0001
# cramfs檔案系統需設定為停用
# 1. 檢查 kernel 是否支援 cramfs
if ! modinfo cramfs &>/dev/null && ! lsmod | grep -q "^cramfs"; then
    log_append "[TWGCB-01-008-0001][PASS] cramfs not available in kernel."
    set_flag flag_001 1
# 2. kernel 支援但已停用
elif grep -q "^install cramfs /bin/true" /etc/modprobe.d/cramfs.conf 2>/dev/null; then
    log_append "[TWGCB-01-008-0001][PASS] cramfs is disabled via modprobe."
    set_flag flag_001 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-008-0001][FAIL] cramfs is available but not disabled."
    set_flag flag_001 0
    # 檢查是否已載入
    if lsmod | grep -q "^cramfs"; then
        log_append "[TWGCB-01-008-0001][CRITICAL] cramfs module is currently loaded!"
    fi
fi
# ======================================
# TWGCB-01-008-0002
# squashfs檔案系統需設定為停用
SQUASHFS_CONF="/etc/modprobe.d/squashfs.conf"
# 1. 檢查 kernel 是否支援 squashfs
if ! modinfo squashfs &>/dev/null && ! lsmod | grep -q "^squashfs"; then
    log_append "[TWGCB-01-008-0002][PASS] squashfs not available in kernel."
    set_flag flag_002 1
# 2. kernel 支援但已停用
elif grep -qE "^install squashfs /bin/(true|false)" "$SQUASHFS_CONF" 2>/dev/null; then
    log_append "[TWGCB-01-008-0002][PASS] squashfs is disabled via modprobe."
    set_flag flag_002 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-008-0002][FAIL] squashfs is available but not disabled."
    set_flag flag_002 0
    # 檢查是否已載入
    if lsmod | grep -q "^squashfs"; then
        log_append "[TWGCB-01-008-0002][CRITICAL] squashfs module is currently loaded!"
        # 顯示掛載點
        log_append "[TWGCB-01-008-0002][CRITICAL] Mounted squashfs filesystems:$(mount | grep squashfs)"
    fi
fi
# ======================================
# TWGCB-01-008-0003
# udf檔案系統需設定為停用
UDF_CONF="/etc/modprobe.d/udf.conf"
# 1. 檢查 kernel 是否支援 UDF
if ! modinfo udf &>/dev/null && ! lsmod | grep -q "^udf"; then
    log_append "[TWGCB-01-008-0003][PASS] udf not available in kernel."
    set_flag flag_003 1
# 2. kernel 支援但已停用
elif grep -qE "^install udf /bin/(true|false)" "$UDF_CONF" 2>/dev/null; then
    log_append "[TWGCB-01-008-0003][PASS] udf is disabled via modprobe."
    set_flag flag_003 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-008-0003][FAIL] udf is available but not disabled."
    set_flag flag_003 0
    # 檢查是否已載入
    if lsmod | grep -q "^udf"; then
        log_append "[TWGCB-01-008-0003][CRITICAL] udf module is currently loaded!"
        # 顯示掛載點
        log_append "[TWGCB-01-008-0003][CRITICAL] Mounted udf filesystems:$(mount | grep udf)"
    fi
fi
# ======================================
# TWGCB-01-008-0004
# 設定/tmp目錄需為tmpfs
if mount | grep -qE "^tmpfs.*/tmp\s"; then
    log_append "[TWGCB-01-008-0004][PASS] /tmp is mounted as tmpfs"
    set_flag flag_004 1
elif findmnt -n -o FSTYPE /tmp 2>/dev/null | grep -q "tmpfs"; then
    log_append "[TWGCB-01-008-0004][PASS] /tmp is mounted as tmpfs"
    set_flag flag_004 1
else
    log_append "[TWGCB-01-008-0004][FAIL] /tmp is NOT mounted as tmpfs , is \"$(stat -f -c %T /tmp)\""
    set_flag flag_004 0
fi
# ======================================
# TWGCB-01-008-0005
# /tmp目錄之nodev選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-008-0005][PASS] nodev option is enabled on /tmp"
    set_flag flag_005 1
else
    log_append "[TWGCB-01-008-0005][FAIL] nodev option is NOT enabled on /tmp"
    set_flag flag_005 0
fi
# ======================================
# TWGCB-01-008-0006
# tmp目錄之nosuid選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-008-0006][PASS] nosuid option is enabled on /tmp"
    set_flag flag_006 1
else
    log_append "[TWGCB-01-008-0006][FAIL] nosuid option is NOT enabled on /tmp"
    set_flag flag_006 0
fi
# ======================================
# TWGCB-01-008-0007
# tmp目錄之noexec選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-008-0007][PASS] noexec option is enabled on /tmp"
    set_flag flag_007 1
else
    log_append "[TWGCB-01-008-0007][FAIL] noexec option is NOT enabled on /tmp"
    set_flag flag_007 0
fi
# ======================================
# TWGCB-01-008-0008
# 需為/var配置獨立之分割磁區或邏輯磁區
if findmnt /var &>/dev/null; then
    log_append "[TWGCB-01-008-0008][PASS] /var is a separate partition"
    findmnt /var
    set_flag flag_008 1
else
    log_append "[TWGCB-01-008-0008][FAIL] /var is NOT a separate partition"
    set_flag flag_008 0
fi
# ======================================
# TWGCB-01-008-0009
# 需為/var/tmp配置獨立之分割磁區或邏輯磁區
if findmnt /var/tmp &>/dev/null; then
    log_append "[TWGCB-01-008-0009][PASS] /var/tmp is a separate partition"
    findmnt /var/tmp
    set_flag flag_009 1
else
    log_append "[TWGCB-01-008-0009][FAIL] /var/tmp is NOT a separate partition"
    set_flag flag_009 0
fi
# ======================================

echo
grep -E 'FAIL|CRITICAL' "$log"