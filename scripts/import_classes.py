import csv
import argparse
from config import databases, database_id


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
                current_class = {
                    "course": course_name,
                    "schedule": schedule,
                    "students": [],
                }
            else:  # It's a student name
                if current_class is not None:
                    current_class["students"].append({"name": value})

    if current_class:
        classes.append(current_class)

    return classes


def save_class_to_appwrite(class_dict):
    try:
        response = databases.create_document(
            database_id=database_id,
            collection_id="classes",
            document_id="unique()",
            data=class_dict,
        )
        print(f"Class {class_dict['course']} saved successfully: {response}")
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
