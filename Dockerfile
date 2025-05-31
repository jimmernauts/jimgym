FROM erlang:28.0.0.0-alpine AS build
RUN apk add build-base && apk add sqlite
COPY --from=ghcr.io/gleam-lang/gleam:v1.10.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
ADD https://github.com/benbjohnson/litestream/releases/download/v0.3.13/litestream-v0.3.13-linux-amd64.tar.gz /tmp/litestream.tar.gz
RUN tar -C /usr/local/bin -xzf /tmp/litestream.tar.gz
RUN cd /app && gleam export erlang-shipment


FROM erlang:28.0.0.0-alpine
RUN \
    addgroup --system webapp && \
    adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
COPY --from=build /usr/local/bin/litestream /usr/local/bin/litestream
WORKDIR /app
ENTRYPOINT [ "litestream","replicate","-config","./jimgym/priv/litestream.yml","-exec","./entrypoint.sh run" ]
