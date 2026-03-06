"""
One-time script to move a student from the wrong class to the correct class
and re-split class notes so the student receives their assigned content.

Usage:
  uv run python scripts/move_student_and_resplit_notes.py --student "Emma" --class "Pam & Paul" --slot "Monday 9:00"
"""

import argparse
import sys
import traceback
from typing import cast

from appwrite.query import Query

from config import databases, database_id

SCHOOL_YEAR = "2025-2026"

# Day of week mapping (abbreviations to full names)
DAY_MAPPING = {
    "Mon": "Monday",
    "Tue": "Tuesday",
    "Wed": "Wednesday",
    "Thu": "Thursday",
    "Fri": "Friday",
    "Sat": "Saturday",
    "Sun": "Sunday",
}

# Course name mapping (variations to standardized names)
COURSE_MAPPING = {
    "Mousy": "Mousy",
    "Mousu": "Mousy",
    "Linda": "Linda",
    "Pam & Paul": "Pam & Paul",
    "P&P": "Pam & Paul",
    "Pam&Paul": "Pam & Paul",
    "Pam and Paul": "Pam & Paul",
    "Oliver": "Oliver",
    "Marcia": "Marcia",
    "Timezone": "Time Zone",
}


def standardize_course_name(course: str) -> str:
    """Standardize course name using COURSE_MAPPING. Raises ValueError if not found."""
    if course in COURSE_MAPPING:
        return COURSE_MAPPING[course]
    raise ValueError(
        f"Unknown course name: {course}. "
        f"Valid courses: {', '.join(sorted(set(COURSE_MAPPING.values())))}"
    )


def expand_day_of_week(day: str) -> str:
    """Expand day abbreviation to full name if applicable."""
    return DAY_MAPPING.get(day, day)


def format_time(time_str: str) -> str:
    """Normalize time to HH:MM format."""
    time_str = time_str.strip()
    if len(time_str) == 4 and time_str.isdigit():
        return f"{time_str[:2]}:{time_str[2:]}"
    return time_str


def parse_slot(slot: str) -> tuple[str, str]:
    """
    Parse slot string "Day Time" into (day_of_week, time_block).
    E.g. "Monday 9:00" -> ("Monday", "9:00"), "Wed 0930" -> ("Wednesday", "09:30").
    """
    parts = slot.strip().split(None, 1)
    if len(parts) != 2:
        raise ValueError(f"Invalid slot format: '{slot}'. Expected 'Day Time' (e.g. 'Monday 9:00').")
    day_part, time_part = parts
    day_of_week = expand_day_of_week(day_part)
    time_block = format_time(time_part)
    return day_of_week, time_block


def get_class_document(
    course: str, day_of_week: str, time_block: str, include_students: bool = True
) -> dict:
    """
    Resolve class by course, day, and time. Returns class document with students expanded.
    Aborts if not found or multiple.
    """
    course_std = standardize_course_name(course)
    queries = [
        Query.equal("course", course_std),
        Query.equal("day_of_week", day_of_week),
        Query.equal("time_block", time_block),
        Query.equal("school_year", SCHOOL_YEAR),
        Query.limit(2),
    ]
    if include_students:
        queries.insert(0, Query.select(["*", "students.*"]))
    response = cast(
        dict,
        databases.list_documents(
            database_id=database_id,
            collection_id="classes",
            queries=queries,
        ),
    )
    docs = response.get("documents", [])
    if len(docs) == 0:
        raise ValueError(f"No class found for '{course}' at '{day_of_week} {time_block}'.")
    if len(docs) > 1:
        raise ValueError(f"Multiple classes found for '{course}' at '{day_of_week} {time_block}'.")
    return docs[0]


def get_class_id(course: str, day_of_week: str, time_block: str) -> str:
    """Resolve class by course, day, and time. Returns class document ID."""
    return get_class_document(course, day_of_week, time_block, include_students=False)["$id"]


def _extract_class_id(student_doc: dict) -> str | None:
    """Extract class ID from student document (handles relation as ID or object)."""
    cls = student_doc.get("class")
    if cls is None:
        return None
    if isinstance(cls, str):
        return cls
    if isinstance(cls, dict) and "$id" in cls:
        return cls["$id"]
    return None


def _students_from_class_doc(class_doc: dict) -> list[dict]:
    """Extract students list from a class document (with students.* expanded)."""
    students = class_doc.get("students", [])
    if isinstance(students, list):
        return students
    return []


def resolve_student(
    student_name: str,
    from_course: str | None,
    from_slot: str | None,
) -> dict:
    """
    Resolve student by name. Fetches class document(s) with students expanded
    (Query.select(['*', 'students.*'])), then finds student in those students.
    Aborts if not found, ambiguous (multiple matches without from-class/from-slot),
    or duplicate in source class (2+ with same name).
    """
    name_lower = student_name.strip().lower()

    if from_course and from_slot:
        # Fetch source class with students expanded
        day_of_week, time_block = parse_slot(from_slot)
        class_doc = get_class_document(from_course, day_of_week, time_block, include_students=True)
        students = _students_from_class_doc(class_doc)
        matches = [s for s in students if s.get("name", "").strip().lower() == name_lower]
        if len(matches) == 0:
            raise ValueError(
                f"No student named '{student_name}' found in source class "
                f"({from_course} at {from_slot})."
            )
        if len(matches) >= 2:
            raise ValueError(
                f"Duplicate student name '{student_name}' in source class. "
                "Cannot determine which student to move. Resolve duplicates manually first."
            )
        return matches[0]

    # No from-class/from-slot: list all classes with students, search across them
    response = cast(
        dict,
        databases.list_documents(
            database_id=database_id,
            collection_id="classes",
            queries=[
                Query.equal("school_year", SCHOOL_YEAR),
                Query.select(["*", "students.*"]),
                Query.limit(100),
            ],
        ),
    )
    all_matches: list[dict] = []
    for class_doc in response.get("documents", []):
        students = _students_from_class_doc(class_doc)
        for s in students:
            if s.get("name", "").strip().lower() == name_lower:
                all_matches.append(s)

    if len(all_matches) == 0:
        raise ValueError(f"No student found with name '{student_name}'.")
    if len(all_matches) == 1:
        return all_matches[0]
    # Multiple matches - check for duplicate in same class (abort) or across classes (need --from)
    # Group by class to detect same-class duplicates
    class_ids = [_extract_class_id(s) for s in all_matches]
    if len(class_ids) != len(set(class_ids)):
        # At least two matches share the same class
        raise ValueError(
            f"Duplicate student name '{student_name}' in source class. "
            "Cannot determine which student to move. Resolve duplicates manually first."
        )
    raise ValueError(
        f"Multiple students named '{student_name}'. "
        "Use --from-class and --from-slot to specify source class."
    )


def _list_students_in_class(class_id: str) -> list[dict]:
    """List all students in a class by fetching the class document with students expanded."""
    class_doc = cast(
        dict,
        databases.get_document(
            database_id=database_id,
            collection_id="classes",
            document_id=class_id,
            queries=[Query.select(["*", "students.*"])],
        ),
    )
    return _students_from_class_doc(class_doc)


def has_duplicate_in_target(target_class_students: list[dict], student_name: str) -> bool:
    """Return True if a student with the same name exists in the target class."""
    name_lower = student_name.strip().lower()
    for s in target_class_students:
        if s.get("name", "").strip().lower() == name_lower:
            return True
    return False


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Move a student to the correct class and re-split notes."
    )
    parser.add_argument("--student", required=True, help="Student name (e.g. 'Emma', 'John Smith')")
    parser.add_argument(
        "--class",
        dest="course",
        required=True,
        help="Target course/class name (e.g. 'Pam & Paul', 'Mousy')",
    )
    parser.add_argument(
        "--slot",
        required=True,
        help="Target time slot: 'Day Time' (e.g. 'Monday 9:00', 'Wed 14:30')",
    )
    parser.add_argument(
        "--from-class",
        dest="from_course",
        help="Source course name; required when student name matches multiple students",
    )
    parser.add_argument(
        "--from-slot",
        help="Source time slot; required with --from-class when student name matches multiple",
    )
    parser.add_argument("--dry-run", action="store_true", help="Log actions without making changes")
    parser.add_argument("--limit", type=int, help="Only re-split first N notes (for testing)")
    args = parser.parse_args()

    try:
        # 1. Resolve target class
        day_of_week, time_block = parse_slot(args.slot)
        target_class_id = get_class_id(args.course, day_of_week, time_block)
        print(f"Target class: {args.course} at {args.slot} (id={target_class_id})")

        # 2. Resolve student
        student = resolve_student(args.student, args.from_course, args.from_slot)
        student_id = student["$id"]
        student_name = student.get("name", args.student)
        current_class_id = _extract_class_id(student)
        print(f"Student: {student_name} (id={student_id}), current class id={current_class_id}")

        # 3. Duplicate check in target class
        target_students = _list_students_in_class(target_class_id)
        if has_duplicate_in_target(target_students, student_name):
            print(
                f"Error: Duplicate student '{student_name}' already exists in target class. "
                "Resolve duplicate before moving.",
                file=sys.stderr,
            )
            return 1

        # 4. Verify student is in wrong class
        if current_class_id == target_class_id:
            print("Error: Student is already in target class.", file=sys.stderr)
            return 1

        # 5. Move student
        if args.dry_run:
            print("[DRY RUN] Would move student to target class")
        else:
            databases.update_document(
                database_id=database_id,
                collection_id="students",
                document_id=student_id,
                data={"class": target_class_id},
            )
            print("Moved student to target class.")

        # 6. List notes to re-split
        note_limit = args.limit if args.limit is not None else 500
        response = cast(
            dict,
            databases.list_documents(
                database_id=database_id,
                collection_id="notes",
                queries=[
                    Query.equal("class", target_class_id),
                    Query.equal("is_transcribed", True),
                    Query.equal("is_split", True),
                    Query.limit(note_limit),
                ],
            ),
        )
        notes = response.get("documents", [])
        print(f"Found {len(notes)} notes to re-split.")

        # 7. Re-split each note
        resplit_count = 0
        for note in notes:
            note_id = note.get("$id")
            if not note_id:
                continue
            if args.dry_run:
                print(f"[DRY RUN] Would re-split note {note_id}")
            else:
                databases.update_document(
                    database_id=database_id,
                    collection_id="notes",
                    document_id=note_id,
                    data={"is_split": False},
                )
                print(f"Re-split note {note_id}")
            resplit_count += 1

        # 8. Summary
        print(f"Done. Student moved. Re-split {resplit_count} notes.")
        return 0

    except ValueError as e:
        print(f"Error: {e}", file=sys.stderr)
        return 1
    except Exception as e:
        print(f"Error: {e}", file=sys.stderr)
        traceback.print_exc()
        return 1


if __name__ == "__main__":
    sys.exit(main())
