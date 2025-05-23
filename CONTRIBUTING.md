

# Contributing to Hive Metastore

Thanks for your interest in contributing! This project provides a lightweight containerized Apache Hive Metastore backed by PostgreSQL.

## 🛠 Development Setup

To set up locally:

1. Clone the repository:
   ```bash
   git clone https://github.com/seathegood/hive-metastore.git
   cd hive-metastore
   ```

2. Review and update the `.env` file if needed:
   This file centralizes environment settings for GitHub Actions and local builds.

3. Build the image locally:
   ```bash
   ./build.sh
   ```

4. Run the container (requires PostgreSQL running):
   ```bash
   docker run --rm -e METASTORE_DB_HOST=localhost -e METASTORE_DB_PORT=5432 \
     -e METASTORE_DB_NAME=metastore_db -e METASTORE_DB_USER=hive -e METASTORE_DB_PASSWORD=password \
     -p 9083:9083 hive-metastore:4.0.1
   ```

## ✅ CI/CD

This project uses GitHub Actions for automation:

- `ci.yml`: Validates builds and runs integration tests
- `check-upstream.yml`: Auto-detects new Hive versions and triggers updates
- `publish.yml`: Builds and pushes images on new GitHub Releases

## 🔄 Updating Versions

1. Use `versions.json` to track Hive and JDBC versions and their SHA256 hashes.
2. Run `build.sh` to add new versions — it auto-fetches SHAs from Apache if missing.
3. Commit changes and push to `main`.

## 🧪 Testing

CI tests automatically run on all PRs and main branch updates. They:
- Build the image
- Start PostgreSQL
- Launch the metastore and verify health
- Upload logs and artifacts for analysis

## 🚀 Releasing

1. Tag a release (e.g., `v4.0.1`) via GitHub or `git tag && git push origin tag`.
2. This triggers `publish.yml` to build and publish the image.

## 🤝 Contributions Welcome

Open issues and PRs are welcome. Please follow conventional commits and keep your changes scoped and well-documented.