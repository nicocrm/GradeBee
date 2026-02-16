# AGENTS.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Project Overview

Grade Bee is a mobile application for teachers to record voice notes and generate AI-powered report cards. Built with Flutter (frontend) and Appwrite (backend), with Dart serverless functions for AI processing.

## Development Commands

Uses `just` task runner. All commands support environments: `dev`, `prod`, `test`.

```bash
# Environment setup
just env dev                  # Set environment (copies appwrite.json and generates .env files)
just status                   # Show environment status

# Appwrite sync
just pull dev                 # Pull config from Appwrite, save to envs/dev/
just push dev                 # Push config to Appwrite

# Flutter web
just build-web                # Build web app (runs flutter build web in app/)
just deploy dev               # Build + publish to S3 + Amplify deployment

# Run Appwrite functions locally
appwrite run functions --with-variables

# Flutter app tests
cd app && flutter test

# Function tests (each function is a separate Dart package)
cd functions/create-report-card && dart test
cd functions/gradebee-models && dart test
```

## Architecture

### Flutter App (`app/`)

Feature-based structure using vanilla Flutter (no Riverpod/Bloc by design decision):

```
app/lib/
├── main.dart                    # Entry point, loads .env, initializes GetIt
├── features/                    # Feature modules
│   ├── auth/                    # Login screen and VM
│   ├── class_list/              # Classes, notes, students
│   │   ├── models/              # Class, Note, Student, PendingNote
│   │   ├── repositories/        # ClassRepository
│   │   ├── vm/                  # ViewModels (ChangeNotifier-based)
│   │   └── widgets/
│   └── student_details/         # Individual student view, report cards
│       ├── models/              # Student, ReportCard, ReportCardTemplate
│       ├── repositories/        # StudentRepository
│       ├── services/            # ReportCardService
│       └── vm/
└── shared/
    ├── data/                    # Core services registered via GetIt
    │   ├── app_initializer.dart # DI setup
    │   ├── database.dart        # DatabaseService (Appwrite wrapper)
    │   ├── storage_service.dart # File storage
    │   ├── auth_state.dart      # Authentication
    │   ├── sync_service.dart    # Offline note sync
    │   └── local_storage.dart   # SharedPreferences wrapper
    ├── ui/                      # Shared widgets, mixins
    └── router.dart              # GoRouter config
```

Dependency injection uses `GetIt`. Services are registered in `AppInitializer.initializeServices()`.

### Appwrite Functions (`functions/`)

Dart serverless functions, each is a standalone package:

- **transcribe-note**: Transcribes voice notes via OpenAI
- **split-notes-by-student**: Parses transcribed notes into per-student entries
- **create-report-card**: Generates report cards using OpenAI

Shared packages:
- **gradebee-models**: Domain models used by functions
- **gradebee-function-helpers**: Database helpers, logging setup

Functions follow pattern: parse input → process → save → return result. See `create-report-card/lib/main.dart` for example.

**Important**: Models are intentionally NOT shared between app and functions (different bounded contexts, future offline support).

### Python Scripts (`scripts/`)

Utility scripts for data management using `uv` for dependencies:

- `add_class_note.py` - Batch upload voice notes
- `import_classes.py` - Import classes/students from CSV
- `run_report_cards.py` - Trigger report card generation
- `export_notes.py` - Export student notes to CSV

Scripts use shared config from `config.py`. Requires `.env` with Appwrite credentials.

### Environment Management

Environment configs stored in `envs/{dev,prod,test}/`:
- `appwrite.json` - Appwrite project config
- `.env` - Environment variables

`just env <name>` copies these to root and generates derived `.env` files for app/ and functions/.

## Testing

- Flutter: Uses `mockito` with generated mocks (`@GenerateMocks` annotation, run `dart run build_runner build`)
- Functions: Standard Dart `test` package
- Mock files: `*.mocks.dart` (gitignored, generated)

## Key Conventions

- ViewModels extend `ChangeNotifier`, use `_vm.dart` suffix
- Models use `.model.dart` suffix
- Prefer relative imports (enforced in `analysis_options.yaml`)
- Use `unawaited()` for fire-and-forget futures (linter rule enabled)
