// llm_live_test.go holds every test that calls a real LLM provider. Each
// skips itself via requireLiveLLM when the active provider's API key is
// unset, so `make test` is safe without credentials and exercises them
// automatically when a key is present.
//
// Every test here runs the production path whole: the model segments
// (Extract), Go resolves (AssembleNotes), and the assertion is on the notes a
// teacher would actually see. Asserting on the raw segmentation instead would
// grade a shape no teacher reads (#99).
package handler

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// requireLiveLLM skips the test if the active LLM provider's API key is unset.
// It returns the configured provider for live tests that need it.
func requireLiveLLM(t *testing.T) LLMProvider {
	t.Helper()
	p, err := LoadProvider()
	if err != nil {
		t.Skipf("LLM provider not configured: %v", err)
	}
	return p
}

// newTestLLMExtractor creates an LLM extractor, skipping if the active provider's API key is not set.
func newTestLLMExtractor(t *testing.T) Extractor {
	t.Helper()
	provider := requireLiveLLM(t)
	return newLLMExtractor(provider)
}

// liveNotes runs transcript through the live model and then through
// AssembleNotes, exactly as voice_note_process.go does. A tiling rejection
// fails the test with the spans that caused it — in production it fails the
// job, so it is never an acceptable outcome here either.
func liveNotes(t *testing.T, transcript string, classes []ClassGroup) *AssembledNotes {
	t.Helper()
	ext := newTestLLMExtractor(t)

	resp, err := ext.Extract(t.Context(), ExtractRequest{Transcript: transcript, Classes: classes})
	require.NoError(t, err)

	got, err := AssembleNotes(transcript, classes, *resp)
	require.NoError(t, err, "spans: %+v", resp.Spans)
	return got
}

// noteFor returns the note assembled for name, failing the test when there is
// none. It reports every note it did find, so a failure names the shape that
// arrived rather than just the one that did not.
func noteFor(t *testing.T, got *AssembledNotes, name string) AssembledNote {
	t.Helper()
	for _, n := range got.Notes {
		if n.Name == name {
			return n
		}
	}
	t.Fatalf("no note for %q; got %v in class %q", name, noteNames(got), got.ClassName)
	return AssembledNote{}
}

func noteNames(got *AssembledNotes) []string {
	names := make([]string, len(got.Notes))
	for i, n := range got.Notes {
		names[i] = n.Name
	}
	return names
}

func TestLLM_SingleStudentCorrectClass(t *testing.T) {
	classes := []ClassGroup{
		{Name: "Math 101", Students: []ClassStudent{{Name: "Alice"}, {Name: "Bob"}}},
		{Name: "Science 202", Students: []ClassStudent{{Name: "Charlie"}, {Name: "Diana"}}},
	}

	got := liveNotes(t, "Alice demonstrated excellent problem-solving skills on today's algebra quiz. She scored 95% and helped her classmates understand the quadratic formula.", classes)

	assert.Equal(t, "Math 101", got.ClassName)
	assert.Equal(t, []string{"Alice"}, noteNames(got))
}

// TestLLM_MultiClassTranscriptSplitsCleanly pins a consequence of the #99
// design: Go resolves names within exactly one class, so a recording covering
// two classes yields notes for at most one of them.
//
// What the model does with the class is not asserted. It is asked to decline
// and usually does, but it sometimes pins the class the transcript names first
// — which is not a defect: that class's notes are right and the other class
// gets none. The decline path itself is covered deterministically by
// TestAssembleNotes_NoClassPinned (#105). What is asserted here is the
// invariant that holds either way, and the one a teacher would notice broken:
// no note may carry the other class's observation.
func TestLLM_MultiClassTranscriptSplitsCleanly(t *testing.T) {
	classes := []ClassGroup{
		{Name: "Math 101", Students: []ClassStudent{{Name: "Alice"}, {Name: "Bob"}}},
		{Name: "Science 202", Students: []ClassStudent{{Name: "Diana"}, {Name: "Evan"}}},
	}
	// One marker phrase per class, unique to that class's half of the recording.
	elsewhere := map[string][]string{
		"Math 101":    {"chemistry", "lab notes"},
		"Science 202": {"fractions", "on the board"},
	}

	got := liveNotes(t, "Today I observed two students. In Math 101, Bob was very engaged during the fractions lesson and volunteered to solve problems on the board. In Science 202, Diana conducted her chemistry experiment carefully and wrote detailed lab notes.", classes)

	require.Contains(t, []string{"", "Math 101", "Science 202"}, got.ClassName)
	if got.ClassName == "" {
		assert.Empty(t, noteNames(got), "no class pinned, so no name can resolve")
		assert.NotEmpty(t, got.Unattributed, "the observations must survive as unattributed spans")
		return
	}
	for _, n := range got.Notes {
		assert.Equal(t, got.ClassName, n.ClassName, "a note may only belong to the pinned class")
		for _, phrase := range elsewhere[got.ClassName] {
			assert.NotContains(t, n.Text, phrase,
				"%s's note carries an observation from the other class", n.Name)
		}
	}
}

// TestLLM_UnknownClassSkipped covers a recording about a class the teacher
// does not have. class_name is an enum of the real names plus "", so the model
// cannot invent one; the honest answer is the decline, and nobody resolves.
func TestLLM_UnknownClassSkipped(t *testing.T) {
	classes := []ClassGroup{
		{Name: "Math 101", Students: []ClassStudent{{Name: "Alice"}, {Name: "Bob"}}},
		{Name: "Science 202", Students: []ClassStudent{{Name: "Charlie"}}},
	}

	got := liveNotes(t, "Report card for Tommy Wilson, Art 303. Tommy shows great creativity in his paintings and participates actively in class discussions about art history.", classes)

	assert.Empty(t, got.UnknownClassName, "the schema enum must make an invented class impossible")
	assert.Empty(t, noteNames(got))
}

// TestLLM_PartialNameMatch covers a nickname truncated at the end (Alex for
// Alexander). What the live model owes here is the label verbatim: it never
// sees the roster, so "Alex Hamilton" must come back as spoken — a tidied
// "Alexander Hamilton" would be invented. Go's matcher does the rest.
//
// The transcript opens by naming the class, as a real recording does. Without
// that the model has nothing to pin on — an essay on democracy fits English and
// History alike — and correctly declines, which is a separate behaviour covered
// by TestLLM_MultiClassTranscriptSplitsCleanly.
func TestLLM_PartialNameMatch(t *testing.T) {
	classes := []ClassGroup{
		{Name: "English 101", Students: []ClassStudent{{Name: "Alexander Hamilton"}, {Name: "Elizabeth Bennet"}}},
		{Name: "History 201", Students: []ClassStudent{{Name: "Theodore Roosevelt"}}},
	}

	got := liveNotes(t, "English 101. Alex Hamilton wrote an outstanding essay on democracy today. His arguments were well-structured and his writing has improved significantly this semester.", classes)

	assert.Equal(t, "English 101", got.ClassName)
	noteFor(t, got, "Alexander Hamilton")
}

// TestLLM_TruncatedNameMatch covers a transcription dropping a leading
// substring of a name (Malia for Amalia), as distinct from
// TestLLM_PartialNameMatch's trailing-truncated nickname.
func TestLLM_TruncatedNameMatch(t *testing.T) {
	classes := []ClassGroup{
		{Name: "English 101", Students: []ClassStudent{{Name: "Amalia"}, {Name: "Elizabeth"}}},
		{Name: "History 201", Students: []ClassStudent{{Name: "Theodore"}}},
	}

	got := liveNotes(t, "English 101. Malia gave a fantastic presentation on the water cycle today. She answered every follow-up question with confidence.", classes)

	assert.Equal(t, "English 101", got.ClassName)
	noteFor(t, got, "Amalia")
}

// TestExtractPreservesTeacherVoice verifies that a note keeps the teacher's
// own language and emotion. The note text is now the span summary, so the
// preservation rule lives in the segmentation prompt: cleaning up speech
// artifacts must not become rewriting.
func TestExtractPreservesTeacherVoice(t *testing.T) {
	// The transcript opens by naming the class, as every real recording does: with
	// no spoken header the model declines and no note is created at all.
	transcript := `Period 3, Thursday. Maxence was impossibly bad today. I'm ready to choke the living
sh*t out of him. He wouldn't stop talking during the lesson.
Amara was great - very attentive and helpful to other students.`

	got := liveNotes(t, transcript, []ClassGroup{
		{Name: "Period 3", Students: []ClassStudent{{Name: "Maxence"}, {Name: "Amara"}}},
	})

	assert.ElementsMatch(t, []string{"Maxence", "Amara"}, noteNames(got))
	assert.Contains(t, noteFor(t, got, "Maxence").Text, "impossibly bad",
		"note does not preserve the teacher's original phrasing")
}

// TestExtractGroupObservations verifies that a group span reaches every child
// who resolved from a child span — and nobody else. Lisa is on the roster but
// never named, so a note saying the class was loud must not reach her.
func TestExtractGroupObservations(t *testing.T) {
	transcript := `Period 1. Today the class was way too loud and unfocused. Everyone was talking over each other.
Specific note: Tommy helped me organize the materials, which was great.`

	got := liveNotes(t, transcript, []ClassGroup{
		{Name: "Period 1", Students: []ClassStudent{{Name: "Tommy"}, {Name: "Lisa"}}},
	})

	require.Equal(t, []string{"Tommy"}, noteNames(got), "only the named child gets a note")
	tommy := noteFor(t, got, "Tommy")
	assert.Contains(t, tommy.Text, "organize", "missing Tommy's own observation")
	assert.True(t,
		containsAny(tommy.Text, "too loud", "unfocused", "talking over"),
		"missing the group observation. Got: %s", tommy.Text)
}

// TestExtractNoCrossStudentBleed verifies that an observation about one named
// child never lands in another named child's note. Production regression:
// "Harry was doing great, but today Dinara was not doing that good" produced
// the full transcript under both names.
//
// This is deliberately the smallest transcript that shows the bug — two
// children, one assertion each way. Wider shapes are covered by the
// cross_student_bleed and pronoun_run_bleed eval fixtures, which are graded
// rather than gated.
func TestExtractNoCrossStudentBleed(t *testing.T) {
	// No collective referent anywhere, so the two halves must not be shared.
	transcript := "Oliver Thursday. Harry was doing great, but today Dinara was not doing that good."

	got := liveNotes(t, transcript, []ClassGroup{
		{Name: "Oliver · Thu", Students: []ClassStudent{{Name: "Dinara"}, {Name: "Harry"}}},
	})

	harry := noteFor(t, got, "Harry")
	assert.Contains(t, harry.Text, "doing great", "missing Harry's own observation")
	assert.NotContains(t, harry.Text, "Dinara", "Harry's note leaked Dinara's observation")

	dinara := noteFor(t, got, "Dinara")
	assert.Contains(t, dinara.Text, "not doing that good", "missing Dinara's own observation")
	assert.NotContains(t, dinara.Text, "Harry", "Dinara's note leaked Harry's observation")
}

// TestExtractGroupObservationScopedToPinnedClass verifies that a group
// observation stays inside the class the recording is about. Go scopes it
// structurally — the group span fans out only to children resolved within the
// pinned class — so this checks the model pins the class the transcript names
// rather than the other one on the roster.
func TestExtractGroupObservationScopedToPinnedClass(t *testing.T) {
	transcript := `Period 1 notes: Tommy was great today, really focused. The whole class was loud though.`

	got := liveNotes(t, transcript, []ClassGroup{
		{Name: "Period 1", Students: []ClassStudent{{Name: "Tommy"}, {Name: "Lisa"}}},
		{Name: "Period 2", Students: []ClassStudent{{Name: "Sarah"}, {Name: "Jake"}}},
	})

	require.Equal(t, "Period 1", got.ClassName)
	require.Equal(t, []string{"Tommy"}, noteNames(got),
		"only Tommy is named; Lisa, Sarah and Jake must get nothing")
	assert.Contains(t, noteFor(t, got, "Tommy").Text, "loud",
		"Tommy should carry Period 1's group observation")
}

// containsAny reports whether s contains any of subs. The live model is free
// to pick which of several equivalent phrases it keeps.
func containsAny(s string, subs ...string) bool {
	for _, sub := range subs {
		if strings.Contains(s, sub) {
			return true
		}
	}
	return false
}
