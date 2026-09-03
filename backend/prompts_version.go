// prompts_version.go provides deterministic hashes for prompt templates so
// every generated note and report row can be stamped with the prompt version
// that produced it.  This enables production quality drops to be correlated to
// specific prompt or model changes.
//
// # How it works
//
// Static template strings are defined here as package-level consts.  At init()
// time each string is hashed (SHA-256, first 12 hex chars) with a
// PromptVersionTag prefix so that non-template logic changes can be captured
// by manually bumping the tag.
//
// The builder functions in extract.go and report_prompt.go still live there and
// interpolate dynamic values (class names, notes, feedback) into the
// templates.  Hashing the static portion is a reasonable proxy: substantive
// changes almost always touch the static text.
package handler

import (
	"crypto/sha256"
	"encoding/hex"
)

// PromptVersionTag is bumped manually when non-template logic changes (e.g.
// branching behaviour inside builder functions that hashing the template alone
// would not catch).  Format: monotonic integer as string.
const PromptVersionTag = "4"

// --- Extraction prompt templates ---

// extractionPromptPrefix is the static preamble that opens every extraction
// prompt (before the list of class display names is interpolated).
//
// No student name ever reaches this prompt (#99). Shown a roster, the model
// resolves first and re-cuts the transcript to fit the slots it has committed
// to — measured at 2/4 correct boundaries against 4/4 with class names only.
// It segments; Go resolves the names it hears.
//
// The wording is the one measured over 54 transcripts in research round 10,
// which reached 18/22 structurally clean with no tiling violation. Two rules
// carry that: the span arithmetic, stated before anything else, and the
// pronoun-continuation rule. Dropping either produced overlapping spans on
// note 694, which fails the whole job rather than degrading.
//
// The "none never takes an observation with it" rule is #110. The model swept
// a class-wide observation comma-joined to the teacher thinking aloud, straight
// after the header, into the header's "none" span, and it reached nobody — not
// even the unattributed log, which holds only child and group spans. Listing
// "thinking aloud" under "none" without qualification is what pulled the
// mixed run that way: the fixture went from red in 3/6 runs to green in
// 12/12, with span boundaries unchanged across the 22-transcript corpus
// (research round 11). The rule sits last on purpose: placed before the
// label rules it padded labels with pronouns on note 671 in 4/6 runs
// against 0/6 before and 1/6 here. #111 has since made splitLabel split a
// fused label and the matcher skip a padded pronoun, so that cost is mostly
// recovered; the placement stays because it is the arm measured green.
// One shift in the pinned baseline, not a defect: on pronoun_run_bleed two
// pronoun-only spans merge under "Polly", which the pronoun-continuation
// rule asks for and changes no note. Two others showed in one regeneration
// and not the next, on a model with no pinned temperature: a framing clause
// ("so today I wanted to talk about Emma") opening Emma's span, and a
// trailing "group" span absorbing the drill vocabulary after it ("Yes, they
// can. No, they can't."). That second one is the risk to watch: "the whole
// run keeps the observation's kind" pulls against the "none" bullet's
// taught vocabulary whenever the two are joined. Nothing pins it; tighten
// the rule if it shows up in the pinned baseline.
//
// The label rule shows the array shape ("Zachariah and Anaya did very well"
// is ["Zachariah", "Anaya"]) and says one name per item, also #110. Told
// only "verbatim as spoken", the model copied the phrase as one label in
// 13/24 probe runs on the three corpus notes that name two children at
// once; shown the shape, 0/24, with the corpus boundaries unchanged
// (round 11, arm D). splitLabel (spans.go, voice_note_process.go) has
// repaired a fused label since #111, notes and counters alike, so this
// changes no note today: it makes labels arrive in the shape the schema
// means, and leaves the regex a backstop rather than the mechanism.
// TestExtractTwoChildrenOneObservationLabelsEach pins it: red 6/6 on the
// old wording, green 6/6 on this one.
const extractionPromptPrefix = `You are segmenting a teacher's spoken notes about their
students.

The notes arrive as a numbered list of clauses, one per line, in the order the teacher
spoke them. A clause may be a partial sentence: the speech is split at commas as well as
full stops.

Return "spans": contiguous, non-overlapping ranges covering the whole list in order. Span
1 starts at clause 1, each following span starts at the previous span's end + 1, and the
last span ends at the final clause.

Each span has:
- "start" and "end": the first and last clause number, inclusive. A span of one clause has
  start == end.
- "kind":
  - "child" — the teacher is talking about one individual child.
  - "group" — a statement about the class as a whole, using a collective referent
    ("everyone", "all the kids", "the class", "they" meaning the whole group). A statement
    that names one child, or describes only one child, is NEVER "group", however it is
    joined to the rest of the sentence.
  - "none" — not an observation about children: the date, the class header, a greeting,
    vocabulary the children are being taught, thinking aloud that describes no child and
    no class.
- "spoken_labels": for a "child" span, the names the teacher speaks for it, each name
  verbatim as spoken. One name per list item, never two joined by "and" or a comma.
  Usually one item. Use several ONLY when the teacher makes the same observation about
  several children at once: "Zachariah and Anaya did very well" is ["Zachariah", "Anaya"],
  and the span belongs to both. If the observations differ between the children, they are
  separate spans, not one span with several labels. If the child's name is never spoken,
  use the pronoun the teacher uses — but never list a pronoun alongside a name in the same
  span: one child, one label. Empty list for "group" and "none".
- "summary": the observations in that span, rewritten as clear sentences.

Rules:
- A child span runs from where the teacher starts talking about that child to the clause
  before the teacher moves on. It usually opens with the child's name and then continues in
  pronouns; every pronoun clause after that name belongs to that child until the next child
  is named. Do NOT open a new span for a pronoun the teacher is still using for the same
  child.
- Copy "spoken_labels" from the clauses. Do NOT correct, complete, tidy or re-spell a name,
  even when it is obviously garbled — a corrected name matches the wrong child. If the
  teacher said "As a Xand", the label is "As a Xand".
- Never write a name that does not appear in the clauses.
- The summary uses ONLY the clauses in its own span. Never bring in an observation from
  another span, even an adjacent one.
- The summary keeps the teacher's voice: their vocabulary, their tone, first person if they
  used it. Clean up false starts, filler words and repetitions. Do NOT soften, formalise,
  add or editorialise — if the teacher said a child was "impossibly bad", the summary says
  "impossibly bad".
- "none" never takes an observation with it. The header span ends with the header itself:
  the first clause that describes the children opens a new span, even when it is spoken in
  the same breath. When an observation is joined to the teacher thinking aloud ("everyone
  was restless, might try the song earlier next time"), the whole run keeps the
  observation's kind — here "group" — never "none".

Also return "class_name": which class this recording is about. The transcript usually opens
with a spoken header — level name, weekday, time. Match it to one of:
`

// extractionPromptSuffix closes the prompt, after the class list.
//
// The decline is unconditional: a transcript with no spoken header returns ""
// however many classes are listed, and no note is created. Teachers state the
// class when they record, so this costs nothing they would otherwise get.
const extractionPromptSuffix = `
If the header is missing, or does not clearly identify exactly one of the classes listed,
return "" — an empty string — rather than guessing. A wrong class attaches a child's
observations to a different child; no class attaches them to nobody, which is recoverable.
`

// --- Report prompt templates ---

// reportPromptBase is the static opening of every report prompt.
const reportPromptBase = "You are a report card writer for a school teacher.\n" +
	"The student notes are the sole source of facts for the report.\n" +
	"Every observation, data field, and mark must come from the notes — " +
	"not from any examples.\n\n"

// reportSpecHeader is prefixed before the Level's mandatory Report
// Specification — the required structure, sections, and content for the
// report.
const reportSpecHeader = "## Report Specification (defines the report's required " +
	"structure, sections, and content — follow it)\n\n"

// reportInstructionsHeader prefixes the optional ad-hoc-instructions block.
const reportInstructionsHeader = "## Teacher's Instructions for This Report — " +
	"override the Report Specification where they conflict\n\n"

// reportNotesHeader prefixes the student notes section.
const reportNotesHeader = "## Student Notes (source of truth — all report content " +
	"must derive from these)\n"

// reportFeedbackHeader prefixes the feedback-on-previous-draft block.
const reportFeedbackHeader = "## Teacher Feedback on Previous Draft\n"

// reportTaskFooter is the static closing instructions in every report prompt.
const reportTaskFooter = "## Task\n" +
	"Write a report card narrative for this student based on the notes above.\n" +
	"Output the report as clean HTML (using <p>, <h3>, <ul>, <li> tags as appropriate).\n" +
	"Do not include <html>, <head>, or <body> wrapper tags — just the content HTML.\n" +
	"Only include structured Data fields (Absences, Marks, Frequency of use, etc.) if those\n" +
	"values are explicitly present in the notes.\n" +
	"Every statement in the report must be traceable to the notes. " +
	"Do not invent observations.\n"

// --- Computed hashes (populated at init) ---

// ExtractionPromptHash is the short hash of the extraction prompt templates.
// Stamped on every auto-extracted note row.
var ExtractionPromptHash string

// ReportPromptHash is the short hash of the report-generation prompt templates.
// Stamped on every generated report row.
var ReportPromptHash string

func init() {
	// The extraction hash covers both the prefix and suffix (the class list is
	// dynamic, so we use a sentinel to represent it).
	ExtractionPromptHash = hashPrompt(extractionPromptPrefix + "<<<classes>>>" + extractionPromptSuffix)

	// The report hash covers all static fragments concatenated with separators.
	// Dynamic parts (student name, notes, examples, feedback) are represented by
	// sentinels so the hash captures the structural template, not the data.
	reportTemplate := reportPromptBase +
		reportSpecHeader + "<<<reportInstructions>>>" +
		reportInstructionsHeader + "<<<instructions>>>" +
		reportNotesHeader + "<<<notes>>>" +
		reportFeedbackHeader + "<<<feedback>>>" +
		reportTaskFooter
	ReportPromptHash = hashPrompt(reportTemplate)
}

// hashPrompt returns the first 12 hex characters of SHA-256(PromptVersionTag + ":" + s).
func hashPrompt(s string) string {
	h := sha256.Sum256([]byte(PromptVersionTag + ":" + s))
	return hex.EncodeToString(h[:])[:12]
}
