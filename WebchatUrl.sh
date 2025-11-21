#!/bin/bash
#2024/6/4 by LeoYu
read -p "Gateway Server[127.0.0.1]:" gwurl
gwurl=${gwurl:-127.0.0.1}
read -p "Gateway Port[12621]:" port
port=${port:-12621}
read -p "WebChat Name[webchat]:" name
name=${name:-webchat}
read -p "Tenant Code[84459043-01]:" tenantCode
tenantCode=${tenantCode:-84459043-01}
#cd dir
cd apache-tomcat/webapps/gateway/$name/common
pwd
#Config.js
sed -i "s|CRMGatewayUrl: .*/gateway/\",|CRMGatewayUrl: \"http://$gwurl:$port/gateway/\",|" Config.js
sed -i "s|WebChatUrl: .*/gateway/.*/\",|WebChatUrl: \"http://$gwurl:$port/gateway/webchat/\",|" Config.js
sed -i "s|gateway/webchat\",|gateway/$name\",|" Config.js
sed -i "s|12621/gateway|$port/gateway|g" Config.js
sed -i "s|tenantCode: \".*\"|tenantCode: \"$tenantCode\"|" Config.js

echo -e "\n"