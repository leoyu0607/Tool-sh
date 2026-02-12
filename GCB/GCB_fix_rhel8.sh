#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260212

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

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
    set_flag flag_004
    log_append "[TWGCB-01-008-0004][FIX] set /tmp mounted as tmpfs"
fi
# ======================================
# TWGCB-01-008-0005
# /tmp目錄之nodev選項須設定為啟用
if [ $flag_005 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    set_flag flag_005
    log_append "[TWGCB-01-008-0005][FIX] set /tmp option as nodev"
fi
# ======================================
# TWGCB-01-008-0006
# /tmp目錄之nosuid選項須設定為啟用
if [ $flag_006 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    set_flag flag_006
    log_append "[TWGCB-01-008-0006][FIX] set /tmp option as nosuid"
fi
# ======================================
# TWGCB-01-008-0007
# /tmp目錄之noexec選項須設定為啟用
if [ $flag_007 -eq 0 ]; then
    #sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev,noexec/" /usr/lib/systemd/system/tmp.mount
    #sudo systemctl daemon-reload
    #sudo systemctl restart tmp.mount
    # set_flag flag_007
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
        set_flag flag_010
        log_append "[TWGCB-01-008-0010][FIX] add nodev option to /var/tmp in /etc/fstab"
        set_flag flag_011
        log_append "[TWGCB-01-008-0011][FIX] add nosuid option to /var/tmp in /etc/fstab"
        set_flag flag_012
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
    # 這裡假設/home是獨立的分割區，並且使用tmpfs掛載
    # 如果不是，則需要根據實際情況調整掛載方式
    mount_point="/home"
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
    # 輸出修改後的行
    $4 = out
    print
    }
    ' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab; then
        set_flag flag_016
        log_append "[TWGCB-01-008-0016][FIX] add nodev option to /home in /etc/fstab"
    else
        log_append "[TWGCB-01-008-0016][ERROR] failed to update /etc/fstab for nodev option on /home"
    fi
    # 重新掛載
    mount -o remount,nodev "$mount_point" 2>/dev/null || true
    #log_append "[TWGCB-01-008-0010][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0017
# /dev/shm須設定nodev選項
# TWGCB-01-008-0018
# /dev/shm須設定nosuid選項
# TWGCB-01-008-0019
# /dev/shm須設定noexec選項
if [ $flag_017 -eq 0 ] || [ $flag_018 -eq 0 ] || [ $flag_019 -eq 0 ]; then
    echo "tmpfs /dev/shm tmpfs rw,nodev,nosuid,noexec,seclabel 0 0" >> /etc/fstab
    systemctl daemon-reload
    mount -o remount,nodev,nosuid,noexec /dev/shm
    set_flag flag_017 1
    log_append "[TWGCB-01-008-0017][FIX] add nodev option to /dev/shm in /etc/fstab"
    set_flag flag_018 1
    log_append "[TWGCB-01-008-0018][FIX] add nosuid option to /dev/shm in /etc/fstab"
    set_flag flag_019 1
    log_append "[TWGCB-01-008-0019][FIX] add noexec option to /dev/shm in /etc/fstab"
fi
# ======================================
# TWGCB-01-008-0020
# 可攜式儲存裝置須設定nodev選項
# TWGCB-01-008-0021
# 可攜式儲存裝置須設定nosuid選項
# TWGCB-01-008-0022
# 可攜式儲存裝置須設定noexec選項
# TWGCB-01-008-0031
# 需停用USB儲存裝置
if [ $flag_020 -eq 0 ] || [ $flag_021 -eq 0 ] || [ $flag_022 -eq 0 ] || [ $flag_031 -eq 0 ]; then
    echo "install usb-storage /bin/true" > /etc/modprobe.d/disable-usb-storage.conf
    echo "blacklist usb-storage" >> /etc/modprobe.d/disable-usb-storage.conf
    sudo dracut -f
    set_flag flag_020 1
    log_append "[TWGCB-01-008-0020][FIX] disable usb-storage module to prevent portable storage devices"
    set_flag flag_021 1
    log_append "[TWGCB-01-008-0021][FIX] disable usb-storage module to prevent portable storage devices"
    set_flag flag_022 1
    log_append "[TWGCB-01-008-0022][FIX] disable usb-storage module to prevent portable storage devices"
    set_flag flag_031 1
    log_append "[TWGCB-01-008-0031][FIX] disable usb-storage module to prevent USB storage devices"
fi
# ======================================
# TWGCB-01-008-0023
# 使用者家目錄須設定nodev選項
# TWGCB-01-008-0024
# 使用者家目錄須設定nosuid選項
# TWGCB-01-008-0025
# 使用者家目錄須設定noexec選項
if [ $flag_023 -eq 0 ] || [ $flag_024 -eq 0 ] || [ $flag_025 -eq 0 ]; then
    submounts=$(findmnt -R -n -o TARGET /home | tail -n +2)
    for mp in $submounts; do
        if awk -v mp="$mp" '
        BEGIN { OFS="\t" }
        # 跳過空行與註解
        /^[[:space:]]*($|#)/ { print; next }
        {
        # fstab 正常至少 4 欄：spec mount fstype options
        # 若欄位不足就原樣輸出
        if (NF < 4) { print; next }
        # 只處理 mount point = mp 的那行
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
        #if (!("noexec" in seen)) out = (out == "" ? "noexec" : out ",noexec")
        # 輸出修改後的行
        $4 = out
        print
        }
        ' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab; then
            set_flag flag_023 1
            log_append "[TWGCB-01-008-0023][FIX] add nodev option to /home in /etc/fstab"
            set_flag flag_024 1
            log_append "[TWGCB-01-008-0024][FIX] add nosuid option to /home in /etc/fstab"
            set_flag flag_025 1
            log_append "[TWGCB-01-008-0025][IGNORE] 設定後影響服務使用"
        else
            log_append "[TWGCB-01-008-0023][ERROR] failed to update /etc/fstab for nodev option on /home"
            log_append "[TWGCB-01-008-0024][ERROR] failed to update /etc/fstab for nosuid option on /home"
            log_append "[TWGCB-01-008-0025][IGNORE] 設定後影響服務使用"
        fi
        # 重新掛載
        mount -o remount,nodev,nosuid,noexec "$mp" 2>/dev/null || true
    done
fi
# ======================================
# TWGCB-01-008-0026
# NFS須設定nodev選項
# TWGCB-01-008-0027
# NFS須設定nosuid選項
# TWGCB-01-008-0028
# NFS須設定noexec選項
if [ $flag_026 -eq 0 ] || [ $flag_027 -eq 0 ] || [ $flag_028 -eq 0 ]; then
    nfs_mounts=$(findmnt -t nfs4,nfs -n -o TARGET)
    for mp in $nfs_mounts; do
        if awk -v mp="$mp" '
        BEGIN { OFS="\t" }
        # 跳過空行與註解
        /^[[:space:]]*($|#)/ { print; next }
        {
        # fstab 正常至少 4 欄：spec mount fstype options
        # 若欄位不足就原樣輸出
        if (NF < 4) { print; next }
        # 只處理 mount point = mp 的那行
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
            set_flag flag_026 1
            log_append "[TWGCB-01-008-0026][FIX] add nodev option to NFS mount points in /etc/fstab"
            set_flag flag_027 1
            log_append "[TWGCB-01-008-0027][FIX] add nosuid option to NFS mount points in /etc/fstab"
            set_flag flag_028 1
            log_append "[TWGCB-01-008-0028][FIX] add noexec option to NFS mount points in /etc/fstab"
        else
            log_append "[TWGCB-01-008-0026][ERROR] failed to update /etc/fstab for nodev option on NFS mount points"
            log_append "[TWGCB-01-008-0027][ERROR] failed to update /etc/fstab for nosuid option on NFS mount points"
            log_append "[TWGCB-01-008-0028][ERROR] failed to update /etc/fstab for noexec option on NFS mount points"
        fi
        # 重新掛載
        mount -o remount,nodev,nosuid,noexec "$mp" 2>/dev/null || true
    done
fi
# ======================================
# TWGCB-01-008-0029
# 所有具有全域寫入(World-writable)權限之目錄須設定粘滯位(Sticky bit)
if [ $flag_029 -eq 0 ]; then
    dirs=$(find $(findmnt -rn -o TARGET -t ext4,xfs) -type d -perm -0002 ! -perm -1000 2>/dev/null)
    for dir in $dirs; do
        if chmod +t "$dir"; then
            log_append "[TWGCB-01-008-0029][FIX] set sticky bit on world-writable directory: $dir"
        else
            log_append "[TWGCB-01-008-0029][ERROR] failed to set sticky bit on world-writable directory: $dir"
        fi
    done
fi
# ======================================
# TWGCB-01-008-0030
# 需停用autofs服務
if [ $flag_030 -eq 0 ]; then
    if systemctl disable --now autofs; then
        set_flag flag_030 1
        log_append "[TWGCB-01-008-0030][FIX] disable autofs service"
    else
        log_append "[TWGCB-01-008-0030][ERROR] failed to disable autofs service"
    fi
fi
# ======================================
# ======================================
# ======================================

echo "Fix completed. Please reboot the system and review the log file for details."