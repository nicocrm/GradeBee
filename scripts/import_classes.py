import csv
from typing import cast
import argparse
from datetime import datetime
from config import databases, database_id
from appwrite.permission import Permission
from appwrite.role import Role
from appwrite.query import Query

OWNER_USER_ID = "67b972280034245d5ba1"
# Day of week mapping
DAY_MAPPING = {
    "Mon": "Monday",
    "Tue": "Tuesday",
    "Wed": "Wednesday",
    "Thu": "Thursday",
    "Fri": "Friday",
    "Sat": "Saturday",
    "Sun": "Sunday",
}


def expand_day_of_week(short_day):
    return DAY_MAPPING.get(short_day, short_day)


def parse_day_and_time(day_of_week_str):
    if "@" in day_of_week_str:
        day, time = day_of_week_str.split("@", 1)
        return expand_day_of_week(day.strip()), format_time(time.strip())
    return expand_day_of_week(day_of_week_str.strip()), None


def format_time(time_str):
    # Check if the time is in HHMM format
    if len(time_str) == 4 and time_str.isdigit():
        return f"{time_str[:2]}:{time_str[2:]}"  # Format as HH:MM
    return time_str  # Return as is if not in HHMM format


def add_student_notes(student, row):
    notes = {
        "motivation": row[1].strip(),
        "learning": row[2].strip(),
        "behaviour": row[3].strip(),
    }
    for key, value in notes.items():
        if value:
            student["notes"].append(
                {
                    "text": f"{key}: {value}",
                    "when": datetime.now().isoformat(),
                }
            )


def load_classes_from_csv(file_path):
    classes = []
    current_class = None

    with open(file_path, mode="r", newline="") as csvfile:
        reader = csv.reader(csvfile)
        for row in reader:
            if not row:
                continue
            value = row[0].strip()
            if "@" in value:  # It's a class name
                if current_class:
                    classes.append(current_class)
                course_name, schedule = value.split("-")
                day, time_block = parse_day_and_time(schedule)
                current_class = {
                    "course": course_name,
                    "day_of_week": day,
                    "time_block": time_block,
                    "students": [],
                }
            else:  # It's a student name
                if current_class is not None:
                    student_name = value.strip()
                    student = {"name": student_name, "notes": []}
                    add_student_notes(student, row)
                    current_class["students"].append(student)

    if current_class:
        classes.append(current_class)

    return classes


def save_class_to_appwrite(class_dict):
    try:
        # Check if the class already exists
        existing_classes = cast(
            dict,
            databases.list_documents(
                database_id=database_id,
                collection_id="classes",
                queries=[
                    Query.equal("course", class_dict["course"]),
                    Query.equal("day_of_week", class_dict["day_of_week"]),
                    Query.equal("time_block", class_dict["time_block"]),
                ],
            ),
        )

        if existing_classes["total"] > 0:
            print(f"Class {class_dict['course']} already exists. Skipping save.")
            return  # Skip saving if the class already exists

        # Update permissions
        permissions = [
            Permission.read(Role.user(OWNER_USER_ID)),
            Permission.update(Role.user(OWNER_USER_ID)),
        ]
        _ = databases.create_document(
            database_id=database_id,
            collection_id="classes",
            document_id="unique()",
            data=class_dict,
            permissions=permissions,
        )
        print(f"Class {class_dict['course']} saved successfully")
    except Exception as e:
        print(f"Failed to save class {class_dict['course']}: {e}")


def main():
    parser = argparse.ArgumentParser(
        description="Process a CSV file of classes and students."
    )
    parser.add_argument("csv_file", type=str, help="Path to the CSV file")
    args = parser.parse_args()

    classes = load_classes_from_csv(args.csv_file)
    for class_dict in classes:
        save_class_to_appwrite(class_dict)


if __name__ == "__main__":
    main()
