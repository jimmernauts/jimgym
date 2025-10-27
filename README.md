# jimgym

This is the repository for jimgym, a web application for managing and tracking gym workouts.

Written in Gleam compiling to the Erlang backend, using Lustre for server-side rendered HTML.

[fixi.js](https://github.com/bigskysoftware/fixi) is used for client-side interactivity.
Some client-side interactions that manipulate the DOM without server interaction (eg: adding a new form field for a new exercise entry) are written in JavaScript as [fixi extensions](https://github.com/bigskysoftware/fixi) in `priv/static/ext-fixi.js`.

A SQLite database is used for data storage. It is located at data/ relative to the project root. In production, this is overriden using an env var (DATABASE_URL and DATABASE_PATH) to the /data/ absolute path, which points to a fly volume. No additional database backup or syncing is currently used.

A Github Actions workflow is used to build and deploy the application to Fly.io on every push to main.

Just task runner has a couple of simple commands for local development.
