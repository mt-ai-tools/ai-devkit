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

# The cold second reading of a question whose answer moved on the ladder:
# the advisor's own command, the operator's own last rung, which they reach
# for when an answer will not settle. A stronger model than any reader, since
# it works the question itself rather than reading a reply; it never decides.
READING_MODEL="claude-fable-5-1"

# The tools the reading may use: to read and search the project, never to
# change it. The advisor works a question against the code, and a reading
# with no code in reach is an opinion the operator could form alone; one
# that could write would be acting, which a reading never does.
READING_TOOLS="Read,Grep,Glob"

# How long each job may take before it is refused. The jobs of one stop run
# inside one end-of-reply hook, one after the other, so together they stay
# inside the hook's own limit; a job stopped here is a refusal the gate can
# route, where a hook stopped by Claude Code says nothing. Measured
# 2026-10-05: a fresh reader call answered in under 8 s; the checker, handed
# every rule and convention entry (about 39 000 tokens), in 9 to 12 s.
READER_SECONDS=30
CHECKER_SECONDS=60
SORTER_SECONDS=40
# The reading reads code with tools, turn after turn, so it is given what the
# last rung's stop has left beside the reader.
READING_SECONDS=120

# The time limit, in seconds, a project registers the gate with. It must
# outlast every job at its full limit, each with the grace a call that ignores
# its limit is given before it is killed: a gate Claude Code stops is one that
# answers nothing, and the operator would never learn that a reply went
# unjudged. A suite holds the jobs to it.
GATE_HOOK_SECONDS=180

# --- Transforms.

# The longest the jobs of the given limits can take together, one after the
# other, in seconds, each with its grace before it is killed.
derive_stop_seconds() {
  local total=0 seconds
  for seconds in "$@"; do
    total=$((total + seconds + ASK_MODEL_KILL_AFTER))
  done
  printf '%s\n' "$total"
}

# The longest any one stop's jobs can take together, in seconds. A question's
# first stop runs the reader, the checker and the sorter; each later rung of
# the ladder is a stop of its own that runs the reader alone, and only the
# last adds the reading. The reading never shares a stop with the checker or
# the sorter, so the budget is the longer of the two stops, not their sum.
derive_jobs_seconds() {
  local first last
  first="$(derive_stop_seconds "$READER_SECONDS" "$CHECKER_SECONDS" "$SORTER_SECONDS")"
  last="$(derive_stop_seconds "$READER_SECONDS" "$READING_SECONDS")"
  printf '%s\n' "$((first > last ? first : last))"
}
