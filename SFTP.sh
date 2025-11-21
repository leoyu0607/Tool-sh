#!/usr/bin/bash

# 設定系統日
system_date=$(date +%Y%m%d)
system_time=$(date +%H)
#system_date="20230526"
#system_time="09"
merge_file="/data/ecp/ecp_eap8/jboss/extension/mergeDate.txt"
#cd /data/ecp/ecp_eap8/jboss/RegularTest/20250526/TXT
file_path="/data/ecp/ecp_eap8/jboss/extension/temp/upfile"
cd $file_path

# 取得作業日
operation_date=$(awk -F',' -v t="$system_date" '$1==t {printf $2}' $merge_file | tr -d '\r')

# 設定合併檔案名稱
#merged_filename=Before_"$system_date"0001.txt
#echo "merged_filename : $merged_filename"
#> $merged_filename
#ls |grep ^Before|grep $operation_date  > file_list
#for i in `ls |grep ^Before|grep $operation_date`
#do
#cat $i >> "$merged_filename"
#echo "filename: $i"
#echo "merged_filename : $merged_filename"
#cat $i >> $merged_filename
#done

#設定SFTP檔案名稱(陣列)
if [ -z "$operation_date" ]; then
    echo "No Mapping Date!"
    exit 1
else
    echo "operation_date :$operation_date"
    operation_time="${operation_date}${system_time}"
    echo "operation_time :$operation_time"
    shopt -s nullglob
    sftp_files=(After*$operation_time*.txt Before*$operation_time*.txt)
    shopt -u nullglob
fi

# 傳送至 SFTP（請替換以下帳號與路徑）
sftp_user="lispt_nbcs_w"
sftp_host="10.1.115.1"
PORT=22
sftp_path="/CSCATI/upload/UploadSurvivalInvestigationResult/"
#sftp_path="/CSCATI/download/DownloadSurvivalInvestigationToCSR"

# 使用 sshpass 自動輸入密碼（需先安裝 sshpass）
PASSWORD="eY0nP42H"

if [ ${#sftp_files[@]} -eq 0 ]; then
    echo "No Mapping File!"
    exit 1
else
    echo
    echo "sftp_files :"
    printf "%s\n" "${sftp_files[@]}"
    echo
fi

{
echo "cd $sftp_path"
for f in "${sftp_files[@]}"; do
    new_name="${f/"$operation_time"/"$system_date$system_time"}" # 重新命名檔案
    printf 'put "%s" "%s"\n' "$f" "$new_name"
done
} | sshpass -p $PASSWORD sftp -oKexAlgorithms=+diffie-hellman-group14-sha256,diffie-hellman-group-exchange-sha256 -oStrictHostKeyChecking=accept-new -oBatchMode=no -b - -P $PORT ${sftp_user}@${sftp_host}

# 使用 sftp 傳送檔案
#sshpass -p $PASSWORD sftp ${sftp_user}@${sftp_host}  <<EOF
#put $merged_filename $sftp_path/$merged_filename
#bye
#EOF

if [ $? -ne 0 ]; then
  echo "錯誤：SFTP 傳送失敗"
  exit 1
fi

#echo "成功：檔案 $merged_filename 已傳送至 SFTP $sftp_host:$sftp_path"