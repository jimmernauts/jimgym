-- One-time template change. Rehearse on a copy before applying to Turso.
-- Preserve every recorded session and set. The Worker maps A/C history to Whole Body.
BEGIN;
CREATE TEMP TABLE family_merge_check (ok INTEGER NOT NULL CHECK (ok = 1));
INSERT OR ROLLBACK INTO family_merge_check VALUES (
  (SELECT count(*) FROM session_templates WHERE name IN ('Whole Body A', 'Whole Body C')) = 2
  AND NOT EXISTS (SELECT 1 FROM session_templates WHERE name IN ('Whole Body', 'Legs'))
  AND NOT EXISTS (SELECT 1 FROM exercise_templates e JOIN session_templates t
    ON t.id = e.session_template_id WHERE t.name = 'Whole Body A' AND e.sort_order >= 1000)
);
DROP TABLE family_merge_check;
UPDATE session_templates SET name = 'Whole Body' WHERE name = 'Whole Body A';
INSERT INTO session_templates (name, emoji) VALUES ('Legs', '🦵');

-- Use the existing A/C setups first. Use the most recent matching workout for
-- other shortlist entries. Aliases here do not rename recorded exercises.
WITH shortlist(family, name, alternate1, alternate2, alternate3, position) AS (VALUES
  ('Whole Body', 'Bench Press', NULL, NULL, NULL, 0),
  ('Whole Body', 'Pull-ups', NULL, NULL, NULL, 1),
  ('Whole Body', 'Dips', NULL, NULL, NULL, 2),
  ('Whole Body', 'Shoulder Press', NULL, NULL, NULL, 3),
  ('Whole Body', 'Rows', NULL, NULL, NULL, 4),
  ('Whole Body', 'Crunch', NULL, NULL, NULL, 5),
  ('Whole Body', 'Incline Bench Press', 'Incline Bench', NULL, NULL, 6),
  ('Whole Body', 'Military Press', 'Military press', NULL, NULL, 7),
  ('Whole Body', 'Chinup', 'Chinup ', NULL, NULL, 8),
  ('Whole Body', 'Erg', NULL, NULL, NULL, 9),
  ('Legs', 'Squats', 'Squat', NULL, NULL, 0),
  ('Legs', 'Lunges', NULL, NULL, NULL, 1),
  ('Legs', 'Deadlift', 'Deadlift ', NULL, NULL, 2),
  ('Legs', 'Crab band', 'Crab walks', NULL, NULL, 3),
  ('Legs', 'ATG Squat', 'ATG', 'ATG squats', NULL, 4),
  ('Legs', 'Patrick Step', NULL, NULL, NULL, 5),
  ('Legs', 'Sled Drag', NULL, NULL, NULL, 6),
  ('Legs', 'Sled Push', NULL, NULL, NULL, 7),
  ('Legs', 'Machine Squats', NULL, NULL, NULL, 8),
  ('Legs', 'Knee extension', NULL, NULL, NULL, 9),
  ('Legs', 'Box raise', NULL, NULL, NULL, 10),
  ('Legs', 'Leg Press', NULL, NULL, NULL, 11)
), latest_sets AS (
  SELECT l.family, l.name, e.date, e.reps, e.weight, e.duration,
    count(*) OVER (PARTITION BY l.family, l.name, e.date) AS sets,
    row_number() OVER (PARTITION BY l.family, l.name ORDER BY e.date DESC, e.id) AS newest
  FROM shortlist l JOIN exercise_records e ON e.name IN (l.name, l.alternate1, l.alternate2, l.alternate3)
  JOIN gym_sessions s ON s.date = e.date
  WHERE s.session_name IN ('Whole Body A', 'Whole Body C', 'Legs')
), old_defaults AS (
  SELECT e.* FROM exercise_templates e JOIN session_templates t ON e.session_template_id = t.id
  WHERE t.name IN ('Whole Body', 'Whole Body C')
)
INSERT INTO exercise_templates (session_template_id, name, exercise_type, sets, reps, weight, duration, sort_order)
SELECT t.id, l.name,
  coalesce(o.exercise_type, CASE WHEN h.duration IS NULL THEN 'sets' ELSE 'timed' END),
  CASE WHEN h.duration IS NULL OR o.exercise_type = 'sets' THEN coalesce(o.sets, h.sets, 3) END,
  coalesce(o.reps, h.reps),
  CASE WHEN o.id IS NOT NULL THEN o.weight ELSE h.weight END,
  coalesce(o.duration, h.duration), 1000 + l.position
FROM shortlist l JOIN session_templates t ON t.name = l.family
LEFT JOIN old_defaults o ON o.name = l.name
LEFT JOIN latest_sets h ON h.family = l.family AND h.name = l.name AND h.newest = 1;

DELETE FROM exercise_templates WHERE session_template_id = (SELECT id FROM session_templates WHERE name = 'Whole Body') AND sort_order < 1000;
DELETE FROM exercise_templates WHERE session_template_id = (SELECT id FROM session_templates WHERE name = 'Whole Body C');
DELETE FROM session_templates WHERE name = 'Whole Body C';
UPDATE exercise_templates SET sort_order = sort_order - 1000
WHERE session_template_id IN (SELECT id FROM session_templates WHERE name IN ('Whole Body', 'Legs'));
COMMIT;
