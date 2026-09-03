/**
 * assemble.js — promptfoo output transform for the extraction config.
 *
 * The extraction model no longer returns notes. It returns clause-index spans
 * and a class name; Go turns those into per-student notes (#99). This transform
 * runs that same Go code — `eval-cli assemble-extract`, which calls
 * `AssembleNotes` — on the model's output, so the eval grades the notes a
 * teacher actually gets rather than the raw segmentation.
 *
 * It is wired as `defaultTest.options.transform` in
 * promptfooconfig.extract.yaml, which promptfoo applies to the provider's
 * output before any assertion sees it. The shape it returns is the one the
 * scorer and every fixture already read: `{students:[{name, class_name,
 * quoted_text}], ...}`, with each span's summary as `quoted_text`.
 *
 * No network call — the model has already run by this point.
 *
 * @param {string|object} output - The model's spans JSON.
 * @param {{ vars: object }} context - promptfoo transform context.
 * @returns {string} JSON the extraction scorer can read.
 */
'use strict';

const path = require('path');
const { spawnSync } = require('child_process');

const BINARY = path.resolve(__dirname, '..', '..', 'bin', 'eval-cli');

module.exports = (output, context) => {
  const vars = (context && context.vars) || {};
  const request = JSON.stringify({
    // Only the three vars the task needs. Passing vars.task through would
    // override config.task in eval-cli and re-run the prompt builder.
    vars: {
      transcript: vars.transcript,
      classes: vars.classes,
      response: typeof output === 'string' ? output : JSON.stringify(output),
    },
    config: { task: 'assemble-extract' },
  });

  // The model's own output rides along in both branches below, so a red row in
  // baseline.json says whether the model or Go dropped a note. Without it the
  // only way to find out is to call the model again by hand.
  const modelOutput = typeof output === 'string' ? tryParse(output) : output;

  const run = spawnSync(BINARY, [request], { encoding: 'utf8' });

  // A broken harness must not look like a result. `multi_class` passes on an
  // empty student list, so an unbuilt or unreachable binary would score it
  // PASS. Throw instead: promptfoo records the row as an error.
  if (run.error) {
    throw new Error(`${BINARY}: ${run.error.message} (run "make bin/eval-cli")`);
  }

  // A non-zero exit is Go rejecting the model's output — a span tiling
  // violation, or a response it could not parse. That is a real zero, not a
  // broken harness: return the empty shape so the scorer scores the case and
  // the row stays comparable against the baseline.
  if (run.status !== 0) {
    return JSON.stringify({
      students: [],
      unattributed: [],
      assemble_error: (run.stderr || '').trim(),
      model_output: modelOutput,
    });
  }

  // The scorer ignores keys it does not know, so model_output rides along here
  // as well.
  const assembled = JSON.parse(run.stdout);
  assembled.model_output = modelOutput;
  return JSON.stringify(assembled);
};

// tryParse keeps the raw string when the model returned something unparseable —
// which is itself the answer on an assemble_error row.
function tryParse(s) {
  try {
    return JSON.parse(s);
  } catch {
    return s;
  }
}
