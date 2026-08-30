// router.go registers every /api/ route on a Go 1.22+ http.ServeMux using
// method+pattern strings, so path parameters come from r.PathValue and an
// unmatched path or method is a 404 rather than a prefix over-match.
package handler

import (
	"net/http"
	"strconv"
)

// apiMux is the process-wide API router, built once with the Clerk middleware.
// Tests build their own via newAPIMux with a fake auth wrapper.
var apiMux = newAPIMux(clerkAuthMiddleware)

// newAPIMux registers every API route behind auth. Each pattern carries its
// method, so a known path with the wrong method falls to the "/api/" catch-all
// and answers the same JSON 404 as an unknown path — ServeMux's text/plain 405
// never fires because the catch-all always matches.
func newAPIMux(auth func(http.Handler) http.Handler) *http.ServeMux {
	mux := http.NewServeMux()
	route := func(pattern string, fn http.HandlerFunc) {
		mux.Handle(pattern, auth(fn))
	}

	// Classes CRUD
	route("GET /api/classes", handleListClasses)
	route("POST /api/classes", handleCreateClass)
	route("PUT /api/classes/{id}", handleUpdateClass)
	route("DELETE /api/classes/{id}", handleDeleteClass)

	// Levels CRUD (Group-owned; write endpoints admin-gated in the handler)
	route("GET /api/levels", handleListLevels)
	route("POST /api/levels", handleCreateLevel)
	route("PUT /api/levels/{id}", handleUpdateLevel)
	route("DELETE /api/levels/{id}", handleDeleteLevel)

	// Students under class
	route("GET /api/classes/{id}/students", handleListStudents)
	route("POST /api/classes/{id}/students", handleCreateStudent)

	// Students by ID
	route("PUT /api/students/{id}", handleUpdateStudent)
	route("DELETE /api/students/{id}", handleDeleteStudent)

	// Aliases under student
	route("GET /api/students/{id}/aliases", handleListAliases)
	route("POST /api/students/{id}/aliases", handleAddAlias)
	route("DELETE /api/students/{id}/aliases/{aliasID}", handleRemoveAlias)

	// Notes under student
	route("GET /api/students/{id}/notes", handleListNotes)
	route("POST /api/students/{id}/notes", handleCreateNote)

	// Notes by ID
	route("GET /api/notes/{id}", handleGetNote)
	route("PUT /api/notes/{id}", handleUpdateNote)
	route("DELETE /api/notes/{id}", handleDeleteNote)

	// Reports
	route("POST /api/reports", handleGenerateReports)
	route("POST /api/reports/{id}/regenerate", handleRegenerateReport)
	route("GET /api/students/{id}/reports", handleListReports)
	route("GET /api/reports/{id}", handleGetReport)
	route("DELETE /api/reports/{id}", handleDeleteReport)

	// Voice note upload + Drive import
	route("POST /api/voice-notes/upload", handleUpload)
	route("POST /api/text-notes/upload", handleTextNotesUpload)
	route("POST /api/voice-notes/drive-import", handleDriveImport)

	// Google token (for Drive Picker)
	route("GET /api/google-token", handleGoogleToken)

	// Artifact feedback (explicit thumbs ratings)
	route("POST /api/feedback", handleSubmitFeedback)

	// Voice note jobs
	route("GET /api/voice-notes/jobs", handleJobList)
	route("POST /api/voice-notes/jobs/retry", handleJobRetry)
	route("POST /api/voice-notes/jobs/dismiss", handleJobDismiss)

	// Catch-all: unknown path, wrong method, or trailing segments. Registering
	// bare "/api" too stops ServeMux redirecting it to "/api/" with a 301.
	mux.HandleFunc("/api/", jsonNotFound)
	mux.HandleFunc("/api", jsonNotFound)

	return mux
}

// jsonNotFound is the router's own 404; handlers write theirs through writeError.
func jsonNotFound(w http.ResponseWriter, _ *http.Request) {
	writeJSON(w, http.StatusNotFound, map[string]string{"error": "not found"})
}

// idParam reads the named path wildcard (e.g. "id" from "/api/classes/{id}")
// as an int64. It reports false when the segment is absent or not an integer.
func idParam(r *http.Request, name string) (int64, bool) {
	id, err := strconv.ParseInt(r.PathValue(name), 10, 64)
	if err != nil {
		return 0, false
	}
	return id, true
}
