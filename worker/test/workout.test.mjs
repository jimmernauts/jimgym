import { afterAll, beforeAll, expect, test } from "bun:test";
import worker from "../src/index.mjs";
import { startFixture } from "./fixture.mjs";

let fixture;
beforeAll(() => { fixture = startFixture(); });
afterAll(() => { fixture.stop(); });
const origin = "http://jimgym.test";
const request = (path, options) => new Request(`${origin}${path}`, options);
const fetchPage = (path) => worker.fetch(request(path), fixture.env);
const post = (path, fields, source = origin) => worker.fetch(request(path, {
  method: "POST", headers: { Origin: source }, body: new URLSearchParams(fields),
}), fixture.env);

const workout = {
  session_name: "My workout", session_emoji: "💪",
  "Pull-up|name|0": "Pull-up", "Pull-up|reps|0": "8", "Pull-up|weight|0": "-1",
  "Ride|name|0": "Ride", "Ride|duration|0": "15",
};

test("serves the existing home, calendar, workout editor, preview, and template list", async () => {
  expect(await (await fetchPage("/")).text()).toContain("Setup sessions");
  const calendar = await (await fetchPage("/2026/11")).text();
  expect(calendar).toContain("Nov 2026");
  expect(calendar).toContain("/2026/11/9?mini");
  expect(calendar).toContain("Strength%20%26%20Cardio");
  const response = await fetchPage("/2026/11/9");
  expect(response.status).toBe(200);
  expect(response.headers.get("Cache-Control")).toBe("no-store");
  const editor = await response.text();
  expect(editor).toContain("Test workout &lt;em&gt;");
  expect(editor).toContain('action="/2026/11/9"');
  expect(editor).not.toContain(fixture.env.TURSO_AUTH_TOKEN);
  const preview = await (await fetchPage("/2026/11/9?mini")).text();
  for (const value of ["8, 8 reps @ 42.5 kg", "8 reps @ 20 kg", "Bike", "15 min"]) expect(preview).toContain(value);
  expect(preview).not.toContain("<!doctype html>");
  expect(await (await fetchPage("/setup")).text()).toContain("Strength &amp; Cardio");
  expect((await fetchPage("/2026/11/10")).status).toBe(200);
});

test("offers a family shortlist and clones only the explicitly selected earlier workout", async () => {
  const target = "/new?date=2026-11-12&template=";
  const family = `${target}Strength%20%26%20Cardio`;
  const picker = await (await fetchPage(family)).text();
  expect(picker).toContain("Pick activities");
  expect(picker).toContain("Pull-up");
  expect(picker).toContain("Ride");
  const draft = await (await fetchPage(`${family}&start=pick&activity=1`)).text();
  expect(draft).toContain('action="/2026/11/12?new"');
  expect(draft).not.toContain('name="Pull-up|weight|1"');
  expect(draft).toContain('name="Ride|duration|0" type="number" value="15"');
  expect((await fetchPage(`${family}&start=pick&activity=100`)).status).toBe(400);
  expect((await fetchPage(`${family}&clone=2026-11-09`)).status).toBe(404);
  const pastFamily = `${target}Test%20workout%20%3Cem%3E`;
  expect((await post("/2026/11/11?new", {
    ...workout, session_name: "Test workout <em>",
  })).status).toBe(303);
  const choices = await (await fetchPage(pastFamily)).text();
  expect(choices).toContain("Clone a prior workout");
  expect(choices).toContain('value="2026-11-11"');
  expect(choices).toContain('value="2026-11-09"');
  const previous = await (await fetchPage(`${pastFamily}&clone=2026-11-09`)).text();
  expect(previous).toContain('name="Squat|weight|0" step="0.5" type="number" value="42.5"');
  expect((await fetchPage(`${pastFamily}&clone=2026-11-12`)).status).toBe(400);
  expect((await fetchPage("/2026/11/12")).status).toBe(404);
});

test("creates once, then saves edits and replaces records", async () => {
  const path = "/2026/11/13";
  const created = await post(`${path}?new`, workout);
  expect(created.status).toBe(303);
  expect(created.headers.get("Location")).toBe(path);
  const conflict = await post(`${path}?new`, { ...workout, session_name: "Should not replace" });
  expect(conflict.status).toBe(409);
  expect(await (await fetchPage(path)).text()).toContain("My workout");
  expect((await post(path, { session_name: "Revised workout", session_emoji: "🏋️", "Bike|name|0": "Bike", "Bike|duration|0": "22" })).status).toBe(303);
  const preview = await (await fetchPage(`${path}?mini`)).text();
  expect(preview).toContain("Bike");
  expect(preview).toContain("22 min");
  expect(preview).not.toContain("Pull-up");
});

test("keeps one preview row per exercise and preserves set order and weight changes", async () => {
  const path = "/2026/11/18";
  const fields = { session_name: "Set preview", session_emoji: "💪" };
  const addSets = (name, sets) => sets.forEach(([reps, weight], index) => {
    fields[`${name}|name|${index}`] = name;
    fields[`${name}|reps|${index}`] = String(reps);
    fields[`${name}|weight|${index}`] = String(weight);
  });
  addSets("Bench", [[8, 50], [8, 50], [6, 50]]);
  addSets("Rows", [[10, 20], [6, 25.25], [8, 20]]);
  addSets("Chin-up", [[5, -1], [4, -1]]);
  addSets("Push-up", [[7, 0], [6, 0]]);
  expect((await post(`${path}?new`, fields)).status).toBe(303);
  const preview = await (await fetchPage(`${path}?mini`)).text();
  expect(preview.match(/>Bench<\/th>/g)).toHaveLength(1);
  expect(preview).toContain("8, 8, 6 reps @ 50 kg");
  expect(preview).toContain("10 reps @ 20 kg; 6 reps @ 25.25 kg; 8 reps @ 20 kg");
  expect(preview).toContain("5, 4 reps (bodyweight)");
  expect(preview).toContain("7, 6 reps</td>");
  expect(preview).not.toContain("@ 0 kg");
});

test("editor follows submitted exercise order when reloaded and links to past sets", async () => {
  const path = "/2026/11/19";
  const fields = { session_name: "Reorder test", session_emoji: "💪" };
  for (const name of ["Squat", "Bench"]) {
    fields[`${name}|name|0`] = name;
    fields[`${name}|reps|0`] = "10";
    fields[`${name}|weight|0`] = "30";
  }
  const reversed = Object.fromEntries(Object.entries(fields).reverse());
  expect((await post(`${path}?new`, reversed)).status).toBe(303);
  let page = await (await fetchPage(path)).text();
  expect(page.indexOf(">Bench</h2>")).toBeLessThan(page.indexOf(">Squat</h2>"));
  expect(page).toContain("/exercise?name=Squat&amp;before=2026-11-19");
  expect((await post(path, fields)).status).toBe(303);
  page = await (await fetchPage(path)).text();
  expect(page.indexOf(">Squat</h2>")).toBeLessThan(page.indexOf(">Bench</h2>"));
  const history = await (await fetchPage("/exercise?name=Squat&before=2026-11-19")).text();
  expect(history).toContain("Squat history");
  expect(history).toContain("8, 8 reps @ 42.5 kg");
  expect(history).not.toContain("Reorder test");
  expect(history).not.toContain("15 min");
});

test("rejects cross-origin and invalid saves and rolls back an insert failure", async () => {
  const path = "/2026/11/9";
  expect((await post(path, workout, "https://different.example")).status).toBe(403);
  expect((await post(path, { ...workout, "Ride|duration|0": "bad" })).status).toBe(400);
  expect((await post(path, { ...workout, "Ride|name|0": "Simulate storage failure" })).status).toBe(502);
  expect(await (await fetchPage(path)).text()).toContain("Test workout &lt;em&gt;");
  expect(await (await fetchPage(`${path}?mini`)).text()).toContain("42.5 kg");
});

test("rejects invalid routes and reports an unavailable database without leaking details", async () => {
  expect((await fetchPage("/2026/11/31")).status).toBe(404);
  expect((await fetchPage("/2026/13")).status).toBe(404);
  expect((await fetchPage("/new?date=2026-11-31&template=test")).status).toBe(400);
  expect((await worker.fetch(request("/2026/11/9"), {})).status).toBe(503);
  const response = await worker.fetch(request("/2026/11/9"), { ...fixture.env, TURSO_AUTH_TOKEN: "wrong-token" });
  expect(response.status).toBe(502);
  expect(await response.text()).toBe("Workout history unavailable");
});

test("creates and renames a template, adds and removes exercises, then deletes the template", async () => {
  const original = { template_name: "New & strong", emoji: "🧗" };
  const create = await post("/setup/create", original);
  expect(create.status).toBe(303);
  expect(create.headers.get("Location")).toBe("/setup");
  expect((await post("/setup/create", original)).status).toBe(409);
  expect((await post("/setup/update", { old_name: original.template_name, new_name: "Strength & Cardio", emoji: "🧗" })).status).toBe(409);
  const template = { template_name: "Renamed template" };
  expect((await post("/setup/update", { old_name: original.template_name, new_name: template.template_name, emoji: "🧗" })).status).toBe(303);
  const lift = { ...template, exercise_name: "Rows", exercise_type: "sets", sets: "2", reps: "8", weight: "12.5" };
  const timed = { ...template, exercise_name: "Jog", exercise_type: "timed", duration: "18" };
  expect((await post("/setup/exercise/add", lift)).status).toBe(303);
  expect((await post("/setup/exercise/add", timed)).status).toBe(303);
  let page = await (await fetchPage("/setup")).text();
  expect(page).toContain("Renamed template");
  expect(page.indexOf("Rows")).toBeLessThan(page.indexOf("Jog"));
  expect((await post("/setup/exercise/delete", lift)).status).toBe(303);
  page = await (await fetchPage("/setup")).text();
  expect(page).not.toContain("Rows");
  expect(page).toContain("Jog");
  expect((await post("/setup/delete", template)).status).toBe(303);
  page = await (await fetchPage("/setup")).text();
  expect(page).not.toContain("Renamed template");
  expect(page).not.toContain("Jog");
  expect((await post("/setup/delete", template)).status).toBe(404);
});

test("rejects cross-origin and invalid template changes", async () => {
  const template = { template_name: "Strength & Cardio" };
  expect((await post("/setup/delete", template, "https://other.example")).status).toBe(403);
  expect((await post("/setup/create", { template_name: " " })).status).toBe(400);
  expect((await post("/setup/exercise/add", { ...template, exercise_name: "Invalid", exercise_type: "sets", sets: "9999999" })).status).toBe(400);
  expect((await post("/setup/exercise/add", { ...template, exercise_name: "Invalid", exercise_type: "other" })).status).toBe(400);
  expect(await (await fetchPage("/setup")).text()).toContain("Strength &amp; Cardio");
});
