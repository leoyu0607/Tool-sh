#!/bin/bash

#詢問是否繼續執行的函式
ask_yes_no() {
    local prompt="$1"
    local default="$2"
    local reply

    while true; do
        read -p "$prompt " reply
        reply="${reply,,}"  # 轉小寫

        # 如果使用者沒輸入，使用預設值
        if [ -z "$reply" ] && [ -n "$default" ]; then
            reply="$default"
        fi

        case "$reply" in
            y|yes) return 0 ;;  # 回傳 0 表示同意
            n|no)  return 1 ;;  # 回傳 1 表示否
            *) echo "請輸入 y 或 n。" ;;
        esac
    done
}

#備份ecp
cd /data/ecp/
mkdir -p backup
tar -zcvf backup/ecp_$(date +"%Y%m%d")_bak.tar.gz --exclude=ecp/apache-tomcat/logs/* --exclude=ecp/apache-tomcat/extension/ecp/log/* --exclude=ecp/tool/sql ecp/

#取出datasource的DB連線資訊
cd /data/ecp/ecp/apache-tomcat/extension/ecp/config
db_url=$(xmllint --xpath "string(//url)" datasource.xml
)#echo "url = $url"
if [[ $db_url =~ jdbc:[^/]+//([^:/]+):([0-9]+)/([^?]+) ]]; then
	db_ip="${BASH_REMATCH[1]}"
	db_port="${BASH_REMATCH[2]}"
	db_name="${BASH_REMATCH[3]}"
fi
#echo -e "DB IP = $db_ip \nDB port = $db_port \nDB name = $db_name"

#修改driver為新版mssql driver
sed -i 's|<driver-class>.*</driver-class>|<driver-class>com.microsoft.sqlserver.jdbc.SQLServerDriver</driver-class>|' datasource.xml
sed -i "s|<url>.*</url>|<url>jdbc:sqlserver://$db_ip:$db_port;DatabaseName=$db_name;encrypt=true;trustServerCertificate=true;</url>|" datasource.xml
#sed -i 's|<driver-class>.*</driver-class>|<driver-class>org.mariadb.jdbc.Driver</driver-class>|' datasource.xml
#sed -i "s|<url>.*</url>|<url>jdbc:mariadb://$db_ip:$db_port/$db_name;encrypt=true;trustServerCertificate=true;</url>|" datasource.xml

#解壓縮ecp 8.5.0.3.02升級包並執行升級
cd /data/ecp/jboss_setup
tar xvf ecp-linux-8.5.03.*.tar.gz
./ecp-linux-8.5.03*/upgrade.sh <<EOF
y
/data/ecp/ecp
y
A
y
EOF

#解壓縮並放置公版ECP(JBOSS)
if ask_yes_no "是否繼續部屬JBOSS版ECP？[y/n]" "y"; then
	echo "開始部屬JBOSS版ECP..."
else
	echo "取消部屬"
	exit 0
fi
cd /data/ecp/jboss_setup
tar xvf ecp_eap8_20250428_bak.tar.gz -C /data/ecp/
cp ecp.war /data/ecp/ecp_eap8/jboss/standalone/deployments/ecp.war

#更換extension目錄
cd /data/ecp/ecp_eap8/jboss
mv extension extension_eap8_bak
cp -rfp /data/ecp/ecp/apache-tomcat/extension ./

#台壽自己的服務有占用9990 port，要改成9991 port
cd standalone/configuration/
sed -i 's|9990|9991|' standalone-tmp.xml
