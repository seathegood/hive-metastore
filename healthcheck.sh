#!/bin/sh
# shellcheck shell=sh

set -eu
command -v nc > /dev/null || { echo "nc is required"; exit 1; }
command -v xxd > /dev/null || { echo "xxd is required"; exit 1; }

HOST="${HIVE_METASTORE_HOST:-localhost}"
PORT="${HIVE_METASTORE_PORT:-9083}"

if ! nc -z "$HOST" "$PORT"; then
  echo "Metastore TCP port $PORT not open on $HOST"
  exit 1
fi

exec schematool -dbType postgres -info
