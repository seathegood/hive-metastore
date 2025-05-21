#!/bin/bash
set -e

# Validate required environment variables
: "${METASTORE_DB_URL:?Missing METASTORE_DB_URL}"
: "${METASTORE_DB_USER:?Missing METASTORE_DB_USER}"
: "${METASTORE_DB_PASS:?Missing METASTORE_DB_PASS}"
: "${METASTORE_DB_HOST:?Missing METASTORE_DB_HOST}"
: "${METASTORE_DB_PORT:?Missing METASTORE_DB_PORT}"

# If no custom hive-site.xml is mounted, generate one
if [ ! -f "$HIVE_HOME/conf/hive-site.xml" ]; then
  echo "Generating default hive-site.xml..."
  cat <<EOF > $HIVE_HOME/conf/hive-site.xml
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
    <value>${METASTORE_DB_USER}</value>
  </property>
  <property>
    <name>javax.jdo.option.ConnectionPassword</name>
    <value>${METASTORE_DB_PASS}</value>
  </property>
  <property>
    <name>datanucleus.schema.autoCreateAll</name>
    <value>true</value>
  </property>
</configuration>
EOF
else
  echo "Using mounted hive-site.xml"
fi

# Wait for DB availability
echo "Waiting for PostgreSQL at ${METASTORE_DB_HOST}:${METASTORE_DB_PORT}..."
until nc -z "${METASTORE_DB_HOST}" "${METASTORE_DB_PORT}"; do
  sleep 5
done

# Initialize schema if needed
$HIVE_HOME/bin/schematool -dbType postgres -initSchema || true

# Launch Hive Metastore with logging
echo "Starting Hive Metastore..."
exec $HIVE_HOME/bin/hive --service metastore >> /opt/hive/logs/metastore.log 2>&1
