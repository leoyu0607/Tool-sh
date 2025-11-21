#!/bin/bash

# sipx風險修補-6
# 定義一個包含要檢查的port號的列表
PORTS=(5067 5069)

# 檢查每個port
for PORT in "${PORTS[@]}"; do
    # 使用 `netstat` 檢查端口是否在使用
    if netstat -tuln | grep -q ":$PORT "; then
        echo "Port $PORT is in use."
    else
        echo "Port $PORT is not in use."
    fi
done

echo "check ACD 5067,5069 port completed"
echo "=========================================================="
