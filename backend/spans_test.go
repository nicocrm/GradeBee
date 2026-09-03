package handler

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// note694Classes is the roster the model chose from for note 694: the
// pinned class plus a sibling class holding a near-homonym of every label,
// so class scoping has something to fail against.
var note694Classes = []ClassGroup{
	{Name: "Linda · Wed · 13.15", Students: students("Polly", "Levy", "Sheila")},
	{Name: "Linda · Wed · 17.45", Students: rosterLindaWed1745},
}

// note694Response is the model's segmentation of note 694 (research run
// 694-0): header, an unnamed child's block, Polly's block, Levy's block.
func note694Response() SegmentResponse {
	return SegmentResponse{
		ClassName: "Linda · Wed · 17.45",
		Spans: []Span{
			{Start: 1, End: 7, Kind: SpanNone, SpokenLabels: []string{},
				Summary: "Wednesday 1745. Linda. I don't know what to say. Yes, please. Thank you."},
			{Start: 8, End: 11, Kind: SpanChild, SpokenLabels: []string{"She"},
				Summary: "She was helping knock on boxes. She said 'up and down' when she was putting Bunny up and down."},
			{Start: 12, End: 18, Kind: SpanChild, SpokenLabels: []string{"Polly"},
				Summary: "Polly wasn't speaking today. She was laughing and giggling."},
			{Start: 19, End: 32, Kind: SpanChild, SpokenLabels: []string{"Levy"},
				Summary: "Levy was a little active. He said 'again', 'bye-bye', occasionally 'yes', 'please', 'thank you'."},
		},
	}
}

// TestAssembleNotes_Note694 pins the production transcript's outcome: one
// note, for Lévi, holding only his span's summary; the unnamed block and
// Polly's block unattributed with their verbatim source; the header
// discarded. Polly's "laughing and giggling" appears nowhere but in her own
// unattributed span — the #99 bleed, gone.
func TestAssembleNotes_Note694(t *testing.T) {
	got, err := AssembleNotes(note694, note694Classes, note694Response())
	require.NoError(t, err)

	assert.Equal(t, "Linda · Wed · 17.45", got.ClassName)
	assert.Equal(t, []AssembledNote{{
		Name:      "Lévi",
		ClassName: "Linda · Wed · 17.45",
		Text:      "Levy was a little active. He said 'again', 'bye-bye', occasionally 'yes', 'please', 'thank you'.",
	}}, got.Notes)

	require.Len(t, got.Unattributed, 2)
	assert.Equal(t, 8, got.Unattributed[0].Span.Start)
	assert.Equal(t, 11, got.Unattributed[0].Span.End)
	assert.Equal(t, "She was helping knock on boxes. "+
		"She said up and down when she was putting Bunny up and down. "+
		"She also enjoyed the big book with the party balloons and the birthday cake. "+
		"She also loved the snail and the mouse for quickly and slowly.", got.Unattributed[0].Source)
	assert.Equal(t, []string{"Polly"}, got.Unattributed[1].Span.SpokenLabels)
	assert.True(t, strings.HasPrefix(got.Unattributed[1].Source, "Polly wasn't speaking today. She did say bye-bye at the end."), got.Unattributed[1].Source)
	assert.True(t, strings.HasSuffix(got.Unattributed[1].Source, "In playing with a snail for quickly and slowly."), got.Unattributed[1].Source)
	assert.Contains(t, got.Unattributed[1].Source, "laughing and giggling")
	assert.NotContains(t, got.Notes[0].Text, "laughing and giggling")

	assert.Equal(t, []LabelMiss{
		{Label: "She", Start: 8, End: 11},
		{Label: "Polly", Start: 12, End: 18},
	}, got.Misses)
}

// TestAssembleNotes_ClassScoping: the same labels against the sibling class,
// where "Polly" and "Levy" are exact roster names, resolve there — proving
// that with the real class pinned they were rejected by scoping, not by
// accident.
func TestAssembleNotes_ClassScoping(t *testing.T) {
	resp := note694Response()
	resp.ClassName = "Linda · Wed · 13.15"
	got, err := AssembleNotes(note694, note694Classes, resp)
	require.NoError(t, err)
	names := make([]string, len(got.Notes))
	for i, n := range got.Notes {
		names[i] = n.Name + "@" + n.ClassName
	}
	assert.Equal(t, []string{"Polly@Linda · Wed · 13.15", "Levy@Linda · Wed · 13.15"}, names)
	assert.Equal(t, []LabelMiss{{Label: "She", Start: 8, End: 11}}, got.Misses)
}

// TestAssembleNotes_NoClassPinned: an empty class_name (the model declined)
// or a class not in the roster yields zero notes and every child/group span
// unattributed — even where a label would have matched exactly — with every
// label recorded as a miss. `none` spans are still discarded. Only the
// unknown class is reported back, so the caller can tell a decline from a
// defect.
func TestAssembleNotes_NoClassPinned(t *testing.T) {
	for _, className := range []string{"", "Linda · Wed · 99.99"} {
		t.Run("class="+className, func(t *testing.T) {
			resp := note694Response()
			resp.ClassName = className
			// A group span that would fan out if anyone had resolved.
			resp.Spans[0].Kind = SpanGroup
			got, err := AssembleNotes(note694, note694Classes, resp)
			require.NoError(t, err)
			assert.Equal(t, "", got.ClassName)
			assert.Equal(t, className, got.UnknownClassName)
			assert.Empty(t, got.Notes)
			assert.Equal(t, []LabelMiss{
				{Label: "She", Start: 8, End: 11},
				{Label: "Polly", Start: 12, End: 18},
				{Label: "Levy", Start: 19, End: 32},
			}, got.Misses)
			require.Len(t, got.Unattributed, 4)
			for i, u := range got.Unattributed {
				assert.Equal(t, resp.Spans[i], u.Span)
			}
			assert.Equal(t, "Wednesday, 1745. Linda, I don't know what to say. Yes, please. Thank you.", got.Unattributed[0].Source)
		})
	}
	// Control: the same response with the class pinned does produce notes
	// and reports no unknown class.
	got, err := AssembleNotes(note694, note694Classes, note694Response())
	require.NoError(t, err)
	assert.Len(t, got.Notes, 1)
	assert.Equal(t, "", got.UnknownClassName)
}

// groupTranscript is the `group_observation` eval fixture. At clause
// granularity it splits into 7 units; the spans below follow the research
// round 8 segmentation at that granularity.
const groupTranscript = "Quick note about Class B from this afternoon. " +
	"The whole class really struggled with the fractions worksheet today, I think we need to revisit that next week. " +
	"Specifically though, Olivia did really well — she finished early and helped a neighbor. " +
	"Marcus still not turning in homework, third time this week."

var groupClasses = []ClassGroup{
	{Name: "Class A", Students: students("Lucas Green", "Isabelle Brown")},
	{Name: "Class B", Students: students("Olivia Chen", "Marcus Davis", "Zoe Taylor")},
}

func groupResponse() SegmentResponse {
	return SegmentResponse{
		ClassName: "Class B",
		Spans: []Span{
			{Start: 1, End: 1, Kind: SpanNone, SpokenLabels: []string{}, Summary: "Quick note about Class B."},
			{Start: 2, End: 3, Kind: SpanGroup, SpokenLabels: []string{},
				Summary: "The whole class struggled with the fractions worksheet; revisit next week."},
			{Start: 4, End: 5, Kind: SpanChild, SpokenLabels: []string{"Olivia"},
				Summary: "Olivia did really well: finished early and helped a neighbor."},
			{Start: 6, End: 7, Kind: SpanChild, SpokenLabels: []string{"Marcus"},
				Summary: "Marcus is still not turning in homework, the third time this week."},
		},
	}
}

// TestAssembleNotes_GroupSpanFansOutToResolvedChildrenOnly: Olivia and
// Marcus both carry the group span, in transcript order, alongside their
// own; Zoe, on the roster but never named, gets nothing.
func TestAssembleNotes_GroupSpanFansOutToResolvedChildrenOnly(t *testing.T) {
	require.Len(t, SplitClauses(groupTranscript), 7)
	got, err := AssembleNotes(groupTranscript, groupClasses, groupResponse())
	require.NoError(t, err)

	group := "The whole class struggled with the fractions worksheet; revisit next week."
	assert.Equal(t, []AssembledNote{
		{Name: "Olivia Chen", ClassName: "Class B",
			Text: group + "\n\nOlivia did really well: finished early and helped a neighbor."},
		{Name: "Marcus Davis", ClassName: "Class B",
			Text: group + "\n\nMarcus is still not turning in homework, the third time this week."},
	}, got.Notes)
	assert.NotContains(t, got.Notes[0].Text, "homework")
	assert.NotContains(t, got.Notes[1].Text, "finished early")
	assert.Empty(t, got.Unattributed)
	assert.Empty(t, got.Misses)
}

// TestAssembleNotes_GroupSpanWithNobodyResolvedIsUnattributed: when no
// child span resolves, the group span goes to nobody rather than to the
// roster — an absent child must not get a note saying the class struggled.
func TestAssembleNotes_GroupSpanWithNobodyResolvedIsUnattributed(t *testing.T) {
	resp := groupResponse()
	resp.Spans[2].SpokenLabels = []string{"She"}
	resp.Spans[3].SpokenLabels = []string{"He"}
	got, err := AssembleNotes(groupTranscript, groupClasses, resp)
	require.NoError(t, err)
	assert.Empty(t, got.Notes)
	require.Len(t, got.Unattributed, 3)
	assert.Equal(t, SpanGroup, got.Unattributed[0].Span.Kind)
	assert.Equal(t, "The whole class really struggled with the fractions worksheet today, "+
		"I think we need to revisit that next week.", got.Unattributed[0].Source)
	assert.Equal(t, []LabelMiss{{Label: "She", Start: 4, End: 5}, {Label: "He", Start: 6, End: 7}}, got.Misses)
}

// TestAssembleNotes_MultiLabelSpan: one observation about several children
// reaches every label that resolves, and each label that does not is a
// miss — the note still exists for the others. A student named twice in
// one span gets it once; a student named in two spans gets both texts.
func TestAssembleNotes_MultiLabelSpan(t *testing.T) {
	transcript := "Zachariah and Anaya did very well. Jules, Eleanor and Elise were a little tired. Zakaria sang."
	classes := []ClassGroup{{Name: "Pam & Paul · Wed · 14.10", Students: rosterPPWed1410}}
	resp := SegmentResponse{
		ClassName: "Pam & Paul · Wed · 14.10",
		Spans: []Span{
			{Start: 1, End: 1, Kind: SpanChild, SpokenLabels: []string{"Zachariah", "Anaya", "Zachariah"}, Summary: "Did very well."},
			{Start: 2, End: 3, Kind: SpanChild, SpokenLabels: []string{"Jules", "Eleanor", "Elise", "Polly"}, Summary: "A little tired."},
			{Start: 4, End: 4, Kind: SpanChild, SpokenLabels: []string{"Zakaria"}, Summary: "Sang."},
		},
	}
	got, err := AssembleNotes(transcript, classes, resp)
	require.NoError(t, err)
	assert.Equal(t, []AssembledNote{
		{Name: "Zakaria", ClassName: "Pam & Paul · Wed · 14.10", Text: "Did very well.\n\nSang."},
		{Name: "Inaya", ClassName: "Pam & Paul · Wed · 14.10", Text: "Did very well."},
		{Name: "Jules", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
		{Name: "Eléonore", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
		{Name: "Elise", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
	}, got.Notes)
	assert.Equal(t, []LabelMiss{{Label: "Polly", Start: 2, End: 3}}, got.Misses)
	assert.Empty(t, got.Unattributed)
}

// TestAssembleNotes_FusedLabelReachesEveryChildNamed: the prompt asks for
// one label per child, and the model still returns `Zachariah and Anaya`
// as one label in a steady share of runs (note 618). The label is split
// before matching, so the span reaches both children instead of nobody;
// a part that resolves nobody is a miss on its own.
func TestAssembleNotes_FusedLabelReachesEveryChildNamed(t *testing.T) {
	transcript := "Zachariah and Anaya did very well. Jules, Eleanor and Elise were a little tired. Zakaria and Polly sang."
	classes := []ClassGroup{{Name: "Pam & Paul · Wed · 14.10", Students: rosterPPWed1410}}
	resp := SegmentResponse{
		ClassName: "Pam & Paul · Wed · 14.10",
		Spans: []Span{
			{Start: 1, End: 1, Kind: SpanChild, SpokenLabels: []string{"Zachariah and Anaya"}, Summary: "Did very well."},
			{Start: 2, End: 3, Kind: SpanChild, SpokenLabels: []string{"Jules, Eleanor, and Elise"}, Summary: "A little tired."},
			{Start: 4, End: 4, Kind: SpanChild, SpokenLabels: []string{"Zakaria & Polly", "and"}, Summary: "Sang."},
		},
	}
	got, err := AssembleNotes(transcript, classes, resp)
	require.NoError(t, err)
	assert.Equal(t, []AssembledNote{
		{Name: "Zakaria", ClassName: "Pam & Paul · Wed · 14.10", Text: "Did very well.\n\nSang."},
		{Name: "Inaya", ClassName: "Pam & Paul · Wed · 14.10", Text: "Did very well."},
		{Name: "Jules", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
		{Name: "Eléonore", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
		{Name: "Elise", ClassName: "Pam & Paul · Wed · 14.10", Text: "A little tired."},
	}, got.Notes)
	// A label that is nothing but a joiner names nobody and is a miss as
	// itself, never matched whole: `and` would reach `Ana`.
	assert.Equal(t, []LabelMiss{{Label: "Polly", Start: 4, End: 4}, {Label: "and", Start: 4, End: 4}}, got.Misses)
	assert.Empty(t, got.Unattributed)
}

// TestAssembleNotes_SummaryFallsBackToSource: a blank summary is replaced
// by the span's verbatim clauses; a child span with no labels at all is
// unattributed.
func TestAssembleNotes_SummaryFallsBackToSource(t *testing.T) {
	transcript := "Hugo sang today, loudly. Luca did not."
	classes := []ClassGroup{{Name: "C", Students: rosterPPWed1520}}
	resp := SegmentResponse{
		ClassName: "C",
		Spans: []Span{
			{Start: 1, End: 2, Kind: SpanChild, SpokenLabels: []string{"Hugo"}, Summary: "  "},
			{Start: 3, End: 3, Kind: SpanChild, SpokenLabels: []string{}},
		},
	}
	got, err := AssembleNotes(transcript, classes, resp)
	require.NoError(t, err)
	assert.Equal(t, []AssembledNote{{Name: "Hugo", ClassName: "C", Text: "Hugo sang today, loudly."}}, got.Notes)
	require.Len(t, got.Unattributed, 1)
	assert.Equal(t, "Luca did not.", got.Unattributed[0].Source)
	assert.Empty(t, got.Misses)
}

// TestAssembleNotes_RejectsNonTiling: any partition that is not exactly
// clauses 1..N once each, in order, or that carries a span of unknown kind,
// is rejected with ErrSpanTiling and no notes — never repaired.
func TestAssembleNotes_RejectsNonTiling(t *testing.T) {
	transcript := "One. Two. Three. Four." // 4 clauses
	classes := []ClassGroup{{Name: "C", Students: students("Hugo")}}
	child := func(start, end int) Span {
		return Span{Start: start, End: end, Kind: SpanChild, SpokenLabels: []string{"Hugo"}, Summary: "x"}
	}
	cases := []struct {
		name  string
		text  string
		spans []Span
		msg   string
	}{
		{"gap", transcript, []Span{child(1, 2), child(4, 4)}, "leaving clause 3 uncovered"},
		{"overlap", transcript, []Span{child(1, 3), child(3, 4)}, "overlapping clause 3"},
		{"out of range", transcript, []Span{child(1, 5)}, "ends at 5, transcript has 4 clauses"},
		{"start before 1", transcript, []Span{child(0, 4)}, "overlapping clause 0"},
		{"first span late", transcript, []Span{child(2, 4)}, "leaving clause 1 uncovered"},
		{"short", transcript, []Span{child(1, 3)}, "spans end at clause 3, transcript has 4 clauses"},
		{"end before start", transcript, []Span{child(2, 1), child(2, 4)}, "end before start"},
		{"no spans", transcript, nil, "spans end at clause 0, transcript has 4 clauses"},
		{"spans for an empty transcript", "", []Span{child(1, 1)}, "ends at 1, transcript has 0 clauses"},
		{"unknown kind", transcript, []Span{child(1, 2), {Start: 3, End: 4, Kind: "adult", SpokenLabels: []string{}}}, `span 2 has unknown kind "adult"`},
		{"missing kind", transcript, []Span{child(1, 2), {Start: 3, End: 4, SpokenLabels: []string{}}}, `span 2 has unknown kind ""`},
	}
	for _, tc := range cases {
		t.Run(tc.name, func(t *testing.T) {
			got, err := AssembleNotes(tc.text, classes, SegmentResponse{ClassName: "C", Spans: tc.spans})
			require.ErrorIs(t, err, ErrSpanTiling)
			assert.Contains(t, err.Error(), tc.msg)
			assert.Nil(t, got)
		})
	}

	// Control: the tiling partition of the same transcript is accepted.
	got, err := AssembleNotes(transcript, classes, SegmentResponse{ClassName: "C", Spans: []Span{child(1, 2), child(3, 4)}})
	require.NoError(t, err)
	assert.Len(t, got.Notes, 1)

	// An empty transcript with no spans is a valid, empty result.
	got, err = AssembleNotes("  ", classes, SegmentResponse{ClassName: "C"})
	require.NoError(t, err)
	assert.Empty(t, got.Notes)
	assert.Empty(t, got.Unattributed)
}
