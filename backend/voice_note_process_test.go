package handler

import (
	"context"
	"errors"
	"fmt"
	"io"
	"os"
	"path/filepath"
	"strings"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestProcessJob_HappyPath(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	// Seed class + students.
	cls := newTestClass(t, classRepo, "test-group", "user1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)
	_, err = studentRepo.Create(t.Context(), cls.ID, "Bob")
	require.NoError(t, err)

	// Write a temp audio file.
	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	uploadID := newTestVoiceNote(t, voiceNoteRepo, "user1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{
		results: []*CreateNoteResponse{
			{NoteID: 1},
			{NoteID: 2},
		},
	}
	const transcript = "Alice did great today. Bob needs improvement."
	transcriber := &stubTranscriber{result: transcript}
	d := &mockDepsAll{
		transcriber: transcriber,
		roster:      mathRoster("Alice", "Bob"),
		extractor: &stubExtractor{
			result: segmentPerClause(mathClassName, transcript, "Alice", "Bob"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	job := VoiceNoteJob{
		UserID:    "user1",
		UploadID:  uploadID,
		FilePath:  audioPath,
		FileName:  "recording.m4a",
		Status:    JobStatusQueued,
		CreatedAt: time.Now(),
	}
	require.NoError(t, queue.Publish(ctx, job))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("user1", uploadID)))

	got, err := queue.GetJob(ctx, voiceNoteKey("user1", uploadID))
	require.NoError(t, err)
	assert.Equal(t, JobStatusDone, got.Status)
	assert.Len(t, got.NoteLinks, 2)
	assert.Len(t, nc.calls, 2)
	assert.Equal(t, []string{mathClassName}, transcriber.gotBias, "transcriber should receive class names as context bias")
}

func TestProcessJob_TranscribeFail(t *testing.T) {
	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{err: io.ErrUnexpectedEOF},
		roster:        &stubRoster{},
		voiceNoteRepo: &VoiceNoteRepo{db: nil}, // won't be called on failure
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: 1, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

	err := processVoiceNote(ctx, d, queue, voiceNoteKey("u1", 1))
	require.Error(t, err)

	got, err := queue.GetJob(ctx, voiceNoteKey("u1", 1))
	require.NoError(t, err)
	assert.Equal(t, JobStatusFailed, got.Status)
	assert.True(t, strings.Contains(got.Error, "transcribe"), "error = %q, want to contain 'transcribe'", got.Error)
}

func TestProcessJob_ExtractFail(t *testing.T) {
	db := setupTestDB(t)
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	// Create a DB row so MarkPurged has a valid ID to write to.
	vn, err := voiceNoteRepo.Create(t.Context(), "u1", "recording.m4a", audioPath)
	require.NoError(t, err)

	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{result: "some transcript"},
		roster:        &stubRoster{},
		extractor:     &stubExtractor{err: io.ErrUnexpectedEOF},
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: vn.ID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

	err = processVoiceNote(ctx, d, queue, voiceNoteKey("u1", vn.ID))
	require.Error(t, err)

	got, err := queue.GetJob(ctx, voiceNoteKey("u1", vn.ID))
	require.NoError(t, err)
	assert.Equal(t, JobStatusFailed, got.Status)

	// The transcript is written before extraction, so a failed extraction does not
	// lose it — the audio is already gone by then.
	row, err := voiceNoteRepo.GetByID(ctx, vn.ID)
	require.NoError(t, err)
	require.NotNil(t, row.Transcript, "transcript should be persisted before extraction runs")
	assert.Equal(t, "some transcript", *row.Transcript)
}

func TestProcessJob_NoteCreateFail(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "test.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("audio"), 0o644))

	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: "Alice did great."},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{
			result: segmentPerClause(mathClassName, "Alice did great.", "Alice"),
		},
		noteCreator:   &stubNoteCreator{err: io.ErrUnexpectedEOF},
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: 1, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

	err = processVoiceNote(ctx, d, queue, voiceNoteKey("u1", 1))
	require.Error(t, err)

	got, gErr := queue.GetJob(ctx, voiceNoteKey("u1", 1))
	require.NoError(t, gErr)
	assert.Equal(t, JobStatusFailed, got.Status)
}

func TestProcessJob_AlreadyProcessed(t *testing.T) {
	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{}

	ctx := context.Background()
	queue.jobs[voiceNoteKey("u1", 1)] = VoiceNoteJob{
		UserID: "u1", UploadID: 1, Status: JobStatusDone,
	}

	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", 1)), "expected no error for already-processed job")

	got, err := queue.GetJob(ctx, voiceNoteKey("u1", 1))
	require.NoError(t, err)
	assert.Equal(t, JobStatusDone, got.Status, "status changed, should remain done")
}

// TestProcessJob_UnknownClassProducesNoNotes: the model names a class the roster
// does not have. The schema's class_name enum makes that impossible in
// production, so it is a defect worth a warning — and no note, because a name
// resolved against a class that does not exist is a name resolved against
// nothing. The job still completes; the transcript survives for #80.
func TestProcessJob_UnknownClassProducesNoNotes(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "test.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("audio"), 0o644))

	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: "Alice did great."},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{
			result: segmentPerClause("WrongClass", "Alice did great.", "Alice"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)), "an unknown class is a defect, not a job failure")

	got, err := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
	require.NoError(t, err)
	assert.Equal(t, JobStatusDone, got.Status)
	assert.Empty(t, nc.calls, "a class off the roster resolves nobody")
	out := logs.String()
	require.Contains(t, out, "model named a class not on the roster", "the defect was not logged at all")
	// The name a free-writing model put in the class field can be a child's name,
	// so only its length is logged (docs/adr/0003). "WrongClass" is 10 runes.
	assert.Contains(t, out, `"class_name_len":10`)
	assert.NotContains(t, out, "WrongClass", "the model's free text must not reach the logs")

	// The completion record's other zero-note mode. Every other test here pins a
	// class, so without this the field could be inverted and stay green.
	done := logRecord(t, out, "process voice note completed")
	assert.Contains(t, done, `"class_pinned":false`, "no class was pinned, so every label dropped at once")
	assert.Contains(t, done, `"note_count":0`)
}

// TestProcessJob_UnresolvableLabelSkipped: a spoken label that matches nobody in
// the pinned class produces no note. This is the successor to the confidence
// gate — the model no longer scores its own matches, because it no longer makes
// them.
func TestProcessJob_UnresolvableLabelSkipped(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)
	_, err = studentRepo.Create(t.Context(), cls.ID, "Bram")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "test.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("audio"), 0o644))

	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{}
	const transcript = "Alice did great. Quillon was loud."
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: transcript},
		roster:      mathRoster("Alice", "Bram"),
		extractor: &stubExtractor{
			// "Quillon" is nobody in this class — far enough from both Alice and
			// Bram to fall under MatchStudent's threshold, so it resolves to neither.
			result: segmentPerClause(mathClassName, transcript, "Alice", "Quillon"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))
	require.Len(t, nc.calls, 1, "only the label that resolved becomes a note")
	assert.Equal(t, "Alice", nc.calls[0].StudentName)
}

// TestProcessJob_QuotedTextPassedToNoteCreator verifies that the assembled note
// text — the span summary — flows through to CreateNoteRequest unmodified.
func TestProcessJob_QuotedTextPassedToNoteCreator(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}

	rawQuote := "Alice was impossibly good today - she blew my mind with her presentation"

	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: rawQuote},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{result: &SegmentResponse{
			ClassName: mathClassName,
			Spans: []Span{{
				Start: 1, End: len(SplitClauses(rawQuote)), Kind: SpanChild,
				SpokenLabels: []string{"Alice"}, Summary: rawQuote,
			}},
		}},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

	require.Len(t, nc.calls, 1, "expected 1 note creation call")
	assert.Equal(t, rawQuote, nc.calls[0].QuotedText, "QuotedText not passed through")
}

// TestProcessJob_DeletesAudioAfterTranscription verifies that the audio file is
// deleted from disk and purged_at is set in the DB immediately after transcription.
func TestProcessJob_DeletesAudioAfterTranscription(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	// Create a voice note row so MarkPurged has a real ID to update.
	vn, err := voiceNoteRepo.Create(t.Context(), "u1", "recording.m4a", audioPath)
	require.NoError(t, err)

	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: "Alice did well"},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{
			result: segmentPerClause(mathClassName, "Alice did well", "Alice"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{
		UserID: "u1", UploadID: vn.ID, FilePath: audioPath,
		FileName: "recording.m4a", Status: JobStatusQueued, CreatedAt: time.Now(),
	}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", vn.ID)))

	// Audio file must be gone.
	_, statErr := os.Stat(audioPath)
	assert.True(t, os.IsNotExist(statErr), "expected audio file to be deleted after transcription")

	// purged_at must be set in DB.
	got, err := voiceNoteRepo.GetByID(ctx, vn.ID)
	require.NoError(t, err)
	assert.NotNil(t, got.PurgedAt, "expected PurgedAt to be set after transcription")

	// purged_at marks the audio file alone. The transcript stays on the row — it is
	// the only copy once the audio is gone — and leaves with the row when the
	// retention cleanup deletes it (see voice_note_cleanup_test.go).
	require.NotNil(t, got.Transcript, "transcript should survive the audio purge")
	assert.Equal(t, "Alice did well", *got.Transcript)
}

// TestProcessJob_PersistsTranscriptWithoutNotes covers the case #80 depends on: every
// label unresolvable, zero notes created, and the transcript is still on the
// voice_notes row. Before this, notes.transcript was the only copy, so a job that
// created no note left the teacher's words nowhere.
func TestProcessJob_PersistsTranscriptWithoutNotes(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "recording.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("fake audio"), 0o644))

	vn, err := voiceNoteRepo.Create(t.Context(), "u1", "recording.m4a", audioPath)
	require.NoError(t, err)

	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{}
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: "Zephyrine did nothing. Quillon did less."},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{
			// Two labels, neither anywhere near the one child on the roster.
			result: segmentPerClause(mathClassName,
				"Zephyrine did nothing. Quillon did less.", "Zephyrine", "Quillon"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{
		UserID: "u1", UploadID: vn.ID, FilePath: audioPath,
		FileName: "recording.m4a", Status: JobStatusQueued, CreatedAt: time.Now(),
	}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", vn.ID)))

	assert.Empty(t, nc.calls, "no note should be created")

	got, err := voiceNoteRepo.GetByID(ctx, vn.ID)
	require.NoError(t, err)
	require.NotNil(t, got.Transcript, "transcript should be persisted even when no note is created")
	assert.Equal(t, "Zephyrine did nothing. Quillon did less.", *got.Transcript)
}

// TestProcessJob_PersistFailureFailsJobThenRetries: a failed transcript write fails
// the job, so the teacher can retry, but the audio is deleted regardless — the
// privacy page promises the recording is gone right after transcription. The
// failed job keeps the transcript, so the retry skips transcription and only
// repeats the write.
func TestProcessJob_PersistFailureFailsJobThenRetries(t *testing.T) {
	db := setupTestDB(t)
	goodRepo := &VoiceNoteRepo{db: db}
	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, goodRepo, "u1", audioPath)

	closed, err := OpenDB(":memory:")
	require.NoError(t, err)
	require.NoError(t, closed.Close())

	queue := newStubVoiceNoteQueue()
	transcriber := &stubTranscriber{result: "words"}
	d := &mockDepsAll{
		transcriber:   transcriber,
		roster:        mathRoster("Alice"),
		extractor:     &stubExtractor{result: segmentPerClause(mathClassName, "words", "")},
		noteCreator:   &stubNoteCreator{},
		voiceNoteRepo: &VoiceNoteRepo{db: closed},
	}

	ctx := context.Background()
	key := voiceNoteKey("u1", uploadID)
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{
		UserID: "u1", UploadID: uploadID, FilePath: audioPath,
		FileName: "recording.m4a", Status: JobStatusQueued, CreatedAt: time.Now(),
	}))
	require.Error(t, processVoiceNote(ctx, d, queue, key))

	_, statErr := os.Stat(audioPath)
	assert.True(t, os.IsNotExist(statErr), "audio must be deleted even when the transcript could not be persisted")

	got, err := queue.GetJob(ctx, key)
	require.NoError(t, err)
	assert.Equal(t, JobStatusFailed, got.Status)
	assert.Contains(t, got.Error, "persist transcript")
	assert.Equal(t, "words", got.Transcript, "failed job keeps the transcript for retry")

	// Retry with the store back: no audio, no transcription, just the write.
	d.voiceNoteRepo = goodRepo
	transcriber.err = io.ErrUnexpectedEOF
	got.Status = JobStatusQueued
	require.NoError(t, queue.UpdateJob(ctx, *got))
	require.NoError(t, processVoiceNote(ctx, d, queue, key))

	got, err = queue.GetJob(ctx, key)
	require.NoError(t, err)
	assert.Equal(t, JobStatusDone, got.Status)
	row, err := goodRepo.GetByID(ctx, uploadID)
	require.NoError(t, err)
	require.NotNil(t, row.Transcript)
	assert.Equal(t, "words", *row.Transcript)
}

// TestProcessJob_RetryPastRetention: once the cleanup has swept an upload, a retry
// finds either no audio file (job failed before transcription) or no voice_notes
// row (job failed after). Both tell the teacher the upload is too old, with no
// raw error appended, while the telemetry step stays the raw one so saved Sentry
// queries keep matching.
func TestProcessJob_RetryPastRetention(t *testing.T) {
	const tooOld = "this upload is too old to retry"

	t.Run("audio file gone", func(t *testing.T) {
		db := setupTestDB(t)
		voiceNoteRepo := &VoiceNoteRepo{db: db}
		audioPath := filepath.Join(t.TempDir(), "swept.m4a") // never written
		uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
		d := &mockDepsAll{
			transcriber:   &stubTranscriber{result: "unreachable: the open fails first"},
			roster:        &stubRoster{},
			voiceNoteRepo: voiceNoteRepo,
		}

		queue := newStubVoiceNoteQueue()
		ctx, logs := captureLogs(context.Background())
		require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
		require.Error(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

		assert.Contains(t, logs.String(), `"step":"open audio file"`)
		got, err := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
		require.NoError(t, err)
		assert.Equal(t, JobStatusFailed, got.Status)
		assert.Equal(t, tooOld, got.Error)
	})

	t.Run("row gone", func(t *testing.T) {
		db := setupTestDB(t)
		voiceNoteRepo := &VoiceNoteRepo{db: db}
		uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", "")
		require.NoError(t, voiceNoteRepo.Delete(t.Context(), uploadID))
		d := &mockDepsAll{
			transcriber:   &stubTranscriber{err: io.ErrUnexpectedEOF}, // skipped: the job carries its transcript
			roster:        &stubRoster{},
			voiceNoteRepo: voiceNoteRepo,
		}

		queue := newStubVoiceNoteQueue()
		ctx, logs := captureLogs(context.Background())
		require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, Transcript: "kept on the job", Status: JobStatusQueued, CreatedAt: time.Now()}))
		require.Error(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

		assert.Contains(t, logs.String(), `"step":"persist transcript"`)
		got, err := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
		require.NoError(t, err)
		assert.Equal(t, JobStatusFailed, got.Status)
		assert.Equal(t, tooOld, got.Error)
	})
}

// TestProcessJob_PersistsPastedText: a text job never transcribes, and its
// voice_notes row has no file. The pasted text is still written to the row so both
// input kinds leave the same trail.
func TestProcessJob_PersistsPastedText(t *testing.T) {
	db := setupTestDB(t)
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	vn, err := voiceNoteRepo.Create(t.Context(), "u1", "pasted-text", "")
	require.NoError(t, err)

	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{err: io.ErrUnexpectedEOF}, // must not be called
		roster:        mathRoster("Alice"),
		extractor:     &stubExtractor{result: segmentPerClause(mathClassName, "Typed by the teacher", "")},
		noteCreator:   &stubNoteCreator{},
		studentRepo:   &StudentRepo{db: db},
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{
		UserID: "u1", UploadID: vn.ID, FileName: "pasted-text", Source: "text",
		Transcript: "Typed by the teacher", Status: JobStatusQueued, CreatedAt: time.Now(),
	}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", vn.ID)))

	got, err := voiceNoteRepo.GetByID(ctx, vn.ID)
	require.NoError(t, err)
	require.NotNil(t, got.Transcript)
	assert.Equal(t, "Typed by the teacher", *got.Transcript)
	assert.Nil(t, got.PurgedAt, "a text job has no audio to purge")
}

// TestProcessJob_DropSitesOmitStudentName locks in ADR 0003: the drop path may
// not put a student name in the logs, because the log handler ships them to
// Sentry. The label that failed to resolve is a name as the teacher spoke it,
// so it is as sensitive as a roster name. Asserting the record is still emitted
// keeps the test from passing just because the path never ran, and asserting on
// the name *value* rather than on a field name also catches a name interpolated
// into a message.
func TestProcessJob_DropSitesOmitStudentName(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}

	// Clause 2's label resolves to nobody in Math · Mon; clause 1's resolves to
	// Alice, so the job still creates a note and the drop is a drop, not a
	// wholesale failure.
	const transcript = "Alice did great. Zephyrine did not."
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: transcript},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{
			model:  "test-model-v1",
			result: segmentPerClause(mathClassName, transcript, "Alice", "Zephyrine"),
		},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))
	require.Len(t, nc.calls, 1, "the unresolvable label should be dropped, the resolvable one kept")

	out := logs.String()
	require.Contains(t, out, `"reason":"no_roster_match"`, "the drop was not logged at all")
	assert.NotContains(t, out, "Zephyrine", "the drop leaked the spoken label into the logs")
	assert.NotContains(t, out, "Alice", "no student name belongs in these logs, resolved or not")

	dropped := logRecord(t, out, `"reason":"no_roster_match"`)
	assert.Contains(t, dropped, "process voice note: mention dropped", "the stable query key changed")
	// key is fmt.Sprintf("%s/%d", userID, uploadID) (voice_note_job.go), so it is
	// redundant with the user_id/upload_id fields beside it. It is asserted for
	// field-set uniformity with the completion record.
	assert.Contains(t, dropped, `"key":"u1/`, "the drop should carry the job key")
	assert.Contains(t, dropped, `"user_id":"u1"`, "the drop should carry the user id")
	assert.Contains(t, dropped, fmt.Sprintf(`"upload_id":%d`, uploadID), "the drop should carry the upload id")
	// By value: class_name is the diagnostic field for this reason, and it is
	// empty exactly when the model declined to pin a class — the case that drops
	// every label at once.
	assert.Contains(t, dropped, `"class_name":"Math · Mon"`, "the drop should keep the class the label was resolved in")
	// The clause range replaces the label: it locates the miss in the persisted
	// transcript without naming anybody.
	assert.Contains(t, dropped, `"span_start":2`, "the drop should locate the span it came from")
	assert.Contains(t, dropped, `"span_end":2`, "the drop should locate the span it came from")
	// Model and prompt version turn a bare drop rate into a figure attributable to a
	// specific model/prompt change (#96).
	assert.Contains(t, dropped, `"model":"test-model-v1"`, "the drop should carry the model that produced the segmentation")
	assert.Contains(t, dropped, promptHashAttr, "the drop should carry the extraction prompt hash")
}

// TestProcessJob_CompletionRecordCountsMentions covers the denominator half of the
// drop instrumentation: a bare count of drops cannot be read as a rate, so the
// completion record has to say how many mentions the segmentation produced.
//
// A mention is one spoken label on one child span. Every expected value is
// deliberately distinct — 6/2/4/3 — because counters that all happen to be 1
// cannot catch a counter wired to the wrong variable. Misses and unattributed
// spans must differ from each other in particular: they count different things
// (labels, spans) and would otherwise be interchangeable here. The fixture is
// sized for that discrimination, not for realism.
func TestProcessJob_CompletionRecordCountsMentions(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	for _, name := range []string{"Alice", "Bram"} {
		_, err := studentRepo.Create(t.Context(), cls.ID, name)
		require.NoError(t, err)
	}

	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}, {NoteID: 2}}}

	const transcript = "Alice did great. Bram did too. Zephyrine did not. Quillon left early. Xander never came. Yara complained."
	seg := segmentPerClause(mathClassName, transcript,
		// 2 notes: both on the roster.
		"Alice", "Bram",
		// 4 mentions that resolve to nobody.
		"Zephyrine", "Quillon", "Xander", "Yara")
	// The last span becomes the group observation. Rewriting a clause span in
	// place keeps the tiling intact — appending one would leave it overlapping.
	// It carries no label, so it is not a mention, and it fans out to Alice and
	// Bram rather than counting as unattributed.
	seg.Spans[len(seg.Spans)-1].Kind = SpanGroup
	seg.Spans[len(seg.Spans)-1].SpokenLabels = nil
	// Yara moves onto Xander's span, so one span carries two labels that both
	// miss. That is what separates the label counter from the span counter: four
	// misses across three unattributed spans.
	seg.Spans[4].SpokenLabels = []string{"Xander", "Yara"}

	d := &mockDepsAll{
		transcriber:   &stubTranscriber{result: transcript},
		roster:        mathRoster("Alice", "Bram"),
		extractor:     &stubExtractor{model: "test-model-v1", result: seg},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

	done := logRecord(t, logs.String(), "process voice note completed")
	assert.Contains(t, done, `"mentions_total":6`, "denominator should count every label on a child span")
	assert.Contains(t, done, `"note_count":2`, "only labels that resolved become notes")
	assert.Contains(t, done, `"dropped_no_roster_match":4`, "one drop record per label that resolved to nobody")
	// The group span fanned out to Alice and Bram, so it is attributed, not
	// unattributed. unattributed_spans counts spans, never labels: it is the
	// counter that would otherwise have no home once a span carries several.
	assert.Contains(t, done, `"unattributed_spans":3`, "each child span whose only label missed is one unattributed span")
	assert.Contains(t, done, `"class_pinned":true`)
	// Model and prompt version turn the drop rate into a figure attributable to a
	// specific model/prompt change (#96).
	assert.Contains(t, done, `"model":"test-model-v1"`, "completion record should carry the model that produced the segmentation")
	assert.Contains(t, done, promptHashAttr, "completion record should carry the extraction prompt hash")
}

// TestProcessJob_TilingRejectFailsJob: spans that do not cover every clause are
// rejected, never repaired — a repaired partition is a guess about which child
// owns the missing text. The job fails so the teacher can re-run it, the
// transcript is already persisted, and no note is created from a partial
// segmentation.
func TestProcessJob_TilingRejectFailsJob(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}

	// Three clauses, one span covering the first: clause 3 is uncovered, so the
	// teacher's last observation belongs to nobody the model named.
	const transcript = "Alice did great. She was focused. Then everyone melted down."
	d := &mockDepsAll{
		transcriber: &stubTranscriber{result: transcript},
		roster:      mathRoster("Alice"),
		extractor: &stubExtractor{result: &SegmentResponse{
			ClassName: mathClassName,
			Spans: []Span{{
				Start: 1, End: 1, Kind: SpanChild,
				SpokenLabels: []string{"Alice"}, Summary: "Alice did great.",
			}},
		}},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

	err = processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID))
	require.Error(t, err, "a segmentation that does not tile must fail the job")
	assert.ErrorIs(t, err, ErrSpanTiling)

	// The step is the stable query key for this failure, separate from every other
	// extraction failure.
	assert.Contains(t, logs.String(), `"step":"reject span tiling"`)
	assert.Empty(t, nc.calls, "a rejected segmentation creates no note, not even the covered one")

	got, gerr := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
	require.NoError(t, gerr)
	assert.Equal(t, JobStatusFailed, got.Status)
	assert.NotContains(t, got.Error, "Alice", "the teacher's message names no student")

	row, rerr := voiceNoteRepo.GetByID(ctx, uploadID)
	require.NoError(t, rerr)
	require.NotNil(t, row.Transcript, "the transcript is persisted before extraction, so a reject loses nothing")
	assert.Equal(t, transcript, *row.Transcript)
}

// TestProcessJob_RosterReadFailureFailsJob: with the roster out of the prompt,
// reading it is load-bearing. A transient failure must not look like a recording
// in which nobody was named — it would complete clean with zero notes.
func TestProcessJob_RosterReadFailureFailsJob(t *testing.T) {
	db := setupTestDB(t)
	voiceNoteRepo := &VoiceNoteRepo{db: db}
	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)

	nc := &stubNoteCreator{}
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{result: "Alice did great."},
		roster:        &stubRoster{studentsErr: io.ErrUnexpectedEOF},
		extractor:     &stubExtractor{err: errors.New("must not be reached")},
		noteCreator:   nc,
		studentRepo:   &StudentRepo{db: db},
		voiceNoteRepo: voiceNoteRepo,
	}

	queue := newStubVoiceNoteQueue()
	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

	require.Error(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))
	assert.Contains(t, logs.String(), `"step":"read roster"`)
	assert.Empty(t, nc.calls)

	got, gerr := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
	require.NoError(t, gerr)
	assert.Equal(t, JobStatusFailed, got.Status)
}

// TestProcessJob_CompletionRecordNamesZeroMentionMode covers the third
// silent-nothing mode: extraction returns no mentions at all, so the job completes
// with no notes and no drops. It is indistinguishable from a job whose mentions
// were all dropped unless mentions_total says so.
func TestProcessJob_CompletionRecordNamesZeroMentionMode(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	newTestClass(t, classRepo, "test-group", "u1", "Math", "")

	tmpDir := t.TempDir()
	audioPath := filepath.Join(tmpDir, "test.m4a")
	require.NoError(t, os.WriteFile(audioPath, []byte("audio"), 0o644))

	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	queue := newStubVoiceNoteQueue()
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{result: "Thursday afternoon"},
		roster:        mathRoster("Alice"),
		extractor:     &stubExtractor{result: segmentPerClause(mathClassName, "Thursday afternoon", "")},
		noteCreator:   &stubNoteCreator{},
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	ctx, logs := captureLogs(context.Background())
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

	out := logs.String()
	done := logRecord(t, out, "process voice note completed")
	assert.Contains(t, done, `"mentions_total":0`, "zero-mention mode is what mentions_total:0 names")
	assert.Contains(t, done, `"note_count":0`)
	assert.Contains(t, done, `"dropped_no_roster_match":0`)
	assert.Contains(t, done, `"unattributed_spans":0`, "a `none` span is discarded, not unattributed")
	assert.Contains(t, done, `"class_pinned":true`, "the class was pinned; there was simply nobody in it to name")
	assert.NotContains(t, out, "mention dropped", "no mentions means nothing to drop")
}

// wantExtractionPromptHash recomputes the expected hash from the prompt templates
// via hashPrompt, independently of the ExtractionPromptHash package var — so a
// mutation that blanks that var, or that logs some other package's hash (e.g.
// ReportPromptHash) instead, is caught rather than passing on a same-value or
// right-shape coincidence.
var wantExtractionPromptHash = hashPrompt(extractionPromptPrefix + "<<<classes>>>" + extractionPromptSuffix)

// promptHashAttr is the exact expected prompt_hash attribute as it appears in a
// log line.
var promptHashAttr = fmt.Sprintf(`"prompt_hash":%q`, wantExtractionPromptHash)

// logRecord returns the single captured record whose message contains substr,
// so assertions apply to one record rather than to the whole log.
func logRecord(t *testing.T, out, substr string) string {
	t.Helper()
	var found []string
	for _, line := range strings.Split(strings.TrimSpace(out), "\n") {
		if strings.Contains(line, substr) {
			found = append(found, line)
		}
	}
	require.Len(t, found, 1, "expected exactly one log record containing %q", substr)
	return found[0]
}

// TestProcessJob_FailurePathsOmitStudentName covers the other half of ADR 0003:
// the two fail() paths log at Error, and job_queue_mem re-logs the returned error
// at Error too, so each one becomes a Sentry Issue rather than a log record. These
// are the sites where the name used to be interpolated into the step string.
func TestProcessJob_FailurePathsOmitStudentName(t *testing.T) {
	newDeps := func(studentRepo *StudentRepo, voiceNoteRepo *VoiceNoteRepo, nc NoteCreator) *mockDepsAll {
		return &mockDepsAll{
			transcriber: &stubTranscriber{result: "Zephyrine did well."},
			roster:      mathRoster("Zephyrine"),
			extractor: &stubExtractor{
				result: segmentPerClause(mathClassName, "Zephyrine did well.", "Zephyrine"),
			},
			noteCreator:   nc,
			studentRepo:   studentRepo,
			voiceNoteRepo: voiceNoteRepo,
		}
	}

	t.Run("student lookup fails", func(t *testing.T) {
		db := setupTestDB(t)
		classRepo := &ClassRepo{db: db}
		cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
		_, err := (&StudentRepo{db: db}).Create(t.Context(), cls.ID, "Zephyrine")
		require.NoError(t, err)

		// The voice note lives in its own DB so the transcript write still succeeds
		// once the students DB is closed below.
		voiceNoteRepo := &VoiceNoteRepo{db: setupTestDB(t)}
		audioPath := newTestAudio(t)
		uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)

		d := newDeps(&StudentRepo{db: db}, voiceNoteRepo, &stubNoteCreator{})
		// Close the DB so the lookup fails with something other than ErrNotFound,
		// which is the branch that used to interpolate the name into the step.
		require.NoError(t, db.Close())

		queue := newStubVoiceNoteQueue()
		ctx, logs := captureLogs(context.Background())
		require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

		err = processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID))
		require.Error(t, err, "a failed student lookup should fail the job")

		out := logs.String()
		require.Contains(t, out, "process voice note failed", "the failure was not logged at all")
		// Every fail() in the pipeline shares that message, so pin the step: otherwise a
		// fail() promoted earlier would keep this green while no longer covering this branch.
		require.Contains(t, out, `"step":"find student"`, "a different fail() ran; this branch is no longer covered")
		assert.NotContains(t, out, "Zephyrine", "failure step leaked a student name into the logs")
		assert.NotContains(t, err.Error(), "Zephyrine", "returned error leaks the name, and job_queue_mem re-logs it")

		// job.Error is the teacher's copy, not telemetry — it should still name the
		// student, which is the whole point of splitting it from the logged step.
		got, gerr := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
		require.NoError(t, gerr)
		assert.Contains(t, got.Error, "Zephyrine", "the teacher should still be told which student failed")
	})

	t.Run("note creation fails", func(t *testing.T) {
		db := setupTestDB(t)
		classRepo := &ClassRepo{db: db}
		studentRepo := &StudentRepo{db: db}
		cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
		_, err := studentRepo.Create(t.Context(), cls.ID, "Zephyrine")
		require.NoError(t, err)

		nc := &stubNoteCreator{err: errors.New("note store unavailable")}
		voiceNoteRepo := &VoiceNoteRepo{db: db}
		audioPath := newTestAudio(t)
		uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
		d := newDeps(studentRepo, voiceNoteRepo, nc)

		queue := newStubVoiceNoteQueue()
		ctx, logs := captureLogs(context.Background())
		require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))

		err = processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID))
		require.Error(t, err, "a failed note creation should fail the job")
		require.Len(t, nc.calls, 1, "note creation should have been attempted")

		out := logs.String()
		require.Contains(t, out, "process voice note failed", "the failure was not logged at all")
		require.Contains(t, out, `"step":"create note for student`, "a different fail() ran; this branch is no longer covered")
		assert.NotContains(t, out, "Zephyrine", "failure step leaked a student name into the logs")
		assert.NotContains(t, err.Error(), "Zephyrine", "returned error leaks the name, and job_queue_mem re-logs it")

		got, gerr := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
		require.NoError(t, gerr)
		assert.Contains(t, got.Error, "Zephyrine", "the teacher should still be told which student failed")
		assert.NotContains(t, got.Error, "student 1", "the teacher should not be shown a raw student id")
	})
}

// mathClassName is the display name of newTestClass(…, "Math", ""): Level · Day
// abbreviated, the string classDisplayNameSQL derives. AssembleNotes pins the
// model's class_name against the roster's names and FindByNameAndClass looks up
// the same string, so a stub roster naming the level ("Math") pins nothing and
// every test built on it fails alike, with zero notes and no explanation.
const mathClassName = "Math · Mon"

// mathRoster is the one-class roster these tests extract against.
func mathRoster(names ...string) *stubRoster {
	students := make([]ClassStudent, len(names))
	for i, n := range names {
		students[i] = ClassStudent{Name: n}
	}
	return &stubRoster{
		classNames: []string{mathClassName},
		students:   []ClassGroup{{Name: mathClassName, Students: students}},
	}
}

// TestProcessJob_NoNotesReason: a done job that created no note says which of
// three things happened. One green "No notes created" for all three reads as
// "nothing was in the recording", which is wrong for two of them and sends the
// teacher to do the wrong thing next.
func TestProcessJob_NoNotesReason(t *testing.T) {
	// Every case runs the whole pipeline; only the segmentation differs.
	cases := []struct {
		name       string
		transcript string
		seg        func(transcript string) *SegmentResponse
		want       string
	}{
		{
			name:       "nobody named",
			transcript: "Thursday afternoon.",
			seg: func(tr string) *SegmentResponse {
				return segmentPerClause(mathClassName, tr, "")
			},
			want: NoNotesNobodyNamed,
		},
		{
			name:       "class declined",
			transcript: "Alice did great.",
			seg: func(tr string) *SegmentResponse {
				return segmentPerClause("", tr, "Alice")
			},
			want: NoNotesClassUnclear,
		},
		{
			// Nobody named AND no class pinned: still "nobody named". A
			// recording with no child in it would not have produced a note
			// whatever the class, so sending the teacher to re-state the class
			// would waste their time.
			name:       "class declined and nobody named",
			transcript: "Thursday afternoon.",
			seg: func(tr string) *SegmentResponse {
				return segmentPerClause("", tr, "")
			},
			want: NoNotesNobodyNamed,
		},
		{
			name:       "no name matched",
			transcript: "Zephyrine did great.",
			seg: func(tr string) *SegmentResponse {
				return segmentPerClause(mathClassName, tr, "Zephyrine")
			},
			want: NoNotesNoNameMatched,
		},
	}

	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			db := setupTestDB(t)
			studentRepo := &StudentRepo{db: db}
			classRepo := &ClassRepo{db: db}
			voiceNoteRepo := &VoiceNoteRepo{db: db}

			cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
			_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
			require.NoError(t, err)

			audioPath := newTestAudio(t)
			uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
			nc := &stubNoteCreator{}
			d := &mockDepsAll{
				transcriber:   &stubTranscriber{result: tc.transcript},
				roster:        mathRoster("Alice"),
				extractor:     &stubExtractor{result: tc.seg(tc.transcript)},
				noteCreator:   nc,
				studentRepo:   studentRepo,
				voiceNoteRepo: voiceNoteRepo,
			}

			queue := newStubVoiceNoteQueue()
			ctx := context.Background()
			require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
			require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

			got, err := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
			require.NoError(t, err)
			require.Equal(t, JobStatusDone, got.Status)
			require.Empty(t, nc.calls, "this fixture must produce no note, or it is testing nothing")
			assert.Equal(t, tc.want, got.NoNotesReason)
		})
	}
}

// TestProcessJob_NoNotesReasonEmptyWhenNotesCreated: the field explains an
// empty result, so a job with a note must not carry one — the done card keys
// its whole message off it.
func TestProcessJob_NoNotesReasonEmptyWhenNotesCreated(t *testing.T) {
	db := setupTestDB(t)
	studentRepo := &StudentRepo{db: db}
	classRepo := &ClassRepo{db: db}
	voiceNoteRepo := &VoiceNoteRepo{db: db}

	cls := newTestClass(t, classRepo, "test-group", "u1", "Math", "")
	_, err := studentRepo.Create(t.Context(), cls.ID, "Alice")
	require.NoError(t, err)

	audioPath := newTestAudio(t)
	uploadID := newTestVoiceNote(t, voiceNoteRepo, "u1", audioPath)
	nc := &stubNoteCreator{results: []*CreateNoteResponse{{NoteID: 1}}}
	// One label resolves, one misses: a partial result is still a result, and
	// #80 covers the miss.
	const transcript = "Alice did great. Zephyrine did not."
	d := &mockDepsAll{
		transcriber:   &stubTranscriber{result: transcript},
		roster:        mathRoster("Alice"),
		extractor:     &stubExtractor{result: segmentPerClause(mathClassName, transcript, "Alice", "Zephyrine")},
		noteCreator:   nc,
		studentRepo:   studentRepo,
		voiceNoteRepo: voiceNoteRepo,
	}

	queue := newStubVoiceNoteQueue()
	ctx := context.Background()
	require.NoError(t, queue.Publish(ctx, VoiceNoteJob{UserID: "u1", UploadID: uploadID, FilePath: audioPath, Status: JobStatusQueued, CreatedAt: time.Now()}))
	require.NoError(t, processVoiceNote(ctx, d, queue, voiceNoteKey("u1", uploadID)))

	got, err := queue.GetJob(ctx, voiceNoteKey("u1", uploadID))
	require.NoError(t, err)
	require.Len(t, nc.calls, 1)
	assert.Empty(t, got.NoNotesReason, "a job that created a note explains nothing")
}

// newTestVoiceNote inserts the voice_notes row a job needs. processVoiceNote writes
// the transcript to that row and fails the job when it is missing.
func newTestVoiceNote(t *testing.T, repo *VoiceNoteRepo, userID, filePath string) int64 {
	t.Helper()
	vn, err := repo.Create(t.Context(), userID, filepath.Base(filePath), filePath)
	require.NoError(t, err)
	return vn.ID
}

// newTestAudio writes a throwaway audio file and returns its path.
func newTestAudio(t *testing.T) string {
	t.Helper()
	path := filepath.Join(t.TempDir(), "test.m4a")
	require.NoError(t, os.WriteFile(path, []byte("audio"), 0o644))
	return path
}
