#!/usr/bin/env bash
set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPTS_DIR="${REPO_DIR}/scripts"
WORK_DIR="${REPO_DIR}/build"
SOURCE_URL="https://github.com/SukkaLab/ruleset.skk.moe/archive/refs/heads/master.zip"
ARCHIVE="master.zip"

# chmod +x "${SCRIPTS_DIR}/clean.sh"
# chmod +x "${SCRIPTS_DIR}/process_wildcard.sh"

# 下载
rm -rf "${REPO_DIR}/loon" "${REPO_DIR}/mihomo"
rm -rf "$WORK_DIR" && mkdir -p "$WORK_DIR"
cd "$WORK_DIR"

echo "[1/8] 下载规则库..."
curl -fsSL "$SOURCE_URL" -o "$ARCHIVE"
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
find surge loon mihomo -type f \( -name "*.conf" -o -name "*.txt" \) | while read -r f; do
    dir="$(dirname "$f")"
    base="$(basename "$f")"
    mv "$f" "${dir}/${base%.*}.raw.list"
done

# 清洗
echo "[4/8] 清洗文件..."
find surge loon mihomo -type f -name "*.raw.list" -exec bash "${SCRIPTS_DIR}/clean.sh" {} \;
find surge loon mihomo -type f -empty -delete

# 转换 loon/domainset
echo "[5/8] 转换 domainset..."
find loon/domainset -type f -name "*.raw.list" | while read -r f; do
    python3 "${SCRIPTS_DIR}/domainset.py" "$f"
    rm -f "$f"
done

# 转换 loon DOMAIN-WILDCARD
echo "[6/8] 转换 DOMAIN-WILDCARD..."
find loon/non_ip -type f -name "*.raw.list" -exec \
    bash "${SCRIPTS_DIR}/process_wildcard.sh" {} "${SCRIPTS_DIR}" \;

# 重命名交付
echo "[7/8] 重命名剩余文件..."
find surge loon mihomo -type f -name "*.raw.list" | while read -r f; do
    mv "$f" "${f/.raw.list/.list}"
done

# 清理
echo "[8/8] 清理并输出目录..."
find "${WORK_DIR}" -type f | grep -vF -f "${REPO_DIR}/keeplist.list" | xargs rm
mv "${WORK_DIR}/loon" "${REPO_DIR}/loon"
mv "${WORK_DIR}/surge" "${REPO_DIR}/surge"
mv "${WORK_DIR}/mihomo" "${REPO_DIR}/mihomo"
rm -rf "$WORK_DIR"

echo "Done -> ${REPO_DIR}/loon, ${REPO_DIR}/surge, ${REPO_DIR}/mihomo"