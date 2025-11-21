#!/bin/bash

# sipx風險修補-7

# 確認是否禁止所有用戶對這個目錄及其子目錄的訪問

content=$(sed -n '/<Directory \/>/,/<\/Directory>/p' /home/media/apache/conf/httpd.conf)
echo -n "確認是否禁止所有用戶對這個目錄及其子目錄的訪問:"
if echo $content | grep -q "Require all denied" && echo $content | grep -q "AllowOverride none";then
	echo "Yes"
else
	echo "No"
fi

# 確認是否已設定至允許特定ip連線9999 port
echo -n "確認是否已設定僅允許特定ip連線9999 port:"
if sed -n '/<Directory \"\/home\/media\/apache\/htdocs\">/,/<\/Directory>/p' /home/media/apache/conf/httpd.conf | grep -qE "^\s*#.*Require all granted";then
	echo "Yes"
else
	echo "No"
fi

echo "MEDIA 的 TCP Port 9999 弱點風險檢查已完成"
echo "=========================================================="
