#!/usr/bin/env bash
set -euo pipefail

replset_name="${MONGO_REPLSET_NAME:-rs0}"
admin_user="${MONGO_ROOT_USERNAME:-admin}"
admin_pass="${MONGO_ROOT_PASSWORD:-}"
app_db="${MONGO_APP_DB:-app_db}"
app_user="${MONGO_APP_USERNAME:-app_user}"
app_pass="${MONGO_APP_PASSWORD:-}"

if [[ -z "${admin_pass}" || -z "${app_pass}" ]]; then
  echo "Missing MONGO_ROOT_PASSWORD or MONGO_APP_PASSWORD"
  exit 1
fi

keyfile_path="/etc/mongo-keyfile/keyfile"
chmod 0400 "${keyfile_path}" || true

marker="/data/db/.rs_initialized"

start_mongod_forked() {
  mongod --config /etc/mongo/mongod.conf --pidfilepath /tmp/mongod.pid &
  echo $! >/tmp/mongod-bg.pid
}

stop_mongod_forked() {
  if [[ -f /tmp/mongod.pid ]]; then
    mongod --shutdown --pidfilepath /tmp/mongod.pid || true
  fi
  if [[ -f /tmp/mongod-bg.pid ]]; then
    kill "$(cat /tmp/mongod-bg.pid)" >/dev/null 2>&1 || true
    rm -f /tmp/mongod-bg.pid
  fi
}

wait_for_mongo() {
  for _ in $(seq 1 120); do
    if mongosh --quiet --host 127.0.0.1 --eval 'db.adminCommand({ping:1}).ok' 2>/dev/null | grep -q 1; then
      return 0
    fi
    sleep 1
  done
  return 1
}

wait_for_primary() {
  for _ in $(seq 1 120); do
    if mongosh --quiet --host 127.0.0.1 --eval 'db.hello().isWritablePrimary' 2>/dev/null | grep -q true; then
      return 0
    fi
    sleep 1
  done
  return 1
}

if [[ ! -f "${marker}" ]]; then
  echo "Bootstrapping replica set and users..."

  start_mongod_forked
  wait_for_mongo

  mongosh --quiet --host 127.0.0.1 --eval "rs.initiate({_id: '${replset_name}', members: [{_id: 0, host: 'mongo1:27017'}, {_id: 1, host: 'mongo2:27017'}, {_id: 2, host: 'mongo3:27017'}]})" || true

  wait_for_primary

  mongosh --quiet --host 127.0.0.1 --eval "db.getSiblingDB('admin').createUser({user: '${admin_user}', pwd: '${admin_pass}', roles: [{role: 'root', db: 'admin'}]})" || true

  mongosh --quiet --host 127.0.0.1 -u "${admin_user}" -p "${admin_pass}" --authenticationDatabase admin --eval "db.getSiblingDB('${app_db}').createUser({user: '${app_user}', pwd: '${app_pass}', roles: [{role: 'readWrite', db: '${app_db}'}]})" || true

  touch "${marker}"

  stop_mongod_forked
fi

exec mongod --config /etc/mongo/mongod.conf
