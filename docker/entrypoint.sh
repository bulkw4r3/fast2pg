#!/usr/bin/env bash
set -euo pipefail

APP_USER="${APP_USER:-app}"
APP_DB="${APP_DB:-fast2pg}"
APP_PORT="${PORT:-5001}"
PGPORT="${PGPORT:-5432}"
PGDATA="${PGDATA:-/var/lib/postgresql/data}"
PG_SOCKET_DIR="${PG_SOCKET_DIR:-/var/run/postgresql}"

PG_BIN="$(find /usr/lib/postgresql -mindepth 2 -maxdepth 2 -type d -name bin | sort -V | tail -n 1)"
export PATH="$PG_BIN:$PATH"

install -d -o postgres -g postgres -m 700 "$PGDATA"
install -d -o postgres -g postgres -m 755 "$PG_SOCKET_DIR"

stop_postgres() {
    echo "Stopping Postgres"
    gosu postgres pg_ctl -D "$PGDATA" -m fast -w stop || true
}

if [ ! -f "$PGDATA/PG_VERSION" ]; then
    echo "Initializing Postgres data directory at $PGDATA"
    gosu postgres initdb -D "$PGDATA" --auth-local=peer --auth-host=scram-sha-256 >/dev/null
fi

echo "Starting Postgres"
gosu postgres pg_ctl -D "$PGDATA" -l "$PGDATA/postgres.log" \
    -o "-c unix_socket_directories=$PG_SOCKET_DIR -c port=$PGPORT" -w start
trap stop_postgres ERR

# Create the app role and database on first start.
if ! gosu postgres psql -h "$PG_SOCKET_DIR" -p "$PGPORT" -d postgres -tAc \
        "SELECT 1 FROM pg_roles WHERE rolname='$APP_USER'" | grep -q 1; then
    gosu postgres psql -h "$PG_SOCKET_DIR" -p "$PGPORT" -d postgres -c "CREATE ROLE \"$APP_USER\" LOGIN"
fi
if ! gosu postgres psql -h "$PG_SOCKET_DIR" -p "$PGPORT" -d postgres -tAc \
        "SELECT 1 FROM pg_database WHERE datname='$APP_DB'" | grep -q 1; then
    gosu postgres createdb -h "$PG_SOCKET_DIR" -p "$PGPORT" -O "$APP_USER" "$APP_DB"
fi

echo "Starting fast2pg on port $APP_PORT"
gosu "$APP_USER" /app/.venv/bin/uvicorn fast2pg.app:app \
    --host 0.0.0.0 --port "$APP_PORT" &
app_pid=$!

shutdown() {
    kill -TERM "$app_pid" 2>/dev/null || true
    wait "$app_pid" 2>/dev/null || true
    stop_postgres
    exit 0
}
trap shutdown TERM INT

set +e
wait "$app_pid"
status=$?
set -e

stop_postgres
exit "$status"
