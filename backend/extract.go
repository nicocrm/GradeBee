// extract.go defines the Extractor interface and its LLM implementation.
//
// The extractor segments a transcript: it takes the transcript plus the class
// display names and returns clause-index spans and a class name (#99). It
// never sees a student name — shown a roster the model resolves first and
// re-cuts the transcript to fit the slots it committed to. AssembleNotes
// (spans.go) turns the segmentation into per-student notes.
package handler

import (
	"context"
	"encoding/json"
	"fmt"
	"strconv"
	"strings"
)

// Extractor takes a transcript + class names and returns the segmentation.
type Extractor interface {
	Extract(ctx context.Context, req ExtractRequest) (*SegmentResponse, error)
	// Model returns the model ID used for extraction (for stamping model_version).
	Model() string
}

// ExtractRequest is the input to an extraction call. Classes carries the
// students only so callers can pass the roster straight through to
// AssembleNotes; the prompt reads nothing but the class names.
type ExtractRequest struct {
	Transcript string
	Classes    []ClassGroup
}

// llmExtractor uses an LLMProvider to segment transcripts.
type llmExtractor struct {
	provider LLMProvider
}

func newLLMExtractor(provider LLMProvider) *llmExtractor {
	return &llmExtractor{provider: provider}
}

func (e *llmExtractor) Model() string {
	return e.provider.Model(LLMTaskExtraction)
}

func (e *llmExtractor) Extract(ctx context.Context, req ExtractRequest) (*SegmentResponse, error) {
	var result SegmentResponse
	_, err := e.provider.ChatJSON(ctx, ChatJSONRequest{
		SystemPrompt: BuildExtractionPrompt(req.Classes),
		UserPrompt:   BuildExtractionUserPrompt(req.Transcript),
		SchemaName:   "extract_response",
		Schema:       extractResponseSchema(req.Classes),
	}, &result)
	if err != nil {
		return nil, fmt.Errorf("extraction failed: %w", err)
	}

	return &result, nil
}

// BuildExtractionPrompt returns the system prompt: the segmentation rules
// around the list of class display names. Students are deliberately absent —
// see extractionPromptPrefix.
func BuildExtractionPrompt(classes []ClassGroup) string {
	var sb strings.Builder
	sb.WriteString(extractionPromptPrefix)
	for _, c := range classes {
		sb.WriteString("- " + c.Name + "\n")
	}
	sb.WriteString(extractionPromptSuffix)
	return sb.String()
}

// BuildExtractionUserPrompt renders transcript as the numbered clause list the
// model indexes its spans into.
//
// The numbering is 1..N over SplitClauses(transcript) and AssembleNotes slices
// the same split with the same indices, so this is the only place a clause is
// ever numbered. Number a transcript anywhere else and the two sides drift.
func BuildExtractionUserPrompt(transcript string) string {
	var sb strings.Builder
	for i, clause := range SplitClauses(transcript) {
		sb.WriteString(strconv.Itoa(i + 1))
		sb.WriteString(". ")
		sb.WriteString(clause)
		sb.WriteString("\n")
	}
	return sb.String()
}

// extractResponseSchema returns the JSON schema for structured outputs.
//
// class_name is an enum of the roster's actual class names plus "", so the
// model is structurally able to decline and structurally unable to invent —
// the prompt instruction alone left it inventing class names. An empty roster
// yields the enum [""], the only honest answer when there is no class to name;
// every span then comes back unattributed from AssembleNotes.
func extractResponseSchema(classes []ClassGroup) json.RawMessage {
	classNames := make([]string, 0, len(classes)+1)
	for _, c := range classes {
		classNames = append(classNames, c.Name)
	}
	classNames = append(classNames, "")

	spanSchema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"start": map[string]any{"type": "integer"},
			"end":   map[string]any{"type": "integer"},
			"kind": map[string]any{
				"type": "string",
				"enum": []string{string(SpanChild), string(SpanGroup), string(SpanNone)},
			},
			"spoken_labels": map[string]any{
				"type":  "array",
				"items": map[string]any{"type": "string"},
			},
			"summary": map[string]any{"type": "string"},
		},
		"required":             []string{"start", "end", "kind", "spoken_labels", "summary"},
		"additionalProperties": false,
	}

	schema := map[string]any{
		"type": "object",
		"properties": map[string]any{
			"class_name": map[string]any{"type": "string", "enum": classNames},
			"spans": map[string]any{
				"type":  "array",
				"items": spanSchema,
			},
		},
		"required":             []string{"class_name", "spans"},
		"additionalProperties": false,
	}

	b, err := json.Marshal(schema)
	if err != nil {
		// Construction is fully static/programmatic; a marshal error here
		// means a bug in this function, not a runtime condition to handle.
		panic(fmt.Sprintf("extractResponseSchema: %v", err))
	}
	return json.RawMessage(b)
}
