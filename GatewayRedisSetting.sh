#!/bin/bash
# 2024/6/3 by LeoYu
read -p "Redis Server[127.0.0.1]:" redisIP
redisIP=${redisIP:-127.0.0.1}
read -s -p "Redis Password:" pass
password=$(printf '%s\n' "$pass" | sed 's/[&/\]/\\&/g')
cd apache-tomcat/extension/gateway/config
# application.properties
sed -i 's|cluster.enabled = false|cluster.enabled = true|' application.properties
sed -i 's|cluster.node.name = node1|cluster.node.name = gw_node1|' application.properties
sed -i 's|cache.provider.class = com.jeedsoft.common.advanced.cache.infinispan.InfinispanCacheProvider|cache.provider.class = com.jeedsoft.common.advanced.cache.redis.RedisCacheProvider|' application.properties
sed -i 's|cache.config.file = cache-infinispan.xml|cache.config.file = cache-redis.xml|' application.properties
sed -i 's|# redis.config.file = redis.xml|redis.config.file = redis.xml|' application.properties
# cache-redis.xml
sed -i "s|<server host=\"127.0.0.1\"|<server host=\"$redisIP\"|" cache-redis.xml
sed -i "s|<password></password>|<password>$password</password>|" cache-redis.xml
sed -i 's|<database>11</database>|<database>8</database>|' cache-redis.xml
# redis.xml
sed -i "s|<server host=\"127.0.0.1\"|<server host=\"$redisIP\"|" redis.xml
sed -i "s|<password></password>|<password>$password</password>|" redis.xml
sed -i 's|<database>12</database>|<database>9</database>|' redis.xml
# gateway.xml
cd ../../../conf/Catalina/localhost/
cp context-example.txt gateway.xml
sed -i "s|redisServer=\"127.0.0.1:6379\"|redisServer=\"$redisIP:6379\"|" gateway.xml
sed -i "s|redisPassword=\"\"|redisPassword=\"$password\"|" gateway.xml
sed -i 's|redisDatabase="10"|redisDatabase="7"|' gateway.xml

echo -e "\n"