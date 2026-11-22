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
  db.exec(`
    INSERT INTO session_templates (id, name, emoji) VALUES (1, 'Strength & Cardio', '💪'), (2, 'Test workout <em>', '💪');
    INSERT INTO exercise_templates (session_template_id, name, exercise_type, sets, reps, weight, duration) VALUES
      (1, 'Pull-up', 'sets', 2, 8, -1, NULL), (1, 'Ride', 'timed', NULL, NULL, NULL, 15);
    CREATE TRIGGER simulate_failed_insert BEFORE INSERT ON exercise_records
      WHEN NEW.name = 'Simulate storage failure' BEGIN SELECT RAISE(ABORT, 'Synthetic failure'); END;
  `);
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
      const { batch: { steps } } = await request.json();
      const entries = [{ baton: null }];
      const completed = new Set();
      function shouldRun(condition) {
        if (!condition) return true;
        if (condition.type === "ok") return completed.has(condition.step);
        if (condition.type === "is_autocommit") return !db.inTransaction;
        if (condition.type === "not") return !shouldRun(condition.cond);
        if (condition.type === "and") return condition.conds.every(shouldRun);
        throw Error("Unexpected batch condition");
      }
      for (const [step, { stmt, condition }] of steps.entries()) {
        if (!shouldRun(condition)) continue;
        try {
          const query = db.query(stmt.sql);
          const rows = query.values(...stmt.args.map(({ type, value }) => type === "null" ? null : type === "integer" ? Number(value) : value));
          entries.push({ type: "step_begin", step, cols: query.columnNames.map((name) => ({ name })) });
          entries.push(...(rows ?? []).map((row) => ({ type: "row", row: row.map(encode) })));
          entries.push({ type: "step_end", affected_row_count: 0 });
          completed.add(step);
        } catch (error) {
          entries.push({ type: "step_error", step, error: { message: error.message } });
        }
      }
      return new Response(entries.map((entry) => JSON.stringify(entry)).join("\n") + "\n");
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
