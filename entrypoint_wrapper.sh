#!/bin/sh
set -e
mkdir -p /data
dbmate create
dbmate up
exec ./entrypoint.sh "$@"