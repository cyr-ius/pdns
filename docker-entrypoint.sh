#!/bin/sh

set -euo pipefail

# Configure mysql env vars
: "${DB_LAUNCH:=${PDNS_LAUNCH:-gsqlite3}}"

EXTRA=""

if [ "${DB_LAUNCH}" = 'gsqlite3' ] && [ ! -f "/var/lib/powerdns/pdns.sqlite3" ]; then
    export PDNS_GSQLITE3_DATABASE=/var/lib/powerdns/pdns.sqlite3
    sqlite3 /var/lib/powerdns/pdns.sqlite3 < /usr/share/doc/pdns/schema.sqlite3.sql
    chown -R pdns:pdns /var/lib/powerdns
fi

if [ "${DB_LAUNCH}" = 'gmysql' ]; then

    : "${DB_HOST:=${PDNS_GMYSQL_HOST:-mariadb}}"
    : "${DB_PORT:=${PDNS_GMYSQL_PORT:-3306}}"
    : "${DB_USER:=${PDNS_GMYSQL_USER:-powerdns}}"
    : "${DB_PASSWORD:=${PDNS_GMYSQL_PASSWORD:-powerdns}}"
    : "${DB_DBNAME:=${PDNS_GMYSQL_DBNAME:-powerdns}}"

    export DB_HOST DB_PORT DB_USER DB_PASSWORD DB_DBNAME

    # Password Auth
    if [ "${DB_PASSWORD}" != "" ]; then
        EXTRA="${EXTRA} -p${DB_PASSWORD}"
    fi

    # Allow socket connections
    if [ "${DB_SOCKET:-}" != "" ]; then
        export DB_SOCKET="localhost"
        EXTRA="${EXTRA} --socket=${DB_SOCKET}"
    fi

    MYSQL_COMMAND="mariadb -h ${DB_HOST} -P ${DB_PORT} -u ${DB_USER}${EXTRA}"

    # Wait for MySQL to respond
    until $MYSQL_COMMAND -e ';' ; do
        >&2 echo "Database is unavailable (${DB_HOST}:${DB_PORT} ${DB_USER}) - sleeping"
        sleep 3
    done

    # Initialize DB if needed
    if [ "${SKIP_DB_CREATE:-false}" != 'true' ]; then
        $MYSQL_COMMAND -e "CREATE DATABASE IF NOT EXISTS ${DB_DBNAME}"
    fi

    MYSQL_CHECK_IF_HAS_TABLE="SELECT COUNT(DISTINCT table_name) FROM information_schema.columns WHERE table_schema = '${DB_DBNAME}' AND table_name = 'domains';"
    MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_HAS_TABLE")
    if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
        echo 'Create schema...'
        $MYSQL_COMMAND -D "$DB_DBNAME" < /usr/share/doc/pdns/schema.mysql.sql
    fi

    # SQL migration to version 4.7
    MYSQL_CHECK_IF_47="SELECT COUNT(*) FROM information_schema.columns WHERE table_schema = '${DB_DBNAME}' AND table_name = 'domains' AND column_name = 'options';"
    MYSQL_NUM_TABLE=$($MYSQL_COMMAND --batch --skip-column-names -e "$MYSQL_CHECK_IF_47")
    if [ "$MYSQL_NUM_TABLE" -eq 0 ]; then
        echo 'Migrating MySQL schema to version 4.7...'
        $MYSQL_COMMAND -D "$DB_DBNAME" < /usr/share/doc/pdns/4.3.0_to_4.7.0_schema.mysql.sql
    fi
fi

# Create config file from template
envtpl < /pdns.conf.tpl > /etc/pdns/pdns.conf

exec "$@"