#!/bin/bash
# export_all_images.sh

OUTPUT_DIR="./docker_images"
mkdir -p "$OUTPUT_DIR"

docker images --format "{{.Repository}}:{{.Tag}}" | grep -v "<none>" | while read image; do
    # 將 / 和 : 替換為 _ 作為檔名
    filename=$(echo "$image" | tr '/:' '__')
    echo "匯出: $image -> ${filename}.tar"
    docker save -o "${OUTPUT_DIR}/${filename}.tar" "$image"
done

echo "完成！所有 image 已匯出至 $OUTPUT_DIR"
