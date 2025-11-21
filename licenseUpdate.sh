#!/bin/bash
#2024/6/4 by LeoYu
read -p "Product Type[ecp]:" product
product=${product:-ecp}
cd /apache-tomcat/extension/$product/config/
#backup
cp license.lic license.lic_bak
cp /home/setup/license.lic ./license.lic
echo "Finfish!"