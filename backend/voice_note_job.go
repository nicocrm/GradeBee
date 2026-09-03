// voice_note_job.go defines the VoiceNoteJob type and status constants
// for async voice note processing (transcribe → extract → create notes).
package handler

import (
	"fmt"
	"time"
)

// Job status constants for voice note processing.
const (
	JobStatusQueued        = "queued"
	JobStatusTranscribing  = "transcribing"
	JobStatusExtracting    = "extracting"
	JobStatusCreatingNotes = "creating_notes"
	JobStatusDone          = "done"
	JobStatusFailed        = "failed"
)

// A job can finish with no note for three different reasons, and the teacher
// can only act on two of them. Without this the done card says "No notes
// created" for all three, which reads as "nothing was in the recording" —
// wrong, and the wrong thing to do next.
//
// The class one is the reason this exists: the model is allowed to decline a
// class rather than guess (#99), and a correctly spoken header can still fail
// to identify one, because (level, day) collides for 4 of this user's 12
// classes and time_slot is free text.
const (
	// NoNotesNobodyNamed: the recording named no child at all. Nothing to do.
	NoNotesNobodyNamed = "nobody_named"
	// NoNotesClassUnclear: children were named, but no class was pinned, so
	// there was no roster to resolve them against. Saying the class and time
	// at the start of the next recording fixes it.
	NoNotesClassUnclear = "class_unclear"
	// NoNotesNoNameMatched: the class was pinned and every spoken name missed
	// the roster. An alias fixes the recurring ones; #80 will fix the rest.
	NoNotesNoNameMatched = "no_name_matched"
)

// NoteLink pairs a student name with the ID of the created note.
type NoteLink struct {
	Name      string `json:"name"`
	NoteID    int64  `json:"noteId"`
	StudentID int64  `json:"studentId"`
	ClassName string `json:"className"`
}

// VoiceNoteJob represents an async voice note processing job.
type VoiceNoteJob struct {
	UserID     string     `json:"userId"`
	UploadID   int64      `json:"uploadId"`
	FilePath   string     `json:"filePath"`
	FileName   string     `json:"fileName"`
	MimeType   string     `json:"mimeType"`
	Source     string     `json:"source"`
	Transcript string     `json:"transcript,omitempty"`
	Status     string     `json:"status"`
	CreatedAt  time.Time  `json:"createdAt"`
	NoteLinks  []NoteLink `json:"noteLinks,omitempty"`
	// NoNotesReason is set only on a done job that created no note, to one of
	// the NoNotes* constants. Empty whenever a note was created.
	NoNotesReason string     `json:"noNotesReason,omitempty"`
	Error         string     `json:"error,omitempty"`
	FailedAt      *time.Time `json:"failedAt,omitempty"`
}

// JobKey implements Keyed.
func (j VoiceNoteJob) JobKey() string { return voiceNoteKey(j.UserID, j.UploadID) }

// OwnerID implements Keyed.
func (j VoiceNoteJob) OwnerID() string { return j.UserID }

// voiceNoteKey builds a job key from user ID and upload ID.
// Used by handlers that receive these values separately.
func voiceNoteKey(userID string, uploadID int64) string {
	return fmt.Sprintf("%s/%d", userID, uploadID)
}
