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

# 因為需要操作硬碟系統，所以先備份 /etc/fstab，以防止修改錯誤導致系統無法啟動
cp /etc/fstab /etc/fstab.bak

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
    log_append "[TWGCB-01-008-0008][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0009
# 需為/var/tmp配置獨立之分割磁區或邏輯磁區
if [ $flag_009 -eq 0 ]; then
    log_append "[TWGCB-01-008-0009][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0010
# /var/tmp須設定nodev選項
# TWGCB-01-008-0011
# /var/tmp須設定nosuid選項
# TWGCB-01-008-0012
# /var/tmp須設定noexec選項
if [ $flag_010 -eq 0 ] || [ $flag_011 -eq 0 ] || [ $flag_012 -eq 0 ]; then
    # 這裡假設/var/tmp是獨立的分割區，並且使用tmpfs掛載
    # 如果不是，則需要根據實際情況調整掛載方式
    mount_point="/var/tmp"
    if awk -v mp="$mount_point" '
    BEGIN { OFS="\t" }
    # 跳過空行與註解
    /^[[:space:]]*($|#)/ { print; next }
    {
    # fstab 正常至少 4 欄：spec mount fstype options
    # 若欄位不足就原樣輸出
    if (NF < 4) { print; next }
    # 只處理 mount point = /var/tmp 的那行
    if ($2 != mp) { print; next }
    opts = $4
    # 拆 options
    n = split(opts, a, ",")
    # 用 seen 做去重（保留原順序）
    out = ""
    delete seen
    for (i = 1; i <= n; i++) {
        o = a[i]
        if (o == "") continue
        if (!(o in seen)) {
        seen[o] = 1
        out = (out == "" ? o : out "," o)
        }
    }
    # 確保 nodev 存在（不存在才加）
    if (!("nodev" in seen)) out = (out == "" ? "nodev" : out ",nodev")
    # 確保 nosuid 存在（不存在才加）
    if (!("nosuid" in seen)) out = (out == "" ? "nosuid" : out ",nosuid")
    # 確保 noexec 存在（不存在才加）
    if (!("noexec" in seen)) out = (out == "" ? "noexec" : out ",noexec")
    # 輸出修改後的行
    $4 = out
    print
    }
    ' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab; then
        log_append "[TWGCB-01-008-0010][FIX] add nodev option to /var/tmp in /etc/fstab"
        log_append "[TWGCB-01-008-0011][FIX] add nosuid option to /var/tmp in /etc/fstab"
        log_append "[TWGCB-01-008-0012][FIX] add noexec option to /var/tmp in /etc/fstab"
    else
        log_append "[TWGCB-01-008-0010][ERROR] failed to update /etc/fstab for nodev option on /var/tmp"
        log_append "[TWGCB-01-008-0011][ERROR] failed to update /etc/fstab for nosuid option on /var/tmp"
        log_append "[TWGCB-01-008-0012][ERROR] failed to update /etc/fstab for noexec option on /var/tmp"
    fi
    # 重新掛載
    mount -o remount,nodev,nosuid,noexec "$mount_point" 2>/dev/null || true
    #log_append "[TWGCB-01-008-0010][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0013
# 需為/var/log配置獨立之分割磁區或邏輯磁區
if [ $flag_013 -eq 0 ]; then
    log_append "[TWGCB-01-008-0013][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0014
# 需為/var/log/audit配置獨立之分割磁區或邏輯磁區
if [ $flag_014 -eq 0 ]; then
    log_append "[TWGCB-01-008-0014][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0015
# 需為/home配置獨立之分割磁區或邏輯磁區
if [ $flag_015 -eq 0 ]; then
    log_append "[TWGCB-01-008-0015][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0016
# /home須設定nodev選項
if [ $flag_016 -eq 0 ]; then
    log_append "[TWGCB-01-008-0016][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# ======================================
