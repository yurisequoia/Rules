#!/usr/bin/env python3
"""
用法：python3 w2l.py file.raw.list
输出：file.proceed.list（同目录）

转换规则：
  *  匹配任意字符，作为分隔符提取两侧关键词
  ?  匹配单个字符，作为分隔符提取两侧关键词
  尾部连续纯字面量段 → DOMAIN-SUFFIX
  中间字面量片段    → DOMAIN-KEYWORD

特殊处理：
  suffix 仅为单段常见 TLD 且已有其他条件时丢弃
  去重，保持首次出现顺序

输出格式：
  单条件：DOMAIN-SUFFIX,example.com
  多条件：AND((DOMAIN-KEYWORD,foo),(DOMAIN-SUFFIX,example.com))
"""

import re
import sys
from pathlib import Path

COMMON_TLDS = {
    "com", "net", "org", "io", "co", "cn", "edu", "gov", "mil",
    "int", "info", "biz", "me", "tv", "app", "dev", "ai", "uk",
    "us", "jp", "de", "fr", "ru", "br", "au", "ca", "in", "kr",
}


def convert_line(raw: str) -> str | None:
    line = raw.strip()
    if not line or line.startswith("#"):
        return None

    parts = line.split(".")

    # 从右往左找尾部纯字面量段 → DOMAIN-SUFFIX
    suffix_parts: list[str] = []
    i = len(parts) - 1
    while i >= 0 and not re.search(r"[*?]", parts[i]):
        suffix_parts.insert(0, parts[i])
        i -= 1
    prefix_parts = parts[: i + 1]

    conditions: list[str] = []

    # 前缀以 *? 为分隔符，提取字面量关键词
    if prefix_parts:
        for chunk in re.split(r"[*?]+", ".".join(prefix_parts)):
            keyword = chunk.strip(".").replace(".", "")
            if keyword:
                conditions.append(f"DOMAIN-KEYWORD,{keyword}")

    # suffix 仅为单段常见 TLD 且已有其他条件时丢弃
    if suffix_parts:
        suffix_str = ".".join(suffix_parts)
        if not (len(suffix_parts) == 1 and suffix_parts[0].lower() in COMMON_TLDS and conditions):
            conditions.append(f"DOMAIN-SUFFIX,{suffix_str}")

    if not conditions:
        return None
    if len(conditions) == 1:
        return conditions[0]
    return "AND(" + ",".join(f"({c})" for c in conditions) + ")"


def main():
    if len(sys.argv) != 2:
        print("用法：python3 w2l.py file.raw.list")
        sys.exit(1)

    input_path = Path(sys.argv[1])
    if not input_path.exists():
        print(f"错误：找不到文件 {input_path}", file=sys.stderr)
        sys.exit(1)

    output_path = input_path.with_name(input_path.name.replace(".raw.list", ".list"))

    seen: set[str] = set()
    results: list[str] = []
    for line in input_path.read_text(encoding="utf-8").splitlines():
        result = convert_line(line)
        if result and result not in seen:
            seen.add(result)
            results.append(result)

    output_path.write_text("\n".join(results) + "\n", encoding="utf-8")
    print(f"完成：{len(results)} 条规则 → {output_path}")


if __name__ == "__main__":
    main()