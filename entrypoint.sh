#!/bin/sh
set -euo pipefail

echo "Starting Hive Metastore container..."

# Set required defaults and paths
export HADOOP_HOME=${HADOOP_HOME:-/opt/hadoop}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-$HADOOP_HOME/conf}
export HADOOP_HDFS_HOME=${HADOOP_HDFS_HOME:-/opt/hadoop}
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


echo "Listing Hive libraries:"
find "$HIVE_HOME/lib" -type f -name "*.jar" | sort

echo "Listing Hadoop libraries:"
find "$HADOOP_HOME" -type f -name "*.jar" | sort

echo "Listing Hadoop config files:"
find "$HADOOP_CONF_DIR" -type f | sort

echo "Listing Hadoop bin scripts:"
find "$HADOOP_HOME/bin" -type f | sort

# Ensure log directories exist
mkdir -p "$HIVE_HOME/logs" "$HIVE_HOME/tmp" "$HIVE_CONF_DIR"

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
if ! "$HIVE_HOME/bin/schematool" -dbType postgres -info --verbose | grep -q 'Metastore schema version:'; then
  echo "No schema detected. Initializing Hive schema..."
  HADOOP_CLASSPATH=$(find "$HADOOP_HOME" "$HIVE_HOME/lib" -name '*.jar' | tr '\n' ':' | sed 's/:$//')
  echo "HADOOP_CLASSPATH set to:"
  echo "$HADOOP_CLASSPATH" | tr ':' '\n'
  export HADOOP_CLASSPATH
  "$HIVE_HOME/bin/schematool" -dbType postgres -initSchemaTo 4.0.0 --verbose
else
  echo "Hive schema already initialized."
fi

# Handle SIGTERM/SIGINT
cleanup() {
  echo "Received termination signal. Stopping Hive Metastore..."
  kill "$pid"
  wait "$pid"
  echo "Hive Metastore stopped."
  exit 0
}
trap cleanup TERM INT

# Start Hive Metastore in background
echo "Launching Hive Metastore on port $METASTORE_PORT..."
"$HIVE_HOME/bin/hive" --service metastore &
pid=$!
wait "$pid"
