#!/usr/bin/env python3
"""
用法：python3 domainset.py file.raw.list
输出：file.proceed.list（同目录）

转换规则：
  .example.com  → DOMAIN-SUFFIX,example.com
  example.com   → DOMAIN,example.com
去重，保持首次出现顺序
"""

import sys
from pathlib import Path


def convert_line(raw: str) -> str | None:
    line = raw.strip()
    if not line or line.startswith("#"):
        return None
    if line.startswith("."):
        return f"DOMAIN-SUFFIX,{line[1:]}"
    return f"DOMAIN,{line}"


def main():
    if len(sys.argv) != 2:
        print("用法：python3 domainset.py file.raw.list")
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