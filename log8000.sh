#!/bin/bash
# rec-trigger_v4.sh — Receive event -> call Log8000 Start/Stop

PORT=15383
PREFIX="550"
EXT_NUM="1234"
TIMEOUT_START="3000"
TIMEOUT_STOP="2000"
log8000_ip="10.174.57.109" #10.174.57.109
log8000_port="6901"
API_BASE="https://${log8000_ip}/WebService/Log8000RecSystem.asmx?op="

LOGFILE="./rec.log"
PIDFILE="./rec.pid"
now(){ date +'%F %T.%3N'; }

send_error_notification() {
    local service="$1"
    local errorCode="$2"
    local errorDescription="$3"

    local error_json="{\"service\":\"LOG8000errorMail\",\"errorCode\":\"${errorCode}\",\"errorDescription\":\"${errorDescription}\"}"
    
    curl -sS -X POST "https://ecpdev.taiwanlife.com:12822/ecp/CUS.VoiceBot.doSendErrorMail.data" \
        -H "$ECP_LANG_HEADER" \
        -H "$ECP_CT_HEADER" \
        -H "$ECP_AUTH_HEADER" \
        --connect-timeout 3 --max-time 10 \
        --data-binary "$error_json" \
        --output /dev/null >> "$LOGFILE" 2>&1
}

ECP_UPDATE_API_URL="https://ecpdev.taiwanlife.com:12822/ecp/CUS.VoiceBot.doUpdateOutBoundValue.data"  # 例： "http://192.168.171.31:12841/ecp/CUS.VoiceBot.doUpdateOutBoundValue.data"
ECP_AUTH_HEADER="Authorization: Authorization: Basic YXBpX3R3bGlmZTphcGlfdHdsaWZl"
ECP_LANG_HEADER="Accept-Language: zh-tw"
ECP_CT_HEADER="Content-Type: application/json; charset=UTF-8"

build_get_record_list_xml() {
  local contactId="$1"
  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <GetRecordListByContactID xmlns="http://tempuri.org/">
      <ContactID>${contactId}</ContactID>
    </GetRecordListByContactID>
  </soap:Body>
</soap:Envelope>
EOF
}

call_get_record_list() {
  local contactId="$1"
  local xml
  xml=$(build_get_record_list_xml "$contactId")
  
  local response
  local http_code
  
  response=$(curl -sS -k -X POST "${API_BASE}GetRecordListByContactID" \
    -H "Content-Type: text/xml; charset=utf-8" \
    -H "SOAPAction:http://tempuri.org/GetRecordListByContactID" \
    --connect-timeout 3 --max-time 10 --retry 1 --retry-connrefused \
    --data-binary "$xml" \
    --write-out "\n%{http_code}" \
    2>&1)
  
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  if [ "$http_code" != "200" ]; then
      send_error_notification "LOG8000_GetRecordList" "$http_code" "$body"
  fi
  
  echo "$body"
}
# === SOAP XML 產生 ===
build_xml() {
  local action="$1" ip="$2" port="$3" callId="$4"
  local timeout=$([[ "$action" == "StartRec" ]] && echo "$TIMEOUT_START" || echo "$TIMEOUT_STOP")

  cat <<EOF
<?xml version="1.0" encoding="utf-8"?>
<soap:Envelope xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
               xmlns:xsd="http://www.w3.org/2001/XMLSchema"
               xmlns:soap="http://schemas.xmlsoap.org/soap/envelope/">
  <soap:Body>
    <${action} xmlns="http://tempuri.org/">
      <szExtNum>${EXT_NUM}</szExtNum>
      <szSyncData>empport=${ip}:${port}&amp;VoiceBotId=${callId}</szSyncData>
      <nTimeOut>${timeout}</nTimeOut>
      <IP>${log8000_ip}</IP>
      <Port>${log8000_port}</Port>
    </${action}>
  </soap:Body>
</soap:Envelope>
EOF
}

# === 呼叫 Log8000 API ===
call_log8000() {
  local action="$1" xml="$2" callId="$3"
  echo "[$(now)] Call Log8000 API [$action] CallID=$callId" >> "$LOGFILE"

  local response
  local http_code
  
  response=$(curl -sS -k -X POST "${API_BASE}${action}" \
    -H "Content-Type: text/xml; charset=utf-8" \
    -H "SOAPAction:http://tempuri.org/${action}" \
    --connect-timeout 3 --max-time 10 --retry 1 --retry-connrefused \
    --data-binary "$xml" \
    --write-out "\n%{http_code}" \
    2>&1)
    
  http_code=$(echo "$response" | tail -n1)
  body=$(echo "$response" | sed '$d')
  
  echo "[$(now)][HTTP ${http_code}] $action $callId" >> "$LOGFILE"
  
  if [ "$http_code" != "200" ]; then
      send_error_notification "LOG8000_${action}" "$http_code" "$body"
  fi
}

# === 新增：組 JSON 並呼叫 ECP 回寫 API ===
# 說明：你原本提供的字串（Event=... | CallID=... | ...）我改為**結構化 JSON**
#   {
#     "Event": "...",
#     "CallID": "...",
#     "From": "...",
#     "To": "...",
#     "Dir": "...",
#     "audio": "host:port"
#   }
# 這樣後端更好解析；如果你堅持要單一字串包在某個欄位我也可以幫你微調。
post_update_api() {
  local event="$1" callId="$2" from="$3" to="$4" direction="$5" audioHost="$6" audioPort="$7"

  if [[ -z "$ECP_UPDATE_API_URL" ]]; then
    echo "[$(now)] [ECP-UPDATE] 跳過（未設定 ECP_UPDATE_API_URL） Event=$event CallID=$callId" >> "$LOGFILE"
    return 0
  fi

  # 組 JSON（單行，避免換行）
  local json_payload="{\"event\":\"$event\",\"callId\":\"$callId\",\"from\":\"$from\",\"to\":\"$to\",\"dir\":\"$direction\",\"audio\":\"$audioHost:$audioPort\"}"

  echo "[$(now)] [ECP-UPDATE] POST $ECP_UPDATE_API_URL  CallID=$callId" >> "$LOGFILE"

  stdbuf -oL curl -sS -X POST "$ECP_UPDATE_API_URL" \
    -H "$ECP_LANG_HEADER" \
    -H "$ECP_CT_HEADER" \
    -H "$ECP_AUTH_HEADER" \
    --connect-timeout 3 --max-time 10 --retry 1 --retry-connrefused \
    --data-binary "$json_payload" \
    --write-out "[$(now)][HTTP %{http_code}] ECP-UPDATE $callId\n" \
    --output /dev/null \
    >> "$LOGFILE" 2>&1
}

ECP_RAW_API_URL="https://ecpdev.taiwanlife.com:12822/ecp/CUS.VoiceBot.doInsertPID.data"  # <== 你要回傳的 ECP API，留空就不會呼叫
post_update_api_raw() {
  local raw="$1"
  [[ -z "$ECP_RAW_API_URL" ]] && return 0
  curl -sS -X POST "$ECP_RAW_API_URL" \
    -H "$ECP_LANG_HEADER" \
    -H "$ECP_CT_HEADER" \
    -H "$ECP_AUTH_HEADER" \
    --connect-timeout 3 --max-time 10 --retry 1 --retry-connrefused \
    --data-binary "$raw" \
    --output /dev/null
}


# === 服務管理 ===
service() {
  case "$1" in
    start)
      [[ -f "$PIDFILE" && -s "$PIDFILE" && $(kill -0 $(cat "$PIDFILE") 2>/dev/null) ]] \
        && echo "服務已在執行 (PID: $(cat "$PIDFILE"))" && return
      command -v socat >/dev/null || { echo "請安裝 socat"; exit 1; }
      command -v jq    >/dev/null || { echo "請安裝 jq";    exit 1; }
      command -v curl  >/dev/null || { echo "請安裝 curl";  exit 1; }
      echo "啟動監聽 TCP $PORT"
      nohup socat TCP-LISTEN:$PORT,fork,reuseaddr EXEC:"$(realpath "$0") handler",stderr >> "$LOGFILE" 2>&1 &
      echo $! > "$PIDFILE"
      echo "已啟動 (PID: $(cat "$PIDFILE"))"
      ;;
    stop)
      [[ -f "$PIDFILE" ]] && kill "$(cat "$PIDFILE")" && rm -f "$PIDFILE" && echo "已停止服務" || echo "服務未在執行"
      ;;
    status)
        if [[ -f "$PIDFILE" ]] && kill -0 "$(cat "$PIDFILE")" 2>/dev/null; then
         echo "服務正在執行中 (PID: $(cat "$PIDFILE"))"
        else
         echo "服務未執行"
        fi
      ;;
  esac
}

# === handler：每連線請求 ===
if [[ "$1" == "handler" ]]; then
  # 讀 header，取出 Content-Length
  while IFS=$'\r' read -r line; do
    [[ -z "$line" ]] && break
    [[ "$line" =~ [Cc]ontent-[Ll]ength ]] && content_length=${line##*: }
  done

  body=$(dd bs=1 count="$content_length" 2>/dev/null)
  event=$(jq -r '.event // empty' <<< "$body")
  callId=$(jq -r '.callId // empty' <<< "$body")
  from=$(jq -r '.from // empty' <<< "$body")
  to=$(jq -r '.to // empty' <<< "$body"); to="${to#$PREFIX}"
  direction=$(jq -r '.direction // empty' <<< "$body")
  audioHost=$(jq -r '.audioHost // empty' <<< "$body")
  audioPort=$(jq -r '.audioPort // empty' <<< "$body")
  [[ -z "$audioHost" ]] && audioHost="$log8000_ip"

  echo "[$(now)] 收到Event : Event=$event | CallID=$callId | From=$from -> To=$to | Dir=$direction | audio=${audioHost}:${audioPort}" >> "$LOGFILE"

  case "$event" in
    create)
      xml=$(build_xml "StartRec" "$audioHost" "$audioPort" "$callId")
      call_log8000 "StartRec" "$xml" "$callId"
      # === 新增：同步回寫 ECP
      post_update_api "$event" "$callId" "$from" "$to" "$direction" "$audioHost" "$audioPort"
      ;;
    delete)
      xml=$(build_xml "StopRec" "$audioHost" "$audioPort" "$callId")
      call_log8000 "StopRec" "$xml" "$callId"
      # === 新增：同步回寫 ECP
      post_update_api "$event" "$callId" "$from" "$to" "$direction" "$audioHost" "$audioPort"
      # === 新增：StopRec後呼叫 GetRecordListByContactID 並回傳PID給 ECP
      get_record_response=$(call_get_record_list "$callId")
      PID=$(echo "$get_record_response" | grep -oP '(?<=<PID>).*?(?=</PID>)' | head -n1)
      [[ -n "$PID" ]] && post_update_api_raw "$(echo -n "{\"PID\":\"$PID\",\"callId\":\"$callId\"}" | tr -d '\n')"
      ;;
    *)
      echo "[$(now)][Unknown Event] event=$event" >> "$LOGFILE"
      ;;
  esac
  exit 0
fi

# === 主指令 ===
case "$1" in
  start|stop|status) service "$1" ;;
  *) echo "用法: $0 {start|stop|status}" ;;
esac
