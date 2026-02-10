#!/bin/bash

base_dir="/home/ai3/"

scan_dir() {
  local dir="$1"
  local wl="$2"

  if [[ ! -d "$dir" ]]; then
    echo "ERROR: directory not found: $dir"
    return
  fi

  if [[ ! -f "$wl" ]]; then
    echo "ERROR: whitelist not found: $wl"
    return
  fi

  echo "Scanning directory: $dir"
  echo "Using whitelist: $wl"

  while IFS= read -r -d '' file; do
    name="$(basename "$file")"
    if ! grep -Fxq "$name" "$wl"; then
      echo "$file"
      ((TOTAL_BAD++))
    fi
  done < <(find "$dir" -type f -name "*.jar" -print0)

  echo "-----------------------------------"
}

echo "=============================="
echo "請選擇Scan模式："
echo "[1] ECP wiithout BIRT"
echo "[2] ECP with BIRT"
echo "[3] CRM Gateway"
echo "[4] Medeia Proxy"
echo "[5] CBM without BIRT"
echo "[6] CBM with BIRT"
echo "[7] CBE without BIRT"
echo "[8] CBE with BIRT"
read -rp "請輸入選項編號(1-8): " choice
echo "=============================="
case $choice in
  1) 
    service="ecp"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/ecp_no_birt_tomcat.txt"
    webapps_white_list="./white_list/ecp_no_birt_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  2) 
    service="ecp"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/ecp_tomcat.txt"
    webapps_white_list="./white_list/ecp_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  3) 
    service="gateway"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/gateway_tomcat.txt"
    webapps_white_list="./white_list/gateway_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  4) 
    service="mediaproxy"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/mediaproxy_tomcat.txt"
    webapps_white_list="./white_list/mediaproxy_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  5) 
    service="cbm"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/cbm_no_birt_tomcat.txt"
    webapps_white_list="./white_list/cbm_no_birt_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  6) 
    service="cbm"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/cbm_tomcat.txt"
    webapps_white_list="./white_list/cbm_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  7) 
    service="cbe"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/cbe_no_birt_tomcat.txt"
    webapps_white_list="./white_list/cbe_no_birt_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  8) 
    service="cbe"
    tomact_dir="$base_dir/$service/apache-tomcat/lib/"
    webapps_dir="$base_dir/$service/apache-tomcat/webapps/$service/WEB-INF/lib/"
    tomcat_white_list="./white_list/cbe_tomcat.txt"
    webapps_white_list="./white_list/cbe_webapps.txt"
    echo "Tomcat："
    scan_dir "$tomact_dir" "$tomcat_white_list"
    echo "Webapps："
    scan_dir "$webapps_dir" "$webapps_white_list"
    ;;
  *) 
    echo "無效選項，請選擇1到8之間的數字。"
    exit 1
    ;;
esac
