// voice_note_assign.go implements POST /api/voice-notes/{uploadId}/assign: the
// teacher files passages the recording could not place — a pronoun block, a
// name nobody on the roster answers to — to a child they pick on the done
// card, and a note exists for that child, dated from the recording (#134).
//
// The passages come from the card, not from the job. The job is in memory and
// gone on restart, and pass 2 is non-deterministic, so an index into a job's
// passage list could point at other text than the teacher ticked. That makes
// the text client-supplied: the server holds no copy to check it against, and
// the note is filed under NoteSourceAssigned rather than a model-written
// source for exactly that reason.
package handler

import (
	"encoding/json"
	"errors"
	"net/http"
	"strings"
)

// AssignPassagesRequest is the body of the assign call: the class in force on
// the card, the child to file to, and the passages the teacher ticked.
//
// One student per call. The card confirms per child, so a confirm is one
// request and one note: atomic by construction, with no transaction across
// notes to get wrong.
type AssignPassagesRequest struct {
	// ClassID is the class whose roster the card offered. The server checks
	// that the caller owns it and that StudentID is on it, which proves the
	// picker showed the right roster and forbids filing to a child of another
	// class.
	ClassID   int64           `json:"classId"`
	StudentID int64           `json:"studentId"`
	Passages  []AssignPassage `json:"passages"`
}

// AssignPassage is one passage as the card sends it back: what kind it was,
// and the words. Nothing else — spoken labels and the student are the
// server's business, and the server does not read them here.
type AssignPassage struct {
	Kind    PassageKind `json:"kind"`
	Summary string      `json:"summary"`
}

// AssignPassagesResponse is the note link the call made, in the shape the card
// already merges into its note links, plus whether it was an append.
type AssignPassagesResponse struct {
	NoteID    int64  `json:"noteId"`
	StudentID int64  `json:"studentId"`
	Name      string `json:"name"`
	ClassName string `json:"className"`
	// Appended is false on every response this shard can give: a note was
	// created. #135 adds the append path.
	Appended bool `json:"appended"`
}

// handleAssignPassages files ticked passages to one child as a new note.
//
// Order matters, and it is the assemble handler's:
//
//   - Every ownership gate runs before the lock and before any read a write
//     depends on: the recording (bare 404 either way, so a probe learns
//     nothing), the class, the student's membership of that class, the
//     transcript's presence. A body that fails validation is refused, never
//     repaired.
//   - The lock is taken after the checks and held across the note write and
//     the job update. A double-click gets 409 at once.
//   - The job is read inside the lock: a mid-run or failed job is refused,
//     and a done one gets the link appended, nothing more. No passage state,
//     no class, no review state moves. Review
//     lives on the card; the link is the filing result, and a reload rebuilds
//     the card from the job, so the job has to carry it or the count is wrong,
//     the class picker comes back, and a re-pick on a declined recording
//     makes a second note for a child who has one.
func handleAssignPassages(w http.ResponseWriter, r *http.Request) {
	log := loggerFromRequest(r)

	userID, err := userIDFromRequest(r)
	if err != nil {
		writeError(w, r, err)
		return
	}
	uploadID, ok := idParam(r, "uploadId")
	if !ok {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid upload id"})
		return
	}

	// The passages are bounded by the transcript, and the transcript by
	// maxTextSize; the envelope allowance is text_notes.go's.
	r.Body = http.MaxBytesReader(w, r.Body, int64(maxTextSize)+1024)
	var req AssignPassagesRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		var tooBig *http.MaxBytesError
		if errors.As(err, &tooBig) {
			writeJSON(w, http.StatusRequestEntityTooLarge, map[string]string{"error": "request too large"})
			return
		}
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "invalid JSON"})
		return
	}
	if req.ClassID <= 0 || req.StudentID <= 0 {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": "classId and studentId are required"})
		return
	}

	// Ownership, part one: the recording. GetByID is unscoped, so the user
	// match is the gate, and it runs first so a caller probing another
	// tenant's upload id always gets the same body whatever else they send.
	row, err := serviceDeps.GetVoiceNoteRepo().GetByID(r.Context(), uploadID)
	switch {
	case errors.Is(err, ErrNotFound):
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "recording not found"})
		return
	case err != nil:
		writeInternalError(w, r, err)
		return
	case row.UserID != userID:
		log.Warn("assign passages: recording not owned", "upload_id", uploadID, "user_id", userID)
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "recording not found"})
		return
	}

	// Part two: the class, scanned over the caller's own list.
	class, err := ownedClass(r.Context(), req.ClassID, userID)
	switch {
	case errors.Is(err, ErrNotFound):
		log.Warn("assign passages: class not owned", "upload_id", uploadID, "user_id", userID)
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "class not found"})
		return
	case err != nil:
		writeInternalError(w, r, err)
		return
	}

	// Part three: the student is on that class. Membership, not just
	// ownership: the roster the card offered is the one the note is filed
	// against, and a child of another class must not be reachable through it.
	student, err := serviceDeps.GetStudentRepo().GetByID(r.Context(), req.StudentID)
	switch {
	case errors.Is(err, ErrNotFound), err == nil && student.ClassID != req.ClassID:
		log.Warn("assign passages: student not on class", "upload_id", uploadID, "user_id", userID, "student_id", req.StudentID)
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "student not found"})
		return
	case err != nil:
		writeInternalError(w, r, err)
		return
	}

	if row.Transcript == nil || *row.Transcript == "" {
		// A job that failed before transcription, or a row the retention
		// cleanup emptied. Same as assemble: nothing to file a note against.
		writeJSON(w, http.StatusNotFound, map[string]string{"error": "this recording has no transcript"})
		return
	}
	transcript := *row.Transcript

	noteDate, err := uploadDay(row.CreatedAt)
	if err != nil {
		writeInternalError(w, r, err)
		return
	}

	own, group, kindCounts, err := splitAssignPassages(req.Passages, transcript)
	if err != nil {
		writeJSON(w, http.StatusBadRequest, map[string]string{"error": err.Error()})
		return
	}

	extractor, err := serviceDeps.GetExtractor()
	if err != nil {
		writeInternalError(w, r, err)
		return
	}

	// One write at a time per recording. Immediately, not a blocking wait: a
	// double-click gets told no rather than making a second note.
	key := voiceNoteKey(userID, uploadID)
	if !takeUploadLock(key) {
		writeJSON(w, http.StatusConflict, map[string]string{"error": "this recording is already being filed"})
		return
	}
	defer releaseUploadLock(key)

	// The job, read once inside the lock. Two of assemble's refusals apply
	// and one does not. A job mid-run would have the pipeline's closing write
	// replace the link list seconds later, and a failed one's route is retry,
	// which rebuilds the job the same way: the note would survive, the card
	// would lose it, and the child might get the pipeline's copy too. "Already
	// has notes" is not copied: a card with one child filed and two rows open
	// is the case this endpoint exists for. Not reachable from the card, which
	// renders these controls on a done card only; this is the API's own line.
	// A gone job is fine: after a restart the card is gone on the next reload
	// too, and nothing is lost.
	queue, queueErr := serviceDeps.GetVoiceNoteQueue()
	var job *VoiceNoteJob
	if queueErr == nil {
		if j, err := queue.GetJob(r.Context(), key); err == nil {
			job = j
		}
	}
	switch {
	case job == nil:
	case job.Status == JobStatusFailed:
		writeJSON(w, http.StatusConflict, map[string]string{"error": "this recording did not finish — retry it first"})
		return
	case job.Status != JobStatusDone:
		writeJSON(w, http.StatusConflict, map[string]string{"error": "this recording is still being processed"})
		return
	}

	// The extractor's model, as the pipeline and assemble stamp it: it
	// produced the words, it only missed the assignment. The job carries no
	// version, and the window for a mismatch is the card's lifetime.
	result, err := serviceDeps.GetNoteCreator().CreateNote(r.Context(), CreateNoteRequest{
		StudentID:    student.ID,
		StudentName:  student.Name,
		QuotedText:   joinPassageText(own, group),
		Transcript:   transcript,
		Date:         noteDate,
		ModelVersion: extractor.Model(),
		Source:       NoteSourceAssigned,
	})
	if err != nil {
		writeInternalError(w, r, err)
		return
	}
	link := NoteLink{Name: student.Name, NoteID: result.NoteID, StudentID: student.ID, ClassName: class.Name}

	// The link goes on the queued job, as assemble writes its links at the end
	// of its handler. Nothing else on the job moves.
	if job != nil {
		job.NoteLinks = append(job.NoteLinks, link)
		if err := queue.UpdateJob(r.Context(), *job); err != nil {
			// The note exists; only the card's next poll is stale.
			log.Warn("assign passages: could not update queued job", "upload_id", uploadID, "error", err)
		}
	}

	// Same pinned query string as the pipeline's and the class picker's
	// recovery records, so the Sentry readout sees every route a passage can
	// reach a child by. No name, no text (docs/adr/0003).
	log.Info("process voice note: passage recovered",
		"route", "manual",
		"appended", false,
		"kind_counts", kindCounts,
		"passage_count", len(own)+len(group),
		"user_id", userID, "upload_id", uploadID, "student_id", student.ID,
		"model", extractor.Model(), "prompt_hash", ExtractionPromptHash)

	writeJSON(w, http.StatusOK, AssignPassagesResponse{
		NoteID:    link.NoteID,
		StudentID: link.StudentID,
		Name:      link.Name,
		ClassName: link.ClassName,
		Appended:  false,
	})
}

// splitAssignPassages validates the passages the card sent and sorts them into
// the child's own and the recording's class-wide ones, in the order sent.
//
// Every rule refuses rather than repairs: a kind outside the three the card
// can hold, an empty summary, a summary longer than the transcript it claims
// to summarise, or nothing but group passages — a note that says only
// "everyone did well" is not a filing of anything that reached nobody. There
// is no `none`: those are dropped at assembly and never on the wire.
//
// The length cap is the whole of the text check. A substring rule would fail
// the first time the model rewrote a sentence, which is what a summary is.
func splitAssignPassages(passages []AssignPassage, transcript string) (own, group []string, kindCounts map[PassageKind]int, err error) {
	kindCounts = map[PassageKind]int{}
	for _, p := range passages {
		switch p.Kind {
		case PassageChild, PassageUnknown, PassageGroup:
		default:
			return nil, nil, nil, errors.New("passage kind must be child, unknown or group")
		}
		if strings.TrimSpace(p.Summary) == "" {
			return nil, nil, nil, errors.New("passage summary is required")
		}
		if len(p.Summary) > len(transcript) {
			return nil, nil, nil, errors.New("passage summary is longer than the recording")
		}
		kindCounts[p.Kind]++
		if p.Kind == PassageGroup {
			group = append(group, p.Summary)
		} else {
			own = append(own, p.Summary)
		}
	}
	if len(own) == 0 {
		return nil, nil, nil, errors.New("at least one child or unknown passage is required")
	}
	return own, group, kindCounts, nil
}
