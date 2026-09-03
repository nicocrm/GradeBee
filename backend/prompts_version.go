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
    thinking aloud, vocabulary the children are being taught.
- "spoken_labels": for a "child" span, the names the teacher speaks for it, verbatim as
  spoken. Usually one. Use several ONLY when the teacher makes the same observation about
  several children at once ("Zachariah and Anaya did very well") — then the span belongs to
  all of them. If the observations differ between the children, they are separate spans,
  not one span with several labels. If the child's name is never spoken, use the pronoun
  the teacher uses — but never list a pronoun alongside a name in the same span: one child,
  one label. Empty list for "group" and "none".
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
