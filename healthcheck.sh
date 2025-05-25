#!/bin/sh
set -eu

HOST="${HIVE_METASTORE_HOST:-localhost}"
PORT="${HIVE_METASTORE_PORT:-9083}"

if nc -z "$HOST" "$PORT"; then
  exit 0
else
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") Hive Metastore is not responding on $HOST:$PORT"
  exit 1
fi
