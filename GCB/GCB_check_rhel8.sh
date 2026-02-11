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
# TWGCB-01-008-0017
# /dev/shm須設定nodev選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-008-0017][PASS] nodev option is enabled on /dev/shm"
    set_flag flag_017 1
else
    log_append "[TWGCB-01-008-0017][FAIL] nodev option is NOT enabled on /dev/shm"
    set_flag flag_017 0
fi
# ======================================
# TWGCB-01-008-0018
# /dev/shm須設定nosuid選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-008-0018][PASS] nosuid option is enabled on /dev/shm"
    set_flag flag_018 1
else
    log_append "[TWGCB-01-008-0018][FAIL] nosuid option is NOT enabled on /dev/shm"
    set_flag flag_018 0
fi
# ======================================
# TWGCB-01-008-0019
# /dev/shm須設定noexec選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-008-0019][PASS] noexec option is enabled on /dev/shm"
    set_flag flag_019 1
else
    log_append "[TWGCB-01-008-0019][FAIL] noexec option is NOT enabled on /dev/shm"
    set_flag flag_019 0
fi
# ======================================
# TWGCB-01-008-0020
# 可攜式儲存裝置須設定nodev選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-008-0020][PASS] no portable storage detected"
        set_flag flag_020 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_020 1
            log_append "[TWGCB-01-008-0020][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw nodev; then
                set_flag flag_020 1
                log_append "[TWGCB-01-008-0020][PASS] [$dev] nodev set"
            else
                set_flag flag_020 0
                log_append "[TWGCB-01-008-0020][FAIL] [$dev] nodev not set"
            fi
        done
    done
# ======================================
# TWGCB-01-008-0021
# 可攜式儲存裝置須設定nosuid選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-008-0021][PASS] no portable storage detected"
        set_flag flag_021 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_021 1
            log_append "[TWGCB-01-008-0021][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw nosuid; then
                set_flag flag_021 1
                log_append "[TWGCB-01-008-0021][PASS] [$dev] nosuid set"
            else
                set_flag flag_021 0
                log_append "[TWGCB-01-008-0021][FAIL] [$dev] nosuid not set"
            fi
        done
    done
# ======================================
# TWGCB-01-008-0022
# 可攜式儲存裝置須設定noexec選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-008-0022][PASS] no portable storage detected"
        set_flag flag_022 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_022 1
            log_append "[TWGCB-01-008-0022][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw noexec; then
                set_flag flag_022 1
                log_append "[TWGCB-01-008-0022][PASS] [$dev] noexec set"
            else
                set_flag flag_022 0
                log_append "[TWGCB-01-008-0022][FAIL] [$dev] noexec not set"
            fi
        done
    done
# ======================================
# TWGCB-01-008-0023
# 使用者家目錄須設定nodev選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-008-0023][PASS] No sub-mounts under /home"
    set_flag flag_023 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-008-0023][INFO] Found sub-mount: $mp"
    #檢查子目錄是否 nodev
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw nodev; then
        set_flag flag_023 1
        log_append "[TWGCB-01-008-0023][PASS] [$mp] nodev set"
    else
        set_flag flag_023 0
        log_append "[TWGCB-01-008-0023][FAIL] [$mp] nodev missing"
    fi
done
# ======================================
# TWGCB-01-008-0024
# 使用者家目錄須設定nosuid選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-008-0024][PASS] No sub-mounts under /home"
    set_flag flag_024 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-008-0024][INFO] Found sub-mount: $mp"
    #檢查子目錄是否 nosuid
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw nosuid; then
        set_flag flag_024 1
        log_append "[TWGCB-01-008-0024][PASS] [$mp] nosuid set"
    else
        set_flag flag_024 0
        log_append "[TWGCB-01-008-0024][FAIL] [$mp] nosuid missing"
    fi
done
# ======================================
# TWGCB-01-008-0025
# 使用者家目錄須設定noexec選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-008-0025][PASS] No sub-mounts under /home"
    set_flag flag_025 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-008-0025][INFO] Found sub-mount: $mp"
    #檢查子目錄是否 noexec
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw noexec; then
        set_flag flag_025 1
        log_append "[TWGCB-01-008-0025][PASS] [$mp] noexec set"
    else
        set_flag flag_025 0
        log_append "[TWGCB-01-008-0025][FAIL] [$mp] noexec missing"
    fi
done
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================
# ======================================

echo
#grep -E 'FAIL|CRITICAL' "$log"
echo "Summary: $pass checks passed, $fail checks failed, $skip checks skipped."