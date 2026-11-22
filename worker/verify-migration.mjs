import { Database } from "bun:sqlite";
import { createHash } from "node:crypto";
import { connect } from "@tursodatabase/serverless";

const tables = {
  schema_migrations: "version",
  gym_sessions: "id, created_at, date, session_name, emoji",
  exercise_records: "id, created_at, date, name, reps, weight, duration",
  session_templates: "id, created_at, name, emoji",
  exercise_templates: "id, created_at, session_template_id, name, exercise_type, sets, reps, weight, duration, sort_order",
};

export async function databaseManifest(all) {
  const manifest = {};
  for (const [table, columns] of Object.entries(tables)) {
    const rows = await all(`SELECT ${columns} FROM ${table} ORDER BY 1`);
    const keys = columns.split(", ");
    const hash = createHash("sha256");
    for (const row of rows) hash.update(JSON.stringify(keys.map((key) => row[key])) + "\n");
    manifest[table] = { count: rows.length, digest: hash.digest("hex") };
  }
  const [dates] = await all("SELECT MIN(date) AS first, MAX(date) AS last FROM gym_sessions");
  const sequences = await all("SELECT name, seq FROM sqlite_sequence WHERE name IN ('gym_sessions','exercise_records','session_templates','exercise_templates') ORDER BY name");
  const [orphans] = await all(`SELECT
    (SELECT COUNT(*) FROM exercise_templates e LEFT JOIN session_templates t ON t.id=e.session_template_id WHERE t.id IS NULL) AS template_exercises,
    (SELECT COUNT(*) FROM exercise_records e LEFT JOIN gym_sessions s ON s.date=e.date WHERE s.date IS NULL) AS exercise_records`);
  return { ...manifest, dates: [dates.first, dates.last], sequences: sequences.map(({ name, seq }) => [name, seq]), orphans: [orphans.template_exercises, orphans.exercise_records] };
}

export function changedChecks(source, target) {
  const changes = Object.keys(source).filter((key) => JSON.stringify(source[key]) !== JSON.stringify(target[key]));
  if (source.orphans.some(Boolean) || target.orphans.some(Boolean)) changes.push("unlinked records require review");
  return changes;
}

if (import.meta.main) {
  const [sourcePath, targetPath] = process.argv.slice(2);
  if (!sourcePath || !targetPath) {
    console.error("Usage: bun verify-migration.mjs SOURCE.db TARGET.db|--turso");
    process.exit(2);
  }
  try {
    const snapshot = new Database(sourcePath, { readonly: true });
    const source = await databaseManifest((sql) => snapshot.query(sql).all());
    snapshot.close();
    let target;
    if (targetPath === "--turso") {
      const { TURSO_URL, TURSO_AUTH_TOKEN } = process.env;
      if (!TURSO_URL || !TURSO_AUTH_TOKEN) throw Error("Missing Turso connection");
      const db = connect({ url: TURSO_URL, authToken: TURSO_AUTH_TOKEN, defaultQueryTimeout: 15000 });
      target = await databaseManifest((sql) => db.all(sql));
    } else {
      const copy = new Database(targetPath, { readonly: true });
      target = await databaseManifest((sql) => copy.query(sql).all());
      copy.close();
    }
    const changes = changedChecks(source, target);
    if (changes.length) {
      console.error(`Migration checks failed: ${changes.join(", ")}`);
      process.exitCode = 1;
    } else {
      console.log("Migration checks passed: rows, date range, ID sequences, and record links match.");
    }
  } catch {
    console.error("Migration checks could not read the source or target. Check the paths, schema and credentials.");
    process.exitCode = 1;
  }
}
