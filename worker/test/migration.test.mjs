import { Database } from "bun:sqlite";
import { expect, test } from "bun:test";
import { databaseManifest, changedChecks } from "../verify-migration.mjs";

const schema = await Bun.file(new URL("../../schema/schema.sql", import.meta.url)).text();
const seed = await Bun.file(new URL("./seed.sql", import.meta.url)).text();

function fixture() {
  const db = new Database(":memory:");
  db.exec(schema);
  db.exec(seed);
  db.exec(`
    INSERT INTO session_templates (id, name) VALUES (12, 'Template');
    INSERT INTO exercise_templates (id, session_template_id, name, exercise_type) VALUES (42, 12, 'Squat', 'sets');
    UPDATE sqlite_sequence SET seq = 100 WHERE name = 'gym_sessions';
  `);
  return db;
}

const manifestFor = (db) => databaseManifest((sql) => db.query(sql).all());

test("a synthetic SQLite snapshot restores with the same rows, links, and next IDs", async () => {
  const source = fixture();
  const target = Database.deserialize(source.serialize());
  try {
    expect(changedChecks(await manifestFor(source), await manifestFor(target))).toEqual([]);
    const next = target.query("INSERT INTO gym_sessions (date) VALUES ('2026-11-20') RETURNING id").get();
    expect(next.id).toBe(101);
  } finally {
    source.close();
    target.close();
  }
});

test("reports changed values even when counts match, sequence drift and broken links", async () => {
  const source = fixture();
  const target = Database.deserialize(source.serialize());
  try {
    target.exec(`UPDATE exercise_records SET weight = 43 WHERE id = 1;
      UPDATE sqlite_sequence SET seq = 2 WHERE name = 'gym_sessions';
      UPDATE exercise_templates SET session_template_id = 99 WHERE id = 42;`);
    expect(changedChecks(await manifestFor(source), await manifestFor(target))).toEqual([
      "exercise_records", "exercise_templates", "sequences", "orphans", "unlinked records require review",
    ]);
  } finally {
    source.close();
    target.close();
  }
});
