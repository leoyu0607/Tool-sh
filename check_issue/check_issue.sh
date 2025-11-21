#/bin/bash


## check apache version
echo "check apache version start"
acdweb_apache=$(su - acdweb -c ' httpd -v | grep "Server version" | awk "{print $3}" | cut -d"/" -f2 ')
media_apache=$(su - media -c ' httpd -v | grep "Server version" | awk "{print $3}" | cut -d"/" -f2 ')

echo "acdweb apache version : " $acdweb_apache
echo "media apache version : " $media_apache

echo "check apache version completed"
echo "=========================================================="

## check apache TRACE off
echo "check acdweb apache TRACD status"
acdweb_Trace=$(curl -s -X TRACE http://127.0.0.1:14900 | grep "TRACE\|is not allowed for this URL" )
if [[ "$acdweb_Trace" == *"The requested method TRACE is not allowed for this URL"* ]]; then
	    echo "acdweb apache TRACE check is OK"
    else
	        echo "acdweb apache: configuration needs to add TraceEnable off"
	fi

echo "check media apache TRACD status"
media_Trace=$(curl -s -X TRACE http://127.0.0.1:9999 | grep "TRACE\|is not allowed for this URL" )
if [[ "$media_Trace" == *"The requested method TRACE is not allowed for this URL"* ]]; then
	    echo "media apache TRACE check is ok"
    else
	        echo "media apache: configuration needs to add TraceEnable off"
	fi

echo "check media apache TRACD completed"
echo "=========================================================="

## Check  TLS supports lower versions
echo "check TLS supports lower versions start "
## 定義需檢查的tls版本
tls_versions=( "tls1" "tls1_1" "tls1_2" "tls1_3")
## 定義需檢查的port
ports=(5049)
# 輸入IP地址
read -p "請輸入SIPX IP地址: " ip_address

for port in "${ports[@]}"; do
	echo "檢查 IP $ip_address 的端口 $port 是否支持 TLS 版本..."
	for tls in "${tls_versions[@]}"; do
		echo -n "  檢查 $tls: "
		output=$(openssl s_client -connect "$ip_address:$port" -"$tls" < /dev/null 2>&1)
	
	# 檢查 Cipher 是否支援
	if echo "$output" | grep -q "Cipher    : 0000"; then
		echo "不支持"          
	else
		echo "支持"
		# 擷取相關 SSL 參數
		echo "    擷取 SSL 參數..."
		# 擷取 Cipher
		cipher=$(echo "$output" | grep "Cipher is" | awk -F'Cipher is ' '{ print $2 }')
		# 擷取 Key Length
		key_length=$(echo "$output" | grep -i "public key is" | awk -F'public key is ' '{ print $2}')
		# 擷取憑證信息
		cert_pem=$(echo "$output" | sed -n '/-----BEGIN CERTIFICATE-----/,/-----END CERTIFICATE-----/p')
		cert_subject=$(echo "$cert_pem" | openssl x509 -noout -subject)
	
		if [ -z "$cipher" ]; then
			cipher="N/A"
		fi
		
		# 如果 Key Length 沒有值，顯示 "N/A"
		if [ -z "$key_length" ]; then
			key_length="N/A"
		fi
		echo "      Cipher: $cipher"
		echo "      Key Length: ${key_length:-N/A}"  # 如果找不到密鑰長度，顯示 N/A
		echo "      憑證 Subject: $cert_subject"
	fi
	done
done
echo "check TLS supports lower versions completed "
echo "=========================================================="

## 
