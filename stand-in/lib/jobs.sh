#!/usr/bin/env bash
# Which model does each of the stand-in's reading jobs, and how long it may
# take, in one place. Sourced, never executed.
#
# A job that misreads moves up a model by changing its one line here, and the
# change is measured on the real past cases the stand-in keeps; nothing else
# names a model. Full names, not the CLI's aliases: an alias moves to the next
# release on its own, and a job's model changes only when someone says so.
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"

# The reader turns a finished reply into the fixed form: reading only, so the
# smallest model that reads it right.
READER_MODEL="claude-haiku-4-5"

# The sorter names a question's kind and its option's risks: a judgement
# against the preset's own words, a step up from reading.
SORTER_MODEL="claude-sonnet-5-5"

# The checker reads a question against every rule and convention entry, whole:
# a judgement against the project's own words, as the sorter's is.
CHECKER_MODEL="claude-sonnet-5-5"

# How long each job may take before it is refused. All three run inside one
# end-of-reply hook, one after the other, so together they stay inside the
# hook's own limit; a job stopped here is a refusal the gate can route, where
# a hook stopped by Claude Code says nothing. Measured 2026-10-05: a fresh
# reader call answered in under 8 s; the checker, handed every rule and
# convention entry (about 39 000 tokens), in 9 to 12 s.
READER_SECONDS=30
CHECKER_SECONDS=60
SORTER_SECONDS=40

# The time limit, in seconds, a project registers the gate with. It must
# outlast every job at its full limit, each with the grace a call that ignores
# its limit is given before it is killed: a gate Claude Code stops is one that
# answers nothing, and the operator would never learn that a reply went
# unjudged. A suite holds the jobs to it.
GATE_HOOK_SECONDS=180

# --- Transforms.

# The longest the gate's jobs can take together, in seconds.
derive_jobs_seconds() {
  local total=0 seconds
  for seconds in "$READER_SECONDS" "$CHECKER_SECONDS" "$SORTER_SECONDS"; do
    total=$((total + seconds + ASK_MODEL_KILL_AFTER))
  done
  printf '%s\n' "$total"
}
