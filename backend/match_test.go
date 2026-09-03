package handler

import (
	"testing"

	"github.com/stretchr/testify/assert"
)

func students(names ...string) []ClassStudent {
	out := make([]ClassStudent, len(names))
	for i, n := range names {
		out[i] = ClassStudent{Name: n}
	}
	return out
}

func aliased(name string, aliases ...string) ClassStudent {
	return ClassStudent{Name: name, Aliases: aliases}
}

func TestFoldName(t *testing.T) {
	cases := map[string]string{
		"Lévi":                 "levi",
		"Eléonore":             "eleonore",
		"Anaïs":                "anais",
		"As a Xand":            "asaxand",
		"O'Brien":              "obrien",
		"  Zack  ":             "zack",
		"Jean-Luc":             "jeanluc",
		"CLÉMENCE":             "clemence",
		"1745":                 "1745",
		"":                     "",
		" - ":                  "",
		"Ben & Brenda · Larry": "benbrendalarry",
	}
	for in, want := range cases {
		assert.Equal(t, want, foldName(in), "%q", in)
	}
}

func TestSimilarity(t *testing.T) {
	cases := []struct {
		a, b string
		want float64
	}{
		{"levi", "levi", 1.0},
		{"levy", "levi", 0.75},
		{"zachariah", "zakaria", 1 - 3.0/9},
		{"colm", "come", 0.5},
		{"", "come", 0.0},
		{"", "", 0.0},
		{"abc", "xyz", 0.0},
	}
	for _, tc := range cases {
		assert.InDelta(t, tc.want, similarity(tc.a, tc.b), 1e-9, "%q vs %q", tc.a, tc.b)
	}
}

// Rosters as of the research rounds, first names only. Two classes share
// a level name and a weekday, which is why the matcher takes one class's
// students rather than the roster. "Oliver · Thu" is reconstructed from the
// research scores (Louis → Luis 0.80, Ryan → Rayan 0.80).
var (
	rosterLindaSat0855 = students("Brianna", "Elisabeth", "Nathan")
	rosterLindaSat1005 = students("Aline", "Côme", "George", "Jules")
	rosterLindaWed1315 = students("Matthew", "Vasco")
	rosterLindaWed1745 = students("Eléonore", "Leopoldine", "Lévi")
	rosterMousySat1115 = students("Marceline")
	rosterMousySat1225 = students("Aria")
	rosterMousyThu1715 = students("Nazireah")
	rosterOliverThu    = students("Dinara", "Gatien", "Harry", "Luis", "Rayan")
	rosterPPFri1740    = students("Alina", "Alya", "Anaïs", "Charline", "Louise", "Mariam", "Maya", "Romane")
	rosterPPWed1410    = students("Amalia", "Elise", "Eléonore", "Inaya", "Jules", "Manoa", "Rebecca", "Zakaria")
	rosterPPWed1520    = students("Aurore", "Edith", "Gauthier", "Hugo", "Jules", "Luca", "Lyam", "Naomie")
	rosterPPWed1630    = []ClassStudent{
		{Name: "Alexandre"}, aliased("Alyssa", "Alicia"), {Name: "Amalia"},
		{Name: "Clémence"}, {Name: "James"}, {Name: "Louis"}, {Name: "Zack"},
	}
	rosterSamFri1630 = []ClassStudent{
		aliased("Brieu", "Rio"), {Name: "Clémence"}, {Name: "Giulia"}, {Name: "Hortense"}, {Name: "Manoe"},
	}
)

type matchCase struct {
	label string
	class []ClassStudent
	want  string // "" = nobody
}

// TestMatchStudent_Corpus pins every (label, class) pair the segmentation
// model returned over the 22-transcript corpus (research round 9), matched
// within the class the model pinned. `Asa` is tested on its own below.
func TestMatchStudent_Corpus(t *testing.T) {
	cases := []matchCase{
		{"Brianna", rosterLindaSat0855, "Brianna"},
		{"Elizabeth", rosterLindaSat0855, "Elisabeth"}, // 0.89
		{"Nathan", rosterLindaSat0855, "Nathan"},

		{"Aline", rosterLindaSat1005, "Aline"},
		{"Colm", rosterLindaSat1005, "Côme"}, // 0.50, exactly at threshold; runner-up 0.20
		{"George", rosterLindaSat1005, "George"},
		{"Jules", rosterLindaSat1005, "Jules"},

		{"Matthew", rosterLindaWed1315, "Matthew"},
		{"Vasco", rosterLindaWed1315, "Vasco"},

		{"Levy", rosterLindaWed1745, "Lévi"}, // 0.75
		{"Polly", rosterLindaWed1745, ""},    // Leopoldine 0.30, below threshold
		{"She", rosterLindaWed1745, ""},      // stop-list

		{"Marceline", rosterMousySat1115, "Marceline"},
		{"Aria", rosterMousySat1225, "Aria"},
		{"She", rosterMousySat1225, ""},
		{"Nazaria", rosterMousyThu1715, "Nazireah"}, // 0.62, sole student

		{"Dinara", rosterOliverThu, "Dinara"},
		{"Gatien", rosterOliverThu, "Gatien"},
		{"Harry", rosterOliverThu, "Harry"},
		{"Louis", rosterOliverThu, "Luis"}, // 0.80
		{"Ryan", rosterOliverThu, "Rayan"}, // 0.80

		{"Alia", rosterPPFri1740, ""}, // Alina 0.80 over Alya 0.75: margin 0.05
		{"Alina", rosterPPFri1740, "Alina"},
		{"Anais", rosterPPFri1740, "Anaïs"}, // exact after fold
		{"Charlene", rosterPPFri1740, "Charline"},
		{"Louise", rosterPPFri1740, "Louise"},
		{"Maya", rosterPPFri1740, "Maya"},
		{"Miriam", rosterPPFri1740, "Mariam"},
		{"Ramal", rosterPPFri1740, ""}, // Romane 0.50 over Maya 0.40: margin 0.10

		{"Amelia", rosterPPWed1410, "Amalia"},
		{"Anaya", rosterPPWed1410, "Inaya"},      // 0.80, Amalia 0.50
		{"Eleanor", rosterPPWed1410, "Eléonore"}, // 0.75
		{"Elise", rosterPPWed1410, "Elise"},
		{"Jules", rosterPPWed1410, "Jules"},
		{"Manoa", rosterPPWed1410, "Manoa"},
		{"Rebecca", rosterPPWed1410, "Rebecca"},
		{"Zachariah", rosterPPWed1410, "Zakaria"}, // 0.67, Amalia 0.44

		{"Aurora", rosterPPWed1520, "Aurore"},
		{"Aurore", rosterPPWed1520, "Aurore"},
		{"Edith", rosterPPWed1520, "Edith"},
		{"Gautier", rosterPPWed1520, "Gauthier"},
		{"Hugo", rosterPPWed1520, "Hugo"},
		{"Jules", rosterPPWed1520, "Jules"},
		{"Liam", rosterPPWed1520, "Lyam"}, // 0.75, Luca 0.25
		{"Luca", rosterPPWed1520, "Luca"},
		{"Naomi", rosterPPWed1520, "Naomie"},

		{"Alexandre", rosterPPWed1630, "Alexandre"},
		{"Alicia", rosterPPWed1630, "Alyssa"}, // alias, exact
		{"Clemence", rosterPPWed1630, "Clémence"},
		{"Clements", rosterPPWed1630, "Clémence"}, // 0.75
		{"James", rosterPPWed1630, "James"},
		{"Louis", rosterPPWed1630, "Louis"},
		{"Malia", rosterPPWed1630, "Amalia"}, // 0.83, Alyssa 0.50
		{"Zach", rosterPPWed1630, "Zack"},    // 0.75

		{"Clemence", rosterSamFri1630, "Clémence"},
		{"Her", rosterSamFri1630, ""},         // stop-list; Hortense 0.25 anyway
		{"Julia", rosterSamFri1630, "Giulia"}, // 0.67
		{"Meno", rosterSamFri1630, "Manoe"},   // 0.60, Clémence 0.38
		{"Rio", rosterSamFri1630, "Brieu"},    // alias, exact; fuzzy would be 0.40
	}
	assert.Len(t, cases, 59)
	runMatchCases(t, cases)
}

func runMatchCases(t *testing.T, cases []matchCase) {
	t.Helper()
	for _, tc := range cases {
		got, ok := MatchStudent(tc.label, tc.class)
		assert.Equal(t, tc.want, got, "label %q", tc.label)
		assert.Equal(t, tc.want != "", ok, "label %q ok", tc.label)
	}
}

// TestMatchStudent_VerbatimLabelBeatsTidiedLabel: the model once returned
// `Asa` for the spoken "As a Xand". Verbatim, it reaches Alexandre; tidied,
// it lands on Alyssa at 0.50 with a 0.17 margin — the accepted false
// positive of threshold 0.50 (plan decision 1), guarded by the prompt's
// verbatim-label rule rather than by the matcher. Pinned so a threshold
// change surfaces it deliberately.
func TestMatchStudent_VerbatimLabelBeatsTidiedLabel(t *testing.T) {
	runMatchCases(t, []matchCase{
		{"As a Xand", rosterPPWed1630, "Alexandre"},
		{"Asa", rosterPPWed1630, "Alyssa"},
	})
}

// TestMatchStudent_Gates exercises each gate on its own: threshold, margin,
// stop-list, and the exact short-circuit that bypasses all three.
func TestMatchStudent_Gates(t *testing.T) {
	runMatchCases(t, []matchCase{
		// Alicia ties Amalia and Alyssa at 0.50 with no alias to break it.
		{"Alicia", students("Alexandre", "Alyssa", "Amalia"), ""},
		// The same label resolves outright once the teacher adds the alias,
		// even though Amalia at 0.50 would fail the margin on the fuzzy path.
		{"Alicia", []ClassStudent{{Name: "Alexandre"}, aliased("Alyssa", "Alicia"), {Name: "Amalia"}}, "Alyssa"},
		// Alias, exact: fuzzy alone rejects Rio → Brieu at 0.40.
		{"Rio", students("Brieu", "Clémence"), ""},
		{"Rio", []ClassStudent{aliased("Brieu", "Rio"), {Name: "Clémence"}}, "Brieu"},
		// Near-misses of an alias go through the fuzzy path over the alias.
		{"Ryo", []ClassStudent{aliased("Brieu", "Rio"), {Name: "Clémence"}, {Name: "Giulia"}}, "Brieu"},
		{"Alycia", []ClassStudent{{Name: "Alexandre"}, aliased("Alyssa", "Alicia"), {Name: "Amalia"}}, "Alyssa"},
		// A student's own second string never counts as the runner-up.
		{"Alycia", []ClassStudent{aliased("Alyssa", "Alicia", "Alycja")}, "Alyssa"},
		// Stop-list beats a score that passes both other gates: They → Théo
		// is 0.75 with a 0.75 margin.
		{"They", students("Théo"), ""},
		{"they", students("Théo"), ""},
		{"THEY", students("Théo"), ""},
		{"He", students("Hector"), ""},
		{"everyone", students("Evelyn"), ""},
		// Case and accents never matter.
		{"levi", students("Lévi"), "Lévi"},
		{"LÉVI", students("Lévi"), "Lévi"},
		// Nothing to match.
		{"", students("Lévi"), ""},
		{" - ", students("Lévi"), ""},
		{"Lévi", nil, ""},
		{"Lévi", students(), ""},
	})
}

// TestMatchStudent_SharedStringIsATie: two students sharing a name or an
// alias in one class resolve to nobody, on the exact path and on the fuzzy
// path alike. Breaking the tie by roster order would be the bug (#99) again.
func TestMatchStudent_SharedStringIsATie(t *testing.T) {
	runMatchCases(t, []matchCase{
		{"Jules", students("Jules", "Jules"), ""},
		{"Jules", students("Jules", "Hugo"), "Jules"}, // same label, no tie
		{"Ali", []ClassStudent{aliased("Alyssa", "Ali"), aliased("Amalia", "Ali")}, ""},
		{"Ali", []ClassStudent{aliased("Alyssa", "Ali"), {Name: "Amalia"}}, "Alyssa"},
		// One student's alias equals another student's name.
		{"Amalia", []ClassStudent{aliased("Alyssa", "Amalia"), {Name: "Amalia"}}, ""},
		// Fuzzy path: the two exact twins score the same, so margin is 0.
		{"Jule", students("Jules", "Jules"), ""},
		{"Jule", students("Jules", "Hugo"), "Jules"},
	})
}
