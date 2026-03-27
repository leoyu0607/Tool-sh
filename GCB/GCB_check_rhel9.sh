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


# ======================================
# TWGCB-01-012-0011
# /var/tmp須設定nosuid選項
# 相依TWGCB-01-012-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-012-0011][SKIP] /var/tmp is not a separate partition, skipping nosuid check"
    set_flag flag_011 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-012-0011][PASS] nosuid option is enabled on /var/tmp"
    set_flag flag_011 1
else
    log_append "[TWGCB-01-012-0011][FAIL] nosuid option is NOT enabled on /var/tmp"
    set_flag flag_011 0
fi
# ======================================
# TWGCB-01-012-0012
# /var/tmp須設定noexec選項
# 相依TWGCB-01-012-0009
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-012-0012][SKIP] /var/tmp is not a separate partition, skipping noexec check"
    set_flag flag_012 2
elif findmnt -n -o OPTIONS /var/tmp 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-012-0012][PASS] noexec option is enabled on /var/tmp"
    set_flag flag_012 1
else
    log_append "[TWGCB-01-012-0012][FAIL] noexec option is NOT enabled on /var/tmp"
    set_flag flag_012 0
fi
# ======================================
# TWGCB-01-012-0013
# 需為/var/log配置獨立之分割磁區或邏輯磁區
if findmnt /var/log &>/dev/null; then
    log_append "[TWGCB-01-012-0013][PASS] /var/log is a separate partition"
    findmnt /var/log
    set_flag flag_013 1
else
    log_append "[TWGCB-01-012-0013][FAIL] /var/log is NOT a separate partition"
    set_flag flag_013 0
fi
# ======================================
# TWGCB-01-012-0014
# 需為/var/log/audit配置獨立之分割磁區或邏輯磁區
if findmnt /var/log/audit &>/dev/null; then
    log_append "[TWGCB-01-012-0014][PASS] /var/log/audit is a separate partition"
    findmnt /var/log/audit
    set_flag flag_014 1
else
    log_append "[TWGCB-01-012-0014][FAIL] /var/log/audit is NOT a separate partition"
    set_flag flag_014 0
fi
# ======================================
# TWGCB-01-012-0015
# 需為/home配置獨立之分割磁區或邏輯磁區
if findmnt /home &>/dev/null; then
    log_append "[TWGCB-01-012-0015][PASS] /home is a separate partition"
    findmnt /home
    set_flag flag_015 1
else
    log_append "[TWGCB-01-012-0015][FAIL] /home is NOT a separate partition"
    set_flag flag_015 0
fi
# ======================================
# TWGCB-01-012-0016
# /home須設定nodev選項
# 相依TWGCB-01-012-0015
if [ $flag_015 -eq 0 ]; then
    log_append "[TWGCB-01-012-0016][SKIP] /home is not a separate partition, skipping nodev check"
    set_flag flag_016 2
elif findmnt -n -o OPTIONS /home 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-012-0016][PASS] nodev option is enabled on /home"
    set_flag flag_016 1
else
    log_append "[TWGCB-01-012-0016][FAIL] nodev option is NOT enabled on /home"
    set_flag flag_016 0
fi
# ======================================
# TWGCB-01-012-0017
# /dev/shm須設定nodev選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q nodev; then
    log_append "[TWGCB-01-012-0017][PASS] nodev option is enabled on /dev/shm"
    set_flag flag_017 1
else
    log_append "[TWGCB-01-012-0017][FAIL] nodev option is NOT enabled on /dev/shm"
    set_flag flag_017 0
fi
# ======================================
# TWGCB-01-012-0018
# /dev/shm須設定nosuid選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q nosuid; then
    log_append "[TWGCB-01-012-0018][PASS] nosuid option is enabled on /dev/shm"
    set_flag flag_018 1
else
    log_append "[TWGCB-01-012-0018][FAIL] nosuid option is NOT enabled on /dev/shm"
    set_flag flag_018 0
fi
# ======================================
# TWGCB-01-012-0019
# /dev/shm須設定noexec選項
if findmnt -n -o OPTIONS /dev/shm 2>/dev/null | grep -q noexec; then
    log_append "[TWGCB-01-012-0019][PASS] noexec option is enabled on /dev/shm"
    set_flag flag_019 1
else
    log_append "[TWGCB-01-012-0019][FAIL] noexec option is NOT enabled on /dev/shm"
    set_flag flag_019 0
fi
# ======================================
# TWGCB-01-012-0020
# 可攜式儲存裝置須設定nodev選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-012-0020][PASS] no portable storage detected"
        set_flag flag_020 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_020 1
            log_append "[TWGCB-01-012-0020][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw nodev; then
                set_flag flag_020 1
                log_append "[TWGCB-01-012-0020][PASS] [$dev] nodev set"
            else
                set_flag flag_020 0
                log_append "[TWGCB-01-012-0020][FAIL] [$dev] nodev not set"
            fi
        done
    done
# ======================================
# TWGCB-01-012-0021
# 可攜式儲存裝置須設定nosuid選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-012-0021][PASS] no portable storage detected"
        set_flag flag_021 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_021 1
            log_append "[TWGCB-01-012-0021][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw nosuid; then
                set_flag flag_021 1
                log_append "[TWGCB-01-012-0021][PASS] [$dev] nosuid set"
            else
                set_flag flag_021 0
                log_append "[TWGCB-01-012-0021][FAIL] [$dev] nosuid not set"
            fi
        done
    done
# ======================================
# TWGCB-01-012-0022
# 可攜式儲存裝置須設定noexec選項
usb_devs=$(lsblk -o NAME,TRAN -nr | awk '$2=="usb"{print $1}')
    if [ -z "$usb_devs" ]; then
        log_append "[TWGCB-01-012-0022][PASS] no portable storage detected"
        set_flag flag_022 1
    fi
    for dev in $usb_devs; do
        mounts=$(lsblk -nr -o MOUNTPOINT /dev/$dev | grep -v '^$')
        if [ -z "$mounts" ]; then
            set_flag flag_022 1
            log_append "[TWGCB-01-012-0022][PASS] [$dev] not mounted"
            continue
        fi
        for mp in $mounts; do
            opts=$(findmnt -no OPTIONS --target "$mp")
            if echo "$opts" | grep -qw noexec; then
                set_flag flag_022 1
                log_append "[TWGCB-01-012-0022][PASS] [$dev] noexec set"
            else
                set_flag flag_022 0
                log_append "[TWGCB-01-012-0022][FAIL] [$dev] noexec not set"
            fi
        done
    done
# ======================================
# TWGCB-01-012-0023
# 使用者家目錄須設定nodev選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-012-0023][PASS] No sub-mounts under /home"
    set_flag flag_023 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-012-0023][INFO] Found sub-mount: $mp"
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw nodev; then
        set_flag flag_023 1
        log_append "[TWGCB-01-012-0023][PASS] [$mp] nodev set"
    else
        set_flag flag_023 0
        log_append "[TWGCB-01-012-0023][FAIL] [$mp] nodev missing"
    fi
done
# ======================================
# TWGCB-01-012-0024
# 使用者家目錄須設定nosuid選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-012-0024][PASS] No sub-mounts under /home"
    set_flag flag_024 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-012-0024][INFO] Found sub-mount: $mp"
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw nosuid; then
        set_flag flag_024 1
        log_append "[TWGCB-01-012-0024][PASS] [$mp] nosuid set"
    else
        set_flag flag_024 0
        log_append "[TWGCB-01-012-0024][FAIL] [$mp] nosuid missing"
    fi
done
# ======================================
# TWGCB-01-012-0025
# 使用者家目錄須設定noexec選項
submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
if [ -z "$submounts" ]; then
    log_append "[TWGCB-01-012-0025][PASS] No sub-mounts under /home"
    set_flag flag_025 1
fi
for mp in $submounts; do
    log_append "[TWGCB-01-012-0025][INFO] Found sub-mount: $mp"
    opts=$(findmnt -n -o OPTIONS "$mp")
    if echo "$opts" | grep -qw noexec; then
        set_flag flag_025 1
        log_append "[TWGCB-01-012-0025][PASS] [$mp] noexec set"
    else
        set_flag flag_025 0
        log_append "[TWGCB-01-012-0025][FAIL] [$mp] noexec missing"
    fi
done
# ======================================
# TWGCB-01-012-0026
# NFS須設定nodev選項
nfs_mounts=$(findmnt -t nfs4,nfs -n -o TARGET)
if [ -z "$nfs_mounts" ]; then
    log_append "[TWGCB-01-012-0026][PASS] No NFS mounts detected"
    set_flag flag_026 1
else
    for mp in $nfs_mounts; do
        log_append "[TWGCB-01-012-0026][INFO] Found NFS mount: $mp"
        opts=$(findmnt -n -o OPTIONS "$mp")
        if echo "$opts" | grep -qw nodev; then
            set_flag flag_026 1
            log_append "[TWGCB-01-012-0026][PASS] [$mp] nodev set"
        else
            set_flag flag_026 0
            log_append "[TWGCB-01-012-0026][FAIL] [$mp] nodev missing"
        fi
    done
fi
# ======================================
# TWGCB-01-012-0027
# NFS須設定nosuid選項
nfs_mounts=$(findmnt -t nfs4,nfs -n -o TARGET)
if [ -z "$nfs_mounts" ]; then
    log_append "[TWGCB-01-012-0027][PASS] No NFS mounts detected"
    set_flag flag_027 1
else
    for mp in $nfs_mounts; do
        log_append "[TWGCB-01-012-0027][INFO] Found NFS mount: $mp"
        opts=$(findmnt -n -o OPTIONS "$mp")
        if echo "$opts" | grep -qw nosuid; then
            set_flag flag_027 1
            log_append "[TWGCB-01-012-0027][PASS] [$mp] nosuid set"
        else
            set_flag flag_027 0
            log_append "[TWGCB-01-012-0027][FAIL] [$mp] nosuid missing"
        fi
    done
fi
# ======================================
# TWGCB-01-012-0028
# NFS須設定noexec選項
nfs_mounts=$(findmnt -t nfs4,nfs -n -o TARGET)
if [ -z "$nfs_mounts" ]; then
    log_append "[TWGCB-01-012-0028][PASS] No NFS mounts detected"
    set_flag flag_028 1
else
    for mp in $nfs_mounts; do
        log_append "[TWGCB-01-012-0028][INFO] Found NFS mount: $mp"
        opts=$(findmnt -n -o OPTIONS "$mp")
        if echo "$opts" | grep -qw noexec; then
            set_flag flag_028 1
            log_append "[TWGCB-01-012-0028][PASS] [$mp] noexec set"
        else
            set_flag flag_028 0
            log_append "[TWGCB-01-012-0028][FAIL] [$mp] noexec missing"
        fi
    done
fi
# ======================================
# TWGCB-01-012-0029
# 所有具有全域寫入(World-writable)權限之目錄須設定粘滯位(Sticky bit)
dirs=$(find $(findmnt -rn -o TARGET -t ext4,xfs) -type d -perm -0002 ! -perm -1000 2>/dev/null)
if [ -n "$dirs" ]; then
    log_append "[TWGCB-01-012-0029][FAIL] Found world-writable directories without sticky bit:"
    echo "$dirs" | while read -r d; do
        log_append "[TWGCB-01-012-0029][INFO] $d"
    done
    set_flag flag_029 0
else
    log_append "[TWGCB-01-012-0029][PASS] No world-writable directories without sticky bit found"
    set_flag flag_029 1
fi
# ======================================
# TWGCB-01-012-0030
# 需停用autofs服務
if systemctl is-enabled autofs > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0030][FAIL] autofs service is enabled"
    set_flag flag_030 0
else
    log_append "[TWGCB-01-012-0030][PASS] autofs service is disabled"
    set_flag flag_030 1
fi
# ======================================
# TWGCB-01-012-0031
# 需停用USB儲存裝置
# 相依TWGCB-01-012-0020,TWGCB-01-012-0021,TWGCB-01-012-0022
if lsmod | grep -q '^usb_storage'; then
    log_append "[TWGCB-01-012-0031][FAIL] usb_storage module is loaded"
    set_flag flag_031 0
else
    if grep -R "blacklist usb-storage" /etc/modprobe.d/ > /dev/null 2>&1; then
        if grep -R "install usb-storage /bin/true" /etc/modprobe.d/ > /dev/null 2>&1; then
            log_append "[TWGCB-01-012-0031][PASS] usb-storage was disabled"
            set_flag flag_031 1
        else
            log_append "[TWGCB-01-012-0031][FAIL] usb-storage install override missing"
            set_flag flag_031 0
        fi
    else
        log_append "[TWGCB-01-012-0031][FAIL] usb-storage is not blacklisted"
        set_flag flag_031 0
    fi
fi
# ======================================
# TWGCB-01-012-0032
# 啟用GPG簽章驗證功能
t=1
check_gpg() {
    param=$1
    value_expected=1
    global_value=$(grep -E "^\s*$param\s*=" /etc/dnf/dnf.conf 2>/dev/null | tail -n1 | awk -F= '{print $2}' | tr -d ' ')
    if [ -z "$global_value" ]; then
        log_append "[TWGCB-01-012-0032][FAIL] $param not set in global config"
        t=0
    elif [ "$global_value" != "$value_expected" ]; then
        log_append "[TWGCB-01-012-0032][FAIL] Global $param=$global_value (expected 1)"
        t=0
    else
        log_append "[TWGCB-01-012-0032][PASS] Global $param=1"
    fi
    for repo in /etc/yum.repos.d/*.repo; do
        repo_value=$(grep -E "^\s*$param\s*=" "$repo" 2>/dev/null | tail -n1 | awk -F= '{print $2}' | tr -d ' ')
        if [ -z "$repo_value" ]; then
            log_append "[TWGCB-01-012-0032][FAIL] $param not set in repo $repo"
            t=0
        elif [ "$repo_value" != "$value_expected" ]; then
            log_append "[TWGCB-01-012-0032][FAIL] Repo $repo has $param=$repo_value (expected 1)"
            t=0
        else
            log_append "[TWGCB-01-012-0032][PASS] Repo $repo has $param=1"
        fi
    done
}
check_gpg gpgcheck
check_gpg localpkg_gpgcheck
if [ $t -eq 1 ]; then
    set_flag flag_032 1
else
    set_flag flag_032 0
fi
# ======================================
# TWGCB-01-012-0033
# 需安裝sudo套件
if rpm -q sudo &>/dev/null; then
    log_append "[TWGCB-01-012-0033][PASS] sudo package is installed"
    set_flag flag_033 1
else
    log_append "[TWGCB-01-012-0033][FAIL] sudo package is NOT installed"
    set_flag flag_033 0
fi
# ======================================
# TWGCB-01-012-0034
# 設定sudo指令使用pty(pseudo terminal，虛擬終端)
# 相依TWGCB-01-012-0033
if [ $flag_033 -eq 0 ]; then
    log_append "[TWGCB-01-012-0034][SKIP] sudo package is not installed, skipping pty check"
    set_flag flag_034 2
elif grep -Eq '^[[:space:]]*Defaults[[:space:]]+.*use_pty' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    log_append "[TWGCB-01-012-0034][PASS] sudo is configured to use pty"
    set_flag flag_034 1
else
    log_append "[TWGCB-01-012-0034][FAIL] sudo is NOT configured to use pty"
    set_flag flag_034 0
fi
# ======================================
# TWGCB-01-012-0035
# sudo自定義日誌檔案須設定為/var/log/sudo.log
# 相依TWGCB-01-012-0033
if [ $flag_033 -eq 0 ]; then
    log_append "[TWGCB-01-012-0035][SKIP] sudo package is not installed, skipping log file check"
    set_flag flag_035 2
elif grep -REq '^[[:space:]]*Defaults([^#\n]*,)?[[:space:]]*logfile[[:space:]]*=[[:space:]]*"?/var/log/sudo\.log"?([[:space:]]|,|$)' /etc/sudoers /etc/sudoers.d/* 2>/dev/null; then
    log_append "[TWGCB-01-012-0035][PASS] sudo is configured to use /var/log/sudo.log"
    set_flag flag_035 1
else
    log_append "[TWGCB-01-012-0035][FAIL] sudo is NOT configured to use /var/log/sudo.log"
    set_flag flag_035 0
fi
# ======================================
# TWGCB-01-012-0036
# 安裝AIDE套件
if rpm -q aide &>/dev/null; then
    log_append "[TWGCB-01-012-0036][PASS] AIDE package is installed"
    set_flag flag_036 1
else
    log_append "[TWGCB-01-012-0036][FAIL] AIDE package is NOT installed"
    set_flag flag_036 0
fi
# ======================================
# TWGCB-01-012-0037
# 定期檢查檔案系統完整性
# 相依TWGCB-01-012-0036
current="$(crontab -l 2>/dev/null || true)"
if [ $flag_036 -eq 0 ]; then
    log_append "[TWGCB-01-012-0037][SKIP] AIDE package is not installed, skipping cron job check"
    set_flag flag_037 2
elif printf "%s\n" "$current" | grep -Fq "aide --check"; then
    log_append "[TWGCB-01-012-0037][PASS] cron already exists"
    set_flag flag_037 1
else
    log_append "[TWGCB-01-012-0037][FAIL] No cron job found for AIDE integrity check"
    set_flag flag_037 0
fi
# ======================================
# TWGCB-01-012-0038
# 開機載入程式設定檔之所有權須為root:root
t=1
check_owner() {
    file=$1
    if [ -f "$file" ]; then
        owner=$(stat -c "%U:%G" "$file")
        if [ "$owner" != "root:root" ]; then
            log_append "[TWGCB-01-012-0038][FAIL] $file owner is $owner (expected root:root)"
            t=0
        else
            log_append "[TWGCB-01-012-0038][PASS] $file owner is root:root"
        fi
    else
        log_append "[TWGCB-01-012-0038][INFO] $file does not exist, skipping check"
    fi
}
check_owner /boot/grub2/grub.cfg
if [ -d /sys/firmware/efi ]; then
    check_owner /boot/efi/EFI/rhel/grub.cfg
fi
check_owner /boot/grub2/user.cfg
check_owner /boot/grub2/grubenv
if [ $t -eq 1 ]; then
    set_flag flag_038 1
else
    set_flag flag_038 0
fi
# ======================================
# TWGCB-01-012-0039
# 開機載入程式設定檔之權限須為600或更嚴格
t=1
check_permission() {
    file=$1
    if [ -f "$file" ]; then
        perm=$(stat -c "%a" "$file")
        if [ "$perm" -gt 600 ]; then
            log_append "[TWGCB-01-012-0039][FAIL] $file permission is $perm (expected 600 or more restrictive)"
            t=0
        else
            log_append "[TWGCB-01-012-0039][PASS] $file permission is $perm"
        fi
    else
        log_append "[TWGCB-01-012-0039][INFO] $file does not exist, skipping check"
    fi
}
check_permission /boot/grub2/grub.cfg
if [ -d /sys/firmware/efi ]; then
    check_permission /boot/efi/EFI/rhel/grub.cfg
fi
check_permission /boot/grub2/user.cfg
check_permission /boot/grub2/grubenv
if [ $t -eq 1 ]; then
    set_flag flag_039 1
else
    set_flag flag_039 0
fi
# ======================================
# TWGCB-01-012-0040
# 開機載入程式之通行碼
if [ -f /boot/grub2/grub.cfg ]; then
    if grep -Eq '^\s*set\s+superusers=' /boot/grub2/grub.cfg && grep -Eq '^\s*password_pbkdf2\s+' /boot/grub2/grub.cfg; then
        log_append "[TWGCB-01-012-0040][PASS] GRUB password is set"
        set_flag flag_040 1
    else
        log_append "[TWGCB-01-012-0040][FAIL] GRUB password is NOT set"
        set_flag flag_040 0
    fi
fi
# ======================================
# TWGCB-01-012-0041
# 單一使用者模式需啟用身分鑑別功能
t=1
for svc in rescue.service emergency.service; do
    if systemctl cat "$svc" 2>/dev/null | grep -q "systemd-sulogin-shell"; then
        log_append "[TWGCB-01-012-0041][PASS] $svc uses systemd-sulogin-shell for authentication"
    else
        log_append "[TWGCB-01-012-0041][FAIL] $svc does NOT use systemd-sulogin-shell for authentication"
        t=0
    fi
done
if [ $t -eq 1 ]; then
    set_flag flag_041 1
else
    set_flag flag_041 0
fi

# ======================================
# TWGCB-01-012-0042
# 停用核心傾印(Core dump)功能
check_core_dump_disabled() {
    local fail=0
    # 1) limits: * hard core 0
    if grep -RqsE '^\s*\*\s+hard\s+core\s+0\s*$' /etc/security/limits.conf /etc/security/limits.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0042][PASS] limits: '* hard core 0' is set"
    else
        log_append "[TWGCB-01-012-0042][FAIL] limits: missing '* hard core 0'"
        fail=1
    fi
    # 2) sysctl: fs.suid_dumpable = 0 (runtime)
    if [ "$(sysctl -n fs.suid_dumpable 2>/dev/null)" = "0" ]; then
        log_append "[TWGCB-01-012-0042][PASS] sysctl runtime: fs.suid_dumpable=0"
    else
        log_append "[TWGCB-01-012-0042][FAIL] sysctl runtime: fs.suid_dumpable != 0"
        fail=1
    fi
    # 3) sysctl: kernel.core_pattern = |/bin/false (runtime)
    if [ "$(sysctl -n kernel.core_pattern 2>/dev/null)" = "|/bin/false" ]; then
        log_append "[TWGCB-01-012-0042][PASS] sysctl runtime: kernel.core_pattern='|/bin/false'"
    else
        log_append "[TWGCB-01-012-0042][FAIL] sysctl runtime: kernel.core_pattern is not '|/bin/false'"
        fail=1
    fi
    # 4) 檢查 sysctl 設定檔是否能持久化（避免重開失效）
    if grep -RqsE '^\s*fs\.suid_dumpable\s*=\s*0\s*$' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0042][PASS] sysctl config: fs.suid_dumpable=0 present"
    else
        log_append "[TWGCB-01-012-0042][FAIL] sysctl config: fs.suid_dumpable=0 not found in config files"
        fail=1
    fi
    if grep -RqsE '^\s*kernel\.core_pattern\s*=\s*\|/bin/false\s*$' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0042][PASS] sysctl config: kernel.core_pattern='|/bin/false' present"
    else
        log_append "[TWGCB-01-012-0042][FAIL] sysctl config: kernel.core_pattern not found in config files"
        fail=1
    fi
    # 5) 若有 systemd-coredump.socket：確認 mask + coredump.conf
    if systemctl list-unit-files 2>/dev/null | grep -q '^systemd-coredump\.socket'; then
        if systemctl is-enabled systemd-coredump.socket 2>/dev/null | grep -q '^masked$'; then
            log_append "[TWGCB-01-012-0042][PASS] systemd-coredump.socket is masked"
        else
            log_append "[TWGCB-01-012-0042][FAIL] systemd-coredump.socket is not masked"
            fail=1
        fi
        if [ -f /etc/systemd/coredump.conf ] \
           && grep -qsE '^\s*Storage\s*=\s*none\s*$' /etc/systemd/coredump.conf \
           && grep -qsE '^\s*ProcessSizeMax\s*=\s*0\s*$' /etc/systemd/coredump.conf; then
            log_append "[TWGCB-01-012-0042][PASS] /etc/systemd/coredump.conf Storage=none & ProcessSizeMax=0"
        else
            log_append "[TWGCB-01-012-0042][FAIL] /etc/systemd/coredump.conf missing Storage=none or ProcessSizeMax=0"
            fail=1
        fi
    else
        log_append "[TWGCB-01-012-0042][INFO] systemd-coredump.socket not present (skip coredump service checks)"
    fi
    return $fail
}
if check_core_dump_disabled; then
    set_flag flag_042 1
else
    set_flag flag_042 0
fi
# ======================================
# TWGCB-01-012-0043
# 系統開機時是否需啟用記憶體位址空間配置隨機載入(Address space layout randomization, ASLR)功能
if grep -R '^\s*kernel\.randomize_va_space\s*=\s*2\s*$' /etc/sysctl.conf /etc/sysctl.d/*.conf >/dev/null 2>&1; then
    log_append "[TWGCB-01-012-0043][PASS] ASLR is enabled (kernel.randomize_va_space=2)"
    set_flag flag_043 1
else
    log_append "[TWGCB-01-012-0043][FAIL] ASLR is NOT enabled (kernel.randomize_va_space != 2)"
    set_flag flag_043 0
fi
# ======================================
# TWGCB-01-012-0044
# 設定全系統加密原則為FUTURE或FIPS
if grep -E -i '^\s*(FUTURE|FIPS)\s*(\s+#.*)?$' /etc/crypto-policies/config >/dev/null 2>&1; then
    log_append "[TWGCB-01-012-0044][PASS] System-wide crypto policy is set to FUTURE or FIPS"
    set_flag flag_044 1
else
    log_append "[TWGCB-01-012-0044][FAIL] System-wide crypto policy is NOT set to FUTURE or FIPS"
    set_flag flag_044 0
fi
# ======================================
# TWGCB-01-012-0045
# /etc/passwd檔案所有權需為root:root
file="/etc/passwd"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:root" ]; then
    set_flag flag_045 1
    log_append "[TWGCB-01-012-0045][PASS] $file owner is root:root"
else
    set_flag flag_045 0
    log_append "[TWGCB-01-012-0045][FAIL] $file owner is not root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0046
# /etc/passwd檔案權限需為644或更嚴格
file="/etc/passwd"
perm=$(stat -c "%a" "$file")
if [ "$perm" -le 644 ]; then
    set_flag flag_046 1
else
    set_flag flag_046 0
fi
# ======================================
# TWGCB-01-012-0047
# /etc/shadow檔案所有權需為root:shadow或是root:root
file="/etc/shadow"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:shadow" ] || [ "$owner" = "root:root" ]; then
    set_flag flag_047 1
    log_append "[TWGCB-01-012-0047][PASS] $file owner is root:shadow or root:root (current: $owner)"
else
    set_flag flag_047 0
    log_append "[TWGCB-01-012-0047][FAIL] $file owner is not root:shadow or root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0048
# /etc/shadow檔案權限需為000
file="/etc/shadow"
perm=$(stat -c "%a" "$file")
if [ "$perm" -eq 000 ]; then
    set_flag flag_048 1
    log_append "[TWGCB-01-012-0048][PASS] $file permission is 000"
else
    set_flag flag_048 0
    log_append "[TWGCB-01-012-0048][FAIL] $file permission is not 000 (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0049
# /etc/group檔案所有權需為root:root
file="/etc/group"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:root" ]; then
    set_flag flag_049 1
    log_append "[TWGCB-01-012-0049][PASS] $file owner is root:root"
else
    set_flag flag_049 0
    log_append "[TWGCB-01-012-0049][FAIL] $file owner is not root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0050
# /etc/group檔案權限需為644或更嚴格
file="/etc/group"
perm=$(stat -c "%a" "$file")
if [ "$perm" -le 644 ]; then
    set_flag flag_050 1
    log_append "[TWGCB-01-012-0050][PASS] $file permission is 644 or more restrictive (current: $perm)"
else
    set_flag flag_050 0
    log_append "[TWGCB-01-012-0050][FAIL] $file permission is not 644 or more restrictive (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0051
# /etc/gshadow檔案所有權需為root:shadow或是root:root
file="/etc/gshadow"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:shadow" ] || [ "$owner" = "root:root" ]; then
    set_flag flag_051 1
    log_append "[TWGCB-01-012-0051][PASS] $file owner is root:shadow or root:root (current: $owner)"
else
    set_flag flag_051 0
    log_append "[TWGCB-01-012-0051][FAIL] $file owner is not root:shadow or root:root (current: $owner)"
fi

# ======================================
# TWGCB-01-012-0052
# /etc/gshadow檔案權限需為000
file="/etc/gshadow"
perm=$(stat -c "%a" "$file")
if [ "$perm" -eq 000 ]; then
    set_flag flag_052 1
    log_append "[TWGCB-01-012-0052][PASS] $file permission is 000"
else
    set_flag flag_052 0
    log_append "[TWGCB-01-012-0052][FAIL] $file permission is not 000 (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0053
# /etc/passwd-檔案所有權需為root:root
file="/etc/passwd-"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:root" ]; then
    set_flag flag_053 1
    log_append "[TWGCB-01-012-0053][PASS] $file owner is root:root"
else
    set_flag flag_053 0
    log_append "[TWGCB-01-012-0053][FAIL] $file owner is not root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0054
# /etc/passwd-檔案權限需為600或更嚴格
file="/etc/passwd-"
perm=$(stat -c "%a" "$file")
if [ "$perm" -le 600 ]; then
    set_flag flag_054 1
    log_append "[TWGCB-01-012-0054][PASS] $file permission is 600 or more restrictive (current: $perm)"
else
    set_flag flag_054 0
    log_append "[TWGCB-01-012-0054][FAIL] $file permission is not 600 or more restrictive (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0055
# /etc/shadow-檔案所有權需為root:shadow或是root:root
file="/etc/shadow-"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:shadow" ] || [ "$owner" = "root:root" ]; then
    set_flag flag_055 1
    log_append "[TWGCB-01-012-0055][PASS] $file owner is root:shadow or root:root (current: $owner)"
else
    set_flag flag_055 0
    log_append "[TWGCB-01-012-0055][FAIL] $file owner is not root:shadow or root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0056
# /etc/shadow-檔案權限需為000
file="/etc/shadow-"
perm=$(stat -c "%a" "$file")
if [ "$perm" -eq 000 ]; then
    set_flag flag_056 1
    log_append "[TWGCB-01-012-0056][PASS] $file permission is 000"
else
    set_flag flag_056 0
    log_append "[TWGCB-01-012-0056][FAIL] $file permission is not 000 (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0057
# /etc/group-檔案所有權需為root:root
file="/etc/group-"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:root" ]; then
    set_flag flag_057 1
    log_append "[TWGCB-01-012-0057][PASS] $file owner is root:root"
else
    set_flag flag_057 0
    log_append "[TWGCB-01-012-0057][FAIL] $file owner is not root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0058
# /etc/group-檔案權限需為644或更嚴格
file="/etc/group-"
perm=$(stat -c "%a" "$file")
if [ "$perm" -le 644 ]; then
    set_flag flag_058 1
    log_append "[TWGCB-01-012-0058][PASS] $file permission is 644 or more restrictive (current: $perm)"
else
    set_flag flag_058 0
    log_append "[TWGCB-01-012-0058][FAIL] $file permission is not 644 or more restrictive (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0059
# /etc/gshadow-檔案所有權需為root:shadow或是root:root
file="/etc/gshadow-"
owner=$(stat -c "%U:%G" "$file")
if [ "$owner" = "root:shadow" ] || [ "$owner" = "root:root" ]; then
    set_flag flag_059 1
    log_append "[TWGCB-01-012-0059][PASS] $file owner is root:shadow or root:root (current: $owner)"
else
    set_flag flag_059 0
    log_append "[TWGCB-01-012-0059][FAIL] $file owner is not root:shadow or root:root (current: $owner)"
fi
# ======================================
# TWGCB-01-012-0060
# /etc/gshadow-檔案權限需為000
file="/etc/gshadow-"
perm=$(stat -c "%a" "$file")
if [ "$perm" -eq 000 ]; then
    set_flag flag_060 1
    log_append "[TWGCB-01-012-0060][PASS] $file permission is 000"
else
    set_flag flag_060 0
    log_append "[TWGCB-01-012-0060][FAIL] $file permission is not 000 (current: $perm)"
fi
# ======================================
# TWGCB-01-012-0061
# 其他使用者禁止寫入具有全域寫入(World-writable)權限的檔案
world_writable_files=$(find $(findmnt -rn -o TARGET -t ext4,xfs) -xdev -type f -perm -0002 2>/dev/null)
if [ -n "$world_writable_files" ]; then
    log_append "[TWGCB-01-012-0061][FAIL] Found world-writable files without sticky bit:"
    echo "$world_writable_files" | while read -r f; do
        log_append "[TWGCB-01-012-0061][INFO] File Path: $f"
    done
    set_flag flag_061 0
else
    log_append "[TWGCB-01-012-0061][PASS] No world-writable files without sticky bit found"
    set_flag flag_061 1
fi

# ======================================
# TWGCB-01-012-0062
# 檢查所有檔案與目錄擁有者是否皆為合法使用者
valid_uids=$(awk -F: '{print $3}' /etc/passwd)
invalid_uid_entries=$(
  while read -r mp; do
    find "$mp" -xdev -printf '%U %u %p\n'
  done < <(findmnt -rn -o TARGET -t ext4,xfs) \
  | awk 'NR==FNR{ok[$1]=1; next} !ok[$1]' <(printf "%s\n" "$valid_uids") - \
  | sort -u
)
if [ -n "$invalid_uid_entries" ]; then
    echo "$invalid_uid_entries" > /tmp/gcb_062_invalid_uid_entries.txt
    log_append "[TWGCB-01-012-0062][FAIL] Found files or directories owned by invalid users:"
    echo "$invalid_uid_entries" | while read -r userId userName fileName; do
        log_append "[TWGCB-01-012-0062][INFO] Invalid User Id: $userId, User Name: $userName, File Name: $fileName"
    done
    set_flag flag_062 0
else
    log_append "[TWGCB-01-012-0062][PASS] All files and directories have valid owners"
    set_flag flag_062 1
fi
# ======================================
# TWGCB-01-012-0063
# 檢查所有檔案與目錄擁有者是否皆為合法群組
valid_gids=$(awk -F: '{print $3}' /etc/group)
invalid_gid_entries=$(
  while read -r mp; do
    find "$mp" -xdev -printf '%G %g %p\n'
  done < <(findmnt -rn -o TARGET -t ext4,xfs) \
  | awk 'NR==FNR{ok[$1]=1; next} !ok[$1]' <(printf "%s\n" "$valid_gids") - \
  | sort -u
)
if [ -n "$invalid_gid_entries" ]; then
    echo "$invalid_gid_entries" > /tmp/gcb_063_invalid_gid_entries.txt
    log_append "[TWGCB-01-012-0063][FAIL] Found files or directories owned by invalid groups:"
    echo "$invalid_gid_entries" | while read -r groupId groupName fileName; do
        log_append "[TWGCB-01-012-0063][INFO] Invalid Group Id: $groupId, Group Name: $groupName, File Name: $fileName"
    done
    set_flag flag_063 0
else
    log_append "[TWGCB-01-012-0063][PASS] All files and directories have valid group owners"
    set_flag flag_063 1
fi
# ======================================
# TWGCB-01-012-0064
# 所有具有全域寫入權限的目錄擁有者需為root或其他系統帳號
invalid_world_writable_dirs=$(
  while read -r mp; do
    find "$mp" -xdev -type d -perm -0002 ! -perm -1000 -printf '%U %u %p\n'
  done < <(findmnt -rn -o TARGET -t ext4,xfs) \
  | awk '$1 >= 1000 {print $0}' \
  | sort -u
)
if [ -n "$invalid_world_writable_dirs" ]; then
    echo "$invalid_world_writable_dirs" > /tmp/gcb_064_invalid_world_writable_dirs.txt
    log_append "[TWGCB-01-012-0064][FAIL] Found world-writable directories owned by non-root and non-system accounts:"
    echo "$invalid_world_writable_dirs" | while read -r userId userName dirName; do
        log_append "[TWGCB-01-012-0064][INFO] World-writable Directory: $dirName, Owner User Id: $userId, Owner User Name: $userName"
    done
    set_flag flag_064 0
else
    log_append "[TWGCB-01-012-0064][PASS] All world-writable directories are owned by root or system accounts"
    set_flag flag_064 1
fi
# ======================================
# TWGCB-01-012-0065
# 所有具有全域寫入權限的目錄擁有群組需為root或其他系統群組
invalid_world_writable_dirs_groups=$(
  while read -r mp; do
    find "$mp" -xdev -type d -perm -0002 ! -perm -1000 -printf '%G %g %p\n'
  done < <(findmnt -rn -o TARGET -t ext4,xfs) \
  | awk '$1 >= 1000 {print $0}' \
  | sort -u
)
if [ -n "$invalid_world_writable_dirs_groups" ]; then
    echo "$invalid_world_writable_dirs_groups" > /tmp/gcb_065_invalid_world_writable_dirs_groups.txt
    log_append "[TWGCB-01-012-0065][FAIL] Found world-writable directories with group ownership of non-root and non-system groups:"
    echo "$invalid_world_writable_dirs_groups" | while read -r groupId groupName dirName; do
        log_append "[TWGCB-01-012-0065][INFO] World-writable Directory: $dirName, Owner Group Id: $groupId, Owner Group Name: $groupName"
    done
    set_flag flag_065 0
else
    log_append "[TWGCB-01-012-0065][PASS] All world-writable directories have group ownership of root or system groups"
    set_flag flag_065 1
fi
# ======================================
# TWGCB-01-012-0066
# 需設定系統命令檔案權限，使系統命令檔案具有755或更低權限
invalid_command_files=$(
  find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \
    -xdev -type f -perm /0022 -printf '%m %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_command_files" ]; then
    echo "$invalid_command_files" > /tmp/gcb_066_invalid_command_files.txt
    log_append "[TWGCB-01-012-0066][FAIL] Found executable files with permissions more permissive than 755"
    echo "$invalid_command_files" | while read -r perm fileName; do
        log_append "[TWGCB-01-012-0066][INFO] Command File: $fileName, Permission: $perm"
    done
    set_flag flag_066 0
else
    log_append "[TWGCB-01-012-0066][PASS] All executable files have permissions of 755 or more restrictive"
    set_flag flag_066 1
fi
# ======================================
# TWGCB-01-012-0067
# 需設定系統命令檔案權限，使系統命令檔案擁有者為root
invalid_command_files=$(
  find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \
    -xdev -type f ! -user root -printf '%U %u %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_command_files" ]; then
    log_append "[TWGCB-01-012-0067][FAIL] Found executable files not owned by root"
    echo "$invalid_command_files" | while read -r ownerId ownerName fileName; do
        log_append "[TWGCB-01-012-0067][INFO] Command File: $fileName, Owner User Id: $ownerId, Owner User Name: $ownerName"
    done
    set_flag flag_067 0
else
    log_append "[TWGCB-01-012-0067][PASS] All executable files are owned by root"
    set_flag flag_067 1
fi
# ======================================
# TWGCB-01-012-0068
# 需設定系統命令檔案權限，使系統命令檔案擁有群組為root
invalid_command_files=$(
  find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \
    -xdev -type f ! -group root ! -group tty ! -group slocate ! -group lock -printf '%G %g %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_command_files" ]; then
    log_append "[TWGCB-01-012-0068][FAIL] Found executable files not owned by root group"
    echo "$invalid_command_files" | while read -r groupId groupName fileName; do
        log_append "[TWGCB-01-012-0068][INFO] Command File: $fileName, Owner Group Id: $groupId, Owner Group Name: $groupName"
    done
    set_flag flag_068 0
else
    log_append "[TWGCB-01-012-0068][PASS] All executable files are owned by root group"
    set_flag flag_068 1
fi
# ======================================
# TWGCB-01-012-0069
# 需設定程式庫檔案權限，使程式庫檔案具有755或更低權限
invalid_library_files=$(
  find -L /lib /lib64 /usr/lib /usr/lib64 \
    -xdev -type f -perm /0022 -printf '%m %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_library_files" ]; then
    echo "$invalid_library_files" > /tmp/gcb_069_invalid_library_files.txt
    log_append "[TWGCB-01-012-0069][FAIL] Found library files with permissions more permissive than 755"
    echo "$invalid_library_files" | while read -r perm fileName; do
        log_append "[TWGCB-01-012-0069][INFO] Library File: $fileName, Permission: $perm"
    done
    set_flag flag_069 0
else
    log_append "[TWGCB-01-012-0069][PASS] All library files have permissions of 755 or more restrictive"
    set_flag flag_069 1
fi
# ======================================
# TWGCB-01-012-0070
# 需設定程式庫檔案權限，使程式庫檔案擁有者為root
invalid_library_files=$(
  find -L /lib /lib64 /usr/lib /usr/lib64 \
    -xdev -type f ! -user root -printf '%U %u %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_library_files" ]; then
    log_append "[TWGCB-01-012-0070][FAIL] Found library files not owned by root"
    echo "$invalid_library_files" | while read -r ownerId ownerName fileName; do
        log_append "[TWGCB-01-012-0070][INFO] Library File: $fileName, Owner User Id: $ownerId, Owner User Name: $ownerName"
    done
    set_flag flag_070 0
else
    log_append "[TWGCB-01-012-0070][PASS] All library files are owned by root"
    set_flag flag_070 1
fi
# ======================================
# TWGCB-01-012-0071
# 需設定程式庫檔案權限，使程式庫檔案擁有群組為root
invalid_library_files=$(
  find -L /lib /lib64 /usr/lib /usr/lib64 \
    -xdev -type f ! -group root -printf '%G %g %p\n' 2>/dev/null \
  | sort -u
)
if [ -n "$invalid_library_files" ]; then
    log_append "[TWGCB-01-012-0071][FAIL] Found library files not owned by root group"
    echo "$invalid_library_files" | while read -r groupId groupName fileName; do
        log_append "[TWGCB-01-012-0071][INFO] Library File: $fileName, Owner Group Id: $groupId, Owner Group Name: $groupName"
    done
    set_flag flag_071 0
else
    log_append "[TWGCB-01-012-0071][PASS] All library files are owned by root group"
    set_flag flag_071 1
fi

# ======================================
# TWGCB-01-012-0072
# 帳號不使用空白密碼
empty_password_users=$(awk -F: '($2 == "") {print $1}' /etc/shadow)
if [ -n "$empty_password_users" ]; then
    log_append "[TWGCB-01-012-0072][FAIL] Found accounts with empty passwords:"
    echo "$empty_password_users" | while read -r user; do
        log_append "[TWGCB-01-012-0072][INFO] User with empty password: $user"
    done
    set_flag flag_072 0
else
    log_append "[TWGCB-01-012-0072][PASS] No accounts with empty passwords found"
    set_flag flag_072 1
fi
# ======================================
# TWGCB-01-012-0073
# root帳號的路徑變數不包含「.」、「..」、路徑開頭不是「/」及空元素
path_fail=0
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
    if [ -z "$dir" ]; then
        log_append "[TWGCB-01-012-0073][FAIL] PATH contains empty element"
        path_fail=1
    elif [ "$dir" = "." ] || [ "$dir" = ".." ]; then
        log_append "[TWGCB-01-012-0073][FAIL] PATH contains relative path: $dir"
        path_fail=1
    elif [[ "$dir" != /* ]]; then
        log_append "[TWGCB-01-012-0073][FAIL] PATH contains path not starting with /: $dir"
        path_fail=1
    fi
done
if [ $path_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0073][PASS] root PATH does not contain relative or empty elements (PATH=$PATH)"
    set_flag flag_073 1
else
    log_append "[TWGCB-01-012-0073][FAIL] root PATH contains invalid elements (PATH=$PATH)"
    set_flag flag_073 0
fi
# ======================================
# TWGCB-01-012-0074
# root帳號的路徑變數不包含world-writable或group-writable目錄
path_writable_fail=0
IFS=':' read -ra PATH_DIRS <<< "$PATH"
for dir in "${PATH_DIRS[@]}"; do
    [ -z "$dir" ] && continue
    if [ -d "$dir" ]; then
        perms=$(stat -c "%a" "$dir")
        if [ $(( 8#${perms: -3} & 8#020 )) -ne 0 ]; then
            log_append "[TWGCB-01-012-0074][FAIL] PATH directory is group-writable: $dir (permission: $perms)"
            path_writable_fail=1
        fi
        if [ $(( 8#${perms: -3} & 8#002 )) -ne 0 ]; then
            log_append "[TWGCB-01-012-0074][FAIL] PATH directory is world-writable: $dir (permission: $perms)"
            path_writable_fail=1
        fi
    fi
done
if [ $path_writable_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0074][PASS] root PATH does not contain world-writable or group-writable directories"
    set_flag flag_074 1
else
    set_flag flag_074 0
fi
# ======================================
# TWGCB-01-012-0075
# /etc/passwd檔案行首的「+」符號需禁止
if grep -q '^\+:' /etc/passwd; then
    log_append "[TWGCB-01-012-0075][FAIL] /etc/passwd contains lines starting with '+'"
    grep '^\+:' /etc/passwd | while read -r line; do
        log_append "[TWGCB-01-012-0075][INFO] Found entry: $line"
    done
    set_flag flag_075 0
else
    log_append "[TWGCB-01-012-0075][PASS] /etc/passwd does not contain lines starting with '+'"
    set_flag flag_075 1
fi
# ======================================
# TWGCB-01-012-0076
# /etc/shadow檔案行首的「+」符號需禁止
if grep -q '^\+:' /etc/shadow; then
    log_append "[TWGCB-01-012-0076][FAIL] /etc/shadow contains lines starting with '+'"
    grep '^\+:' /etc/shadow | while read -r line; do
        log_append "[TWGCB-01-012-0076][INFO] Found entry: $line"
    done
    set_flag flag_076 0
else
    log_append "[TWGCB-01-012-0076][PASS] /etc/shadow does not contain lines starting with '+'"
    set_flag flag_076 1
fi
# ======================================
# TWGCB-01-012-0077
# /etc/group檔案行首的「+」符號需禁止
if grep -q '^\+:' /etc/group; then
    log_append "[TWGCB-01-012-0077][FAIL] /etc/group contains lines starting with '+'"
    grep '^\+:' /etc/group | while read -r line; do
        log_append "[TWGCB-01-012-0077][INFO] Found entry: $line"
    done
    set_flag flag_077 0
else
    log_append "[TWGCB-01-012-0077][PASS] /etc/group does not contain lines starting with '+'"
    set_flag flag_077 1
fi
# ======================================
# TWGCB-01-012-0078
# 僅root帳號之UID為0
uid0_accounts=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd | grep -v '^root$')
if [ -n "$uid0_accounts" ]; then
    log_append "[TWGCB-01-012-0078][FAIL] Found non-root accounts with UID=0:"
    echo "$uid0_accounts" | while read -r account; do
        log_append "[TWGCB-01-012-0078][INFO] Account with UID=0: $account"
    done
    set_flag flag_078 0
else
    log_append "[TWGCB-01-012-0078][PASS] Only root has UID=0"
    set_flag flag_078 1
fi
# ======================================
# TWGCB-01-012-0079
# 使用者家目錄權限須為700或更低權限
home_perm_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        log_append "[TWGCB-01-012-0079][INFO] Home directory ($home) of user $username does not exist"
        continue
    fi
    perm=$(stat -c "%a" "$home")
    if [ $(( 8#${perm: -3} & 8#077 )) -ne 0 ]; then
        log_append "[TWGCB-01-012-0079][FAIL] Home directory ($home) of user $username has permission $perm (expected 700 or more restrictive)"
        home_perm_fail=1
    fi
done < /etc/passwd
if [ $home_perm_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0079][PASS] All user home directories have permissions of 700 or more restrictive"
    set_flag flag_079 1
else
    set_flag flag_079 0
fi
# ======================================
# TWGCB-01-012-0080
# 使用者家目錄擁有者須為該使用者
home_owner_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        log_append "[TWGCB-01-012-0080][INFO] Home directory ($home) of user $username does not exist"
        continue
    fi
    owner=$(stat -L -c "%U" "$home")
    if [ "$owner" != "$username" ]; then
        log_append "[TWGCB-01-012-0080][FAIL] Home directory ($home) of user $username is owned by $owner"
        home_owner_fail=1
    fi
done < /etc/passwd
if [ $home_owner_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0080][PASS] All user home directories are owned by the respective users"
    set_flag flag_080 1
else
    set_flag flag_080 0
fi
# ======================================
# TWGCB-01-012-0081
# 使用者家目錄擁有群組須為該使用者之群組
home_grp_fail=0
while IFS=: read -r username _ uid gid _ home shell; do
    if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        log_append "[TWGCB-01-012-0081][INFO] Home directory ($home) of user $username does not exist"
        continue
    fi
    owner_gid=$(stat -L -c "%g" "$home")
    if [ "$owner_gid" != "$gid" ]; then
        log_append "[TWGCB-01-012-0081][FAIL] Home directory ($home) of user $username is owned by group GID $owner_gid (expected GID $gid)"
        home_grp_fail=1
    fi
done < /etc/passwd
if [ $home_grp_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0081][PASS] All user home directories are owned by the user's own group"
    set_flag flag_081 1
else
    set_flag flag_081 0
fi

# ======================================
# TWGCB-01-012-0082
# 使用者家目錄的「.」開頭檔案權限須為go-w或更低權限
dot_perm_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        continue
    fi
    for dotfile in "$home"/.[A-Za-z0-9]*; do
        [ -h "$dotfile" ] && continue
        [ ! -f "$dotfile" ] && continue
        fileperm=$(ls -ld "$dotfile" | cut -f1 -d" ")
        if [ "$(echo "$fileperm" | cut -c6)" != "-" ]; then
            log_append "[TWGCB-01-012-0082][FAIL] Group write permission set on dot file: $dotfile (perm: $fileperm)"
            dot_perm_fail=1
        fi
        if [ "$(echo "$fileperm" | cut -c9)" != "-" ]; then
            log_append "[TWGCB-01-012-0082][FAIL] Other write permission set on dot file: $dotfile (perm: $fileperm)"
            dot_perm_fail=1
        fi
    done
done < /etc/passwd
if [ $dot_perm_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0082][PASS] No dot files in user home directories have group/other write permissions"
    set_flag flag_082 1
else
    set_flag flag_082 0
fi
# ======================================
# TWGCB-01-012-0083
# 使用者家目錄的「.forward」檔案須移除
forward_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        continue
    fi
    if [ ! -h "$home/.forward" ] && [ -f "$home/.forward" ]; then
        log_append "[TWGCB-01-012-0083][FAIL] .forward file exists for user $username: $home/.forward"
        forward_fail=1
    fi
done < /etc/passwd
if [ $forward_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0083][PASS] No .forward files found in user home directories"
    set_flag flag_083 1
else
    set_flag flag_083 0
fi
# ======================================
# TWGCB-01-012-0084
# 使用者家目錄的「.netrc」檔案須移除
netrc_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        continue
    fi
    if [ ! -h "$home/.netrc" ] && [ -f "$home/.netrc" ]; then
        log_append "[TWGCB-01-012-0084][FAIL] .netrc file exists for user $username: $home/.netrc"
        netrc_fail=1
    fi
done < /etc/passwd
if [ $netrc_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0084][PASS] No .netrc files found in user home directories"
    set_flag flag_084 1
else
    set_flag flag_084 0
fi
# ======================================
# TWGCB-01-012-0085
# 使用者家目錄的「.rhosts」檔案須移除
rhosts_fail=0
while IFS=: read -r username _ _ _ _ home shell; do
    if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
        continue
    fi
    if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/usr/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
        continue
    fi
    if [ -z "$home" ] || [ "$home" = "/" ]; then
        continue
    fi
    if [ ! -d "$home" ]; then
        continue
    fi
    if [ ! -h "$home/.rhosts" ] && [ -f "$home/.rhosts" ]; then
        log_append "[TWGCB-01-012-0085][FAIL] .rhosts file exists for user $username: $home/.rhosts"
        rhosts_fail=1
    fi
done < /etc/passwd
if [ $rhosts_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0085][PASS] No .rhosts files found in user home directories"
    set_flag flag_085 1
else
    set_flag flag_085 0
fi
# ======================================
# TWGCB-01-012-0086
# /etc/passwd檔案中帳號的群組皆須存在於/etc/group檔案中
gid_missing_fail=0
while IFS= read -r gid; do
    if ! grep -q -P "^[^:]*:[^:]*:${gid}:" /etc/group; then
        log_append "[TWGCB-01-012-0086][FAIL] GID $gid is referenced in /etc/passwd but does not exist in /etc/group"
        gid_missing_fail=1
    fi
done < <(cut -s -d: -f4 /etc/passwd | sort -u)
if [ $gid_missing_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0086][PASS] All GIDs in /etc/passwd exist in /etc/group"
    set_flag flag_086 1
else
    set_flag flag_086 0
fi
# ======================================
# TWGCB-01-012-0087
# 使用者帳號之UID須為唯一值
dup_uid_fail=0
while read -r count uid; do
    if [ "$count" -gt 1 ]; then
        users=$(awk -F: "(\$3 == $uid) { print \$1 }" /etc/passwd | tr '\n' ' ')
        log_append "[TWGCB-01-012-0087][FAIL] Duplicate UID ($uid): $users"
        dup_uid_fail=1
    fi
done < <(cut -f3 -d: /etc/passwd | sort -n | uniq -c)
if [ $dup_uid_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0087][PASS] All user accounts have unique UIDs"
    set_flag flag_087 1
else
    set_flag flag_087 0
fi
# ======================================
# TWGCB-01-012-0088
# 群組之GID須為唯一值
dup_gid_fail=0
while IFS= read -r gid; do
    log_append "[TWGCB-01-012-0088][FAIL] Duplicate GID ($gid) in /etc/group"
    dup_gid_fail=1
done < <(cut -d: -f3 /etc/group | sort | uniq -d)
if [ $dup_gid_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0088][PASS] All groups have unique GIDs"
    set_flag flag_088 1
else
    set_flag flag_088 0
fi
# ======================================
# TWGCB-01-012-0089
# 使用者帳號名稱須為唯一值
dup_uname_fail=0
while IFS= read -r uname; do
    log_append "[TWGCB-01-012-0089][FAIL] Duplicate username ($uname) in /etc/passwd"
    dup_uname_fail=1
done < <(cut -d: -f1 /etc/passwd | sort | uniq -d)
if [ $dup_uname_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0089][PASS] All user account names are unique"
    set_flag flag_089 1
else
    set_flag flag_089 0
fi
# ======================================
# TWGCB-01-012-0090
# 群組名稱須為唯一值
dup_gname_fail=0
while IFS= read -r gname; do
    log_append "[TWGCB-01-012-0090][FAIL] Duplicate group name ($gname) in /etc/group"
    dup_gname_fail=1
done < <(cut -d: -f1 /etc/group | sort | uniq -d)
if [ $dup_gname_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0090][PASS] All group names are unique"
    set_flag flag_090 1
else
    set_flag flag_090 0
fi
# ======================================
# TWGCB-01-012-0091
# shadow群組成員須為空
shadow_members=$(awk -F: '($1=="shadow") {print $NF}' /etc/group)
if [ -n "$shadow_members" ]; then
    log_append "[TWGCB-01-012-0091][FAIL] shadow group contains members: $shadow_members"
    set_flag flag_091 0
else
    log_append "[TWGCB-01-012-0091][PASS] shadow group contains no members"
    set_flag flag_091 1
fi

# ======================================
# TWGCB-01-012-0092
# xinetd套件須移除
if rpm -q xinetd &>/dev/null; then
    log_append "[TWGCB-01-012-0092][FAIL] xinetd package is installed and must be removed"
    set_flag flag_092 0
else
    log_append "[TWGCB-01-012-0092][PASS] xinetd package is not installed"
    set_flag flag_092 1
fi
# ======================================
# TWGCB-01-012-0093
# chrony須設定1個以上時間同步來源
if ! rpm -q chrony &>/dev/null; then
    log_append "[TWGCB-01-012-0093][SKIP] chrony package is not installed"
    set_flag flag_093 2
elif [ ! -f /etc/chrony.conf ]; then
    log_append "[TWGCB-01-012-0093][FAIL] /etc/chrony.conf does not exist"
    set_flag flag_093 0
else
    ntp_count=$(grep -cE "^(server|pool)" /etc/chrony.conf 2>/dev/null || echo 0)
    if [ "$ntp_count" -ge 1 ]; then
        log_append "[TWGCB-01-012-0093][PASS] chrony has $ntp_count NTP time source(s) configured"
        set_flag flag_093 1
    else
        log_append "[TWGCB-01-012-0093][FAIL] chrony has no NTP server or pool configured in /etc/chrony.conf"
        set_flag flag_093 0
    fi
fi
# ======================================
# TWGCB-01-012-0094
# rsyncd服務須停用
if systemctl is-enabled rsyncd > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0094][FAIL] rsyncd service is enabled"
    set_flag flag_094 0
else
    log_append "[TWGCB-01-012-0094][PASS] rsyncd service is disabled or not installed"
    set_flag flag_094 1
fi
# ======================================
# TWGCB-01-012-0095
# avahi-daemon服務及socket須停用
avahi_fail=0
if systemctl is-enabled avahi-daemon.service > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0095][FAIL] avahi-daemon.service is enabled"
    avahi_fail=1
fi
if systemctl is-enabled avahi-daemon.socket > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0095][FAIL] avahi-daemon.socket is enabled"
    avahi_fail=1
fi
if [ $avahi_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0095][PASS] avahi-daemon.service and avahi-daemon.socket are both disabled or not installed"
    set_flag flag_095 1
else
    set_flag flag_095 0
fi
# ======================================
# TWGCB-01-012-0096
# SNMP服務須停用（或僅啟用SNMPv3）
if systemctl is-enabled snmpd > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0096][FAIL] snmpd service is enabled (must be disabled or configured for SNMPv3 only)"
    set_flag flag_096 0
else
    log_append "[TWGCB-01-012-0096][PASS] snmpd service is disabled or not installed"
    set_flag flag_096 1
fi
# ======================================
# TWGCB-01-012-0097
# Squid服務須停用
if systemctl is-enabled squid > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0097][FAIL] squid service is enabled"
    set_flag flag_097 0
else
    log_append "[TWGCB-01-012-0097][PASS] squid service is disabled or not installed"
    set_flag flag_097 1
fi
# ======================================
# TWGCB-01-012-0098
# Samba服務須停用
if systemctl is-enabled smb > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0098][FAIL] smb (Samba) service is enabled"
    set_flag flag_098 0
else
    log_append "[TWGCB-01-012-0098][PASS] smb (Samba) service is disabled or not installed"
    set_flag flag_098 1
fi
# ======================================
# TWGCB-01-012-0099
# FTP伺服器服務須停用
if systemctl is-enabled vsftpd > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0099][FAIL] vsftpd (FTP server) service is enabled"
    set_flag flag_099 0
else
    log_append "[TWGCB-01-012-0099][PASS] vsftpd (FTP server) service is disabled or not installed"
    set_flag flag_099 1
fi
# ======================================
# TWGCB-01-012-0100
# NIS伺服器服務須停用
if systemctl is-enabled ypserv > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0100][FAIL] ypserv (NIS server) service is enabled"
    set_flag flag_100 0
else
    log_append "[TWGCB-01-012-0100][PASS] ypserv (NIS server) service is disabled or not installed"
    set_flag flag_100 1
fi
# ======================================
# TWGCB-01-012-0101
# kdump服務須啟用
if systemctl is-enabled kdump.service > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0101][PASS] kdump.service is enabled"
    set_flag flag_101 1
else
    log_append "[TWGCB-01-012-0101][FAIL] kdump.service is not enabled"
    set_flag flag_101 0
fi

# ======================================
# TWGCB-01-012-0102
# NIS用戶端套件(ypbind)須移除
if rpm -q ypbind &>/dev/null; then
    log_append "[TWGCB-01-012-0102][FAIL] ypbind (NIS client) package is installed and must be removed"
    set_flag flag_102 0
else
    log_append "[TWGCB-01-012-0102][PASS] ypbind (NIS client) package is not installed"
    set_flag flag_102 1
fi
# ======================================
# TWGCB-01-012-0103
# telnet用戶端套件須移除
if rpm -q telnet &>/dev/null; then
    log_append "[TWGCB-01-012-0103][FAIL] telnet client package is installed and must be removed"
    set_flag flag_103 0
else
    log_append "[TWGCB-01-012-0103][PASS] telnet client package is not installed"
    set_flag flag_103 1
fi
# ======================================
# TWGCB-01-012-0104
# telnet伺服器套件須移除
if rpm -q telnet-server &>/dev/null; then
    log_append "[TWGCB-01-012-0104][FAIL] telnet-server package is installed and must be removed"
    set_flag flag_104 0
else
    log_append "[TWGCB-01-012-0104][PASS] telnet-server package is not installed"
    set_flag flag_104 1
fi
# ======================================
# TWGCB-01-012-0105
# rsh伺服器套件須移除
if rpm -q rsh-server &>/dev/null; then
    log_append "[TWGCB-01-012-0105][FAIL] rsh-server package is installed and must be removed"
    set_flag flag_105 0
else
    log_append "[TWGCB-01-012-0105][PASS] rsh-server package is not installed"
    set_flag flag_105 1
fi
# ======================================
# TWGCB-01-012-0106
# tftp伺服器套件須移除
if rpm -q tftp-server &>/dev/null; then
    log_append "[TWGCB-01-012-0106][FAIL] tftp-server package is installed and must be removed"
    set_flag flag_106 0
else
    log_append "[TWGCB-01-012-0106][PASS] tftp-server package is not installed"
    set_flag flag_106 1
fi
# ======================================
# TWGCB-01-012-0107
# 更新套件後須移除舊版本元件 (clean_requirements_on_remove=True)
cr_fail=0
for conf in /etc/yum.conf /etc/dnf/dnf.conf; do
    if [ -f "$conf" ]; then
        if grep -qiE '^\s*clean_requirements_on_remove\s*=\s*[Tt]rue' "$conf"; then
            log_append "[TWGCB-01-012-0107][PASS] clean_requirements_on_remove=True found in $conf"
        else
            log_append "[TWGCB-01-012-0107][FAIL] clean_requirements_on_remove=True not found in $conf"
            cr_fail=1
        fi
    else
        log_append "[TWGCB-01-012-0107][INFO] $conf does not exist, skipping"
    fi
done
if [ $cr_fail -eq 0 ]; then set_flag flag_107 1; else set_flag flag_107 0; fi
# ======================================
# TWGCB-01-012-0108
# IP轉送須停用 (net.ipv4.ip_forward=0, net.ipv6.conf.all.forwarding=0)
ipfwd_fail=0
if [ "$(sysctl -n net.ipv4.ip_forward 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0108][PASS] sysctl runtime: net.ipv4.ip_forward=0"
else
    log_append "[TWGCB-01-012-0108][FAIL] sysctl runtime: net.ipv4.ip_forward is not 0"
    ipfwd_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.ip_forward\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0108][PASS] sysctl config: net.ipv4.ip_forward=0 present"
else
    log_append "[TWGCB-01-012-0108][FAIL] sysctl config: net.ipv4.ip_forward=0 not found in config files"
    ipfwd_fail=1
fi
if [ "$(sysctl -n net.ipv6.conf.all.forwarding 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0108][PASS] sysctl runtime: net.ipv6.conf.all.forwarding=0"
else
    log_append "[TWGCB-01-012-0108][FAIL] sysctl runtime: net.ipv6.conf.all.forwarding is not 0"
    ipfwd_fail=1
fi
if grep -RqsE '^\s*net\.ipv6\.conf\.all\.forwarding\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0108][PASS] sysctl config: net.ipv6.conf.all.forwarding=0 present"
else
    log_append "[TWGCB-01-012-0108][FAIL] sysctl config: net.ipv6.conf.all.forwarding=0 not found in config files"
    ipfwd_fail=1
fi
if [ $ipfwd_fail -eq 0 ]; then set_flag flag_108 1; else set_flag flag_108 0; fi
# ======================================
# TWGCB-01-012-0109
# 所有網路介面傳送ICMP重新導向封包須停用 (net.ipv4.conf.all.send_redirects=0)
redir_all_fail=0
if [ "$(sysctl -n net.ipv4.conf.all.send_redirects 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0109][PASS] sysctl runtime: net.ipv4.conf.all.send_redirects=0"
else
    log_append "[TWGCB-01-012-0109][FAIL] sysctl runtime: net.ipv4.conf.all.send_redirects is not 0"
    redir_all_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.all\.send_redirects\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0109][PASS] sysctl config: net.ipv4.conf.all.send_redirects=0 present"
else
    log_append "[TWGCB-01-012-0109][FAIL] sysctl config: net.ipv4.conf.all.send_redirects=0 not found in config files"
    redir_all_fail=1
fi
if [ $redir_all_fail -eq 0 ]; then set_flag flag_109 1; else set_flag flag_109 0; fi
# ======================================
# TWGCB-01-012-0110
# 預設網路介面傳送ICMP重新導向封包須停用 (net.ipv4.conf.default.send_redirects=0)
redir_def_fail=0
if [ "$(sysctl -n net.ipv4.conf.default.send_redirects 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0110][PASS] sysctl runtime: net.ipv4.conf.default.send_redirects=0"
else
    log_append "[TWGCB-01-012-0110][FAIL] sysctl runtime: net.ipv4.conf.default.send_redirects is not 0"
    redir_def_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.default\.send_redirects\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0110][PASS] sysctl config: net.ipv4.conf.default.send_redirects=0 present"
else
    log_append "[TWGCB-01-012-0110][FAIL] sysctl config: net.ipv4.conf.default.send_redirects=0 not found in config files"
    redir_def_fail=1
fi
if [ $redir_def_fail -eq 0 ]; then set_flag flag_110 1; else set_flag flag_110 0; fi
# ======================================
# TWGCB-01-012-0111
# 所有網路介面不接受來源路由封包 (net.ipv4/ipv6.conf.all.accept_source_route=0)
src_rt_all_fail=0
for key in net.ipv4.conf.all.accept_source_route net.ipv6.conf.all.accept_source_route; do
    if [ "$(sysctl -n $key 2>/dev/null)" = "0" ]; then
        log_append "[TWGCB-01-012-0111][PASS] sysctl runtime: $key=0"
    else
        log_append "[TWGCB-01-012-0111][FAIL] sysctl runtime: $key is not 0"
        src_rt_all_fail=1
    fi
    kesc=$(echo "$key" | sed 's/\./\\./g')
    if grep -RqsE "^\s*${kesc}\s*=\s*0" /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0111][PASS] sysctl config: $key=0 present"
    else
        log_append "[TWGCB-01-012-0111][FAIL] sysctl config: $key=0 not found in config files"
        src_rt_all_fail=1
    fi
done
if [ $src_rt_all_fail -eq 0 ]; then set_flag flag_111 1; else set_flag flag_111 0; fi
# ======================================
# TWGCB-01-012-0112
# 預設網路介面不接受來源路由封包 (net.ipv4/ipv6.conf.default.accept_source_route=0)
src_rt_def_fail=0
for key in net.ipv4.conf.default.accept_source_route net.ipv6.conf.default.accept_source_route; do
    if [ "$(sysctl -n $key 2>/dev/null)" = "0" ]; then
        log_append "[TWGCB-01-012-0112][PASS] sysctl runtime: $key=0"
    else
        log_append "[TWGCB-01-012-0112][FAIL] sysctl runtime: $key is not 0"
        src_rt_def_fail=1
    fi
    kesc=$(echo "$key" | sed 's/\./\\./g')
    if grep -RqsE "^\s*${kesc}\s*=\s*0" /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0112][PASS] sysctl config: $key=0 present"
    else
        log_append "[TWGCB-01-012-0112][FAIL] sysctl config: $key=0 not found in config files"
        src_rt_def_fail=1
    fi
done
if [ $src_rt_def_fail -eq 0 ]; then set_flag flag_112 1; else set_flag flag_112 0; fi
# ======================================
# TWGCB-01-012-0113
# 所有網路介面不接受ICMP重新導向封包 (net.ipv4/ipv6.conf.all.accept_redirects=0)
acc_redir_all_fail=0
for key in net.ipv4.conf.all.accept_redirects net.ipv6.conf.all.accept_redirects; do
    if [ "$(sysctl -n $key 2>/dev/null)" = "0" ]; then
        log_append "[TWGCB-01-012-0113][PASS] sysctl runtime: $key=0"
    else
        log_append "[TWGCB-01-012-0113][FAIL] sysctl runtime: $key is not 0"
        acc_redir_all_fail=1
    fi
    kesc=$(echo "$key" | sed 's/\./\\./g')
    if grep -RqsE "^\s*${kesc}\s*=\s*0" /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0113][PASS] sysctl config: $key=0 present"
    else
        log_append "[TWGCB-01-012-0113][FAIL] sysctl config: $key=0 not found in config files"
        acc_redir_all_fail=1
    fi
done
if [ $acc_redir_all_fail -eq 0 ]; then set_flag flag_113 1; else set_flag flag_113 0; fi
# ======================================
# TWGCB-01-012-0114
# 預設網路介面不接受ICMP重新導向封包 (net.ipv4/ipv6.conf.default.accept_redirects=0)
acc_redir_def_fail=0
for key in net.ipv4.conf.default.accept_redirects net.ipv6.conf.default.accept_redirects; do
    if [ "$(sysctl -n $key 2>/dev/null)" = "0" ]; then
        log_append "[TWGCB-01-012-0114][PASS] sysctl runtime: $key=0"
    else
        log_append "[TWGCB-01-012-0114][FAIL] sysctl runtime: $key is not 0"
        acc_redir_def_fail=1
    fi
    kesc=$(echo "$key" | sed 's/\./\\./g')
    if grep -RqsE "^\s*${kesc}\s*=\s*0" /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
        log_append "[TWGCB-01-012-0114][PASS] sysctl config: $key=0 present"
    else
        log_append "[TWGCB-01-012-0114][FAIL] sysctl config: $key=0 not found in config files"
        acc_redir_def_fail=1
    fi
done
if [ $acc_redir_def_fail -eq 0 ]; then set_flag flag_114 1; else set_flag flag_114 0; fi
# ======================================
# TWGCB-01-012-0115
# 所有網路介面不接受安全ICMP重新導向封包 (net.ipv4.conf.all.secure_redirects=0)
sec_redir_all_fail=0
if [ "$(sysctl -n net.ipv4.conf.all.secure_redirects 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0115][PASS] sysctl runtime: net.ipv4.conf.all.secure_redirects=0"
else
    log_append "[TWGCB-01-012-0115][FAIL] sysctl runtime: net.ipv4.conf.all.secure_redirects is not 0"
    sec_redir_all_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.all\.secure_redirects\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0115][PASS] sysctl config: net.ipv4.conf.all.secure_redirects=0 present"
else
    log_append "[TWGCB-01-012-0115][FAIL] sysctl config: net.ipv4.conf.all.secure_redirects=0 not found in config files"
    sec_redir_all_fail=1
fi
if [ $sec_redir_all_fail -eq 0 ]; then set_flag flag_115 1; else set_flag flag_115 0; fi
# ======================================
# TWGCB-01-012-0116
# 預設網路介面不接受安全ICMP重新導向封包 (net.ipv4.conf.default.secure_redirects=0)
sec_redir_def_fail=0
if [ "$(sysctl -n net.ipv4.conf.default.secure_redirects 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0116][PASS] sysctl runtime: net.ipv4.conf.default.secure_redirects=0"
else
    log_append "[TWGCB-01-012-0116][FAIL] sysctl runtime: net.ipv4.conf.default.secure_redirects is not 0"
    sec_redir_def_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.default\.secure_redirects\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0116][PASS] sysctl config: net.ipv4.conf.default.secure_redirects=0 present"
else
    log_append "[TWGCB-01-012-0116][FAIL] sysctl config: net.ipv4.conf.default.secure_redirects=0 not found in config files"
    sec_redir_def_fail=1
fi
if [ $sec_redir_def_fail -eq 0 ]; then set_flag flag_116 1; else set_flag flag_116 0; fi
# ======================================
# TWGCB-01-012-0117
# 所有網路介面須記錄可疑封包 (net.ipv4.conf.all.log_martians=1)
log_mart_all_fail=0
if [ "$(sysctl -n net.ipv4.conf.all.log_martians 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0117][PASS] sysctl runtime: net.ipv4.conf.all.log_martians=1"
else
    log_append "[TWGCB-01-012-0117][FAIL] sysctl runtime: net.ipv4.conf.all.log_martians is not 1"
    log_mart_all_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.all\.log_martians\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0117][PASS] sysctl config: net.ipv4.conf.all.log_martians=1 present"
else
    log_append "[TWGCB-01-012-0117][FAIL] sysctl config: net.ipv4.conf.all.log_martians=1 not found in config files"
    log_mart_all_fail=1
fi
if [ $log_mart_all_fail -eq 0 ]; then set_flag flag_117 1; else set_flag flag_117 0; fi
# ======================================
# TWGCB-01-012-0118
# 預設網路介面須記錄可疑封包 (net.ipv4.conf.default.log_martians=1)
log_mart_def_fail=0
if [ "$(sysctl -n net.ipv4.conf.default.log_martians 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0118][PASS] sysctl runtime: net.ipv4.conf.default.log_martians=1"
else
    log_append "[TWGCB-01-012-0118][FAIL] sysctl runtime: net.ipv4.conf.default.log_martians is not 1"
    log_mart_def_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.default\.log_martians\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0118][PASS] sysctl config: net.ipv4.conf.default.log_martians=1 present"
else
    log_append "[TWGCB-01-012-0118][FAIL] sysctl config: net.ipv4.conf.default.log_martians=1 not found in config files"
    log_mart_def_fail=1
fi
if [ $log_mart_def_fail -eq 0 ]; then set_flag flag_118 1; else set_flag flag_118 0; fi
# ======================================
# TWGCB-01-012-0119
# 不回應ICMP廣播要求 (net.ipv4.icmp_echo_ignore_broadcasts=1)
icmp_bc_fail=0
if [ "$(sysctl -n net.ipv4.icmp_echo_ignore_broadcasts 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0119][PASS] sysctl runtime: net.ipv4.icmp_echo_ignore_broadcasts=1"
else
    log_append "[TWGCB-01-012-0119][FAIL] sysctl runtime: net.ipv4.icmp_echo_ignore_broadcasts is not 1"
    icmp_bc_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.icmp_echo_ignore_broadcasts\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0119][PASS] sysctl config: net.ipv4.icmp_echo_ignore_broadcasts=1 present"
else
    log_append "[TWGCB-01-012-0119][FAIL] sysctl config: net.ipv4.icmp_echo_ignore_broadcasts=1 not found in config files"
    icmp_bc_fail=1
fi
if [ $icmp_bc_fail -eq 0 ]; then set_flag flag_119 1; else set_flag flag_119 0; fi
# ======================================
# TWGCB-01-012-0120
# 忽略偽造之ICMP錯誤訊息 (net.ipv4.icmp_ignore_bogus_error_responses=1)
icmp_bogus_fail=0
if [ "$(sysctl -n net.ipv4.icmp_ignore_bogus_error_responses 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0120][PASS] sysctl runtime: net.ipv4.icmp_ignore_bogus_error_responses=1"
else
    log_append "[TWGCB-01-012-0120][FAIL] sysctl runtime: net.ipv4.icmp_ignore_bogus_error_responses is not 1"
    icmp_bogus_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.icmp_ignore_bogus_error_responses\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0120][PASS] sysctl config: net.ipv4.icmp_ignore_bogus_error_responses=1 present"
else
    log_append "[TWGCB-01-012-0120][FAIL] sysctl config: net.ipv4.icmp_ignore_bogus_error_responses=1 not found in config files"
    icmp_bogus_fail=1
fi
if [ $icmp_bogus_fail -eq 0 ]; then set_flag flag_120 1; else set_flag flag_120 0; fi
# ======================================
# TWGCB-01-012-0121
# 所有網路介面須啟用逆向路徑過濾 (net.ipv4.conf.all.rp_filter=1)
rp_all_fail=0
if [ "$(sysctl -n net.ipv4.conf.all.rp_filter 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0121][PASS] sysctl runtime: net.ipv4.conf.all.rp_filter=1"
else
    log_append "[TWGCB-01-012-0121][FAIL] sysctl runtime: net.ipv4.conf.all.rp_filter is not 1"
    rp_all_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.all\.rp_filter\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0121][PASS] sysctl config: net.ipv4.conf.all.rp_filter=1 present"
else
    log_append "[TWGCB-01-012-0121][FAIL] sysctl config: net.ipv4.conf.all.rp_filter=1 not found in config files"
    rp_all_fail=1
fi
if [ $rp_all_fail -eq 0 ]; then set_flag flag_121 1; else set_flag flag_121 0; fi
# ======================================
# TWGCB-01-012-0122
# 預設網路介面須啟用逆向路徑過濾 (net.ipv4.conf.default.rp_filter=1)
rp_def_fail=0
if [ "$(sysctl -n net.ipv4.conf.default.rp_filter 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0122][PASS] sysctl runtime: net.ipv4.conf.default.rp_filter=1"
else
    log_append "[TWGCB-01-012-0122][FAIL] sysctl runtime: net.ipv4.conf.default.rp_filter is not 1"
    rp_def_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.conf\.default\.rp_filter\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0122][PASS] sysctl config: net.ipv4.conf.default.rp_filter=1 present"
else
    log_append "[TWGCB-01-012-0122][FAIL] sysctl config: net.ipv4.conf.default.rp_filter=1 not found in config files"
    rp_def_fail=1
fi
if [ $rp_def_fail -eq 0 ]; then set_flag flag_122 1; else set_flag flag_122 0; fi
# ======================================
# TWGCB-01-012-0123
# TCP SYN cookies須啟用 (net.ipv4.tcp_syncookies=1)
syncook_fail=0
if [ "$(sysctl -n net.ipv4.tcp_syncookies 2>/dev/null)" = "1" ]; then
    log_append "[TWGCB-01-012-0123][PASS] sysctl runtime: net.ipv4.tcp_syncookies=1"
else
    log_append "[TWGCB-01-012-0123][FAIL] sysctl runtime: net.ipv4.tcp_syncookies is not 1"
    syncook_fail=1
fi
if grep -RqsE '^\s*net\.ipv4\.tcp_syncookies\s*=\s*1' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0123][PASS] sysctl config: net.ipv4.tcp_syncookies=1 present"
else
    log_append "[TWGCB-01-012-0123][FAIL] sysctl config: net.ipv4.tcp_syncookies=1 not found in config files"
    syncook_fail=1
fi
if [ $syncook_fail -eq 0 ]; then set_flag flag_123 1; else set_flag flag_123 0; fi
# ======================================
# TWGCB-01-012-0124
# 所有網路介面不接受IPv6路由器公告 (net.ipv6.conf.all.accept_ra=0)
ra_all_fail=0
if [ "$(sysctl -n net.ipv6.conf.all.accept_ra 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0124][PASS] sysctl runtime: net.ipv6.conf.all.accept_ra=0"
else
    log_append "[TWGCB-01-012-0124][FAIL] sysctl runtime: net.ipv6.conf.all.accept_ra is not 0"
    ra_all_fail=1
fi
if grep -RqsE '^\s*net\.ipv6\.conf\.all\.accept_ra\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0124][PASS] sysctl config: net.ipv6.conf.all.accept_ra=0 present"
else
    log_append "[TWGCB-01-012-0124][FAIL] sysctl config: net.ipv6.conf.all.accept_ra=0 not found in config files"
    ra_all_fail=1
fi
if [ $ra_all_fail -eq 0 ]; then set_flag flag_124 1; else set_flag flag_124 0; fi
# ======================================
# TWGCB-01-012-0125
# 預設網路介面不接受IPv6路由器公告 (net.ipv6.conf.default.accept_ra=0)
ra_def_fail=0
if [ "$(sysctl -n net.ipv6.conf.default.accept_ra 2>/dev/null)" = "0" ]; then
    log_append "[TWGCB-01-012-0125][PASS] sysctl runtime: net.ipv6.conf.default.accept_ra=0"
else
    log_append "[TWGCB-01-012-0125][FAIL] sysctl runtime: net.ipv6.conf.default.accept_ra is not 0"
    ra_def_fail=1
fi
if grep -RqsE '^\s*net\.ipv6\.conf\.default\.accept_ra\s*=\s*0' /etc/sysctl.conf /etc/sysctl.d 2>/dev/null; then
    log_append "[TWGCB-01-012-0125][PASS] sysctl config: net.ipv6.conf.default.accept_ra=0 present"
else
    log_append "[TWGCB-01-012-0125][FAIL] sysctl config: net.ipv6.conf.default.accept_ra=0 not found in config files"
    ra_def_fail=1
fi
if [ $ra_def_fail -eq 0 ]; then set_flag flag_125 1; else set_flag flag_125 0; fi
# ======================================
# TWGCB-01-012-0126
# DCCP協定須停用
if ! modinfo dccp &>/dev/null && ! lsmod | grep -q "^dccp"; then
    log_append "[TWGCB-01-012-0126][PASS] dccp module not available in kernel"
    set_flag flag_126 1
elif grep -q "^install dccp /bin/true" /etc/modprobe.d/dccp.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0126][PASS] dccp is disabled via modprobe"
    set_flag flag_126 1
else
    log_append "[TWGCB-01-012-0126][FAIL] dccp module is available but not disabled"
    set_flag flag_126 0
fi
# ======================================
# TWGCB-01-012-0127
# SCTP協定須停用
if ! modinfo sctp &>/dev/null && ! lsmod | grep -q "^sctp"; then
    log_append "[TWGCB-01-012-0127][PASS] sctp module not available in kernel"
    set_flag flag_127 1
elif grep -q "^install sctp /bin/true" /etc/modprobe.d/sctp.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0127][PASS] sctp is disabled via modprobe"
    set_flag flag_127 1
else
    log_append "[TWGCB-01-012-0127][FAIL] sctp module is available but not disabled"
    set_flag flag_127 0
fi
# ======================================
# TWGCB-01-012-0128
# RDS協定須停用
if ! modinfo rds &>/dev/null && ! lsmod | grep -q "^rds"; then
    log_append "[TWGCB-01-012-0128][PASS] rds module not available in kernel"
    set_flag flag_128 1
elif grep -q "^install rds /bin/true" /etc/modprobe.d/rds.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0128][PASS] rds is disabled via modprobe"
    set_flag flag_128 1
else
    log_append "[TWGCB-01-012-0128][FAIL] rds module is available but not disabled"
    set_flag flag_128 0
fi
# ======================================
# TWGCB-01-012-0129
# TIPC協定須停用
if ! modinfo tipc &>/dev/null && ! lsmod | grep -q "^tipc"; then
    log_append "[TWGCB-01-012-0129][PASS] tipc module not available in kernel"
    set_flag flag_129 1
elif grep -q "^install tipc /bin/true" /etc/modprobe.d/tipc.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0129][PASS] tipc is disabled via modprobe"
    set_flag flag_129 1
else
    log_append "[TWGCB-01-012-0129][FAIL] tipc module is available but not disabled"
    set_flag flag_129 0
fi
# ======================================
# TWGCB-01-012-0130
# 無線網路介面須停用
wireless_dirs=$(find /sys/class/net/*/wireless -type d 2>/dev/null)
if [ -z "$wireless_dirs" ]; then
    log_append "[TWGCB-01-012-0130][PASS] No wireless network interfaces found"
    set_flag flag_130 1
else
    if command -v nmcli &>/dev/null; then
        wifi_status=$(nmcli radio wifi 2>/dev/null)
        if echo "$wifi_status" | grep -qi "disabled"; then
            log_append "[TWGCB-01-012-0130][PASS] Wireless interfaces are disabled (nmcli radio wifi: $wifi_status)"
            set_flag flag_130 1
        else
            log_append "[TWGCB-01-012-0130][FAIL] Wireless interfaces exist and are not disabled (nmcli radio wifi: $wifi_status)"
            set_flag flag_130 0
        fi
    else
        log_append "[TWGCB-01-012-0130][FAIL] Wireless interfaces exist; nmcli not available to verify status"
        set_flag flag_130 0
    fi
fi
# ======================================
# TWGCB-01-012-0131
# 網路介面不得開啟混雜模式
promisc_ifaces=$(ip link 2>/dev/null | grep -i promisc | awk -F': ' '{print $2}')
if [ -z "$promisc_ifaces" ]; then
    log_append "[TWGCB-01-012-0131][PASS] No network interfaces in promiscuous mode"
    set_flag flag_131 1
else
    log_append "[TWGCB-01-012-0131][FAIL] Network interfaces in promiscuous mode: $promisc_ifaces"
    set_flag flag_131 0
fi
# ======================================
# TWGCB-01-012-0132
# auditd套件須安裝 (audit, audit-libs)
audit_pkg_fail=0
for pkg in audit audit-libs; do
    if rpm -q "$pkg" &>/dev/null; then
        log_append "[TWGCB-01-012-0132][PASS] $pkg package is installed"
    else
        log_append "[TWGCB-01-012-0132][FAIL] $pkg package is NOT installed"
        audit_pkg_fail=1
    fi
done
if [ $audit_pkg_fail -eq 0 ]; then set_flag flag_132 1; else set_flag flag_132 0; fi
# ======================================
# TWGCB-01-012-0133
# auditd服務須啟用
if systemctl is-enabled auditd > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0133][PASS] auditd service is enabled"
    set_flag flag_133 1
else
    log_append "[TWGCB-01-012-0133][FAIL] auditd service is not enabled"
    set_flag flag_133 0
fi
# ======================================
# TWGCB-01-012-0134
# 稽核auditd啟動前之程序 (audit=1 in GRUB_CMDLINE_LINUX)
grub134_fail=0
if grep -qE 'audit=1' /proc/cmdline 2>/dev/null; then
    log_append "[TWGCB-01-012-0134][PASS] audit=1 present in current kernel cmdline"
else
    log_append "[TWGCB-01-012-0134][FAIL] audit=1 not found in current kernel cmdline"
    grub134_fail=1
fi
if grep -qE 'GRUB_CMDLINE_LINUX.*audit=1' /etc/default/grub 2>/dev/null; then
    log_append "[TWGCB-01-012-0134][PASS] audit=1 present in /etc/default/grub"
else
    log_append "[TWGCB-01-012-0134][FAIL] audit=1 not found in /etc/default/grub"
    grub134_fail=1
fi
if [ $grub134_fail -eq 0 ]; then set_flag flag_134 1; else set_flag flag_134 0; fi
# ======================================
# TWGCB-01-012-0135
# 稽核待辦事項數量限制 (audit_backlog_limit>=8192 in GRUB_CMDLINE_LINUX)
grub135_fail=0
backlog_curr=$(grep -oP 'audit_backlog_limit=\K[0-9]+' /proc/cmdline 2>/dev/null)
if [ -n "$backlog_curr" ] && [ "$backlog_curr" -ge 8192 ]; then
    log_append "[TWGCB-01-012-0135][PASS] audit_backlog_limit=$backlog_curr in current kernel cmdline (>=8192)"
else
    log_append "[TWGCB-01-012-0135][FAIL] audit_backlog_limit not set or < 8192 in current kernel cmdline (value: ${backlog_curr:-not set})"
    grub135_fail=1
fi
backlog_grub=$(grep -oP 'audit_backlog_limit=\K[0-9]+' /etc/default/grub 2>/dev/null)
if [ -n "$backlog_grub" ] && [ "$backlog_grub" -ge 8192 ]; then
    log_append "[TWGCB-01-012-0135][PASS] audit_backlog_limit=$backlog_grub in /etc/default/grub (>=8192)"
else
    log_append "[TWGCB-01-012-0135][FAIL] audit_backlog_limit not set or < 8192 in /etc/default/grub (value: ${backlog_grub:-not set})"
    grub135_fail=1
fi
if [ $grub135_fail -eq 0 ]; then set_flag flag_135 1; else set_flag flag_135 0; fi
# ======================================
# TWGCB-01-012-0136
# 稽核處理失敗時通知系統管理者 (postmaster: root in /etc/aliases)
if grep -qsE '^\s*postmaster\s*:\s*root' /etc/aliases 2>/dev/null; then
    log_append "[TWGCB-01-012-0136][PASS] postmaster: root found in /etc/aliases"
    set_flag flag_136 1
else
    log_append "[TWGCB-01-012-0136][FAIL] postmaster: root not found in /etc/aliases"
    set_flag flag_136 0
fi
# ======================================
# TWGCB-01-012-0137 / 0138 / 0139 / 0140
# 稽核日誌檔案及目錄之所有權與權限
audit_log_file=$(awk -F'[= \t]+' '/^\s*log_file\s*=/{print $2}' /etc/audit/auditd.conf 2>/dev/null)
audit_log_file="${audit_log_file:-/var/log/audit/audit.log}"
audit_log_dir=$(dirname "$audit_log_file")
# 0137 - 稽核日誌檔案所有權須為root:root
if [ -f "$audit_log_file" ]; then
    owner137=$(stat -c "%U:%G" "$audit_log_file")
    if [ "$owner137" = "root:root" ]; then
        log_append "[TWGCB-01-012-0137][PASS] audit log file $audit_log_file is owned by root:root"
        set_flag flag_137 1
    else
        log_append "[TWGCB-01-012-0137][FAIL] audit log file $audit_log_file is owned by $owner137 (expected root:root)"
        set_flag flag_137 0
    fi
else
    log_append "[TWGCB-01-012-0137][SKIP] audit log file $audit_log_file does not exist"
    set_flag flag_137 2
fi
# 0138 - 稽核日誌檔案權限須為600或更低
if [ -f "$audit_log_file" ]; then
    perm138=$(stat -c "%a" "$audit_log_file")
    if [ $(( 8#${perm138: -3} & 8#177 )) -eq 0 ]; then
        log_append "[TWGCB-01-012-0138][PASS] audit log file $audit_log_file has permission $perm138 (<=600)"
        set_flag flag_138 1
    else
        log_append "[TWGCB-01-012-0138][FAIL] audit log file $audit_log_file has permission $perm138 (expected 600 or more restrictive)"
        set_flag flag_138 0
    fi
else
    log_append "[TWGCB-01-012-0138][SKIP] audit log file $audit_log_file does not exist"
    set_flag flag_138 2
fi
# 0139 - 稽核日誌目錄所有權須為root:root
if [ -d "$audit_log_dir" ]; then
    owner139=$(stat -c "%U:%G" "$audit_log_dir")
    if [ "$owner139" = "root:root" ]; then
        log_append "[TWGCB-01-012-0139][PASS] audit log directory $audit_log_dir is owned by root:root"
        set_flag flag_139 1
    else
        log_append "[TWGCB-01-012-0139][FAIL] audit log directory $audit_log_dir is owned by $owner139 (expected root:root)"
        set_flag flag_139 0
    fi
else
    log_append "[TWGCB-01-012-0139][SKIP] audit log directory $audit_log_dir does not exist"
    set_flag flag_139 2
fi
# 0140 - 稽核日誌目錄權限須為700或更低
if [ -d "$audit_log_dir" ]; then
    perm140=$(stat -c "%a" "$audit_log_dir")
    if [ $(( 8#${perm140: -3} & 8#077 )) -eq 0 ]; then
        log_append "[TWGCB-01-012-0140][PASS] audit log directory $audit_log_dir has permission $perm140 (<=700)"
        set_flag flag_140 1
    else
        log_append "[TWGCB-01-012-0140][FAIL] audit log directory $audit_log_dir has permission $perm140 (expected 700 or more restrictive)"
        set_flag flag_140 0
    fi
else
    log_append "[TWGCB-01-012-0140][SKIP] audit log directory $audit_log_dir does not exist"
    set_flag flag_140 2
fi
# ======================================
# TWGCB-01-012-0141
# 稽核規則檔案權限須為600或更低
audit_rules_file="/etc/audit/rules.d/audit.rules"
if [ -f "$audit_rules_file" ]; then
    perm141=$(stat -c "%a" "$audit_rules_file")
    if [ $(( 8#${perm141: -3} & ~8#600 & 8#777 )) -eq 0 ]; then
        log_append "[TWGCB-01-012-0141][PASS] $audit_rules_file has permission $perm141 (<=600)"
        set_flag flag_141 1
    else
        log_append "[TWGCB-01-012-0141][FAIL] $audit_rules_file has permission $perm141 (expected 600 or more restrictive)"
        set_flag flag_141 0
    fi
else
    log_append "[TWGCB-01-012-0141][SKIP] $audit_rules_file does not exist"
    set_flag flag_141 2
fi
# ======================================
# TWGCB-01-012-0142
# 稽核設定檔案權限須為640或更低
if [ -f /etc/audit/auditd.conf ]; then
    perm142=$(stat -c "%a" /etc/audit/auditd.conf)
    if [ $(( 8#${perm142: -3} & ~8#640 & 8#777 )) -eq 0 ]; then
        log_append "[TWGCB-01-012-0142][PASS] /etc/audit/auditd.conf has permission $perm142 (<=640)"
        set_flag flag_142 1
    else
        log_append "[TWGCB-01-012-0142][FAIL] /etc/audit/auditd.conf has permission $perm142 (expected 640 or more restrictive)"
        set_flag flag_142 0
    fi
else
    log_append "[TWGCB-01-012-0142][SKIP] /etc/audit/auditd.conf does not exist"
    set_flag flag_142 2
fi
# ======================================
# TWGCB-01-012-0143 / 0144
# 稽核工具權限須為750或更低，所有權須為root:root
audit_tools="/sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/audisp-remote /sbin/audisp-syslog /sbin/augenrules /sbin/rsyslogd"
tool_perm_fail=0
tool_owner_fail=0
for tool in $audit_tools; do
    [ ! -f "$tool" ] && continue
    perm=$(stat -c "%a" "$tool")
    if [ $(( 8#${perm: -3} & ~8#750 & 8#777 )) -ne 0 ]; then
        log_append "[TWGCB-01-012-0143][FAIL] $tool has permission $perm (expected 750 or more restrictive)"
        tool_perm_fail=1
    fi
    owner=$(stat -c "%U:%G" "$tool")
    if [ "$owner" != "root:root" ]; then
        log_append "[TWGCB-01-012-0144][FAIL] $tool is owned by $owner (expected root:root)"
        tool_owner_fail=1
    fi
done
if [ $tool_perm_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0143][PASS] All audit tools have permissions of 750 or more restrictive"
    set_flag flag_143 1
else
    set_flag flag_143 0
fi
if [ $tool_owner_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0144][PASS] All audit tools are owned by root:root"
    set_flag flag_144 1
else
    set_flag flag_144 0
fi
# ======================================
# TWGCB-01-012-0145
# AIDE須設定監控稽核工具完整性
if ! rpm -q aide &>/dev/null; then
    log_append "[TWGCB-01-012-0145][SKIP] AIDE is not installed, cannot verify audit tool integrity monitoring"
    set_flag flag_145 2
elif [ ! -f /etc/aide.conf ]; then
    log_append "[TWGCB-01-012-0145][FAIL] /etc/aide.conf not found"
    set_flag flag_145 0
else
    if grep -q '/usr/sbin/auditctl' /etc/aide.conf 2>/dev/null; then
        log_append "[TWGCB-01-012-0145][PASS] AIDE is configured to monitor audit tools"
        set_flag flag_145 1
    else
        log_append "[TWGCB-01-012-0145][FAIL] AIDE is not configured to monitor audit tools in /etc/aide.conf"
        set_flag flag_145 0
    fi
fi
# ======================================
# TWGCB-01-012-0146
# 稽核日誌檔案大小上限須為32MB以上
if [ -f /etc/audit/auditd.conf ]; then
    max_log=$(awk -F'[= \t]+' '/^\s*max_log_file\s*=/{print $2}' /etc/audit/auditd.conf 2>/dev/null | tr -d ' ')
    if [ -n "$max_log" ] && [ "$max_log" -ge 32 ] 2>/dev/null; then
        log_append "[TWGCB-01-012-0146][PASS] max_log_file=$max_log in auditd.conf (>=32)"
        set_flag flag_146 1
    else
        log_append "[TWGCB-01-012-0146][FAIL] max_log_file=${max_log:-not set} in auditd.conf (expected >=32)"
        set_flag flag_146 0
    fi
else
    log_append "[TWGCB-01-012-0146][SKIP] /etc/audit/auditd.conf not found"
    set_flag flag_146 2
fi
# ======================================
# TWGCB-01-012-0147
# 稽核日誌達到上限之行為須設為keep_logs
if [ -f /etc/audit/auditd.conf ]; then
    log_action=$(awk -F'[= \t]+' '/^\s*max_log_file_action\s*=/{print $2}' /etc/audit/auditd.conf 2>/dev/null | tr -d ' ')
    if [ "$log_action" = "keep_logs" ]; then
        log_append "[TWGCB-01-012-0147][PASS] max_log_file_action=keep_logs in auditd.conf"
        set_flag flag_147 1
    else
        log_append "[TWGCB-01-012-0147][FAIL] max_log_file_action=${log_action:-not set} in auditd.conf (expected keep_logs)"
        set_flag flag_147 0
    fi
else
    log_append "[TWGCB-01-012-0147][SKIP] /etc/audit/auditd.conf not found"
    set_flag flag_147 2
fi
# ======================================
# TWGCB-01-012-0148
# 稽核規則：記錄系統管理者活動 (-w /etc/sudoers -p wa -k scope)
scope_fail=0
for rule in "-w /etc/sudoers -p wa -k scope" "-w /etc/sudoers.d/ -p wa -k scope"; do
    path=$(echo "$rule" | awk '{print $2}')
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0148][PASS] audit rule present: $rule"
    else
        log_append "[TWGCB-01-012-0148][FAIL] audit rule missing: $rule"
        scope_fail=1
    fi
done
if [ $scope_fail -eq 0 ]; then set_flag flag_148 1; else set_flag flag_148 0; fi
# ======================================
# TWGCB-01-012-0149
# 稽核規則：記錄變更登入與登出資訊事件
login_fail=0
for path in /var/run/faillock/ /var/log/lastlog; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0149][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0149][FAIL] audit rule missing for: $path"
        login_fail=1
    fi
done
if [ $login_fail -eq 0 ]; then set_flag flag_149 1; else set_flag flag_149 0; fi
# ======================================
# TWGCB-01-012-0150
# 稽核規則：記錄會談啟始資訊
session_fail=0
for path in /var/run/utmp /var/log/wtmp /var/log/btmp; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0150][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0150][FAIL] audit rule missing for: $path"
        session_fail=1
    fi
done
if [ $session_fail -eq 0 ]; then set_flag flag_150 1; else set_flag flag_150 0; fi
# ======================================
# TWGCB-01-012-0151
# 稽核規則：記錄系統時間修改事件
time_fail=0
for key in "adjtimex" "settimeofday" "clock_settime"; do
    if auditctl -l 2>/dev/null | grep -qF "$key" || \
       grep -rqsF "$key" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0151][PASS] audit rule present for syscall: $key"
    else
        log_append "[TWGCB-01-012-0151][FAIL] audit rule missing for syscall: $key"
        time_fail=1
    fi
done
if auditctl -l 2>/dev/null | grep -qF "/etc/localtime" || \
   grep -rqsF "/etc/localtime" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0151][PASS] audit rule present for: /etc/localtime"
else
    log_append "[TWGCB-01-012-0151][FAIL] audit rule missing for: /etc/localtime"
    time_fail=1
fi
if [ $time_fail -eq 0 ]; then set_flag flag_151 1; else set_flag flag_151 0; fi
# ======================================
# TWGCB-01-012-0152
# 稽核規則：記錄強制存取控制設定變更
mac_fail=0
for path in /etc/selinux/ /usr/share/selinux/; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0152][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0152][FAIL] audit rule missing for: $path"
        mac_fail=1
    fi
done
if [ $mac_fail -eq 0 ]; then set_flag flag_152 1; else set_flag flag_152 0; fi
# ======================================
# TWGCB-01-012-0153
# 稽核規則：記錄系統區域資訊變更
locale_fail=0
for key in "sethostname" "setdomainname"; do
    if auditctl -l 2>/dev/null | grep -qF "$key" || \
       grep -rqsF "$key" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0153][PASS] audit rule present for syscall: $key"
    else
        log_append "[TWGCB-01-012-0153][FAIL] audit rule missing for syscall: $key"
        locale_fail=1
    fi
done
for path in /etc/issue /etc/issue.net /etc/hosts /etc/sysconfig/network-scripts/; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0153][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0153][FAIL] audit rule missing for: $path"
        locale_fail=1
    fi
done
if [ $locale_fail -eq 0 ]; then set_flag flag_153 1; else set_flag flag_153 0; fi
# ======================================
# TWGCB-01-012-0154
# 稽核規則：記錄自主存取控制權限修改
perm_mod_fail=0
for key in "chmod" "fchmod" "chown" "fchown" "setxattr" "removexattr"; do
    if auditctl -l 2>/dev/null | grep -qF "$key" || \
       grep -rqsF "$key" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0154][PASS] audit rule present for syscall: $key"
    else
        log_append "[TWGCB-01-012-0154][FAIL] audit rule missing for syscall: $key"
        perm_mod_fail=1
    fi
done
if [ $perm_mod_fail -eq 0 ]; then set_flag flag_154 1; else set_flag flag_154 0; fi
# ======================================
# TWGCB-01-012-0155
# 稽核規則：記錄未授權使用者嘗試存取檔案
access_fail=0
if auditctl -l 2>/dev/null | grep -qF "EACCES" || \
   grep -rqsF "EACCES" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0155][PASS] audit rule present for EACCES"
else
    log_append "[TWGCB-01-012-0155][FAIL] audit rule missing for EACCES"
    access_fail=1
fi
if auditctl -l 2>/dev/null | grep -qF "EPERM" || \
   grep -rqsF "EPERM" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0155][PASS] audit rule present for EPERM"
else
    log_append "[TWGCB-01-012-0155][FAIL] audit rule missing for EPERM"
    access_fail=1
fi
if [ $access_fail -eq 0 ]; then set_flag flag_155 1; else set_flag flag_155 0; fi
# ======================================
# TWGCB-01-012-0156
# 稽核規則：記錄使用者與群組帳號資訊
identity_fail=0
for path in /etc/group /etc/passwd /etc/gshadow /etc/shadow /etc/security/opasswd; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0156][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0156][FAIL] audit rule missing for: $path"
        identity_fail=1
    fi
done
if [ $identity_fail -eq 0 ]; then set_flag flag_156 1; else set_flag flag_156 0; fi
# ======================================
# TWGCB-01-012-0157
# 稽核規則：記錄檔案系統掛載操作
mounts_fail=0
if auditctl -l 2>/dev/null | grep -qF "mount" || \
   grep -rqsE "\-S mount" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0157][PASS] audit rule present for mount syscall"
else
    log_append "[TWGCB-01-012-0157][FAIL] audit rule missing for mount syscall"
    mounts_fail=1
fi
if [ $mounts_fail -eq 0 ]; then set_flag flag_157 1; else set_flag flag_157 0; fi
# ======================================
# TWGCB-01-012-0158
# 稽核規則：記錄特權指令使用與操作
priv_fail=0
if auditctl -l 2>/dev/null | grep -qF "privileged" || \
   grep -rqsF "privileged" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null || \
   [ -f /etc/audit/rules.d/privileged.rules ]; then
    log_append "[TWGCB-01-012-0158][PASS] privileged command audit rules present"
else
    log_append "[TWGCB-01-012-0158][FAIL] privileged command audit rules missing"
    priv_fail=1
fi
if [ $priv_fail -eq 0 ]; then set_flag flag_158 1; else set_flag flag_158 0; fi
# ======================================
# TWGCB-01-012-0159
# 稽核規則：記錄檔案刪除操作
delete_fail=0
for key in "unlink" "unlinkat" "rename" "renameat" "rmdir"; do
    if auditctl -l 2>/dev/null | grep -qF "$key" || \
       grep -rqsF "$key" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0159][PASS] audit rule present for syscall: $key"
    else
        log_append "[TWGCB-01-012-0159][FAIL] audit rule missing for syscall: $key"
        delete_fail=1
    fi
done
if [ $delete_fail -eq 0 ]; then set_flag flag_159 1; else set_flag flag_159 0; fi
# ======================================
# TWGCB-01-012-0160
# 稽核規則：記錄核心模組載入與卸載
modules_fail=0
for path in /sbin/insmod /sbin/rmmod /sbin/modprobe; do
    if auditctl -l 2>/dev/null | grep -qF "$path" || \
       grep -rqsF "$path" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0160][PASS] audit rule present for: $path"
    else
        log_append "[TWGCB-01-012-0160][FAIL] audit rule missing for: $path"
        modules_fail=1
    fi
done
for key in "init_module" "delete_module"; do
    if auditctl -l 2>/dev/null | grep -qF "$key" || \
       grep -rqsF "$key" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
        log_append "[TWGCB-01-012-0160][PASS] audit rule present for syscall: $key"
    else
        log_append "[TWGCB-01-012-0160][FAIL] audit rule missing for syscall: $key"
        modules_fail=1
    fi
done
if [ $modules_fail -eq 0 ]; then set_flag flag_160 1; else set_flag flag_160 0; fi
# ======================================
# TWGCB-01-012-0161
# 稽核規則：記錄系統管理者的活動及變更
sudo_log=$(grep -r logfile /etc/sudoers* 2>/dev/null | sed -e 's/.*logfile=//;s/[, ].*//' | head -1)
sudo_log="${sudo_log:-/var/log/sudo.log}"
actions_fail=0
if auditctl -l 2>/dev/null | grep -qF "$sudo_log" || \
   grep -rqsF "$sudo_log" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0161][PASS] audit rule present for sudo log: $sudo_log"
else
    log_append "[TWGCB-01-012-0161][FAIL] audit rule missing for sudo log: $sudo_log"
    actions_fail=1
fi
if [ $actions_fail -eq 0 ]; then set_flag flag_161 1; else set_flag flag_161 0; fi
# ======================================
# TWGCB-01-012-0162
# 稽核規則：記錄 chcon 指令使用
chcon_fail=0
if auditctl -l 2>/dev/null | grep -qF "/usr/bin/chcon" || \
   grep -rqsF "/usr/bin/chcon" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0162][PASS] audit rule present for /usr/bin/chcon"
else
    log_append "[TWGCB-01-012-0162][FAIL] audit rule missing for /usr/bin/chcon"
    chcon_fail=1
fi
if [ $chcon_fail -eq 0 ]; then set_flag flag_162 1; else set_flag flag_162 0; fi
# ======================================
# TWGCB-01-012-0163
# 稽核規則：記錄 ssh-agent 程序使用
sshagent_fail=0
if auditctl -l 2>/dev/null | grep -qF "/usr/bin/ssh-agent" || \
   grep -rqsF "/usr/bin/ssh-agent" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0163][PASS] audit rule present for /usr/bin/ssh-agent"
else
    log_append "[TWGCB-01-012-0163][FAIL] audit rule missing for /usr/bin/ssh-agent"
    sshagent_fail=1
fi
if [ $sshagent_fail -eq 0 ]; then set_flag flag_163 1; else set_flag flag_163 0; fi
# ======================================
# TWGCB-01-012-0164
# 稽核規則：記錄 unix_update 程序使用
unixupdate_fail=0
if auditctl -l 2>/dev/null | grep -qF "/sbin/unix_update" || \
   grep -rqsF "/sbin/unix_update" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0164][PASS] audit rule present for /sbin/unix_update"
else
    log_append "[TWGCB-01-012-0164][FAIL] audit rule missing for /sbin/unix_update"
    unixupdate_fail=1
fi
if [ $unixupdate_fail -eq 0 ]; then set_flag flag_164 1; else set_flag flag_164 0; fi
# ======================================
# TWGCB-01-012-0165
# 稽核規則：記錄 setfacl 指令使用
setfacl_fail=0
if auditctl -l 2>/dev/null | grep -qF "/usr/bin/setfacl" || \
   grep -rqsF "/usr/bin/setfacl" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0165][PASS] audit rule present for /usr/bin/setfacl"
else
    log_append "[TWGCB-01-012-0165][FAIL] audit rule missing for /usr/bin/setfacl"
    setfacl_fail=1
fi
if [ $setfacl_fail -eq 0 ]; then set_flag flag_165 1; else set_flag flag_165 0; fi
# ======================================
# TWGCB-01-012-0166
# 稽核規則：記錄 finit_module 系統呼叫
finitmod_fail=0
if auditctl -l 2>/dev/null | grep -qF "finit_module" || \
   grep -rqsF "finit_module" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0166][PASS] audit rule present for finit_module"
else
    log_append "[TWGCB-01-012-0166][FAIL] audit rule missing for finit_module"
    finitmod_fail=1
fi
if [ $finitmod_fail -eq 0 ]; then set_flag flag_166 1; else set_flag flag_166 0; fi
# ======================================
# TWGCB-01-012-0167
# 稽核規則：記錄 open_by_handle_at 系統呼叫
obha_fail=0
if auditctl -l 2>/dev/null | grep -qF "open_by_handle_at" || \
   grep -rqsF "open_by_handle_at" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0167][PASS] audit rule present for open_by_handle_at"
else
    log_append "[TWGCB-01-012-0167][FAIL] audit rule missing for open_by_handle_at"
    obha_fail=1
fi
if [ $obha_fail -eq 0 ]; then set_flag flag_167 1; else set_flag flag_167 0; fi
# ======================================
# TWGCB-01-012-0168
# 稽核規則：記錄 usermod 指令使用
usermod_fail=0
if auditctl -l 2>/dev/null | grep -qF "/usr/sbin/usermod" || \
   grep -rqsF "/usr/sbin/usermod" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0168][PASS] audit rule present for /usr/sbin/usermod"
else
    log_append "[TWGCB-01-012-0168][FAIL] audit rule missing for /usr/sbin/usermod"
    usermod_fail=1
fi
if [ $usermod_fail -eq 0 ]; then set_flag flag_168 1; else set_flag flag_168 0; fi
# ======================================
# TWGCB-01-012-0169
# 稽核規則：記錄 chacl 指令使用
chacl_fail=0
if auditctl -l 2>/dev/null | grep -qF "/usr/bin/chacl" || \
   grep -rqsF "/usr/bin/chacl" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0169][PASS] audit rule present for /usr/bin/chacl"
else
    log_append "[TWGCB-01-012-0169][FAIL] audit rule missing for /usr/bin/chacl"
    chacl_fail=1
fi
if [ $chacl_fail -eq 0 ]; then set_flag flag_169 1; else set_flag flag_169 0; fi
# ======================================
# TWGCB-01-012-0170
# 稽核規則：記錄 kmod 指令使用
kmod_fail=0
kmod_path=$(command -v kmod 2>/dev/null || echo "/bin/kmod")
if auditctl -l 2>/dev/null | grep -qF "kmod" || \
   grep -rqsF "kmod" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0170][PASS] audit rule present for kmod"
else
    log_append "[TWGCB-01-012-0170][FAIL] audit rule missing for kmod"
    kmod_fail=1
fi
if [ $kmod_fail -eq 0 ]; then set_flag flag_170 1; else set_flag flag_170 0; fi
# ======================================
# TWGCB-01-012-0171
# 稽核規則：記錄登入失敗鎖定資訊
faillock_fail=0
if auditctl -l 2>/dev/null | grep -qF "/var/log/faillock" || \
   grep -rqsF "/var/log/faillock" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0171][PASS] audit rule present for /var/log/faillock"
else
    log_append "[TWGCB-01-012-0171][FAIL] audit rule missing for /var/log/faillock"
    faillock_fail=1
fi
if [ $faillock_fail -eq 0 ]; then set_flag flag_171 1; else set_flag flag_171 0; fi
# ======================================
# TWGCB-01-012-0172
# 稽核規則：記錄特權提升執行操作
execpriv_fail=0
if auditctl -l 2>/dev/null | grep -qF "execpriv" || \
   grep -rqsF "execpriv" /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0172][PASS] execpriv audit rules present"
else
    log_append "[TWGCB-01-012-0172][FAIL] execpriv audit rules missing"
    execpriv_fail=1
fi
if [ $execpriv_fail -eq 0 ]; then set_flag flag_172 1; else set_flag flag_172 0; fi
# ======================================
# TWGCB-01-012-0173
# 稽核規則：設定稽核規則為不可修改
immutable_fail=0
if grep -rqsE '^\s*-e\s+2' /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0173][PASS] audit immutable flag -e 2 is set"
else
    log_append "[TWGCB-01-012-0173][FAIL] audit immutable flag -e 2 is not set"
    immutable_fail=1
fi
if grep -rqsF -- '--loginuid-immutable' /etc/audit/rules.d/ /etc/audit/audit.rules 2>/dev/null; then
    log_append "[TWGCB-01-012-0173][PASS] --loginuid-immutable is set"
else
    log_append "[TWGCB-01-012-0173][FAIL] --loginuid-immutable is not set"
    immutable_fail=1
fi
if [ $immutable_fail -eq 0 ]; then set_flag flag_173 1; else set_flag flag_173 0; fi
# ======================================
# TWGCB-01-012-0174
# rsyslog 套件安裝
if rpm -q rsyslog &>/dev/null; then
    log_append "[TWGCB-01-012-0174][PASS] rsyslog is installed"
    set_flag flag_174 1
else
    log_append "[TWGCB-01-012-0174][FAIL] rsyslog is not installed"
    set_flag flag_174 0
fi
# ======================================
# TWGCB-01-012-0175
# rsyslog 服務啟用
if systemctl is-enabled rsyslog > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0175][PASS] rsyslog service is enabled"
    set_flag flag_175 1
else
    log_append "[TWGCB-01-012-0175][FAIL] rsyslog service is not enabled"
    set_flag flag_175 0
fi
# ======================================
# TWGCB-01-012-0176
# rsyslog FileCreateMode 設定為 0640
if grep -rqsE '^\s*\$FileCreateMode\s+0?640' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
    log_append "[TWGCB-01-012-0176][PASS] rsyslog FileCreateMode is 0640"
    set_flag flag_176 1
else
    log_append "[TWGCB-01-012-0176][FAIL] rsyslog FileCreateMode is not set to 0640"
    set_flag flag_176 0
fi
# ======================================
# TWGCB-01-012-0177
# rsyslog 記錄 auth/authpriv/daemon 事件
if grep -rqsE 'auth\.\*.*authpriv\.\*|authpriv\.\*.*auth\.\*' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
    log_append "[TWGCB-01-012-0177][PASS] rsyslog auth logging is configured"
    set_flag flag_177 1
else
    log_append "[TWGCB-01-012-0177][FAIL] rsyslog auth logging is not configured"
    set_flag flag_177 0
fi
# ======================================
# TWGCB-01-012-0178
# /var/log/messages 所有權
if [ -f /var/log/messages ]; then
    owner178=$(stat -c "%U:%G" /var/log/messages)
    if [ "$owner178" = "root:root" ]; then
        log_append "[TWGCB-01-012-0178][PASS] /var/log/messages is owned by root:root"
        set_flag flag_178 1
    else
        log_append "[TWGCB-01-012-0178][FAIL] /var/log/messages is owned by $owner178 (expected root:root)"
        set_flag flag_178 0
    fi
else
    log_append "[TWGCB-01-012-0178][SKIP] /var/log/messages does not exist"
    set_flag flag_178 2
fi
# ======================================
# TWGCB-01-012-0179
# /var/log 目錄所有權
owner179=$(stat -c "%U:%G" /var/log 2>/dev/null)
if [ "$owner179" = "root:root" ]; then
    log_append "[TWGCB-01-012-0179][PASS] /var/log is owned by root:root"
    set_flag flag_179 1
else
    log_append "[TWGCB-01-012-0179][FAIL] /var/log is owned by $owner179 (expected root:root)"
    set_flag flag_179 0
fi
# ======================================
# TWGCB-01-012-0180
# systemd-journald 轉發至 syslog
if grep -qsE '^\s*ForwardToSyslog\s*=\s*yes' /etc/systemd/journald.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0180][PASS] journald ForwardToSyslog=yes is configured"
    set_flag flag_180 1
else
    log_append "[TWGCB-01-012-0180][FAIL] journald ForwardToSyslog=yes is not configured"
    set_flag flag_180 0
fi
# ======================================
# TWGCB-01-012-0181
# journald 記錄檔壓縮
if grep -qsE '^\s*Compress\s*=\s*yes' /etc/systemd/journald.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0181][PASS] journald Compress=yes is configured"
    set_flag flag_181 1
else
    log_append "[TWGCB-01-012-0181][FAIL] journald Compress=yes is not configured"
    set_flag flag_181 0
fi
# ======================================
# TWGCB-01-012-0182
# journald 將日誌寫至持久化存儲媒體
if grep -qsE '^\s*Storage\s*=\s*persistent' /etc/systemd/journald.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0182][PASS] journald Storage=persistent is configured"
    set_flag flag_182 1
else
    log_append "[TWGCB-01-012-0182][FAIL] journald Storage=persistent is not configured"
    set_flag flag_182 0
fi
# (0183/0184 不存在於文件中，跳過)
# ======================================
# TWGCB-01-012-0185
# SELinux 套件安裝
if rpm -q libselinux &>/dev/null; then
    log_append "[TWGCB-01-012-0185][PASS] libselinux is installed"
    set_flag flag_185 1
else
    log_append "[TWGCB-01-012-0185][FAIL] libselinux is not installed"
    set_flag flag_185 0
fi
# ======================================
# TWGCB-01-012-0186
# 開機程序中未啟用 SELinux 禁用參數
grub186_fail=0
if grep -qP '(selinux=0|enforcing=0)' /proc/cmdline 2>/dev/null; then
    log_append "[TWGCB-01-012-0186][FAIL] selinux=0 or enforcing=0 found in current kernel cmdline"
    grub186_fail=1
else
    log_append "[TWGCB-01-012-0186][PASS] no selinux=0 or enforcing=0 in current kernel cmdline"
fi
if grep -qP '(selinux=0|enforcing=0)' /etc/default/grub 2>/dev/null; then
    log_append "[TWGCB-01-012-0186][FAIL] selinux=0 or enforcing=0 found in /etc/default/grub"
    grub186_fail=1
else
    log_append "[TWGCB-01-012-0186][PASS] no selinux=0 or enforcing=0 in /etc/default/grub"
fi
if [ $grub186_fail -eq 0 ]; then set_flag flag_186 1; else set_flag flag_186 0; fi
# ======================================
# TWGCB-01-012-0187
# SELinux 框架設定
if grep -qsE '^\s*SELINUXTYPE\s*=\s*targeted' /etc/selinux/config 2>/dev/null; then
    log_append "[TWGCB-01-012-0187][PASS] SELINUXTYPE=targeted is configured"
    set_flag flag_187 1
else
    log_append "[TWGCB-01-012-0187][FAIL] SELINUXTYPE=targeted is not configured"
    set_flag flag_187 0
fi
# ======================================
# TWGCB-01-012-0188
# SELinux 啟用狀態
selinux188_fail=0
if grep -qsE '^\s*SELINUX\s*=\s*enforcing' /etc/selinux/config 2>/dev/null; then
    log_append "[TWGCB-01-012-0188][PASS] SELINUX=enforcing in /etc/selinux/config"
else
    log_append "[TWGCB-01-012-0188][FAIL] SELINUX=enforcing not set in /etc/selinux/config"
    selinux188_fail=1
fi
selinux_mode=$(getenforce 2>/dev/null)
if [ "$selinux_mode" = "Enforcing" ]; then
    log_append "[TWGCB-01-012-0188][PASS] SELinux runtime mode is Enforcing"
else
    log_append "[TWGCB-01-012-0188][FAIL] SELinux runtime mode is $selinux_mode (expected Enforcing)"
    selinux188_fail=1
fi
if [ $selinux188_fail -eq 0 ]; then set_flag flag_188 1; else set_flag flag_188 0; fi
# ======================================
# TWGCB-01-012-0189
# 未設定的服務程序（需人工確認）
unconfined_count=$(ps -eZf 2>/dev/null | grep unconfined_service_t | grep -v grep | wc -l)
if [ "$unconfined_count" -eq 0 ]; then
    log_append "[TWGCB-01-012-0189][PASS] no unconfined_service_t processes found"
    set_flag flag_189 1
else
    log_append "[TWGCB-01-012-0189][FAIL] $unconfined_count unconfined_service_t process(es) found (manual remediation required)"
    set_flag flag_189 0
fi
# ======================================
# TWGCB-01-012-0190
# setroubleshoot 套件移除
if rpm -q setroubleshoot &>/dev/null; then
    log_append "[TWGCB-01-012-0190][FAIL] setroubleshoot is installed and must be removed"
    set_flag flag_190 0
else
    log_append "[TWGCB-01-012-0190][PASS] setroubleshoot is not installed"
    set_flag flag_190 1
fi
# ======================================
# TWGCB-01-012-0191
# mcstrans 套件移除
if rpm -q mcstrans &>/dev/null; then
    log_append "[TWGCB-01-012-0191][FAIL] mcstrans is installed and must be removed"
    set_flag flag_191 0
else
    log_append "[TWGCB-01-012-0191][PASS] mcstrans is not installed"
    set_flag flag_191 1
fi

# TWGCB-01-012-0192: crond service is enabled
if systemctl is-enabled crond > /dev/null 2>&1; then
    log_append "[TWGCB-01-012-0192][PASS] crond service is enabled"
    set_flag flag_192 1
else
    log_append "[TWGCB-01-012-0192][FAIL] crond service is not enabled"
    set_flag flag_192 0
fi

# TWGCB-01-012-0193: /etc/crontab owner root:root
if [ "$(stat -c '%U:%G' /etc/crontab 2>/dev/null)" = "root:root" ]; then
    log_append "[TWGCB-01-012-0193][PASS] /etc/crontab is owned by root:root"
    set_flag flag_193 1
else
    log_append "[TWGCB-01-012-0193][FAIL] /etc/crontab is not owned by root:root"
    set_flag flag_193 0
fi

# TWGCB-01-012-0194: /etc/crontab permissions 600
if [ "$(stat -c '%a' /etc/crontab 2>/dev/null)" = "600" ]; then
    log_append "[TWGCB-01-012-0194][PASS] /etc/crontab permissions are 600"
    set_flag flag_194 1
else
    log_append "[TWGCB-01-012-0194][FAIL] /etc/crontab permissions are not 600"
    set_flag flag_194 0
fi

# TWGCB-01-012-0195: /etc/cron.hourly owner root:root
if [ "$(stat -c '%U:%G' /etc/cron.hourly 2>/dev/null)" = "root:root" ]; then
    log_append "[TWGCB-01-012-0195][PASS] /etc/cron.hourly is owned by root:root"
    set_flag flag_195 1
else
    log_append "[TWGCB-01-012-0195][FAIL] /etc/cron.hourly is not owned by root:root"
    set_flag flag_195 0
fi

# TWGCB-01-012-0196: /etc/cron.hourly permissions 700
if [ "$(stat -c '%a' /etc/cron.hourly 2>/dev/null)" = "700" ]; then
    log_append "[TWGCB-01-012-0196][PASS] /etc/cron.hourly permissions are 700"
    set_flag flag_196 1
else
    log_append "[TWGCB-01-012-0196][FAIL] /etc/cron.hourly permissions are not 700"
    set_flag flag_196 0
fi

# TWGCB-01-012-0197: /etc/cron.daily owner root:root
if [ "$(stat -c '%U:%G' /etc/cron.daily 2>/dev/null)" = "root:root" ]; then
    log_append "[TWGCB-01-012-0197][PASS] /etc/cron.daily is owned by root:root"
    set_flag flag_197 1
else
    log_append "[TWGCB-01-012-0197][FAIL] /etc/cron.daily is not owned by root:root"
    set_flag flag_197 0
fi

# TWGCB-01-012-0198: /etc/cron.daily permissions 700
if [ "$(stat -c '%a' /etc/cron.daily 2>/dev/null)" = "700" ]; then
    log_append "[TWGCB-01-012-0198][PASS] /etc/cron.daily permissions are 700"
    set_flag flag_198 1
else
    log_append "[TWGCB-01-012-0198][FAIL] /etc/cron.daily permissions are not 700"
    set_flag flag_198 0
fi

# TWGCB-01-012-0199: /etc/cron.weekly owner root:root
if [ "$(stat -c '%U:%G' /etc/cron.weekly 2>/dev/null)" = "root:root" ]; then
    log_append "[TWGCB-01-012-0199][PASS] /etc/cron.weekly is owned by root:root"
    set_flag flag_199 1
else
    log_append "[TWGCB-01-012-0199][FAIL] /etc/cron.weekly is not owned by root:root"
    set_flag flag_199 0
fi

# TWGCB-01-012-0200: /etc/cron.weekly permissions 700
if [ "$(stat -c '%a' /etc/cron.weekly 2>/dev/null)" = "700" ]; then
    log_append "[TWGCB-01-012-0200][PASS] /etc/cron.weekly permissions are 700"
    set_flag flag_200 1
else
    log_append "[TWGCB-01-012-0200][FAIL] /etc/cron.weekly permissions are not 700"
    set_flag flag_200 0
fi

# TWGCB-01-012-0201: /etc/cron.monthly owner root:root
if [ "$(stat -c '%U:%G' /etc/cron.monthly 2>/dev/null)" = "root:root" ]; then
    log_append "[TWGCB-01-012-0201][PASS] /etc/cron.monthly is owned by root:root"
    set_flag flag_201 1
else
    log_append "[TWGCB-01-012-0201][FAIL] /etc/cron.monthly is not owned by root:root"
    set_flag flag_201 0
fi

# TWGCB-01-012-0202: /etc/cron.monthly permissions 700
perm202=$(stat -c "%a" /etc/cron.monthly 2>/dev/null)
if [ $(( 8#${perm202: -3} & ~8#700 & 8#777 )) -eq 0 ]; then
    log_append "[TWGCB-01-012-0202][PASS] /etc/cron.monthly has permission $perm202 (700 or more restrictive)"
    set_flag flag_202 1
else
    log_append "[TWGCB-01-012-0202][FAIL] /etc/cron.monthly has permission $perm202 (expected 700 or more restrictive)"
    set_flag flag_202 0
fi

# TWGCB-01-012-0203: /etc/cron.d owner root:root
owner203=$(stat -c "%U:%G" /etc/cron.d 2>/dev/null)
if [ "$owner203" = "root:root" ]; then
    log_append "[TWGCB-01-012-0203][PASS] /etc/cron.d is owned by root:root"
    set_flag flag_203 1
else
    log_append "[TWGCB-01-012-0203][FAIL] /etc/cron.d is owned by $owner203 (expected root:root)"
    set_flag flag_203 0
fi

# TWGCB-01-012-0204: /etc/cron.d permissions 700
perm204=$(stat -c "%a" /etc/cron.d 2>/dev/null)
if [ $(( 8#${perm204: -3} & ~8#700 & 8#777 )) -eq 0 ]; then
    log_append "[TWGCB-01-012-0204][PASS] /etc/cron.d has permission $perm204 (700 or more restrictive)"
    set_flag flag_204 1
else
    log_append "[TWGCB-01-012-0204][FAIL] /etc/cron.d has permission $perm204 (expected 700 or more restrictive)"
    set_flag flag_204 0
fi

# TWGCB-01-012-0205: cron.allow/at.allow exist root:root, cron.deny/at.deny absent
cron205_fail=0
for f in /etc/cron.allow /etc/at.allow; do
    if [ -f "$f" ]; then
        own=$(stat -c "%U:%G" "$f")
        if [ "$own" = "root:root" ]; then
            log_append "[TWGCB-01-012-0205][PASS] $f exists and is owned by root:root"
        else
            log_append "[TWGCB-01-012-0205][FAIL] $f is owned by $own (expected root:root)"
            cron205_fail=1
        fi
    else
        log_append "[TWGCB-01-012-0205][FAIL] $f does not exist"
        cron205_fail=1
    fi
done
if [ -f /etc/cron.deny ] || [ -f /etc/at.deny ]; then
    log_append "[TWGCB-01-012-0205][FAIL] /etc/cron.deny or /etc/at.deny exists (should be removed)"
    cron205_fail=1
fi
if [ $cron205_fail -eq 0 ]; then set_flag flag_205 1; else set_flag flag_205 0; fi

# TWGCB-01-012-0206: cron.allow/at.allow permissions 600
cron206_fail=0
for f in /etc/cron.allow /etc/at.allow; do
    if [ -f "$f" ]; then
        perm=$(stat -c "%a" "$f")
        if [ $(( 8#${perm: -3} & ~8#600 & 8#777 )) -eq 0 ]; then
            log_append "[TWGCB-01-012-0206][PASS] $f has permission $perm (600 or more restrictive)"
        else
            log_append "[TWGCB-01-012-0206][FAIL] $f has permission $perm (expected 600 or more restrictive)"
            cron206_fail=1
        fi
    else
        log_append "[TWGCB-01-012-0206][FAIL] $f does not exist"
        cron206_fail=1
    fi
done
if [ $cron206_fail -eq 0 ]; then set_flag flag_206 1; else set_flag flag_206 0; fi

# TWGCB-01-012-0207: rsyslog cron logging configured
if grep -rqsE 'cron\.\*' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
    log_append "[TWGCB-01-012-0207][PASS] rsyslog cron logging is configured"
    set_flag flag_207 1
else
    log_append "[TWGCB-01-012-0207][FAIL] rsyslog cron logging is not configured"
    set_flag flag_207 0
fi

# TWGCB-01-012-0208: pwquality retry=3
pam208_fail=0
for f in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    [ ! -f "$f" ] && continue
    if grep -qE '^\s*password\s+requisite\s+pam_pwquality.so.*retry=3' "$f" 2>/dev/null || \
       grep -qE '^\s*retry\s*=\s*3' /etc/security/pwquality.conf 2>/dev/null; then
        log_append "[TWGCB-01-012-0208][PASS] pwquality retry=3 is configured"
    else
        log_append "[TWGCB-01-012-0208][FAIL] pwquality retry=3 is not configured in $f"
        pam208_fail=1
    fi
    break
done
if grep -qE '^\s*Retry\s*=\s*3' /etc/security/pwquality.conf 2>/dev/null || \
   grep -qE '^\s*retry\s*=\s*3' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0208][PASS] pwquality retry=3 in pwquality.conf"
    pam208_fail=0
fi
if [ $pam208_fail -eq 0 ]; then set_flag flag_208 1; else set_flag flag_208 0; fi

# TWGCB-01-012-0209: PAM enforce_for_root
pam209_fail=0
for f in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    [ ! -f "$f" ] && continue
    if grep -qE '^\s*password\s+requisite\s+pam_pwquality.so.*enforce_for_root' "$f" 2>/dev/null; then
        log_append "[TWGCB-01-012-0209][PASS] enforce_for_root is configured in $f"
    else
        log_append "[TWGCB-01-012-0209][FAIL] enforce_for_root is not configured in $f"
        pam209_fail=1
    fi
done
if [ $pam209_fail -eq 0 ]; then set_flag flag_209 1; else set_flag flag_209 0; fi

# TWGCB-01-012-0210: pwquality minlen >= 12
if grep -qsE '^\s*minlen\s*=\s*(1[2-9]|[2-9][0-9])' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0210][PASS] pwquality minlen >= 12"
    set_flag flag_210 1
else
    log_append "[TWGCB-01-012-0210][FAIL] pwquality minlen is not set to 12 or more"
    set_flag flag_210 0
fi

# TWGCB-01-012-0211: pwquality minclass=4
if grep -qsE '^\s*minclass\s*=\s*[4-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0211][PASS] pwquality minclass >= 4"
    set_flag flag_211 1
else
    log_append "[TWGCB-01-012-0211][FAIL] pwquality minclass is not set to 4 or more"
    set_flag flag_211 0
fi

# TWGCB-01-012-0212: pwquality dcredit=-1
if grep -qsE '^\s*dcredit\s*=\s*-[1-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0212][PASS] pwquality dcredit is set (require at least 1 digit)"
    set_flag flag_212 1
else
    log_append "[TWGCB-01-012-0212][FAIL] pwquality dcredit is not set to -1 or less"
    set_flag flag_212 0
fi

# TWGCB-01-012-0213: pwquality ucredit=-1
if grep -qsE '^\s*ucredit\s*=\s*-[1-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0213][PASS] pwquality ucredit is set (require at least 1 uppercase)"
    set_flag flag_213 1
else
    log_append "[TWGCB-01-012-0213][FAIL] pwquality ucredit is not set to -1 or less"
    set_flag flag_213 0
fi

# TWGCB-01-012-0214: pwquality lcredit=-1
if grep -qsE '^\s*lcredit\s*=\s*-[1-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0214][PASS] pwquality lcredit is set (require at least 1 lowercase)"
    set_flag flag_214 1
else
    log_append "[TWGCB-01-012-0214][FAIL] pwquality lcredit is not set to -1 or less"
    set_flag flag_214 0
fi

# TWGCB-01-012-0215: pwquality ocredit=-1
if grep -qsE '^\s*ocredit\s*=\s*-[1-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0215][PASS] pwquality ocredit is set (require at least 1 special char)"
    set_flag flag_215 1
else
    log_append "[TWGCB-01-012-0215][FAIL] pwquality ocredit is not set to -1 or less"
    set_flag flag_215 0
fi

# TWGCB-01-012-0216: pwquality difok >= 3
if grep -qsE '^\s*difok\s*=\s*[3-9]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0216][PASS] pwquality difok >= 3"
    set_flag flag_216 1
else
    log_append "[TWGCB-01-012-0216][FAIL] pwquality difok is not set to 3 or more"
    set_flag flag_216 0
fi

# TWGCB-01-012-0217: pwquality maxclassrepeat <= 4
if grep -qsE '^\s*maxclassrepeat\s*=\s*[1-4]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0217][PASS] pwquality maxclassrepeat <= 4"
    set_flag flag_217 1
else
    log_append "[TWGCB-01-012-0217][FAIL] pwquality maxclassrepeat is not set to 4 or less"
    set_flag flag_217 0
fi

# TWGCB-01-012-0218: pwquality maxrepeat <= 3
if grep -qsE '^\s*maxrepeat\s*=\s*[1-3]' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0218][PASS] pwquality maxrepeat <= 3"
    set_flag flag_218 1
else
    log_append "[TWGCB-01-012-0218][FAIL] pwquality maxrepeat is not set to 3 or less"
    set_flag flag_218 0
fi

# TWGCB-01-012-0219: pwquality dictcheck=1
if grep -qsE '^\s*dictcheck\s*=\s*1' /etc/security/pwquality.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0219][PASS] pwquality dictcheck=1 is configured"
    set_flag flag_219 1
else
    log_append "[TWGCB-01-012-0219][FAIL] pwquality dictcheck=1 is not configured"
    set_flag flag_219 0
fi

# TWGCB-01-012-0220: faillock deny <= 5
flock220_fail=0
if grep -qsE '^\s*deny\s*=\s*[1-5]' /etc/security/faillock.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0220][PASS] faillock deny <= 5 in faillock.conf"
elif grep -rqsE 'pam_faillock\.so.*deny=[1-5]' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
    log_append "[TWGCB-01-012-0220][PASS] faillock deny <= 5 in PAM files"
else
    log_append "[TWGCB-01-012-0220][FAIL] faillock deny is not set to 5 or less"
    flock220_fail=1
fi
if [ $flock220_fail -eq 0 ]; then set_flag flag_220 1; else set_flag flag_220 0; fi

# TWGCB-01-012-0221: faillock unlock_time >= 900
flock221_fail=0
if grep -qsE '^\s*unlock_time\s*=\s*(9[0-9][0-9]|[1-9][0-9]{3,})' /etc/security/faillock.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0221][PASS] faillock unlock_time >= 900 in faillock.conf"
elif grep -rqsE 'pam_faillock\.so.*unlock_time=(9[0-9][0-9]|[1-9][0-9]{3,})' /etc/pam.d/system-auth /etc/pam.d/password-auth 2>/dev/null; then
    log_append "[TWGCB-01-012-0221][PASS] faillock unlock_time >= 900 in PAM files"
else
    log_append "[TWGCB-01-012-0221][FAIL] faillock unlock_time is not set to 900 or more"
    flock221_fail=1
fi
if [ $flock221_fail -eq 0 ]; then set_flag flag_221 1; else set_flag flag_221 0; fi

# TWGCB-01-012-0222: password remember >= 3
pam222_fail=0
for f in /etc/pam.d/system-auth /etc/pam.d/password-auth; do
    [ ! -f "$f" ] && continue
    if grep -qE '^\s*password\s+.*(pam_unix|pam_pwhistory)\.so.*remember=[3-9]' "$f" 2>/dev/null; then
        log_append "[TWGCB-01-012-0222][PASS] password remember >= 3 in $f"
    else
        log_append "[TWGCB-01-012-0222][FAIL] password remember is not set to 3 or more in $f"
        pam222_fail=1
    fi
done
if [ $pam222_fail -eq 0 ]; then set_flag flag_222 1; else set_flag flag_222 0; fi

# TWGCB-01-012-0223: pam_lastlog showfailed
pam223_found=0
for f in /etc/pam.d/system-auth /etc/pam.d/login /etc/pam.d/sshd; do
    [ ! -f "$f" ] && continue
    if grep -qE '^\s*session\s+required\s+pam_lastlog\.so.*showfailed' "$f" 2>/dev/null; then
        log_append "[TWGCB-01-012-0223][PASS] pam_lastlog showfailed configured in $f"
        pam223_found=1
        break
    fi
done
if [ $pam223_found -eq 1 ]; then set_flag flag_223 1; else
    log_append "[TWGCB-01-012-0223][FAIL] pam_lastlog showfailed not configured"
    set_flag flag_223 0
fi

# TWGCB-01-012-0224: crypt_style=sha512 and ENCRYPT_METHOD=SHA512
pw224_fail=0
if grep -qsE '^\s*crypt_style\s*=\s*sha512' /etc/libuser.conf 2>/dev/null; then
    log_append "[TWGCB-01-012-0224][PASS] libuser.conf crypt_style=sha512"
else
    log_append "[TWGCB-01-012-0224][FAIL] libuser.conf crypt_style=sha512 not set"
    pw224_fail=1
fi
if grep -qsE '^\s*ENCRYPT_METHOD\s+SHA512' /etc/login.defs 2>/dev/null; then
    log_append "[TWGCB-01-012-0224][PASS] login.defs ENCRYPT_METHOD=SHA512"
else
    log_append "[TWGCB-01-012-0224][FAIL] login.defs ENCRYPT_METHOD=SHA512 not set"
    pw224_fail=1
fi
if [ $pw224_fail -eq 0 ]; then set_flag flag_224 1; else set_flag flag_224 0; fi

# TWGCB-01-012-0225: PASS_MIN_DAYS >= 1
if grep -qsE '^\s*PASS_MIN_DAYS\s+[1-9]' /etc/login.defs 2>/dev/null; then
    log_append "[TWGCB-01-012-0225][PASS] login.defs PASS_MIN_DAYS >= 1"
    set_flag flag_225 1
else
    log_append "[TWGCB-01-012-0225][FAIL] login.defs PASS_MIN_DAYS is not set to 1 or more"
    set_flag flag_225 0
fi

# TWGCB-01-012-0226: PASS_WARN_AGE >= 14
if grep -qsE '^\s*PASS_WARN_AGE\s+(1[4-9]|[2-9][0-9])' /etc/login.defs 2>/dev/null; then
    log_append "[TWGCB-01-012-0226][PASS] login.defs PASS_WARN_AGE >= 14"
    set_flag flag_226 1
else
    log_append "[TWGCB-01-012-0226][FAIL] login.defs PASS_WARN_AGE is not set to 14 or more"
    set_flag flag_226 0
fi

# TWGCB-01-012-0227: PASS_MAX_DAYS <= 90
max_days=$(grep -sE '^\s*PASS_MAX_DAYS\s+' /etc/login.defs 2>/dev/null | awk '{print $2}')
if [ -n "$max_days" ] && [ "$max_days" -le 90 ] 2>/dev/null; then
    log_append "[TWGCB-01-012-0227][PASS] login.defs PASS_MAX_DAYS=$max_days (<= 90)"
    set_flag flag_227 1
else
    log_append "[TWGCB-01-012-0227][FAIL] login.defs PASS_MAX_DAYS is not set to 90 or less (current: ${max_days:-not set})"
    set_flag flag_227 0
fi

# TWGCB-01-012-0228: useradd default INACTIVE <= 30
inactive_val=$(useradd -D 2>/dev/null | grep INACTIVE | cut -d= -f2)
if [ -n "$inactive_val" ] && [ "$inactive_val" -le 30 ] && [ "$inactive_val" -ge 1 ] 2>/dev/null; then
    log_append "[TWGCB-01-012-0228][PASS] useradd default INACTIVE=$inactive_val (<= 30)"
    set_flag flag_228 1
else
    log_append "[TWGCB-01-012-0228][FAIL] useradd default INACTIVE is not set to 30 or less (current: ${inactive_val:-not set})"
    set_flag flag_228 0
fi

# TWGCB-01-012-0229: FAIL_DELAY >= 4
fail_delay=$(grep -sE '^\s*FAIL_DELAY\s+' /etc/login.defs 2>/dev/null | awk '{print $2}')
if [ -n "$fail_delay" ] && [ "$fail_delay" -ge 4 ] 2>/dev/null; then
    log_append "[TWGCB-01-012-0229][PASS] login.defs FAIL_DELAY=$fail_delay (>= 4)"
    set_flag flag_229 1
else
    log_append "[TWGCB-01-012-0229][FAIL] login.defs FAIL_DELAY is not set to 4 or more (current: ${fail_delay:-not set})"
    set_flag flag_229 0
fi

# TWGCB-01-012-0230: CREATE_HOME=yes
if grep -qsE '^\s*CREATE_HOME\s+yes' /etc/login.defs 2>/dev/null; then
    log_append "[TWGCB-01-012-0230][PASS] login.defs CREATE_HOME=yes"
    set_flag flag_230 1
else
    log_append "[TWGCB-01-012-0230][FAIL] login.defs CREATE_HOME=yes is not set"
    set_flag flag_230 0
fi

# TWGCB-01-012-0231: sudoers no NOPASSWD or !authenticate
sudo231_fail=0
if grep -rsiE '(NOPASSWD|!authenticate)' /etc/sudoers /etc/sudoers.d/ 2>/dev/null | grep -vE '^\s*#' | grep -q .; then
    log_append "[TWGCB-01-012-0231][FAIL] NOPASSWD or !authenticate found in sudoers (manual remediation required)"
    sudo231_fail=1
else
    log_append "[TWGCB-01-012-0231][PASS] no NOPASSWD or !authenticate in sudoers"
fi
if [ $sudo231_fail -eq 0 ]; then set_flag flag_231 1; else set_flag flag_231 0; fi

# TWGCB-01-012-0232: limits maxlogins <= 10
if grep -rqsE '^\s*\*\s+hard\s+maxlogins\s+([1-9]|10)\b' /etc/security/limits.conf /etc/security/limits.d/ 2>/dev/null; then
    log_append "[TWGCB-01-012-0232][PASS] limits maxlogins <= 10 is configured"
    set_flag flag_232 1
else
    log_append "[TWGCB-01-012-0232][FAIL] limits maxlogins is not configured to 10 or less"
    set_flag flag_232 0
fi

# TWGCB-01-012-0233: kbd package installed
if rpm -q kbd &>/dev/null; then
    log_append "[TWGCB-01-012-0233][PASS] kbd package is installed"
    set_flag flag_233 1
else
    log_append "[TWGCB-01-012-0233][FAIL] kbd package is not installed"
    set_flag flag_233 0
fi

# TWGCB-01-012-0234: GNOME screensaver lock-enabled=true
if command -v dconf &>/dev/null; then
    if grep -rqsE '^\s*lock-enabled\s*=\s*true' /etc/dconf/db/ 2>/dev/null; then
        log_append "[TWGCB-01-012-0234][PASS] GNOME screensaver lock-enabled=true"
        set_flag flag_234 1
    else
        log_append "[TWGCB-01-012-0234][FAIL] GNOME screensaver lock-enabled=true not configured"
        set_flag flag_234 0
    fi
else
    log_append "[TWGCB-01-012-0234][SKIP] dconf not installed (GNOME not present)"
    set_flag flag_234 2
fi

# TWGCB-01-012-0235: GNOME idle-delay >= 900
if command -v dconf &>/dev/null; then
    if grep -rqsE '^\s*idle-delay\s*=\s*uint32\s+[89][0-9][0-9]|idle-delay\s*=\s*uint32\s+[1-9][0-9]{3,}' /etc/dconf/db/ 2>/dev/null; then
        log_append "[TWGCB-01-012-0235][PASS] GNOME idle-delay >= 900 configured"
        set_flag flag_235 1
    else
        log_append "[TWGCB-01-012-0235][FAIL] GNOME idle-delay is not set to 900 or more"
        set_flag flag_235 0
    fi
else
    log_append "[TWGCB-01-012-0235][SKIP] dconf not installed (GNOME not present)"
    set_flag flag_235 2
fi

# TWGCB-01-012-0236: GDM AutomaticLoginEnable=false
if [ -f /etc/gdm/custom.conf ]; then
    if grep -qsE '^\s*AutomaticLoginEnable\s*=\s*[Ff]alse' /etc/gdm/custom.conf 2>/dev/null; then
        log_append "[TWGCB-01-012-0236][PASS] GDM AutomaticLoginEnable=false"
        set_flag flag_236 1
    else
        log_append "[TWGCB-01-012-0236][FAIL] GDM AutomaticLoginEnable is not set to false"
        set_flag flag_236 0
    fi
else
    log_append "[TWGCB-01-012-0236][SKIP] /etc/gdm/custom.conf not found (GDM not installed)"
    set_flag flag_236 2
fi

# TWGCB-01-012-0237: system accounts use nologin or /bin/false
uid_min=$(awk '/^\s*UID_MIN/{print $2}' /etc/login.defs 2>/dev/null)
uid_min="${uid_min:-1000}"
nologin_path=$(which nologin 2>/dev/null || echo "/sbin/nologin")
sys237_fail=0
while IFS=: read -r user _ uid _ _ _ shell; do
    [ "$user" = "root" ] || [ "$user" = "sync" ] || [ "$user" = "shutdown" ] || [ "$user" = "halt" ] && continue
    [[ "$user" =~ ^\+ ]] && continue
    [ "$uid" -ge "$uid_min" ] 2>/dev/null && continue
    if [ "$shell" != "$nologin_path" ] && [ "$shell" != "/bin/false" ] && [ "$shell" != "/usr/sbin/nologin" ]; then
        log_append "[TWGCB-01-012-0237][FAIL] system account $user has login shell: $shell"
        sys237_fail=1
    fi
done < /etc/passwd
if [ $sys237_fail -eq 0 ]; then
    log_append "[TWGCB-01-012-0237][PASS] all system accounts use nologin or /bin/false"
    set_flag flag_237 1
else
    set_flag flag_237 0
fi

# TWGCB-01-012-0238: TMOUT >= 900
if grep -rqsE '^\s*readonly\s+TMOUT\s*=\s*(9[0-9][0-9]|[1-9][0-9]{3,})' /etc/profile /etc/profile.d/ 2>/dev/null || \
   grep -rqsE '^\s*TMOUT\s*=\s*(9[0-9][0-9]|[1-9][0-9]{3,})' /etc/profile /etc/profile.d/ 2>/dev/null; then
    log_append "[TWGCB-01-012-0238][PASS] TMOUT >= 900 configured in profile"
    set_flag flag_238 1
else
    log_append "[TWGCB-01-012-0238][FAIL] TMOUT >= 900 not configured in /etc/profile or /etc/profile.d/"
    set_flag flag_238 0
fi

# TWGCB-01-012-0239: GNOME dconf locks for screensaver
if command -v dconf &>/dev/null; then
    if grep -rqsF '/org/gnome/desktop/session/idle-delay' /etc/dconf/db/ 2>/dev/null; then
        log_append "[TWGCB-01-012-0239][PASS] GNOME dconf locks for screensaver configured"
        set_flag flag_239 1
    else
        log_append "[TWGCB-01-012-0239][FAIL] GNOME dconf locks for screensaver not configured"
        set_flag flag_239 0
    fi
else
    log_append "[TWGCB-01-012-0239][SKIP] dconf not installed (GNOME not present)"
    set_flag flag_239 2
fi

# TWGCB-01-012-0240: root primary group GID 0
root_gid=$(id -g root 2>/dev/null)
if [ "$root_gid" = "0" ]; then
    log_append "[TWGCB-01-012-0240][PASS] root primary group is GID 0"
    set_flag flag_240 1
else
    log_append "[TWGCB-01-012-0240][FAIL] root primary group is GID $root_gid (expected 0)"
    set_flag flag_240 0
fi

# TWGCB-01-012-0241: umask 027 in profile files
umask241_fail=0
if grep -rqsE '^\s*umask\s+0?27\b' /etc/profile /etc/profile.d/ /etc/bashrc 2>/dev/null; then
    log_append "[TWGCB-01-012-0241][PASS] umask 027 configured in profile files"
else
    log_append "[TWGCB-01-012-0241][FAIL] umask 027 not configured in /etc/profile or /etc/bashrc"
    umask241_fail=1
fi
if [ $umask241_fail -eq 0 ]; then set_flag flag_241 1; else set_flag flag_241 0; fi

# TWGCB-01-012-0242: login.defs UMASK=027
if grep -qsE '^\s*UMASK\s+0?27\b' /etc/login.defs 2>/dev/null; then
    log_append "[TWGCB-01-012-0242][PASS] login.defs UMASK=027"
    set_flag flag_242 1
else
    log_append "[TWGCB-01-012-0242][FAIL] login.defs UMASK is not set to 027"
    set_flag flag_242 0
fi

# TWGCB-01-012-0243: /etc/pam.d/su has pam_wheel.so use_uid
if grep -qsE '^\s*auth\s+required\s+pam_wheel\.so\s+use_uid' /etc/pam.d/su 2>/dev/null; then
    log_append "[TWGCB-01-012-0243][PASS] /etc/pam.d/su has auth required pam_wheel.so use_uid"
    set_flag flag_243 1
else
    log_append "[TWGCB-01-012-0243][FAIL] /etc/pam.d/su missing auth required pam_wheel.so use_uid"
    set_flag flag_243 0
fi

# TWGCB-01-012-0244: firewalld installed
if rpm -q firewalld &>/dev/null; then
    log_append "[TWGCB-01-012-0244][PASS] firewalld is installed"
    set_flag flag_244 1
else
    log_append "[TWGCB-01-012-0244][FAIL] firewalld is not installed"
    set_flag flag_244 0
fi

# TWGCB-01-012-0245: firewalld service enabled
if systemctl is-enabled firewalld 2>/dev/null | grep -q '^enabled$'; then
    log_append "[TWGCB-01-012-0245][PASS] firewalld service is enabled"
    set_flag flag_245 1
else
    log_append "[TWGCB-01-012-0245][FAIL] firewalld service is not enabled"
    set_flag flag_245 0
fi

# TWGCB-01-012-0246: iptables/ip6tables disabled when using firewalld
if [ $flag_244 -ne 1 ]; then
    log_append "[TWGCB-01-012-0246][SKIP] firewalld not installed; skipping iptables check"
    set_flag flag_246 2
else
    ipt246_fail=0
    for svc in iptables ip6tables; do
        if systemctl is-enabled "$svc" > /dev/null 2>&1; then
            log_append "[TWGCB-01-012-0246][FAIL] $svc is enabled (should be masked when using firewalld)"
            ipt246_fail=1
        fi
    done
    if [ $ipt246_fail -eq 0 ]; then
        log_append "[TWGCB-01-012-0246][PASS] iptables and ip6tables are disabled/masked"
        set_flag flag_246 1
    else
        set_flag flag_246 0
    fi
fi

# TWGCB-01-012-0247: nftables disabled when using firewalld
if [ $flag_244 -ne 1 ]; then
    log_append "[TWGCB-01-012-0247][SKIP] firewalld not installed; skipping nftables-disable check"
    set_flag flag_247 2
else
    if systemctl is-enabled nftables > /dev/null 2>&1; then
        log_append "[TWGCB-01-012-0247][FAIL] nftables is enabled (should be masked when using firewalld)"
        set_flag flag_247 0
    else
        log_append "[TWGCB-01-012-0247][PASS] nftables is disabled/masked"
        set_flag flag_247 1
    fi
fi

# TWGCB-01-012-0248: firewalld default zone set
if [ $flag_244 -ne 1 ]; then
    log_append "[TWGCB-01-012-0248][SKIP] firewalld not installed"
    set_flag flag_248 2
else
    default_zone=$(firewall-cmd --get-default-zone 2>/dev/null)
    if [ -n "$default_zone" ]; then
        log_append "[TWGCB-01-012-0248][PASS] firewalld default zone is: $default_zone"
        set_flag flag_248 1
    else
        log_append "[TWGCB-01-012-0248][FAIL] firewalld default zone is not set"
        set_flag flag_248 0
    fi
fi

# TWGCB-01-012-0249: nftables service enabled (when using nftables)
if [ $flag_245 -eq 1 ]; then
    log_append "[TWGCB-01-012-0249][SKIP] firewalld is in use; nftables section not applicable"
    set_flag flag_249 2
else
    if systemctl is-enabled nftables 2>/dev/null | grep -q '^enabled$'; then
        log_append "[TWGCB-01-012-0249][PASS] nftables service is enabled"
        set_flag flag_249 1
    else
        log_append "[TWGCB-01-012-0249][FAIL] nftables service is not enabled"
        set_flag flag_249 0
    fi
fi

# TWGCB-01-012-0250: firewalld disabled when using nftables
if [ $flag_245 -eq 1 ]; then
    log_append "[TWGCB-01-012-0250][SKIP] firewalld is in use; nftables section not applicable"
    set_flag flag_250 2
else
    if systemctl is-enabled firewalld > /dev/null 2>&1; then
        log_append "[TWGCB-01-012-0250][FAIL] firewalld is enabled (should be masked when using nftables)"
        set_flag flag_250 0
    else
        log_append "[TWGCB-01-012-0250][PASS] firewalld is disabled/masked"
        set_flag flag_250 1
    fi
fi

# TWGCB-01-012-0251: nftables has at least 1 table (when using nftables)
if [ $flag_245 -eq 1 ]; then
    log_append "[TWGCB-01-012-0251][SKIP] firewalld is in use; nftables section not applicable"
    set_flag flag_251 2
else
    if nft list tables 2>/dev/null | grep -q .; then
        log_append "[TWGCB-01-012-0251][PASS] nftables has at least 1 table configured"
        set_flag flag_251 1
    else
        log_append "[TWGCB-01-012-0251][FAIL] nftables has no tables configured"
        set_flag flag_251 0
    fi
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
