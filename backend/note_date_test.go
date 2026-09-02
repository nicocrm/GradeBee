package handler

import (
	"bytes"
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"net/http/httptest"
	"os"
	"path/filepath"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// A note is dated from the voice note's upload time, not from the clock at
// processing time. The two diverge whenever a job is retried or waits behind a
// backlog, and the processing clock would then drop the note out of the report
// window it belongs to.
func TestProcessJob_DatesNoteFromUploadTime(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "user1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: "Alice did great today."},
		roster: &stubRoster{
			classNames: []string{"Math"},
			students:   []ClassGroup{{Name: "Math", Students: []ClassStudent{{Name: "Alice"}}}},
		},
		extractor: &stubExtractor{result: &ExtractResponse{
			Students: []MatchedStudent{
				{Name: "Alice", ClassName: "Math · Mon", QuotedText: "Did great", Confidence: 0.9},
			},
		}},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	// Uploaded well in the past: a job retried days later, or one that sat in a
	// backlog. Processing happens now.
	uploadedAt := time.Date(2026, 2, 10, 16, 15, 0, 0, time.UTC)

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{
		UserID:    "user1",
		UploadID:  1,
		FilePath:  audioPath,
		FileName:  "recording.m4a",
		Status:    JobStatusQueued,
		CreatedAt: uploadedAt,
	}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("user1", 1)))

	require.Len(t, nc.calls, 1)
	assert.Equal(t, "2026-02-10", nc.calls[0].Date,
		"note should carry the upload day, not the processing day")
}

// The extraction schema no longer asks the model for a date, so a model that
// volunteers one cannot reach the database.
func TestExtractResponseSchema_HasNoDateField(t *testing.T) {
	raw := extractResponseSchema([]ClassGroup{{Name: "Math"}})

	var schema struct {
		Properties map[string]json.RawMessage `json:"properties"`
		Required   []string                   `json:"required"`
	}
	require.NoError(t, json.Unmarshal(raw, &schema))

	assert.NotContains(t, schema.Properties, "date")
	assert.NotContains(t, schema.Required, "date")
}

// The UI sends <input type="date">, but the endpoint is reachable directly and
// notes.date is a bare TEXT column the report query compares with BETWEEN — a
// non-date string there silently excludes the note from every report.
func TestHandleCreateNote_RejectsMalformedDate(t *testing.T) {
	ctx, r := testDBAndRepos(t)
	serviceDeps = &mockDepsAll{
		db:          r.notes.db,
		classRepo:   r.classes,
		studentRepo: r.students,
		noteRepo:    r.notes,
	}
	t.Cleanup(func() { serviceDeps = nil })

	c := newTestClass(t, r.classes, "test-group", "user1", "Math", "")
	s, err := r.students.Create(ctx, c.ID, "Alice")
	require.NoError(t, err)

	post := func(t *testing.T, date string) *httptest.ResponseRecorder {
		t.Helper()
		body, err := json.Marshal(map[string]string{"date": date, "summary": "Did well"})
		require.NoError(t, err)
		req := httptest.NewRequest(http.MethodPost,
			fmt.Sprintf("/students/%d/notes", s.ID), bytes.NewReader(body))
		req.SetPathValue("id", itoa(s.ID))
		req = withClerkUser(req, "user1")
		rec := httptest.NewRecorder()
		handleCreateNote(rec, req)
		return rec
	}

	for _, date := range []string{"Saturday", "Friday, Marcia, 1740", "1615-01", "2026-13-45", "22/03/2026"} {
		t.Run(date, func(t *testing.T) {
			rec := post(t, date)
			require.Equal(t, http.StatusBadRequest, rec.Code, "body=%s", rec.Body.String())
			var resp map[string]string
			require.NoError(t, json.NewDecoder(rec.Body).Decode(&resp))
			assert.Equal(t, "date must be YYYY-MM-DD", resp["error"])
		})
	}

	t.Run("well-formed date is accepted", func(t *testing.T) {
		rec := post(t, "2026-03-22")
		require.Equal(t, http.StatusCreated, rec.Code, "body=%s", rec.Body.String())
	})
}
