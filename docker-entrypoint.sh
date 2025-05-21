#!/bin/bash
set -e

# Create hive-site.xml with PostgreSQL configuration
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

# Wait for DB to be available
echo "Waiting for PostgreSQL at ${METASTORE_DB_HOST}:${METASTORE_DB_PORT}..."
until nc -z "${METASTORE_DB_HOST}" "${METASTORE_DB_PORT}"; do
  sleep 5
done

# Initialize schema if needed
$HIVE_HOME/bin/schematool -dbType postgres -initSchema || true

# Start the Hive metastore
exec $HIVE_HOME/bin/hive --service metastore
