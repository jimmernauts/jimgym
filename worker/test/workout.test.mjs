import { afterAll, beforeAll, expect, test } from "bun:test";
import worker from "../src/index.mjs";
import { startFixture } from "./fixture.mjs";

let fixture;
beforeAll(() => { fixture = startFixture(); });
afterAll(() => { fixture.stop(); });

const request = (path, method = "GET") => new Request(`http://jimgym.test${path}`, { method });

test("renders sets and timed exercise history from the database", async () => {
  const response = await worker.fetch(request("/2026/11/9"), fixture.env);
  expect(response.status).toBe(200);
  expect(response.headers.get("Cache-Control")).toBe("no-store");
  const html = await response.text();
  expect(html).toStartWith("<!doctype html>");
  expect(html).toContain("Test workout &lt;em&gt;");
  expect(html).toContain("2×8");
  expect(html).toContain("42.5kg");
  expect(html).toContain("20kg");
  expect(html).toContain("1 sets Bike 15m");
  expect(html).not.toContain(fixture.env.TURSO_AUTH_TOKEN);
});

test("renders a workout with no exercise records or optional metadata", async () => {
  const response = await worker.fetch(request("/2026/11/10"), fixture.env);
  expect(response.status).toBe(200);
  expect(await response.text()).toContain("<title>Workout</title>");
});

test("returns not found for an absent workout, an invalid date, or a write request", async () => {
  expect((await worker.fetch(request("/2026/11/11"), fixture.env)).status).toBe(404);
  expect((await worker.fetch(request("/2026/11/31"), {})).status).toBe(404);
  expect((await worker.fetch(request("/2026/11/09", "POST"), {})).status).toBe(404);
});

test("reports an unavailable database without returning its details", async () => {
  expect((await worker.fetch(request("/2026/11/9"), {})).status).toBe(503);
  const response = await worker.fetch(request("/2026/11/9"), { ...fixture.env, TURSO_AUTH_TOKEN: "wrong-token" });
  expect(response.status).toBe(502);
  expect(await response.text()).toBe("Workout history unavailable");
});
