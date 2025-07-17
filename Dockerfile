FROM eclipse-temurin:21-jdk-alpine AS base

SHELL ["/bin/sh", "-c"]

# Set build-time arguments
ARG HIVE_VERSION=4.0.1
ARG HADOOP_VERSION=3.4.1
ARG BUILD_DATE
ARG VCS_REF
ARG HIVE_TARBALL_SHA256
ARG PG_JDBC_VERSION=42.7.5

# Set environment variables
ENV HIVE_VERSION=${HIVE_VERSION} \
    HADOOP_VERSION=${HADOOP_VERSION} \
    PG_JDBC_VERSION=${PG_JDBC_VERSION} \
    HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop \
    JAVA_TOOL_OPTIONS="-Djava.security.egd=file:/dev/urandom" \
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
RUN apk update && apk upgrade && apk add --no-cache \
    bash \
    wget \
    netcat-openbsd \
    openssl \
    ca-certificates \
    jq
      
# Install Hive, Hadoop, and JDBC driver
RUN mkdir -p $HIVE_HOME && \
    cd /tmp && \
    wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    sha256sum -c apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz -C /opt && \
    mv /opt/apache-hive-${HIVE_VERSION}-bin/* $HIVE_HOME && \
    PG_JDBC_SHA256=$(jq -r --arg ver "$PG_JDBC_VERSION" '.postgresql[$ver].sha256' /opt/versions.json) && \
    wget -q https://jdbc.postgresql.org/download/postgresql-${PG_JDBC_VERSION}.jar -O /tmp/driver.jar && \
    echo "${PG_JDBC_SHA256}  /tmp/driver.jar" | sha256sum -c - && \
    mv /tmp/driver.jar /opt/hive/lib/postgresql-jdbc.jar && \
    test -f /opt/hive/lib/postgresql-jdbc.jar && \
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    sha512sum -c hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz -C /opt && \
    mv /opt/hadoop-${HADOOP_VERSION} $HADOOP_HOME && \
    rm -rf /tmp/* && \
    chmod -R go-rwx $HIVE_HOME $HADOOP_HOME

# Add non-root hive user and set ownership
RUN addgroup -S hive && \
    adduser -S -G hive hive && \
    chown -R hive:hive $HIVE_HOME $HADOOP_HOME && \
    mkdir -p /opt/hive/logs /opt/hive/tmp && \
    chown -R hive:hive /opt/hive/logs /opt/hive/tmp

# Entrypoint and healthcheck
ARG TARGETARCH
COPY --chmod=0755 --chown=hive:hive docker-entrypoint.sh /usr/local/bin/docker-entrypoint-${TARGETARCH}.sh
RUN mv /usr/local/bin/docker-entrypoint-${TARGETARCH}.sh /usr/local/bin/docker-entrypoint.sh && \
    sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

COPY --chmod=0755 --chown=hive:hive healthcheck.sh /usr/local/bin/healthcheck.sh
RUN sed -i 's/\r$//' /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh


# Set working directory and user
WORKDIR $HIVE_HOME
USER hive

# Volume mounts (optional)
VOLUME ["/opt/hive/logs", "/opt/hive/tmp"]

# Expose the default Hive Metastore port
EXPOSE 9083

# Set the entrypoint
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Define health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD ["/usr/local/bin/healthcheck.sh"]
