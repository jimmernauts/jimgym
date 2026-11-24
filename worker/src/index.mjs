import { connect } from "@tursodatabase/serverless";
import { render_page, new_workout, choose_start } from "../build/dev/javascript/jimgym_worker/jimgym_worker.mjs";
import { getTemplates, getWorkout, saveWorkout, parseWorkout } from "./workouts.mjs";
import { isTemplateAction, parseTemplateAction, changeTemplate } from "./templates.mjs";

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
const render = (page, { sessions = [], templates = [], year = 0, month = 0, action = "" } = {}) => {
  const order = [...new Set(sessions[0]?.exercises.map(({ name }) => name))];
  return html(render_page(page, year, month, action, JSON.stringify({ sessions, templates, order })));
};
const isIsoDate = (iso) => /^\d{4}-\d{2}-\d{2}$/.test(iso ?? "") && workoutDate('/' + iso.replaceAll('-', '/')) === iso;

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
    const templateAction = isTemplateAction(pathname);
    if (request.method === "POST") {
      if (!day && !templateAction) return notFound();
      if (request.headers.get("Origin") !== url.origin) return respond("Forbidden", 403);
    } else if (request.method !== "GET" || !(day || calendar || starting || pathname === "/" || pathname === "/setup" || pathname === "/exercise")) {
      return notFound();
    }
    if (!env.TURSO_URL || !env.TURSO_AUTH_TOKEN) return unavailable(503);
    try {
      const db = connect({ url: env.TURSO_URL, authToken: env.TURSO_AUTH_TOKEN, defaultQueryTimeout: 10000 });
      if (request.method === "POST") {
        if (templateAction) {
          let args;
          try { args = parseTemplateAction(pathname, await request.formData()); } catch { return respond("Invalid template form. No changes were saved.", 400); }
          const status = await changeTemplate(db, pathname, args);
          if (status === 303) return redirect("/setup");
          if (status === 409) return respond("A template with that name already exists.", 409);
          return notFound();
        }
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
      if (pathname === "/exercise") {
        const name = url.searchParams.get("name");
        const before = url.searchParams.get("before");
        if (!name?.trim() || name.length > 300 || !isIsoDate(before)) return respond("Invalid exercise or date", 400);
        const rows = await db.all(`SELECT s.date, s.session_name, s.emoji, e.name, e.reps, e.weight, e.duration
          FROM exercise_records e JOIN gym_sessions s ON s.date = e.date
          WHERE e.name = ? AND e.date IN (SELECT DISTINCT date FROM exercise_records WHERE name = ? AND date < ? ORDER BY date DESC LIMIT 8)
          ORDER BY s.date DESC, e.id`, name, name, before);
        const sessions = new Map();
        for (const { date, session_name, emoji, ...exercise } of rows) {
          if (!sessions.has(date)) sessions.set(date, { date, session_name, emoji, exercises: [] });
          sessions.get(date).exercises.push(exercise);
        }
        return render("history", { action: name, sessions: [...sessions.values()] });
      }
      if (starting) {
        const name = url.searchParams.get("template");
        const iso = url.searchParams.get("date") ?? new Date().toISOString().slice(0, 10);
        if (!name || !isIsoDate(iso)) return respond("Invalid workout date or family", 400);
        const action = datePath(iso);
        if (await getWorkout(db, iso)) return redirect(action);
        const [template] = await getTemplates(db, name);
        if (!template) return notFound();
        const clone = url.searchParams.get("clone");
        if (clone !== null) {
          if (!isIsoDate(clone) || clone >= iso) return respond("Choose an earlier workout", 400);
          const prior = await getWorkout(db, clone);
          if (!prior || prior.session_name !== name) return notFound();
          return render("editor", { sessions: [{ ...prior, date: iso }], action: `${action}?new` });
        }
        if (url.searchParams.get("start") === "pick") {
          const selected = url.searchParams.getAll("activity");
          if (selected.some((i) => !/^\d+$/.test(i) || Number(i) >= template.exercises.length)) return respond("Invalid activity", 400);
          const indices = new Set(selected.map(Number));
          const activities = template.exercises.filter((_, index) => indices.has(index));
          return html(new_workout(iso, `${action}?new`, JSON.stringify({ ...template, exercises: activities })));
        }
        const rows = await db.all("SELECT date FROM gym_sessions WHERE session_name = ? AND date < ? ORDER BY date DESC", name, iso);
        return html(choose_start(iso, JSON.stringify({ family: template, prior: rows.map(({ date }) => date) })));
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
