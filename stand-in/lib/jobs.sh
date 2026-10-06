#!/usr/bin/env bash
# Which model does each of the stand-in's reading jobs, and how long it may
# take, in one place. Sourced, never executed.
#
# A job that misreads moves up a model by changing its one line here, and the
# change is measured on the real past cases the stand-in keeps; nothing else
# names a model. Full names, not the CLI's aliases: an alias moves to the next
# release on its own, and a job's model changes only when someone says so.
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"

# The reader turns a finished reply into the fixed form: reading only, so the
# smallest model that reads it right.
READER_MODEL="claude-haiku-4-5"

# The sorter names a question's kind and its option's risks: a judgement
# against the preset's own words, a step up from reading.
SORTER_MODEL="claude-sonnet-5-5"

# The checker reads a question against every rule and convention entry, whole:
# a judgement against the project's own words, as the sorter's is.
CHECKER_MODEL="claude-sonnet-5-5"

# The matcher tells, on each ladder rung after the first, which of the first
# rung's options a reply now recommends, or that it chose something new or
# stopped asking. Rare, since only a ladder reaches it, and it is the read
# that will one day let a question pass without the operator: a step up from
# the every-reply reader, whose relabelled options and missed restatements
# kept live ladders from ever holding (measured 2026-10-05).
MATCHER_MODEL="claude-sonnet-5-5"

# The summary reader tells the operator, in everyday words, how a question
# reached them: a fresh model, never the working agent, which would be
# summarising its own case.
SUMMARY_MODEL="claude-sonnet-5-5"

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
MATCHER_SECONDS=40
SUMMARY_SECONDS=40
# The reading reads code with tools, turn after turn, so it is given what its
# stop has left beside the matcher. Measured 2026-10-05: 55 to 95 s.
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

# The longest any one stop's jobs can take together, in seconds: the longest
# of the stops a question can make, never their sum, since each is a hook run
# of its own. A question's first stop runs the reader, the checker and the
# sorter. Each ladder rung after the first runs the matcher alone, the reader
# no longer needed there, and so does the bigger look around's reply. The
# reply to "are you sure?" asked once more runs the matcher and, where the
# answer moved again, the cold reading; the plain retelling's reply, always
# the last stop before the operator, runs the reader for the retold question
# and the summary, and writes the question log's line, which may wait its
# turn at the log's lock.
#
# The three jobs of a changed answer's message — matcher, reading and
# summary — cannot share one stop: at their limits they take 215 s, past the
# hook's 180. Each rides a stop the question makes anyway, so no stop is
# added and no limit raised. The reading rides the second "are you sure?"'s
# stop, the one stop that knows whether the answer moved again, which is the
# only case a reading is run for (settled 2026-10-06); the bigger look's stop
# is left the matcher alone, with room it does not need. Moving any of them
# onto another job's stop is a change to this budget first.
#
# A finished step's report makes one stop of its own (settled 2026-10-06, the
# step go): the reader, then the sorter labelling its problems, then the log's
# line, all in the stop that read the report, since the go, or why it is the
# operator's, is decided there and nowhere later. It runs no checker, which
# reads questions alone, and no summary or retelling: the report reaches the
# operator as the agent wrote it, in front of them already, so nothing is
# asked of a model to tell it again. Its stop stays below the question's
# first, which runs the checker beside the same reader and sorter.
derive_jobs_seconds() {
  local stop longest=0
  for stop in \
    "$(derive_stop_seconds "$READER_SECONDS" "$CHECKER_SECONDS" "$SORTER_SECONDS")" \
    "$(derive_stop_seconds "$MATCHER_SECONDS")" \
    "$(derive_stop_seconds "$MATCHER_SECONDS" "$READING_SECONDS")" \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$SORTER_SECONDS") + LOG_LOCK_SECONDS))"; do
    [ "$stop" -le "$longest" ] || longest="$stop"
  done
  printf '%s\n' "$longest"
}
