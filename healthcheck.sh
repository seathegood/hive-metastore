#!/bin/bash
set -euo pipefail

HOST="${HIVE_METASTORE_HOST:-localhost}"
PORT="${HIVE_METASTORE_PORT:-9083}"

if nc -z -w 2 "$HOST" "$PORT"; then
  exit 0
else
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") Hive Metastore is not responding on $HOST:$PORT"
  exit 1
fi
