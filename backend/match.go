// match.go resolves a spoken label ("Levy", "Zachariah", "As a Xand") to a
// student in one class (#99). The extraction model never sees the roster —
// shown student names it re-cuts the transcript to fit them — so this is the
// only place a name is resolved, and it is pure so eval-cli can feed it
// fixture rosters.
//
// Resolution order, measured in research rounds 5 and 9:
//
//  1. Exact match on a folded name or alias wins outright: no threshold, no
//     margin. An alias is the teacher's override and must never lose to a
//     heuristic. Two students sharing the string is a real tie → nobody.
//  2. Otherwise normalised Levenshtein over every name and alias, a
//     student's score being the best of their strings. Three gates, all
//     required: the label is not a pronoun; score >= 0.50; margin >= 0.15
//     over the best score of a *different* student.
//
// Breaking a tie by roster order would reproduce the root cause inside Go.
package handler

import (
	"strings"
	"unicode"

	"golang.org/x/text/unicode/norm"
)

const (
	// matchThreshold admits Colm → Côme (0.50) and rejects Polly →
	// Leopoldine (0.30), Her (0.25), Rio → Brieu (0.40).
	matchThreshold = 0.50
	// matchMargin rejects Alicia (ties Amalia / Alyssa at 0.50) and Alia
	// (Alina 0.80 over Alya 0.75).
	matchMargin = 0.15
)

// labelStopList holds folded labels that are never a name: the pronouns the
// teacher falls back on when a child is not named, plus the collective
// referents a mislabelled group span might carry. Checked before any fuzzy
// score — `They` scores 0.75 against `Théo` with a 0.75 margin.
var labelStopList = map[string]bool{
	"he": true, "him": true, "his": true,
	"she": true, "her": true, "hers": true,
	"they": true, "them": true, "their": true, "theirs": true,
	"it": true, "its": true,
	"i": true, "me": true, "my": true, "mine": true,
	"we": true, "us": true, "our": true, "ours": true,
	"you": true, "your": true, "yours": true,
	"this": true, "that": true, "these": true, "those": true,
	"who": true, "someone": true, "somebody": true, "anyone": true, "anybody": true,
	"everyone": true, "everybody": true, "nobody": true, "noone": true,
	"all": true, "both": true, "one": true,
}

// MatchStudent resolves label against the students of one class and returns
// the canonical roster name, or "" and false when nobody resolves. The
// caller must scope students to the pinned class: against the whole roster
// a level name like `Linda` outscores every true positive.
func MatchStudent(label string, students []ClassStudent) (string, bool) {
	key := foldName(label)
	if key == "" {
		return "", false
	}

	exact := ""
	for _, s := range students {
		if hasExactString(s, key) {
			if exact != "" {
				return "", false // two students share the name or alias
			}
			exact = s.Name
		}
	}
	if exact != "" {
		return exact, true
	}

	if labelStopList[key] {
		return "", false
	}

	best, runnerUp, bestName := 0.0, 0.0, ""
	for _, s := range students {
		score := bestScore(s, key)
		switch {
		case score > best:
			runnerUp, best, bestName = best, score, s.Name
		case score > runnerUp:
			runnerUp = score
		}
	}
	if best < matchThreshold || best-runnerUp < matchMargin {
		return "", false
	}
	return bestName, true
}

func hasExactString(s ClassStudent, key string) bool {
	if foldName(s.Name) == key {
		return true
	}
	for _, a := range s.Aliases {
		if foldName(a) == key {
			return true
		}
	}
	return false
}

// bestScore is the student's best similarity over their name and aliases.
// A student's own second string never counts against them: the margin is
// taken between students, not between strings.
func bestScore(s ClassStudent, key string) float64 {
	best := similarity(key, foldName(s.Name))
	for _, a := range s.Aliases {
		if sc := similarity(key, foldName(a)); sc > best {
			best = sc
		}
	}
	return best
}

// foldName lowercases, strips accents and drops everything that is not a
// letter or digit, so `Lévi` → `levi` and `As a Xand` → `asaxand`.
func foldName(s string) string {
	var b strings.Builder
	for _, r := range norm.NFD.String(strings.ToLower(s)) {
		if unicode.IsLetter(r) || unicode.IsDigit(r) {
			b.WriteRune(r)
		}
	}
	return b.String()
}

// similarity is normalised Levenshtein: 1 − distance / longer length, so
// identical strings score 1 and strings sharing nothing score 0.
func similarity(a, b string) float64 {
	ra, rb := []rune(a), []rune(b)
	longest := max(len(ra), len(rb))
	if longest == 0 {
		return 0
	}
	return 1 - float64(levenshtein(ra, rb))/float64(longest)
}

func levenshtein(a, b []rune) int {
	prev := make([]int, len(b)+1)
	cur := make([]int, len(b)+1)
	for j := range prev {
		prev[j] = j
	}
	for i := 1; i <= len(a); i++ {
		cur[0] = i
		for j := 1; j <= len(b); j++ {
			cost := 1
			if a[i-1] == b[j-1] {
				cost = 0
			}
			cur[j] = min(prev[j]+1, cur[j-1]+1, prev[j-1]+cost)
		}
		prev, cur = cur, prev
	}
	return prev[len(b)]
}
