#!/usr/bin/env bash
# 用法：process_wildcard.sh <file> <scripts_dir>
# 原地处理：
#   1. 提取 DOMAIN-WILDCARD, 开头的行，去掉前缀后写入临时 raw.list
#   2. 用 w2l.py 转换成 .list
#   3. 将原文件中的 DOMAIN-WILDCARD 行替换为转换结果，去重
#   4. 写入同名 .list，删除 .raw.list

set -euo pipefail

if [[ $# -ne 2 ]]; then
    echo "用法：process_wildcard.sh <file> <scripts_dir>" >&2
    exit 1
fi

FILE="$1"
SCRIPTS_DIR="$2"
TMPDIR_LOCAL="$(mktemp -d)"
trap 'rm -rf "$TMPDIR_LOCAL"' EXIT

RAW_TMP="${TMPDIR_LOCAL}/wildcard.raw.list"
PROCEED_TMP="${TMPDIR_LOCAL}/wildcard.list"

# 1. 提取 DOMAIN-WILDCARD 行，去掉 "DOMAIN-WILDCARD," 前缀
grep '^DOMAIN-WILDCARD,' "$FILE" \
    | sed 's/^DOMAIN-WILDCARD,//' \
    > "$RAW_TMP" || true   # 没有匹配行时 grep 返回 1，允许继续

# 确定最终输出路径（.raw.list → .list）
OUTPUT_FILE="${FILE/.raw.list/.list}"

if [[ ! -s "$RAW_TMP" ]]; then
    # 没有 DOMAIN-WILDCARD 行，直接去重写出 .list，删除 .raw.list
    awk '!/^[[:space:]]*$/ && !seen[$0]++' "$FILE" > "$OUTPUT_FILE"
    rm -f "$FILE"
    exit 0
fi

# 2. 转换通配符规则；w2l.py 输出到同目录的 wildcard.list
python3 "${SCRIPTS_DIR}/w2l.py" "$RAW_TMP"

# 3. 合并：原文件去掉 DOMAIN-WILDCARD 行 + 转换结果，整体去重，写入 .list
{
    grep -v '^DOMAIN-WILDCARD,' "$FILE" || true
    cat "$PROCEED_TMP"
} | awk '
    /^[[:space:]]*$/ { next }
    !seen[$0]++
' > "$OUTPUT_FILE"

# 4. 删除 .raw.list
rm -f "$FILE"