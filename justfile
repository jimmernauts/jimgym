run:
  concurrently "bunx --bun @tailwindcss/cli -i ./src/jimgym.css -o ./priv/static/jimgym.css --watch" "watchexec --restart --verbose --wrap-process=session --stop-signal SIGTERM --exts gleam --debounce 500ms --watch src/ -- 'gleam run'"

replicate:
  # copy from ./priv/data to ./data
  # then run replicate over just run
  cp -r ./priv/data_seed ./data
  litestream replicate -config ./priv/litestream.yml -exec "just run"