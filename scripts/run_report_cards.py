from typing import cast
from datetime import datetime
from config import databases, database_id
from appwrite.permission import Permission
from appwrite.role import Role
from appwrite.query import Query


def create_report_card(student_id):
    """Create a new report card document for a student"""
    report_card_data = {
        "when": datetime.now().isoformat(),
        "is_generated": False,
        "student": student_id,
        "template": "67b4f59d000dc6068175",
    }

    try:
        # Create report card document with permissions
        result = databases.create_document(
            database_id=database_id,
            collection_id="report_cards",
            document_id="unique()",
            data=report_card_data,
            permissions=[
                Permission.read(Role.user("67b972280034245d5ba1")),
            ],
        )
        print(f"Created report card for student {student_id}")
        return result
    except Exception as e:
        print(f"Error creating report card for student {student_id}: {str(e)}")
        return None


def delete_report_cards(students):
    for student in students:
        for report_card in student["report_cards"]:
            databases.delete_document(
                database_id=database_id,
                collection_id="report_cards",
                document_id=report_card["$id"],
            )
            print(f"Deleted report card {report_card['$id']} for student {student['$id']}")
        student["report_cards"] = []


def main():
    try:
        # Fetch all students
        response = cast(dict, databases.list_documents(
            database_id=database_id,
            collection_id="students",
            queries=[Query.limit(100)],
        ))

        delete_report_cards(response["documents"])

        # Filter students with empty report_cards
        students = [s for s in response["documents"] if not s.get("report_cards")]
        print(f"Found {len(students)} students without report cards")

        # Create report cards for each student
        for student in students:
            create_report_card(student["$id"])

    except Exception as e:
        print(f"Error fetching students: {str(e)}")


if __name__ == "__main__":
    main()
