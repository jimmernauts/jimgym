CREATE TABLE IF NOT EXISTS "schema_migrations" (version varchar(128) primary key);
CREATE TABLE gym_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date TEXT NOT NULL UNIQUE,
    session_name TEXT NULL,
    emoji TEXT NULL
);
CREATE TABLE exercise_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date TEXT NOT NULL,
    name TEXT NOT NULL,
    reps INTEGER NULL,
    weight REAL NULL,
    duration INTEGER NULL
);
CREATE TABLE session_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    name TEXT NOT NULL UNIQUE,
    emoji TEXT NOT NULL DEFAULT '💪'
);
CREATE TABLE exercise_templates (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    session_template_id INTEGER NOT NULL,
    name TEXT NOT NULL,
    exercise_type TEXT NOT NULL CHECK(exercise_type IN ('sets', 'timed')),
    sets INTEGER NULL,
    reps INTEGER NULL,
    weight REAL NULL,
    duration INTEGER NULL,
    sort_order INTEGER NOT NULL DEFAULT 0,
    FOREIGN KEY (session_template_id) REFERENCES session_templates(id) ON DELETE CASCADE
);
-- Dbmate schema migrations
INSERT INTO "schema_migrations" (version) VALUES
  ('20250826201049'),
  ('20250827213147'),
  ('20260113220354');
