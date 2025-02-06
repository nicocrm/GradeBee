import csv
from typing import cast
from config import databases, database_id


def fetch_classes():
    # Fetch classes from the database
    return cast(dict, databases.list_documents(database_id, "classes"))


def export_notes_to_csv():
    classes = fetch_classes()

    with open("student_notes.csv", mode="w", newline="") as file:
        writer = csv.writer(file)
        # Write the header
        writer.writerow(
            ["Course", "Schedule", "Student", "Note1", "Note2", "Note3", "..."]
        )

        for class_doc in classes["documents"]:
            course = class_doc["course"]
            schedule = class_doc["schedule"]
            students = class_doc["students"]

            for student_doc in students:
                student_name = student_doc["name"]
                notes = student_doc["notes"]
                note_texts = [note["text"] for note in notes]

                # Write the row for each student
                writer.writerow([course, schedule, student_name] + note_texts)


if __name__ == "__main__":
    export_notes_to_csv()
