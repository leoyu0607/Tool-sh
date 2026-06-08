#!/bin/bash
#
# gen_selfsign_cert.sh
# 產生 ai3.cloud 自簽憑證（含 SAN）
#
# Usage: ./gen_selfsign_cert.sh

set -euo pipefail

DOMAIN="ai3.cloud"
DAYS=3650                # 10 年效期
OUT_DIR="./certs"
KEY_FILE="${OUT_DIR}/${DOMAIN}.key"
CSR_FILE="${OUT_DIR}/${DOMAIN}.csr"
CRT_FILE="${OUT_DIR}/${DOMAIN}.crt"
KEY_SIZE=4096

mkdir -p "$OUT_DIR"

echo "========================================"
echo " 產生自簽憑證: ${DOMAIN}"
echo "========================================"

# ===== 建立 OpenSSL 設定檔（含 SAN）=====
OPENSSL_CNF=$(mktemp /tmp/openssl_XXXXXX.cnf)
cat > "$OPENSSL_CNF" <<EOF
[req]
default_bits       = ${KEY_SIZE}
prompt             = no
default_md         = sha256
distinguished_name = dn
x509_extensions    = v3_ext
req_extensions     = v3_ext

[dn]
C  = TW
ST = Taiwan
L  = Taipei
O  = ai3 co.
OU = IT
CN = ${DOMAIN}

[v3_ext]
basicConstraints       = CA:FALSE
keyUsage               = digitalSignature, keyEncipherment
extendedKeyUsage       = serverAuth, clientAuth
subjectAltName         = @alt_names
subjectKeyIdentifier   = hash
authorityKeyIdentifier = keyid,issuer

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF

# ===== 產生私鑰 =====
echo ""
echo "[1/3] 產生 RSA ${KEY_SIZE}-bit 私鑰..."
openssl genrsa -out "$KEY_FILE" "$KEY_SIZE" 2>/dev/null
echo "  -> ${KEY_FILE}"

# ===== 產生自簽憑證 =====
echo ""
echo "[2/3] 產生自簽憑證 (效期 ${DAYS} 天)..."
openssl req -new -x509 \
    -key "$KEY_FILE" \
    -out "$CRT_FILE" \
    -days "$DAYS" \
    -config "$OPENSSL_CNF"
echo "  -> ${CRT_FILE}"

# ===== 驗證憑證內容 =====
echo ""
echo "[3/3] 憑證資訊："
echo "----------------------------------------"
openssl x509 -in "$CRT_FILE" -noout \
    -subject -issuer -dates -ext subjectAltName
echo "----------------------------------------"

# 清理暫存
rm -f "$OPENSSL_CNF"

echo ""
echo "產出檔案："
echo "  私鑰: ${KEY_FILE}"
echo "  憑證: ${CRT_FILE}"
echo ""
echo "搭配前一支腳本匯入 Java cacerts 範例："
echo "  sudo ./import_cert.sh \\"
echo "    -c ${CRT_FILE} \\"
echo "    -k /usr/lib/jvm/java-1.8.0/jre/lib/security/cacerts \\"
echo "    -a ${DOMAIN} \\"
echo "    -u appuser \\"
echo "    -h \"10.0.0.5 ${DOMAIN}\""
