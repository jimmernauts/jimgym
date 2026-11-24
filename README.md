# jimgym

jimgym tracks gym workouts and templates. Gleam and Lustre render HTML on a Cloudflare Worker. The Worker reads and writes a Turso database. Cloudflare Access controls sign-in, and [fixi.js](https://github.com/bigskysoftware/fixi) handles short page updates. The live site is [jimgym.jimmernauts.workers.dev](https://jimgym.jimmernauts.workers.dev).

## Develop and release

| Stage | Worker | Database | What to check |
|---|---|---|---|
| Local | Wrangler on localhost | Synthetic SQLite fixture | Run the tests. Use the browser to exercise the changed workflow. |
| Dev | Shared Cloudflare Workers Preview named `dev` ([dev site](https://dev-jimgym.jimmernauts.workers.dev)) | `jimgym-dev` in Turso | Check the release on Cloudflare: sign in, open the changed screens, and test saves against dev only. |
| Prod | Existing `jimgym` Worker behind Access | `jimgym-prod` in Turso | Release the same tested commit. Check sign-in and confirm a known workout opens. |

Start with the [local run instructions](worker/README.md). Run `bun run test` from the `worker` directory. Local tests do not need cloud credentials. Keep production credentials out of local development, Git, and chat.

### Dev setup

Use one [Workers Preview](https://developers.cloudflare.com/workers/previews/) named `dev` under the existing `jimgym` Worker. Each preview deployment replaces the code on that shared preview. It does not deploy production. Do not change the production Turso secrets to test a feature.

For initial setup, create the preview without database secrets. In the Cloudflare dashboard, protect `jimgym` preview traffic with owner-only Access without changing the existing production rule. Verify signed-out requests to the preview page and stylesheet are blocked before adding any secrets. [Preview URLs are public by default](https://developers.cloudflare.com/workers/previews/custom-domains/#protect-preview-content). Do not use a production Version URL as the dev preview.

From the `worker` directory, build and upload the tested commit to the same preview every time:

```sh
bun run test
bunx wrangler preview --name dev --ignore-base-config
```

Once Access is verified, set `TURSO_URL` and `TURSO_AUTH_TOKEN` on `dev` only with `wrangler preview secret put SECRET_NAME --name dev`. Use a write token scoped to `jimgym-dev` so you can test saves. Do not put either value in the Preview Base configuration. Check signed-out access after each deployment. Sign in and test new behavior in dev before releasing the same commit to production. All dev releases share one database, so apply and test schema migrations there before production.

### Production release

Releases are manual. From the tested commit, run the Worker tests again, then upload a production Worker version. Confirm the target is `jimgym` and the secret bindings are present. Deploy that version without changing routes or the Access policy:

```sh
cd "$(git rev-parse --show-toplevel)/worker"
bun install --frozen-lockfile
bun run test
bunx wrangler versions upload
bunx wrangler versions view NEW_VERSION_ID
bunx wrangler versions deploy NEW_VERSION_ID@100% --yes
bunx wrangler deployments status
```

Replace `NEW_VERSION_ID` with the ID from the upload. Before deploying, check that `versions view` lists both `TURSO_URL` and `TURSO_AUTH_TOKEN` as secrets. Record the prior and new version IDs. Check that signed-out requests to a workout page and its stylesheet still redirect to Access. Sign in and open a known workout including its sets. If the code release fails, redeploy the prior version if it is compatible with the current schema and secrets. A Worker rollback does not reverse Turso writes or schema changes. Take a verified database backup before a production schema migration.

Use the version commands, not `wrangler deploy` or `wrangler triggers deploy`, for a code-only production release. The checked-in Wrangler configuration disables `workers.dev` if applied as a trigger change. Do not change the production Worker’s routes or the preview routing settings as part of a code release. A push to `main` does not deploy production.

See the [database verification instructions](worker/README.md#verify-a-database-import) for the read-only checks used during migration.
