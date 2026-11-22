-- Synthetic workouts only. Apply to an empty database after schema/schema.sql.
BEGIN;
INSERT INTO gym_sessions (date, session_name, emoji) VALUES
  ('2026-11-09', 'Test workout <em>', '💪'),
  ('2026-11-10', NULL, NULL);
INSERT INTO exercise_records (date, name, reps, weight, duration) VALUES
  ('2026-11-09', 'Squat', 8, 42.5, NULL),
  ('2026-11-09', 'Squat', 8, 42.5, NULL),
  ('2026-11-09', 'Press', 8, 20, NULL),
  ('2026-11-09', 'Bike', NULL, NULL, 15);
COMMIT;
