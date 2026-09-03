// voice_note_process.go implements the voice note processing pipeline
// (transcribe → extract → create notes). Called by MemQueue workers.
package handler

import (
	"context"
	"errors"
	"fmt"
	"os"
	"strings"
	"time"
)

// errNoSpeechDetected marks an empty/silent recording. It's a user-input
// condition, not an application bug, so fail() logs it as a warning instead
// of an error — keeping it out of Sentry issues while still failing the job.
var errNoSpeechDetected = errors.New("no speech detected in audio")

// processVoiceNote runs the voice note pipeline for a single job.
// It is the ProcessFunc for the voice note MemQueue — receives the queue
// (for status updates) and the job key.
func processVoiceNote(ctx context.Context, d deps, q JobQueue[VoiceNoteJob], key string) error {
	log := loggerFromContext(ctx)

	job, err := q.GetJob(ctx, key)
	if err != nil {
		return fmt.Errorf("process voice note: get job: %w", err)
	}

	// Idempotency: only process jobs that are queued.
	if job.Status != JobStatusQueued {
		log.Info("process voice note: skipping non-queued job", "key", key, "status", job.Status)
		return nil
	}

	userID := job.UserID
	uploadID := job.UploadID

	// failJob marks the job failed and returns the error, writing to two audiences.
	//
	// step is telemetry: it is logged here, and the returned error is logged again by
	// the queue worker, so both reach Sentry and neither may carry a student name
	// (docs/adr/0003). message is what the teacher reads verbatim — JobStatus
	// renders job.Error.
	failJob := func(step, message string, err error) error {
		if errors.Is(err, errNoSpeechDetected) {
			log.Warn("process voice note failed", "step", step, "key", key, "error", err)
		} else {
			log.Error("process voice note failed", "step", step, "key", key, "error", err)
		}
		now := time.Now()
		job.Status = JobStatusFailed
		job.Error = message
		job.FailedAt = &now
		if updateErr := q.UpdateJob(ctx, *job); updateErr != nil {
			log.Error("process voice note: failed to update job status to failed", "error", updateErr)
		}
		return fmt.Errorf("process voice note: %s: %w", step, err)
	}
	// failWith composes the teacher's message from detail plus the raw error. detail
	// may name the student they are entitled to see; step must not.
	failWith := func(step, detail string, err error) error {
		return failJob(step, fmt.Sprintf("%s: %s", detail, err.Error()), err)
	}

	// failTooOld is for a retry that outlived the retention cleanup: the audio file
	// or the voice_notes row is gone, and no wording of the raw error helps the
	// teacher. Same telemetry step as the raw failure would have carried.
	failTooOld := func(step string, err error) error {
		return failJob(step, "this upload is too old to retry", err)
	}

	// Helper to mark job as failed and return the error, where the same wording
	// serves both audiences because no student is named.
	fail := func(step string, err error) error {
		return failWith(step, step, err)
	}

	// --- Step 1: Transcribe (skip if text was pasted) ---
	roster := d.GetRoster(ctx, userID)
	var transcript string
	if job.Transcript != "" {
		// Text input, or a retry after transcription — skip transcription entirely.
		transcript = job.Transcript
		log.Info("process voice note: skipping transcription, job already carries the text", "key", key)
	} else {
		job.Status = JobStatusTranscribing
		if err := q.UpdateJob(ctx, *job); err != nil {
			return fail("update status to transcribing", err)
		}

		audioFile, err := os.Open(job.FilePath)
		if err != nil {
			if os.IsNotExist(err) {
				// The retention cleanup removed the file: a job that failed before
				// transcription and was retried after the window.
				return failTooOld("open audio file", err)
			}
			return fail("open audio file", err)
		}
		defer audioFile.Close()

		var classNames []string
		names, err := roster.ClassNames(ctx)
		if err != nil {
			log.Warn("process voice note: could not read class names", "error", err)
		} else {
			classNames = names
		}

		transcriber, err := d.GetTranscriber()
		if err != nil {
			return fail("init transcriber", err)
		}

		transcript, err = transcriber.Transcribe(ctx, job.FileName, audioFile, classNames)
		if err != nil {
			return fail("transcribe", err)
		}
		if strings.TrimSpace(transcript) == "" {
			return fail("transcribe", errNoSpeechDetected)
		}
		job.Transcript = transcript

		// Delete the audio file immediately after successful transcription —
		// the raw recording is no longer needed; the transcript is sufficient.
		// This comes before the transcript is persisted, on purpose: the privacy
		// page promises the recording is gone right after transcription, so no
		// failure below may leave it on disk.
		if job.FilePath != "" {
			if removeErr := os.Remove(job.FilePath); removeErr != nil && !os.IsNotExist(removeErr) {
				log.Warn("process voice note: could not delete audio after transcription",
					"path", job.FilePath, "error", removeErr)
			} else {
				voiceNoteRepo := d.GetVoiceNoteRepo()
				if purgeErr := voiceNoteRepo.MarkPurged(ctx, uploadID); purgeErr != nil {
					log.Warn("process voice note: could not mark audio purged", "error", purgeErr)
				}
			}
		}
	}

	// Persist the transcript on the voice_notes row before extraction, so it exists
	// whether or not any note is created — the only other copy is notes.transcript,
	// written per created note. A failed write fails the job: the job struct keeps
	// the transcript, so a retry skips transcription and lands here again. The
	// error carries no transcript (docs/adr/0003).
	if err := d.GetVoiceNoteRepo().SetTranscript(ctx, uploadID, transcript); err != nil {
		if errors.Is(err, ErrNotFound) {
			// The retention cleanup removed the row: a retry that outlived the window.
			return failTooOld("persist transcript", err)
		}
		return fail("persist transcript", err)
	}

	// --- Step 2: Extract ---
	job.Status = JobStatusExtracting
	if err := q.UpdateJob(ctx, *job); err != nil {
		return fail("update status to extracting", err)
	}

	classes, err := roster.Students(ctx)
	if err != nil {
		// Fail rather than continue. With the roster out of the prompt this read is
		// load-bearing: no classes means nothing pins, every label misses and the job
		// finishes clean with zero notes. A transient DB error must not look like a
		// recording nobody was named in. The transcript is persisted, so a retry is free.
		return fail("read roster", err)
	}

	extractor, err := d.GetExtractor()
	if err != nil {
		return fail("init extractor", err)
	}

	segmentation, err := extractor.Extract(ctx, ExtractRequest{
		Transcript: transcript,
		Classes:    classes,
	})
	if err != nil {
		return fail("extract", err)
	}

	// The model segments; Go resolves the names (#99). AssembleNotes rejects spans
	// that do not tile the clauses rather than repairing them — a repaired partition
	// is a guess about which child owns the missing text, the failure this whole
	// pipeline exists to remove.
	assembled, err := AssembleNotes(transcript, classes, *segmentation)
	if err != nil {
		// ErrSpanTiling is AssembleNotes's only error. "reject span tiling" is its
		// own stable query key, separate from every other extraction failure. No
		// automatic retry: the same transcript through the same model tiles no
		// better. The transcript is already persisted, so the teacher can re-run.
		return failJob("reject span tiling",
			"could not split this recording into per-student observations", err)
	}
	if assembled.UnknownClassName != "" {
		// The schema constrains class_name to an enum of real names plus "", so a
		// name outside it means the schema was not applied — a prompt or provider
		// defect, not a teacher's recording.
		//
		// The name itself is withheld. Everywhere else class_name is a string this
		// code put in the enum; here it is whatever an unconstrained model wrote,
		// and a model writing freely into a class field can write a child's name
		// (docs/adr/0003). Its length is enough to tell a truncated response from a
		// hallucinated class, and the transcript on the row has the rest.
		log.Warn("process voice note: model named a class not on the roster",
			"key", key, "user_id", userID, "upload_id", uploadID,
			"class_name_len", len([]rune(assembled.UnknownClassName)),
			"model", extractor.Model(), "prompt_hash", ExtractionPromptHash)
	}

	// --- Step 3: Create notes ---
	job.Status = JobStatusCreatingNotes
	if err := q.UpdateJob(ctx, *job); err != nil {
		return fail("update status to creating_notes", err)
	}

	noteCreator := d.GetNoteCreator()
	studentRepo := d.GetStudentRepo()

	var noteLinks []NoteLink

	// The note's date is the day the teacher recorded, which is the day the job was
	// created at upload (voice_note_dispatch.go) — not time.Now(). Processing is queued
	// and retryable (handleJobRetry republishes the same job struct, and Publish stores
	// it verbatim), so the processing clock can land days after the recording and would
	// drop the note out of the report window it belongs to. Do not "simplify" this to
	// time.Now().
	//
	// UTC, matching every created_at column. No teacher timezone is stored anywhere, so
	// a recording whose local day differs from its UTC day is dated to the UTC one.
	// West of Greenwich that window is late afternoon to local midnight — class time:
	// 16:15 at UTC-8 is 00:15 the next day in UTC. East of Greenwich it is local
	// midnight to the offset, which is not class time. Today's teachers are all east of
	// Greenwich; plumbing a client timezone is deferred, not judged unnecessary.
	noteDate := job.CreatedAt.UTC().Format(time.DateOnly)

	// Drops are only interpretable as a rate, so the completion record below needs a
	// denominator and a per-reason breakdown. note_count alone yields notes-created,
	// never mentions-extracted.
	//
	// A mention is one spoken label on one child span — the unit the model produces and
	// the unit that can be dropped, so the numerator below stays a subset of this.
	// Group spans that fanned out to nobody are counted separately, as spans: they
	// carry no label and were never a mention.
	mentionsTotal := 0
	for _, sp := range segmentation.Spans {
		if sp.Kind == SpanChild {
			mentionsTotal += len(sp.SpokenLabels)
		}
	}

	droppedNoRosterMatch := len(assembled.Misses)
	for _, miss := range assembled.Misses {
		// "process voice note: mention dropped" is a stable query key: the Sentry
		// readout filters on this exact string paired with reason. Do not reword it
		// without updating the saved queries.
		//
		// The label that missed is a name as the teacher spoke it, so it never
		// reaches telemetry (docs/adr/0003) — the span's clause range locates it in
		// the persisted transcript instead. class_name is the diagnostic field: it
		// is empty whenever the model declined to pin a class, which drops every
		// label at once.
		log.Info("process voice note: mention dropped",
			"reason", "no_roster_match",
			"key", key, "user_id", userID, "upload_id", uploadID,
			"class_name", assembled.ClassName,
			"span_start", miss.Start, "span_end", miss.End,
			"model", extractor.Model(), "prompt_hash", ExtractionPromptHash)
	}

	for _, note := range assembled.Notes {
		// AssembleNotes returns canonical roster names, so this lookup is an ID
		// read, not a second matcher: the exact NOCASE match is expected to hit.
		studentID, err := studentRepo.FindByNameAndClass(ctx, note.Name, note.ClassName, userID)
		if err != nil {
			if errors.Is(err, ErrNotFound) {
				// The roster read and this lookup disagree — the class was renamed
				// or the student deleted between them.
				droppedNoRosterMatch++
				log.Info("process voice note: mention dropped",
					"reason", "no_roster_match",
					"key", key, "user_id", userID, "upload_id", uploadID,
					"class_name", note.ClassName,
					"model", extractor.Model(), "prompt_hash", ExtractionPromptHash)
				continue
			}
			// The failed lookup is the only source of an identifier here, so telemetry
			// carries none; the teacher still gets the name that failed to resolve.
			return failWith("find student", "find student "+note.Name, err)
		}

		result, err := noteCreator.CreateNote(ctx, CreateNoteRequest{
			StudentID:    studentID,
			StudentName:  note.Name,
			QuotedText:   note.Text,
			Transcript:   transcript,
			Date:         noteDate,
			ModelVersion: extractor.Model(),
		})
		if err != nil {
			return failWith(
				fmt.Sprintf("create note for student %d", studentID),
				"create note for "+note.Name,
				err)
		}
		noteLinks = append(noteLinks, NoteLink{
			Name: note.Name, NoteID: result.NoteID,
			StudentID: studentID, ClassName: note.ClassName,
		})
	}

	// --- Done ---
	voiceNoteRepo := d.GetVoiceNoteRepo()
	if err := voiceNoteRepo.MarkProcessed(ctx, uploadID); err != nil {
		log.Warn("process voice note: failed to mark voice note processed", "error", err)
	}

	job.Status = JobStatusDone
	job.NoteLinks = noteLinks
	job.NoNotesReason = noNotesReason(len(noteLinks), mentionsTotal, assembled.ClassName)
	job.Error = ""
	job.FailedAt = nil
	if err := q.UpdateJob(ctx, *job); err != nil {
		return fmt.Errorf("process voice note: update status to done: %w", err)
	}

	// mentions_total is the denominator the drop records are read against; 0 also
	// names the third silent-nothing mode, where extraction returned no mentions at
	// all and there is consequently nothing to drop.
	//
	// This record is the authoritative numerator as well as the denominator: derive the
	// drop rate from its own dropped_* fields over its own mentions_total. Counting the
	// per-mention drop records instead mixes populations — a job that fails partway
	// emits drop records but never reaches this line — and that mistake has already
	// produced one wrong figure for this task.
	log.Info("process voice note completed",
		"key", key, "user_id", userID, "upload_id", uploadID,
		"note_count", len(noteLinks),
		"mentions_total", mentionsTotal,
		"dropped_no_roster_match", droppedNoRosterMatch,
		"unattributed_spans", len(assembled.Unattributed),
		"class_pinned", assembled.ClassName != "",
		"model", extractor.Model(), "prompt_hash", ExtractionPromptHash)
	return nil
}

// noNotesReason explains a job that created no note, for the teacher rather
// than for telemetry — the done card shows it verbatim in intent.
//
// Order matters. A recording that named nobody has nothing to attribute
// whatever the class, so it is not a class problem even when the class was
// also declined; saying otherwise would send the teacher to re-record
// something that was never going to produce a note.
func noNotesReason(noteCount, mentionsTotal int, pinnedClass string) string {
	switch {
	case noteCount > 0:
		return ""
	case mentionsTotal == 0:
		return NoNotesNobodyNamed
	case pinnedClass == "":
		return NoNotesClassUnclear
	default:
		return NoNotesNoNameMatched
	}
}
