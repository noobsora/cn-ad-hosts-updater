#!/usr/bin/env bash
set -euo pipefail

# 源订阅地址
URL1="https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt"
URL2="https://anti-ad.net/adguard.txt"

# 临时下载目录
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# 下载两个列表
curl -fsSL "$URL1" -o "$TMPDIR/list1.txt"
curl -fsSL "$URL2" -o "$TMPDIR/list2.txt"

# 合并、去重、过滤注释与空行
cat "$TMPDIR/list1.txt" "$TMPDIR/list2.txt" \
  | sed '/^\s*#/d;/^\s*$/d' \
  | sed 's/^\*\.?//g' \
  | sort -u \
  > "$TMPDIR/merged.txt"

# 生成 hosts 格式
OUTDIR="output"
mkdir -p "$OUTDIR"
{
  echo "# Merged hosts list generated on $(date -u +'%Y-%m-%dT%H:%M:%SZ') UTC"
  echo "# Sources: $URL1 , $URL2"
  while read -r domain; do
    echo "0.0.0.0 $domain"
  done < "$TMPDIR/merged.txt"
} > "$OUTDIR/hosts.txt"
