FROM erlang:28.0.0.0-alpine AS build
RUN apk add --no-cache build-base sqlite
COPY --from=ghcr.io/gleam-lang/gleam:v1.13.0-erlang-alpine /bin/gleam /bin/gleam
WORKDIR /app

# 1) Deps metadata first (cacheable)
COPY gleam.toml manifest.toml ./
# If you have any lock/manifest files, include them here
# Pre-fetch deps (faster and cacheable)
RUN --mount=type=cache,target=/root/.cache/gleam \
    gleam deps download

# 2) App source next (only invalidates when code changes)
COPY src/ ./src/
COPY schema/ ./schema/
COPY priv/ ./priv/
# Avoid copying non-build assets (like priv/wrapper.sh) into build stage

# 3) Compile/export (cached if src/ unchanged)
RUN --mount=type=cache,target=/root/.cache/gleam \
    gleam export erlang-shipment


FROM erlang:28.0.0.0-alpine
RUN \
    addgroup --system webapp && \
    adduser --system webapp -g webapp
WORKDIR /app

COPY --from=build /app/build/erlang-shipment /app
COPY --from=build /app/schema /app/schema
COPY /entrypoint_wrapper.sh /app/entrypoint_wrapper.sh
RUN chmod +x /app/entrypoint_wrapper.sh

COPY --from=ghcr.io/amacneil/dbmate:latest /usr/local/bin/dbmate /bin/dbmate

ENTRYPOINT [ "./entrypoint_wrapper.sh" ]
CMD ["run"]
