FROM erlang:28.0.0.0-alpine AS build
RUN apk add build-base && apk add sqlite

COPY --from=ghcr.io/gleam-lang/gleam:v1.12.0-erlang-alpine /bin/gleam /bin/gleam
COPY . /app/
RUN cd /app && gleam export erlang-shipment


FROM erlang:28.0.0.0-alpine
RUN \
    addgroup --system webapp && \
    adduser --system webapp -g webapp
COPY --from=build /app/build/erlang-shipment /app
WORKDIR /app
ENTRYPOINT [ "./entrypoint.sh" ]
