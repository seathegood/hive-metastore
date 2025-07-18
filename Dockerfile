# Stage 1: Builder - fetch and validate Hive, Hadoop, and JDBC
FROM eclipse-temurin:21-jdk-alpine AS builder

ARG HIVE_VERSION=4.0.1
ARG HADOOP_VERSION=3.4.1
ARG PG_JDBC_VERSION=42.7.5

ENV HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop

COPY versions.json /opt/versions.json

RUN apk update && apk add --no-cache \
    bash \
    wget \
    openssl \
    ca-certificates \
    jq

WORKDIR /build

# Download and verify Hive
RUN wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz && \
    wget -q https://dlcdn.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    sha256sum -c apache-hive-${HIVE_VERSION}-bin.tar.gz.sha256 && \
    tar -xzf apache-hive-${HIVE_VERSION}-bin.tar.gz

# Download and verify Hadoop
RUN wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz && \
    wget -q https://dlcdn.apache.org/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    sha512sum -c hadoop-${HADOOP_VERSION}.tar.gz.sha512 && \
    tar -xzf hadoop-${HADOOP_VERSION}.tar.gz

# Download and verify JDBC driver
RUN PG_JDBC_SHA256=$(jq -r --arg ver "${PG_JDBC_VERSION}" '.postgresql[$ver].sha256' /opt/versions.json) && \
    wget -q https://jdbc.postgresql.org/download/postgresql-${PG_JDBC_VERSION}.jar -O postgresql-jdbc.jar && \
    echo "${PG_JDBC_SHA256}  postgresql-jdbc.jar" | sha256sum -c -

# Stage 2: Runtime - minimal and secure image
FROM eclipse-temurin:21-jdk-alpine AS runtime

ARG HIVE_VERSION=4.0.1
ARG HADOOP_VERSION=3.4.1
ARG PG_JDBC_VERSION=42.7.5
ARG BUILD_DATE
ARG VCS_REF

ENV HIVE_VERSION=${HIVE_VERSION} \
    HADOOP_VERSION=${HADOOP_VERSION} \
    PG_JDBC_VERSION=${PG_JDBC_VERSION} \
    HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop \
    JAVA_TOOL_OPTIONS="-Djava.security.egd=file:/dev/urandom" \
    PATH="/opt/hadoop/bin:$PATH"

# OCI-compliant labels
LABEL org.opencontainers.image.vendor="Sea the Good, LLC" \
      org.opencontainers.image.url="https://github.com/seathegood/hive-metastore" \
      org.opencontainers.image.title="Hive Metastore" \
      org.opencontainers.image.description="Minimal Hive Metastore image using an external PostgreSQL database" \
      org.opencontainers.image.version=${HIVE_VERSION} \
      org.opencontainers.image.source="https://github.com/seathegood/hive-metastore" \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.created=${BUILD_DATE} \
      org.opencontainers.image.revision=${VCS_REF}

RUN apk update && apk add --no-cache \
    bash \
    netcat-openbsd \
    ca-certificates

# Create non-root user and working directories
RUN addgroup -S hive && \
    adduser -S -G hive hive && \
    mkdir -p $HIVE_HOME $HADOOP_HOME /opt/hive/logs /opt/hive/tmp && \
    chown -R hive:hive $HIVE_HOME $HADOOP_HOME /opt/hive/logs /opt/hive/tmp

# Copy validated binaries and configs from builder stage
COPY --from=builder /build/apache-hive-${HIVE_VERSION}-bin/ $HIVE_HOME/
COPY --from=builder /build/hadoop-${HADOOP_VERSION}/ $HADOOP_HOME/
COPY --from=builder /build/postgresql-jdbc.jar $HIVE_HOME/lib/postgresql-jdbc.jar

# Secure permissions
RUN chmod -R go-rwx $HIVE_HOME $HADOOP_HOME

# Entry scripts and healthcheck
ARG TARGETARCH
COPY --chmod=0755 --chown=hive:hive docker-entrypoint.sh /usr/local/bin/docker-entrypoint-${TARGETARCH}.sh
RUN mv /usr/local/bin/docker-entrypoint-${TARGETARCH}.sh /usr/local/bin/docker-entrypoint.sh && \
    sed -i 's/\r$//' /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

COPY --chmod=0755 --chown=hive:hive healthcheck.sh /usr/local/bin/healthcheck.sh
RUN sed -i 's/\r$//' /usr/local/bin/healthcheck.sh && \
    chmod +x /usr/local/bin/healthcheck.sh

WORKDIR $HIVE_HOME
USER hive

VOLUME ["/opt/hive/logs", "/opt/hive/tmp"]
EXPOSE 9083

ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
HEALTHCHECK --interval=30s --timeout=10s --start-period=60s \
  CMD ["/usr/local/bin/healthcheck.sh"]
