import { connect } from "@tursodatabase/serverless";
import { render_page, new_workout } from "../build/dev/javascript/jimgym_worker/jimgym_worker.mjs";
import { getTemplates, getWorkout, saveWorkout, parseWorkout } from "./workouts.mjs";

function respond(body, status, type = "text/plain") {
  return new Response(body, {
    status,
    headers: { "Content-Type": `${type}; charset=utf-8`, "Cache-Control": "no-store" },
  });
}
const unavailable = (status = 502) => respond("Workout history unavailable", status);
const notFound = () => respond("Not found", 404);
const redirect = (location) => new Response(null, { status: 303, headers: { Location: location, "Cache-Control": "no-store" } });
const html = (result) => result.isOk() ? respond(result[0], 200, "text/html") : unavailable();
const render = (page, { sessions = [], templates = [], year = 0, month = 0, action = "" } = {}) =>
  html(render_page(page, year, month, action, JSON.stringify({ sessions, templates })));

function workoutDate(path) {
  const match = /^\/(\d{4})\/(\d{1,2})\/(\d{1,2})$/.exec(path);
  if (!match) return null;
  const [, year, month, day] = match;
  const iso = `${year}-${month.padStart(2, "0")}-${day.padStart(2, "0")}`;
  const date = new Date(`${iso}T00:00:00Z`);
  return Number(year) > 0 && Number.isFinite(date.getTime()) && date.toISOString().startsWith(iso) ? iso : null;
}
const datePath = (iso) => `/${iso.split("-").map(Number).join("/")}`;

export default {
  async fetch(request, env) {
    const url = new URL(request.url);
    const { pathname } = url;
    const day = workoutDate(pathname);
    const monthMatch = /^\/(\d{4})\/(\d{1,2})$/.exec(pathname);
    const year = Number(monthMatch?.[1]);
    const month = Number(monthMatch?.[2]);
    const calendar = year > 0 && month >= 1 && month <= 12;
    const starting = /^\/new(?:\/[^/]+)?$/.test(pathname);
    if (request.method === "POST") {
      if (!day) return notFound();
      if (request.headers.get("Origin") !== url.origin) return respond("Forbidden", 403);
    } else if (request.method !== "GET" || !(day || calendar || starting || pathname === "/" || pathname === "/setup")) {
      return notFound();
    }
    if (!env.TURSO_URL || !env.TURSO_AUTH_TOKEN) return unavailable(503);
    try {
      const db = connect({ url: env.TURSO_URL, authToken: env.TURSO_AUTH_TOKEN, defaultQueryTimeout: 10000 });
      if (request.method === "POST") {
        let workout;
        try { workout = parseWorkout(await request.formData()); } catch { return respond("Invalid workout form. No changes were saved.", 400); }
        if (!await saveWorkout(db, day, workout, url.searchParams.has("new"))) {
          return respond("A workout already exists for this date. Open it from the calendar to edit it.", 409);
        }
        return redirect(datePath(day));
      }
      if (day) {
        const session = await getWorkout(db, day);
        if (!session) return notFound();
        return render(url.searchParams.has("mini") ? "preview" : "editor", { sessions: [session], action: datePath(day) });
      }
      if (starting) {
        const name = url.searchParams.get("template");
        const iso = url.searchParams.get("date") ?? new Date().toISOString().slice(0, 10);
        if (!name || !/^\d{4}-\d{2}-\d{2}$/.test(iso) || workoutDate('/' + iso.replaceAll('-', '/')) !== iso) return respond("Invalid workout date or template", 400);
        const action = datePath(iso);
        if (await getWorkout(db, iso)) return redirect(action);
        const [template] = await getTemplates(db, name);
        if (!template) return notFound();
        const previous = await db.get("SELECT date FROM gym_sessions WHERE session_name = ? AND date < ? ORDER BY date DESC LIMIT 1", name, iso);
        const draft = previous && await getWorkout(db, previous.date);
        return draft ? render("editor", { sessions: [{ ...draft, date: iso }], action: `${action}?new` })
          : html(new_workout(iso, `${action}?new`, JSON.stringify(template)));
      }
      const templates = await getTemplates(db);
      if (pathname === "/setup") return render("setup", { templates });
      const prefix = calendar ? `${monthMatch[1]}-${monthMatch[2].padStart(2, "0")}-` : new Date().toISOString().slice(0, 10);
      const rows = await db.all("SELECT date, session_name, emoji FROM gym_sessions WHERE substr(date, 1, ?) = ? ORDER BY date", prefix.length, prefix);
      const sessions = rows.map(({ date, session_name, emoji }) => ({ date, session_name, emoji: emoji || "💪", exercises: [] }));
      return render(calendar ? "calendar" : "home", { sessions, templates, year, month });
    } catch {
      // Database errors may contain query or connection details.
      return unavailable();
    }
  },
};
