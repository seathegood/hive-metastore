FROM openjdk:8-jdk-slim

# Install required packages
RUN apt-get update && \
    apt-get install -y wget netcat && \
    rm -rf /var/lib/apt/lists/*

# Set environment variables
ENV HIVE_VERSION=3.1.3 \
    HIVE_HOME=/opt/hive \
    HADOOP_HOME=/opt/hadoop

# Download and extract Hive
RUN mkdir -p $HIVE_HOME && \
    wget -q https://downloads.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz -O /tmp/hive.tar.gz && \
    tar -xzf /tmp/hive.tar.gz -C /opt && \
    mv /opt/apache-hive-${HIVE_VERSION}-bin/* $HIVE_HOME && \
    rm -rf /tmp/hive.tar.gz

# Copy custom entrypoint and healthcheck scripts
COPY docker-entrypoint.sh /usr/local/bin/
COPY healthcheck.sh /usr/local/bin/

# Make scripts executable
RUN chmod +x /usr/local/bin/docker-entrypoint.sh /usr/local/bin/healthcheck.sh

# Copy JDBC driver (assumes you add it to your build context)
COPY mysql-connector-java.jar /opt/hive/lib/

# Set working directory
WORKDIR $HIVE_HOME

# Expose the default Hive Metastore port
EXPOSE 9083

# Set the entrypoint
ENTRYPOINT ["docker-entrypoint.sh"]

# Define health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=15s \
  CMD ["/usr/local/bin/healthcheck.sh"]
