package handler

import (
	"encoding/json"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
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
		"Arthur 1":             "arthur1",
		"Arthur 1.":            "arthur1",
		"Arthur one":           "arthurone", // not folded: Voxtral writes digits
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
		{"one", students("Oney", "Arthur 1"), ""},
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

// TestMatchStudent_FullNameRoster: a teacher says the first name; four
// production students and every full name added from now on are `First
// Last`. Whole-name scoring gave Emma → Emma Torres 0.40 and no note at all
// (#111), so each whitespace part of the roster name is a string of its own:
// exact after the typed strings, fuzzy alongside them. The tie rule is
// unchanged: two children sharing a first name in one class resolve to
// nobody.
func TestMatchStudent_FullNameRoster(t *testing.T) {
	classA := students("Emma Torres", "Ryan Mitchell", "Lila Patel")
	runMatchCases(t, []matchCase{
		{"Emma", classA, "Emma Torres"},
		{"Ryan", classA, "Ryan Mitchell"},
		{"Noah", students("Noah Jensen", "Mia Clark"), "Noah Jensen"},
		{"Olivia", students("Olivia Chen", "Marcus Davis", "Zoe Taylor"), "Olivia Chen"},
		// The whole name and a surname alone still reach the child.
		{"Emma Torres", classA, "Emma Torres"},
		{"Torres", classA, "Emma Torres"},
		// A middle part counts too.
		{"Rose", students("Anna Rose Lee", "Tom"), "Anna Rose Lee"},
		// Fuzzy path over a part: Emme → emma 0.75, Ryan Mitchell's best 0.17.
		{"Emme", classA, "Emma Torres"},
		// A part is exact, so it wins outright: fuzzy alone would give
		// Isabelle Brown 1.0 over Isabella 0.875, under the margin.
		{"Isabelle", students("Isabelle Brown", "Isabella"), "Isabelle Brown"},
		// Ties: two full names sharing a first name, on both paths.
		{"Emma", students("Emma Torres", "Emma Wilson"), ""},
		{"Emme", students("Emma Torres", "Emma Wilson"), ""},
		{"Emma", students("Emma Torres", "Emma Wilson", "Ryan Mitchell"), ""},
		// A shared surname is a tie the same way.
		{"Torres", students("Emma Torres", "Luis Torres"), ""},
		// Typed strings come first: a whole name or an alias equal to the
		// label beats a part derived from another child's name, so the
		// teacher can break a first-name tie with an alias.
		{"Emma", students("Emma", "Emma Torres"), "Emma"},
		{"Morgan", students("Jack Morgan", "Morgan"), "Morgan"},
		{"Emma", []ClassStudent{{Name: "Emma Torres"}, aliased("Bea", "Emma")}, "Bea"},
		{"Emma", []ClassStudent{{Name: "Emma Torres"}, aliased("Emma Wilson", "Emma")}, "Emma Wilson"},
		// Only the name is split: a hyphen is one part, so `Jean` does not
		// tie with Jean-Luc.
		{"Jean", students("Jean", "Jean-Luc"), "Jean"},
		{"Luc", students("Jean-Luc Picard"), ""}, // luc → jeanluc 0.43, picard 0.17
		// Parts under three runes are exact-only: `de` would score 0.67
		// against `Dee` on the fuzzy path, and `Li` still reaches Li Wei.
		{"Dee", students("Maria de la Cruz", "Sam"), ""},
		{"Li", students("Li Wei", "Sam"), "Li Wei"},
		// Stop-list gates both the exact and the fuzzy path over a part:
		// the matcher derived `he` from `Wei He`, nobody typed it.
		{"He", students("Wei He", "Sam"), ""},
		{"I", students("Anna I Smith"), ""},
		{"They", students("Théo Martin"), ""},
		// A typed string still bypasses it, as before.
		{"He", []ClassStudent{aliased("Hector", "He")}, "Hector"},
	})
}

// TestMatchStudent_NumberedNames: two children with the same first name are
// enrolled as `Arthur 1` and `Arthur 2`. Voxtral writes a spoken number as
// a digit, so the name is exact as spoken; a child carrying a number
// scores 0 against a label carrying a different one, so `Artur 2` meets
// `Arthur 2` alone where it scored 0.86 against both and tied. A bare
// `Arthur` still ties.
func TestMatchStudent_NumberedNames(t *testing.T) {
	twins := students("Arthur 1", "Arthur 2", "Lucie")
	runMatchCases(t, []matchCase{
		{"Arthur 1", twins, "Arthur 1"},
		{"Arthur 2", twins, "Arthur 2"},
		{"Arthur 2.", twins, "Arthur 2"},
		{"Artur 2", twins, "Arthur 2"}, // 0.86, Arthur 1 gated to 0
		{"Artur 1", twins, "Arthur 1"},
		// No number: both twins score 0.86 on the whole and 1.0 on the
		// part, tie.
		{"Arthur", twins, ""},
		{"Artur", twins, ""},
		// A number nobody carries gates both twins to 0.
		{"Arthur 3", twins, ""},
		// A child without a number is never gated: lucy2 → lucie 0.60.
		{"Lucy 2", twins, "Lucie"},
		{"Lucie", twins, "Lucie"},
		// A typed alias still wins outright, numbered or not, and even
		// when another child carries that number.
		{"Tutu", []ClassStudent{{Name: "Arthur 1"}, aliased("Arthur 2", "Tutu")}, "Arthur 2"},
		{"Arthur 2", []ClassStudent{aliased("Arthur Dupont", "Arthur 2"), {Name: "Bob 2"}, {Name: "Bob 1"}}, "Arthur Dupont"},
		// A near name elsewhere in the class is gated like anyone else.
		{"Artur 2", students("Arthur 1", "Arthur 2", "Arthus"), "Arthur 2"},
		{"Artus", students("Arthur 1", "Arthur 2", "Arthus"), "Arthus"},
		// A number alone is not a name: `2` is no part.
		{"2", twins, ""},
		{"1745", students("1745"), "1745"},
		// Number words are not folded: Voxtral writes digits (probe,
		// 2026-09-03). `arthurone` scores 0.67 against both twins, tie.
		{"Arthur one", twins, ""},
	})
}

func TestSplitLabel(t *testing.T) {
	cases := map[string][]string{
		"Zachariah and Anaya":       {"Zachariah", "Anaya"},
		"Jules, Eleanor and Elise":  {"Jules", "Eleanor", "Elise"},
		"Jules, Eleanor, and Elise": {"Jules", "Eleanor", "Elise"},
		"Emma, and, Ryan":           {"Emma", "Ryan"},
		"Andy and":                  {"Andy"},
		"and":                       nil, // nothing left: names nobody
		"Vasco AND Matthew":         {"Vasco", "Matthew"},
		"Jean-Luc et Marie":         {"Jean-Luc et Marie"}, // English joiners only
		"Emma & Ryan":               {"Emma", "Ryan"},
		"Emma/Ryan":                 {"Emma", "Ryan"},
		"Liam; Luca":                {"Liam", "Luca"},
		"Anna Rose Lee":             {"Anna Rose Lee"},
		"Anne-and-Marie":            {"Anne-and-Marie"},
		"Andrea":                    {"Andrea"},
		"Colette":                   {"Colette"},
		"Arthur 2":                  {"Arthur 2"},
		"Emma":                      {"Emma"},
		"":                          nil,
		" , ":                       nil,
	}
	for in, want := range cases {
		assert.Equal(t, want, splitLabel(in), "%q", in)
	}
}

// TestMatchStudent_MiddleNamesAndInitials: a teacher tells two children
// with one first name apart by a middle name or an initial. Voxtral writes
// a spoken initial as the letter, with or without a period (probe,
// 2026-09-03), so the whole name is exact; a bare first name is a tie.
func TestMatchStudent_MiddleNamesAndInitials(t *testing.T) {
	initials := students("Emma T", "Emma R", "Lucie")
	middles := students("Emma Rose", "Emma Louise", "Lucie")
	runMatchCases(t, []matchCase{
		{"Emma T", initials, "Emma T"},
		{"Emma T.", initials, "Emma T"},
		{"Emma R", initials, "Emma R"},
		{"Emmy T", initials, "Emma T"}, // 0.80 over 0.60
		{"Emma", initials, ""},
		{"Emma T", students("Emma T.", "Emma R."), "Emma T."},
		{"Emma Rose", middles, "Emma Rose"},
		{"Emma Roze", middles, "Emma Rose"}, // 0.88 over Emma Louise 0.60
		// `Emma Rows` sits exactly on the margin (0.75 over 0.60) and is
		// left out on purpose: it would pin float noise, not a rule.
		{"Emma Louisa", middles, "Emma Louise"},
		{"Rose", middles, "Emma Rose"},
		{"Emma", middles, ""},
		// A plain `Emma` typed beside `Emma Rose` takes the bare label.
		{"Emma", students("Emma Rose", "Emma"), "Emma"},
		{"Rose", students("Emma Rose", "Emma"), "Emma Rose"},
		// Known gap: an initial written as a word. Voxtral did not do this
		// in the probe; pinned so a fix shows up deliberately.
		{"Emma Tee", initials, ""}, // 0.71 over 0.57, margin 0.14
	})
}

// TestMatchStudent_NumberedRosterFixture: the numbered_roster eval fixture's
// Go half. Voxtral writes a spoken `Arthur one` as `Arthur 1` (probe,
// 2026-09-03), which is how the fixture's transcript carries it; it must
// reach the child, as must a mangled stem.
func TestMatchStudent_NumberedRosterFixture(t *testing.T) {
	classes := fixtureClasses(t, "numbered_roster")
	require.Len(t, classes, 1)
	class := classes[0].Students
	runMatchCases(t, []matchCase{
		{"Arthur 2", class, "Arthur 2"},
		{"Arthur 1", class, "Arthur 1"},
		{"Artur 2", class, "Arthur 2"},
		{"Arthur", class, ""},
	})
}

func fixtureClasses(t *testing.T, fixture string) []ClassGroup {
	t.Helper()
	raw, err := os.ReadFile(filepath.Join("evals", "fixtures", "extraction", fixture, "classes.json"))
	require.NoError(t, err)
	var classes []ClassGroup
	require.NoError(t, json.Unmarshal(raw, &classes))
	return classes
}

// TestMatchStudent_FullNameRosterFixture: the extraction eval carries a
// full-name roster again in fixtures/extraction/full_name_roster, so the
// harness covers #111. It needs a model run to grade; this pins the Go half
// without one — every expected child resolves from their first name within
// their class — so a roster edit cannot quietly turn the fixture red.
func TestMatchStudent_FullNameRosterFixture(t *testing.T) {
	classes := fixtureClasses(t, "full_name_roster")

	var expected struct {
		Students []struct {
			Name      string `json:"name"`
			ClassName string `json:"class_name"`
		} `json:"expected_students"`
	}
	raw, err := os.ReadFile(filepath.Join("evals", "fixtures", "extraction", "full_name_roster", "expected.json"))
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal(raw, &expected))
	require.NotEmpty(t, expected.Students)

	for _, exp := range expected.Students {
		parts := strings.Fields(exp.Name)
		require.Greater(t, len(parts), 1, "%q is not a full name", exp.Name)
		var class []ClassStudent
		for _, c := range classes {
			if c.Name == exp.ClassName {
				class = c.Students
			}
		}
		require.NotEmpty(t, class, "class %q not in classes.json", exp.ClassName)
		got, ok := MatchStudent(parts[0], class)
		assert.True(t, ok, "first name %q", parts[0])
		assert.Equal(t, exp.Name, got)
	}
}
