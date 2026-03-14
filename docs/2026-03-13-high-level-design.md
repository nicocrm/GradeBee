This document is rough, high level design and should not be used to infer the project structure or architecture beyond initial planning.


# Voice Notes → Student Report System

## Goal

Allow teachers to record voice notes about students and automatically generate structured notes and report cards.

Teachers should only need to:

1. Maintain a simple student list
2. Upload voice recordings

The system handles transcription, note organization, and report generation.

---

# Architecture Overview

User connects their Google Drive to the application.

The application:

* reads student/class data from a spreadsheet
* watches a Drive folder for uploaded voice notes
* transcribes and processes recordings
* generates Markdown notes and report cards in Drive


%% to alleviate needs of a database to start, we could store the user information in JSON files in object storage:
%%
%% {
%%   "user_id": "user123",
%%   "services": {
%%     "google_drive": {
%%       "access_token": "ya29.a0AfH6SMD...",
%%       "refresh_token": "1//0gZrH...",
%%       "expires_at": "2026-03-13T14:00:00Z"
%%     },
%%     "google_sheets": {
%%       "access_token": "ya29.a0AfH6SMD...",
%%       "refresh_token": "1//0gZrH...",
%%       "expires_at": "2026-03-13T14:00:00Z"
%%     }
%%   }
%% }

---

# Google Drive Structure

```
VoiceNotes/
    uploads/        # teacher uploads recordings here
    notes/          # generated structured notes per student
    reports/        # generated report cards
```

Teachers interact only with:

```
uploads/
```

---

# Student Data Source

Student data is stored in a spreadsheet.

Spreadsheet name:

```
ClassSetup
```

Single sheet structure:

| class | student |
| ----- | ------- |
| 5A    | Lucas   |
| 5A    | Emma    |
| 5B    | Chloé   |

Rules for teachers:

* Do not rename columns
* Add rows freely
* One student per row

The spreadsheet is **read-only for the application**.

The application never modifies it.

---

# Voice Note Processing Pipeline

When a new file appears in:

```
uploads/
```

the system performs:

1. Download audio file
2. Speech-to-text transcription
3. Student name extraction
4. Match student name against spreadsheet list
5. Generate structured note

---

# Generated Notes

Notes are written as Markdown files.

%% We should convert them to google doc and include a feedback section

Example location:

```
notes/
    5A_Lucas/
        2026-03-13-reading.md
```

Example content:

```
# Lucas
Date: 2026-03-13
Topic: Reading

## Transcript
Lucas is improving a lot in reading but still struggles with long words.

## Summary
Lucas has shown clear improvement in reading fluency but still needs
support with complex vocabulary.
```

---

# Report Card Generation

When requested, the system aggregates notes per student and generates a report.

Example output:

```
reports/
    2026_term2/
        Lucas.md
        Emma.md
```

Example:

```
# Lucas — Term 2 Report

Lucas has made significant progress in reading fluency and participates
more confidently during reading activities.

Further work is recommended on spelling and vocabulary development.
```

%% We could include a feedback section so that the teacher can give feedback on each section and we can parse and regenerate that.
%% But it will be expensive, if we have to read all documents every time they want to rerun a single report card!
%% Suggest options

---

# Student Matching Strategy

Student names extracted from transcripts are matched against the student list.

Techniques used:

* AI-based entity extraction
* fuzzy name matching
* optional manual correction if confidence is low

---

# Design Principles

* Teachers interact mostly with Google Drive
* Spreadsheet used only for configuration
* Application never edits user spreadsheet
* Generated artifacts stored as Markdown
* Minimal UI required

---

# Benefits

* Very low friction for teachers
* Minimal UI development required
* Human-readable output
* Easy to extend with AI features
* Easy to export to other formats (PDF, Docs)


