#!/usr/bin/env bash
(
  set -euo pipefail

  echo "Waiting for replication user to be ready..."
  for i in $(seq 1 180); do
    if mysql -hmysql-master -u"${MYSQL_REPLICATION_USER}" -p"${MYSQL_REPLICATION_PASSWORD}" -e "SELECT 1" >/dev/null 2>&1; then
      break
    fi
    sleep 2
  done

  echo "Configuring replica with GTID auto-position..."
  mysql --socket=/var/lib/mysql/mysql.sock -uroot -p"${MYSQL_ROOT_PASSWORD}" <<SQL
STOP REPLICA;
RESET REPLICA ALL;
CHANGE REPLICATION SOURCE TO
  SOURCE_HOST='mysql-master',
  SOURCE_PORT=3306,
  SOURCE_USER='${MYSQL_REPLICATION_USER}',
  SOURCE_PASSWORD='${MYSQL_REPLICATION_PASSWORD}',
  SOURCE_AUTO_POSITION=1,
  GET_SOURCE_PUBLIC_KEY=1;
START REPLICA;
SET PERSIST read_only=ON;
SET PERSIST super_read_only=ON;
SQL
)
