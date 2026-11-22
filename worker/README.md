# jimgym Worker

The local Worker serves the existing home screen, calendar, workout preview, and workout editor. It can create and update workouts. The setup screen lists templates but cannot edit them yet. The Wrangler configuration does not enable a public route.

Run these commands from the `worker` directory. Install Gleam, Bun, and Node.js (22.12 or later).

```sh
bun install --frozen-lockfile
bun run test
```

To open the prototype in a browser, start the synthetic SQLite fixture in one terminal:

```sh
bun test/fixture.mjs 8790
```

In a second terminal, start the Worker. These are fixture values, not production credentials:

```sh
bun run dev --ip 127.0.0.1 --var TURSO_URL:http://127.0.0.1:8790 --var TURSO_AUTH_TOKEN:synthetic-test-token
```

Open [the calendar](http://127.0.0.1:8787/2026/11), select an empty date, and choose a template. Edit the workout, then use the save button. The fixture uses the app’s schema and synthetic workouts and templates. It does not read or change existing workout data.

The local Worker does not use Cloudflare Access. For staging, use a separate Turso database and store its token as a Worker secret. Do not use Mealstack or production jimgym data.
