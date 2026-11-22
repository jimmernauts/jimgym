import { Database } from "bun:sqlite";

const fixtureToken = "synthetic-test-token";

function encode(value) {
  if (value === null) return { type: "null" };
  if (typeof value === "string") return { type: "text", value };
  if (Number.isInteger(value)) return { type: "integer", value: String(value) };
  return { type: "float", value };
}

// Exercise the real driver's HTTP cursor against SQLite with synthetic rows only.
export function startFixture(port = 0) {
  const db = new Database(":memory:");
  db.exec(schema);
  db.exec(seed);
  db.exec("PRAGMA query_only = ON;");
  const server = Bun.serve({
    hostname: "127.0.0.1",
    port,
    async fetch(request) {
      if (new URL(request.url).pathname !== "/v3/cursor" || request.method !== "POST") {
        return new Response("Unexpected request", { status: 404 });
      }
      if (request.headers.get("Authorization") !== `Bearer ${fixtureToken}`) {
        return new Response("Bad fixture token", { status: 401 });
      }
      const { batch: { steps: [{ stmt }] } } = await request.json();
      const query = db.query(stmt.sql);
      const rows = query.values(...stmt.args.map(({ value }) => value));
      return new Response([
        { baton: null },
        { type: "step_begin", step: 0, cols: query.columnNames.map((name) => ({ name })) },
        ...rows.map((row) => ({ type: "row", row: row.map(encode) })),
        { type: "step_end", affected_row_count: 0 },
        { type: "step_begin", step: 1, cols: [] },
        { type: "step_end", affected_row_count: 0 },
      ].map((entry) => JSON.stringify(entry)).join("\n") + "\n");
    },
  });
  return {
    env: { TURSO_URL: server.url.href, TURSO_AUTH_TOKEN: fixtureToken },
    stop() { server.stop(true); db.close(); },
  };
}

const schema = await Bun.file(new URL("../../schema/schema.sql", import.meta.url)).text();
const seed = await Bun.file(new URL("seed.sql", import.meta.url)).text();

if (import.meta.main) {
  console.log(startFixture(Number(Bun.argv[2]) || 0).env);
}
