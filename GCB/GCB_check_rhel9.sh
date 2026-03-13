#!/bin/bash
# This script checks if the operating system is RHEL 9
##version:GCB_v1.0

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# flag=0代表未通過;1代表通過;2代表不適用或無法檢查
flag="./.GCBflag"
> "$flag"
log="./GCB_check_rhel9.log"
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
# TWGCB-01-012-0001
# cramfs檔案系統需設定為停用
# 1. 檢查 kernel 是否支援 cramfs
if ! modinfo cramfs &>/dev/null && ! lsmod | grep -q "^cramfs"; then
    log_append "[TWGCB-01-012-0001][PASS] cramfs not available in kernel."
    set_flag flag_001 1
# 2. kernel 支援但已停用
elif grep -q "^install cramfs /bin/true" /etc/modprobe.d/cramfs.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0001][PASS] cramfs is disabled via modprobe."
    set_flag flag_001 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-012-0001][FAIL] cramfs is available but not disabled."
    set_flag flag_001 0
    # 檢查是否已載入
    if lsmod | grep -q "^cramfs"; then
        log_append "[TWGCB-01-012-0001][CRITICAL] cramfs module is currently loaded!"
    fi
fi
# ======================================
# TWGCB-01-012-0002
# squashfs檔案系統需設定為停用
SQUASHFS_CONF="/etc/modprobe.d/squashfs.conf"
# 1. 檢查 kernel 是否支援 squashfs
if ! modinfo squashfs &>/dev/null && ! lsmod | grep -q "^squashfs"; then
    log_append "[TWGCB-01-012-0002][PASS] squashfs not available in kernel."
    set_flag flag_002 1
# 2. kernel 支援但已停用
elif grep -qE "^install squashfs /bin/(true|false)" "$SQUASHFS_CONF" 2>/dev/null; then
    log_append "[TWGCB-01-012-0002][PASS] squashfs is disabled via modprobe."
    set_flag flag_002 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-012-0002][FAIL] squashfs is available but not disabled."
    set_flag flag_002 0
    # 檢查是否已載入
    if lsmod | grep -q "^squashfs"; then
        log_append "[TWGCB-01-012-0002][CRITICAL] squashfs module is currently loaded!"
        log_append "[TWGCB-01-012-0002][CRITICAL] Mounted squashfs filesystems:$(mount | grep squashfs)"
    fi
fi
# ======================================
# TWGCB-01-012-0003
# udf檔案系統需設定為停用
UDF_CONF="/etc/modprobe.d/udf.conf"
# 1. 檢查 kernel 是否支援 UDF
if ! modinfo udf &>/dev/null && ! lsmod | grep -q "^udf"; then
    log_append "[TWGCB-01-012-0003][PASS] udf not available in kernel."
    set_flag flag_003 1
# 2. kernel 支援但已停用
elif grep -qE "^install udf /bin/(true|false)" "$UDF_CONF" 2>/dev/null; then
    log_append "[TWGCB-01-012-0003][PASS] udf is disabled via modprobe."
    set_flag flag_003 1
# 3. kernel 支援但未停用
else
    log_append "[TWGCB-01-012-0003][FAIL] udf is available but not disabled."
    set_flag flag_003 0
    # 檢查是否已載入
    if lsmod | grep -q "^udf"; then
        log_append "[TWGCB-01-012-0003][CRITICAL] udf module is currently loaded!"
        log_append "[TWGCB-01-012-0003][CRITICAL] Mounted udf filesystems:$(mount | grep udf)"
    fi
fi
# ======================================
# TWGCB-01-012-0004
# 設定/tmp目錄需為tmpfs
if mount | grep -qE "^tmpfs.*/tmp\s"; then
    log_append "[TWGCB-01-012-0004][PASS] /tmp is mounted as tmpfs"
    set_flag flag_004 1
elif findmnt -n -o FSTYPE /tmp 2>/dev/null | grep -q "tmpfs"; then
    log_append "[TWGCB-01-012-0004][PASS] /tmp is mounted as tmpfs"
    set_flag flag_004 1
else
    log_append "[TWGCB-01-012-0004][FAIL] /tmp is NOT mounted as tmpfs , is \"$(stat -f -c %T /tmp)\""
    set_flag flag_004 0
fi
# ======================================
# TWGCB-01-012-0005
# /tmp目錄之nodev選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-012-0005][PASS] nodev option is enabled on /tmp"
    set_flag flag_005 1
else
    log_append "[TWGCB-01-012-0005][FAIL] nodev option is NOT enabled on /tmp"
    set_flag flag_005 0
fi
# ======================================
# TWGCB-01-012-0006
# /tmp目錄之nosuid選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-012-0006][PASS] nosuid option is enabled on /tmp"
    set_flag flag_006 1
else
    log_append "[TWGCB-01-012-0006][FAIL] nosuid option is NOT enabled on /tmp"
    set_flag flag_006 0
fi
# ======================================
# TWGCB-01-012-0007
# /tmp目錄之noexec選項須設定為啟用
if findmnt -n -o OPTIONS /tmp 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-012-0007][PASS] noexec option is enabled on /tmp"
    set_flag flag_007 1
else
    log_append "[TWGCB-01-012-0007][FAIL] noexec option is NOT enabled on /tmp"
    set_flag flag_007 0
fi
# ======================================
# TWGCB-01-012-0008
# 需為/var配置獨立之分割磁區或邏輯磁區
if findmnt /var &>/dev/null; then
    log_append "[TWGCB-01-012-0008][PASS] /var is a separate partition"
    findmnt /var
    set_flag flag_008 1
else
    log_append "[TWGCB-01-012-0008][FAIL] /var is NOT a separate partition"
    set_flag flag_008 0
fi
# ======================================
# TWGCB-01-012-0009
# 需為/var/tmp配置獨立之分割磁區或邏輯磁區
if findmnt /var/tmp &>/dev/null; then
    log_append "[TWGCB-01-012-0009][PASS] /var/tmp is a separate partition"
    findmnt /var/tmp
    set_flag flag_009 1
else
    log_append "[TWGCB-01-012-0009][FAIL] /var/tmp is NOT a separate partition"
    set_flag flag_009 0
fi
# ======================================
# TWGCB-01-012-0010
# /var/tmp須設定nodev選項
# 相依TWGCB-01-012-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-012-0010][SKIP] /var/tmp is not a separate partition, skipping nodev check"
    set_flag flag_010 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-012-0010][PASS] nodev option is enabled on /var/tmp"
    set_flag flag_010 1
else
    log_append "[TWGCB-01-012-0010][FAIL] nodev option is NOT enabled on /var/tmp"
    set_flag flag_010 0
fi


echo
grep -E 'FAIL|CRITICAL' "$log"
# ======================================
# 結果統計
log_append "========================================"
log_append "檢查結果統計:"
log_append "通過(PASS): $pass"
log_append "失敗(FAIL): $fail"
log_append "跳過(SKIP): $skip"
log_append "========================================"
echo "Log saved to: $log"
echo "Flag file saved to: $flag"
