#!/bin/bash

PORT=15383
API_URL_BASE="http://your.api/handle"
PREFIX=550

echo "Listening on port $PORT..."
echo

nc -ltk $PORT | {
    while true; do
        header=""
        content_length=0

        # 收集 HTTP header
        while IFS= read -r line; do
            line=${line//$'\r'/}
            [[ -z "$line" ]] && break
            header+="$line"$'\n'
        done

        # 直接從 header 變數中擷取 content-length（避免 grep + awk）
        while read -r hline; do
            if [[ "${hline,,}" == content-length:* ]]; then
		content_length="${hline##*: }"
		break
	    fi
        done <<< "$header"

        # 若沒 content-length 就跳過
        [[ -z "$content_length" || "$content_length" -le 0 ]] && continue

        # 精確讀取 body
        body=$(dd bs=1 count="$content_length" 2>/dev/null)

        # 提取 JSON 欄位（改用 Bash 參數展開）
        event="${body#*\"event\":\"}"
        event="${event%%\"*}"

        callId="${body#*\"callId\":\"}"
        callId="${callId%%\"*}"

        from="${body#*\"from\":\"}"
        from="${from%%\"*}"

        to="${body#*\"to\":\"}"
        to="${to%%\"*}"
        to="${to#$PREFIX}"  # 移除開頭的 550

        direction="${body#*\"direction\":\"}"
        direction="${direction%%\"*}"

        audioHost="${body#*\"audioHost\":\"}"
        audioHost="${audioHost%%\"*}"

        audioPort="${body#*\"audioPort\":\"}"
        audioPort="${audioPort%%\"*}"

        echo "Event: $event | From: $from -> To: $to | CallID: $callId"
	echo

        # 根據事件呼叫 API
        case "$event" in
            create)
                curl -sS -X POST "$API_URL_BASE/create/$callId" \
                    -H "Content-Type: application/json" \
                    -d "$body" &
                ;;
            delete)
                curl -sS -X POST "$API_URL_BASE/delete/$callId" \
                    -H "Content-Type: application/json" \
                    -d "$body" &
                ;;
            *)
                echo "Unknown event: $event"
                ;;
        esac
    done
}
