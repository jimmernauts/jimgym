-- migrate:up
CREATE TABLE IF NOT EXISTS gym_sessions (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date TEXT NOT NULL UNIQUE,
    session_name TEXT NULL,
    emoji TEXT NULL
);
CREATE TABLE IF NOT EXISTS exercise_records (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    created_at TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    date TEXT NOT NULL,
    name TEXT NOT NULL,
    reps INTEGER NULL,
    weight REAL NULL,
    duration INTEGER NULL
);
-- migrate:down
DROP TABLE gym_sessions;
DROP TABLE exercise_records;