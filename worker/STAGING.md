# Stage the read-only workout page

Use the `jimgym-workout-prototype` Worker and a new `jimgym-staging` Turso database. Do not change Mealstack, jimgym on Fly, or an account-wide Access policy. Use only synthetic data. Start in the root of the [jimgym checkout](https://github.com/jimmernauts/jimgym).

## Create and protect the Worker

1. Confirm Wrangler is signed in to the Cloudflare account that hosts Mealstack and that the account can manage both Workers and Access. Do not use production database credentials.
2. Build and deploy the Worker **without secrets**. The checked-in configuration disables `workers.dev` and preview URLs and declares no routes or custom domains.

   ```sh
   cd "$(git rev-parse --show-toplevel)/worker"
   bun install --frozen-lockfile
   bun run test
   bunx wrangler deploy
   ```

3. In the [Cloudflare dashboard](https://dash.cloudflare.com/), open **Workers & Pages → jimgym-workout-prototype → Access → Protect this Worker behind Access**. Select **All traffic**. Allow only the owner's exact email address. Do not add a bypass rule. See [Protect one Worker](https://developers.cloudflare.com/workers/configuration/cloudflare-access/#protect-one-worker).
4. After the policy is active, enable only the `workers.dev` hostname in **Settings → Domains & Routes**. Keep preview URLs off. Copy the hostname from that screen. The checked-in configuration still turns the hostname off on a later `wrangler deploy`; if that happens, confirm Access is active again before re-enabling the hostname.
5. Open `https://<staging-host>/2026/11/9` in a private browser window. Expect an Access sign-in page, not a response from jimgym. Sign in with the owner account and expect `503 Workout history unavailable` until the database is connected. A signed-in account outside the policy must get an Access denial. If not, turn the hostname off and fix the policy before continuing.

## Connect synthetic data

Sign in with the [Turso CLI](https://docs.turso.tech/cli/introduction). Create a **new, empty** database in the intended organization. Stop if the name is in use; do not apply this seed to an existing database.

```sh
turso db create jimgym-staging
cat ../schema/schema.sql test/seed.sql | turso db shell jimgym-staging
turso db shell jimgym-staging 'SELECT (SELECT count(*) FROM gym_sessions) AS workouts, (SELECT count(*) FROM exercise_records) AS exercise_records;'
```

Expect two workouts and four exercise records. Set the database URL and a read-only token that expires in seven days. These commands pass the values into Wrangler without printing them to the terminal.

```bash
(
  set -euo pipefail
  turso db show jimgym-staging --url | bunx wrangler secret put TURSO_URL
  turso db tokens create jimgym-staging --read-only --expiration 7d | bunx wrangler secret put TURSO_AUTH_TOKEN
)
```

## Check before sharing the link

- Open `/2026/11/9` on the owner's phone. Expect **Test workout &lt;em&gt;**, two sets of eight Squats at 42.5 kg, one set of eight Press at 20 kg, and a 15-minute bike ride. Check that the page has its stylesheet.
- Confirm `/2026/11/10` works and `/2026/11/11` returns 404 for the owner. Close the session or open a private browser and check both the workout URL and `/jimgym.css` go through Access. Check that an account outside the policy is denied. Verify that there is no preview URL or other route.
- If any unauthorized client can reach the app, disable the staging hostname immediately. Fix and retest Access before enabling the hostname again. Do not move any production data at this stage.
