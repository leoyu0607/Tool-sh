#!/bin/bash
#
# import_cert.sh
# 匯入憑證至 Java cacerts 並新增 hosts 紀錄
#
# Usage:
#   sudo ./import_cert.sh -c <憑證檔> -j <Java Home 路徑> -a <別名> -u <執行keytool的使用者> -h <hosts紀錄>
#
# Example:
#   sudo ./import_cert.sh \
#     -c /tmp/myca.crt \
#     -j /usr/lib/jvm/java-1.8.0/jre \
#     -a myca \
#     -u appuser \
#     -h "10.0.0.5 api.internal.local"

set -euo pipefail

# ===== 預設值 =====
CERT_FILE="./ai3_cloud.crt"
JAVA_HOME=""
ALIAS="Ai3"
RUN_USER="ai3"
HOSTS_ENTRY="192.168.173.125 nginx.ai3.cloud"
KEYSTORE_PASS="changeit"   # Java cacerts 預設密碼

usage() {
    cat <<EOF
Usage: sudo $0 -c <憑證檔> -j <Java Home 路徑> -a <別名> -u <使用者> -h <hosts紀錄> [-p <密碼>]

  -c  憑證檔案路徑 (PEM/DER)
  -j  Java Home 路徑
  -a  匯入別名 (alias)
  -u  執行 keytool 的使用者
  -h  要加入 /etc/hosts 的紀錄，格式: "IP FQDN"
  -p  keystore 密碼 (預設: changeit)
EOF
    exit 1
}

# ===== 參數解析 =====
while getopts "c:j:a:u:h:p:" opt; do
    case "$opt" in
        c) CERT_FILE="$OPTARG" ;;
        j) JAVA_HOME="$OPTARG" ;;
        a) ALIAS="$OPTARG" ;;
        u) RUN_USER="$OPTARG" ;;
        h) HOSTS_ENTRY="$OPTARG" ;;
        p) KEYSTORE_PASS="$OPTARG" ;;
        *) usage ;;
    esac
done

# 找到 keytool 路徑（與 keystore 同一 JAVA_HOME）
KEYSTORE="${JAVA_HOME:+$JAVA_HOME/lib/security/cacerts}"
KEYTOOL="${JAVA_HOME:+$JAVA_HOME/bin/keytool}"

# ===== 驗證必要參數 =====
[[ -z "$CERT_FILE" || -z "$JAVA_HOME" || -z "$KEYSTORE" || -z "$ALIAS" || -z "$RUN_USER" || -z "$HOSTS_ENTRY" ]] && usage

# ===== 前置檢查 =====
if [[ $EUID -ne 0 ]]; then
    echo "[ERROR] 此腳本需要 root 權限執行 (sudo)" >&2
    exit 1
fi

if [[ ! -f "$CERT_FILE" ]]; then
    echo "[ERROR] 憑證檔案不存在: $CERT_FILE" >&2
    exit 1
fi

if [[ ! -f "$KEYSTORE" ]]; then
    echo "[ERROR] Keystore 不存在: $KEYSTORE" >&2
    exit 1
fi

if ! id "$RUN_USER" &>/dev/null; then
    echo "[ERROR] 使用者不存在: $RUN_USER" >&2
    exit 1
fi

if [[ ! -x "$KEYTOOL" ]]; then
    # fallback: 從 PATH 找
    KEYTOOL=$(command -v keytool 2>/dev/null || true)
    if [[ -z "$KEYTOOL" ]]; then
        echo "[ERROR] 找不到 keytool，請確認 JAVA_HOME 或 PATH" >&2
        exit 1
    fi
fi

echo "========================================"
echo " 憑證匯入 & Hosts 設定"
echo "========================================"
echo " 憑證檔案 : $CERT_FILE"
echo " Keystore : $KEYSTORE"
echo " 別名     : $ALIAS"
echo " 執行使用者: $RUN_USER"
echo " keytool  : $KEYTOOL"
echo " Hosts 紀錄: $HOSTS_ENTRY"
echo "========================================"

# ===== Step 1: 檢查別名是否已存在 =====
echo ""
echo "[Step 1] 檢查別名 '$ALIAS' 是否已存在..."

if su - "$RUN_USER" -s /bin/bash -c \
    "'$KEYTOOL' -list -alias '$ALIAS' -keystore '$KEYSTORE' -storepass '$KEYSTORE_PASS'" &>/dev/null; then
    echo "[WARN] 別名 '$ALIAS' 已存在，先刪除舊憑證..."
    su - "$RUN_USER" -s /bin/bash -c \
        "'$KEYTOOL' -delete -alias '$ALIAS' -keystore '$KEYSTORE' -storepass '$KEYSTORE_PASS'"
    echo "[OK] 舊憑證已刪除"
fi

# ===== Step 2: 匯入憑證（切換使用者） =====
echo ""
echo "[Step 2] 以使用者 '$RUN_USER' 匯入憑證..."

# 確保該使用者可讀取憑證檔
TEMP_CERT=$(mktemp /tmp/cert_import_XXXXXX.crt)
cp "$CERT_FILE" "$TEMP_CERT"
chmod 644 "$TEMP_CERT"

su - "$RUN_USER" -s /bin/bash -c \
    "'$KEYTOOL' -importcert \
        -noprompt \
        -trustcacerts \
        -alias '$ALIAS' \
        -file '$TEMP_CERT' \
        -keystore '$KEYSTORE' \
        -storepass '$KEYSTORE_PASS'"

if [[ $? -eq 0 ]]; then
    echo "[OK] 憑證匯入成功"
else
    echo "[ERROR] 憑證匯入失敗" >&2
    rm -f "$TEMP_CERT"
    exit 1
fi

rm -f "$TEMP_CERT"

# ===== Step 3: 驗證匯入結果 =====
echo ""
echo "[Step 3] 驗證匯入結果..."

su - "$RUN_USER" -s /bin/bash -c \
    "'$KEYTOOL' -list -alias '$ALIAS' -keystore '$KEYSTORE' -storepass '$KEYSTORE_PASS'" \
    && echo "[OK] 驗證通過" \
    || { echo "[ERROR] 驗證失敗" >&2; exit 1; }

# ===== Step 4: 新增 /etc/hosts 紀錄 =====
echo ""
echo "[Step 4] 設定 /etc/hosts..."

HOSTS_IP=$(echo "$HOSTS_ENTRY" | awk '{print $1}')
HOSTS_FQDN=$(echo "$HOSTS_ENTRY" | awk '{print $2}')

if grep -qE "^[^#]*\b${HOSTS_FQDN}\b" /etc/hosts; then
    echo "[WARN] /etc/hosts 已有 '$HOSTS_FQDN' 的紀錄："
    grep -E "\b${HOSTS_FQDN}\b" /etc/hosts
    echo "[SKIP] 跳過 hosts 設定，如需覆蓋請手動修改"
else
    # 備份
    cp /etc/hosts /etc/hosts.bak.$(date +%Y%m%d%H%M%S)
    echo "$HOSTS_ENTRY" >> /etc/hosts
    echo "[OK] 已新增: $HOSTS_ENTRY"
fi

echo ""
echo "========================================"
echo " 全部完成"
echo "========================================"
