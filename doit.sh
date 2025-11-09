#!/usr/bin/env bash
set -euo pipefail

# 自动创建 root1 用户，跳过授权模式，授予 ALL PRIVILEGES
TMPDIR="/tmp/mysql_add_admin_$$"
mkdir -p "$TMPDIR"

NEW_USER="root1"
NEW_PWD="root1"

echo "[*] This script will stop MySQL, start it with --skip-grant-tables, create user '${NEW_USER}', then restart MySQL."

# Detect MySQL service
SERVICE=$(systemctl list-units --type=service --all | grep -E "mysql|mysqld|mariadb" | head -n1 | awk '{print $1}' || true)
echo "[*] Detected service: $SERVICE"

# Stop MySQL
echo "[*] Stopping MySQL service..."
systemctl stop "$SERVICE" || service "$SERVICE" stop || true
sleep 1
pkill -9 mysqld || true

# Start mysqld with skip-grant-tables
echo "[*] Starting temporary mysqld with --skip-grant-tables ..."
if command -v mysqld_safe >/dev/null 2>&1; then
    nohup mysqld_safe --skip-grant-tables --skip-networking > "$TMPDIR/mysqld_safe.log" 2>&1 &
else
    nohup /usr/sbin/mysqld --skip-grant-tables --skip-networking > "$TMPDIR/mysqld.log" 2>&1 &
fi

# Wait for mysqld to be ready
SECS=0
until mysqladmin ping >/dev/null 2>&1 || [ $SECS -ge 30 ]; do
    sleep 1
    SECS=$((SECS+1))
done

if ! mysqladmin ping >/dev/null 2>&1; then
    echo "[ERROR] Temporary mysqld did not start. Check logs in $TMPDIR."
    exit 1
fi
echo "[*] Temporary mysqld running."

# Create SQL file
SQLFILE="$TMPDIR/add_admin.sql"
cat > "$SQLFILE" <<SQL
CREATE USER IF NOT EXISTS '${NEW_USER}'@'localhost' IDENTIFIED BY '${NEW_PWD}';
CREATE USER IF NOT EXISTS '${NEW_USER}'@'%' IDENTIFIED BY '${NEW_PWD}';
GRANT ALL PRIVILEGES ON *.* TO '${NEW_USER}'@'localhost' WITH GRANT OPTION;
GRANT ALL PRIVILEGES ON *.* TO '${NEW_USER}'@'%' WITH GRANT OPTION;
FLUSH PRIVILEGES;
SQL

# Execute SQL
mysql < "$SQLFILE"

# Stop temporary mysqld
pkill -f 'skip-grant-tables' || pkill mysqld || true
sleep 1

# Start normal MySQL service
systemctl start "$SERVICE" || service "$SERVICE" start || true
sleep 2

# Verify login
CONF_NEW="$TMPDIR/newuser.cnf"
cat > "$CONF_NEW" <<EOF
[client]
user=${NEW_USER}
password=${NEW_PWD}
host=127.0.0.1
EOF
chmod 600 "$CONF_NEW"

if mysql --defaults-extra-file="$CONF_NEW" -e "SELECT 'ok' as res;" >/dev/null 2>&1; then
    echo "[OK] User '${NEW_USER}' created successfully and verified!"
else
    echo "[ERROR] Cannot login as '${NEW_USER}'. Check logs."
fi

rm -f "$CONF_NEW"
echo "[*] Done. Temporary files/logs kept in $TMPDIR."
