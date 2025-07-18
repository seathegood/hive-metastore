# Hive Metastore Docker Image (PostgreSQL Backend)

![Docker Cloud Build Status](https://img.shields.io/docker/cloud/build/seathegood/hive-metastore)
![License: Apache-2.0](https://img.shields.io/badge/license-Apache--2.0-blue.svg)
[![CI](https://github.com/seathegood/hive-metastore/actions/workflows/ci.yml/badge.svg)](https://github.com/seathegood/hive-metastore/actions/workflows/ci.yml)
[![Publish](https://github.com/seathegood/hive-metastore/actions/workflows/publish.yml/badge.svg)](https://github.com/seathegood/hive-metastore/actions/workflows/publish.yml)
[![Docker Pulls](https://img.shields.io/docker/pulls/seathegood/hive-metastore.svg)](https://hub.docker.com/r/seathegood/hive-metastore)
[![GitHub Stars](https://img.shields.io/github/stars/seathegood/hive-metastore.svg?style=social&label=Star)](https://github.com/seathegood/hive-metastore/stargazers)

A minimal, production-ready Docker image for running the [Apache Hive Metastore](https://hive.apache.org) backed by an external PostgreSQL database. Designed for security, observability, and automation in container environments.

---

## Features

- Uses official Hive release (default: `4.0.1`)
- Minimal base image (`eclipse-temurin:21-jdk-alpine`)
- Multi-arch support (via GitHub Actions)
- Hardened image:
  - Non-root `hive` user
  - Only essential packages installed
  - File permissions locked down
- Automatic schema initialization on first run
- Thrift-based healthcheck support
- Graceful shutdown handling
- Environment-driven configuration
- Supports custom `hive-site.xml` via volume mount

---

## Usage

### Pull from Docker Hub

```bash
docker pull seathegood/hive-metastore:latest
```

### Quickstart

```bash
docker run -d \
  -e POSTGRES_USER=hive \
  -e POSTGRES_PASSWORD=hivepassword \
  -e METASTORE_DB_HOST=postgres.local \
  -e METASTORE_DB_PORT=5432 \
  -e METASTORE_PORT=9083 \
  -p 9083:9083 \
  seathegood/hive-metastore:latest
```

> This image includes the PostgreSQL JDBC driver and does not require manual copying.

---

## Configuration

### Required Environment Variables

| Variable             | Description                                  |
|----------------------|----------------------------------------------|
| `POSTGRES_USER`      | Username for the metastore DB                |
| `POSTGRES_PASSWORD`  | Password for the metastore DB                |
| `METASTORE_DB_HOST`  | Hostname of the PostgreSQL database          |
| `METASTORE_DB_PORT`  | Port of the PostgreSQL database (default: 5432) |
| `METASTORE_PORT`     | Port to expose Hive Metastore (default: 9083) |

> You may optionally set `METASTORE_DB_URL` to override the full JDBC connection string.

---

## Healthcheck

This image includes a healthcheck that:
- Verifies TCP port availability on the configured host/port
- Sends a minimal Thrift ping request to confirm service responsiveness

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD ["/usr/local/bin/healthcheck.sh"]
```

---

## Logging

Hive Metastore logs are sent to `stdout` and `stderr`, making them accessible via:

```bash
docker logs <container>
```

No log files are written to disk by default.

---

## Graceful Shutdown

The container traps `SIGTERM` and `SIGINT` to ensure the Hive process shuts down cleanly.

---

## Kubernetes Security Context (Example)

To further harden the container in orchestration environments:

```yaml
securityContext:
  runAsUser: 999
  readOnlyRootFilesystem: true
  allowPrivilegeEscalation: false
```

---

## Building Locally

```bash
docker build -t hive-metastore:local \
  --build-arg HIVE_VERSION=4.0.1 \
  --build-arg HADOOP_VERSION=3.4.1 \
  .
```

---

## CI/CD

- **`ci.yml`**: Linting and validation
- **`publish.yml`**: Builds and pushes Docker images on tagged releases
- **`check-upstream.yml`**: Monitors for Hive releases, bumps versions, and creates pull requests/releases

---

## Deployment Examples

### Docker Compose

```yaml
version: '3.8'

services:
  postgres:
    image: postgres:15
    environment:
      POSTGRES_USER: hive
      POSTGRES_PASSWORD: hivepassword
      POSTGRES_DB: metastore_db
    ports:
      - 5432:5432

  hive-metastore:
    image: seathegood/hive-metastore:latest
    depends_on:
      - postgres
    environment:
      POSTGRES_USER: hive
      POSTGRES_PASSWORD: hivepassword
      METASTORE_DB_HOST: postgres
      METASTORE_DB_PORT: 5432
      METASTORE_PORT: 9083
    ports:
      - 9083:9083
    healthcheck:
      test: ["CMD", "/usr/local/bin/healthcheck.sh"]
      interval: 30s
      timeout: 10s
      retries: 3
```

### Kubernetes Deployment (Minimal)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: hive-metastore
spec:
  replicas: 1
  selector:
    matchLabels:
      app: hive-metastore
  template:
    metadata:
      labels:
        app: hive-metastore
    spec:
      containers:
        - name: metastore
          image: seathegood/hive-metastore:latest
          ports:
            - containerPort: 9083
          env:
            - name: POSTGRES_USER
              value: hive
            - name: POSTGRES_PASSWORD
              value: hivepassword
            - name: METASTORE_DB_HOST
              value: postgres.default.svc.cluster.local
            - name: METASTORE_DB_PORT
              value: "5432"
            - name: METASTORE_PORT
              value: "9083"
          readinessProbe:
            exec:
              command: ["/usr/local/bin/healthcheck.sh"]
            initialDelaySeconds: 30
            periodSeconds: 15
---
apiVersion: v1
kind: Service
metadata:
  name: hive-metastore
spec:
  ports:
    - port: 9083
      targetPort: 9083
  selector:
    app: hive-metastore
```

### Helm Values Snippet

```yaml
hiveMetastore:
  enabled: true
  image:
    repository: seathegood/hive-metastore
    tag: latest
  env:
    POSTGRES_USER: hive
    POSTGRES_PASSWORD: hivepassword
    METASTORE_DB_HOST: postgres
    METASTORE_DB_PORT: 5432
    METASTORE_PORT: 9083
  service:
    type: ClusterIP
    port: 9083
```

---

## Contributing

We welcome contributions! See [CONTRIBUTING.md](./CONTRIBUTING.md) for details on local setup, testing, and release process.

---

## License

Apache License 2.0 — see the [LICENSE](./LICENSE) file.
