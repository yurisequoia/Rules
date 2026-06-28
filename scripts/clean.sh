#!/usr/bin/env bash
# 用法：clean.sh <file>

set -euo pipefail

if [[ $# -ne 1 ]]; then
    echo "用法：clean.sh <file>" >&2
    exit 1
fi

FILE="$1"

awk '
    /^#/                   { next }
    /-ruleset\.skk\.moe$/  { next }
    /^[[:space:]]*$/       { next }
    !seen[$0]++
' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
