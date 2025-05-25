#!/bin/sh
set -eu


# Set HADOOP_HOME for schematool
export HADOOP_HOME=/opt/hadoop
export PATH="$HADOOP_HOME/bin:$PATH"

# Validate required environment variables
: "${POSTGRES_USER:?Missing POSTGRES_USER}"
: "${POSTGRES_PASSWORD:?Missing POSTGRES_PASSWORD}"
: "${METASTORE_DB_HOST:?Missing METASTORE_DB_HOST}"
: "${METASTORE_DB_PORT:?Missing METASTORE_DB_PORT}"
: "${METASTORE_PORT:?Missing METASTORE_PORT}"

# Build Postgres ConnectionURL
: "${METASTORE_DB_URL:=jdbc:postgresql://${METASTORE_DB_HOST}:${METASTORE_DB_PORT}/metastore_db}"

# If no custom hive-site.xml is mounted, generate one
if [ ! -f "$HIVE_HOME/conf/hive-site.xml" ]; then
  echo "Generating default hive-site.xml..."
  cat <<EOF > "$HIVE_HOME/conf/hive-site.xml"
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

# Wait for DB availability
echo "Waiting for PostgreSQL at ${METASTORE_DB_HOST}:${METASTORE_DB_PORT}..."
timeout=60
elapsed=0
until nc -z "${METASTORE_DB_HOST}" "${METASTORE_DB_PORT}"; do
  sleep 5
  elapsed=$((elapsed + 5))
  if [ "$elapsed" -ge "$timeout" ]; then
    echo "Error: Timed out waiting for ${METASTORE_DB_HOST}:${METASTORE_DB_PORT}"
    exit 1
  fi
done

# Initialize schema if needed
if ! "$HIVE_HOME/bin/schematool" -dbType postgres -info >/dev/null 2>&1; then
  echo "Initializing Hive schema..."
  "$HIVE_HOME/bin/schematool" -dbType postgres -initSchema
fi

# Launch Hive Metastore with logging
echo "Starting Hive Metastore..."
echo "Command: $HIVE_HOME/bin/hive --service metastore"
exec >> /opt/hive/logs/metastore.log 2>&1
exec "$HIVE_HOME/bin/hive" --service metastore 2>&1 | tee -a /opt/hive/logs/metastore.out
