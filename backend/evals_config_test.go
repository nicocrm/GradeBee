// evals_config_test.go guards the eval harness against grading a model that
// production does not run.
package handler

import (
	"encoding/json"
	"os"
	"path/filepath"
	"sort"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
	"gopkg.in/yaml.v3"
)

// promptfooConfig is the minimal slice of a promptfoo config file needed to
// check which model a provider grades.
type promptfooConfig struct {
	Providers []struct {
		ID     string `yaml:"id"`
		Label  string `yaml:"label"`
		Config struct {
			ResponseFormat struct {
				JSONSchema struct {
					Schema struct {
						Properties struct {
							Spans struct {
								Items struct {
									Properties map[string]any `yaml:"properties"`
									Required   []string       `yaml:"required"`
								} `yaml:"items"`
							} `yaml:"spans"`
						} `yaml:"properties"`
						Required []string `yaml:"required"`
					} `yaml:"schema"`
				} `yaml:"json_schema"`
			} `yaml:"response_format"`
		} `yaml:"config"`
	} `yaml:"providers"`
}

// TestEvalConfigsTrackProductionModels asserts that each eval config's canonical
// provider — the one evals/scripts/diff-baseline.js scores for regressions —
// names the same model as defaultModels("mistral"), the deployed configuration.
//
// Without this the two drift silently: the extraction config spent its life
// pinned to mistral-small-2603 while production ran mistral-medium-2508, so
// every score in evals/baseline.json described a model we do not ship.
//
// Scope, deliberately narrower than LoadProvider: this checks the Mistral
// defaults only. It does not follow LLM_PROVIDER=openai or the LLM_MODEL_*
// overrides resolveModels() applies, because the configs hardcode a
// "mistral:"-prefixed provider id and cannot express either. A deployment that
// overrides those env vars is outside what this guard can see.
//
// Non-canonical providers are deliberately unchecked. They exist to compare
// other models and are free to name anything.
func TestEvalConfigsTrackProductionModels(t *testing.T) {
	models := defaultModels("mistral")

	cases := []struct {
		file  string
		label string
		task  LLMTask
	}{
		{"promptfooconfig.extract.yaml", "gradebee-extract", LLMTaskExtraction},
		{"promptfooconfig.report.yaml", "gradebee-report", LLMTaskReport},
	}

	for _, tc := range cases {
		t.Run(tc.file, func(t *testing.T) {
			raw, err := os.ReadFile(filepath.Join("evals", tc.file))
			require.NoError(t, err)

			var cfg promptfooConfig
			require.NoError(t, yaml.Unmarshal(raw, &cfg))

			var got string
			for _, p := range cfg.Providers {
				if p.Label != tc.label {
					continue
				}
				require.Empty(t, got, "more than one provider is labelled %q", tc.label)
				got = p.ID
			}
			require.NotEmpty(t, got, "no provider labelled %q in %s", tc.label, tc.file)

			assert.Equal(t, "mistral:"+models[tc.task], got,
				"%s grades a different model than defaultModels(\"mistral\"): fix the "+
					"provider id, or update defaultModels() and regenerate evals/baseline.json",
				tc.file)
		})
	}
}

// TestExtractConfigSchemaMatchesProduction asserts that the response schema in
// promptfooconfig.extract.yaml asks the model for the same fields
// extractResponseSchema() does.
//
// The two are separate copies on purpose — the eval cannot template a
// per-fixture roster into a static provider config, so its class_name stays a
// plain string where production constrains it to an enum. Everything else must
// match, and did not: the config pinned the retired students[] schema for the
// whole of #99 while eval-cli had moved to spans, so the model was asked to
// segment and structurally forced to answer in the old shape. Nothing failed;
// the scores just stopped meaning anything.
//
// Field names only. Types and nesting below a span are left to the reviewer —
// a wrong type fails loudly at eval time, a missing field does not.
func TestExtractConfigSchemaMatchesProduction(t *testing.T) {
	raw, err := os.ReadFile(filepath.Join("evals", "promptfooconfig.extract.yaml"))
	require.NoError(t, err)

	var cfg promptfooConfig
	require.NoError(t, yaml.Unmarshal(raw, &cfg))

	var production struct {
		Properties map[string]any `json:"properties"`
		Required   []string       `json:"required"`
		Items      struct {
			Properties map[string]any `json:"properties"`
			Required   []string       `json:"required"`
		}
	}
	require.NoError(t, json.Unmarshal(extractResponseSchema(nil), &production))
	var spans struct {
		Items struct {
			Properties map[string]any `json:"properties"`
			Required   []string       `json:"required"`
		} `json:"items"`
	}
	spansRaw, err := json.Marshal(production.Properties["spans"])
	require.NoError(t, err)
	require.NoError(t, json.Unmarshal(spansRaw, &spans))

	for _, p := range cfg.Providers {
		schema := p.Config.ResponseFormat.JSONSchema.Schema
		t.Run(p.Label, func(t *testing.T) {
			require.NotEmpty(t, schema.Required, "provider %q declares no response schema", p.Label)
			assert.Equal(t, sorted(production.Required), sorted(schema.Required),
				"top-level fields differ from extractResponseSchema()")
			assert.Equal(t, sorted(spans.Items.Required), sorted(schema.Properties.Spans.Items.Required),
				"span fields differ from extractResponseSchema()")
			assert.Equal(t, sorted(keys(spans.Items.Properties)), sorted(keys(schema.Properties.Spans.Items.Properties)),
				"span properties differ from extractResponseSchema()")
		})
	}
}

func sorted(s []string) []string {
	out := append([]string(nil), s...)
	sort.Strings(out)
	return out
}

func keys(m map[string]any) []string {
	out := make([]string, 0, len(m))
	for k := range m {
		out = append(out, k)
	}
	return out
}
