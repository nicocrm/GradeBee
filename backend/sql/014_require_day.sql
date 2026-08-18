-- 014_require_day.sql
-- Add classes.day: a mandatory weekday, parsed out of the existing free-text
-- time_slot. Day is the day of the first class of the week when a Level
-- meets several times; Time slot remains optional free text alongside it.
--
-- Parsing: scan time_slot (case-insensitively) for the first three-letter
-- day abbreviation (mon/tue/wed/thu/fri/sat/sun) that appears in it, by
-- earliest position — this matches both abbreviated ("Wed@14:10") and full
-- ("Group 1 Wednesday") forms, and for "Tuesday & Friday" picks Tuesday
-- (the earlier match) per spec. The matched day name (full or abbreviated)
-- is then stripped from time_slot, along with leftover separators
-- (" ", "@", "-", "&"), leaving the rest as the new time_slot
-- ("Wed@14:10" -> day Wednesday, time_slot "14:10"; "Group 1 Wednesday" ->
-- day Wednesday, time_slot "Group 1").
--
-- Class id=30 (Linda) has no day recorded at all (empty time_slot) and is
-- assigned Saturday per spec, as a one-shot literal exception — not a
-- general "empty text defaults to Saturday" rule.
--
-- Any other class whose day still can't be determined after this aborts the
-- migration by name: that means its text held a day-like word the parser
-- did not recognise, a parser bug worth stopping for, not missing data.
--
-- Uses the table-rebuild pattern (SQLite can't add a CHECK constraint or
-- change a UNIQUE index via ALTER TABLE) — see 006_students_name_nocase.sql
-- and 011_class_level_id.sql for the same pattern. Only classes itself needs
-- rebuilding here; no other table's schema changes, so child tables (students,
-- student_aliases) are left alone — SQLite auto-retargets their FK text at
-- the renamed "classes_old", and rebuilding classes back to "classes" retargets
-- them back without touching their own definitions.

PRAGMA foreign_keys = OFF;

-- 1. Add day, nullable for now — populated below, then hardened when the
--    table is rebuilt.
ALTER TABLE classes ADD COLUMN day TEXT;

-- 2. Backfill day: earliest-position match among the seven three-letter
--    abbreviations, case-insensitive.
UPDATE classes
SET day = (
    SELECT full_name FROM (
        SELECT 'Monday'    AS full_name, INSTR(LOWER(classes.time_slot), 'mon') AS pos UNION ALL
        SELECT 'Tuesday',   INSTR(LOWER(classes.time_slot), 'tue') UNION ALL
        SELECT 'Wednesday', INSTR(LOWER(classes.time_slot), 'wed') UNION ALL
        SELECT 'Thursday',  INSTR(LOWER(classes.time_slot), 'thu') UNION ALL
        SELECT 'Friday',    INSTR(LOWER(classes.time_slot), 'fri') UNION ALL
        SELECT 'Saturday',  INSTR(LOWER(classes.time_slot), 'sat') UNION ALL
        SELECT 'Sunday',    INSTR(LOWER(classes.time_slot), 'sun')
    )
    WHERE pos > 0
    ORDER BY pos ASC
    LIMIT 1
);

-- 3. One-shot literal exception: Linda (id=30) has no day recorded and is
--    assigned Saturday, per spec.
UPDATE classes SET day = 'Saturday' WHERE id = 30 AND day IS NULL;

-- 4. Guard: abort naming the first class whose day still couldn't be
--    determined — a parser bug (unrecognised day text), not missing data.
CREATE TEMP TABLE _require_day_guard(x);
CREATE TEMP TRIGGER _require_day_guard_check BEFORE INSERT ON _require_day_guard
BEGIN
    SELECT RAISE(ABORT, 'migration 014: class id=' ||
        (SELECT id FROM classes WHERE day IS NULL LIMIT 1) ||
        ' has unrecognised or missing day text: ' ||
        (SELECT time_slot FROM classes WHERE day IS NULL LIMIT 1))
    WHERE (SELECT COUNT(*) FROM classes WHERE day IS NULL) > 0;
END;
INSERT INTO _require_day_guard VALUES (1);
DROP TRIGGER _require_day_guard_check;
DROP TABLE _require_day_guard;

-- 5. Rebuild classes: harden day to NOT NULL with a CHECK over the seven
--    weekday names, and widen uniqueness to (user_id, level_id, day, time_slot)
--    so two classes at the same Level and day are distinguished by time slot.
-- Stripping the day token out of time_slot happens here, in the INSERT,
-- rather than via an in-place UPDATE on the old table: an in-place strip
-- would collide with the old UNIQUE(user_id, level_id, time_slot) constraint
-- whenever two classes at the same Level strip down to the same leftover
-- text (e.g. two bare-day classes both stripping to ''), even though their
-- new (day, time_slot) pairs are distinct.
ALTER TABLE classes RENAME TO classes_old;

CREATE TABLE classes (
    id            INTEGER PRIMARY KEY,
    user_id       TEXT NOT NULL,
    level_id      INTEGER NOT NULL REFERENCES levels(id) ON DELETE RESTRICT,
    day           TEXT NOT NULL CHECK (day IN ('Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday')),
    time_slot     TEXT NOT NULL DEFAULT '',
    position      INTEGER NOT NULL DEFAULT 0,
    created_at    TEXT NOT NULL DEFAULT (strftime('%Y-%m-%dT%H:%M:%fZ','now')),
    UNIQUE (user_id, level_id, day, time_slot)
);

INSERT INTO classes (id, user_id, level_id, day, time_slot, position, created_at)
    SELECT id, user_id, level_id, day,
        TRIM(TRIM(TRIM(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
            REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(REPLACE(
                time_slot,
                'Monday', ''), 'Tuesday', ''), 'Wednesday', ''), 'Thursday', ''), 'Friday', ''), 'Saturday', ''), 'Sunday', ''),
                'Mon', ''), 'Tue', ''), 'Wed', ''), 'Thu', ''), 'Fri', ''), 'Sat', ''), 'Sun', '')
            , ' @-'), '&'), ' @-'),
        position, created_at
    FROM classes_old;

DROP TABLE classes_old;

CREATE INDEX idx_classes_user  ON classes(user_id);
CREATE INDEX idx_classes_level ON classes(level_id);

PRAGMA foreign_keys = ON;
