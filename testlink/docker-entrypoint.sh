#!/usr/bin/env bash
set -e

: "${TL_DB_HOST:=mariadb}"
: "${TL_DB_PORT:=3306}"
: "${TL_DB_NAME:=bitnami_testlink}"
: "${TL_DB_USER:=bn_testlink}"
: "${TL_DB_PASS:=change_db_pw}"
: "${TL_DB_PREFIX:=}"
: "${TL_ENABLE_API:=true}"
: "${TL_ADMIN_USER:=admin}"
: "${TL_ADMIN_PASS:=admin12345}"
: "${TL_ADMIN_EMAIL:=admin@example.com}"

CONFIG_DB="/var/www/html/config_db.inc.php"
CONFIG_MAIN="/var/www/html/config.inc.php"

echo "Waiting for DB ${TL_DB_HOST}:${TL_DB_PORT}..."
for i in {1..60}; do
  if mysqladmin ping -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" --silent; then
    echo "DB is up."
    break
  fi
  sleep 2
done

# Write DB config (if not present)
if [ ! -f "$CONFIG_DB" ]; then
  cat > "$CONFIG_DB" <<PHP
<?php
define('DB_TYPE','mysqli');
define('DB_USER','${TL_DB_USER}');
define('DB_PASS','${TL_DB_PASS}');
define('DB_HOST','${TL_DB_HOST}');
define('DB_NAME','${TL_DB_NAME}');
define('DB_TABLE_PREFIX','${TL_DB_PREFIX}');
define('TL_ABS_PATH','/var/www/html/');
PHP
  chown www-data:www-data "$CONFIG_DB"
  chmod 640 "$CONFIG_DB"
  echo "Wrote $CONFIG_DB"
fi

# Writable dirs
mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c
chown -R www-data:www-data /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c || true

# Import schema if users table missing
SCHEMA_OK=$(mysql -N -s -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" \
  -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TL_DB_NAME}' AND table_name='users';")
if [ "${SCHEMA_OK}" = "0" ]; then
  echo "No TestLink schema detected. Importing..."
  mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
    < /var/www/html/install/sql/testlink_create_tables.sql
  mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
    < /var/www/html/install/sql/testlink_create_tables_mysql.sql || true
  echo "Schema import complete."
fi

# Enable API flag (if present)
if [ -f "$CONFIG_MAIN" ] && [ "${TL_ENABLE_API}" = "true" ]; then
  grep -q "\$tlCfg->api->enabled" "$CONFIG_MAIN" \
    && sed -i "s/\$tlCfg->api->enabled\s*=\s*FALSE/\$tlCfg->api->enabled = TRUE/i" "$CONFIG_MAIN" || true
fi

# Create admin if not present
php -r '
$u=getenv("TL_ADMIN_USER"); $p=getenv("TL_ADMIN_PASS"); $e=getenv("TL_ADMIN_EMAIL");
require_once "/var/www/html/config_db.inc.php";
$mysqli=@new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($mysqli->connect_errno) { fwrite(STDERR,"DB not ready\n"); exit(0); }
$u_esc=$mysqli->real_escape_string($u);
$res=$mysqli->query("SHOW TABLES LIKE \"users\"");
if($res && $res->num_rows>0){
  $res2=$mysqli->query("SELECT 1 FROM users WHERE login=\"{$u_esc}\" LIMIT 1");
  if(!$res2 || $res2->num_rows==0){
    $hash=password_hash($p, PASSWORD_BCRYPT);
    $mysqli->query("INSERT INTO users (login,password,email,role_id,active,locale) VALUES (\"$u_esc\",\"$hash\",\"$e\",8,1,\"en_GB\")");
    echo "Admin user created\n";
  }
} else {
  fwrite(STDERR,"Users table not found; schema may not be fully imported\n");
}
'

chown -R www-data:www-data /var/www/html
exec apache2-foreground
