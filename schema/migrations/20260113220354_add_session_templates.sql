-- migrate:up
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

-- Seed with default templates
INSERT INTO session_templates (name, emoji) VALUES 
    ('Whole Body Full', '💪'),
    ('Rehab', '🧎'),
    ('Ride', '🚴'),
    ('Cardio', '🏃');

-- Seed exercises for Whole Body Full (id=1)
INSERT INTO exercise_templates (session_template_id, name, exercise_type, sets, reps, weight, sort_order) VALUES
    (1, 'Bench Press', 'sets', 3, 10, 35.0, 1),
    (1, 'Pull-ups', 'sets', 3, 8, 14.0, 2),
    (1, 'Rows', 'sets', 3, 10, 25.0, 3),
    (1, 'Shoulder Press', 'sets', 3, 8, 18.0, 4),
    (1, 'ATG Squat', 'sets', 3, 10, -1.0, 5);

-- Seed exercises for Rehab (id=2)
INSERT INTO exercise_templates (session_template_id, name, exercise_type, sets, reps, weight, sort_order) VALUES
    (2, 'Patrick Step', 'sets', 3, 20, 0.0, 1);

-- Seed exercises for Ride (id=3)
INSERT INTO exercise_templates (session_template_id, name, exercise_type, duration, sort_order) VALUES
    (3, 'Bike ride', 'timed', 45, 1);

-- Seed exercises for Cardio (id=4)  
INSERT INTO exercise_templates (session_template_id, name, exercise_type, duration, sort_order) VALUES
    (4, 'Backwards Treadmill', 'timed', 20, 1),
    (4, 'Rowing', 'timed', 10, 2);

-- migrate:down
DROP TABLE IF EXISTS exercise_templates;
DROP TABLE IF EXISTS session_templates;
