#!/bin/bash
set -euo pipefail

# Paths
DOCKERFILE="Dockerfile"
VERSIONS_JSON="versions.json"

# Extract PostgreSQL JDBC version from Dockerfile
PG_JDBC_VERSION=$(grep '^ARG PG_JDBC_VERSION=' "$DOCKERFILE" | head -n1 | sed 's/.*=//' | tr -d '[:space:]')

echo "Detected PostgreSQL JDBC version: $PG_JDBC_VERSION"

# Construct .jar file name and URL
JAR_FILE="postgresql-${PG_JDBC_VERSION}.jar"
JAR_URL="https://jdbc.postgresql.org/download/${JAR_FILE}"

# Download the .jar
echo "Downloading ${JAR_FILE}..."
curl -sSL -o "$JAR_FILE" "$JAR_URL"

# Calculate SHA256 hash
echo "Calculating SHA256..."
SHA256=$(shasum -a 256 "$JAR_FILE" | awk '{print $1}')

# Insert into versions.json using jq
echo "Updating ${VERSIONS_JSON} with version ${PG_JDBC_VERSION} and SHA256..."
jq --arg v "$PG_JDBC_VERSION" --arg h "$SHA256" \
  '.postgresql[$v] = { "sha256": $h }' "$VERSIONS_JSON" > tmp.versions.json && mv tmp.versions.json "$VERSIONS_JSON"

# Clean up
rm "$JAR_FILE"

echo "✅ versions.json updated successfully."
