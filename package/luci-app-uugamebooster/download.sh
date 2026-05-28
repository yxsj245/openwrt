#!/bin/sh
API_URL="https://router.uu.163.com/api/plugin?type=openwrt-x86_64"
OUTPUT_DIR="$1"

if [ -z "$OUTPUT_DIR" ]; then
    echo "Usage: $0 <output_directory>"
    exit 1
fi

mkdir -p "$OUTPUT_DIR"

echo "正在获取UU加速器最新版本信息..."
UU_API=$(curl -s "$API_URL")
UU_URL=$(echo "$UU_API" | sed 's/.*"url":"//;s/".*//')

if [ -z "$UU_URL" ]; then
    echo "无法获取UU加速器下载链接"
    exit 1
fi

echo "下载链接: $UU_URL"
curl -L --connect-timeout 30 --max-time 120 -o "$OUTPUT_DIR/uu.tar.gz" "$UU_URL"
if [ $? -ne 0 ]; then
    echo "下载UU加速器失败"
    exit 1
fi

tar xzf "$OUTPUT_DIR/uu.tar.gz" -C "$OUTPUT_DIR/"
echo "UU加速器下载解压完成"
