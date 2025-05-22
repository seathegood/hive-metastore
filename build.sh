#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }
[[ -f versions.json ]] || { echo >&2 "versions.json not found."; exit 1; }

VERSION="${1:-4.0.1}"
SHA=$(jq -r --arg version "$VERSION" '.[$version].sha256' versions.json)

if [[ "$SHA" == "null" || -z "$SHA" ]]; then
  echo "Error: SHA not found for version $VERSION in versions.json"
  exit 1
fi

docker build \
  --build-arg HIVE_VERSION="$VERSION" \
  --build-arg HIVE_TARBALL_SHA256="$SHA" \
  --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  -t seathegood/hive-metastore:"$VERSION" \
  -t seathegood/hive-metastore:latest .