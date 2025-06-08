#!/bin/sh
tigrisfs ${SQLITE_REPLICA_BUCKET} ./data
./entrypoint.sh run