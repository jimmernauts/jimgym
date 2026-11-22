import { connect } from "@tursodatabase/serverless";
import { render_workout } from "../build/dev/javascript/jimgym_worker/jimgym_worker.mjs";

const workoutQuery = `SELECT s.session_name, s.emoji, e.name, e.reps, e.weight, e.duration
  FROM gym_sessions AS s
  LEFT JOIN exercise_records AS e ON e.date = s.date
  WHERE s.date = ? ORDER BY e.id`;

function respond(body, status, type = "text/plain") {
  return new Response(body, {
    status,
    headers: { "Content-Type": `${type}; charset=utf-8`, "Cache-Control": "no-store" },
  });
}

function workoutDate(path) {
  const match = /^\/(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(path);
  if (!match) return null;
  const [, year, month, day] = match;
  const iso = `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
  const date = new Date(`${iso}T00:00:00Z`);
  return Number.isFinite(date.getTime()) && date.toISOString().startsWith(iso) ? iso : null;
}

export default {
  async fetch(request, env) {
    const iso = workoutDate(new URL(request.url).pathname);
    if (!iso || request.method !== "GET") return respond("Not found", 404);
    if (!env.TURSO_URL || !env.TURSO_AUTH_TOKEN) return respond("Workout history unavailable", 503);

    try {
      const db = connect({ url: env.TURSO_URL, authToken: env.TURSO_AUTH_TOKEN });
      const rows = await db.all(workoutQuery, iso);
      if (!rows.length) return respond("Workout not found", 404);

      const { session_name: name, emoji } = rows[0];
      const exercises = rows
        .filter((row) => row.name !== null)
        .map(({ name, reps, weight, duration }) => ({ name, reps, weight, duration }));
      const result = render_workout(iso, JSON.stringify({ name, emoji, exercises }));
      if (result.isOk()) return respond(result[0], 200, "text/html");
    } catch {
      // Do not expose database responses, credentials, or queries to the browser.
    }
    return respond("Workout history unavailable", 502);
  },
};
