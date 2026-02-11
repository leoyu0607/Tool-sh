#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260210

# flag=0代表未通過;1代表通過;2代表不適用或無法檢查
flag="./.GCBflag"
> "$flag"
log="./GCB_check_rhel8.log"
> "$log"

pass=0
fail=0
skip=0

log_append() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" | tee -a "$log"
}

set_flag() {
    if [  $2 -eq 1 ]; then
        eval "$1=$2"
        echo "$1=$2" >> "$flag"
        pass=$((pass + 1))
    elif [ $2 -eq 2 ]; then
        eval "$1=$2"
        echo "$1=$2" >> "$flag"
        skip=$((skip + 1))
    else
        eval "$1=$2"
        echo "$1=$2" >> "$flag"
        fail=$((fail + 1))
    fi
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
# TWGCB-01-008-0010
# /var/tmp須設定nodev選項
# 相依TWGCB-01-008-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-008-0010][SKIP] /var/tmp is not a separate partition, skipping nodev check"
    set_flag flag_010 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-008-0010][PASS] nodev option is enabled on /var/tmp"
    set_flag flag_010 1
else
    log_append "[TWGCB-01-008-0010][FAIL] nodev option is NOT enabled on /var/tmp"
    set_flag flag_010 0
fi
# ======================================
# TWGCB-01-008-0011
# /var/tmp須設定nosuid選項
# 相依TWGCB-01-008-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-008-0011][SKIP] /var/tmp is not a separate partition, skipping nosuid check"
    set_flag flag_011 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-008-0011][PASS] nosuid option is enabled on /var/tmp"
    set_flag flag_011 1
else
    log_append "[TWGCB-01-008-0011][FAIL] nosuid option is NOT enabled on /var/tmp"
    set_flag flag_011 0
fi
# ======================================
# TWGCB-01-008-0012
# /var/tmp須設定noexec選項
# 相依TWGCB-01-008-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-008-0012][SKIP] /var/tmp is not a separate partition, skipping noexec check"
    set_flag flag_012 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-008-0012][PASS] noexec option is enabled on /var/tmp"
    set_flag flag_012 1
else
    log_append "[TWGCB-01-008-0012][FAIL] noexec option is NOT enabled on /var/tmp"
    set_flag flag_012 0
fi
# ======================================
# TWGCB-01-008-0013
# 需為/var/log配置獨立之分割磁區或邏輯磁區
if findmnt /var/log &>/dev/null; then
    log_append "[TWGCB-01-008-0013][PASS] /var/log is a separate partition"
    findmnt /var/log
    set_flag flag_013 1
else
    log_append "[TWGCB-01-008-0013][FAIL] /var/log is NOT a separate partition"
    set_flag flag_013 0
fi
# ======================================
# TWGCB-01-008-0014
# 需為/var/log/audit配置獨立之分割磁區或邏輯磁區
if findmnt /var/log/audit &>/dev/null; then
    log_append "[TWGCB-01-008-0014][PASS] /var/log/audit is a separate partition"
    findmnt /var/log/audit
    set_flag flag_014 1
else
    log_append "[TWGCB-01-008-0014][FAIL] /var/log/audit is NOT a separate partition"
    set_flag flag_014 0
fi
# ======================================
# TWGCB-01-008-0015
# 需為/home配置獨立之分割磁區或邏輯磁區
if findmnt /home &>/dev/null; then
    log_append "[TWGCB-01-008-0015][PASS] /home is a separate partition"
    findmnt /home
    set_flag flag_015 1
else
    log_append "[TWGCB-01-008-0015][FAIL] /home is NOT a separate partition"
    set_flag flag_015 0
fi
# ======================================
# TWGCB-01-008-0016
# /home須設定nodev選項
# 相依TWGCB-01-008-0015
if [ $flag_015 -eq 0 ]; then
    log_append "[TWGCB-01-008-0016][SKIP] /home is not a separate partition, skipping nodev check"
    set_flag flag_016 2
elif findmnt -n -o OPTIONS /home 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-008-0016][PASS] nodev option is enabled on /home"
    set_flag flag_016 1
else
    log_append "[TWGCB-01-008-0016][FAIL] nodev option is NOT enabled on /home"
    set_flag flag_016 0
fi
# ======================================
# ======================================

echo
#grep -E 'FAIL|CRITICAL' "$log"
echo "Summary: $pass checks passed, $fail checks failed, $skip checks skipped."