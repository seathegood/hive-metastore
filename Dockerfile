FROM eclipse-temurin:21-jdk-alpine

SHELL ["/bin/sh", "-c"]

# Set build-time arguments
ARG HIVE_VERSION=4.0.1
ARG HADOOP_VERSION=3.4.1
ARG BUILD_DATE
ARG VCS_REF
ARG HIVE_TARBALL_SHA256

# Set environment variables
ENV HIVE_VERSION=${HIVE_VERSION} \
    HADOOP_VERSION=${HADOOP_VERSION} \
    HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop \
    JAVA_TOOL_OPTIONS="-Djava.security.egd=file:/dev/urandom" \
    PG_JDBC_VERSION=42.7.5 \
    PATH="/opt/hadoop/bin:$PATH"

COPY versions.json /opt/versions.json

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
RUN apk update && \
    apk upgrade && \
    apk add --no-cache \
      bash \
      coreutils \
      shadow \
      wget \
      netcat-openbsd \
      openssl \
      ca-certificates \
      jq
      
SHELL ["/bin/bash", "-c"]
      
RUN mkdir -p $HIVE_HOME && \
    cd /tmp && \
    wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    sha256sum -c apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz -C /opt && \
    mv /opt/apache-hive-${HIVE_VERSION}-bin/* $HIVE_HOME && \
    rm -rf /tmp/apache-hive-${HIVE_VERSION}-bin.tar.gz /tmp/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    PG_JDBC_SHA256=$(jq -r --arg ver "$PG_JDBC_VERSION" '.postgresql[$ver].sha256' /opt/versions.json) && \
    wget -q https://jdbc.postgresql.org/download/postgresql-${PG_JDBC_VERSION}.jar -O /tmp/driver.jar && \
    echo "${PG_JDBC_SHA256}  /tmp/driver.jar" | sha256sum -c - && \
    mv /tmp/driver.jar /opt/hive/lib/postgresql-jdbc.jar && \
    test -f /opt/hive/lib/postgresql-jdbc.jar && \
    rm -f /tmp/driver.jar && \
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    sha512sum -c hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -rf /tmp/hadoop-${HADOOP_VERSION}.tar.gz /tmp/hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    apk del wget netcat-openbsd && \
    rm -rf /var/cache/apk/* && \
    chmod -R go-rwx $HIVE_HOME && \
    chmod -R go-rwx $HADOOP_HOME

# Create non-root hive user and set ownership
RUN groupadd -r hive && useradd --no-log-init -r -g hive hive && \
    chown -R hive:hive $HIVE_HOME && \
    chown -R hive:hive $HADOOP_HOME && \
    mkdir -p /opt/hive/logs /opt/hive/tmp && \
    chown -R hive:hive /opt/hive/logs /opt/hive/tmp

ARG TARGETARCH
COPY --chown=hive:hive docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN echo "$TARGETARCH" > /tmp/arch.txt && \
    cat /tmp/arch.txt && \
    sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh && \
    echo "First few lines:" && head -n 5 /usr/local/bin/docker-entrypoint.sh && \
    echo "Byte content:" && cat -A /usr/local/bin/docker-entrypoint.sh | head -n 10

COPY --chown=hive:hive healthcheck.sh /usr/local/bin/healthcheck.sh
RUN echo "$TARGETARCH" > /tmp/arch-health.txt && \
    cat /tmp/arch-health.txt && \
    sed -i 's/\r$//' /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh && \
    echo "First few lines:" && head -n 5 /usr/local/bin/healthcheck.sh && \
    echo "Byte content:" && cat -A /usr/local/bin/healthcheck.sh | head -n 10

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
