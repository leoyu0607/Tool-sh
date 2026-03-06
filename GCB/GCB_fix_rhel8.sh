#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260217

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

flag="./.GCBflag"
source "$flag"
log="./GCB_fix_rhel8.log"
> "$log"

success=0
ignore=0
error=0

log_append() {
    timestamp=$(date "+%Y-%m-%d %H:%M:%S")
    echo "$timestamp $1" | tee -a "$log"
}

set_flag() {
    if [  $2 -eq 1 ]; then
        eval "$1=$2"
        sed -i "s/^$1=.*/$1=$2/" "$flag"
        success=$((success + 1))
    elif [ $2 -eq 2 ]; then
        eval "$1=$2"
        sed -i "s/^$1=.*/$1=$2/" "$flag"
        ignore=$((ignore + 1))
    else
        eval "$1=$2"
        sed -i "s/^$1=.*/$1=$2/" "$flag"
        error=$((error + 1))
    fi
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
    set_flag flag_001 1
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
    set_flag flag_002 1
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
    set_flag flag_003 1
    log_append "[TWGCB-01-008-0003][FIX] disable the udf"
fi
# ======================================
# TWGCB-01-008-0004
# 設定/tmp目錄需為tmpfs
if [ $flag_004 -eq 0 ]; then
    systemctl enable --now tmp.mount
    set_flag flag_004 1
    log_append "[TWGCB-01-008-0004][FIX] set /tmp mounted as tmpfs"
fi
# ======================================
# TWGCB-01-008-0005
# /tmp目錄之nodev選項須設定為啟用
if [ $flag_005 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    set_flag flag_005 1
    log_append "[TWGCB-01-008-0005][FIX] set /tmp option as nodev"
fi
# ======================================
# TWGCB-01-008-0006
# /tmp目錄之nosuid選項須設定為啟用
if [ $flag_006 -eq 0 ]; then
    sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev/" /usr/lib/systemd/system/tmp.mount
    sudo systemctl daemon-reload
    sudo systemctl restart tmp.mount
    set_flag flag_006 1
    log_append "[TWGCB-01-008-0006][FIX] set /tmp option as nosuid"
fi
# ======================================
# TWGCB-01-008-0007
# /tmp目錄之noexec選項須設定為啟用
if [ $flag_007 -eq 0 ]; then
    #sed -i "s/Options.*/Options=mode=1777,strictatime,nosuid,nodev,noexec/" /usr/lib/systemd/system/tmp.mount
    #sudo systemctl daemon-reload
    #sudo systemctl restart tmp.mount
    # set_flag flag_007 1
    #log_append "[TWGCB-01-008-0007][FIX] set /tmp option as noexec"
    log_append "[TWGCB-01-008-0007][IGNORE] 設定後影響服務使用"
fi
# ======================================
# TWGCB-01-008-0008
# 需為/var配置獨立之分割磁區或邏輯磁區
if [ $flag_008 -eq 0 ]; then
    set_flag flag_008 2
    log_append "[TWGCB-01-008-0008][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0009
# 需為/var/tmp配置獨立之分割磁區或邏輯磁區
if [ $flag_009 -eq 0 ]; then
    set_flag flag_008 2
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
        set_flag flag_010 1
        log_append "[TWGCB-01-008-0010][FIX] add nodev option to /var/tmp in /etc/fstab"
        set_flag flag_011 1
        log_append "[TWGCB-01-008-0011][FIX] add nosuid option to /var/tmp in /etc/fstab"
        set_flag flag_012 1
        log_append "[TWGCB-01-008-0012][FIX] add noexec option to /var/tmp in /etc/fstab"
    else
        set_flag flag_010 0
        log_append "[TWGCB-01-008-0010][ERROR] failed to update /etc/fstab for nodev option on /var/tmp"
        set_flag flag_011 0
        log_append "[TWGCB-01-008-0011][ERROR] failed to update /etc/fstab for nosuid option on /var/tmp"
        set_flag flag_012 0
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
    set_flag flag_013 2
    log_append "[TWGCB-01-008-0013][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0014
# 需為/var/log/audit配置獨立之分割磁區或邏輯磁區
if [ $flag_014 -eq 0 ]; then
    set_flag flag_014 2
    log_append "[TWGCB-01-008-0014][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-008-0015
# 需為/home配置獨立之分割磁區或邏輯磁區
if [ $flag_015 -eq 0 ]; then
    set_flag flag_015 2
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
        set_flag flag_016 1
        log_append "[TWGCB-01-008-0016][FIX] add nodev option to /home in /etc/fstab"
    else
        set_flag flag_016 0
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
    echo "即將重新載入模組"
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
            set_flag flag_023 0
            log_append "[TWGCB-01-008-0023][ERROR] failed to update /etc/fstab for nodev option on /home"
            set_flag flag_024 0
            log_append "[TWGCB-01-008-0024][ERROR] failed to update /etc/fstab for nosuid option on /home"
            set_flag flag_025 0
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
            set_flag flag_026 0
            log_append "[TWGCB-01-008-0026][ERROR] failed to update /etc/fstab for nodev option on NFS mount points"
            set_flag flag_027 0
            log_append "[TWGCB-01-008-0027][ERROR] failed to update /etc/fstab for nosuid option on NFS mount points"
            set_flag flag_028 0
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
            set_flag flag_029 1
            log_append "[TWGCB-01-008-0029][FIX] set sticky bit on world-writable directory: $dir"
        else
            set_flag flag_029 0
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
        set_flag flag_030 0
        log_append "[TWGCB-01-008-0030][ERROR] failed to disable autofs service"
    fi
fi
# ======================================
# TWGCB-01-008-0031
# 需停用USB儲存裝置
# 已經在前面 TWGCB-01-008-0020 ~ TWGCB-01-008-0022 的修正中處理了
# ======================================
# TWGCB-01-008-0032
# 啟用GPG簽章驗證功能
if [ $flag_032 -eq 0 ]; then
    #修復全域設定
    if [ -f /etc/dnf/dnf.conf ]; then
        cp -a /etc/dnf/dnf.conf "/etc/dnf/dnf.conf.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
        sed -i -E '/^\s*gpgcheck\s*=/d' /etc/dnf/dnf.conf
        sed -i -E '/^\s*localpkg_gpgcheck\s*=/d' /etc/dnf/dnf.conf
        echo "gpgcheck=1" >> /etc/dnf/dnf.conf
        echo "localpkg_gpgcheck=1" >> /etc/dnf/dnf.conf
    else
        log_append "[TWGCB-01-008-0032][ERROR] /etc/dnf/dnf.conf not found, cannot set global gpgcheck"
    fi
    #修復repo設定
    shopt -s nullglob
    repo_files=(/etc/yum.repos.d/*.repo)
    shopt -u nullglob
    if [ ${#repo_files[@]} -eq 0 ]; then
        set_flag flag_032 0
        log_append "[TWGCB-01-008-0032][ERROR] No .repo files found in /etc/yum.repos.d/, cannot set repo gpgcheck"
    else
        for repo in "${repo_files[@]}"; do
            cp -a "$repo" "$repo.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
            sed -i -E 's/^\s*gpgcheck\s*=.*/gpgcheck=1/' "$repo"
            sed -i -E 's/^\s*localpkg_gpgcheck\s*=.*/localpkg_gpgcheck=1/' "$repo"
            # 若確保每個 [repoid] 區塊都有這些參數
            awk '
            function ensure_defaults() {
                if (!seen["gpgcheck"])          print "gpgcheck=1"
                if (!seen["localpkg_gpgcheck"]) print "localpkg_gpgcheck=1"
            }

            # 遇到新區塊 [repoid]
            /^[[:space:]]*\[/ {
                # 先補齊上一個區塊缺的參數
                if (in_section) ensure_defaults()

                # reset 區塊狀態
                delete seen
                in_section = 1
            }

            # 記錄本區塊是否看過這些 key
            /^[[:space:]]*gpgcheck[[:space:]]*=/          { seen["gpgcheck"] = 1 }
            /^[[:space:]]*localpkg_gpgcheck[[:space:]]*=/ { seen["localpkg_gpgcheck"] = 1 }

            # 原樣輸出每一行
            { print }

            END {
                if (in_section) ensure_defaults()
            }
            ' "$repo" > "${repo}.tmp" && mv -f "${repo}.tmp" "$repo"
        done
    fi
    set_flag flag_032 1
    log_append "[TWGCB-01-008-0032][FIX] enable GPG signature verification"
fi
# ======================================
# TWGCB-01-008-0033
# 需安裝sudo套件
if [ $flag_033 -eq 0 ]; then
    if dnf install -y sudo; then
        set_flag flag_033 1
        log_append "[TWGCB-01-008-0033][FIX] install sudo package"
    else
        set_flag flag_033 0
        log_append "[TWGCB-01-008-0033][ERROR] failed to install sudo package"
    fi
fi
# ======================================
# TWGCB-01-008-0034
# 設定sudo指令使用pty(pseudo terminal，虛擬終端)
if [ $flag_034 -eq 0 ]; then
    echo "Defaults use_pty" > /etc/sudoers.d/99-use-pty
    chmod 440 /etc/sudoers.d/99-use-pty
    visudo -c
    log_append "[TWGCB-01-008-0034][FIX] set sudo to use pseudo terminal (pty)"
    set_flag flag_034 1
fi
# ======================================
# TWGCB-01-008-0035
# sudo自定義日誌檔案須設定為/var/log/sudo.log
if [ $flag_035 -eq 0 ]; then
    echo "Defaults logfile=\"/var/log/sudo.log\"" > /etc/sudoers.d/99-sudo-logfile
    chmod 440 /etc/sudoers.d/99-sudo-logfile
    visudo -c
    log_append "[TWGCB-01-008-0035][FIX] set sudo custom log file to /var/log/sudo.log"
    set_flag flag_035 1
fi
# ======================================
# TWGCB-01-008-0036
# 安裝AIDE(Advanced Intrusion Detection Environment，先進入侵偵測環境)套件
if [ $flag_036 -eq 0 ]; then
    if dnf install -y aide --setopt=timeout=10 --setopt=retries=1 > /tmp/dnf_install.log 2>&1; then
        set_flag flag_036 1
        log_append "[TWGCB-01-008-0036][FIX] install AIDE package"
    else
        set_flag flag_036 0
        log_append "[TWGCB-01-008-0036][ERROR] failed to install AIDE package"
    fi
fi
# ======================================
# TWGCB-01-008-0037
# 定期檢查檔案系統完整性
# 相依TWGCB-01-008-0036
if [ $flag_036 -eq 0 ]; then
    set_flag flag_037 2
    log_append "[TWGCB-01-008-0037][IGNORE] 需要先安裝AIDE套件"
elif [ $flag_036 -eq 1 ] && [ $flag_037 -eq 0 ]; then
    current="$(crontab -l 2>/dev/null || true)"
    (echo "$current"; echo "0 5 * * * /usr/sbin/aide --check > /var/log/aide-check.log 2>&1") | crontab -
    set_flag flag_037 1
    log_append "[TWGCB-01-008-0037][FIX] schedule regular file integrity checks with AIDE"
fi
# ======================================
# TWGCB-01-008-0038
# 開機載入程式設定檔之所有權須為root:root
# TWGCB-01-008-0039
# 開機載入程式設定檔之權限須為600或更嚴格
if [ $flag_038 -eq 0 ] || [ $flag_039 -eq 0 ]; then
    files=(/boot/grub2/grub.cfg /boot/efi/EFI/rocky/grub.cfg /boot/grub2/user.cfg /boot/grub2/grubenv)
    for file in "${files[@]}"; do
        if [ -f "$file" ]; then
            log_append "[TWGCB-01-008-0038]TWGCB[INFO] $file: setting ownership to root:root and permissions to 600"
            chown root:root "$file"
            chmod 600 "$file"
        fi
    done
    set_flag flag_038 1
    set_flag flag_039 1
    log_append "[TWGCB-01-008-0038]TWGCB[FIX] set ownership of boot loader config files to root:root"
    log_append "[TWGCB-01-008-0039][FIX] set permissions of boot loader config files to 600"
fi
# ======================================
# TWGCB-01-008-0040
# 開機載入程式之密碼
if [ $flag_040 -eq 0 ]; then
    set_flag flag_040 2
    log_append "[TWGCB-01-008-0040][IGNORE] 影響後續維運，需要手動設定GRUB密碼，請參考官方文件進行設定"
fi
# ======================================
# TWGCB-01-008-0041
# 單一使用者模式(Single user mode)需啟用身分驗證功能
if [ $flag_041 -eq 0 ]; then
    #移除 override unit files 和 drop-in overrides 以確保不會繞過預設的認證設定
    if [ -f /etc/systemd/system/rescue.service ] || [ -f /etc/systemd/system/emergency.service ]; then
        rm -f /etc/systemd/system/rescue.service 2>/dev/null || true
        rm -f /etc/systemd/system/emergency.service 2>/dev/null || true
        log_append "[TWGCB-01-008-0041][INFO] removed override unit files in /etc/systemd/system/"
    fi
    if [ -d /etc/systemd/system/rescue.service.d ] || [ -d /etc/systemd/system/emergency.service.d ]; then
        rm -rf /etc/systemd/system/rescue.service.d 2>/dev/null || true
        rm -rf /etc/systemd/system/emergency.service.d 2>/dev/null || true
        log_append "[TWGCB-01-008-0041][INFO] removed drop-in overrides in /etc/systemd/system/*.service.d/"
    fi
    #取得狀態退出碼,0表示未被修改,非0表示被修改或不存在
    verify_rescue=0
    verify_emerg=0
    [ -f /usr/lib/systemd/system/rescue.service ] && rpm -Vf /usr/lib/systemd/system/rescue.service >/dev/null 2>&1 || verify_rescue=$?
    [ -f /usr/lib/systemd/system/emergency.service ] && rpm -Vf /usr/lib/systemd/system/emergency.service >/dev/null 2>&1 || verify_emerg=$?
    if [ $verify_rescue -ne 0 ] || [ $verify_emerg -ne 0 ]; then
        if dnf reinstall -y systemd --setopt=timeout=10 --setopt=retries=1 > /tmp/dnf_reinstall.log 2>&1; then
            log_append "[TWGCB-01-008-0041][INFO] reinstalled systemd to restore default rescue and emergency services"
        else
            log_append "[TWGCB-01-008-0041][ERROR] failed to reinstall systemd to restore default rescue and emergency services"
        fi
    else
        log_append "[TWGCB-01-008-0041][INFO] rescue and emergency services are intact, no need to reinstall systemd"
    fi
    systemctl daemon-reload # 重新載入unit cache
    ok=1
    systemctl cat rescue.service 2>/dev/null | grep -q "systemd-sulogin-shell" || ok=0
    systemctl cat emergency.service 2>/dev/null | grep -q "systemd-sulogin-shell" || ok=0
    if [ $ok -eq 1 ]; then
        set_flag flag_041 1
        log_append "[TWGCB-01-008-0041][FIX] ensure rescue and emergency services use systemd-sulogin-shell for authentication"
    else
        set_flag flag_041 0
        log_append "[TWGCB-01-008-0041][ERROR] rescue and emergency services do not use systemd-sulogin-shell for authentication, manual review and fix required"
    fi
fi
# ======================================
# TWGCB-01-008-0042
# 停用核心傾印(Core dump)功能
if [ $flag_042 -eq 0 ]; then
    set_flag flag_042 2
    log_append "[TWGCB-01-008-0042][IGNORE] 影響Sipx服務使用，請評估後手動設定"
fi
# ======================================
# TWGCB-01-008-0043
# 系統開機時是否需啟用記憶體位址空間配置隨機載入(Address space layout randomization, ASLR)功能
if [ $flag_043 -eq 0 ]; then
    echo "kernel.randomize_va_space = 2" > /etc/sysctl.d/99-aslr.conf
    sysctl -w kernel.randomize_va_space=2
    set_flag flag_043 1
    log_append "[TWGCB-01-008-0043][FIX] enable Address Space Layout Randomization (ASLR)"
fi
# ======================================
# TWGCB-01-008-0044
# 設定全系統加密原則為FUTURE或FIPS
if [ $flag_044 -eq 0 ];then
    if [ -f /etc/crypto-policies/config ]; then
        cp -a /etc/crypto-policies/config "/etc/crypto-policies/config.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
        echo "FUTURE" > /etc/crypto-policies/config
        update-crypto-policies --set FUTURE
        update-crypto-policies
        fips-mode-setup --enable
        set_flag flag_044 1
        log_append "[TWGCB-01-008-0044][FIX] set system-wide crypto policy to FUTURE"
    else
        set_flag flag_044 0
        log_append "[TWGCB-01-008-0044][ERROR] /etc/crypto-policies/config not found, cannot set crypto policy"
    fi
fi
# ======================================
# TWGCB-01-008-0045
# /etc/passwd檔案所有權需為root:root
if [ $flag_045 -eq 0 ]; then
    chown root:root /etc/passwd
    log_append "[TWGCB-01-008-0045][FIX] /etc/passwd ownership set to root:root"
    set_flag flag_045 1
fi
# ======================================
# TWGCB-01-008-0046
# /etc/passwd檔案權限需為644或更嚴格
if [ $flag_046 -eq 0 ]; then
    chmod 644 /etc/passwd
    log_append "[TWGCB-01-008-0046][FIX] /etc/passwd permissions set to 644"
    set_flag flag_046 1
fi
# ======================================
# TWGCB-01-008-0047
# /etc/shadow檔案所有權需為root:shadow或是root:root
if [ $flag_047 -eq 0 ]; then
    chown root:root /etc/shadow
    log_append "[TWGCB-01-008-0047][FIX] /etc/shadow ownership set to root:root"
    set_flag flag_047 1
fi
# ======================================
# TWGCB-01-008-0048
# /etc/shadow檔案權限需為000
if [ $flag_048 -eq 0 ]; then
    chmod 000 /etc/shadow
    log_append "[TWGCB-01-008-0048][FIX] /etc/shadow permissions set to 000"
    set_flag flag_048 1
fi
# ======================================
# TWGCB-01-008-0049
# /etc/group檔案所有權需為root:root
if [ $flag_049 -eq 0 ]; then
    chown root:root /etc/group
    log_append "[TWGCB-01-008-0049][FIX] /etc/group ownership set to root:root"
    set_flag flag_049 1
fi
# ======================================
# TWGCB-01-008-0050
# /etc/group檔案權限需為644或更嚴格
if [ $flag_050 -eq 0 ]; then
    chmod 644 /etc/group
    log_append "[TWGCB-01-008-0050][FIX] /etc/group permissions set to 644"
    set_flag flag_050 1
fi
# ======================================
# TWGCB-01-008-0051
# /etc/gshadow檔案所有權需為root:shadow或是root:root
if [ $flag_051 -eq 0 ]; then
    chown root:root /etc/gshadow
    log_append "[TWGCB-01-008-0051][FIX] /etc/gshadow ownership set to root:root"
    set_flag flag_051 1
fi
# ======================================
# TWGCB-01-008-0052
# /etc/gshadow檔案權限需為000
if [ $flag_052 -eq 0 ]; then
    chmod 000 /etc/gshadow
    log_append "[TWGCB-01-008-0052][FIX] /etc/gshadow permissions set to 000"
    set_flag flag_052 1
fi
# ======================================
# TWGCB-01-008-0053
# /etc/passwd-檔案所有權需為root:root
if [ $flag_053 -eq 0 ]; then
    chown root:root /etc/passwd-
    log_append "[TWGCB-01-008-0053][FIX] /etc/passwd- ownership set to root:root"
    set_flag flag_053 1
fi
# ======================================
# TWGCB-01-008-0054
# /etc/passwd-檔案權限需為600或更嚴格
if [ $flag_054 -eq 0 ]; then
    chmod 600 /etc/passwd-
    log_append "[TWGCB-01-008-0054][FIX] /etc/passwd- permissions set to 600"
    set_flag flag_054 1
fi
# ======================================
# TWGCB-01-008-0055
# /etc/shadow-檔案所有權需為root:shadow或是root:root
if [ $flag_055 -eq 0 ]; then
    chown root:root /etc/shadow-
    log_append "[TWGCB-01-008-0055][FIX] /etc/shadow- ownership set to root:root"
    set_flag flag_055 1
fi
# ======================================
# TWGCB-01-008-0056
# /etc/shadow-檔案權限需為000
if [ $flag_056 -eq 0 ]; then
    chmod 000 /etc/shadow-
    log_append "[TWGCB-01-008-0056][FIX] /etc/shadow- permissions set to 000"
    set_flag flag_056 1
fi
# ======================================
# TWGCB-01-008-0057
# /etc/group-檔案所有權需為root:root
if [ $flag_057 -eq 0 ]; then
    chown root:root /etc/group-
    log_append "[TWGCB-01-008-0057][FIX] /etc/group- ownership set to root:root"
    set_flag flag_057 1
fi
# ======================================
# TWGCB-01-008-0058
# /etc/group-檔案權限需為644或更嚴格
if [ $flag_058 -eq 0 ]; then
    chmod 644 /etc/group-
    log_append "[TWGCB-01-008-0058][FIX] /etc/group- permissions set to 644"
    set_flag flag_058 1
fi
# ======================================
# TWGCB-01-008-0059
# /etc/gshadow-檔案所有權需為root:shadow或是root:root
if [ $flag_059 -eq 0 ]; then
    chown root:root /etc/gshadow-
    log_append "[TWGCB-01-008-0059][FIX] /etc/gshadow- ownership set to root:root"
    set_flag flag_059 1
fi
# ======================================
# TWGCB-01-008-0060
# /etc/gshadow-檔案權限需為000
if [ $flag_060 -eq 0 ]; then
    chmod 000 /etc/gshadow-
    log_append "[TWGCB-01-008-0060][FIX] /etc/gshadow- permissions set to 000"
    set_flag flag_060 1
fi
# ======================================
# TWGCB-01-008-0061
# 其他使用者禁止寫入具有全域寫入(World-writable)權限的檔案
if [ $flag_061 -eq 0 ]; then
    # 找出所有具有全域寫入權限的檔案
    files=$(find $(findmnt -rn -o TARGET -t ext4,xfs) -xdev -type f -perm -0002 2>/dev/null)
    for file in $files; do
        if chmod o-w "$file"; then
            log_append "[TWGCB-01-008-0061][FIX] removed world-writable permission from file: $file"
            set_flag flag_061 1
        else
            log_append "[TWGCB-01-008-0061][ERROR] failed to remove world-writable permission from file: $file"
            set_flag flag_061 0
        fi
    done
fi
# ======================================
# TWGCB-01-008-0062
# 檢查所有檔案與目錄擁有者是否皆為合法使用者
if [ $flag_062 -eq 0 ]; then
    if [ -s /tmp/gcb_062_invalid_uid_entries.txt ]; then
        fail=0
        while read -r uid user path; do
            [ -z "$path" ] && continue
            if [ ! -e "$path" ]; then
                log_append "[TWGCB-01-008-0062][ERROR] path not exists, skip: uid=$uid user=$user path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chown root:root "$path"; then
                log_append "[TWGCB-01-008-0062][FIX] changed ownership of $path to root:root from uid=$uid user=$user"
            else
                log_append "[TWGCB-01-008-0062][ERROR] failed to change ownership of $path to root:root (uid=$uid)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_062_invalid_uid_entries.txt
        if [ $fail -eq 0 ]; then
            set_flag flag_062 1
            rm -f /tmp/gcb_062_invalid_uid_entries.txt
            log_append "[TWGCB-01-008-0062][FIX] all invalid UID entries fixed"
        else
            log_append "[TWGCB-01-008-0062][ERROR] some invalid UID entries could not be fixed, please check the log"
            set_flag flag_062 0
        fi
    else
        set_flag flag_062 0
        log_append "[TWGCB-01-008-0062][ERROR] no invalid UID entries file found"
    fi
fi
# ======================================
# TWGCB-01-008-0063
# 檢查所有檔案與目錄擁有者是否皆為合法群組
if [ $flag_063 -eq 0 ]; then
    if [ -s /tmp/gcb_063_invalid_gid_entries.txt ]; then
        fail=0
        while read -r gid group path; do
            [ -z "$path" ] && continue
            if [ ! -e "$path" ]; then
                log_append "[TWGCB-01-008-0063][ERROR] path not exists, skip: gid=$gid group=$group path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chown root:root "$path"; then
                log_append "[TWGCB-01-008-0063][INFO] changed ownership of $path to root:root from gid=$gid group=$group"
            else
                log_append "[TWGCB-01-008-0063][ERROR] failed to change ownership of $path to root:root (gid=$gid)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_063_invalid_gid_entries.txt
        if [ $fail -eq 0 ]; then
            set_flag flag_063 1
            rm -f /tmp/gcb_063_invalid_gid_entries.txt
            log_append "[TWGCB-01-008-0063][FIX] all invalid GID entries fixed"
            set_flag flag_063 1
        else
            log_append "[TWGCB-01-008-0063][ERROR] some invalid GID entries could not be fixed, please check the log"
            set_flag flag_063 0
        fi
    else
        log_append "[TWGCB-01-008-0063][ERROR] no invalid GID entries file found"
        set_flag flag_063 0
    fi
fi
# ======================================
# TWGCB-01-008-0064
# 所有具有全域寫入權限的目錄擁有者需為root或其他系統帳號
if [ $flag_064 -eq 0 ]; then
    if [ -s /tmp/gcb_064_invalid_world_writable_dirs.txt ]; then
        fail=0
        while read -r uid user path; do
            [ -z "$path" ] && continue
            if [ ! -d "$path" ]; then
                log_append "[TWGCB-01-008-0064][ERROR] path not exists, skip: uid=$uid user=$user path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chown root:root "$path"; then
                log_append "[TWGCB-01-008-0064][INFO] changed ownership of $path to root:root from uid=$uid user=$user"
            else
                log_append "[TWGCB-01-008-0064][ERROR] failed to change ownership of $path to root:root (uid=$uid)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_064_invalid_world_writable_dirs.txt
        if [ $fail -eq 0 ]; then
            rm -f /tmp/gcb_064_invalid_world_writable_dirs.txt
            log_append "[TWGCB-01-008-0064][FIX] all invalid world-writable directories fixed"
            set_flag flag_064 1
        else
            log_append "[TWGCB-01-008-0064][ERROR] some invalid world-writable directories could not be fixed, please check the log"
            set_flag flag_064 0
        fi
    else
        log_append "[TWGCB-01-008-0064][ERROR] no invalid world-writable directories file found"
        set_flag flag_064 0
    fi
fi
# ======================================
# TWGCB-01-008-0065
# 所有具有全域寫入權限的目錄擁有群組需為root或其他系統群組
if [ $flag_065 -eq 0 ]; then
    if [ -s /tmp/gcb_065_invalid_world_writable_dirs_groups.txt ]; then
        fail=0
        while read -r gid group path; do
            [ -z "$path" ] && continue
            if [ ! -d "$path" ]; then
                log_append "[TWGCB-01-008-0065][ERROR] path not exists, skip: gid=$gid group=$group path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chown root:root "$path"; then
                log_append "[TWGCB-01-008-0065][INFO] changed ownership of $path to root:root from gid=$gid group=$group"
            else
                log_append "[TWGCB-01-008-0065][ERROR] failed to change ownership of $path to root:root (gid=$gid)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_065_invalid_world_writable_dirs_groups.txt
        if [ $fail -eq 0 ]; then
            rm -f /tmp/gcb_065_invalid_world_writable_dirs_groups.txt
            log_append "[TWGCB-01-008-0065][FIX] all invalid world-writable directories fixed"
            set_flag flag_065 1
        else
            log_append "[TWGCB-01-008-0065][ERROR] some invalid world-writable directories could not be fixed, please check the log"
            set_flag flag_065 0
        fi
    else
        log_append "[TWGCB-01-008-0065][ERROR] no invalid world-writable directories file found"
        set_flag flag_065 0
    fi
fi
# ======================================
# TWGCB-01-008-0066
# 需設定系統命令檔案權限，使系統命令檔案具有755或更低權限
if [ $flag_066 -eq 0 ]; then
    if [ -s /tmp/gcb_066_invalid_command_files.txt ]; then
        fail=0
        while read -r perm path; do
            [ -z "$path" ] && continue
            if [ ! -f "$path" ]; then
                log_append "[TWGCB-01-008-0066][ERROR] path not exists, skip: perm=$perm path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chmod 755 "$path"; then
                log_append "[TWGCB-01-008-0066][INFO] changed permissions of $path to 755 from perm=$perm"
            else
                log_append "[TWGCB-01-008-0066][ERROR] failed to change permissions of $path to 755 (perm=$perm)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_066_invalid_command_files.txt
        if [ $fail -eq 0 ]; then
            rm -f /tmp/gcb_066_invalid_command_files.txt
            log_append "[TWGCB-01-008-0066][FIX] all invalid command files fixed"
            set_flag flag_066 1
        else
            log_append "[TWGCB-01-008-0066][ERROR] some invalid command files could not be fixed, please check the log"
            set_flag flag_066 0
        fi
    else
        log_append "[TWGCB-01-008-0066][ERROR] no invalid command files file found"
        set_flag flag_066 0
    fi
fi
# ======================================
# TWGCB-01-008-0067
# 需設定系統命令檔案權限，使系統命令檔案擁有者為root
# TWGCB-01-008-0068
# 需設定系統命令檔案權限，使系統命令檔案擁有群組為root
if [ $flag_067 -eq 0 ] || [ $flag_068 -eq 0 ]; then
    invalid_command_files=$(
    find -L /bin /sbin /usr/bin /usr/sbin /usr/local/bin /usr/local/sbin \
        -xdev -type f ! \( -user root -a \( -group root -o -group tty -o -group slocate -o -group lock \) \) -printf '%U %u %G %g %p\n' 2>/dev/null \
    | sort -u
    )
    fail=0
    while read -r uid user gid group path; do
        [ -z "$path" ] && continue
        if [ ! -f "$path" ]; then
            log_append "[TWGCB-01-008-0067][ERROR] path not exists, skip: perm=$perm uid=$uid group=$group path=$path"
            log_append "[TWGCB-01-008-0068][ERROR] path not exists, skip: perm=$perm uid=$uid group=$group path=$path"
            continue
        fi
        if chown root:root "$path"; then
            log_append "[TWGCB-01-008-0067][INFO] changed ownership of $path to root:root from uid=$uid group=$group"
            log_append "[TWGCB-01-008-0068][INFO] changed ownership of $path to root:root from uid=$uid group=$group"
        else
            fail=$((fail + 1))
            log_append "[TWGCB-01-008-0067][ERROR] failed to change ownership of $path to root:root (uid=$uid group=$group)"
            log_append "[TWGCB-01-008-0068][ERROR] failed to change ownership of $path to root:root (uid=$uid group=$group)"
        fi
    done <<< "$invalid_command_files"
    if [ $fail -eq 0 ]; then
        log_append "[TWGCB-01-008-0067][FIX] all invalid command files fixed"
        log_append "[TWGCB-01-008-0068][FIX] all invalid command files fixed"
        set_flag flag_067 1
        set_flag flag_068 1
    else
        log_append "[TWGCB-01-008-0067][ERROR] some invalid command files could not be fixed, please check the log"
        log_append "[TWGCB-01-008-0068][ERROR] some invalid command files could not be fixed, please check the log"
        set_flag flag_067 0
        set_flag flag_068 0
    fi
fi
# ======================================
# TWGCB-01-008-0069
# 需設定程式庫檔案權限，使程式庫檔案具有755或更低權限
if [ $flag_069 -eq 0 ]; then
    if [ -s /tmp/gcb_069_invalid_library_files.txt ]; then
        fail=0
        while read -r perm path; do
            [ -z "$path" ] && continue
            if [ ! -f "$path" ]; then
                log_append "[TWGCB-01-008-0069][ERROR] path not exists, skip: perm=$perm path=$path"
                fail=$((fail + 1))
                continue
            fi
            if chmod 755 "$path"; then
                log_append "[TWGCB-01-008-0069][INFO] changed permissions of $path to 755 from perm=$perm"
            else
                log_append "[TWGCB-01-008-0069][ERROR] failed to change permissions of $path to 755 (perm=$perm)"
                fail=$((fail + 1))
            fi
        done < /tmp/gcb_069_invalid_library_files.txt
        if [ $fail -eq 0 ]; then
            rm -f /tmp/gcb_069_invalid_library_files.txt
            log_append "[TWGCB-01-008-0069][FIX] all invalid library files fixed"
            set_flag flag_069 1
        else
            log_append "[TWGCB-01-008-0069][ERROR] some invalid library files could not be fixed, please check the log"
            set_flag flag_069 0
        fi
    else
        log_append "[TWGCB-01-008-0069][ERROR] no invalid library files file found"
        set_flag flag_069 0
    fi
fi
# ======================================
# TWGCB-01-008-0070
# 需設定程式庫檔案權限，使程式庫檔案擁有者為root
# TWGCB-01-008-0071
# 需設定程式庫檔案權限，使程式庫檔案擁有群組為root
if [ $flag_070 -eq 0 ] || [ $flag_071 -eq 0 ]; then
    invalid_library_files=$(
    find -L /lib /lib64 /usr/lib /usr/lib64 \
        -xdev -type f ! \( -user root -a -group root \) -printf '%U %u %G %g %p\n' 2>/dev/null \
    | sort -u
    )
    fail=0
    while read -r uid user gid group path; do
        [ -z "$path" ] && continue
        if [ ! -f "$path" ]; then
            log_append "[TWGCB-01-008-0070][ERROR] path not exists, skip: perm=$perm uid=$uid group=$group path=$path"
            log_append "[TWGCB-01-008-0071][ERROR] path not exists, skip: perm=$perm uid=$uid group=$group path=$path"
            continue
        fi
        if chown root:root "$path"; then
            log_append "[TWGCB-01-008-0070][INFO] changed ownership of $path to root:root from uid=$uid group=$group"
            log_append "[TWGCB-01-008-0071][INFO] changed ownership of $path to root:root from uid=$uid group=$group"
        else
            fail=$((fail + 1))
            log_append "[TWGCB-01-008-0070][ERROR] failed to change ownership of $path to root:root (uid=$uid group=$group)"
            log_append "[TWGCB-01-008-0071][ERROR] failed to change ownership of $path to root:root (uid=$uid group=$group)"
        fi
    done <<< "$invalid_library_files"
    if [ $fail -eq 0 ]; then
        log_append "[TWGCB-01-008-0070][FIX] all invalid library files fixed"
        log_append "[TWGCB-01-008-0071][FIX] all invalid library files fixed"
        set_flag flag_070 1
        set_flag flag_071 1
    else
        log_append "[TWGCB-01-008-0070][ERROR] some invalid library files could not be fixed, please check the log"
        log_append "[TWGCB-01-008-0071][ERROR] some invalid library files could not be fixed, please check the log"
        set_flag flag_070 0
        set_flag flag_071 0
    fi
fi
# ======================================
# TWGCB-01-008-0072
# 帳號不使用空白密碼
if [ $flag_072 -eq 0 ]; then
    fail=0
    empty_password_users=$(awk -F: '($2 == "") {print $1}' /etc/shadow)
    for user in $empty_password_users; do
        if passwd -l "$user"; then
            log_append "[TWGCB-01-008-0072][FIX] locked account with empty password: $user"
        else
            log_append "[TWGCB-01-008-0072][ERROR] failed to lock account: $user"
            fail=$((fail + 1))
        fi
    done
    if [ $fail -eq 0 ]; then
        set_flag flag_072 1
    else
        set_flag flag_072 0
    fi
fi
# ======================================
# TWGCB-01-008-0073
# root帳號的路徑變數不包含「.」「..」路徑開頭不是「/」及空元素
if [ $flag_073 -eq 0 ]; then
    profile_file="/etc/profile.d/99-gcb-root-path.sh"
    cat > "$profile_file" << 'EOF'
# GCB TWGCB-01-008-0073: ensure root PATH contains only absolute paths
if [ "$(id -u)" -eq 0 ]; then
    export PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin
fi
EOF
    chmod 644 "$profile_file"
    set_flag flag_073 1
    log_append "[TWGCB-01-008-0073][FIX] set secure PATH for root in $profile_file"
fi
# ======================================
# TWGCB-01-008-0074
# root帳號的路徑變數不包含world-writable或group-writable目錄
if [ $flag_074 -eq 0 ]; then
    fail=0
    IFS=':' read -ra PATH_DIRS <<< "$PATH"
    for dir in "${PATH_DIRS[@]}"; do
        [ -z "$dir" ] && continue
        if [ -d "$dir" ]; then
            perms=$(stat -c "%a" "$dir")
            if [ $(( 8#${perms: -3} & 8#020 )) -ne 0 ]; then
                if chmod g-w "$dir"; then
                    log_append "[TWGCB-01-008-0074][FIX] removed group-write permission from PATH directory: $dir"
                else
                    log_append "[TWGCB-01-008-0074][ERROR] failed to remove group-write from: $dir"
                    fail=$((fail + 1))
                fi
            fi
            if [ $(( 8#${perms: -3} & 8#002 )) -ne 0 ]; then
                if chmod o-w "$dir"; then
                    log_append "[TWGCB-01-008-0074][FIX] removed world-write permission from PATH directory: $dir"
                else
                    log_append "[TWGCB-01-008-0074][ERROR] failed to remove world-write from: $dir"
                    fail=$((fail + 1))
                fi
            fi
        fi
    done
    if [ $fail -eq 0 ]; then
        set_flag flag_074 1
    else
        set_flag flag_074 0
    fi
fi
# ======================================
# TWGCB-01-008-0075
# /etc/passwd檔案行首的「+」符號需禁止
if [ $flag_075 -eq 0 ]; then
    cp -a /etc/passwd "/etc/passwd.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
    if sed -i '/^\+:/d' /etc/passwd; then
        set_flag flag_075 1
        log_append "[TWGCB-01-008-0075][FIX] removed '+' entries from /etc/passwd"
    else
        set_flag flag_075 0
        log_append "[TWGCB-01-008-0075][ERROR] failed to remove '+' entries from /etc/passwd"
    fi
fi
# ======================================
# TWGCB-01-008-0076
# /etc/shadow檔案行首的「+」符號需禁止
if [ $flag_076 -eq 0 ]; then
    cp -a /etc/shadow "/etc/shadow.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
    if sed -i '/^\+:/d' /etc/shadow; then
        set_flag flag_076 1
        log_append "[TWGCB-01-008-0076][FIX] removed '+' entries from /etc/shadow"
    else
        set_flag flag_076 0
        log_append "[TWGCB-01-008-0076][ERROR] failed to remove '+' entries from /etc/shadow"
    fi
fi
# ======================================
# TWGCB-01-008-0077
# /etc/group檔案行首的「+」符號需禁止
if [ $flag_077 -eq 0 ]; then
    cp -a /etc/group "/etc/group.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
    if sed -i '/^\+:/d' /etc/group; then
        set_flag flag_077 1
        log_append "[TWGCB-01-008-0077][FIX] removed '+' entries from /etc/group"
    else
        set_flag flag_077 0
        log_append "[TWGCB-01-008-0077][ERROR] failed to remove '+' entries from /etc/group"
    fi
fi
# ======================================
# TWGCB-01-008-0078
# 僅root帳號之UID為0
if [ $flag_078 -eq 0 ]; then
    fail=0
    uid0_accounts=$(awk -F: '($3 == 0) { print $1 }' /etc/passwd | grep -v '^root$')
    for account in $uid0_accounts; do
        # 找下一個可用 UID（>= 1000）
        new_uid=$(awk -F: '{print $3}' /etc/passwd | sort -n | awk 'BEGIN{uid=1000} $1>=uid{uid=$1+1} END{print uid}')
        if usermod -u "$new_uid" "$account"; then
            log_append "[TWGCB-01-008-0078][FIX] changed UID of $account from 0 to $new_uid (files under home dir may need re-owning)"
        else
            log_append "[TWGCB-01-008-0078][ERROR] failed to change UID of $account"
            fail=$((fail + 1))
        fi
    done
    if [ $fail -eq 0 ]; then
        set_flag flag_078 1
    else
        set_flag flag_078 0
    fi
fi
# ======================================
# TWGCB-01-008-0079
# 使用者家目錄權限須為700或更低權限
if [ $flag_079 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        perm=$(stat -c "%a" "$home")
        if [ $(( 8#${perm: -3} & 8#077 )) -ne 0 ]; then
            if chmod 700 "$home"; then
                log_append "[TWGCB-01-008-0079][FIX] changed permissions of $home (user: $username) from $perm to 700"
            else
                log_append "[TWGCB-01-008-0079][ERROR] failed to change permissions of $home (user: $username)"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_079 1
    else
        set_flag flag_079 0
    fi
fi
# ======================================
# TWGCB-01-008-0080
# 使用者家目錄擁有者須為該使用者
if [ $flag_080 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        owner=$(stat -L -c "%U" "$home")
        if [ "$owner" != "$username" ]; then
            if chown "$username" "$home"; then
                log_append "[TWGCB-01-008-0080][FIX] changed owner of $home from $owner to $username"
            else
                log_append "[TWGCB-01-008-0080][ERROR] failed to change owner of $home to $username"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_080 1
    else
        set_flag flag_080 0
    fi
fi

# ======================================
# TWGCB-01-008-0081
# 使用者家目錄擁有群組須為該使用者之群組
if [ $flag_081 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ uid gid _ home shell; do
        if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        owner_gid=$(stat -L -c "%g" "$home")
        if [ "$owner_gid" != "$gid" ]; then
            if chgrp "$gid" "$home"; then
                log_append "[TWGCB-01-008-0081][FIX] changed group of $home from GID $owner_gid to GID $gid (user: $username)"
            else
                log_append "[TWGCB-01-008-0081][ERROR] failed to change group of $home to GID $gid (user: $username)"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_081 1
    else
        set_flag flag_081 0
    fi
fi
# ======================================
# TWGCB-01-008-0082
# 使用者家目錄的「.」開頭檔案權限須為go-w或更低權限
if [ $flag_082 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
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
            need_fix=0
            if [ "$(echo "$fileperm" | cut -c6)" != "-" ]; then
                need_fix=1
            fi
            if [ "$(echo "$fileperm" | cut -c9)" != "-" ]; then
                need_fix=1
            fi
            if [ $need_fix -eq 1 ]; then
                if chmod go-w "$dotfile"; then
                    log_append "[TWGCB-01-008-0082][FIX] removed group/other write permission from $dotfile (user: $username)"
                else
                    log_append "[TWGCB-01-008-0082][ERROR] failed to chmod $dotfile (user: $username)"
                    fail=$((fail + 1))
                fi
            fi
        done
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_082 1
    else
        set_flag flag_082 0
    fi
fi
# ======================================
# TWGCB-01-008-0083
# 使用者家目錄的「.forward」檔案須移除
if [ $flag_083 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        if [ ! -h "$home/.forward" ] && [ -f "$home/.forward" ]; then
            if rm -f "$home/.forward"; then
                log_append "[TWGCB-01-008-0083][FIX] removed .forward file: $home/.forward (user: $username)"
            else
                log_append "[TWGCB-01-008-0083][ERROR] failed to remove $home/.forward (user: $username)"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_083 1
    else
        set_flag flag_083 0
    fi
fi
# ======================================
# TWGCB-01-008-0084
# 使用者家目錄的「.netrc」檔案須移除
if [ $flag_084 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        if [ ! -h "$home/.netrc" ] && [ -f "$home/.netrc" ]; then
            if rm -f "$home/.netrc"; then
                log_append "[TWGCB-01-008-0084][FIX] removed .netrc file: $home/.netrc (user: $username)"
            else
                log_append "[TWGCB-01-008-0084][ERROR] failed to remove $home/.netrc (user: $username)"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_084 1
    else
        set_flag flag_084 0
    fi
fi
# ======================================
# TWGCB-01-008-0085
# 使用者家目錄的「.rhosts」檔案須移除
if [ $flag_085 -eq 0 ]; then
    fail=0
    while IFS=: read -r username _ _ _ _ home shell; do
        if [ "$username" = "root" ] || [ "$username" = "halt" ] || [ "$username" = "sync" ] || [ "$username" = "shutdown" ]; then
            continue
        fi
        if [ "$shell" = "/sbin/nologin" ] || [ "$shell" = "/bin/false" ]; then
            continue
        fi
        if [ -z "$home" ] || [ "$home" = "/" ]; then
            continue
        fi
        if [ ! -d "$home" ]; then
            continue
        fi
        if [ ! -h "$home/.rhosts" ] && [ -f "$home/.rhosts" ]; then
            if rm -f "$home/.rhosts"; then
                log_append "[TWGCB-01-008-0085][FIX] removed .rhosts file: $home/.rhosts (user: $username)"
            else
                log_append "[TWGCB-01-008-0085][ERROR] failed to remove $home/.rhosts (user: $username)"
                fail=$((fail + 1))
            fi
        fi
    done < /etc/passwd
    if [ $fail -eq 0 ]; then
        set_flag flag_085 1
    else
        set_flag flag_085 0
    fi
fi
# ======================================
# TWGCB-01-008-0086
# /etc/passwd檔案中帳號的群組皆須存在於/etc/group檔案中
if [ $flag_086 -eq 0 ]; then
    fail=0
    while IFS= read -r gid; do
        if ! grep -q -P "^[^:]*:[^:]*:${gid}:" /etc/group; then
            grp_name="gcb_group_${gid}"
            if groupadd -g "$gid" "$grp_name" 2>/dev/null; then
                log_append "[TWGCB-01-008-0086][FIX] created group $grp_name with GID $gid (referenced in /etc/passwd but missing from /etc/group)"
            else
                log_append "[TWGCB-01-008-0086][ERROR] failed to create group for GID $gid - please manually run: groupadd -g $gid <groupname>"
                fail=$((fail + 1))
            fi
        fi
    done < <(cut -s -d: -f4 /etc/passwd | sort -u)
    if [ $fail -eq 0 ]; then
        set_flag flag_086 1
    else
        set_flag flag_086 0
    fi
fi
# ======================================
# TWGCB-01-008-0087
# 使用者帳號之UID須為唯一值
if [ $flag_087 -eq 0 ]; then
    fail=0
    while read -r count uid; do
        if [ "$count" -gt 1 ]; then
            # 保留第一個帳號，對其餘帳號重新分配 UID
            first=1
            while IFS=: read -r uname _ u_uid _; do
                if [ "$u_uid" = "$uid" ]; then
                    if [ $first -eq 1 ]; then
                        first=0
                        continue
                    fi
                    new_uid=$(awk -F: '{print $3}' /etc/passwd | sort -n | awk 'BEGIN{u=1000} $1>=u{u=$1+1} END{print u}')
                    if usermod -u "$new_uid" "$uname"; then
                        log_append "[TWGCB-01-008-0087][FIX] changed UID of $uname from $uid to $new_uid (duplicate UID resolved)"
                    else
                        log_append "[TWGCB-01-008-0087][ERROR] failed to change UID of $uname"
                        fail=$((fail + 1))
                    fi
                fi
            done < /etc/passwd
        fi
    done < <(cut -f3 -d: /etc/passwd | sort -n | uniq -c)
    if [ $fail -eq 0 ]; then
        set_flag flag_087 1
    else
        set_flag flag_087 0
    fi
fi
# ======================================
# TWGCB-01-008-0088
# 群組之GID須為唯一值
if [ $flag_088 -eq 0 ]; then
    fail=0
    while IFS= read -r gid; do
        # 保留第一個群組，對其餘群組重新分配 GID
        first=1
        while IFS=: read -r grp_name _ g_gid _; do
            if [ "$g_gid" = "$gid" ]; then
                if [ $first -eq 1 ]; then
                    first=0
                    continue
                fi
                new_gid=$(cut -d: -f3 /etc/group | sort -n | awk 'BEGIN{g=1000} $1>=g{g=$1+1} END{print g}')
                if groupmod -g "$new_gid" "$grp_name"; then
                    log_append "[TWGCB-01-008-0088][FIX] changed GID of group $grp_name from $gid to $new_gid (duplicate GID resolved)"
                else
                    log_append "[TWGCB-01-008-0088][ERROR] failed to change GID of group $grp_name"
                    fail=$((fail + 1))
                fi
            fi
        done < /etc/group
    done < <(cut -d: -f3 /etc/group | sort | uniq -d)
    if [ $fail -eq 0 ]; then
        set_flag flag_088 1
    else
        set_flag flag_088 0
    fi
fi
# ======================================
# TWGCB-01-008-0089
# 使用者帳號名稱須為唯一值
if [ $flag_089 -eq 0 ]; then
    # 帳號名稱重複須人工處理，記錄後標記錯誤
    while IFS= read -r uname; do
        log_append "[TWGCB-01-008-0089][ERROR] Duplicate username ($uname) requires manual intervention: edit /etc/passwd to assign unique names"
    done < <(cut -d: -f1 /etc/passwd | sort | uniq -d)
    set_flag flag_089 0
fi
# ======================================
# TWGCB-01-008-0090
# 群組名稱須為唯一值
if [ $flag_090 -eq 0 ]; then
    # 群組名稱重複須人工處理，記錄後標記錯誤
    while IFS= read -r gname; do
        log_append "[TWGCB-01-008-0090][ERROR] Duplicate group name ($gname) requires manual intervention: edit /etc/group to assign unique names"
    done < <(cut -d: -f1 /etc/group | sort | uniq -d)
    set_flag flag_090 0
fi

# ======================================
# TWGCB-01-008-0091
# shadow群組成員須為空
if [ $flag_091 -eq 0 ]; then
    cp -a /etc/group "/etc/group.bak.$(date +%F_%H%M%S)" 2>/dev/null || true
    if sed -ri 's/(^shadow:[^:]*:[^:]*:)([^:]+$)/\1/' /etc/group; then
        set_flag flag_091 1
        log_append "[TWGCB-01-008-0091][FIX] removed all members from shadow group in /etc/group"
    else
        set_flag flag_091 0
        log_append "[TWGCB-01-008-0091][ERROR] failed to remove members from shadow group"
    fi
fi
# ======================================
# TWGCB-01-008-0092
# xinetd套件須移除
if [ $flag_092 -eq 0 ]; then
    if dnf remove -y xinetd; then
        set_flag flag_092 1
        log_append "[TWGCB-01-008-0092][FIX] removed xinetd package"
    else
        set_flag flag_092 0
        log_append "[TWGCB-01-008-0092][ERROR] failed to remove xinetd package"
    fi
fi
# ======================================
# TWGCB-01-008-0093
# chrony須設定1個以上時間同步來源
if [ $flag_093 -eq 0 ]; then
    if [ -f /etc/chrony.conf ]; then
        echo "pool 2.rhel.pool.ntp.org iburst" >> /etc/chrony.conf
        set_flag flag_093 1
        log_append "[TWGCB-01-008-0093][FIX] added default NTP pool (pool 2.rhel.pool.ntp.org iburst) to /etc/chrony.conf - please update to your organization's NTP server"
        systemctl restart chronyd 2>/dev/null || true
    else
        set_flag flag_093 0
        log_append "[TWGCB-01-008-0093][ERROR] /etc/chrony.conf not found; install chrony and configure NTP server manually"
    fi
fi
# ======================================
# TWGCB-01-008-0094
# rsyncd服務須停用
if [ $flag_094 -eq 0 ]; then
    if systemctl --now mask rsyncd; then
        set_flag flag_094 1
        log_append "[TWGCB-01-008-0094][FIX] masked rsyncd service"
    else
        set_flag flag_094 0
        log_append "[TWGCB-01-008-0094][ERROR] failed to mask rsyncd service"
    fi
fi
# ======================================
# TWGCB-01-008-0095
# avahi-daemon服務及socket須停用
if [ $flag_095 -eq 0 ]; then
    fail=0
    if systemctl --now mask avahi-daemon.service 2>/dev/null; then
        log_append "[TWGCB-01-008-0095][FIX] masked avahi-daemon.service"
    else
        log_append "[TWGCB-01-008-0095][INFO] avahi-daemon.service not found or already masked"
    fi
    if systemctl --now mask avahi-daemon.socket 2>/dev/null; then
        log_append "[TWGCB-01-008-0095][FIX] masked avahi-daemon.socket"
    else
        log_append "[TWGCB-01-008-0095][INFO] avahi-daemon.socket not found or already masked"
    fi
    set_flag flag_095 1
fi
# ======================================
# TWGCB-01-008-0096
# SNMP服務須停用
if [ $flag_096 -eq 0 ]; then
    if systemctl --now mask snmpd; then
        set_flag flag_096 1
        log_append "[TWGCB-01-008-0096][FIX] masked snmpd service"
    else
        set_flag flag_096 0
        log_append "[TWGCB-01-008-0096][ERROR] failed to mask snmpd service"
    fi
fi
# ======================================
# TWGCB-01-008-0097
# Squid服務須停用
if [ $flag_097 -eq 0 ]; then
    if systemctl --now mask squid; then
        set_flag flag_097 1
        log_append "[TWGCB-01-008-0097][FIX] masked squid service"
    else
        set_flag flag_097 0
        log_append "[TWGCB-01-008-0097][ERROR] failed to mask squid service"
    fi
fi
# ======================================
# TWGCB-01-008-0098
# Samba服務須停用
if [ $flag_098 -eq 0 ]; then
    if systemctl --now mask smb; then
        set_flag flag_098 1
        log_append "[TWGCB-01-008-0098][FIX] masked smb (Samba) service"
    else
        set_flag flag_098 0
        log_append "[TWGCB-01-008-0098][ERROR] failed to mask smb service"
    fi
fi
# ======================================
# TWGCB-01-008-0099
# FTP伺服器服務須停用
if [ $flag_099 -eq 0 ]; then
    if systemctl --now mask vsftpd; then
        set_flag flag_099 1
        log_append "[TWGCB-01-008-0099][FIX] masked vsftpd (FTP server) service"
    else
        set_flag flag_099 0
        log_append "[TWGCB-01-008-0099][ERROR] failed to mask vsftpd service"
    fi
fi
# ======================================
# TWGCB-01-008-0100
# NIS伺服器服務須停用
if [ $flag_100 -eq 0 ]; then
    if systemctl --now mask ypserv; then
        set_flag flag_100 1
        log_append "[TWGCB-01-008-0100][FIX] masked ypserv (NIS server) service"
    else
        set_flag flag_100 0
        log_append "[TWGCB-01-008-0100][ERROR] failed to mask ypserv service"
    fi
fi

# ======================================
# TWGCB-01-008-0101
# kdump服務須啟用
if [ $flag_101 -eq 0 ]; then
    if systemctl --now enable kdump.service; then
        set_flag flag_101 1
        log_append "[TWGCB-01-008-0101][FIX] enabled kdump.service"
    else
        set_flag flag_101 0
        log_append "[TWGCB-01-008-0101][ERROR] failed to enable kdump.service"
    fi
fi
# ======================================
# TWGCB-01-008-0102
# NIS用戶端套件(ypbind)須移除
if [ $flag_102 -eq 0 ]; then
    if dnf remove -y ypbind; then
        set_flag flag_102 1
        log_append "[TWGCB-01-008-0102][FIX] removed ypbind (NIS client) package"
    else
        set_flag flag_102 0
        log_append "[TWGCB-01-008-0102][ERROR] failed to remove ypbind package"
    fi
fi
# ======================================
# TWGCB-01-008-0103
# telnet用戶端套件須移除
if [ $flag_103 -eq 0 ]; then
    if dnf remove -y telnet; then
        set_flag flag_103 1
        log_append "[TWGCB-01-008-0103][FIX] removed telnet client package"
    else
        set_flag flag_103 0
        log_append "[TWGCB-01-008-0103][ERROR] failed to remove telnet package"
    fi
fi
# ======================================
# TWGCB-01-008-0104
# telnet伺服器套件須移除
if [ $flag_104 -eq 0 ]; then
    if dnf remove -y telnet-server; then
        set_flag flag_104 1
        log_append "[TWGCB-01-008-0104][FIX] removed telnet-server package"
    else
        set_flag flag_104 0
        log_append "[TWGCB-01-008-0104][ERROR] failed to remove telnet-server package"
    fi
fi
# ======================================
# TWGCB-01-008-0105
# rsh伺服器套件須移除
if [ $flag_105 -eq 0 ]; then
    if dnf remove -y rsh-server; then
        set_flag flag_105 1
        log_append "[TWGCB-01-008-0105][FIX] removed rsh-server package"
    else
        set_flag flag_105 0
        log_append "[TWGCB-01-008-0105][ERROR] failed to remove rsh-server package"
    fi
fi
# ======================================
# TWGCB-01-008-0106
# tftp伺服器套件須移除
if [ $flag_106 -eq 0 ]; then
    if dnf remove -y tftp-server; then
        set_flag flag_106 1
        log_append "[TWGCB-01-008-0106][FIX] removed tftp-server package"
    else
        set_flag flag_106 0
        log_append "[TWGCB-01-008-0106][ERROR] failed to remove tftp-server package"
    fi
fi
# ======================================
# TWGCB-01-008-0107
# 更新套件後須移除舊版本元件 (clean_requirements_on_remove=True)
if [ $flag_107 -eq 0 ]; then
    fail=0
    for conf in /etc/yum.conf /etc/dnf/dnf.conf; do
        [ ! -f "$conf" ] && continue
        if grep -qiE '^\s*clean_requirements_on_remove\s*=' "$conf"; then
            sed -i 's/^\s*clean_requirements_on_remove\s*=.*/clean_requirements_on_remove=True/' "$conf"
        else
            echo "clean_requirements_on_remove=True" >> "$conf"
        fi
        if grep -qiE '^\s*clean_requirements_on_remove\s*=\s*[Tt]rue' "$conf"; then
            log_append "[TWGCB-01-008-0107][FIX] set clean_requirements_on_remove=True in $conf"
        else
            log_append "[TWGCB-01-008-0107][ERROR] failed to set clean_requirements_on_remove in $conf"
            fail=$((fail + 1))
        fi
    done
    if [ $fail -eq 0 ]; then
        set_flag flag_107 1
    else
        set_flag flag_107 0
    fi
fi
# ======================================
# TWGCB-01-008-0108
# IP轉送須停用 (net.ipv4.ip_forward=0, net.ipv6.conf.all.forwarding=0)
if [ $flag_108 -eq 0 ]; then
    fail=0
    # IPv4: 移除衝突設定並寫入持久化設定
    grep -ElsZ '^\s*net\.ipv4\.ip_forward\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.ip_forward\s*=.*$/# removed by GCB fix 0108/'
    printf "\nnet.ipv4.ip_forward = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    sysctl -w net.ipv4.ip_forward=0 && sysctl -w net.ipv4.route.flush=1 || fail=$((fail + 1))
    log_append "[TWGCB-01-008-0108][FIX] set net.ipv4.ip_forward=0"
    # IPv6
    grep -ElsZ '^\s*net\.ipv6\.conf\.all\.forwarding\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv6\.conf\.all\.forwarding\s*=.*$/# removed by GCB fix 0108/'
    printf "\nnet.ipv6.conf.all.forwarding = 0\n" >> /etc/sysctl.d/60-gcb-netipv6.conf
    sysctl -w net.ipv6.conf.all.forwarding=0 && sysctl -w net.ipv6.route.flush=1 2>/dev/null || true
    log_append "[TWGCB-01-008-0108][FIX] set net.ipv6.conf.all.forwarding=0"
    if [ $fail -eq 0 ]; then
        set_flag flag_108 1
    else
        set_flag flag_108 0
    fi
fi
# ======================================
# TWGCB-01-008-0109
# 所有網路介面傳送ICMP重新導向封包須停用 (net.ipv4.conf.all.send_redirects=0)
if [ $flag_109 -eq 0 ]; then
    fail=0
    grep -ElsZ '^\s*net\.ipv4\.conf\.all\.send_redirects\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.all\.send_redirects\s*=.*$/# removed by GCB fix 0109/'
    printf "\nnet.ipv4.conf.all.send_redirects = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.all.send_redirects=0 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_109 1
        log_append "[TWGCB-01-008-0109][FIX] set net.ipv4.conf.all.send_redirects=0"
    else
        set_flag flag_109 0
        log_append "[TWGCB-01-008-0109][ERROR] failed to apply net.ipv4.conf.all.send_redirects=0"
    fi
fi
# ======================================
# TWGCB-01-008-0110
# 預設網路介面傳送ICMP重新導向封包須停用 (net.ipv4.conf.default.send_redirects=0)
if [ $flag_110 -eq 0 ]; then
    fail=0
    grep -ElsZ '^\s*net\.ipv4\.conf\.default\.send_redirects\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.default\.send_redirects\s*=.*$/# removed by GCB fix 0110/'
    printf "\nnet.ipv4.conf.default.send_redirects = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.default.send_redirects=0 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_110 1
        log_append "[TWGCB-01-008-0110][FIX] set net.ipv4.conf.default.send_redirects=0"
    else
        set_flag flag_110 0
        log_append "[TWGCB-01-008-0110][ERROR] failed to apply net.ipv4.conf.default.send_redirects=0"
    fi
fi

# ======================================
# TWGCB-01-008-0111
# 所有網路介面不接受來源路由封包 (net.ipv4/ipv6.conf.all.accept_source_route=0)
if [ $flag_111 -eq 0 ]; then
    fail=0
    for key in net.ipv4.conf.all.accept_source_route net.ipv6.conf.all.accept_source_route; do
        kesc=$(echo "$key" | sed 's/\./\\./g')
        grep -ElsZ "^\s*${kesc}\s*=" /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
            xargs -0 -r sed -i "s/^\s*${kesc}\s*=.*$/# removed by GCB fix 0111/"
        printf "\n${key} = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
        sysctl -w ${key}=0 || fail=$((fail + 1))
    done
    sysctl -w net.ipv4.route.flush=1; sysctl -w net.ipv6.route.flush=1 2>/dev/null || true
    log_append "[TWGCB-01-008-0111][FIX] set accept_source_route=0 for all interfaces"
    if [ $fail -eq 0 ]; then set_flag flag_111 1; else set_flag flag_111 0; fi
fi
# ======================================
# TWGCB-01-008-0112
# 預設網路介面不接受來源路由封包 (net.ipv4/ipv6.conf.default.accept_source_route=0)
if [ $flag_112 -eq 0 ]; then
    fail=0
    for key in net.ipv4.conf.default.accept_source_route net.ipv6.conf.default.accept_source_route; do
        kesc=$(echo "$key" | sed 's/\./\\./g')
        grep -ElsZ "^\s*${kesc}\s*=" /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
            xargs -0 -r sed -i "s/^\s*${kesc}\s*=.*$/# removed by GCB fix 0112/"
        printf "\n${key} = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
        sysctl -w ${key}=0 || fail=$((fail + 1))
    done
    sysctl -w net.ipv4.route.flush=1; sysctl -w net.ipv6.route.flush=1 2>/dev/null || true
    log_append "[TWGCB-01-008-0112][FIX] set accept_source_route=0 for default interfaces"
    if [ $fail -eq 0 ]; then set_flag flag_112 1; else set_flag flag_112 0; fi
fi
# ======================================
# TWGCB-01-008-0113
# 所有網路介面不接受ICMP重新導向封包 (net.ipv4/ipv6.conf.all.accept_redirects=0)
if [ $flag_113 -eq 0 ]; then
    fail=0
    for key in net.ipv4.conf.all.accept_redirects net.ipv6.conf.all.accept_redirects; do
        kesc=$(echo "$key" | sed 's/\./\\./g')
        grep -ElsZ "^\s*${kesc}\s*=" /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
            xargs -0 -r sed -i "s/^\s*${kesc}\s*=.*$/# removed by GCB fix 0113/"
        printf "\n${key} = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
        sysctl -w ${key}=0 || fail=$((fail + 1))
    done
    sysctl -w net.ipv4.route.flush=1; sysctl -w net.ipv6.route.flush=1 2>/dev/null || true
    log_append "[TWGCB-01-008-0113][FIX] set accept_redirects=0 for all interfaces"
    if [ $fail -eq 0 ]; then set_flag flag_113 1; else set_flag flag_113 0; fi
fi
# ======================================
# TWGCB-01-008-0114
# 預設網路介面不接受ICMP重新導向封包 (net.ipv4/ipv6.conf.default.accept_redirects=0)
if [ $flag_114 -eq 0 ]; then
    fail=0
    for key in net.ipv4.conf.default.accept_redirects net.ipv6.conf.default.accept_redirects; do
        kesc=$(echo "$key" | sed 's/\./\\./g')
        grep -ElsZ "^\s*${kesc}\s*=" /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
            xargs -0 -r sed -i "s/^\s*${kesc}\s*=.*$/# removed by GCB fix 0114/"
        printf "\n${key} = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
        sysctl -w ${key}=0 || fail=$((fail + 1))
    done
    sysctl -w net.ipv4.route.flush=1; sysctl -w net.ipv6.route.flush=1 2>/dev/null || true
    log_append "[TWGCB-01-008-0114][FIX] set accept_redirects=0 for default interfaces"
    if [ $fail -eq 0 ]; then set_flag flag_114 1; else set_flag flag_114 0; fi
fi
# ======================================
# TWGCB-01-008-0115
# 所有網路介面不接受安全ICMP重新導向封包 (net.ipv4.conf.all.secure_redirects=0)
if [ $flag_115 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.all\.secure_redirects\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.all\.secure_redirects\s*=.*$/# removed by GCB fix 0115/'
    printf "\nnet.ipv4.conf.all.secure_redirects = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.all.secure_redirects=0 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_115 1
        log_append "[TWGCB-01-008-0115][FIX] set net.ipv4.conf.all.secure_redirects=0"
    else
        set_flag flag_115 0
        log_append "[TWGCB-01-008-0115][ERROR] failed to apply net.ipv4.conf.all.secure_redirects=0"
    fi
fi
# ======================================
# TWGCB-01-008-0116
# 預設網路介面不接受安全ICMP重新導向封包 (net.ipv4.conf.default.secure_redirects=0)
if [ $flag_116 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.default\.secure_redirects\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.default\.secure_redirects\s*=.*$/# removed by GCB fix 0116/'
    printf "\nnet.ipv4.conf.default.secure_redirects = 0\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.default.secure_redirects=0 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_116 1
        log_append "[TWGCB-01-008-0116][FIX] set net.ipv4.conf.default.secure_redirects=0"
    else
        set_flag flag_116 0
        log_append "[TWGCB-01-008-0116][ERROR] failed to apply net.ipv4.conf.default.secure_redirects=0"
    fi
fi
# ======================================
# TWGCB-01-008-0117
# 所有網路介面須記錄可疑封包 (net.ipv4.conf.all.log_martians=1)
if [ $flag_117 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.all\.log_martians\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.all\.log_martians\s*=.*$/# removed by GCB fix 0117/'
    printf "\nnet.ipv4.conf.all.log_martians = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.all.log_martians=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_117 1
        log_append "[TWGCB-01-008-0117][FIX] set net.ipv4.conf.all.log_martians=1"
    else
        set_flag flag_117 0
        log_append "[TWGCB-01-008-0117][ERROR] failed to apply net.ipv4.conf.all.log_martians=1"
    fi
fi
# ======================================
# TWGCB-01-008-0118
# 預設網路介面須記錄可疑封包 (net.ipv4.conf.default.log_martians=1)
if [ $flag_118 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.default\.log_martians\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.default\.log_martians\s*=.*$/# removed by GCB fix 0118/'
    printf "\nnet.ipv4.conf.default.log_martians = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.default.log_martians=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_118 1
        log_append "[TWGCB-01-008-0118][FIX] set net.ipv4.conf.default.log_martians=1"
    else
        set_flag flag_118 0
        log_append "[TWGCB-01-008-0118][ERROR] failed to apply net.ipv4.conf.default.log_martians=1"
    fi
fi
# ======================================
# TWGCB-01-008-0119
# 不回應ICMP廣播要求 (net.ipv4.icmp_echo_ignore_broadcasts=1)
if [ $flag_119 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.icmp_echo_ignore_broadcasts\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.icmp_echo_ignore_broadcasts\s*=.*$/# removed by GCB fix 0119/'
    printf "\nnet.ipv4.icmp_echo_ignore_broadcasts = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.icmp_echo_ignore_broadcasts=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_119 1
        log_append "[TWGCB-01-008-0119][FIX] set net.ipv4.icmp_echo_ignore_broadcasts=1"
    else
        set_flag flag_119 0
        log_append "[TWGCB-01-008-0119][ERROR] failed to apply net.ipv4.icmp_echo_ignore_broadcasts=1"
    fi
fi
# ======================================
# TWGCB-01-008-0120
# 忽略偽造之ICMP錯誤訊息 (net.ipv4.icmp_ignore_bogus_error_responses=1)
if [ $flag_120 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.icmp_ignore_bogus_error_responses\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.icmp_ignore_bogus_error_responses\s*=.*$/# removed by GCB fix 0120/'
    printf "\nnet.ipv4.icmp_ignore_bogus_error_responses = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.icmp_ignore_bogus_error_responses=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_120 1
        log_append "[TWGCB-01-008-0120][FIX] set net.ipv4.icmp_ignore_bogus_error_responses=1"
    else
        set_flag flag_120 0
        log_append "[TWGCB-01-008-0120][ERROR] failed to apply net.ipv4.icmp_ignore_bogus_error_responses=1"
    fi
fi

# ======================================
# TWGCB-01-008-0121
# 所有網路介面須啟用逆向路徑過濾 (net.ipv4.conf.all.rp_filter=1)
if [ $flag_121 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.all\.rp_filter\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.all\.rp_filter\s*=.*$/# removed by GCB fix 0121/'
    printf "\nnet.ipv4.conf.all.rp_filter = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.all.rp_filter=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_121 1
        log_append "[TWGCB-01-008-0121][FIX] set net.ipv4.conf.all.rp_filter=1"
    else
        set_flag flag_121 0
        log_append "[TWGCB-01-008-0121][ERROR] failed to apply net.ipv4.conf.all.rp_filter=1"
    fi
fi
# ======================================
# TWGCB-01-008-0122
# 預設網路介面須啟用逆向路徑過濾 (net.ipv4.conf.default.rp_filter=1)
if [ $flag_122 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.conf\.default\.rp_filter\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.conf\.default\.rp_filter\s*=.*$/# removed by GCB fix 0122/'
    printf "\nnet.ipv4.conf.default.rp_filter = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.conf.default.rp_filter=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_122 1
        log_append "[TWGCB-01-008-0122][FIX] set net.ipv4.conf.default.rp_filter=1"
    else
        set_flag flag_122 0
        log_append "[TWGCB-01-008-0122][ERROR] failed to apply net.ipv4.conf.default.rp_filter=1"
    fi
fi
# ======================================
# TWGCB-01-008-0123
# TCP SYN cookies須啟用 (net.ipv4.tcp_syncookies=1)
if [ $flag_123 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv4\.tcp_syncookies\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv4\.tcp_syncookies\s*=.*$/# removed by GCB fix 0123/'
    printf "\nnet.ipv4.tcp_syncookies = 1\n" >> /etc/sysctl.d/60-gcb-netipv4.conf
    if sysctl -w net.ipv4.tcp_syncookies=1 && sysctl -w net.ipv4.route.flush=1; then
        set_flag flag_123 1
        log_append "[TWGCB-01-008-0123][FIX] set net.ipv4.tcp_syncookies=1"
    else
        set_flag flag_123 0
        log_append "[TWGCB-01-008-0123][ERROR] failed to apply net.ipv4.tcp_syncookies=1"
    fi
fi
# ======================================
# TWGCB-01-008-0124
# 所有網路介面不接受IPv6 RA (net.ipv6.conf.all.accept_ra=0)
if [ $flag_124 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv6\.conf\.all\.accept_ra\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv6\.conf\.all\.accept_ra\s*=.*$/# removed by GCB fix 0124/'
    printf "\nnet.ipv6.conf.all.accept_ra = 0\n" >> /etc/sysctl.d/60-gcb-netipv6.conf
    if sysctl -w net.ipv6.conf.all.accept_ra=0 && sysctl -w net.ipv6.route.flush=1 2>/dev/null; then
        set_flag flag_124 1
        log_append "[TWGCB-01-008-0124][FIX] set net.ipv6.conf.all.accept_ra=0"
    else
        set_flag flag_124 0
        log_append "[TWGCB-01-008-0124][ERROR] failed to apply net.ipv6.conf.all.accept_ra=0"
    fi
fi
# ======================================
# TWGCB-01-008-0125
# 預設網路介面不接受IPv6 RA (net.ipv6.conf.default.accept_ra=0)
if [ $flag_125 -eq 0 ]; then
    grep -ElsZ '^\s*net\.ipv6\.conf\.default\.accept_ra\s*=' /etc/sysctl.conf /etc/sysctl.d/*.conf 2>/dev/null | \
        xargs -0 -r sed -i 's/^\s*net\.ipv6\.conf\.default\.accept_ra\s*=.*$/# removed by GCB fix 0125/'
    printf "\nnet.ipv6.conf.default.accept_ra = 0\n" >> /etc/sysctl.d/60-gcb-netipv6.conf
    if sysctl -w net.ipv6.conf.default.accept_ra=0 && sysctl -w net.ipv6.route.flush=1 2>/dev/null; then
        set_flag flag_125 1
        log_append "[TWGCB-01-008-0125][FIX] set net.ipv6.conf.default.accept_ra=0"
    else
        set_flag flag_125 0
        log_append "[TWGCB-01-008-0125][ERROR] failed to apply net.ipv6.conf.default.accept_ra=0"
    fi
fi
# ======================================
# TWGCB-01-008-0126
# DCCP協定須停用
if [ $flag_126 -eq 0 ]; then
    conf="/etc/modprobe.d/dccp.conf"
    { echo "install dccp /bin/true"; echo "blacklist dccp"; } > "$conf"
    set_flag flag_126 1
    log_append "[TWGCB-01-008-0126][FIX] disabled dccp module via $conf (reboot required)"
fi
# ======================================
# TWGCB-01-008-0127
# SCTP協定須停用
if [ $flag_127 -eq 0 ]; then
    conf="/etc/modprobe.d/sctp.conf"
    { echo "install sctp /bin/true"; echo "blacklist sctp"; } > "$conf"
    set_flag flag_127 1
    log_append "[TWGCB-01-008-0127][FIX] disabled sctp module via $conf (reboot required)"
fi
# ======================================
# TWGCB-01-008-0128
# RDS協定須停用
if [ $flag_128 -eq 0 ]; then
    conf="/etc/modprobe.d/rds.conf"
    { echo "install rds /bin/true"; echo "blacklist rds"; } > "$conf"
    set_flag flag_128 1
    log_append "[TWGCB-01-008-0128][FIX] disabled rds module via $conf (reboot required)"
fi
# ======================================
# TWGCB-01-008-0129
# TIPC協定須停用
if [ $flag_129 -eq 0 ]; then
    conf="/etc/modprobe.d/tipc.conf"
    { echo "install tipc /bin/true"; echo "blacklist tipc"; } > "$conf"
    set_flag flag_129 1
    log_append "[TWGCB-01-008-0129][FIX] disabled tipc module via $conf (reboot required)"
fi
# ======================================
# TWGCB-01-008-0130
# 無線網路介面須停用
if [ $flag_130 -eq 0 ]; then
    wireless_dirs=$(find /sys/class/net/*/wireless -type d 2>/dev/null)
    if [ -z "$wireless_dirs" ]; then
        set_flag flag_130 1
        log_append "[TWGCB-01-008-0130][FIX] No wireless interfaces found"
    elif command -v nmcli &>/dev/null; then
        if nmcli radio all off; then
            set_flag flag_130 1
            log_append "[TWGCB-01-008-0130][FIX] disabled all wireless interfaces via nmcli"
        else
            set_flag flag_130 0
            log_append "[TWGCB-01-008-0130][ERROR] failed to disable wireless via nmcli"
        fi
    else
        mnames=$(for ddir in $(find /sys/class/net/*/wireless -type d 2>/dev/null | xargs -r dirname); do
            basename "$(readlink -f "$ddir/device/driver/module")" 2>/dev/null
        done | sort -u)
        conf="/etc/modprobe.d/disable_wireless.conf"
        > "$conf"
        for dm in $mnames; do
            echo "install $dm /bin/true" >> "$conf"
            echo "blacklist $dm" >> "$conf"
        done
        set_flag flag_130 1
        log_append "[TWGCB-01-008-0130][FIX] blacklisted wireless drivers in $conf (reboot required)"
    fi
fi

# ======================================
# TWGCB-01-008-0131
# 網路介面不得開啟混雜模式
if [ $flag_131 -eq 0 ]; then
    fail=0
    ip link 2>/dev/null | grep -i promisc | awk -F': ' '{print $2}' | while read -r iface; do
        iface_clean=$(echo "$iface" | awk '{print $1}')
        if ip link set dev "$iface_clean" promisc off 2>/dev/null; then
            log_append "[TWGCB-01-008-0131][FIX] disabled promiscuous mode on interface: $iface_clean"
        else
            log_append "[TWGCB-01-008-0131][ERROR] failed to disable promisc on: $iface_clean"
            fail=$((fail + 1))
        fi
    done
    if [ $fail -eq 0 ]; then set_flag flag_131 1; else set_flag flag_131 0; fi
fi
# ======================================
# TWGCB-01-008-0132
# auditd套件須安裝
if [ $flag_132 -eq 0 ]; then
    if dnf install -y audit audit-libs; then
        set_flag flag_132 1
        log_append "[TWGCB-01-008-0132][FIX] installed audit and audit-libs packages"
    else
        set_flag flag_132 0
        log_append "[TWGCB-01-008-0132][ERROR] failed to install audit/audit-libs packages"
    fi
fi
# ======================================
# TWGCB-01-008-0133
# auditd服務須啟用
if [ $flag_133 -eq 0 ]; then
    if systemctl --now enable auditd; then
        set_flag flag_133 1
        log_append "[TWGCB-01-008-0133][FIX] enabled and started auditd service"
    else
        set_flag flag_133 0
        log_append "[TWGCB-01-008-0133][ERROR] failed to enable auditd service"
    fi
fi
# ======================================
# TWGCB-01-008-0134
# 稽核auditd啟動前之程序 (audit=1 in GRUB_CMDLINE_LINUX)
if [ $flag_134 -eq 0 ]; then
    if [ -f /etc/default/grub ]; then
        if grep -q 'GRUB_CMDLINE_LINUX=' /etc/default/grub; then
            # 在現有的 GRUB_CMDLINE_LINUX 末尾加上 audit=1（若還沒有）
            if ! grep -qE 'GRUB_CMDLINE_LINUX.*audit=1' /etc/default/grub; then
                sed -i 's/\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 audit=1"/' /etc/default/grub
            fi
        else
            echo 'GRUB_CMDLINE_LINUX="audit=1"' >> /etc/default/grub
        fi
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || \
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg 2>/dev/null
        set_flag flag_134 1
        log_append "[TWGCB-01-008-0134][FIX] added audit=1 to GRUB_CMDLINE_LINUX (reboot required)"
    else
        set_flag flag_134 0
        log_append "[TWGCB-01-008-0134][ERROR] /etc/default/grub not found"
    fi
fi
# ======================================
# TWGCB-01-008-0135
# 稽核待辦事項數量限制 (audit_backlog_limit>=8192)
if [ $flag_135 -eq 0 ]; then
    if [ -f /etc/default/grub ]; then
        if grep -qE 'audit_backlog_limit=[0-9]+' /etc/default/grub; then
            # 更新現有值
            sed -i 's/audit_backlog_limit=[0-9]*/audit_backlog_limit=8192/' /etc/default/grub
        elif grep -q 'GRUB_CMDLINE_LINUX=' /etc/default/grub; then
            sed -i 's/\(GRUB_CMDLINE_LINUX="[^"]*\)"/\1 audit_backlog_limit=8192"/' /etc/default/grub
        else
            echo 'GRUB_CMDLINE_LINUX="audit_backlog_limit=8192"' >> /etc/default/grub
        fi
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || \
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg 2>/dev/null
        set_flag flag_135 1
        log_append "[TWGCB-01-008-0135][FIX] set audit_backlog_limit=8192 in GRUB_CMDLINE_LINUX (reboot required)"
    else
        set_flag flag_135 0
        log_append "[TWGCB-01-008-0135][ERROR] /etc/default/grub not found"
    fi
fi
# ======================================
# TWGCB-01-008-0136
# 稽核處理失敗時通知系統管理者 (postmaster: root in /etc/aliases)
if [ $flag_136 -eq 0 ]; then
    if grep -qsE '^\s*postmaster\s*:' /etc/aliases 2>/dev/null; then
        sed -i 's/^\s*postmaster\s*:.*/postmaster: root/' /etc/aliases
    else
        echo "postmaster: root" >> /etc/aliases
    fi
    newaliases 2>/dev/null || true
    set_flag flag_136 1
    log_append "[TWGCB-01-008-0136][FIX] set postmaster: root in /etc/aliases"
fi
# ======================================
# TWGCB-01-008-0137 / 0138 / 0139 / 0140
audit_log_file=$(awk -F'[= \t]+' '/^\s*log_file\s*=/{print $2}' /etc/audit/auditd.conf 2>/dev/null)
audit_log_file="${audit_log_file:-/var/log/audit/audit.log}"
audit_log_dir=$(dirname "$audit_log_file")
# 0137 - 稽核日誌檔案所有權
if [ $flag_137 -eq 0 ]; then
    if [ -f "$audit_log_file" ]; then
        if chown root:root "$audit_log_file"; then
            set_flag flag_137 1
            log_append "[TWGCB-01-008-0137][FIX] changed owner of $audit_log_file to root:root"
        else
            set_flag flag_137 0
            log_append "[TWGCB-01-008-0137][ERROR] failed to chown $audit_log_file"
        fi
    fi
fi
# 0138 - 稽核日誌檔案權限
if [ $flag_138 -eq 0 ]; then
    if [ -f "$audit_log_file" ]; then
        if chmod 600 "$audit_log_file"; then
            set_flag flag_138 1
            log_append "[TWGCB-01-008-0138][FIX] changed permissions of $audit_log_file to 600"
        else
            set_flag flag_138 0
            log_append "[TWGCB-01-008-0138][ERROR] failed to chmod $audit_log_file"
        fi
    fi
fi
# 0139 - 稽核日誌目錄所有權
if [ $flag_139 -eq 0 ]; then
    if [ -d "$audit_log_dir" ]; then
        if chown root:root "$audit_log_dir"; then
            set_flag flag_139 1
            log_append "[TWGCB-01-008-0139][FIX] changed owner of $audit_log_dir to root:root"
        else
            set_flag flag_139 0
            log_append "[TWGCB-01-008-0139][ERROR] failed to chown $audit_log_dir"
        fi
    fi
fi
# 0140 - 稽核日誌目錄權限
if [ $flag_140 -eq 0 ]; then
    if [ -d "$audit_log_dir" ]; then
        if chmod 700 "$audit_log_dir"; then
            set_flag flag_140 1
            log_append "[TWGCB-01-008-0140][FIX] changed permissions of $audit_log_dir to 700"
        else
            set_flag flag_140 0
            log_append "[TWGCB-01-008-0140][ERROR] failed to chmod $audit_log_dir"
        fi
    fi
fi
# 0141 - 稽核規則檔案權限
if [ $flag_141 -eq 0 ]; then
    audit_rules_file="/etc/audit/rules.d/audit.rules"
    if [ -f "$audit_rules_file" ]; then
        if chmod 600 "$audit_rules_file"; then
            set_flag flag_141 1
            log_append "[TWGCB-01-008-0141][FIX] changed permissions of $audit_rules_file to 600"
        else
            set_flag flag_141 0
            log_append "[TWGCB-01-008-0141][ERROR] failed to chmod $audit_rules_file"
        fi
    fi
fi
# 0142 - auditd.conf 檔案權限
if [ $flag_142 -eq 0 ]; then
    if chmod 640 /etc/audit/auditd.conf; then
        set_flag flag_142 1
        log_append "[TWGCB-01-008-0142][FIX] changed permissions of /etc/audit/auditd.conf to 640"
    else
        set_flag flag_142 0
        log_append "[TWGCB-01-008-0142][ERROR] failed to chmod /etc/audit/auditd.conf"
    fi
fi
# 0143 - 稽核工具檔案權限
if [ $flag_143 -eq 0 ]; then
    fail143=0
    audit_tools="/sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/audisp-remote /sbin/audisp-syslog /sbin/augenrules /sbin/rsyslogd"
    for tool in $audit_tools; do
        [ ! -f "$tool" ] && continue
        perm=$(stat -c "%a" "$tool")
        if [ $(( 8#${perm: -3} & ~8#750 & 8#777 )) -ne 0 ]; then
            if chmod 750 "$tool"; then
                log_append "[TWGCB-01-008-0143][FIX] changed permissions of $tool to 750"
            else
                log_append "[TWGCB-01-008-0143][ERROR] failed to chmod $tool"
                fail143=1
            fi
        fi
    done
    if [ $fail143 -eq 0 ]; then set_flag flag_143 1; else set_flag flag_143 0; fi
fi
# 0144 - 稽核工具所有權
if [ $flag_144 -eq 0 ]; then
    fail144=0
    audit_tools="/sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/audisp-remote /sbin/audisp-syslog /sbin/augenrules /sbin/rsyslogd"
    for tool in $audit_tools; do
        [ ! -f "$tool" ] && continue
        owner=$(stat -c "%U:%G" "$tool")
        if [ "$owner" != "root:root" ]; then
            if chown root:root "$tool"; then
                log_append "[TWGCB-01-008-0144][FIX] changed owner of $tool to root:root"
            else
                log_append "[TWGCB-01-008-0144][ERROR] failed to chown $tool"
                fail144=1
            fi
        fi
    done
    if [ $fail144 -eq 0 ]; then set_flag flag_144 1; else set_flag flag_144 0; fi
fi
# 0145 - AIDE 監控稽核工具（僅在 AIDE 已安裝時執行）
if [ "${flag_145:-2}" -eq 0 ]; then
    if command -v aide &>/dev/null; then
        aide_conf="/etc/aide.conf"
        if [ -f "$aide_conf" ]; then
            needs_update=0
            for tool in /sbin/auditctl /sbin/aureport /sbin/ausearch /sbin/autrace /sbin/auditd /sbin/augenrules; do
                [ ! -f "$tool" ] && continue
                if ! grep -qF "$tool" "$aide_conf"; then
                    echo "$tool p+i+n+u+g+s+b+acl+xattrs+sha512" >> "$aide_conf"
                    log_append "[TWGCB-01-008-0145][FIX] added $tool monitoring to $aide_conf"
                    needs_update=1
                fi
            done
            if [ $needs_update -eq 1 ]; then
                set_flag flag_145 1
            else
                set_flag flag_145 1
            fi
        else
            log_append "[TWGCB-01-008-0145][ERROR] $aide_conf not found"
            set_flag flag_145 0
        fi
    fi
fi
# 0146 - auditd max_log_file 設定
if [ $flag_146 -eq 0 ]; then
    auditd_conf="/etc/audit/auditd.conf"
    if grep -qiE '^\s*max_log_file\s*=' "$auditd_conf" 2>/dev/null; then
        sed -i 's/^\s*max_log_file\s*=.*/max_log_file = 32/' "$auditd_conf"
    else
        echo "max_log_file = 32" >> "$auditd_conf"
    fi
    set_flag flag_146 1
    log_append "[TWGCB-01-008-0146][FIX] set max_log_file = 32 in $auditd_conf"
fi
# 0147 - auditd max_log_file_action 設定
if [ $flag_147 -eq 0 ]; then
    auditd_conf="/etc/audit/auditd.conf"
    if grep -qiE '^\s*max_log_file_action\s*=' "$auditd_conf" 2>/dev/null; then
        sed -i 's/^\s*max_log_file_action\s*=.*/max_log_file_action = keep_logs/' "$auditd_conf"
    else
        echo "max_log_file_action = keep_logs" >> "$auditd_conf"
    fi
    set_flag flag_147 1
    log_append "[TWGCB-01-008-0147][FIX] set max_log_file_action = keep_logs in $auditd_conf"
fi
# 0148 - 稽核 sudoers 變更規則
if [ $flag_148 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed148=0
    if ! grep -qF '/etc/sudoers' "$gcb_rules" 2>/dev/null; then
        echo "-w /etc/sudoers -p wa -k scope" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0148][FIX] added audit rule: -w /etc/sudoers -p wa -k scope"
        changed148=1
    fi
    if ! grep -qF '/etc/sudoers.d/' "$gcb_rules" 2>/dev/null; then
        echo "-w /etc/sudoers.d/ -p wa -k scope" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0148][FIX] added audit rule: -w /etc/sudoers.d/ -p wa -k scope"
        changed148=1
    fi
    if [ $changed148 -eq 1 ]; then
        augenrules --load 2>/dev/null && log_append "[TWGCB-01-008-0148][FIX] reloaded audit rules via augenrules"
    fi
    set_flag flag_148 1
fi
# 0149 - 稽核登入失敗記錄規則
if [ $flag_149 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed149=0
    if ! grep -qF '/var/run/faillock/' "$gcb_rules" 2>/dev/null; then
        echo "-w /var/run/faillock/ -p wa -k logins" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0149][FIX] added audit rule: -w /var/run/faillock/ -p wa -k logins"
        changed149=1
    fi
    if ! grep -qF '/var/log/lastlog' "$gcb_rules" 2>/dev/null; then
        echo "-w /var/log/lastlog -p wa -k logins" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0149][FIX] added audit rule: -w /var/log/lastlog -p wa -k logins"
        changed149=1
    fi
    if [ $changed149 -eq 1 ]; then
        augenrules --load 2>/dev/null && log_append "[TWGCB-01-008-0149][FIX] reloaded audit rules via augenrules"
    fi
    set_flag flag_149 1
fi
# 0150 - 稽核 Session 記錄規則
if [ $flag_150 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed150=0
    if ! grep -qF '/var/run/utmp' "$gcb_rules" 2>/dev/null; then
        echo "-w /var/run/utmp -p wa -k session" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0150][FIX] added audit rule: -w /var/run/utmp -p wa -k session"
        changed150=1
    fi
    if ! grep -qF '/var/log/wtmp' "$gcb_rules" 2>/dev/null; then
        echo "-w /var/log/wtmp -p wa -k logins" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0150][FIX] added audit rule: -w /var/log/wtmp -p wa -k logins"
        changed150=1
    fi
    if ! grep -qF '/var/log/btmp' "$gcb_rules" 2>/dev/null; then
        echo "-w /var/log/btmp -p wa -k logins" >> "$gcb_rules"
        log_append "[TWGCB-01-008-0150][FIX] added audit rule: -w /var/log/btmp -p wa -k logins"
        changed150=1
    fi
    if [ $changed150 -eq 1 ]; then
        augenrules --load 2>/dev/null && log_append "[TWGCB-01-008-0150][FIX] reloaded audit rules via augenrules"
    fi
    set_flag flag_150 1
fi
# 0151 - 稽核系統時間修改規則
if [ $flag_151 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_151=(
        "-a always,exit -F arch=b64 -S adjtimex -S settimeofday -k time-change"
        "-a always,exit -F arch=b32 -S adjtimex -S settimeofday -S stime -k time-change"
        "-a always,exit -F arch=b64 -S clock_settime -k time-change"
        "-a always,exit -F arch=b32 -S clock_settime -k time-change"
        "-w /etc/localtime -p wa -k time-change"
    )
    for rule in "${rules_151[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0151][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_151 1
fi
# 0152 - 稽核強制存取控制設定規則
if [ $flag_152 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_152=(
        "-w /etc/selinux/ -p wa -k MAC-policy"
        "-w /usr/share/selinux/ -p wa -k MAC-policy"
    )
    for rule in "${rules_152[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0152][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_152 1
fi
# 0153 - 稽核系統區域資訊變更規則
if [ $flag_153 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_153=(
        "-a always,exit -F arch=b64 -S sethostname -S setdomainname -k system-locale"
        "-a always,exit -F arch=b32 -S sethostname -S setdomainname -k system-locale"
        "-w /etc/issue -p wa -k system-locale"
        "-w /etc/issue.net -p wa -k system-locale"
        "-w /etc/hosts -p wa -k system-locale"
        "-w /etc/sysconfig/network-scripts/ -p wa -k system-locale"
    )
    for rule in "${rules_153[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0153][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_153 1
fi
# 0154 - 稽核自主存取控制權限修改規則
if [ $flag_154 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_154=(
        "-a always,exit -F arch=b64 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod"
        "-a always,exit -F arch=b32 -S chmod -S fchmod -S fchmodat -F auid>=1000 -F auid!=4294967295 -k perm_mod"
        "-a always,exit -F arch=b64 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod"
        "-a always,exit -F arch=b32 -S chown -S fchown -S fchownat -S lchown -F auid>=1000 -F auid!=4294967295 -k perm_mod"
        "-a always,exit -F arch=b64 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod"
        "-a always,exit -F arch=b32 -S setxattr -S lsetxattr -S fsetxattr -S removexattr -S lremovexattr -S fremovexattr -F auid>=1000 -F auid!=4294967295 -k perm_mod"
    )
    for rule in "${rules_154[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0154][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_154 1
fi
# 0155 - 稽核未授權存取嘗試規則
if [ $flag_155 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_155=(
        "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access"
        "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k access"
        "-a always,exit -F arch=b64 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access"
        "-a always,exit -F arch=b32 -S creat -S open -S openat -S truncate -S ftruncate -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k access"
    )
    for rule in "${rules_155[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0155][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_155 1
fi
# 0156 - 稽核使用者與群組帳號資訊規則
if [ $flag_156 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_156=(
        "-w /etc/group -p wa -k identity"
        "-w /etc/passwd -p wa -k identity"
        "-w /etc/gshadow -p wa -k identity"
        "-w /etc/shadow -p wa -k identity"
        "-w /etc/security/opasswd -p wa -k identity"
    )
    for rule in "${rules_156[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0156][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_156 1
fi
# 0157 - 稽核檔案系統掛載操作規則
if [ $flag_157 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_157=(
        "-a always,exit -F arch=b64 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts"
        "-a always,exit -F arch=b32 -S mount -F auid>=1000 -F auid!=4294967295 -k mounts"
    )
    for rule in "${rules_157[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0157][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_157 1
fi
# 0158 - 稽核特權指令使用規則
if [ $flag_158 -eq 0 ]; then
    priv_rules="/etc/audit/rules.d/privileged.rules"
    find / -xdev \( -perm -4000 -o -perm -2000 \) -type f 2>/dev/null | \
        awk '{print "-a always,exit -F path=" $1 " -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged"}' \
        > "$priv_rules"
    augenrules --load 2>/dev/null
    set_flag flag_158 1
    log_append "[TWGCB-01-008-0158][FIX] generated privileged command audit rules in $priv_rules"
fi
# 0159 - 稽核檔案刪除操作規則
if [ $flag_159 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_159=(
        "-a always,exit -F arch=b64 -S unlink -S unlinkat -S rename -S renameat -S rmdir -F auid>=1000 -F auid!=4294967295 -k delete"
        "-a always,exit -F arch=b32 -S unlink -S unlinkat -S rename -S renameat -S rmdir -F auid>=1000 -F auid!=4294967295 -k delete"
    )
    for rule in "${rules_159[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0159][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_159 1
fi
# 0160 - 稽核核心模組載入卸載規則
if [ $flag_160 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_160=(
        "-w /sbin/insmod -p x -k modules"
        "-w /sbin/rmmod -p x -k modules"
        "-w /sbin/modprobe -p x -k modules"
        "-a always,exit -F arch=b64 -S init_module -S delete_module -k modules"
        "-a always,exit -F arch=b32 -S init_module -S delete_module -k modules"
    )
    for rule in "${rules_160[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0160][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_160 1
fi
# 0161 - 稽核系統管理者活動規則
if [ $flag_161 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    sudo_log=$(grep -r logfile /etc/sudoers* 2>/dev/null | sed -e 's/.*logfile=//;s/[, ].*//' | head -1)
    sudo_log="${sudo_log:-/var/log/sudo.log}"
    rule="-w ${sudo_log} -p wa -k actions"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0161][FIX] added audit rule: $rule"
    fi
    set_flag flag_161 1
fi
# 0162 - 稽核 chcon 指令規則
if [ $flag_162 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/usr/bin/chcon -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_chng"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0162][FIX] added audit rule: $rule"
    fi
    set_flag flag_162 1
fi
# 0163 - 稽核 ssh-agent 程序規則
if [ $flag_163 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/usr/bin/ssh-agent -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-ssh"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0163][FIX] added audit rule: $rule"
    fi
    set_flag flag_163 1
fi
# 0164 - 稽核 unix_update 程序規則
if [ $flag_164 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/sbin/unix_update -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-unix-update"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0164][FIX] added audit rule: $rule"
    fi
    set_flag flag_164 1
fi
# 0165 - 稽核 setfacl 指令規則
if [ $flag_165 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/usr/bin/setfacl -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_chng"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0165][FIX] added audit rule: $rule"
    fi
    set_flag flag_165 1
fi
# 0166 - 稽核 finit_module 系統呼叫規則
if [ $flag_166 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_166=(
        "-a always,exit -F arch=b32 -S finit_module -F auid>=1000 -F auid!=4294967295 -k module_chng"
        "-a always,exit -F arch=b64 -S finit_module -F auid>=1000 -F auid!=4294967295 -k module_chng"
    )
    for rule in "${rules_166[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0166][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_166 1
fi
# 0167 - 稽核 open_by_handle_at 系統呼叫規則
if [ $flag_167 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_167=(
        "-a always,exit -F arch=b32 -S open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k perm_access"
        "-a always,exit -F arch=b64 -S open_by_handle_at -F exit=-EPERM -F auid>=1000 -F auid!=4294967295 -k perm_access"
        "-a always,exit -F arch=b32 -S open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k perm_access"
        "-a always,exit -F arch=b64 -S open_by_handle_at -F exit=-EACCES -F auid>=1000 -F auid!=4294967295 -k perm_access"
    )
    for rule in "${rules_167[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0167][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_167 1
fi
# 0168 - 稽核 usermod 指令規則
if [ $flag_168 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/usr/sbin/usermod -F perm=x -F auid>=1000 -F auid!=4294967295 -k privileged-usermod"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0168][FIX] added audit rule: $rule"
    fi
    set_flag flag_168 1
fi
# 0169 - 稽核 chacl 指令規則
if [ $flag_169 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-a always,exit -F path=/usr/bin/chacl -F perm=x -F auid>=1000 -F auid!=4294967295 -k perm_chng"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0169][FIX] added audit rule: $rule"
    fi
    set_flag flag_169 1
fi
# 0170 - 稽核 kmod 指令規則
if [ $flag_170 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    kmod_path=$(command -v kmod 2>/dev/null || echo "/bin/kmod")
    rule="-w ${kmod_path} -p x -k modules"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0170][FIX] added audit rule: $rule"
    fi
    set_flag flag_170 1
fi
# 0171 - 稽核 faillock 登入失敗規則
if [ $flag_171 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    rule="-w /var/log/faillock -p wa -k logins"
    if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
        echo "$rule" >> "$gcb_rules"
        augenrules --load 2>/dev/null
        log_append "[TWGCB-01-008-0171][FIX] added audit rule: $rule"
    fi
    set_flag flag_171 1
fi
# 0172 - 稽核特權提升執行規則
if [ $flag_172 -eq 0 ]; then
    gcb_rules="/etc/audit/rules.d/50-gcb.rules"
    touch "$gcb_rules"
    changed=0
    rules_172=(
        "-a always,exit -F arch=b32 -F auid!=unset -S execve -C uid!=euid -F key=execpriv"
        "-a always,exit -F arch=b64 -F auid!=unset -S execve -C uid!=euid -F key=execpriv"
        "-a always,exit -F arch=b32 -F auid!=unset -S execve -C gid!=egid -F key=execpriv"
        "-a always,exit -F arch=b64 -F auid!=unset -S execve -C gid!=egid -F key=execpriv"
    )
    for rule in "${rules_172[@]}"; do
        if ! grep -qF "$rule" "$gcb_rules" 2>/dev/null; then
            echo "$rule" >> "$gcb_rules"
            log_append "[TWGCB-01-008-0172][FIX] added audit rule: $rule"
            changed=1
        fi
    done
    [ $changed -eq 1 ] && augenrules --load 2>/dev/null
    set_flag flag_172 1
fi
# 0173 - 設定稽核規則不可修改
if [ $flag_173 -eq 0 ]; then
    immutable_rules="/etc/audit/rules.d/99-immutable.rules"
    touch "$immutable_rules"
    if ! grep -qF -- '--loginuid-immutable' "$immutable_rules" 2>/dev/null; then
        echo "--loginuid-immutable" >> "$immutable_rules"
        log_append "[TWGCB-01-008-0173][FIX] added --loginuid-immutable to $immutable_rules"
    fi
    if ! grep -qE '^\s*-e\s+2' "$immutable_rules" 2>/dev/null; then
        echo "-e 2" >> "$immutable_rules"
        log_append "[TWGCB-01-008-0173][FIX] added -e 2 to $immutable_rules (reboot required to activate)"
    fi
    augenrules --load 2>/dev/null
    set_flag flag_173 1
fi
# 0174 - 安裝 rsyslog 套件
if [ $flag_174 -eq 0 ]; then
    if dnf install -y rsyslog 2>/dev/null; then
        set_flag flag_174 1
        log_append "[TWGCB-01-008-0174][FIX] installed rsyslog"
    else
        set_flag flag_174 0
        log_append "[TWGCB-01-008-0174][ERROR] failed to install rsyslog"
    fi
fi
# 0175 - 啟用 rsyslog 服務
if [ $flag_175 -eq 0 ]; then
    if systemctl --now enable rsyslog 2>/dev/null; then
        set_flag flag_175 1
        log_append "[TWGCB-01-008-0175][FIX] enabled and started rsyslog"
    else
        set_flag flag_175 0
        log_append "[TWGCB-01-008-0175][ERROR] failed to enable rsyslog"
    fi
fi
# 0176 - 設定 rsyslog FileCreateMode 為 0640
if [ $flag_176 -eq 0 ]; then
    rsyslog_conf="/etc/rsyslog.conf"
    if grep -qsE '^\s*\$FileCreateMode' "$rsyslog_conf" 2>/dev/null; then
        sed -i 's/^\s*\$FileCreateMode.*/\$FileCreateMode 0640/' "$rsyslog_conf"
    else
        echo '$FileCreateMode 0640' >> "$rsyslog_conf"
    fi
    systemctl restart rsyslog 2>/dev/null
    set_flag flag_176 1
    log_append "[TWGCB-01-008-0176][FIX] set FileCreateMode 0640 in $rsyslog_conf"
fi
# 0177 - 設定 rsyslog 記錄 auth/authpriv/daemon
if [ $flag_177 -eq 0 ]; then
    gcb_rsyslog="/etc/rsyslog.d/50-gcb.conf"
    if ! grep -rqsE 'auth\.\*.*authpriv\.\*|authpriv\.\*.*auth\.\*' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
        echo "auth.*,authpriv.*,daemon.* /var/log/secure" >> "$gcb_rsyslog"
        systemctl restart rsyslog 2>/dev/null
        log_append "[TWGCB-01-008-0177][FIX] added auth logging config to $gcb_rsyslog"
    fi
    set_flag flag_177 1
fi
# 0178 - 修正 /var/log/messages 所有權
if [ "${flag_178:-2}" -eq 0 ]; then
    if [ -f /var/log/messages ]; then
        if chown root:root /var/log/messages; then
            set_flag flag_178 1
            log_append "[TWGCB-01-008-0178][FIX] changed owner of /var/log/messages to root:root"
        else
            set_flag flag_178 0
            log_append "[TWGCB-01-008-0178][ERROR] failed to chown /var/log/messages"
        fi
    fi
fi
# 0179 - 修正 /var/log 目錄所有權
if [ $flag_179 -eq 0 ]; then
    if chown root:root /var/log; then
        set_flag flag_179 1
        log_append "[TWGCB-01-008-0179][FIX] changed owner of /var/log to root:root"
    else
        set_flag flag_179 0
        log_append "[TWGCB-01-008-0179][ERROR] failed to chown /var/log"
    fi
fi
# 0180 - 設定 journald ForwardToSyslog
if [ $flag_180 -eq 0 ]; then
    journald_conf="/etc/systemd/journald.conf"
    if grep -qsE '^\s*ForwardToSyslog\s*=' "$journald_conf" 2>/dev/null; then
        sed -i 's/^\s*ForwardToSyslog\s*=.*/ForwardToSyslog=yes/' "$journald_conf"
    else
        echo "ForwardToSyslog=yes" >> "$journald_conf"
    fi
    systemctl restart systemd-journald 2>/dev/null
    set_flag flag_180 1
    log_append "[TWGCB-01-008-0180][FIX] set ForwardToSyslog=yes in $journald_conf"
fi
# 0181 - 設定 journald 記錄檔壓縮
if [ $flag_181 -eq 0 ]; then
    journald_conf="/etc/systemd/journald.conf"
    if grep -qsE '^\s*Compress\s*=' "$journald_conf" 2>/dev/null; then
        sed -i 's/^\s*Compress\s*=.*/Compress=yes/' "$journald_conf"
    else
        echo "Compress=yes" >> "$journald_conf"
    fi
    systemctl restart systemd-journald 2>/dev/null
    set_flag flag_181 1
    log_append "[TWGCB-01-008-0181][FIX] set Compress=yes in $journald_conf"
fi
# 0182 - 設定 journald 持久化存儲
if [ $flag_182 -eq 0 ]; then
    journald_conf="/etc/systemd/journald.conf"
    if grep -qsE '^\s*Storage\s*=' "$journald_conf" 2>/dev/null; then
        sed -i 's/^\s*Storage\s*=.*/Storage=persistent/' "$journald_conf"
    else
        echo "Storage=persistent" >> "$journald_conf"
    fi
    systemctl restart systemd-journald 2>/dev/null
    set_flag flag_182 1
    log_append "[TWGCB-01-008-0182][FIX] set Storage=persistent in $journald_conf"
fi
# 0185 - 安裝 libselinux 套件
if [ $flag_185 -eq 0 ]; then
    if dnf install -y libselinux 2>/dev/null; then
        set_flag flag_185 1
        log_append "[TWGCB-01-008-0185][FIX] installed libselinux"
    else
        set_flag flag_185 0
        log_append "[TWGCB-01-008-0185][ERROR] failed to install libselinux"
    fi
fi
# 0186 - 移除 GRUB 中的 SELinux 禁用參數
if [ $flag_186 -eq 0 ]; then
    grub_file="/etc/default/grub"
    if grep -qP '(selinux=0|enforcing=0)' "$grub_file" 2>/dev/null; then
        sed -i 's/ selinux=0//g; s/ enforcing=0//g' "$grub_file"
        grub2-mkconfig -o /boot/grub2/grub.cfg 2>/dev/null || \
            grub2-mkconfig -o /boot/efi/EFI/redhat/grub.cfg 2>/dev/null
        log_append "[TWGCB-01-008-0186][FIX] removed selinux=0/enforcing=0 from GRUB (reboot required)"
    fi
    set_flag flag_186 1
fi
# 0187 - 設定 SELinux 框架為 targeted
if [ $flag_187 -eq 0 ]; then
    selinux_conf="/etc/selinux/config"
    if grep -qsE '^\s*SELINUXTYPE\s*=' "$selinux_conf" 2>/dev/null; then
        sed -i 's/^\s*SELINUXTYPE\s*=.*/SELINUXTYPE=targeted/' "$selinux_conf"
    else
        echo "SELINUXTYPE=targeted" >> "$selinux_conf"
    fi
    set_flag flag_187 1
    log_append "[TWGCB-01-008-0187][FIX] set SELINUXTYPE=targeted in $selinux_conf"
fi
# 0188 - 設定 SELinux 為 enforcing 模式
if [ $flag_188 -eq 0 ]; then
    selinux_conf="/etc/selinux/config"
    if grep -qsE '^\s*SELINUX\s*=' "$selinux_conf" 2>/dev/null; then
        sed -i 's/^\s*SELINUX\s*=.*/SELINUX=enforcing/' "$selinux_conf"
    else
        echo "SELINUX=enforcing" >> "$selinux_conf"
    fi
    setenforce 1 2>/dev/null
    set_flag flag_188 1
    log_append "[TWGCB-01-008-0188][FIX] set SELINUX=enforcing and applied setenforce 1"
fi
# 0190 - 移除 setroubleshoot 套件
if [ $flag_190 -eq 0 ]; then
    if dnf remove -y setroubleshoot 2>/dev/null; then
        set_flag flag_190 1
        log_append "[TWGCB-01-008-0190][FIX] removed setroubleshoot"
    else
        set_flag flag_190 0
        log_append "[TWGCB-01-008-0190][ERROR] failed to remove setroubleshoot"
    fi
fi
# 0191 - 移除 mcstrans 套件
if [ $flag_191 -eq 0 ]; then
    if dnf remove -y mcstrans 2>/dev/null; then
        set_flag flag_191 1
        log_append "[TWGCB-01-008-0191][FIX] removed mcstrans"
    else
        set_flag flag_191 0
        log_append "[TWGCB-01-008-0191][ERROR] failed to remove mcstrans"
    fi
fi
# 0192 - 啟用 crond 服務
if [ $flag_192 -eq 0 ]; then
    if systemctl --now enable crond 2>/dev/null; then
        set_flag flag_192 1
        log_append "[TWGCB-01-008-0192][FIX] enabled and started crond"
    else
        set_flag flag_192 0
        log_append "[TWGCB-01-008-0192][ERROR] failed to enable crond"
    fi
fi
# 0193 - 修正 /etc/crontab 所有權
if [ $flag_193 -eq 0 ]; then
    if chown root:root /etc/crontab; then
        set_flag flag_193 1
        log_append "[TWGCB-01-008-0193][FIX] changed owner of /etc/crontab to root:root"
    else
        set_flag flag_193 0
        log_append "[TWGCB-01-008-0193][ERROR] failed to chown /etc/crontab"
    fi
fi
# 0194 - 修正 /etc/crontab 權限
if [ $flag_194 -eq 0 ]; then
    if chmod 600 /etc/crontab; then
        set_flag flag_194 1
        log_append "[TWGCB-01-008-0194][FIX] changed permissions of /etc/crontab to 600"
    else
        set_flag flag_194 0
        log_append "[TWGCB-01-008-0194][ERROR] failed to chmod /etc/crontab"
    fi
fi
# 0195 - 修正 /etc/cron.hourly 所有權
if [ $flag_195 -eq 0 ]; then
    if chown root:root /etc/cron.hourly; then
        set_flag flag_195 1
        log_append "[TWGCB-01-008-0195][FIX] changed owner of /etc/cron.hourly to root:root"
    else
        set_flag flag_195 0
        log_append "[TWGCB-01-008-0195][ERROR] failed to chown /etc/cron.hourly"
    fi
fi
# 0196 - 修正 /etc/cron.hourly 權限
if [ $flag_196 -eq 0 ]; then
    if chmod 700 /etc/cron.hourly; then
        set_flag flag_196 1
        log_append "[TWGCB-01-008-0196][FIX] changed permissions of /etc/cron.hourly to 700"
    else
        set_flag flag_196 0
        log_append "[TWGCB-01-008-0196][ERROR] failed to chmod /etc/cron.hourly"
    fi
fi
# 0197 - 修正 /etc/cron.daily 所有權
if [ $flag_197 -eq 0 ]; then
    if chown root:root /etc/cron.daily; then
        set_flag flag_197 1
        log_append "[TWGCB-01-008-0197][FIX] changed owner of /etc/cron.daily to root:root"
    else
        set_flag flag_197 0
        log_append "[TWGCB-01-008-0197][ERROR] failed to chown /etc/cron.daily"
    fi
fi
# 0198 - 修正 /etc/cron.daily 權限
if [ $flag_198 -eq 0 ]; then
    if chmod 700 /etc/cron.daily; then
        set_flag flag_198 1
        log_append "[TWGCB-01-008-0198][FIX] changed permissions of /etc/cron.daily to 700"
    else
        set_flag flag_198 0
        log_append "[TWGCB-01-008-0198][ERROR] failed to chmod /etc/cron.daily"
    fi
fi
# 0199 - 修正 /etc/cron.weekly 所有權
if [ $flag_199 -eq 0 ]; then
    if chown root:root /etc/cron.weekly; then
        set_flag flag_199 1
        log_append "[TWGCB-01-008-0199][FIX] changed owner of /etc/cron.weekly to root:root"
    else
        set_flag flag_199 0
        log_append "[TWGCB-01-008-0199][ERROR] failed to chown /etc/cron.weekly"
    fi
fi
# 0200 - 修正 /etc/cron.weekly 權限
if [ $flag_200 -eq 0 ]; then
    if chmod 700 /etc/cron.weekly; then
        set_flag flag_200 1
        log_append "[TWGCB-01-008-0200][FIX] changed permissions of /etc/cron.weekly to 700"
    else
        set_flag flag_200 0
        log_append "[TWGCB-01-008-0200][ERROR] failed to chmod /etc/cron.weekly"
    fi
fi
# 0201 - 修正 /etc/cron.monthly 所有權
if [ $flag_201 -eq 0 ]; then
    if chown root:root /etc/cron.monthly; then
        set_flag flag_201 1
        log_append "[TWGCB-01-008-0201][FIX] changed owner of /etc/cron.monthly to root:root"
    else
        set_flag flag_201 0
        log_append "[TWGCB-01-008-0201][ERROR] failed to chown /etc/cron.monthly"
    fi
fi
# 0202 - 修正 /etc/cron.monthly 權限
if [ $flag_202 -eq 0 ]; then
    if chmod 700 /etc/cron.monthly; then
        set_flag flag_202 1
        log_append "[TWGCB-01-008-0202][FIX] changed permissions of /etc/cron.monthly to 700"
    else
        set_flag flag_202 0
        log_append "[TWGCB-01-008-0202][ERROR] failed to chmod /etc/cron.monthly"
    fi
fi
# 0203 - 修正 /etc/cron.d 所有權
if [ $flag_203 -eq 0 ]; then
    if chown root:root /etc/cron.d; then
        set_flag flag_203 1
        log_append "[TWGCB-01-008-0203][FIX] changed owner of /etc/cron.d to root:root"
    else
        set_flag flag_203 0
        log_append "[TWGCB-01-008-0203][ERROR] failed to chown /etc/cron.d"
    fi
fi
# 0204 - 修正 /etc/cron.d 權限
if [ $flag_204 -eq 0 ]; then
    if chmod 700 /etc/cron.d; then
        set_flag flag_204 1
        log_append "[TWGCB-01-008-0204][FIX] changed permissions of /etc/cron.d to 700"
    else
        set_flag flag_204 0
        log_append "[TWGCB-01-008-0204][ERROR] failed to chmod /etc/cron.d"
    fi
fi
# 0205 - 設定 cron.allow/at.allow 所有權
if [ $flag_205 -eq 0 ]; then
    rm -f /etc/cron.deny /etc/at.deny
    touch /etc/cron.allow /etc/at.allow
    chown root:root /etc/cron.allow /etc/at.allow
    set_flag flag_205 1
    log_append "[TWGCB-01-008-0205][FIX] removed cron.deny/at.deny, created cron.allow/at.allow with root ownership"
fi
# 0206 - 設定 cron.allow/at.allow 權限
if [ $flag_206 -eq 0 ]; then
    touch /etc/cron.allow /etc/at.allow
    chmod 600 /etc/cron.allow /etc/at.allow
    set_flag flag_206 1
    log_append "[TWGCB-01-008-0206][FIX] set permissions of cron.allow and at.allow to 600"
fi
# 0207 - 設定 rsyslog cron 日誌記錄
if [ $flag_207 -eq 0 ]; then
    gcb_rsyslog="/etc/rsyslog.d/50-gcb.conf"
    mkdir -p /etc/rsyslog.d
    if ! grep -rqsE 'cron\.\*' /etc/rsyslog.conf /etc/rsyslog.d/ 2>/dev/null; then
        echo "cron.* /var/log/cron" >> "$gcb_rsyslog"
        systemctl restart rsyslog 2>/dev/null
        log_append "[TWGCB-01-008-0207][FIX] added cron logging to $gcb_rsyslog"
    fi
    set_flag flag_207 1
fi
# 0208 - 設定 PAM 密碼重試次數 retry=3
if [ $flag_208 -eq 0 ]; then
    pwq_conf="/etc/security/pwquality.conf"
    if grep -qiE '^\s*[Rr]etry\s*=' "$pwq_conf" 2>/dev/null; then
        sed -i 's/^\s*[Rr]etry\s*=.*/Retry = 3/' "$pwq_conf"
    else
        echo "Retry = 3" >> "$pwq_conf"
    fi
    set_flag flag_208 1
    log_append "[TWGCB-01-008-0208][FIX] set Retry=3 in $pwq_conf"
fi
# 0209 - 設定 PAM enforce_for_root
if [ $flag_209 -eq 0 ]; then
    CP=$(authselect current 2>/dev/null | awk 'NR == 1 {print $3}' | grep custom/)
    for FN in system-auth password-auth; do
        [ -n "$CP" ] && PTF="/etc/authselect/$CP/$FN" || PTF="/etc/authselect/$FN"
        [ ! -f "$PTF" ] && PTF="/etc/pam.d/$FN"
        [ ! -f "$PTF" ] && continue
        if ! grep -qE '^\s*password\s+requisite\s+pam_pwquality.so.*enforce_for_root' "$PTF" 2>/dev/null; then
            sed -ri 's/^(\s*password\s+requisite\s+pam_pwquality.so\s+)(.*)$/\1\2 enforce_for_root/' "$PTF"
            log_append "[TWGCB-01-008-0209][FIX] added enforce_for_root to $PTF"
        fi
    done
    authselect apply-changes 2>/dev/null
    set_flag flag_209 1
fi
# 0210 - 設定密碼最小長度 minlen=12
if [ $flag_210 -eq 0 ]; then
    pwq_conf="/etc/security/pwquality.conf"
    if grep -qiE '^\s*minlen\s*=' "$pwq_conf" 2>/dev/null; then
        sed -i 's/^\s*minlen\s*=.*/minlen = 12/' "$pwq_conf"
    else
        echo "minlen = 12" >> "$pwq_conf"
    fi
    if grep -qE '^\s*PASS_MIN_LEN\s+' /etc/login.defs 2>/dev/null; then
        sed -i 's/^\s*PASS_MIN_LEN\s+.*/PASS_MIN_LEN\t12/' /etc/login.defs
    else
        echo "PASS_MIN_LEN	12" >> /etc/login.defs
    fi
    set_flag flag_210 1
    log_append "[TWGCB-01-008-0210][FIX] set minlen=12 in pwquality.conf and PASS_MIN_LEN=12 in login.defs"
fi
# 0211 - 設定密碼字元類別要求 minclass=4
if [ $flag_211 -eq 0 ]; then
    pwq_conf="/etc/security/pwquality.conf"
    if grep -qiE '^\s*minclass\s*=' "$pwq_conf" 2>/dev/null; then
        sed -i 's/^\s*minclass\s*=.*/minclass = 4/' "$pwq_conf"
    else
        echo "minclass = 4" >> "$pwq_conf"
    fi
    set_flag flag_211 1
    log_append "[TWGCB-01-008-0211][FIX] set minclass=4 in $pwq_conf"
fi
# 0212 - 設定密碼須含數字 dcredit=-1
if [ $flag_212 -eq 0 ]; then
    pwq_conf="/etc/security/pwquality.conf"
    if grep -qiE '^\s*dcredit\s*=' "$pwq_conf" 2>/dev/null; then
        sed -i 's/^\s*dcredit\s*=.*/dcredit = -1/' "$pwq_conf"
    else
        echo "dcredit = -1" >> "$pwq_conf"
    fi
    set_flag flag_212 1
    log_append "[TWGCB-01-008-0212][FIX] set dcredit=-1 in $pwq_conf"
fi

echo
echo "Summary: $success fixes applied, $ignore fixes ignored, $error errors occurred."
echo "Fix completed. Please reboot the system and review the log file for details."