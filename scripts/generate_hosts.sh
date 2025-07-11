#!/usr/bin/env bash
set -euo pipefail

# 所有源地址
URLS=(
  "https://raw.githubusercontent.com/Cats-Team/AdRules/main/dns.txt"
  "https://anti-ad.net/adguard.txt"
  "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_53_AWAvenueAdsRule/filter.txt"
  "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_48_HageziMultiPro/filter.txt"
  "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_1_DnsFilter/filter.txt"
  "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/general/filter_59_DnsPopupsFilter/filter.txt"
  "https://raw.githubusercontent.com/AdguardTeam/HostlistsRegistry/refs/heads/main/filters/other/filter_7_SmartTVBlocklist/filter.txt"
)

# 创建临时目录
TMPDIR=$(mktemp -d)
trap "rm -rf $TMPDIR" EXIT

# 下载并合并所有源文件
MERGED="$TMPDIR/merged.txt"
> "$MERGED"
for url in "${URLS[@]}"; do
  echo "Downloading: $url"
  curl -fsSL "$url" | sed '/^\s*#/d;/^\s*$/d;/^!/d' >> "$MERGED"
done

# 去重
sort -u "$MERGED" > "$TMPDIR/cleaned.txt"

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

# 提取域名列表
DOMAINS_FILE="$TMPDIR/domains.txt"
> "$DOMAINS_FILE"
while read -r rule; do
  domain=$(extract_domain "$rule" || true)
  [[ -n "$domain" ]] && echo "$domain" >> "$DOMAINS_FILE"
done < "$TMPDIR/cleaned.txt"

# 去重并排序
sort -u "$DOMAINS_FILE" > "$TMPDIR/final_domains.txt"

# 统计数量
DOMAIN_COUNT=$(wc -l < "$TMPDIR/final_domains.txt")

# 输出 hosts 文件
OUTDIR="output"
mkdir -p "$OUTDIR"
{
  echo "# Merged hosts list generated on $(date -u +'%Y-%m-%dT%H:%M:%SZ') UTC"
  printf "# Sources: %s\n" "${URLS[@]}"
  echo "# Total domains: $DOMAIN_COUNT"
  while read -r domain; do
    echo "0.0.0.0 $domain"
  done < "$TMPDIR/final_domains.txt"
} > "$OUTDIR/hosts.txt"
