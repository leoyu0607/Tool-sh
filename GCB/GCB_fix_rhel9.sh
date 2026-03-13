#!/bin/bash
# This script fixes GCB settings for RHEL 9
##version:GCB_v1.0

if [ "$(id -u)" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

flag="./.GCBflag"
source "$flag"
log="./GCB_fix_rhel9.log"
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
# TWGCB-01-012-0001
# cramfs檔案系統需設定為停用
if [ $flag_001 -eq 0 ]; then
    echo "install cramfs /bin/true" | tee /etc/modprobe.d/cramfs.conf
    echo "blacklist cramfs" | tee -a /etc/modprobe.d/cramfs.conf
    dracut -f
    set_flag flag_001 1
    log_append "[TWGCB-01-012-0001][FIX] disable the cramfs"
fi
# ======================================
# TWGCB-01-012-0002
# squashfs檔案系統需設定為停用
if [ $flag_002 -eq 0 ]; then
    SQUASHFS_CONF="/etc/modprobe.d/squashfs.conf"
    echo "install squashfs /bin/true" | tee "$SQUASHFS_CONF"
    echo "blacklist squashfs" | tee -a "$SQUASHFS_CONF"
    dracut -f
    set_flag flag_002 1
    log_append "[TWGCB-01-012-0002][FIX] disable the squashfs"
fi
# ======================================
# TWGCB-01-012-0003
# udf檔案系統需設定為停用
if [ $flag_003 -eq 0 ]; then
    UDF_CONF="/etc/modprobe.d/udf.conf"
    echo "install udf /bin/true" | tee "$UDF_CONF"
    echo "blacklist udf" | tee -a "$UDF_CONF"
    dracut -f
    set_flag flag_003 1
    log_append "[TWGCB-01-012-0003][FIX] disable the udf"
fi
# ======================================
# TWGCB-01-012-0004
# 設定/tmp目錄需為tmpfs
if [ $flag_004 -eq 0 ]; then
    systemctl enable --now tmp.mount
    set_flag flag_004 1
    log_append "[TWGCB-01-012-0004][FIX] set /tmp mounted as tmpfs"
fi
# ======================================
# TWGCB-01-012-0005
# /tmp目錄之nodev選項須設定為啟用
# TWGCB-01-012-0006
# /tmp目錄之nosuid選項須設定為啟用
if [ $flag_005 -eq 0 ] || [ $flag_006 -eq 0 ]; then
    # 優先修改 systemd tmp.mount 設定
    TMPMOUNT_OVERRIDE="/etc/systemd/system/tmp.mount.d"
    mkdir -p "$TMPMOUNT_OVERRIDE"
    cat > "$TMPMOUNT_OVERRIDE/options.conf" <<'EOF'
[Mount]
Options=mode=1777,strictatime,nosuid,nodev
EOF
    systemctl daemon-reload
    systemctl restart tmp.mount
    set_flag flag_005 1
    log_append "[TWGCB-01-012-0005][FIX] set /tmp option as nodev"
    set_flag flag_006 1
    log_append "[TWGCB-01-012-0006][FIX] set /tmp option as nosuid"
fi
# ======================================
# TWGCB-01-012-0007
# /tmp目錄之noexec選項須設定為啟用
if [ $flag_007 -eq 0 ]; then
    #TMPMOUNT_OVERRIDE="/etc/systemd/system/tmp.mount.d"
    #mkdir -p "$TMPMOUNT_OVERRIDE"
    #cat > "$TMPMOUNT_OVERRIDE/options.conf" <<'EOF'
    #[Mount]
    #Options=mode=1777,strictatime,nosuid,nodev,noexec
    #EOF
    #systemctl daemon-reload
    #systemctl restart tmp.mount
    #set_flag flag_007 1
    #log_append "[TWGCB-01-012-0007][FIX] set /tmp option as noexec"
    log_append "[TWGCB-01-012-0007][IGNORE] 設定後影響服務使用"
fi
# ======================================
# TWGCB-01-012-0008
# 需為/var配置獨立之分割磁區或邏輯磁區
if [ $flag_008 -eq 0 ]; then
    set_flag flag_008 2
    log_append "[TWGCB-01-012-0008][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-012-0009
# 需為/var/tmp配置獨立之分割磁區或邏輯磁區
if [ $flag_009 -eq 0 ]; then
    set_flag flag_009 2
    log_append "[TWGCB-01-012-0009][IGNORE] 需要重建VM或擴充磁碟"
fi
# ======================================
# TWGCB-01-012-0010
# /var/tmp須設定nodev選項
if [ $flag_010 -eq 0 ]; then
    mount_point="/var/tmp"
    if awk -v mp="$mount_point" '
    BEGIN { OFS="\t" }
    /^[[:space:]]*($|#)/ { print; next }
    {
    if (NF < 4) { print; next }
    if ($2 != mp) { print; next }
    opts = $4
    n = split(opts, a, ",")
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
    if (!("nodev" in seen)) out = (out == "" ? "nodev" : out ",nodev")
    $4 = out
    print
    }
    ' /etc/fstab > /etc/fstab.tmp && mv /etc/fstab.tmp /etc/fstab; then
        set_flag flag_010 1
        log_append "[TWGCB-01-012-0010][FIX] add nodev option to /var/tmp in /etc/fstab"
        mount -o remount,nodev "$mount_point" 2>/dev/null || true
    else
        set_flag flag_010 0
        log_append "[TWGCB-01-012-0010][ERROR] failed to update /etc/fstab for nodev option on /var/tmp"
    fi
fi

echo
# ======================================
# 結果統計
log_append "========================================"
log_append "修復結果統計:"
log_append "成功(SUCCESS): $success"
log_append "忽略(IGNORE): $ignore"
log_append "失敗(ERROR): $error"
log_append "========================================"
echo "Log saved to: $log"
