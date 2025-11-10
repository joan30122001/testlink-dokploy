#!/usr/bin/env bash
set -e

: "${TL_DB_HOST:=mariadb}"
: "${TL_DB_PORT:=3306}"
: "${TL_DB_NAME:=testlinkdb}"
: "${TL_DB_USER:=tluser}"
: "${TL_DB_PASS:=TLpass123!}"
: "${TL_DB_PREFIX:=}"
: "${TL_ENABLE_API:=true}"
: "${TL_ADMIN_USER:=admin}"
: "${TL_ADMIN_PASS:=AdminPass123!}"
: "${TL_ADMIN_EMAIL:=admin@example.com}"

CONFIG_DB="/var/www/html/config_db.inc.php"
CONFIG_MAIN="/var/www/html/config.inc.php"

# Ensure main app config exists if a sample is present
if [ ! -f "$CONFIG_MAIN" ] && [ -f /var/www/html/config.inc.php.sample ]; then
  cp /var/www/html/config.inc.php.sample "$CONFIG_MAIN"
  chown www-data:www-data "$CONFIG_MAIN"
  chmod 640 "$CONFIG_MAIN"
fi

echo "[entrypoint] Waiting for DB ${TL_DB_HOST}:${TL_DB_PORT}…"
for i in {1..180}; do
  if mysqladmin ping -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" --silent >/dev/null 2>&1; then
    echo "[entrypoint] DB ping ok"
    break
  fi
  sleep 2
done

# Write DB config (idempotent)
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
  echo "[entrypoint] Wrote $CONFIG_DB"
fi

# Writable dirs
mkdir -p /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c
chown -R www-data:www-data /var/www/html/upload_area /var/www/html/logs /var/www/html/gui/templates_c || true

# Import schema if missing
if mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" -e "SELECT 1" "${TL_DB_NAME}" >/dev/null 2>&1; then
  SCHEMA_OK=$(mysql -N -s -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" \
    -e "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema='${TL_DB_NAME}' AND table_name='users';" 2>/dev/null || echo "ERR")
  if [ "$SCHEMA_OK" = "0" ]; then
    echo "[entrypoint] Importing TestLink schema…"
    mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
      < /var/www/html/install/sql/testlink_create_tables.sql || true
    mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
      < /var/www/html/install/sql/testlink_create_tables_mysql.sql || true
    echo "[entrypoint] Schema import attempt finished."
  fi

  # --- keep: import default data so installer won't force "upgrade" ---
  if [ -f /var/www/html/install/sql/testlink_create_default_data.sql ]; then
    mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
      < /var/www/html/install/sql/testlink_create_default_data.sql || true
  fi
  if [ -f /var/www/html/install/sql/testlink_create_default_data_mysql.sql ]; then
    mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
      < /var/www/html/install/sql/testlink_create_default_data_mysql.sql || true
  fi

  # ✅ FIX: set/keep proper db_version row without using non-existent 'dbversion' column
  mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
    -e "INSERT IGNORE INTO db_version (version,notes,upgrade_ts) VALUES ('DB 1.9.20','TestLink 1.9.20 Raijin', NOW());"
  mysql -h"${TL_DB_HOST}" -P"${TL_DB_PORT}" -u"${TL_DB_USER}" -p"${TL_DB_PASS}" "${TL_DB_NAME}" \
    -e "UPDATE db_version SET notes='TestLink 1.9.20 Raijin' WHERE version='DB 1.9.20';"
fi

# Enable API (best effort)
if [ -f "$CONFIG_MAIN" ] && [ "${TL_ENABLE_API}" = "true" ]; then
  sed -i 's/\($tlCfg->api->enabled\s*=\s*\)FALSE/\1TRUE/i' "$CONFIG_MAIN" || true
fi

# Create admin if table exists
php -r '
$u=getenv("TL_ADMIN_USER"); $p=getenv("TL_ADMIN_PASS"); $e=getenv("TL_ADMIN_EMAIL");
@include "/var/www/html/config_db.inc.php";
if (!defined("DB_HOST")) { fwrite(STDERR,"[entrypoint] no DB config\n"); exit(0); }
$mysqli=@new mysqli(DB_HOST, DB_USER, DB_PASS, DB_NAME);
if ($mysqli->connect_errno){ fwrite(STDERR,"[entrypoint] DB connect fail, skip admin\n"); exit(0); }
$r=$mysqli->query("SHOW TABLES LIKE \"users\"");
if($r && $r->num_rows>0){
  $u_esc=$mysqli->real_escape_string($u);
  $r2=$mysqli->query("SELECT 1 FROM users WHERE login=\"{$u_esc}\" LIMIT 1");
  if(!$r2 || $r2->num_rows==0){
    $hash=password_hash($p, PASSWORD_BCRYPT);
    $ok=$mysqli->query("INSERT INTO users (login,password,email,role_id,active,locale) VALUES (\"$u_esc\",\"$hash\",\"$e\",8,1,\"en_GB\")");
    if($ok){ echo "[entrypoint] Admin user created\n"; }
  }
  // MD5 fallback if schema stores 32-char hashes
  $r3 = $mysqli->query("SHOW COLUMNS FROM users LIKE \"password\"");
  if ($r3 && ($c = $r3->fetch_assoc())) {
    if (preg_match("/varchar\\(32\\)/i", $c["Type"] ?? "")) {
      $md5 = md5($p);
      $mysqli->query("UPDATE users SET password=\"$md5\" WHERE login=\"$u_esc\"") or /* ignore */;
    }
  }

  // --- FORCE: ensure admin uses MD5, is active and unlocked (no other changes) ---
  $forced = md5($p);
  @$mysqli->query("UPDATE users SET password=\"$forced\", active=1, role_id=8 WHERE login=\"$u_esc\"");
  @$mysqli->query("UPDATE users SET is_disabled=0 WHERE login=\"$u_esc\"");
  @$mysqli->query("UPDATE users SET blocked=0 WHERE login=\"$u_esc\"");
  @$mysqli->query("UPDATE users SET password_type=\"MD5\" WHERE login=\"$u_esc\"");
  // --- END FORCE ---
}
' || true

echo "[entrypoint] Starting Apache…"
exec apache2-foreground
