-- 015_repair_auto_note_dates.sql
-- Repair auto note dates that the extraction LLM hallucinated.
--
-- Until the change that ships with this migration, notes.date on an auto note was
-- whatever the extraction model returned. The prompt asked for a date but never said
-- what today was, so the model invented one — most often a year. The note dated
-- 1615-01-01 is a teacher speaking the time "16:15" at the top of a recording.
--
-- This matters because report_generator filters WHERE date BETWEEN ? AND ?. A note
-- recorded this term but stamped 2023 is silently absent from the report — no error,
-- just a shorter report.
--
-- Repair source: substr(created_at, 1, 10), the day the note row was inserted. No
-- match against voice_notes is needed. Measured on production data before writing
-- this (260 notes, 161 auto):
--
--   * all 69 bad rows are source='auto'; no manual row is malformed or off-year
--     (manual dates come from an <input type="date">);
--   * of the 92 auto rows whose date is well-formed and whose year matches
--     created_at, 92 of 92 have date exactly equal to substr(created_at,1,10).
--
-- So created_at reproduces every known-good auto date, and the three groups
-- (13 malformed + 56 off-year + 92 exact) account for all 161 auto rows.
--
-- Scope is deliberately the broken rows rather than every auto row: updating all of
-- them would give the same result on today's data, but would also overwrite a
-- correct date if one ever differed from its insert day. After this migration that
-- becomes possible — the code now dates a note from the voice note's upload time, so
-- a job retried the next day writes date < created_at on purpose.

-- 1. Malformed: not YYYY-MM-DD at all ("Saturday", "Friday, Marcia, 1740").
UPDATE notes
   SET date = substr(created_at, 1, 10),
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
 WHERE source = 'auto'
   AND date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]';

-- 2. Well-formed but the year is invented (2023, 1615) — the note cannot predate or
--    outlive the row that holds it.
UPDATE notes
   SET date = substr(created_at, 1, 10),
       updated_at = strftime('%Y-%m-%dT%H:%M:%fZ', 'now')
 WHERE source = 'auto'
   AND date GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]'
   AND substr(date, 1, 4) <> substr(created_at, 1, 4);

-- 3. Guard: abort naming the first note whose date is still not YYYY-MM-DD. Applies
--    to every source, not just auto — a malformed manual date would mean the API
--    accepted one, which the validation shipping alongside this migration forbids.
--    Off-year is deliberately not guarded: a teacher may legitimately backdate a
--    manual note into a previous year.
--
--    Migrations run inside a transaction (migrate.go), so RAISE(ABORT) rolls the
--    whole file back rather than leaving a partial repair.
CREATE TEMP TABLE _repair_note_dates_guard(x);
CREATE TEMP TRIGGER _repair_note_dates_guard_check BEFORE INSERT ON _repair_note_dates_guard
BEGIN
    SELECT RAISE(ABORT, 'migration 015: note id=' ||
        (SELECT id FROM notes
          WHERE date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' LIMIT 1) ||
        ' (source ' ||
        (SELECT source FROM notes
          WHERE date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' LIMIT 1) ||
        ') still has a malformed date: ' ||
        (SELECT date FROM notes
          WHERE date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]' LIMIT 1))
    WHERE (SELECT COUNT(*) FROM notes
            WHERE date NOT GLOB '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]') > 0;
END;
INSERT INTO _repair_note_dates_guard VALUES (1);
DROP TRIGGER _repair_note_dates_guard_check;
DROP TABLE _repair_note_dates_guard;
