package handler

import (
	"encoding/json"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// Live extraction tests (those that call a real LLM) live in llm_live_test.go;
// this file holds only offline checks.

// schemaProp mirrors the subset of JSON Schema shape produced by
// extractResponseSchema, enough to inspect the class_name enum constraint.
type schemaProp struct {
	Type       string                `json:"type"`
	Enum       []string              `json:"enum,omitempty"`
	Properties map[string]schemaProp `json:"properties,omitempty"`
	Items      *schemaProp           `json:"items,omitempty"`
}

// TestExtractResponseSchemaClassNameEnum verifies that extractResponseSchema
// constrains class_name to the roster's actual class names plus "": the enum is
// what structurally stops the model inventing a class, and "" is what lets it
// decline instead of guessing when the recording covers more than one.
func TestExtractResponseSchemaClassNameEnum(t *testing.T) {
	classes := []ClassGroup{
		{Name: "Period 3", Students: []ClassStudent{{Name: "Maxence"}}},
		{Name: "Period 5", Students: []ClassStudent{{Name: "Amara"}}},
	}

	var schema schemaProp
	require.NoError(t, json.Unmarshal(extractResponseSchema(classes), &schema))
	assert.ElementsMatch(t, []string{"Period 3", "Period 5", ""}, schema.Properties["class_name"].Enum)

	// No roster: the only honest answer is the decline, so that is the only
	// value the schema permits. Every span then comes back unattributed.
	var emptySchema schemaProp
	require.NoError(t, json.Unmarshal(extractResponseSchema(nil), &emptySchema))
	assert.Equal(t, []string{""}, emptySchema.Properties["class_name"].Enum)
}

// TestExtractResponseSchemaSpans verifies the span shape the model must return:
// AssembleNotes reads all five fields, and a missing one is silently the zero
// value — a span with no kind is discarded, a span with no labels reaches
// nobody.
func TestExtractResponseSchemaSpans(t *testing.T) {
	var schema struct {
		Properties struct {
			Spans struct {
				Items struct {
					Properties map[string]schemaProp `json:"properties"`
					Required   []string              `json:"required"`
				} `json:"items"`
			} `json:"spans"`
		} `json:"properties"`
		Required []string `json:"required"`
	}
	require.NoError(t, json.Unmarshal(extractResponseSchema([]ClassGroup{{Name: "Period 3"}}), &schema))

	assert.ElementsMatch(t, []string{"class_name", "spans"}, schema.Required)
	span := schema.Properties.Spans.Items
	assert.ElementsMatch(t, []string{"start", "end", "kind", "spoken_labels", "summary"}, span.Required)
	assert.ElementsMatch(t, []string{"child", "group", "none"}, span.Properties["kind"].Enum,
		"kind must be an enum: validateTiling rejects an unknown kind, failing the whole job")
}

// TestBuildExtractionPromptOmitsStudents is the guard against the roster
// creeping back into the prompt. Shown student names the model resolves first
// and re-cuts the transcript to fit the slots it committed to — measured at 2/4
// correct boundaries against 4/4 with class names only (#99). Aliases are the
// subtler regression: they used to reach the model as "(aka …)" and now live
// only in MatchStudent.
func TestBuildExtractionPromptOmitsStudents(t *testing.T) {
	prompt := BuildExtractionPrompt([]ClassGroup{
		{Name: "Period 1", Students: []ClassStudent{
			{Name: "Alexander", Aliases: []string{"Alex", "Xander"}},
			{Name: "Katherine"},
		}},
		{Name: "Period 2", Students: []ClassStudent{{Name: "Maxence"}}},
	})

	assert.Contains(t, prompt, "- Period 1\n", "the class display names are what the model picks from")
	assert.Contains(t, prompt, "- Period 2\n")
	for _, name := range []string{"Alexander", "Katherine", "Maxence", "Alex", "Xander", "aka"} {
		assert.NotContains(t, prompt, name, "the extraction prompt must never carry a student name or alias")
	}
}

// TestBuildExtractionUserPromptNumbersClauses verifies the numbering the model
// indexes its spans into. It must be 1..N over SplitClauses of the same
// transcript AssembleNotes later slices; renumber on one side only and every
// span points at the wrong child's words.
func TestBuildExtractionUserPromptNumbersClauses(t *testing.T) {
	const transcript = "Thursday. Alice did great, Bob did not."
	clauses := SplitClauses(transcript)
	require.Len(t, clauses, 3, "clauses: %q", clauses)

	got := BuildExtractionUserPrompt(transcript)

	assert.Equal(t, "1. Thursday.\n2. Alice did great,\n3. Bob did not.\n", got)
	assert.Equal(t, len(clauses), strings.Count(got, "\n"), "one numbered line per clause")
	assert.Empty(t, BuildExtractionUserPrompt(""), "a blank transcript has no clauses to number")
}
