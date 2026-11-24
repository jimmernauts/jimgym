# jimgym Worker

The local Worker serves the existing home screen, calendar, workout preview, workout editor, and template setup. It can create and update workouts and templates. The Wrangler configuration does not enable a public route.

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

Open [the calendar](http://127.0.0.1:8787/2026/11), select an empty date, and choose a workout family. Pick activities from the family shortlist or choose an earlier workout in that family to copy its sets and durations. Manage the family shortlists in Setup. Earlier workouts match the family by name.

The editor groups sets by exercise. Use **Move up** or **Move down** and save the workout to keep the new order. Use **History** to open a new tab and see up to eight earlier workouts for an exercise without losing edits. The fixture uses the app’s schema with synthetic data only.

The local Worker does not use Cloudflare Access. For staging, use a separate Turso database and store its token as a Worker secret. Do not use Mealstack or production jimgym data.

## Merge the workout families

`merge-workout-families.sql` replaces the `Whole Body A` and `Whole Body C` templates with `Whole Body`, and creates a `Legs` template. The Worker still offers earlier A and C workouts in the Whole Body clone picker. The change does not rename any recorded workouts or exercises. It leaves `Whole Body B`, `Whole Body Full`, `Cardio`, and `Ride` history unchanged.

Apply this SQL only once per database, in one transaction. Before applying it to Turso, rehearse on a copy of that database. Check that both old templates exist and neither `Whole Body` nor `Legs` exists. Verify that the new templates have 10 and 12 exercises, respectively, and that historical rows have not changed. Deploy the Worker to dev before changing dev data. Do not change production until the split is reviewed.

## Verify a database import

Run the verifier from the Worker directory with a consistent SQLite snapshot. Use a newly imported, separate Turso database, not the existing synthetic database. Keep writes paused on the target while comparing. The verifier only reads data and does not print workout contents.

```sh
turso db create jimgym-rehearsal --from-file /secure/path/jimgym-snapshot.db
bun --env-file=.dev.vars.verify verify-migration.mjs /secure/path/jimgym-snapshot.db --turso
```

Set `TURSO_URL` and a read-only `TURSO_AUTH_TOKEN` for the imported database in the ignored `.dev.vars.verify` file. To compare two local snapshot files instead, supply the second file path in place of `--turso`. Do not proceed to cutover if counts, row digests, date range, ID sequences, or record links fail the check.
