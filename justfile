run:
  concurrently "bunx --bun @tailwindcss/cli -i ./src/jimgym.css -o ./priv/static/jimgym.css --watch" "watchexec --restart --verbose --wrap-process=session --stop-signal SIGTERM --exts gleam --debounce 500ms --watch src/ -- 'gleam run'"
deploy-local:
    docker build -t jimgym:latest .
    docker run --rm --name jimgym -p 8000:8000 --env-file .env jimgym:latest
deploy-fly:
    fly deploy --config fly.toml --remote-only
