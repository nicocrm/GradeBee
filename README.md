# GradeBee

GradeBee helps teachers record voice notes about students and automatically generate structured notes and report cards. Teachers only need to maintain a simple student list and upload voice recordings -- the system handles transcription, note organization, and report generation.

## How It Works

1. Teacher signs in with Google and connects their Google Drive
2. The system creates a folder structure in Drive (`GradeBee/uploads/`, `notes/`, `reports/`)
3. Teacher maintains a `ClassSetup` spreadsheet with class and student names
4. Teacher uploads voice recordings (or drops them into `uploads/`)
5. The system transcribes audio, extracts student names, and generates structured notes as Google Docs
6. On demand, the system aggregates notes into report cards per student

Teachers interact primarily with Google Drive. The web UI is minimal by design.

## Technology Stack

| Layer          | Technology                                             |
| -------------- | ------------------------------------------------------ |
| Frontend       | React 19, TypeScript, Vite                             |
| Routing        | react-router-dom v7                                    |
| Authentication | Clerk (Google OAuth with Drive/Sheets scopes)          |
| Backend        | Go 1.24, plain `net/http`                              |
| Storage        | Google Drive (user's own Drive -- no database)          |
| AI             | OpenAI Whisper (transcription), Claude (summarization) |
| Infrastructure | Scaleway (Object Storage + Serverless Functions)       |
| IaC            | Terraform                                              |

## Project Structure

```
GradeBee/
├── frontend/           # React SPA (Vite)
│   └── src/
│       ├── main.tsx            # Entry point: ClerkProvider + BrowserRouter
│       ├── App.tsx             # Root component: sign-in or DriveSetup
│       └── components/
│           └── DriveSetup.tsx  # Google Drive folder setup flow
├── backend/
│   ├── cmd/server/main.go     # Local dev server entrypoint
│   ├── handler.go             # Scaleway function entrypoint + routing
│   ├── auth.go                # Clerk auth + Google OAuth token retrieval
│   └── setup.go               # POST /setup -- creates Drive folder structure
├── infra/                     # Terraform (Scaleway resources)
├── docs/                      # Design docs and implementation plans
├── Makefile                   # Build and deploy commands
└── package.json               # Root: runs frontend + backend concurrently
```

## API Endpoints

| Method   | Path            | Description                           |
| -------- | --------------- | ------------------------------------- |
| `GET`    | `/` `/health`   | Health check                          |
| `POST`   | `/setup`        | Create Drive folder structure         |

## Getting Started

### Prerequisites

- Node.js
- Go 1.24+
- A [Clerk](https://clerk.com) account configured with Google OAuth (requesting `drive.file` and `spreadsheets.readonly` scopes)

### Setup

1. Copy `.env.example` to `.env` at the project root and fill in the values:

   ```
   # Frontend (VITE_* exposed to client)
   VITE_CLERK_PUBLISHABLE_KEY=pk_test_xxx
   VITE_API_URL=http://localhost:8080

   # Backend
   CLERK_SECRET_KEY=sk_live_xxx
   ALLOWED_ORIGIN=http://localhost:5173
   ```

2. Install dependencies:

   ```sh
   npm install
   cd frontend && npm install
   ```

3. (Optional) Enable git hooks to run `make lint` when backend files change:

   ```sh
   git config core.hooksPath .githooks
   ```

4. Run the development servers:

   ```sh
   npm run dev
   ```

   This starts the frontend on `http://localhost:5173` and the backend on `http://localhost:8080`.

## Implementation Status

The project follows a [phased implementation plan](docs/plans/2026-03-13-phased-implementation.md):

- **Phase 1** -- Auth & Google Drive Connection (done)
- **Phase 2** -- Student List (read from Google Sheets)
- **Phase 3** -- Voice Upload & Transcription (Whisper API)
- **Phase 4** -- Note Generation (Claude API for extraction/summarization)
- **Phase 5** -- Report Card Generation
- **Phase 6** -- Drive Watching (auto-detect uploads)

## License

[GPL v3](LICENSE)
