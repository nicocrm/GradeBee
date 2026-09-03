package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"io"
	"os"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

// mustRawMap converts a map[string]interface{} to map[string]json.RawMessage.
func mustRawMap(m map[string]interface{}) map[string]json.RawMessage {
	result := make(map[string]json.RawMessage, len(m))
	for k, v := range m {
		b, err := json.Marshal(v)
		if err != nil {
			panic(fmt.Sprintf("mustRawMap: marshal %s: %v", k, err))
		}
		result[k] = b
	}
	return result
}

// captureOutput redirects os.Stdout for the duration of f() and returns what was written.
// Not goroutine-safe — use only in sequential tests.
func captureOutput(f func() error) (string, error) {
	r, w, err := os.Pipe()
	if err != nil {
		panic(fmt.Sprintf("captureOutput: pipe: %v", err))
	}
	old := os.Stdout
	os.Stdout = w
	runErr := f()
	w.Close()
	os.Stdout = old
	var buf bytes.Buffer
	if _, err := io.Copy(&buf, r); err != nil {
		panic(fmt.Sprintf("captureOutput: copy: %v", err))
	}
	return buf.String(), runErr
}

func TestRun_MissingArgs(t *testing.T) {
	err := run([]string{"eval-cli"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "usage")
}

func TestRun_NonJSONArg(t *testing.T) {
	err := run([]string{"eval-cli", "unknown"})
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "usage")
}

func TestRunPromptMode_UnknownTask(t *testing.T) {
	err := runPromptMode(`{"vars":{},"config":{"task":"bogus"}}`)
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "unknown task")
}

func TestRunBuildExtractPrompt(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": "Alice read well today.",
		"classes":    []interface{}{},
	})}
	out, err := captureOutput(func() error { return runBuildExtractPrompt(ec) })
	require.NoError(t, err)
	var msgs []map[string]string
	require.NoError(t, json.Unmarshal([]byte(strings.TrimSpace(out)), &msgs))
	require.Len(t, msgs, 2)
	assert.Equal(t, "system", msgs[0]["role"])
	assert.NotEmpty(t, msgs[0]["content"])
	assert.Equal(t, "user", msgs[1]["role"])
	// The user message is the numbered clause list production sends, not the raw
	// transcript: span indices are 1..N over that same split.
	assert.Equal(t, "1. Alice read well today.\n", msgs[1]["content"])
}

func TestRunBuildExtractPrompt_MissingTranscript(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": "",
		"classes":    []interface{}{},
	})}
	_, err := captureOutput(func() error { return runBuildExtractPrompt(ec) })
	require.Error(t, err)
	assert.Contains(t, err.Error(), "transcript")
}

// segmentResponse is what the model returns for the transcript below: the
// header, one child span whose label the roster has and one it does not.
// Clause 1 is "Grade 3A," and clause 2 "Monday." — the splitter cuts on the
// comma too.
const segmentResponse = `{"class_name":"Grade 3A","spans":[` +
	`{"start":1,"end":2,"kind":"none","spoken_labels":[],"summary":""},` +
	`{"start":3,"end":3,"kind":"child","spoken_labels":["Alice"],"summary":"Alice read well."},` +
	`{"start":4,"end":4,"kind":"child","spoken_labels":["Polly"],"summary":"Polly was quiet."}]}`

const segmentTranscript = "Grade 3A, Monday. Alice read well today. Polly was quiet."

func TestRunAssembleExtract(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": segmentTranscript,
		"classes": []interface{}{map[string]interface{}{
			"name":     "Grade 3A",
			"students": []interface{}{map[string]interface{}{"name": "Alice Chen"}},
		}},
		"response": segmentResponse,
	})}
	out, err := captureOutput(func() error { return runAssembleExtract(ec) })
	require.NoError(t, err)

	var got struct {
		Students []struct {
			Name       string `json:"name"`
			ClassName  string `json:"class_name"`
			QuotedText string `json:"quoted_text"`
		} `json:"students"`
		Unattributed []struct {
			Source string `json:"source"`
		} `json:"unattributed"`
	}
	require.NoError(t, json.Unmarshal([]byte(strings.TrimSpace(out)), &got))

	// The scorer reads students[].quoted_text, so the span summary has to land
	// there — that is what lets the fixtures grade the notes Go assembles.
	require.Len(t, got.Students, 1)
	assert.Equal(t, "Alice Chen", got.Students[0].Name)
	assert.Equal(t, "Grade 3A", got.Students[0].ClassName)
	assert.Equal(t, "Alice read well.", got.Students[0].QuotedText)

	// A label matching nobody produces no note, and its clauses stay readable.
	require.Len(t, got.Unattributed, 1)
	assert.Contains(t, got.Unattributed[0].Source, "Polly was quiet.")
}

// The eval config drops production's class_name enum, so a class name the
// roster does not have is possible here and nowhere else. multi_class asserts
// on unknown_class_name to tell that apart from the model declining, both of
// which leave class_name empty.
func TestRunAssembleExtract_InventedClassName(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": segmentTranscript,
		"classes": []interface{}{map[string]interface{}{
			"name":     "Grade 3A",
			"students": []interface{}{map[string]interface{}{"name": "Alice"}},
		}},
		"response": strings.Replace(segmentResponse, "Grade 3A", "Grade 9Z", 1),
	})}
	out, err := captureOutput(func() error { return runAssembleExtract(ec) })
	require.NoError(t, err)

	var got struct {
		Students         []struct{} `json:"students"`
		ClassName        string     `json:"class_name"`
		UnknownClassName string     `json:"unknown_class_name"`
	}
	require.NoError(t, json.Unmarshal([]byte(strings.TrimSpace(out)), &got))
	assert.Empty(t, got.Students)
	assert.Equal(t, "", got.ClassName)
	assert.Equal(t, "Grade 9Z", got.UnknownClassName)
}

// A tiling reject fails the job in production, so it must fail here too rather
// than print a partial set of notes.
func TestRunAssembleExtract_TilingReject(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": segmentTranscript,
		"classes":    []interface{}{},
		"response":   `{"class_name":"","spans":[{"start":1,"end":1,"kind":"none","spoken_labels":[],"summary":""}]}`,
	})}
	_, err := captureOutput(func() error { return runAssembleExtract(ec) })
	require.Error(t, err)
	assert.Contains(t, err.Error(), "tile")
}

func TestRunAssembleExtract_MissingTranscript(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"transcript": "",
		"classes":    []interface{}{},
		"response":   segmentResponse,
	})}
	_, err := captureOutput(func() error { return runAssembleExtract(ec) })
	require.Error(t, err)
	assert.Contains(t, err.Error(), "transcript")
}

func TestRunBuildReportPrompt(t *testing.T) {
	ec := evalContext{Vars: mustRawMap(map[string]interface{}{
		"student_name":        "Alice",
		"class_name":          "Grade 3A",
		"notes":               []interface{}{map[string]interface{}{"date": "2026-01-15", "summary": "Strong reader."}},
		"examples":            []interface{}{},
		"report_instructions": "Write a three-section report.",
		"instructions":        "",
	})}
	out, err := captureOutput(func() error { return runBuildReportPrompt(ec) })
	require.NoError(t, err)
	var msgs []map[string]string
	require.NoError(t, json.Unmarshal([]byte(strings.TrimSpace(out)), &msgs))
	require.Len(t, msgs, 1)
	assert.Equal(t, "user", msgs[0]["role"])
	assert.NotEmpty(t, msgs[0]["content"])
}
