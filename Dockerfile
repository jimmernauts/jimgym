FROM erlang:28.0.0.0-alpine AS build
RUN apk add build-base && apk add sqlite
RUN wget https://github.com/tigrisdata/tigrisfs/releases/download/v1.2.1/tigrisfs_1.2.1_linux_amd64.apk
RUN apk add tigrisfs_1.2.1_linux_amd64.apk --allow-untrusted
COPY --from=ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment


FROM erlang:28.0.0.0-alpine
RUN \
    addgroup --system webapp && \
    adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
COPY --from=build /usr/local/bin/tigrisfs /usr/local/bin/tigrisfs
WORKDIR /app
## NEEDS BUILD ARG?
RUN tigrisfs ${SQLITE_REPLICA_BUCKET} ./data
ENTRYPOINT [ "./entrypoint.sh","run" ]
