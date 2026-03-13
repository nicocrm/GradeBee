# GradeBee: Flutter to React + Vite Migration Plan

Migrate the GradeBee Flutter web app to React + TypeScript + Vite, following the architecture patterns established in math-drill.

## Current State

- **Frontend:** Flutter (Dart) with GoRouter, ChangeNotifier/GetIt, Material Design
- **Backend:** Appwrite (auth, database, storage, serverless functions in Dart)
- **Deploy:** S3 + AWS Amplify (being replaced by Appwrite Sites)

## Target State

- **Frontend:** React 19 + TypeScript + Vite 8
- **Routing:** React Router 7
- **Styling:** Tailwind CSS 3
- **State:** React hooks (useState, useCallback, useEffect, useContext)
- **Auth:** Appwrite Web SDK (keep existing Appwrite auth)
- **Backend:** Appwrite (unchanged - all Dart functions stay as-is)
- **Testing:** Vitest (unit) + Playwright (E2E)
- **Deploy:** Appwrite Sites (static site hosting)

## Architecture Mapping

| Flutter (current) | React (target) | Notes |
|---|---|---|
| `app/lib/main.dart` | `src/main.tsx` | Entry point with providers |
| `app/lib/shared/router.dart` | `src/main.tsx` routes | React Router config |
| `app/lib/features/*/screens/` | `src/pages/` | Page-level components |
| `app/lib/features/*/widgets/` | `src/components/` | Reusable UI components |
| `app/lib/features/*/vm/` | React hooks / component state | No ViewModel layer needed |
| `app/lib/features/*/models/` | `src/types/` | TypeScript interfaces |
| `app/lib/features/*/repositories/` | `src/lib/` | API/data access functions |
| `app/lib/shared/data/` | `src/lib/` | Services (auth, db, storage) |
| `app/lib/shared/ui/` | `src/components/ui/` | Shared UI primitives |
| GetIt DI | React Context | Auth/services context |
| ChangeNotifier | useState/useReducer | Local component state |
| Command pattern | async functions + loading state | Simpler async handling |
| Material Design | Tailwind CSS | Custom design system |
| `pubspec.yaml` | `package.json` | Dependencies |
| `justfile` | `package.json` scripts | Build automation |

---

## Phase 1: Project Scaffolding & Infrastructure

**Goal:** Bootable React app with Vite, Tailwind, routing shell, and Appwrite SDK connected.

### Tasks

1. Create `web/` directory alongside existing `app/` (both coexist during migration)
2. Initialize Vite + React + TypeScript project:
   - `vite.config.ts` with `@` path alias (mirror math-drill)
   - `tsconfig.json` with strict mode, bundler resolution
   - `postcss.config.mjs` + `tailwind.config.ts`
3. Install core dependencies:
   - `react`, `react-dom`, `react-router`
   - `tailwindcss`, `postcss`, `autoprefixer`
   - `appwrite` (JS/TS SDK)
4. Set up `src/globals.css` with Tailwind directives and CSS custom properties for theming
5. Set up environment variables:
   - `VITE_APPWRITE_ENDPOINT`
   - `VITE_APPWRITE_PROJECT_ID`
   - `VITE_APPWRITE_DATABASE_ID`
   - Collection/bucket IDs as needed
6. Create `src/lib/appwrite.ts` - initialize Appwrite `Client`, `Account`, `Databases`, `Storage`, `Functions` singletons
7. Create route skeleton in `src/main.tsx`:
   - `/login` -> `Login.tsx`
   - `/` -> `ClassList.tsx` (redirect from `/`)
   - `/class/:classId` -> `ClassDetails.tsx`
   - `/class/:classId/student/:studentId` -> `StudentDetails.tsx`
8. Create `src/components/PageLayout.tsx` - shared layout wrapper (nav, auth header)
9. Create `src/components/ui/Button.tsx` and `src/components/ui/Card.tsx` base primitives
10. Update `justfile` to add `build-web-react`, `dev-react` commands
11. Configure Appwrite Sites for static hosting:
    - Add site configuration to `appwrite.json`
    - Set up SPA fallback routing (all paths -> `index.html`)
    - Configure custom domain if needed
12. Verify: app boots, routes render placeholder pages, Appwrite client connects

### Verification

- `npm run dev` starts on localhost
- All routes render placeholder text
- Appwrite health check call succeeds in browser console
- Tailwind classes apply correctly

---

## Phase 2: Authentication

**Goal:** Working login/logout with Appwrite, protected routes.

### Tasks

1. Create `src/lib/auth.tsx` - AuthContext provider:
   - `AuthProvider` wraps app, checks existing session on mount
   - Exposes: `user`, `isAuthenticated`, `isLoading`, `login()`, `logout()`
   - Email/password login via `account.createEmailPasswordSession()`
   - Google OAuth via `account.createOAuth2Session()`
2. Create `src/pages/Login.tsx`:
   - Email + password form
   - Google OAuth button
   - Redirect to `/` on success
3. Add auth guard to router:
   - Redirect unauthenticated users to `/login`
   - Redirect authenticated users away from `/login`
4. Create `src/components/AuthHeader.tsx` - user info + logout button in nav
5. Port auth logic from `app/lib/shared/data/auth_state.dart`

### Verification

- Can log in with email/password
- Can log in with Google OAuth
- Unauthenticated users redirected to `/login`
- Session persists across page refresh
- Logout clears session and redirects

---

## Phase 3: Type Definitions & Data Layer

**Goal:** TypeScript types for all domain models, Appwrite data access functions.

### Tasks

1. Create `src/types/` with interfaces matching Appwrite collections:
   - `class.ts` - `Class` (id, name, userId, gradeLevel, etc.)
   - `student.ts` - `Student` (id, name, classId, etc.)
   - `note.ts` - `Note`, `PendingNote` (id, classId, content, audioFileId, status, etc.)
   - `studentNote.ts` - `StudentNote` (id, studentId, noteId, content, etc.)
   - `reportCard.ts` - `ReportCard`, `ReportCardSection`, `ReportCardTemplate`, `ReportCardTemplateLine`
2. Create `src/lib/db.ts` - database helper wrapping Appwrite `Databases`:
   - Generic `listDocuments`, `getDocument`, `createDocument`, `updateDocument`, `deleteDocument` wrappers with typed returns
   - Collection ID constants
3. Create `src/lib/classes.ts` - class data access:
   - `getClasses()`, `getClass(id)`, `createClass()`, `deleteClass()`
4. Create `src/lib/students.ts` - student data access:
   - `getStudents(classId)`, `getStudent(id)`, `createStudent()`, `deleteStudent()`
5. Create `src/lib/notes.ts` - note data access:
   - `getNotes(classId)`, `createNote()`, `deleteNote()`
   - `getStudentNotes(studentId)`
6. Create `src/lib/storage.ts` - Appwrite storage wrapper:
   - `uploadAudio(file)`, `getAudioUrl(fileId)`, `deleteAudio(fileId)`
7. Create `src/lib/functions.ts` - serverless function invocation:
   - `transcribeNote(noteId)`, `splitNotes(noteId)`, `createReportCard(studentId, templateId)`

### Verification

- Unit tests (Vitest) for type guards / serialization helpers
- Can list classes from Appwrite in browser console
- Can CRUD a test document

---

## Phase 4: Class List Page

**Goal:** Fully functional class list - view, create, navigate to class details.

### Tasks

1. Implement `src/pages/ClassList.tsx`:
   - Fetch classes on mount via `getClasses()`
   - Display as card grid (Tailwind)
   - Loading / empty / error states
   - Click navigates to `/class/:classId`
2. Create `src/components/ClassCard.tsx` - individual class display
3. Create `src/pages/AddClass.tsx` or modal:
   - Form: name, grade level
   - Submit calls `createClass()`
   - Redirect/close on success
4. Add FAB or button to trigger add class flow

### Verification

- Classes load and display from Appwrite
- Can create a new class
- Clicking class navigates to details route
- Responsive layout works on mobile/desktop

---

## Phase 5: Class Details & Note Recording

**Goal:** View class students and notes, record and upload voice notes.

### Tasks

1. Implement `src/pages/ClassDetails.tsx`:
   - Fetch class, students, and notes
   - Tab or section layout: Students list + Notes list
   - Student list with click-through to student details
2. Create `src/components/NoteList.tsx` - display notes with status indicators
3. Create `src/components/NoteCard.tsx` - individual note display (date, status, transcript preview)
4. Implement voice recording:
   - Use `MediaRecorder` Web API (replaces Flutter `record` package)
   - Create `src/lib/recorder.ts` - `startRecording()`, `stopRecording()` returning `Blob`
   - Create `src/components/RecordButton.tsx` - record UI with timer
5. Implement note upload flow:
   - Record -> upload audio to Appwrite Storage -> create note document -> invoke transcribe function
6. Display transcription status (polling or realtime via Appwrite)
7. Implement note splitting:
   - Button to trigger `splitNotes()` function call
   - Show split status and resulting student notes

### Verification

- Class details page loads with students and notes
- Can record audio in browser
- Audio uploads to Appwrite storage
- Transcription triggers and completes
- Note splitting works and creates student notes

---

## Phase 6: Student Details & Report Cards

**Goal:** View student notes and generate/view report cards.

### Tasks

1. Implement `src/pages/StudentDetails.tsx`:
   - Fetch student, student notes, report cards
   - Section: Notes timeline
   - Section: Report cards list
2. Create `src/components/StudentNoteList.tsx` - student's notes display
3. Create `src/components/ReportCardList.tsx` - list of generated report cards
4. Create `src/components/ReportCardView.tsx` - single report card display with sections
5. Implement report card generation:
   - Template selection (fetch templates from Appwrite)
   - Trigger `createReportCard()` function
   - Poll for completion
   - Display generated card
6. Port report card creativity/feedback controls from current app

### Verification

- Student details shows notes and report cards
- Can generate new report card
- Report card displays correctly with all sections
- Can regenerate with different feedback/creativity settings

---

## Phase 7: Offline Support & Sync

**Goal:** Offline note queue matching current Flutter behavior.

### Tasks

1. Create `src/lib/offlineStore.ts`:
   - `PendingNote` queue in localStorage (mirrors `LocalStorage<PendingNote>` from Flutter)
   - `addPendingNote()`, `getPendingNotes()`, `removePendingNote()`
2. Create `src/lib/syncService.ts`:
   - On app load and on `online` event, process pending notes queue
   - Upload audio, create note doc, remove from queue on success
3. Add online/offline indicator in UI
4. Modify record flow to queue locally when offline

### Verification

- Can record note while offline (stored in localStorage/IndexedDB)
- Notes sync automatically when connection restored
- Pending notes visible in UI with sync status

---

## Phase 8: Testing

**Goal:** Comprehensive test coverage matching or exceeding current Flutter tests.

### Tasks

1. Set up Vitest:
   - `vitest.config.ts` with path aliases
   - Mock Appwrite SDK for unit tests
2. Unit tests:
   - Data access functions (mocked Appwrite)
   - Offline store logic
   - Sync service logic
   - Auth context behavior
3. Set up Playwright:
   - `playwright.config.ts`
   - Base URL config, dev server startup
4. E2E tests:
   - Login flow
   - Class CRUD
   - Note recording (mock MediaRecorder)
   - Student details navigation
   - Report card generation flow

### Verification

- `npm test` passes all unit tests
- `npm run test:e2e` passes all E2E tests
- Coverage meets acceptable threshold

---

## Phase 9: Deployment & Cutover

**Goal:** Deploy React app via Appwrite Sites, retire Flutter web build.

### Tasks

1. Configure Appwrite Sites deployment:
   - Add site to `appwrite.json` with build command (`cd web && npm run build`) and output directory (`web/dist`)
   - Configure SPA fallback routing (all paths -> `index.html`)
   - Set up custom domain (transfer from current Amplify domain)
   - Configure environment variables in Appwrite console if needed
2. Update `justfile`:
   - `build-web` now builds React app (`cd web && npm run build`)
   - `deploy` uses `appwrite deploy site` (or Appwrite CLI equivalent)
   - Keep Flutter commands as `build-web-flutter` / `deploy-flutter` temporarily
3. Test deployment to dev site
4. Verify all features work in deployed environment
5. Deploy to production, switch DNS to Appwrite Sites
6. After validation period:
   - Remove `app/` Flutter directory
   - Move `web/` contents to project root (or rename)
   - Clean up Flutter-specific files (`pubspec.yaml`, `ios/`, `android/`, etc.)
   - Decommission S3 bucket and Amplify app
   - Update README

### Verification

- Deployed app functions identically to Flutter version
- All routes work with direct URL access (Appwrite Sites SPA fallback)
- Auth flows work in production (correct Appwrite project/domain)
- Voice recording works in production (HTTPS required for MediaRecorder)
- Appwrite functions triggered correctly from new frontend
- Custom domain resolves and SSL works

---

## Out of Scope

- **Appwrite serverless functions** - Dart functions stay as-is; they're backend and independent of frontend framework
- **Mobile app** - This plan covers web only; if mobile is needed later, consider React Native or keep Flutter for mobile
- **Backend migration** - Appwrite remains the backend
- **Feature additions** - Migration is 1:1 feature parity, no new features

## Risk Considerations

| Risk | Mitigation |
|---|---|
| MediaRecorder browser support | Test on target browsers; provide fallback or minimum browser version notice |
| Appwrite JS SDK differences from Dart SDK | Review JS SDK docs for each feature; some API signatures differ |
| Audio format compatibility | MediaRecorder produces webm/opus; verify Appwrite transcription function handles this (may need format conversion) |
| Offline storage limits | localStorage has ~5MB limit; for large audio, consider IndexedDB |
| Parallel development during migration | Both apps coexist in repo; coordinate deploys carefully |
| Appwrite Sites SPA routing | Ensure fallback to `index.html` is configured for client-side routing |

## Dependencies (package.json)

```json
{
  "dependencies": {
    "react": "^19.0.0",
    "react-dom": "^19.0.0",
    "react-router": "^7.0.0",
    "appwrite": "^17.0.0"
  },
  "devDependencies": {
    "@vitejs/plugin-react": "^4.0.0",
    "vite": "^8.0.0",
    "typescript": "~5.7.0",
    "tailwindcss": "^3.0.0",
    "postcss": "^8.0.0",
    "autoprefixer": "^10.0.0",
    "vitest": "^4.0.0",
    "@playwright/test": "^1.50.0"
  }
}
```
