#!/bin/sh
set -euo pipefail

echo "Starting Hive Metastore container..."

# Set required defaults and paths
export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
export HIVE_HOME=${HIVE_HOME:-/opt/hive}
export HIVE_CONF_DIR=${HIVE_CONF_DIR:-$HIVE_HOME/conf}
export PATH="$HADOOP_HOME/bin:$PATH"

# Validate required environment variables
: "${POSTGRES_USER:?Missing POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}"
: "${METASTORE_DB_HOST:?Missing METASTORE_DB_HOST}"
: "${METASTORE_DB_PORT:?Missing METASTORE_DB_PORT}"
: "${METASTORE_PORT:?Missing METASTORE_PORT}"

# Compose JDBC connection string
: "${METASTORE_DB_URL:=jdbc:postgresql://${METASTORE_DB_HOST}:${METASTORE_DB_PORT}/metastore_db}"

# Log config
echo "Hive Home:       $HIVE_HOME"
echo "Hive Config:     $HIVE_CONF_DIR"
echo "Metastore Port:  $METASTORE_PORT"
echo "DB Host:         $METASTORE_DB_HOST"
echo "JDBC URL:        $METASTORE_DB_URL"

# If no custom hive-site.xml is mounted, generate one
if [ ! -f "$HIVE_CONF_DIR/hive-site.xml" ]; then
  echo "Generating default hive-site.xml..."
  cat <<EOF > "$HIVE_CONF_DIR/hive-site.xml"
<configuration>
  <property>
    <name>javax.jdo.option.ConnectionURL</name>
    <value>${METASTORE_DB_URL}</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionDriverName</name>
    <value>org.postgresql.Driver</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionUserName</name>
    <value>${POSTGRES_USER}</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>${POSTGRES_PASSWORD}</value>
  </property>
  <property>
    <name>datanucleus.schema.autoCreateAll</name>
    <value>true</value>
  </property>
  <property>
    <name>hive.metastore.uris</name>
    <value>thrift://0.0.0.0:${METASTORE_PORT}</value>
  </property>
</configuration>
EOF
else
  echo "Using mounted hive-site.xml"
fi

# Wait for the Postgres DB to be ready
echo "Waiting for PostgreSQL at ${METASTORE_DB_HOST}:${METASTORE_DB_PORT}..."
timeout=60
elapsed=0
while ! nc -z "${METASTORE_DB_HOST}" "${METASTORE_DB_PORT}"; do
  echo "  ...still waiting (${elapsed}s elapsed)"
  sleep 5
  elapsed=$((elapsed + 5))
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Timed out waiting for PostgreSQL"
    exit 1
  fi
done

# Initialize schema if not already present
if ! "$HIVE_HOME/bin/schematool" -dbType postgres -info >/dev/null 2>&1; then
  echo "No schema detected. Initializing Hive schema..."
  "$HIVE_HOME/bin/schematool" -dbType postgres -initSchema
else
  echo "Hive schema already initialized."
fi

# Ensure log directories exist
mkdir -p "$HIVE_HOME/logs" "$HIVE_HOME/tmp"
touch "$HIVE_HOME/logs/metastore.log" "$HIVE_HOME/logs/metastore.out"
chown hive:hive "$HIVE_HOME/logs"/*.log || true

# Launch Hive Metastore
echo "Launching Hive Metastore..."
exec >> "$HIVE_HOME/logs/metastore.log" 2>&1
exec "$HIVE_HOME/bin/hive" --service metastore 2>&1 | tee -a "$HIVE_HOME/logs/metastore.out"
