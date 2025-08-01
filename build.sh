#!/usr/bin/env bash
set -euo pipefail

usage() {
  cat <<EOF
Usage: $0 [options]

Options:

General:
  --version <version>   Specify the Hive version to build (default: "4.0.1")
  --platform <platform> Target platform for the build (default: "linux/amd64")
  --push                Push the built image to DockerHub
  --no-cache            Disable Docker build cache
  --debug               Enable debug output during build
  --clean               Clean build cache before building
  --purge               Delete cached builds and buildx cache
  --help                Show this help message and exit

EOF
  exit 1
}

command -v jq >/dev/null 2>&1 || { echo >&2 "jq is required but not installed."; exit 1; }
[[ -f versions.json ]] || { echo >&2 "versions.json not found."; exit 1; }

# Default values
VERSION="4.0.1"
PLATFORM=""
PUSH=""
NO_CACHE=""
DEBUG=""
CLEAN=""
PURGE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --version)
      if [[ -n "${2-}" && ! "$2" =~ ^-- ]]; then
        VERSION="$2"
        shift 2
      else
        echo "Error: --version requires an argument." >&2
        usage
      fi
      ;;
    --platform)
      if [[ -n "${2-}" && ! "$2" =~ ^-- ]]; then
        PLATFORM="$2"
        shift 2
      else
        echo "Error: --platform requires an argument." >&2
        usage
      fi
      ;;
    --push)
      PUSH="true"
      shift
      ;;
    --no-cache)
      NO_CACHE="true"
      shift
      ;;
    --debug)
      DEBUG="true"
      shift
      ;;
    --clean)
      CLEAN="true"
      shift
      ;;
    --purge)
      CLEAN="true"
      PURGE="true"
      shift
      ;;
    --help)
      usage
      ;;
    *)
      echo "Invalid option: $1" >&2
      usage
      ;;
  esac
done

# Clean build cache if requested
if [[ "${CLEAN}" == "true" ]]; then
  echo "Cleaning build cache..."
  rm -rf .buildx-cache
fi

if [[ "${PURGE:-}" == "true" ]]; then
  echo "Purging all cached build layers and artifacts..."
  rm -rf .buildx-cache downloads apache-hive-*-bin.tar.gz

  echo "Pruning dangling images and build cache..."
  docker image prune -f || true
  docker buildx prune -af || true

  echo "Removing temporary version files..."
  rm -f tmp.versions.json

  # Optional: remove buildx builder instance (uncomment if desired)
  # echo "Removing buildx builder 'hive-builder'..."
  # docker buildx rm hive-builder || true

  docker images "seathegood/hive-metastore" --format "{{.Repository}}:{{.Tag}}" | while read -r image; do
    echo "Removing local image: $image"
    docker rmi "$image" || true
  done

  echo "Purge complete."
  exit 0
fi

# Create the cache directory for buildx if not cleaning
# This directory is used to cache intermediate build layers to speed up subsequent builds
mkdir -p .buildx-cache

# Ensure buildx builder exists and is used
if ! docker buildx inspect hive-builder >/dev/null 2>&1; then
  echo "Creating buildx builder 'hive-builder'..."
  docker buildx create --name hive-builder --driver docker-container --use --bootstrap
else
  docker buildx use hive-builder
fi

mkdir -p downloads
TARBALL="downloads/apache-hive-${VERSION}-bin.tar.gz"

if [[ ! -f "${TARBALL}" ]]; then
  echo "Downloading Hive tarball..."
  curl -L "https://dlcdn.apache.org/hive/hive-${VERSION}/apache-hive-${VERSION}-bin.tar.gz" -o "${TARBALL}"
fi

SHA=$(jq -r --arg version "${VERSION}" '.hive[$version].sha256' versions.json)

if [[ "${SHA}" == "null" || -z "${SHA}" ]]; then
  echo "SHA not found for Hive version ${VERSION} in versions.json."
  echo "Calculating SHA256 from downloaded tarball..."
  SHA=$(sha256sum "${TARBALL}" | cut -d' ' -f1)

  if [[ -z "${SHA}" ]]; then
    echo "Failed to calculate SHA256 for Hive version ${VERSION}."
    exit 1
  fi

  echo "Found SHA: ${SHA}"
  echo "Updating versions.json..."
  jq --arg v "${VERSION}" --arg s "${SHA}" '.hive[$v] = {sha256: $s}' versions.json > tmp.versions.json && mv tmp.versions.json versions.json
fi

# Construct docker buildx command with logical grouping and explicit quoting

# Define IMAGE_TAG based on PLATFORM presence
if [[ -n "${PLATFORM}" ]]; then
  TAG_SUFFIX="${PLATFORM##*/}"
  IMAGE_TAG="${VERSION}-${TAG_SUFFIX}"
else
  IMAGE_TAG="${VERSION}"
fi

# Validate tagging variables before build
if [[ -z "${VERSION}" || -z "${IMAGE_TAG}" ]]; then
  echo "Error: Cannot tag image due to missing VERSION or PLATFORM" >&2
  exit 1
fi

BUILD_CMD=(
  docker buildx build
  --file "Dockerfile"
  --build-arg "HIVE_VERSION=${VERSION}"
  --build-arg "HIVE_TARBALL_SHA256=${SHA}"
  --build-arg "BUILD_DATE=$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  --build-arg "VCS_REF=$(git rev-parse --short HEAD)"
  --cache-from="type=local,src=.buildx-cache"
  --cache-to="type=local,dest=.buildx-cache,mode=max"
  -t "seathegood/hive-metastore:${IMAGE_TAG}"
  -t "seathegood/hive-metastore:latest"
  .
)

if [[ -n "${NO_CACHE}" ]]; then
  BUILD_CMD+=(--no-cache)
fi

if [[ -n "${DEBUG}" ]]; then
  BUILD_CMD+=(
    --output="type=docker"
    --progress="plain"
    --pull
    --build-arg "DEBUG=true"
  )
elif [[ -z "${PUSH}" ]]; then
  BUILD_CMD+=(--load)
fi

if [[ -z "${PLATFORM}" ]]; then
  BUILD_CMD+=(--platform "linux/amd64,linux/arm64")
else
  BUILD_CMD+=(--platform "${PLATFORM}")
fi

if [[ -n "${PUSH}" ]]; then
  BUILD_CMD+=(--push)
fi

"${BUILD_CMD[@]}"

# Logging build info
echo "Building Hive Metastore image with:"
echo "  Hive Version: ${VERSION}"
echo "  SHA256: ${SHA}"
echo "  Tarball: ${TARBALL}"
echo "  Platform: ${PLATFORM}"
echo "  Push enabled: ${PUSH}"

echo ""
echo "Docker image sizes:"
docker images seathegood/hive-metastore --format "  Tag: {{.Tag}}\tSize: {{.Size}}" | sort -k2 -h -r