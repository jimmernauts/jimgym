# Stage the read-only workout page

Use the `jimgym` Worker and a new `jimgym-staging` Turso database. Do not change Mealstack, jimgym on Fly, or an account-wide Access policy. Use only synthetic data.

## Verify Cloudflare Access

1. In the [Cloudflare dashboard](https://dash.cloudflare.com/), open **Workers & Pages → jimgym → Access**. Confirm the policy covers **All traffic**, allows only the owner's exact email address, and has no bypass rule. See [Protect one Worker](https://developers.cloudflare.com/workers/configuration/cloudflare-access/#protect-one-worker).
2. In **Settings → Domains & Routes**, confirm that [jimgym.jimmernauts.workers.dev](https://jimgym.jimmernauts.workers.dev) is the only hostname and that preview URLs are off. The checked-in Wrangler configuration still disables the hostname on a deploy. Do not redeploy for this check.
3. Open the [workout URL](https://jimgym.jimmernauts.workers.dev/2026/11/9) and [stylesheet URL](https://jimgym.jimmernauts.workers.dev/jimgym.css) in a private browser window. Expect Access to ask you to sign in or block the request, not return a response from jimgym. Sign in with the owner account and expect `503 Workout history unavailable` on the workout URL until the database is connected. A signed-in account outside the policy must get an Access denial. If not, turn the hostname off and fix the policy before continuing.

## Connect synthetic data

Sign in with the [Turso CLI](https://docs.turso.tech/cli/introduction). Create a **new, empty** database in the intended organization. Stop if the name is in use; do not apply this seed to an existing database.

```sh
cd "$(git rev-parse --show-toplevel)/worker"
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

- Open the [sample workout](https://jimgym.jimmernauts.workers.dev/2026/11/9) on the owner's phone. Expect **Test workout &lt;em&gt;**, two sets of eight Squats at 42.5 kg, one set of eight Press at 20 kg, and a 15-minute bike ride. Check that the page has its stylesheet.
- Confirm `/2026/11/10` works and `/2026/11/11` returns 404 for the owner. Close the session or open a private browser and check both the workout URL and `/jimgym.css` go through Access. Check that an account outside the policy is denied. Verify that there is no preview URL or other route.
- If any unauthorized client can reach the app, disable the staging hostname immediately. Fix and retest Access before enabling the hostname again. Do not move any production data at this stage.
