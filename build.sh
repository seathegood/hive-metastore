#!/usr/bin/env bash
set -euo pipefail

VERSION=$1
SHA=$(jq -r --arg version "$VERSION" '.[$version].sha256' versions.json)

docker build \
  --build-arg HIVE_VERSION=$VERSION \
  --build-arg HIVE_TARBALL_SHA256=$SHA \
  --build-arg BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ") \
  --build-arg VCS_REF=$(git rev-parse --short HEAD) \
  -t seathegood/hive-metastore:$VERSION .
