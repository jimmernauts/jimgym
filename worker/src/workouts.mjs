const workoutQuery = `SELECT s.date, s.session_name, s.emoji, e.name, e.reps, e.weight, e.duration
  FROM gym_sessions AS s LEFT JOIN exercise_records AS e ON e.date = s.date
  WHERE s.date = ? ORDER BY e.id`;

export async function getWorkout(db, date) {
  const rows = await db.all(workoutQuery, date);
  if (!rows.length) return null;
  const { session_name, emoji } = rows[0];
  const exercises = rows.filter(({ name }) => name !== null)
    .map(({ name, reps, weight, duration }) => ({ name, reps, weight, duration }));
  return { date, session_name, emoji, exercises };
}

export async function getTemplates(db, name) {
  const rows = await db.all(`SELECT t.id, t.name AS template_name, t.emoji,
      e.name, e.exercise_type, e.sets, e.reps, e.weight, e.duration
    FROM session_templates AS t LEFT JOIN exercise_templates AS e ON e.session_template_id = t.id
    ${name === undefined ? "" : "WHERE t.name = ?"} ORDER BY t.id, e.sort_order, e.id`, name === undefined ? [] : [name]);
  const templates = new Map();
  for (const { id, template_name, emoji, name, exercise_type, sets, reps, weight, duration } of rows) {
    if (!templates.has(id)) templates.set(id, { name: template_name, emoji, exercises: [] });
    if (name !== null) templates.get(id).exercises.push({ name, exercise_type, sets, reps, weight, duration });
  }
  return [...templates.values()];
}

export function parseWorkout(form) {
  function one(field) {
    const values = form.getAll(field);
    if (values.length !== 1 || typeof values[0] !== "string" || values[0].length > 300) throw Error("Invalid field");
    return values[0].trim();
  }
  const session_name = one("session_name");
  const emoji = one("session_emoji");
  if (!session_name) throw Error("Missing workout name");
  const groups = new Map();
  for (const name of form.keys()) {
    if (name === "session_name" || name === "session_emoji") continue;
    const match = /^(.*)\|(name|duration|reps|weight)\|(-?\d+)$/.exec(name);
    if (!match) throw Error("Invalid exercise field");
    const [, prefix, field, index] = match;
    const key = `${prefix}|${index}`;
    if (!groups.has(key)) groups.set(key, {});
    groups.get(key)[field] = one(name);
  }
  if (groups.size > 300) throw Error("Too many exercises");
  function integer(value) {
    if (!/^\d+$/.test(value) || !Number.isSafeInteger(Number(value))) throw Error("Invalid count");
    return Number(value);
  }
  return { session_name, emoji, exercises: [...groups.values()].map(({ name, duration, reps, weight }) => {
    if (!name) throw Error("Missing exercise name");
    if (duration !== undefined) {
      if (reps !== undefined || weight !== undefined) throw Error("Mixed exercise types");
      return [name, null, null, integer(duration)];
    }
    if (weight !== "" && (!/^-?(?:\d+(?:\.\d*)?|\.\d+)$/.test(weight) || !Number.isFinite(Number(weight)))) throw Error("Invalid weight");
    return [name, integer(reps), Number(weight), null];
  }) };
}

export async function saveWorkout(db, date, { session_name, emoji, exercises }, createOnly) {
  const insert = "INSERT INTO gym_sessions (date, session_name, emoji) VALUES (?, ?, ?)";
  try {
    await db.batch([
      { sql: createOnly ? insert : `${insert} ON CONFLICT(date) DO UPDATE SET session_name = excluded.session_name, emoji = excluded.emoji`, args: [date, session_name, emoji] },
      { sql: "DELETE FROM exercise_records WHERE date = ?", args: [date] },
      ...exercises.map((exercise) => ({
        sql: "INSERT INTO exercise_records (date, name, reps, weight, duration) VALUES (?, ?, ?, ?, ?)",
        args: [date, ...exercise],
      })),
    ], "immediate");
    return true;
  } catch (error) {
    if (createOnly && String(error.message).includes("gym_sessions.date") && await getWorkout(db, date)) return false;
    throw error;
  }
}
