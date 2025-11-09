#!/usr/bin/env bash
set -euo pipefail

# 宝塔 MySQL 自动创建 root1 用户脚本（skip-grant-tables 模式）
# 适用于宝塔 MySQL 安装路径 /www/server/mysql

TMPDIR="/tmp/mysql_add_admin_bt_$$"
mkdir -p "$TMPDIR"

NEW_USER="root1"
NEW_PWD="root1"

echo "[*] This script will stop Baota MySQL, start it with --skip-grant-tables, create user '${NEW_USER}', then restart MySQL."

# 宝塔 MySQL 安装路径
MYSQL_HOME="/www/server/mysql"
MYSQL_DATA="${MYSQL_HOME}/data"
MYSQL_BIN="${MYSQL_HOME}/bin"

# 检查 mysqld_safe 是否存在
if [ ! -f "${MYSQL_BIN}/mysqld_safe" ]; then
    echo "[ERROR] Cannot find mysqld_safe in ${MYSQL_BIN}"
    exit 1
fi

# 停止宝塔 MySQL 服务
echo "[*] Stopping Baota MySQL service..."
if systemctl list-units --type=service | grep -q "bt_mysql"; then
    systemctl stop bt_mysql
else
    /etc/init.d/bt_mysql stop || true
fi
sleep 1
pkill -9 mysqld || true

# 启动临时 MySQL（跳过授权表）
echo "[*] Starting temporary mysqld with --skip-grant-tables ..."
nohup "${MYSQL_BIN}/mysqld_safe" --datadir="${MYSQL_DATA}" --skip-grant-tables --skip-networking > "${TMPDIR}/mysqld_safe.log" 2>&1 &

# 等待 mysqld 启动
SECS=0
until "${MYSQL_BIN}/mysqladmin" ping >/dev/null 2>&1 || [ $SECS -ge 30 ]; do
    sleep 1
    SECS=$((SECS+1))
done

if ! "${MYSQL_BIN}/mysqladmin" ping >/dev/null 2>&1; then
    echo "[ERROR] Temporary mysqld did not start. Check logs in ${TMPDIR}"
    exit 1
fi
echo "[*] Temporary mysqld running."

# 创建 SQL 文件
SQLFILE="${TMPDIR}/add_admin.sql"
cat > "$SQLFILE" <<SQL
CREATE USER IF NOT EXISTS '${NEW_USER}'@'localhost' IDENTIFIED BY '${NEW_PWD}';
CREATE USER IF NOT EXISTS '${NEW_USER}'@'%' IDENTIFIED BY '${NEW_PWD}';
GRANT ALL PRIVILEGES ON *.* TO '${NEW_USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '${NEW_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

# 执行 SQL
"${MYSQL_BIN}/mysql" < "$SQLFILE"

# 停止临时 mysqld
pkill -f 'skip-grant-tables' || pkill mysqld || true
sleep 1

# 重启宝塔 MySQL 服务
echo "[*] Starting Baota MySQL service normally..."
if systemctl list-units --type=service | grep -q "bt_mysql"; then
    systemctl start bt_mysql
else
    /etc/init.d/bt_mysql start || true
fi
sleep 2

# 验证新用户
CONF_NEW="${TMPDIR}/newuser.cnf"
cat > "$CONF_NEW" <<EOF
[client]
user=${NEW_USER}
password=${NEW_PWD}
host=127.0.0.1
EOF
chmod 600 "$CONF_NEW"

if "${MYSQL_BIN}/mysql" --defaults-extra-file="$CONF_NEW" -e "SELECT 'ok' as res;" >/dev/null 2>&1; then
    echo "[OK] User '${NEW_USER}' created successfully and verified!"
else
    echo "[ERROR] Cannot login as '${NEW_USER}'. Check logs."
fi

rm -f "$CONF_NEW"
echo "[*] Done. Temporary files/logs kept in $TMPDIR"


