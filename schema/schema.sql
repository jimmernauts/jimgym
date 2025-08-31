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
-- Dbmate schema migrations
INSERT INTO "schema_migrations" (version) VALUES
  ('20250826201049'),
  ('20250827213147');
