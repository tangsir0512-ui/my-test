#!/usr/bin/env bash
set -euo pipefail

# ==================== MySQL 配置 ====================
MYSQL_USER="hongjiu"
MYSQL_PASS="hongjiu"
MYSQL_HOST="127.0.0.1"
MYSQL_PORT="3306"
MYSQL_BIN="/www/server/mysql/bin/mysql"   # 宝塔 MySQL 路径

# ==================== SQL 语句 ====================
# 在这里写你想执行的多条 SQL，每条语句以 ; 结尾
SQL_STATEMENTS=$(cat <<'EOF'
use hongjiu;
SELECT * FROM sys_user;
UPDATE sys_user SET user_name = 'gunshi_admin' WHERE id=3;
EOF
)

# ==================== 执行 SQL ====================
echo "[*] Executing SQL statements..."
$MYSQL_BIN -u"$MYSQL_USER" -p"$MYSQL_PASS" -h"$MYSQL_HOST" -P"$MYSQL_PORT" -e "$SQL_STATEMENTS"

echo "[*] Done."
