# GradeBee Scripts

Utility scripts for managing the GradeBee Appwrite backend.

## Configuration

All scripts require environment variables to be set (via `.env` file):

- `APPWRITE_ENDPOINT` - Appwrite API endpoint
- `APPWRITE_PROJECT_ID` - Appwrite project ID
- `APPWRITE_API_KEY` - Appwrite API key
- `APPWRITE_DATABASE_ID` - Database ID
- `NOTES_BUCKET_ID` - Storage bucket ID for voice notes
- `DEFAULT_USER_ID` - Default user ID for permissions

## Scripts

### add_class_note.py

Uploads voice notes (audio files) to Appwrite storage and creates note documents linked to classes.

**Usage:**
```bash
# Batch process all audio files in a folder
python add_class_note.py <folder_path>

# Upload a single file
python add_class_note.py <course> <day_of_week> <time_block> <file_path> [-d]
```

- Supports `.m4a`, `.aac`, `.mp4` files
- Batch mode parses filenames in format `Day-Course@HHMM.m4a` (e.g., `Wed-Mousy@1430.m4a`)
- `-d` flag deletes existing note before uploading
- Re-encodes audio files for lower quality/smaller size

### config.py

Shared configuration module. Sets up Appwrite client and exports:
- `databases` - Appwrite Databases service
- `storage` - Appwrite Storage service
- `database_id`, `bucket_id`, `default_user_id`

### export_notes.py

Exports all student notes to a CSV file.

**Usage:**
```bash
python export_notes.py
```

Creates `student_notes.csv` with columns: Course, Schedule, Student, Note1, Note2, ...

### import_classes.py

Imports classes and students from a CSV file into the database.

**Usage:**
```bash
python import_classes.py <csv_file>
```

CSV format:
- Class rows: `CourseName-Day@HHMM` (e.g., `Mousy-Wed@1430`)
- Student rows: `StudentName,motivation,learning,behaviour`

Skips classes that already exist.

### run_report_cards.py

Creates report card documents for all students without one.

**Usage:**
```bash
python run_report_cards.py
```

Deletes all existing report cards first, then creates new ones for each student.

### update_appwrite_project.py

Copies Appwrite project configuration between environments while preserving target's project ID and name.

**Usage:**
```bash
python update_appwrite_project.py <source_env> <target_env>
```

Reads from `envs/<source>/appwrite.json` and writes to `envs/<target>/appwrite.json`.

### update_note_permissions.py

One-time migration script to fix permissions on notes and student_notes that were created without proper access permissions.

**Usage:**
```bash
python update_note_permissions.py
```

Only updates documents with no permissions or `user:None` permissions.
