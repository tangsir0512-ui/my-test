#!/usr/bin/env bash
set -euo pipefail

# ==================================================
# 脚本功能：打开固定 JAR 文件，提取固定 XML 文件并输出全部内容
# ==================================================

# 固定 JAR 路径
JAR="/www/wwwroot/marsbot/ruoyi-admin.jar"

# 固定 XML 路径（在 JAR 内部）
XML_PATH="BOOT-INF/classes/application_dev.xml"

# 检查 JAR 是否存在
if [ ! -f "$JAR" ]; then
    echo "[ERROR] Jar file not found: $JAR"
    exit 1
fi

# 检查 XML 文件是否在 JAR 中
if ! unzip -l "$JAR" | awk '{print $4}' | grep -x -- "$XML_PATH" >/dev/null 2>&1; then
    echo "[ERROR] File not found in jar: $XML_PATH"
    echo "Files in jar (partial list):"
    unzip -l "$JAR" | awk '{print $4}' | sed -n '1,200p'
    exit 2
fi

# 提取并输出 XML 内容
unzip -p "$JAR" "$XML_PATH"
