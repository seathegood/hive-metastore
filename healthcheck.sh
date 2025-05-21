#!/bin/bash

# Use netcat to test if the Hive Metastore port is accepting connections
if nc -z localhost 9083; then
  exit 0
else
  echo "Hive Metastore is not responding on port 9083"
  exit 1
fi
