// spans.go turns the extraction model's segmentation of a transcript into
// per-student notes (#99). The model returns clause-index spans and a class
// name, never a student name; AssembleNotes validates the spans, pins the
// class, resolves each spoken label with MatchStudent and fans group spans
// out. It is pure: voice_note_process.go and eval-cli both call it, so the
// eval grades production, not a copy.
package handler

import (
	"errors"
	"fmt"
	"strings"
)

// SpanKind says what a span is about.
type SpanKind string

const (
	// SpanChild is the teacher talking about one child — or several at
	// once, when SpokenLabels holds more than one name.
	SpanChild SpanKind = "child"
	// SpanGroup is a statement about the class as a whole.
	SpanGroup SpanKind = "group"
	// SpanNone is not an observation: the header, a greeting, taught
	// vocabulary. Discarded.
	SpanNone SpanKind = "none"
)

// Span is one contiguous run of clauses, Start..End inclusive, 1-based
// into SplitClauses(transcript).
type Span struct {
	Start        int      `json:"start"`
	End          int      `json:"end"`
	Kind         SpanKind `json:"kind"`
	SpokenLabels []string `json:"spoken_labels"`
	Summary      string   `json:"summary"`
}

// SegmentResponse is the extraction model's structured output: spans that
// tile the clauses of the transcript, and the class the recording is about.
// ClassName is "" when the model could not identify exactly one class.
type SegmentResponse struct {
	Spans     []Span `json:"spans"`
	ClassName string `json:"class_name"`
}

// ErrSpanTiling is returned when the spans do not cover every clause exactly
// once, in order, or a span carries a kind this code does not know. The job
// fails and no notes are created — a repaired partition would be a guess
// about which child owns the missing clauses.
var ErrSpanTiling = errors.New("spans do not tile the transcript")

// AssembledNote is the note text for one student, keyed by canonical roster
// name and class name. The processor resolves the student ID with the
// existing exact FindByNameAndClass.
type AssembledNote struct {
	Name      string `json:"name"`
	ClassName string `json:"class_name"`
	// Text is each contributing span's summary, in transcript order,
	// falling back to the span's source clauses when the summary is blank.
	Text string `json:"text"`
}

// UnattributedSpan is a child or group span that produced no note. Source
// is the span's clauses, verbatim, so the teacher can assign it later.
type UnattributedSpan struct {
	Span   Span   `json:"span"`
	Source string `json:"source"`
}

// LabelMiss is a spoken label that resolved to nobody, with the span it
// came from. A multi-label span can produce a note and a miss at once.
type LabelMiss struct {
	Label string `json:"label"`
	Start int    `json:"start"`
	End   int    `json:"end"`
}

// AssembledNotes is the outcome of AssembleNotes.
type AssembledNotes struct {
	// ClassName is the pinned class, or "" when the model declined or named
	// a class not in the roster — then every span is unattributed.
	ClassName string `json:"class_name"`
	// UnknownClassName is the class the model named when the roster has no
	// such class ("" otherwise). Declining is expected; this is a schema or
	// prompt defect worth alerting on.
	UnknownClassName string             `json:"unknown_class_name,omitempty"`
	Notes            []AssembledNote    `json:"notes"`
	Unattributed     []UnattributedSpan `json:"unattributed"`
	// Misses is every child-span label that got no student — because it
	// failed to resolve, or because no class was pinned to resolve it in.
	Misses []LabelMiss `json:"misses"`
}

// AssembleNotes splits transcript, checks that resp.Spans tile the clauses,
// pins resp.ClassName to one of classes and resolves every child span's
// labels against that class's students only. Group spans fan out to every
// student who resolved from a child span in this transcript, and nobody
// else — an absent child must not get a note saying the class struggled.
// Returns ErrSpanTiling (wrapped) when the spans are not a tiling.
func AssembleNotes(transcript string, classes []ClassGroup, resp SegmentResponse) (*AssembledNotes, error) {
	clauses := SplitClauses(transcript)
	if err := validateTiling(resp.Spans, len(clauses)); err != nil {
		return nil, err
	}

	out := &AssembledNotes{}
	var students []ClassStudent
	pinned := false
	for _, c := range classes {
		if resp.ClassName != "" && c.Name == resp.ClassName {
			out.ClassName, students, pinned = c.Name, c.Students, true
			break
		}
	}
	if !pinned && resp.ClassName != "" {
		out.UnknownClassName = resp.ClassName
	}

	// Pass 1: resolve child spans, so group spans know who is present.
	resolved := make([][]string, len(resp.Spans)) // per span, canonical names
	var present []string                          // every student resolved, first-seen order
	seen := map[string]bool{}
	for i, sp := range resp.Spans {
		if sp.Kind != SpanChild {
			continue
		}
		for _, spoken := range sp.SpokenLabels {
			name, ok := "", false
			if pinned {
				name, ok = MatchStudent(spoken, students)
			}
			if !ok {
				out.Misses = append(out.Misses, LabelMiss{Label: spoken, Start: sp.Start, End: sp.End})
				continue
			}
			resolved[i] = appendUnique(resolved[i], name)
			if !seen[name] {
				seen[name] = true
				present = append(present, name)
			}
		}
	}

	// Pass 2: hand each span's text to its owners, in transcript order.
	texts := map[string][]string{}
	for i, sp := range resp.Spans {
		var owners []string
		switch sp.Kind {
		case SpanChild:
			owners = resolved[i]
		case SpanGroup:
			owners = present
		default: // SpanNone; anything else was rejected by validateTiling
			continue
		}
		if len(owners) == 0 {
			out.Unattributed = append(out.Unattributed, UnattributedSpan{Span: sp, Source: spanSource(clauses, sp)})
			continue
		}
		text := strings.TrimSpace(sp.Summary)
		if text == "" {
			text = spanSource(clauses, sp)
		}
		for _, name := range owners {
			texts[name] = append(texts[name], text)
		}
	}
	for _, name := range present {
		out.Notes = append(out.Notes, AssembledNote{
			Name:      name,
			ClassName: out.ClassName,
			Text:      strings.Join(texts[name], "\n\n"),
		})
	}
	return out, nil
}

// validateTiling checks that spans cover clauses 1..n exactly once, in
// order, and that every span has a known kind. Every failure the research
// found violates this; no correct output does. Reject, never repair: a span
// of unknown kind skipped silently would drop an observation without a
// trace, the very failure #99 exists to remove.
func validateTiling(spans []Span, n int) error {
	next := 1
	for i, sp := range spans {
		switch {
		case sp.Kind != SpanChild && sp.Kind != SpanGroup && sp.Kind != SpanNone:
			return fmt.Errorf("%w: span %d has unknown kind %q", ErrSpanTiling, i+1, sp.Kind)
		case sp.End < sp.Start:
			return fmt.Errorf("%w: span %d runs %d-%d, end before start", ErrSpanTiling, i+1, sp.Start, sp.End)
		case sp.Start < next:
			return fmt.Errorf("%w: span %d starts at %d, overlapping clause %d", ErrSpanTiling, i+1, sp.Start, next-1)
		case sp.Start > next:
			return fmt.Errorf("%w: span %d starts at %d, leaving clause %d uncovered", ErrSpanTiling, i+1, sp.Start, next)
		case sp.End > n:
			return fmt.Errorf("%w: span %d ends at %d, transcript has %d clauses", ErrSpanTiling, i+1, sp.End, n)
		}
		next = sp.End + 1
	}
	if next != n+1 {
		return fmt.Errorf("%w: spans end at clause %d, transcript has %d clauses", ErrSpanTiling, next-1, n)
	}
	return nil
}

func spanSource(clauses []string, sp Span) string {
	return strings.Join(clauses[sp.Start-1:sp.End], " ")
}

func appendUnique(names []string, name string) []string {
	for _, n := range names {
		if n == name {
			return names
		}
	}
	return append(names, name)
}
