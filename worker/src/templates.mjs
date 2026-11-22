const actions = new Set(["/setup/create", "/setup/update", "/setup/delete", "/setup/exercise/add", "/setup/exercise/delete"]);
export const isTemplateAction = (path) => actions.has(path);

export function parseTemplateAction(path, form) {
  const field = (key, fallback) => {
    const values = form.getAll(key);
    if (!values.length && fallback !== undefined) return fallback;
    if (values.length !== 1 || typeof values[0] !== "string" || values[0].length > 300) throw Error("Invalid field");
    if (!values[0].trim() && fallback === undefined) throw Error("Missing field");
    return values[0];
  };
  const count = (key, fallback, max = Number.MAX_SAFE_INTEGER) => {
    const value = field(key, "");
    if (!value) return fallback;
    if (!/^\d+$/.test(value) || !Number.isSafeInteger(Number(value)) || Number(value) > max) throw Error("Invalid count");
    return Number(value);
  };
  if (path === "/setup/update") return [field("new_name"), field("emoji", "💪"), field("old_name")];
  const template = field("template_name");
  if (path === "/setup/create") return [template, field("emoji", "💪")];
  if (path === "/setup/delete") return [template];
  const exercise = field("exercise_name");
  if (path === "/setup/exercise/delete") return [template, exercise];
  const kind = field("exercise_type");
  if (kind === "timed") return [exercise, kind, null, null, null, count("duration", 0), template];
  if (kind !== "sets") throw Error("Invalid exercise type");
  const weight = field("weight", "");
  if (weight && (!/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(weight) || !Number.isFinite(Number(weight)))) throw Error("Invalid weight");
  return [exercise, kind, count("sets", 3, 300), count("reps", 10), Number(weight), null, template];
}

export async function changeTemplate(db, path, args) {
  switch (path) {
    case "/setup/create": {
      const row = await db.get("INSERT INTO session_templates (name, emoji) VALUES (?, ?) ON CONFLICT(name) DO NOTHING RETURNING id", args);
      return row ? 303 : 409;
    }
    case "/setup/update": {
      try {
        const row = await db.get("UPDATE session_templates SET name = ?, emoji = ? WHERE name = ? RETURNING id", args);
        return row ? 303 : 404;
      } catch (error) {
        if (String(error.message).includes("UNIQUE constraint failed: session_templates.name")) return 409;
        throw error;
      }
    }
    case "/setup/delete": {
      const [, removed] = await db.batch([
        { sql: "DELETE FROM exercise_templates WHERE session_template_id = (SELECT id FROM session_templates WHERE name = ?)", args },
        { sql: "DELETE FROM session_templates WHERE name = ? RETURNING id", args },
      ], "immediate");
      return removed.rows.length ? 303 : 404;
    }
    case "/setup/exercise/add": {
      const row = await db.get(`INSERT INTO exercise_templates
        (session_template_id, name, exercise_type, sets, reps, weight, duration, sort_order)
        SELECT t.id, ?, ?, ?, ?, ?, ?,
          COALESCE((SELECT MAX(e.sort_order) FROM exercise_templates e WHERE e.session_template_id = t.id), -1) + 1
        FROM session_templates t WHERE t.name = ? RETURNING id`, args);
      return row ? 303 : 404;
    }
    case "/setup/exercise/delete": {
      const rows = await db.all(`DELETE FROM exercise_templates WHERE session_template_id =
        (SELECT id FROM session_templates WHERE name = ?) AND name = ? RETURNING id`, args);
      return rows.length ? 303 : 404;
    }
  }
}
