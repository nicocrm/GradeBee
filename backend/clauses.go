// clauses.go splits a transcript into the numbered clauses the extraction
// model segments into spans (#99). The same split is run once to build the
// prompt and once to recover a span's source text, so it must be pure and
// deterministic; nothing is stored.
//
// The rule was measured over 54 transcripts / 1156 clauses (research round
// 10). Split points, in order of precedence:
//
//   - `.`, `!` or `?` followed by whitespace
//   - `.`, `!` or `?` followed directly by an upper-case letter — Whisper
//     emits "Billy.Elise did good" with no space
//   - `,` or `;` followed by whitespace
//
// A bare comma (`1,000`) and a period followed by a digit or lower-case
// letter (`17.45`, `e.g. the`) never split. Over-splitting is harmless — a
// child's block simply spans more clauses — while under-splitting is fatal,
// because two children sharing one clause can never be separated.
package handler

import (
	"strings"
	"unicode"
)

// SplitClauses splits transcript into clauses. Each clause keeps its own
// terminal punctuation and is trimmed of surrounding whitespace; empty
// clauses are dropped. Returns nil for a blank transcript.
func SplitClauses(transcript string) []string {
	runes := []rune(transcript)
	var clauses []string
	start := 0
	flush := func(end int) {
		if c := strings.TrimSpace(string(runes[start:end])); c != "" {
			clauses = append(clauses, c)
		}
		start = end
	}
	for i, r := range runes {
		next, hasNext := rune(0), i+1 < len(runes)
		if hasNext {
			next = runes[i+1]
		}
		switch {
		case isSentenceEnd(r) && hasNext && (unicode.IsSpace(next) || unicode.IsUpper(next)):
			flush(i + 1)
		case (r == ',' || r == ';') && hasNext && unicode.IsSpace(next):
			flush(i + 1)
		}
	}
	flush(len(runes))
	return clauses
}

func isSentenceEnd(r rune) bool {
	return r == '.' || r == '!' || r == '?'
}
