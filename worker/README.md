# jimgym Worker prototype

This local prototype renders one workout history page with the same Lustre history view as the Fly app. It does not support writes, the calendar, or template setup. There is no public Worker route in `wrangler.jsonc`. Do not add one until owner-only Cloudflare Access is in place and verified.

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

Open [the example workout](http://127.0.0.1:8787/2026/11/9). The fixture uses the app's schema and does not read any existing workout data. The local Worker does not use Cloudflare Access. For staging, use a separate Turso database and store its token as a Worker secret. Do not use either Mealstack or production jimgym data for the first staging check.
