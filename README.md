# jimgym

jimgym tracks gym workouts and templates. Gleam and Lustre render HTML on a Cloudflare Worker. The Worker reads and writes a Turso database. Cloudflare Access controls sign-in, and [fixi.js](https://github.com/bigskysoftware/fixi) handles short page updates. The live site is [jimgym.jimmernauts.workers.dev](https://jimgym.jimmernauts.workers.dev).

## Develop and release

| Stage | Worker | Database | What to check |
|---|---|---|---|
| Local | Wrangler on localhost | Synthetic SQLite fixture | Run the tests. Use the browser to exercise the changed workflow. |
| Dev | Separate, Access-protected `jimgym-dev` Worker **(not set up yet)** | `jimgym-dev` in Turso | Check the release on Cloudflare: sign in, open the changed screens, and test saves against dev only. |
| Prod | Existing `jimgym` Worker behind Access | `jimgym-prod` in Turso | Release the same tested commit. Check sign-in and confirm a known workout opens. |

Start with the [local run instructions](worker/README.md). Run `bun run test` from the `worker` directory. Local tests do not need cloud credentials. Keep production credentials out of local development, Git, and chat.

### Dev setup

`jimgym-dev` exists in Turso, but it is not a separate Cloudflare deployment yet. The existing `jimgym` Worker was used for the initial dev test and now serves production. Do not switch its Turso secrets back and forth to test a feature.

Before the first dev release, create a separate Worker with preview URLs and public routes off. Set up owner-only Cloudflare Access before enabling its hostname. Use separate Wrangler configuration and `TURSO_URL` and `TURSO_AUTH_TOKEN` secrets scoped to `jimgym-dev`. Test signed-out access to both pages and static files. If a change needs a schema migration, apply and verify it in dev before production.

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

Use the version commands, not `wrangler deploy` or `wrangler triggers deploy`, for a code-only production release. The checked-in Wrangler configuration disables `workers.dev` if applied as a trigger change. Preview URLs stay off. The legacy Fly GitHub workflow still exists and runs on pushes to `main`; it does not deploy to Cloudflare. Remove it before merging this branch to `main`.

See the [database verification instructions](worker/README.md#verify-a-database-import) for the read-only checks used during migration.
