# Plan: Move Student and Re-Split Notes Script

One-time Python script to move a student from the wrong class to the correct class and re-split class notes so the student receives their assigned content.

## Overview

**Problem:** A student was in the wrong class. Notes were recorded against the correct class, but when split, the student wasn't in the class roster, so their content was not assigned to them.

**Solution:** Move the student to the correct class, then re-trigger the split for all transcribed notes in that class. The split function uses the updated class roster and will assign content to the moved student (overwriting existing student notes as needed).

## Prerequisites

- `just env dev` (or target env) run so `.env` is available
- Appwrite credentials in `.env` (APPWRITE_ENDPOINT, APPWRITE_PROJECT_ID, APPWRITE_API_KEY, APPWRITE_DATABASE_ID)
- Script uses existing `config.py` (same pattern as `run_report_cards.py`, `import_classes.py`)

## Script: `move_student_and_resplit_notes.py`

### Arguments

| Arg | Required | Description |
|-----|----------|-------------|
| `--student` | Yes | Student name (e.g., `"John"`, `"Emma Smith"`) |
| `--class` | Yes | Course/class name (e.g., `"Pam & Paul"`, `"Mousy"`). Use `dest="course"` in argparse to avoid Python keyword. |
| `--slot` | Yes | Time slot: `"Day Time"` (e.g., `"Monday 9:00"`, `"Wed 14:30"`) — identifies the **target** class (destination) |
| `--from-class` | No | Course name of the **source** class; required with `--from-slot` when the student name matches multiple students |
| `--from-slot` | No | Time slot of the **source** class; required with `--from-class` when the student name matches multiple students |
| `--dry-run` | No | Log actions without making changes |
| `--limit N` | No | Only re-split first N notes (for testing) |

**Examples:**
```bash
# Move "Emma" to Pam & Paul Monday 9:00 (unambiguous)
--student "Emma" --class "Pam & Paul" --slot "Monday 9:00"

# Move "John" when he exists in multiple classes — specify source class
--student "John" --class "Mousy" --slot "Wednesday 10:00" --from-class "Pam & Paul" --from-slot "Monday 9:00"
```

### Resolving Student by Name

1. List all students (paginate if needed; use `Query.limit(500)` or similar); filter by name (case-insensitive match).
2. If **no match** → abort: `"No student found with name '{name}'."`
3. If **one match** → use that student (source class = student's current class).
4. If **multiple matches** → require both `--from-class` and `--from-slot` to disambiguate. Resolve source class via `--from-class` + `--from-slot`; filter to students whose `class` matches that class ID. If `--from-class`/`--from-slot` missing → abort: `"Multiple students named '{name}'. Use --from-class and --from-slot to specify source class."`
5. **Abort if 2+ students with same name in source class:** After narrowing to source class, if more than one student in that class has the matching name → abort: `"Duplicate student name '{name}' in source class. Cannot determine which student to move. Resolve duplicates manually first."`

### Resolving Class by Name and Time Slot

1. Parse `--slot` into `day_of_week` and `time_block`:
   - Accept `"Monday 9:00"`, `"Wed 14:30"`, `"Wednesday 10:00"`.
   - Day: support full names (Monday, Tuesday, …) and abbreviations (Mon, Tue, Wed, …).
   - Time: `"HH:MM"` or `"HHMM"` → normalize to `"HH:MM"`.
2. Standardize course name via `COURSE_MAPPING` (reuse from `add_class_note.py` or define locally).
3. Query classes: `course` + `day_of_week` + `time_block` + `school_year` (use `SCHOOL_YEAR` from env or default `"2025-2026"`).
4. If **one match** → use that class.
5. If **no match** → abort: `"No class found for '{course}' at '{slot}'."`
6. If **multiple matches** → abort (schema should prevent this).

### Flow

1. **Resolve target class**
   - Parse `--class` and `--slot`; query for class; abort if not found.

2. **Resolve student**
   - List students matching `--student` by name.
   - If multiple matches, resolve `--from-slot` to source class; pick student in that class.
   - Abort if not found or ambiguous (and `--from-slot` missing).

3. **Duplicate student check**
   - Query students where `class` = target class ID (students already in target class)
   - If any has the same `name` as the student being moved → **abort with clear error**
   - Error message: `"Duplicate student: '{name}' already exists in target class. Resolve duplicate before moving."`

4. **Verify student is in wrong class**
   - Compare student's current `class` with target class ID
   - If already in target class → abort: `"Student is already in target class."`

5. **Move student**
   - Update student document: set `class` = target class ID
   - Use `databases.update_document(database_id, "students", student_id, {"class": target_class_id})`
   - Skip in dry-run

6. **List notes to re-split**
   - Query notes where:
     - `class` = target class ID
     - `is_transcribed` = true
     - `is_split` = true
   - Apply `--limit N` if provided

7. **Re-split each note**
   - For each note: `databases.update_document(..., "notes", note_id, {"is_split": False})`
   - This triggers the `split-notes-by-student` Appwrite function (event-driven)
   - Log each note ID as it is updated
   - Skip in dry-run

8. **Summary**
   - Print: student moved, count of notes re-split, any errors

### Duplicate Check Logic

```python
def check_duplicate_student(target_class_students: list, student_name: str) -> bool:
    """Return True if a student with the same name exists in the target class."""
    for s in target_class_students:
        if s.get("name", "").strip().lower() == student_name.strip().lower():
            return True
    return False
```

- Case-insensitive name comparison
- Run before moving the student
- If duplicate found: print error, exit with non-zero code

### Slot Parsing

- **Day:** Map abbreviations to full names (Mon→Monday, Wed→Wednesday, etc.). Reuse `DAY_MAPPING` from `import_classes.py` if available.
- **Time:** Accept `"9:00"`, `"0930"`, `"14:30"`; normalize to `"HH:MM"` for `time_block`.
- **Slot format:** `"Day Time"` with space separator. E.g. `"Monday 9:00"`, `"Wed 14:30"`.

### Shared Constants

- `SCHOOL_YEAR`: Use `"2025-2026"` (or from env) when querying classes.
- `COURSE_MAPPING`: Reuse from `add_class_note.py` for standardizing course names; or copy into script to avoid cross-import.

### API Usage (Appwrite Python SDK)

- `databases.get_document(database_id, collection_id, document_id)` — fetch student, class
- `databases.list_documents(database_id, collection_id, queries=[...])` — list notes, list students in class
- `databases.update_document(database_id, collection_id, document_id, data)` — move student, reset is_split

### Query for Notes

```python
Query.equal("class", target_class_id),
Query.equal("is_transcribed", True),
Query.equal("is_split", True),
Query.limit(500),  # safety cap
```

### Error Handling

- Catch Appwrite API errors; print message and stack trace; exit 1
- On duplicate or validation failure: exit 1 with clear message

## Usage Examples

```bash
# Full run — move Emma to Pam & Paul Monday 9:00
uv run python scripts/move_student_and_resplit_notes.py --student "Emma" --class "Pam & Paul" --slot "Monday 9:00"

# Dry run (no changes)
uv run python scripts/move_student_and_resplit_notes.py --student "Emma" --class "Pam & Paul" --slot "Monday 9:00" --dry-run

# Disambiguate when name matches multiple students — specify source class
uv run python scripts/move_student_and_resplit_notes.py --student "John" --class "Mousy" --slot "Wednesday 10:00" --from-class "Pam & Paul" --from-slot "Monday 9:00"

# Test with first 2 notes only
uv run python scripts/move_student_and_resplit_notes.py --student "Emma" --class "Pam & Paul" --slot "Monday 9:00" --limit 2
```

## Out of Scope (per user)

- Concurrent update throttling
- Report card regeneration
- Merging duplicate students (script aborts instead)

## Files to Create

| File | Purpose |
|------|---------|
| `scripts/move_student_and_resplit_notes.py` | Main script |

## Dependencies

- Uses existing `config.py` (databases, database_id)
- No new packages required (appwrite, dotenv already in use)
