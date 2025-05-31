#!/usr/bin/env bash
set -euo pipefail

command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }
[[ -f versions.json ]] || { echo >&2 "versions.json not found."; exit 1; }

VERSION="${1:-4.0.1}"
PLATFORM="${2:-linux/amd64}"
NO_CACHE="${3:-}"
DEBUG="${4:-}"

SHA=$(jq -r --arg version "$VERSION" '.hive[$version].sha256' versions.json)

if [[ "$SHA" == "null" || -z "$SHA" ]]; then
  echo "SHA not found for Hive version $VERSION in versions.json."
  echo "Attempting to download SHA256 from Apache..."
  SHA=$(curl -s "https://dlcdn.apache.org/hive/hive-${VERSION}/apache-hive-${VERSION}-bin.tar.gz.sha256" | cut -d' ' -f1)

  if [[ -z "$SHA" ]]; then
    echo "Failed to fetch SHA256 for Hive version $VERSION."
    exit 1
  fi

  echo "Found SHA: $SHA"
  echo "Updating versions.json..."
  jq --arg v "$VERSION" --arg s "$SHA" '.hive[$v] = {sha256: $s}' versions.json > tmp.versions.json && mv tmp.versions.json versions.json
fi

docker buildx build \
  --platform "$PLATFORM" \
  --build-arg HIVE_VERSION="$VERSION" \
  --build-arg HIVE_TARBALL_SHA256="$SHA" \
  --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  ${DEBUG:+--output=type=docker} ${DEBUG:+"--progress=plain"} ${DEBUG:+"--no-cache"} ${DEBUG:+"--pull"} ${DEBUG:+"--build-arg"} ${DEBUG:+DEBUG=true} \
  ${DEBUG:-"--load"} \
  -t seathegood/hive-metastore:"$VERSION-${PLATFORM##*/}" \
  -t seathegood/hive-metastore:latest .