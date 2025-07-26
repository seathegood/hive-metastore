#!/usr/bin/env bash
set -euo pipefail


command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }
[[ -f versions.json ]] || { echo >&2 "versions.json not found."; exit 1; }

# Ensure buildx builder exists and is used
if ! docker buildx inspect hive-builder >/dev/null 2>&1; then
  echo "Creating buildx builder 'hive-builder'..."
  docker buildx create --name hive-builder --driver docker-container --use --bootstrap
else
  docker buildx use hive-builder
fi

mkdir -p downloads
VERSION="${1:-4.0.1}"
PLATFORM="${2:-linux/amd64}"
NO_CACHE="${3:-}"
DEBUG="${4:-}"
TARBALL="downloads/apache-hive-${VERSION}-bin.tar.gz"

if [[ ! -f "$TARBALL" ]]; then
  echo "Downloading Hive tarball..."
  curl -L "https://dlcdn.apache.org/hive/hive-${VERSION}/apache-hive-${VERSION}-bin.tar.gz" -o "$TARBALL"
fi

SHA=$(jq -r --arg version "$VERSION" '.hive[$version].sha256' versions.json)

if [[ "$SHA" == "null" || -z "$SHA" ]]; then
  echo "SHA not found for Hive version $VERSION in versions.json."
  echo "Calculating SHA256 from downloaded tarball..."
  SHA=$(sha256sum "$TARBALL" | cut -d' ' -f1)

  if [[ -z "$SHA" ]]; then
    echo "Failed to calculate SHA256 for Hive version $VERSION."
    exit 1
  fi

  echo "Found SHA: $SHA"
  echo "Updating versions.json..."
  jq --arg v "$VERSION" --arg s "$SHA" '.hive[$v] = {sha256: $s}' versions.json > tmp.versions.json && mv tmp.versions.json versions.json
fi

docker buildx build \
  --platform "$PLATFORM" \
  --file Dockerfile \
  --build-arg HIVE_VERSION="$VERSION" \
  --build-arg HIVE_TARBALL_SHA256="$SHA" \
  --build-arg BUILD_DATE="$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
  --build-arg VCS_REF="$(git rev-parse --short HEAD)" \
  ${NO_CACHE:+--no-cache} \
  ${DEBUG:+--output=type=docker} ${DEBUG:+"--progress=plain"} ${DEBUG:+"--pull"} ${DEBUG:+"--build-arg"} ${DEBUG:+DEBUG=true} \
  ${DEBUG:-"--load"} \
  --cache-from=type=local,src=.buildx-cache \
  --cache-to=type=local,dest=.buildx-cache,mode=max \
  -t seathegood/hive-metastore:"$VERSION-${PLATFORM##*/}" \
  -t seathegood/hive-metastore:latest .