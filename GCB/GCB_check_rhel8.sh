#!/bin/bash
# This script checks if the operating system is RHEL 8  
##version:20260203

log="./GCB_check_rhel8.log"

log_append() {
    echo "$1" | tee -a "$log"
}

# ======================================
# TWGCB-01-008-0001
# cramfs檔案系統需設定為停用
check_cramfs_disabled() {
    log_append "Check TWGCB-01-008-0001: cramfs filesystem disabled"
    if ! grep -q "^install cramfs /bin/true" /etc/modprobe.d/cramfs.conf 2>/dev/null; then
        log_append "  [FAIL] cramfs is not disabled."
    else
        log_append "  [PASS] cramfs is disabled."
    fi
}
# ======================================
