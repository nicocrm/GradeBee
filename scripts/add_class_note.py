from datetime import datetime
import subprocess
import sys
from tempfile import TemporaryDirectory
from typing import cast, Tuple
from appwrite.query import Query
from appwrite.input_file import InputFile
from appwrite.permission import Permission
from appwrite.role import Role
from config import storage, databases, database_id, bucket_id, default_user_id
import logging
import os
import glob
import re

# Configure logging
logging.basicConfig(
    level=logging.INFO,  # Changed from ERROR to INFO to see more messages
    format="%(asctime)s - %(levelname)s - %(message)s"
)

# Course name mapping (variations to standardized names)
COURSE_MAPPING = {
    # Mousy variations
    'Mousy': 'Mousy',
    'Mousu': 'Mousy',
    
    # Linda (no variations)
    'Linda': 'Linda',
    
    # Pam & Paul variations
    'Pam & Paul': 'Pam & Paul',
    'P&P': 'Pam & Paul',
    'Pam&Paul': 'Pam & Paul',
    'Pam and Paul': 'Pam & Paul',
    
    # Oliver (no variations)
    'Oliver': 'Oliver',
    # Marcia (no variations)
    'Marcia': 'Marcia',
    'Timezone': 'Time Zone'
}

def standardize_course_name(course: str) -> str:
    """
    Standardize a course name using the mapping.
    Returns the standardized name or raises ValueError if not found.
    """
    # Try exact match (case-sensitive)
    if course in COURSE_MAPPING:
        return COURSE_MAPPING[course]
    
    raise ValueError(f"Unknown course name: {course}. Valid courses are: {', '.join(sorted(set(COURSE_MAPPING.values())))}")


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
    except Exception as e:
        logging.error(f"Error uploading file {file_path}: {str(e)}")
        raise


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
            raise ValueError(f"Class not found for course: {course}, day: {day_of_week}, time: {time_block}")
    except Exception as e:
        logging.error(f"Error retrieving class document: {str(e)}", exc_info=True)
        raise


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
            permissions=[
                Permission.read(Role.user(default_user_id)),
                Permission.update(Role.user(default_user_id)),
                Permission.delete(Role.user(default_user_id)),
            ],
        )
        logging.info("Note created successfully.")
    except Exception as e:
        logging.error(f"Error creating note: {str(e)}")
        raise


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
                logging.info("Note deleted successfully.")

            # Delete the file
            storage.delete_file(bucket_id=bucket_id, file_id=file_id)
            logging.info("File deleted successfully.")
    except Exception as e:
        logging.error(f"Error deleting resources: {str(e)}")
        raise


def upload_voice_note(course, day_of_week, time_block, file_path, delete_existing):
    try:
        class_id = get_class_document(course, day_of_week, time_block)

        if delete_existing:
            delete_resources(file_path, class_id)
        audio_file_id = upload_audio_file(file_path)
        create_note_for_class(class_id, audio_file_id)
        
        # Delete the file after successful processing
        try:
            os.remove(file_path)
            logging.info(f"Deleted processed file: {file_path}")
        except Exception as e:
            logging.warning(f"Could not delete file {file_path}: {str(e)}")
    except Exception as e:
        logging.error(f"Error processing note: {str(e)}")
        raise


def parse_filename(filename: str) -> Tuple[str, str, str]:
    """
    Parse filename in format 'Day-Course@HHMM.m4a' or 'Course-Day@HHMM.m4a' to extract course, day, and time.
    Returns (course, day, time) tuple.
    Supports both abbreviated (e.g., 'Wed') and full day names (e.g., 'Wednesday').
    Ignores letter suffixes (e.g., 'b', 'c') after the time.
    Ignores (n) suffixes at the end of the filename (e.g., '(1)', '(2)').
    """
    # Remove file extension
    name_without_ext = os.path.splitext(filename)[0]
    
    # Remove any (n) suffix from the filename
    name_without_ext = re.sub(r'\(\d+\)$', '', name_without_ext)
    
    # Split by @ to separate time
    parts = name_without_ext.split('@')
    if len(parts) != 2:
        raise ValueError(f"Invalid filename format: {filename}")
    
    # Parse time (HHMM format), ignoring any letter suffix
    time_str = parts[1]
    # Remove any letter suffix (e.g., 'b', 'c') from the time
    time_str = re.sub(r'[a-zA-Z]+$', '', time_str)
    
    if not re.match(r'^\d{4}$', time_str):
        raise ValueError(f"Invalid time format in {filename}")
    time = f"{time_str[:2]}:{time_str[2:]}"
    
    # Split by - to separate day and course
    day_course = parts[0].split('-')
    if len(day_course) != 2:
        raise ValueError(f"Invalid day-course format in {filename}")
    
    # Try both possible orders (day-course and course-day)
    first_part = day_course[0]
    second_part = day_course[1]
    
    # Day name mapping (abbreviations to full names)
    day_mapping = {
        'Mon': 'Monday',
        'Tue': 'Tuesday',
        'Wed': 'Wednesday',
        'Thu': 'Thursday',
        'Fri': 'Friday',
        'Sat': 'Saturday',
        'Sun': 'Sunday'
    }
    
    # List of valid full day names
    valid_days = list(day_mapping.values())
    
    # Try first part as day
    if first_part in valid_days:
        day = first_part
        course = second_part
    else:
        # Try first part as day abbreviation
        day_abbr = first_part[:3].capitalize()
        if day_abbr in day_mapping:
            day = day_mapping[day_abbr]
            course = second_part
        else:
            # Try second part as day
            if second_part in valid_days:
                day = second_part
                course = first_part
            else:
                # Try second part as day abbreviation
                day_abbr = second_part[:3].capitalize()
                if day_abbr in day_mapping:
                    day = day_mapping[day_abbr]
                    course = first_part
                else:
                    raise ValueError(f"Could not identify day of week in {filename}")
    
    # Standardize the course name
    course = standardize_course_name(course)
    
    return course, day, time


def process_folder(folder_path):
    """Process all audio files in the specified folder."""
    # Supported audio file extensions
    audio_extensions = ['*.m4a', '*.aac', '*.mp4']
    
    # Get all audio files in the folder
    audio_files = []
    for ext in audio_extensions:
        audio_files.extend(glob.glob(os.path.join(folder_path, ext)))
    
    if not audio_files:
        logging.info(f"No audio files found in {folder_path}")
        return
    
    # Process each audio file
    logging.info(f"Processing {len(audio_files)} files...")
    success_count = 0
    error_count = 0
    
    for file_path in audio_files:
        filename = os.path.basename(file_path)
        try:
            course, day, time = parse_filename(filename)
            logging.info(f"Processing {filename}...")
            logging.info(f"  Course: {course}")
            logging.info(f"  Day: {day}")
            logging.info(f"  Time: {time}")
            upload_voice_note(course, day, time, file_path, False)
            success_count += 1
        except ValueError as e:
            logging.warning(f"Skipping {filename}: {str(e)}")
            error_count += 1
            continue
        except Exception as e:
            logging.error(f"Error processing {filename}: {str(e)}")
            error_count += 1
            continue
    
    logging.info("\nProcessing complete:")
    logging.info(f"  Successfully processed: {success_count} files")
    logging.info(f"  Errors/Skips: {error_count} files")


if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python add_class_note.py <folder_path>")
        print("   or: python add_class_note.py <course> <day_of_week> <time_block> <file_path> [-d]")
        sys.exit(1)

    if len(sys.argv) == 2:
        # Process all notes from folder
        folder_path = sys.argv[1]
        if not os.path.isdir(folder_path):
            print(f"Error: {folder_path} is not a valid directory")
            sys.exit(1)
        process_folder(folder_path)
    else:
        # Process single file
        if len(sys.argv) < 5 or len(sys.argv) > 6:
            print("Usage: python add_class_note.py <course> <day_of_week> <time_block> <file_path> [-d]")
            sys.exit(1)

        course_name = sys.argv[1]
        day_of_week = sys.argv[2]
        time_block = sys.argv[3]
        file_path = sys.argv[4]
        delete_flag = "-d" in sys.argv

        try:
            upload_voice_note(course_name, day_of_week, time_block, file_path, delete_flag)
        except Exception as e:
            print(f"Error: {str(e)}")
            sys.exit(1)
