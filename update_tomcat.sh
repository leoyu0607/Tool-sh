#!/bin/bash

##腳本放置於server.sh同層目錄執行;apache-tomcat更新包放置於/tmp下

#備份apache-tomcat
mkdir -p ../backup/
tar --wildcards -czvf ../backup/apache-tomcat_$(date +"%Y%m%d")_bak.tar.gz --exclude=apache-tomcat/logs/* --exclude=apache-tomcat/extension/*/log/* --exclude=apache-tomcat/extension/*/temp/* apache-tomcat/

#解壓縮tomcat包
tar xvf /tmp/apache-tomcat*.tar.gz -C /tmp/

#開始更新
cp -rfp /tmp/apache-tomcat*/bin/ apache-tomcat/
cp -rfp /tmp/apache-tomcat*/lib/ apache-tomcat/
cp -rfp /tmp/apache-tomcat*/BUILDING.txt apache-tomcat/
cp -rfp /tmp/apache-tomcat*/CONTRIBUTING.md apache-tomcat/
cp -rfp /tmp/apache-tomcat*/LICENSE apache-tomcat/
cp -rfp /tmp/apache-tomcat*/NOTICE apache-tomcat/
cp -rfp /tmp/apache-tomcat*/README.md apache-tomcat/
cp -rfp /tmp/apache-tomcat*/RELEASE-NOTES apache-tomcat/
cp -rfp /tmp/apache-tomcat*/RUNNING.txt apache-tomcat/

#移除/tmp下目錄
rm -rf /tmp/apache-tomcat*/

echo
echo

#顯示tomcat版本
export PATH=jre/bin:$PATH
export JAVA_HOME=jre
./apache-tomcat/bin/version.sh 2>/dev/null | grep "Server number"