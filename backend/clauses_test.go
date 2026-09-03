package handler

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// note694 is the production transcript behind #99: three children run
// together, the middle stretch all pronouns. The research spans (round 8/9)
// number its clauses 1..32, so the count below pins the splitter to what
// the model was measured against.
const note694 = "Wednesday, 1745. Linda, I don't know what to say. Yes, please. Thank you. " +
	"She was helping knock on boxes. She said up and down when she was putting Bunny up and down. " +
	"She also enjoyed the big book with the party balloons and the birthday cake. " +
	"She also loved the snail and the mouse for quickly and slowly. Polly wasn't speaking today. " +
	"She did say bye-bye at the end. She also really liked the snail and the mouse. " +
	"She was laughing and giggling. She also enjoyed the magnets, putting the party balloons where they belong. " +
	"In playing with a snail for quickly and slowly. Levy was a little active. " +
	"He said again, bye-bye, occasionally yes, please, thank you. " +
	"And he was repeating some of the colors, for example, red, blue, green, and yellow. " +
	"He also loved the snail and the mouse, especially the mouse when it went quickly."

// TestSplitClauses_Modes covers each split rule measured in research round
// 10 and each non-split the rules must leave alone.
func TestSplitClauses_Modes(t *testing.T) {
	cases := []struct {
		name string
		in   string
		want []string
	}{
		{"sentence end then space", "Polly was quiet. She said bye.",
			[]string{"Polly was quiet.", "She said bye."}},
		{"question and exclamation", "Did he sing? He did! Twice.",
			[]string{"Did he sing?", "He did!", "Twice."}},
		{"sentence end then capital, no space (Whisper)", "For what chores for Billy.Elise did good.",
			[]string{"For what chores for Billy.", "Elise did good."}},
		{"sentence end then accented capital", "Well done.Élise sang.",
			[]string{"Well done.", "Élise sang."}},
		{"comma then space", "Dinara was a handful today, Gatien was doing good, Harry played with the toys.",
			[]string{"Dinara was a handful today,", "Gatien was doing good,", "Harry played with the toys."}},
		{"semicolon then space", "Vasco counted; Matthew did not.",
			[]string{"Vasco counted;", "Matthew did not."}},
		{"decimal time is one clause", "Wednesday 17.45 was fine.",
			[]string{"Wednesday 17.45 was fine."}},
		{"period then lowercase, no space, is one clause", "For what chores for Billy.elise did good.",
			[]string{"For what chores for Billy.elise did good."}},
		{"bare comma is one clause", "He counted to 1,000 today.",
			[]string{"He counted to 1,000 today."}},
		{"comma at end of text is one clause", "He counted,",
			[]string{"He counted,"}},
		{"newline counts as whitespace", "Yes.\nNo,\nmaybe.",
			[]string{"Yes.", "No,", "maybe."}},
		{"whitespace before a comma is trimmed", "today , she sang.",
			[]string{"today ,", "she sang."}},
		{"consecutive punctuation splits once", "Really?! Yes... Sure.",
			[]string{"Really?!", "Yes...", "Sure."}},
		{"filler over-splits harmlessly", "Oh, um, yes.",
			[]string{"Oh,", "um,", "yes."}},
		{"leading and trailing whitespace dropped", "  Hugo sang.  ",
			[]string{"Hugo sang."}},
		{"empty", "", nil},
		{"whitespace only", " \n\t ", nil},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			assert.Equal(t, tc.want, SplitClauses(tc.in))
		})
	}
}

// TestSplitClauses_MultiNameClausesStayWhole pins the four corpus clauses
// that name two children with no punctuation between them: the splitter
// cannot separate them, and spoken_labels as a list is what covers them.
func TestSplitClauses_MultiNameClausesStayWhole(t *testing.T) {
	for _, s := range []string{
		"Oscar and Leo are able to count one to ten.",
		"Vasco and Matthew were able to count one to five with me.",
		"Vasco and Matthew have some issues sitting in place again with their cushions.",
		"Clemence was the same as Louis.",
	} {
		assert.Equal(t, []string{s}, SplitClauses(s), s)
	}
}

// TestSplitClauses_Note694 pins the production transcript to the 32 clauses
// the research spans index, with the clauses at each span boundary.
func TestSplitClauses_Note694(t *testing.T) {
	got := SplitClauses(note694)
	require.Len(t, got, 32)
	assert.Equal(t, "Wednesday,", got[0])
	assert.Equal(t, "1745.", got[1])
	assert.Equal(t, "Thank you.", got[6])
	assert.Equal(t, "She was helping knock on boxes.", got[7])
	assert.Equal(t, "Polly wasn't speaking today.", got[11])
	assert.Equal(t, "Levy was a little active.", got[18])
	assert.Equal(t, "especially the mouse when it went quickly.", got[31])
	// Every character of the transcript survives, in order — only whitespace
	// at clause edges is dropped.
	assert.Equal(t, strings.Join(strings.Fields(note694), " "), strings.Join(got, " "))
}
