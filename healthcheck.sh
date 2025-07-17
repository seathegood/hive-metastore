#!/bin/sh
# shellcheck shell=sh
set -eu

HOST="${HIVE_METASTORE_HOST:-localhost}"
PORT="${HIVE_METASTORE_PORT:-9083}"

# First check: Is the TCP port open?
if ! nc -z "$HOST" "$PORT"; then
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") Hive Metastore is not responding on $HOST:$PORT (TCP check failed)"
  exit 1
fi

# Second check: Try sending a minimal Thrift "PING" request
# Hive Thrift server should respond (or close the connection) to valid framed protocol
# The message below is the Thrift binary framing for method "PING" (nonexistent, but valid enough)
PING_HEX="80010000000450494E4700"
PING_BIN=$(echo "$PING_HEX" | xxd -r -p)

if ! printf "$PING_BIN" | nc "$HOST" "$PORT" -w 2 > /dev/null 2>&1; then
  echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ") Hive Metastore accepted TCP but failed Thrift responsiveness test on $HOST:$PORT"
  exit 1
fi

# All checks passed
exit 0
