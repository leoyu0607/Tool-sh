#!/bin/bash

# === 共用設定 ===
PORT=15383
PREFIX="550"
log8000_ip="10.1.244.218"
log8000_port="6901"
API_BASE="https://${log8000_ip}/WebService/Log8000RecSystem.asmx?op="
ECP_UAT_API_BASE="https://ecpuat.taiwanlife.com/ecp/CUS.VoiceBot.iris.data"
LOGFILE="./rec.log"
PIDFILE="./rec.pid"

# === 組 xml body ===
EXT_NUM="1234"
TIMEOUT_START="3000"
TIMEOUT_STOP="2000"

build_startrec_xml() {
    local ip="$1"
    local port="$2"
    cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <StartRec xmlns="http://tempuri.org/">
      <szExtNum>${EXT_NUM}</szExtNum>
      <nCallDirection>2</nCallDirection>
      <szSyncData>empport=${ip}:${port}&amp;</szSyncData>
      <nTimeOut>${TIMEOUT_START}</nTimeOut>
      <IP>${log8000_ip}</IP>
      <Port>${log8000_port}</Port>
    </StartRec>
  </soap:Body>
</soap:Envelope>
EOF
}

build_stoprec_xml() {
    local ip="$1"
    local port="$2"
    cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <StopRec xmlns="http://tempuri.org/">
      <szExtNum>${EXT_NUM}</szExtNum>
      <szSyncData>empport=${ip}:${port}&amp;</szSyncData>
      <nTimeOut>${TIMEOUT_STOP}</nTimeOut>
      <IP>${log8000_ip}</IP>
      <Port>${log8000_port}</Port>
    </StopRec>
  </soap:Body>
</soap:Envelope>
EOF
}

# === 組json body ===

build_json_body() {
  local event="$1"
  local callId="$2"
  local from="$3"
  local to="$4"
  local direction="$5"
  local audioHost="$6"
  local audioPort="$7"
  local RecordPath="$8"

  jq -n \
    --arg event "$event" \
    --arg callId "$callId" \
    --arg from "$from" \
    --arg to "$to" \
    --arg direction "$direction" \
    --arg audioHost "$audioHost" \
    --arg audioPort "$audioPort" \
    --arg RecordPath "$RecordPath" \
    '{
        event: $event,
        callId: $callId,
        from: $from,
        to: $to,
        direction: $direction,
        audioHost: $audioHost,
        audioPort: $audioPort,
        RecordPath: $RecordPath
      }'
}


# === 主流程：啟動監聽 ===
start_service() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "服務已在執行 (PID: $(cat "$PIDFILE"))"
        return
    fi

    command -v socat >/dev/null 2>&1 || {
        echo "請先安裝 socat，例如：sudo dnf install socat"
        exit 1
    }

    command -v jq >/dev/null 2>&1 || {
        echo "請先安裝 jq，例如：sudo dnf install jq"
        exit 1
    }

    echo "啟動 socat 監聽 TCP port $PORT"
    nohup socat TCP-LISTEN:$PORT,fork,reuseaddr,keepalive,linger=1 -T 5 \
    EXEC:"$(realpath "$0") handler",stderr >> "$LOGFILE" 2>&1 &
    echo $! > "$PIDFILE"
    echo "已啟動 (PID: $(cat "$PIDFILE"))"
}

stop_service() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        kill "$(cat "$PIDFILE")"
        rm -f "$PIDFILE"
        echo "已停止服務"
    else
        echo "服務未在執行中"
    fi
}

status_service() {
    if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
        echo "服務正在執行中 (PID: $(cat "$PIDFILE"))"
    else
        echo "服務未執行"
    fi
}

now(){ date +'%F %T.%3N';  }

# === handler：處理每筆請求 ===
# 讀取整個 HTTP 請求
if [[ "$1" == "handler" ]]; then
    now=$(date +'%F %T.%3N')
    echo "[$(now)] 收到EVENT" >> "$LOGFILE"

    header=""
    while IFS=$'\r' read -r line; do
        [[ -z "$line" ]] && break
        header+="$line"$'\n'
    done

    content_length=$(echo "$header" | awk -F ': ' 'BEGIN{IGNORECASE=1} /Content-Length:/ {print $2}')

    if [[ -z "$content_length" || ! "$content_length" =~ ^[0-9]+$ ]]; then
        echo "[$(now)] Content-Length 解析失敗：[$content_length]" >> "$LOGFILE"
        exit 0
    fi

    body=$(dd bs=1 count="$content_length" 2>/dev/null)

    # 擷取欄位
    event=$(jq -r '.event // empty' <<< "$body")
    callId=$(jq -r '.callId // empty' <<< "$body")
    from=$(jq -r '.from // empty' <<< "$body")
    to=$(jq -r '.to // empty' <<< "$body")
    to="${to#$PREFIX}"
    direction=$(jq -r '.direction // empty' <<< "$body")
    audioHost=$(jq -r '.audioHost // empty' <<< "$body")
    audioPort=$(jq -r '.audioPort // empty' <<< "$body")

    echo "[$(now)] Event: $event | From: $from -> To: $to | CallID: $callId | Direction: $direction" >> "$LOGFILE"
    echo "[$(now)] Audio Host: $audioHost | Audio Port: $audioPort" >> "$LOGFILE"

    # 執行對應 API 呼叫
    case "$event" in
        create)
            echo "[$(now)] Call Log8000 API - [Start]" >> "$LOGFILE"
            XMLBody=$(build_startrec_xml "$audioHost" "$audioPort")
            stdbuf -oL curl -sS -k -X POST "${API_BASE}StartRec" \
                -H "Content-Type: text/xml; charset=utf-8" \
                -H "SOAPAction=http://tempuri.org/StartRec" \
                -d "$XMLBody" \
                --write-out "[$(now)][HTTP %{http_code}] $(date +'%F %T') $event $callId\n" \
                --output /dev/null \
                >> "$LOGFILE" 2>&1
        ;;
        delete)
            echo "[$(now)] Call Log8000 API - [Stop]" >> "$LOGFILE"
            XMLBody=$(build_stoprec_xml "$audioHost" "$audioPort")
            stdbuf -oL curl -sS -k -X POST "${API_BASE}StopRec" \
                -H "Content-Type: text/xml; charset=utf-8" \
                -H "SOAPAction=http://tempuri.org/StopRec" \
                -d "$XMLBody" \
                --write-out "[$(now)][HTTP %{http_code}] $(date +'%F %T') $event $callId\n" \
                --output /dev/null \
                >> "$LOGFILE" 2>&1
            RecordPath=$(mysql -u messipx -pmesSIPX1234 -D smp -N -B -e "SELECT srfmsgid FROM cti_callrecord WHERE callid='${callId}' and type = 1 LIMIT 1;")
            echo "[$(now)] Call Edwin API" >> "$LOGFILE"
            JsonBody=$(build_json_body "$event" "$callId" "$from" "$to" "$direction" "$audioHost" "$audioPort" "$RecordPath")
            stdbuf -oL curl -sS -k -X POST "$ECP_UAT_API_BASE" \
                -H "Content-Type: application/json" \
                -H "Authorization: Basic YWRtaW5pc3RyYXRvcjpjc21pMXFhekBXU1g=" \
                -H "Accept-Language: zh-tw" \
                -d "$JsonBody" \
                --write-out "[$(now)][HTTP %{http_code}]" \
                --output /dev/null \
                >> "$LOGFILE" 2>&1
        ;;
        *)
            stdbuf -oL echo "[$(now)][Unknown Event] event=$event" >> "$LOGFILE"
        ;;
    esac
    exit 0
fi

case "$1" in
  start) start_service ;;
  stop) stop_service ;;
  status) status_service ;;
  *)
    echo "用法: $0 {start|stop|status}"
    ;;
esac