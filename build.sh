#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
WORK_DIR="${REPO_DIR}/build"
SOURCE_URL="https://github.com/SukkaLab/ruleset.skk.moe/archive/refs/heads/master.zip"
FALLBACK_URL="https://gitlab.com/SukkaW/ruleset.skk.moe/-/archive/master/ruleset.skk.moe-master.zip"
ARCHIVE="master.zip"

cleanup() {
    status=$?
    trap - EXIT
    cd "$REPO_DIR" || exit "$status"
    rm -rf -- "$WORK_DIR" || true
    exit "$status"
}
trap cleanup EXIT

# 下载
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[1/8] 下载规则库..."
if ! curl -fsSL "$SOURCE_URL" -o "$ARCHIVE"; then
    echo "主地址下载失败，尝试备用地址..."
    if ! curl -fsSL "$FALLBACK_URL" -o "$ARCHIVE"; then
        echo "备用地址下载失败，退出。" >&2
        rm -f "$ARCHIVE"
        exit 1
    fi
fi
unzip -q "$ARCHIVE"

EXTRACT_DIR="ruleset.skk.moe-master"
mv "${EXTRACT_DIR}/List" .
mv "${EXTRACT_DIR}/Clash" .
rm -f "$ARCHIVE"
rm -rf "$EXTRACT_DIR"

# 目录整理
echo "[2/8] 整理目录结构..."
cp -r List surge
mv List loon
mv Clash mihomo

# 文件重命名
echo "[3/8] 重命名文件..."
find surge loon mihomo -type f \( -name "*.conf" -o -name "*.txt" \) -print0 | while IFS= read -r -d '' f; do
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    mv "$f" "${dir}/${base%.*}.raw.list"
done

# 清洗
echo "[4/8] 清洗文件..."
cat "${REPO_DIR}/keeplist.list" > "${WORK_DIR}/keeplist.list"
find surge loon mihomo -type f -print0 | while IFS= read -r -d '' f; do
    if grep -F -f "${WORK_DIR}/keeplist.list" <<< "${f##*/}" > /dev/null; then
        continue
    else
        status=$?
        if [[ "$status" -ne 1 ]]; then
            exit "$status"
        fi
    fi
    rm -- "$f"
done
rm -- "${WORK_DIR}/keeplist.list"
find surge loon mihomo -type f -name "*.raw.list" -print0 | while IFS= read -r -d '' f; do
    bash "${SCRIPTS_DIR}/clean.sh" "$f"
done
find surge loon mihomo -type f -empty -delete
find surge loon mihomo -type f -name "my_*" -delete

# 转换 loon/domainset
echo "[5/8] 转换 domainset..."
find loon/domainset -type f -name "*.raw.list" -print0 | while IFS= read -r -d '' f; do
    python3 "${SCRIPTS_DIR}/domainset.py" "$f"
    rm -f "$f"
done

# 转换 loon DOMAIN-WILDCARD
echo "[6/8] 转换 DOMAIN-WILDCARD..."
find loon/non_ip -type f -name "*.raw.list" -print0 | while IFS= read -r -d '' f; do
    bash "${SCRIPTS_DIR}/process_wildcard.sh" "$f" "${SCRIPTS_DIR}"
done

# 重命名交付
echo "[7/8] 重命名剩余文件..."
find surge loon mihomo -type f -name "*.raw.list" -print0 | while IFS= read -r -d '' f; do
    mv "$f" "${f%.raw.list}.list"
done

# 在写入统计信息前确认每个目录都有非空产物。
for output in loon surge mihomo; do
    if [[ ! -d "$output" ]] || [[ -z "$(find "$output" -type f -name '*.list' ! -empty -printf x)" ]]; then
        echo "错误：${output} 缺少非空规则产物。" >&2
        exit 1
    fi
done

# 增加生成时间与计数
TIMESTAMP="$(env TZ=Asia/Shanghai date '+%Y-%m-%d %H:%M:%S %Z')"
find "${WORK_DIR}" -type f -name "*.list" -print0 | while IFS= read -r -d '' f; do
    line_count="$(grep -c '' "$f")"
    sed -i "1i # Last Update: ${TIMESTAMP}\n# Total Rules: ${line_count}" "$f"
done

# 清理
echo "[8/8] 清理并输出目录..."
cd "$REPO_DIR"
rm -rf -- "${REPO_DIR}/loon" "${REPO_DIR}/surge" "${REPO_DIR}/mihomo"
mv "${WORK_DIR}/loon" "${REPO_DIR}/loon"
mv "${WORK_DIR}/surge" "${REPO_DIR}/surge"
mv "${WORK_DIR}/mihomo" "${REPO_DIR}/mihomo"

echo "Done -> ${REPO_DIR}/loon, ${REPO_DIR}/surge, ${REPO_DIR}/mihomo"
