# Hive Metastore Docker Image (PostgreSQL Backend)


![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/seathegood/hive-metastore)
![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)
[![CI](https://github.com/seathegood/hive-metastore/actions/workflows/ci.yml/badge.svg)](https://github.com/seathegood/hive-metastore/actions/workflows/ci.yml)
[![Publish](https://github.com/seathegood/hive-metastore/actions/workflows/publish.yml/badge.svg)](https://github.com/seathegood/hive-metastore/actions/workflows/publish.yml)

This is a minimal, hardened Docker image for running the [Apache Hive Metastore](https://hive.apache.org) backed by an external PostgreSQL database. Designed for use in containerized environments with an emphasis on security, observability, and compliance.

---

## Features

- Uses official Hive distribution (default: `4.0.1`)
- External PostgreSQL support with auto-schema initialization
- Healthcheck via port scan
- Runs as non-root user
- Small image footprint using `eclipse-temurin`
- Production-hardened with:
  - minimal installed packages
  - locked-down file permissions
  - optional volume persistence

---

## Usage

### Docker Hub

```bash
docker pull seathegood/hive-metastore:latest
```

### Quickstart (Docker CLI)

```bash
docker run -d \
  -e METASTORE_DB_URL=jdbc:postgresql://<host>:5432/hive \
  -e METASTORE_DB_USER=hive \
  -e METASTORE_DB_PASS=hivepassword \
  -e METASTORE_DB_HOST=<host> \
  -e METASTORE_DB_PORT=5432 \
  -v /path/to/logs:/opt/hive/logs \
  -v /path/to/tmp:/opt/hive/tmp \
  -p 9083:9083 \
  seathegood/hive-metastore:latest
```

> You must supply a PostgreSQL JDBC driver named `postgresql-jdbc.jar` in the Docker build context.

---

## Environment Variables

| Variable             | Required | Description                          |
|----------------------|----------|--------------------------------------|
| `METASTORE_DB_URL`   | ✅        | Full JDBC URL to the PostgreSQL DB   |
| `METASTORE_DB_USER`  | ✅        | Database username                    |
| `METASTORE_DB_PASS`  | ✅        | Database password                    |
| `METASTORE_DB_HOST`  | ✅        | DB host (used for health check)     |
| `METASTORE_DB_PORT`  | ✅        | DB port (used for health check)     |

---

## Health Check

The image includes a basic `HEALTHCHECK` that verifies the Hive Metastore is listening on port `9083`.

---

## Security Notes

This image is hardened for production use:

- Non-root user (`hive`)
- Build-time tools removed after install
- Limited package surface
- File permissions locked down
- Logs and temp paths are volume-mountable

To further harden in Kubernetes or Nomad:
```yaml
securityContext:
  runAsUser: 999
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

---

## Building Locally

```bash
wget https://jdbc.postgresql.org/download/postgresql-42.7.3.jar -O postgresql-jdbc.jar

docker build -t hive-metastore:local --build-arg HIVE_VERSION=3.1.3 .
```

---

## CI/CD

This project uses GitHub Actions to build and publish multi-arch Docker images on each release.

- `ci.yml`: Validates builds and tests against PostgreSQL
- `publish.yml`: Builds and pushes tagged releases to Docker Hub
- `check-upstream.yml`: Monitors Apache Hive for new releases, updates the Dockerfile and versions.json, and creates a GitHub release which triggers `publish.yml`

---

## License

Apache 2.0 – See `LICENSE` file.
