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

# 合并、去重：剔除注释与空行
cat "$TMPDIR/list1.txt" "$TMPDIR/list2.txt" \
  | sed '/^\s*#/d;/^\s*$/d' \
  | sed '/^!/d' \
  | sort -u \
  > "$TMPDIR/merged.txt"

# 提取域名规则
extract_domain() {
  local line="$1"
  if [[ "$line" =~ ^\|\|([^\^]+)\^ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^@@\|\|([^\^]+)\^ ]]; then
    echo "${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^\*\.(.+) ]]; then
    echo "*.${BASH_REMATCH[1]}"
  elif [[ "$line" =~ ^([A-Za-z0-9.-]+)$ ]]; then
    echo "${BASH_REMATCH[1]}"
  fi
}

# 生成纯域名列表
DOMAINS_FILE="$TMPDIR/domains.txt"
> "$DOMAINS_FILE"
while read -r rule; do
  domain=$(extract_domain "$rule" || true)
  [[ -n "$domain" ]] && echo "$domain" >> "$DOMAINS_FILE"
done < "$TMPDIR/merged.txt"

# 最终去重排序
sort -u "$DOMAINS_FILE" > "$TMPDIR/final_domains.txt"

# 输出 hosts 格式
OUTDIR="output"
mkdir -p "$OUTDIR"
{
  echo "# Merged hosts list generated on $(date -u +'%Y-%m-%dT%H:%M:%SZ') UTC"
  echo "# Sources: $URL1 , $URL2"
  while read -r domain; do
    echo "0.0.0.0 $domain"
  done < "$TMPDIR/final_domains.txt"
} > "$OUTDIR/hosts.txt"
