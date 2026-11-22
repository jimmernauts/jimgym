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
  for (const value of ["2×8", "42.5kg", "20kg", "1 sets Bike 15m"]) expect(preview).toContain(value);
  expect(preview).not.toContain("<!doctype html>");
  expect(await (await fetchPage("/setup")).text()).toContain("Strength &amp; Cardio");
  expect((await fetchPage("/2026/11/10")).status).toBe(200);
});

test("prepares a draft from a template or an earlier matching workout, without a write", async () => {
  const template = await (await fetchPage("/new?date=2026-11-12&template=Strength%20%26%20Cardio")).text();
  expect(template).toContain('action="/2026/11/12?new"');
  expect(template).toContain('name="Pull-up|weight|1" type="hidden" value="-1"');
  expect(template).toContain('name="Ride|duration|0" type="number" value="15"');
  const previous = await (await fetchPage("/new?date=2026-11-12&template=Test%20workout%20%3Cem%3E")).text();
  expect(previous).toContain('name="Squat|weight|0" step="0.5" type="number" value="42.5"');
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
  expect(preview).toContain("Bike 22m");
  expect(preview).not.toContain("Pull-up");
});

test("rejects cross-origin and invalid saves and rolls back an insert failure", async () => {
  const path = "/2026/11/9";
  expect((await post(path, workout, "https://different.example")).status).toBe(403);
  expect((await post(path, { ...workout, "Ride|duration|0": "bad" })).status).toBe(400);
  expect((await post(path, { ...workout, "Ride|name|0": "Simulate storage failure" })).status).toBe(502);
  expect(await (await fetchPage(path)).text()).toContain("Test workout &lt;em&gt;");
  expect(await (await fetchPage(`${path}?mini`)).text()).toContain("42.5kg");
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
