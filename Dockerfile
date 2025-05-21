FROM openjdk:8-jdk-slim

# Set build-time arguments
ARG HIVE_VERSION=3.1.3
ARG BUILD_DATE
ARG VCS_REF
ARG HIVE_TARBALL_SHA256

# Set environment variables
ENV HIVE_VERSION=${HIVE_VERSION} \
    HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop \
    JAVA_TOOL_OPTIONS="-Djava.security.egd=file:/dev/urandom" \
    PG_JDBC_VERSION=42.7.3 \
    HIVE_TARBALL_SHA256=${HIVE_TARBALL_SHA256}

# Add OCI-compliant image labels
LABEL \
  org.opencontainers.image.vendor="Sea the Good, LLC" \
  org.opencontainers.image.url="https://github.com/seathegood/hive-metastore" \
  org.opencontainers.image.title="Hive Metastore" \
  org.opencontainers.image.description="Minimal Hive Metastore image using an external PostgreSQL database" \
  org.opencontainers.image.version=${HIVE_VERSION} \
  org.opencontainers.image.source="https://github.com/seathegood/hive-metastore" \
  org.opencontainers.image.licenses="Apache-2.0" \
  org.opencontainers.image.created=${BUILD_DATE} \
  org.opencontainers.image.revision=${VCS_REF}

# Install and configure all dependencies in a single layer
RUN apt-get update && \
    apt-get install -y wget netcat ca-certificates jq && \
    mkdir -p $HIVE_HOME && \
    wget -q https://downloads.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz -O /tmp/hive.tar.gz && \
    echo "$HIVE_TARBALL_SHA256  /tmp/hive.tar.gz" | sha256sum -c - && \
    tar -xzf /tmp/hive.tar.gz -C /opt && \
    mv /opt/apache-hive-${HIVE_VERSION}-bin/* $HIVE_HOME && \
    rm -rf /tmp/hive.tar.gz && \
    wget -q https://jdbc.postgresql.org/download/postgresql-${PG_JDBC_VERSION}.jar -O /tmp/driver.jar && \
    echo "2f658167b98f9f9992fd313db43d888a46ea01f85f49a81e33b1f59a8354bdbb  /tmp/driver.jar" | sha256sum -c - && \
    mv /tmp/driver.jar /opt/hive/lib/postgresql-jdbc.jar && \
    rm -f /tmp/driver.jar && \
    apt-get purge -y --auto-remove wget netcat && \
    apt-get clean && \
    chmod -R go-rwx $HIVE_HOME

# Create non-root hive user
RUN groupadd -r hive && useradd --no-log-init -r -g hive hive && \
    chown -R hive:hive $HIVE_HOME

# Copy custom entrypoint and healthcheck scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY healthcheck.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Set working directory
WORKDIR $HIVE_HOME

# Switch to non-root user
USER hive

# Optional volumes for logs and temp files
VOLUME ["/opt/hive/logs", "/opt/hive/tmp"]

# Expose the default Hive Metastore port
EXPOSE 9083

# Set the entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Define health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s \
  CMD ["/usr/local/bin/healthcheck.sh"]
