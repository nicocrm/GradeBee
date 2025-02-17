from datetime import datetime
import subprocess
import sys
from tempfile import TemporaryDirectory
from typing import cast
from appwrite.query import Query
from appwrite.input_file import InputFile
from config import storage, databases, database_id, bucket_id
import logging
import os

# Configure logging
logging.basicConfig(
    level=logging.ERROR, format="%(asctime)s - %(levelname)s - %(message)s"
)


def reencode_low_quality(input_file: str):
    with TemporaryDirectory() as tmpdir:
        tempfile = tmpdir + "/" + os.path.basename(input_file)
        command = [
            "ffmpeg",
            "-i",
            input_file,
            "-vcodec",
            "libx264",
            "-acodec",
            "aac",
            "-b:a",
            "64k",
            "-y",
            tempfile,
        ]
        subprocess.run(command, check=True)
        os.rename(tempfile, input_file)


def upload_audio_file(file_path):
    """Uploads an audio file to Appwrite storage."""
    if (
        file_path.endswith(".m4a")
        or file_path.endswith(".aac")
        or file_path.endswith(".mp4")
    ):
        reencode_low_quality(file_path)
    try:
        response = cast(
            dict,
            storage.create_file(
                bucket_id=bucket_id,
                file_id="unique()",
                file=InputFile.from_path(file_path),
            ),
        )
        return response["$id"]
    except Exception:
        logging.error("Error uploading file", exc_info=True)
        sys.exit(1)


def get_class_document(course, day_of_week, time_block):
    """Retrieves the class document from the database."""
    try:
        response = cast(
            dict,
            databases.list_documents(
                database_id=database_id,
                collection_id="classes",
                queries=[
                    Query.equal("course", course),
                    Query.equal("day_of_week", day_of_week),
                    Query.equal("time_block", time_block),
                ],
            ),
        )
        if response["total"] > 0:
            return response["documents"][0]["$id"]
        else:
            logging.error("Class not found.")
            sys.exit(1)
    except Exception as e:
        logging.error("Error retrieving class document", exc_info=True)
        sys.exit(1)


def create_note_for_class(class_id, audio_file_id):
    """Creates a note in the notes collection."""
    try:
        databases.create_document(
            database_id=database_id,
            collection_id="notes",
            document_id="unique()",
            data={
                "class": class_id,
                "when": datetime.now().isoformat(),
                "voice": audio_file_id,
            },
        )
        print("Note created successfully.")
    except Exception as e:
        logging.error("Error creating note", exc_info=True)
        sys.exit(1)


def delete_resources(file_path, class_id):
    """Deletes the specified file and associated note."""
    try:
        # Find the file in the bucket
        file_name = os.path.basename(file_path)
        files_response = cast(
            dict,
            storage.list_files(
                bucket_id=bucket_id, queries=[Query.equal("name", file_name)]
            ),
        )
        file_to_delete = next(
            (f for f in files_response["files"] if f["name"] == file_name), None
        )

        if file_to_delete:
            file_id = file_to_delete["$id"]

            # Find the note with the class_id and voice attribute matching the file_id
            notes_response = cast(
                dict,
                databases.list_documents(
                    database_id=database_id,
                    collection_id="notes",
                    queries=[
                        Query.equal("class", class_id),
                        Query.equal("voice", file_id),
                    ],
                ),
            )

            if notes_response["total"] > 0:
                note_id = notes_response["documents"][0]["$id"]
                databases.delete_document(
                    database_id=database_id, collection_id="notes", document_id=note_id
                )
                print("Note deleted successfully.")

            # Delete the file
            storage.delete_file(bucket_id=bucket_id, file_id=file_id)
            print("File deleted successfully.")
    except Exception:
        logging.error("Error deleting resources", exc_info=True)
        sys.exit(1)


def main(course, day_of_week, time_block, file_path, delete_flag):
    class_id = get_class_document(course, day_of_week, time_block)

    if delete_flag:
        delete_resources(file_path, class_id)
    audio_file_id = upload_audio_file(file_path)
    create_note_for_class(class_id, audio_file_id)


if __name__ == "__main__":
    if len(sys.argv) < 5 or len(sys.argv) > 6:
        print("Usage: python add_class_note.py <course> <day_of_week> <time_block> <file_path> [-d]")
        sys.exit(1)

    course_name = sys.argv[1]
    day_of_week = sys.argv[2]
    time_block = sys.argv[3]
    file_path = sys.argv[4]
    delete_flag = "-d" in sys.argv

    main(course_name, day_of_week, time_block, file_path, delete_flag)
