#!/bin/bash
#===============================================================================
# change_nic.sh - Rocky Linux 8 網卡名稱 & MAC 位址修改工具
# 用途：修改網路介面名稱（如 eth0 → lan0）及 MAC 位址（持久化）
# 適用：Rocky Linux 8 / RHEL 8 / CentOS 8（NetworkManager 環境）
# 執行：sudo bash change_nic.sh
#===============================================================================

set -euo pipefail

# ---- 顏色定義 ----
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $*"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $*"; }
error() { echo -e "${RED}[ERROR]${NC} $*"; }

# ---- 權限檢查 ----
if [[ $EUID -ne 0 ]]; then
    error "請以 root 執行：sudo bash $0"
    exit 1
fi

# ---- 列出目前網卡資訊 ----
show_nics() {
    echo ""
    echo -e "${CYAN}========== 目前網路介面 ==========${NC}"
    printf "%-16s %-20s %-10s %s\n" "介面名稱" "MAC 位址" "狀態" "連線設定(nmcli)"
    echo "--------------------------------------------------------------"
    for dev in /sys/class/net/*; do
        name=$(basename "$dev")
        [[ "$name" == "lo" ]] && continue
        mac=$(cat "$dev/address" 2>/dev/null || echo "N/A")
        state=$(cat "$dev/operstate" 2>/dev/null || echo "unknown")
        nm_conn=$(nmcli -t -f NAME,DEVICE con show --active 2>/dev/null \
                  | grep ":${name}$" | cut -d: -f1 || echo "-")
        [[ -z "$nm_conn" ]] && nm_conn="-"
        printf "%-16s %-20s %-10s %s\n" "$name" "$mac" "$state" "$nm_conn"
    done
    echo ""
}

# ---- 驗證 MAC 格式 ----
validate_mac() {
    local mac="$1"
    if [[ "$mac" =~ ^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$ ]]; then
        return 0
    fi
    return 1
}

# ---- 驗證介面名稱 ----
validate_ifname() {
    local name="$1"
    # Linux 介面名稱：1-15 字元，不含 / 空白 :
    if [[ "$name" =~ ^[a-zA-Z0-9_-]{1,15}$ ]]; then
        return 0
    fi
    return 1
}

# ---- 取得介面的硬體 MAC（用於 udev 規則比對） ----
get_permanent_mac() {
    local iface="$1"
    # 優先用 ethtool 取得原始 MAC
    local pmac
    pmac=$(ethtool -P "$iface" 2>/dev/null | awk '{print $NF}')
    if [[ -n "$pmac" && "$pmac" != "00:00:00:00:00:00" ]]; then
        echo "$pmac"
    else
        cat "/sys/class/net/${iface}/address"
    fi
}

# ---- 修改 MAC 位址 ----
change_mac() {
    local iface="$1"
    local new_mac="$2"

    # 找到 nmcli 連線名稱
    local conn_name
    conn_name=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null \
                | grep ":${iface}$" | head -1 | cut -d: -f1)

    if [[ -n "$conn_name" ]]; then
        info "透過 NetworkManager 設定 MAC（連線：${conn_name}）"
        nmcli con modify "$conn_name" ethernet.cloned-mac-address "$new_mac"
        nmcli con down "$conn_name" 2>/dev/null || true
        nmcli con up "$conn_name"
        info "MAC 已變更為 ${new_mac}（持久化，重開機後生效）"
    else
        warn "找不到 nmcli 連線設定，改用 ip link 臨時修改"
        ip link set "$iface" down
        ip link set "$iface" address "$new_mac"
        ip link set "$iface" up
        warn "此為臨時變更，重開機後會還原。建議用 nmcli 管理。"
    fi
}

# ---- 修改網卡名稱（透過 udev 規則持久化） ----
change_name() {
    local old_name="$1"
    local new_name="$2"

    # 檢查新名稱是否已被佔用
    if [[ -d "/sys/class/net/${new_name}" ]]; then
        error "介面名稱 '${new_name}' 已存在！"
        return 1
    fi

    # 取得硬體 MAC 作為 udev 比對依據
    local hw_mac
    hw_mac=$(get_permanent_mac "$old_name")
    info "硬體 MAC: ${hw_mac}"

    # 寫入 udev 規則
    local udev_file="/etc/udev/rules.d/70-custom-ifnames.rules"
    # 移除該 MAC 的舊規則（如有）
    if [[ -f "$udev_file" ]]; then
        sed -i "/${hw_mac}/Id" "$udev_file"
    fi

    local rule="SUBSYSTEM==\"net\", ACTION==\"add\", ATTR{address}==\"${hw_mac}\", NAME=\"${new_name}\""
    echo "$rule" >> "$udev_file"
    info "已寫入 udev 規則：${udev_file}"
    echo "  → ${rule}"

    # 同步更新 nmcli 連線設定中的 interface-name
    local conn_name
    conn_name=$(nmcli -t -f NAME,DEVICE con show 2>/dev/null \
                | grep ":${old_name}$" | head -1 | cut -d: -f1)

    if [[ -n "$conn_name" ]]; then
        nmcli con modify "$conn_name" connection.interface-name "$new_name"
        info "已更新 nmcli 連線 '${conn_name}' 的 interface-name → ${new_name}"
    fi

    # 如果有 ifcfg 檔案也一併更新
    local ifcfg="/etc/sysconfig/network-scripts/ifcfg-${old_name}"
    if [[ -f "$ifcfg" ]]; then
        sed -i "s/^DEVICE=.*/DEVICE=${new_name}/" "$ifcfg"
        local new_ifcfg="/etc/sysconfig/network-scripts/ifcfg-${new_name}"
        if [[ "$ifcfg" != "$new_ifcfg" ]]; then
            mv "$ifcfg" "$new_ifcfg"
            info "已重新命名 ifcfg 檔案 → ${new_ifcfg}"
        fi
    fi

    warn "網卡名稱變更需重開機才會生效。"
    echo -e "  執行: ${CYAN}reboot${NC}"
}

# ---- 停用 Predictable Network Interface Names（選用） ----
disable_predictable_names() {
    info "停用 Predictable Network Interface Names..."
    info "這會讓系統回歸 eth0/eth1 傳統命名（搭配 udev 規則可自訂）"

    # 加入 kernel 參數
    local grub_file="/etc/default/grub"
    if grep -q "net.ifnames=0" "$grub_file" 2>/dev/null; then
        info "GRUB 已包含 net.ifnames=0，跳過。"
    else
        cp "$grub_file" "${grub_file}.bak.$(date +%Y%m%d%H%M%S)"
        sed -i 's/\(GRUB_CMDLINE_LINUX="[^"]*\)/\1 net.ifnames=0 biosdevname=0/' "$grub_file"
        info "已修改 ${grub_file}，加入 net.ifnames=0 biosdevname=0"

        # 重建 GRUB
        if [[ -d /sys/firmware/efi ]]; then
            grub2-mkconfig -o /boot/efi/EFI/rocky/grub.cfg
        else
            grub2-mkconfig -o /boot/grub2/grub.cfg
        fi
        info "GRUB 設定已重建。"
    fi

    warn "需重開機生效。重開機後網卡名稱會變為 eth0, eth1 等。"
}

# ======== 主選單 ========
main() {
    echo -e "${CYAN}"
    echo "╔══════════════════════════════════════════════╗"
    echo "║   Rocky Linux 8 - 網卡名稱 / MAC 修改工具   ║"
    echo "╚══════════════════════════════════════════════╝"
    echo -e "${NC}"

    show_nics

    echo "請選擇操作："
    echo "  1) 修改 MAC 位址"
    echo "  2) 修改網卡名稱"
    echo "  3) 同時修改名稱與 MAC"
    echo "  4) 停用 Predictable Names（回歸 eth0 命名）"
    echo "  5) 僅顯示目前網卡資訊"
    echo "  q) 離開"
    echo ""
    read -rp "選擇 [1-5/q]: " choice

    case "$choice" in
        1)
            read -rp "輸入要修改的網卡名稱（如 eth0）: " iface
            if [[ ! -d "/sys/class/net/${iface}" ]]; then
                error "介面 '${iface}' 不存在"; exit 1
            fi
            read -rp "輸入新的 MAC 位址（格式 AA:BB:CC:DD:EE:FF）: " new_mac
            if ! validate_mac "$new_mac"; then
                error "MAC 格式不正確"; exit 1
            fi
            change_mac "$iface" "$new_mac"
            ;;
        2)
            read -rp "輸入目前的網卡名稱（如 ens192）: " old_name
            if [[ ! -d "/sys/class/net/${old_name}" ]]; then
                error "介面 '${old_name}' 不存在"; exit 1
            fi
            read -rp "輸入新的網卡名稱（如 eth0）: " new_name
            if ! validate_ifname "$new_name"; then
                error "名稱格式不正確（1-15 字元，英數 _ -）"; exit 1
            fi
            change_name "$old_name" "$new_name"
            ;;
        3)
            read -rp "輸入目前的網卡名稱（如 ens192）: " old_name
            if [[ ! -d "/sys/class/net/${old_name}" ]]; then
                error "介面 '${old_name}' 不存在"; exit 1
            fi
            read -rp "輸入新的網卡名稱（如 eth0）: " new_name
            if ! validate_ifname "$new_name"; then
                error "名稱格式不正確"; exit 1
            fi
            read -rp "輸入新的 MAC 位址（格式 AA:BB:CC:DD:EE:FF）: " new_mac
            if ! validate_mac "$new_mac"; then
                error "MAC 格式不正確"; exit 1
            fi
            change_mac "$old_name" "$new_mac"
            change_name "$old_name" "$new_name"
            ;;
        4)
            disable_predictable_names
            ;;
        5)
            info "已顯示於上方。"
            ;;
        q|Q)
            info "離開。"
            exit 0
            ;;
        *)
            error "無效選擇"
            exit 1
            ;;
    esac

    echo ""
    info "完成。目前狀態："
    show_nics
}

main "$@"
