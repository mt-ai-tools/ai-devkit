#!/usr/bin/env bash
# Which model does each of the stand-in's reading jobs, and how long it may
# take, in one place. Sourced, never executed.
#
# A job that misreads moves up a model by changing its one line here, and the
# change is measured on the real past cases the stand-in keeps; nothing else
# names a model. Full names, not the CLI's aliases: an alias moves to the next
# release on its own, and a job's model changes only when someone says so.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_JOBS:-}" ] || return 0
STAND_IN_LOADED_JOBS=1
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"

# The reader turns a finished reply into the fixed form: reading only, so the
# smallest model that reads it right. Moved up from Haiku 4.5 on 2026-10-06:
# it read a question that mentioned building a step as a step's report, and
# ran out of time on others; Sonnet read the same replies right six times of
# six, in about five seconds each.
READER_MODEL="claude-sonnet-5-5"

# The sorter names a question's kind and its option's risks: a judgement
# against the preset's own words.
SORTER_MODEL="claude-sonnet-5-5"

# The checker reads a question against every rule and convention entry, whole:
# a judgement against the project's own words, as the sorter's is.
CHECKER_MODEL="claude-sonnet-5-5"

# The matcher tells, on each ladder rung after the first, which of the first
# rung's options a reply now recommends, or that it chose something new or
# stopped asking. Rare, since only a ladder reaches it, and it is the read
# that will one day let a question pass without the operator: its own job,
# since the every-reply reader's relabelled options and missed restatements
# kept live ladders from ever holding (measured 2026-10-05, on Haiku 4.5).
MATCHER_MODEL="claude-sonnet-5-5"

# The summary reader tells the operator, in everyday words, how a question
# reached them: a fresh model, never the working agent, which would be
# summarising its own case.
SUMMARY_MODEL="claude-sonnet-5-5"

# The round reader lays out, in everyday words, every decision of a round of
# questions when the agent asks to start building: a fresh model, never the
# working agent, which would make its own choices read better; the summary
# reader's model, since it retells as that one does.
ROUND_MODEL="claude-sonnet-5-5"

# The closing reader reads a reply to one look of the closing loop into its
# findings, each with the sort the agent gave it: reading only, as the reader
# does, so the reader's model. Read alone on a look's reply, as the matcher is
# on a rung, since what that reply is for is known before it is read.
CLOSING_MODEL="claude-sonnet-5-5"

# The cold second reading of a question whose answer moved on the ladder:
# the advisor's own command, the operator's own last rung, which they reach
# for when an answer will not settle. A stronger model than any reader, since
# it works the question itself rather than reading a reply; it never decides.
READING_MODEL="claude-fable-5-1"

# The case-writer turns one answered question of a finished brief into a test
# case, cleaned to meaning. Opus rather than a reader's model (settled
# 2026-10-06; Haiku was the first pick): a misread case skews the score that
# decides whether a kind may go silent, and nobody rereads the cases.
CASE_MODEL="claude-opus-5-5"

# The secret check reads one case whole, in context, for anything secret a
# scanner cannot see by its shape: a password in plain words, personal data.
# The case-writer's model, since a secret it misses is committed and seen,
# and a seen secret is rotated, never taken back.
SECRET_MODEL="claude-opus-5-5"

# The tools the reading may use: to read and search the project, never to
# change it. The advisor works a question against the code, and a reading
# with no code in reach is an opinion the operator could form alone; one
# that could write would be acting, which a reading never does.
READING_TOOLS="Read,Grep,Glob"

# How long each job may take before it is refused. The jobs of one stop run
# inside one end-of-reply hook, one after the other, so together they stay
# inside the hook's own limit; a job stopped here is a refusal the gate can
# route, where a hook stopped by Claude Code says nothing. Measured: the
# Sonnet reader answers in about 5 s (2026-10-06); the checker, handed every
# rule and convention entry (about 39 000 tokens), took 9 to 12 s before its
# entries were sent apart to be cached (2026-10-05), and is not measured
# since.
READER_SECONDS=30
CHECKER_SECONDS=60
SORTER_SECONDS=40
MATCHER_SECONDS=40
SUMMARY_SECONDS=40
ROUND_SECONDS=40
CLOSING_SECONDS=40
# The reading reads code with tools, turn after turn, so it is given what its
# stop has left beside the matcher. Measured 2026-10-05: 55 to 95 s.
READING_SECONDS=120
# The case-writer and the secret check run in a command the agent runs once
# the brief is finished, never in a stop of the gate (settled 2026-10-07): a
# brief's cases, one Opus call and one check each, outgrow any stop's limit.
# So neither is held to the hook's limit below, and each is given room for a
# whole exchange. Measured 2026-10-07 on two real answered questions: both
# cases written and checked, every call together, in 29 s.
CASE_SECONDS=180
SECRET_SECONDS=90

# The time limit, in seconds, a project registers the gate with. It must
# outlast every job at its full limit, each with the grace a call that ignores
# its limit is given before it is killed: a gate Claude Code stops is one that
# answers nothing, and the operator would never learn that a reply went
# unjudged. A suite holds the jobs to it. Raised from 180 on 2026-10-07, when
# the summary moved into the stop that brings a question to the operator: an
# answer that moved again then runs the matcher, the cold reading and the
# summary in one stop, 225 s at their limits. Raised rather than any job's
# limit trimmed or the reading dropped to fit (settled 2026-10-07); whole
# minutes, as before.
GATE_HOOK_SECONDS=240

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
# answer moved again, the cold reading, the one stop that knows whether it
# did, which is the only case a reading is run for (settled 2026-10-06).
#
# A question reaches the operator in the stop that decides it is theirs
# (settled 2026-10-07: no round asks the agent to retell it first), so that
# stop also runs the summary and writes the question log's line, which may
# wait its turn at the log's lock: on a question's first stop, after the
# reader, the checker and the sorter; on a reply to its kind's challenge,
# after the reader alone; on a rung's stop, after the matcher; and where the
# answer moved again, after the matcher and the reading, the longest stop
# there is. Moving any job onto another job's stop is a change to this
# budget first.
#
# A finished step's report makes one stop of its own (settled 2026-10-06, the
# step go): the reader, then the sorter labelling its problems, then the log's
# line, all in the stop that read the report, since the go, or why it is the
# operator's, is decided there and nowhere later. It runs no checker, which
# reads questions alone, and no summary: the report reaches the operator as
# the agent wrote it, in front of them already, so nothing is asked of a
# model to tell it again. Its stop stays below the question's first, which
# runs the checker beside the same reader and sorter.
#
# A question settled without the operator, once its kind is through the
# trial (settled 2026-10-06), is logged in the stop that settles it, since the
# agent is told to go on there and nothing later would write the line: a kind
# accepted as it stands, on the question's first stop, beside the reader, the
# checker and the sorter; an answer that held, on its last rung's stop, beside
# the matcher alone. Each adds one wait at the log's lock and no model.
#
# A request to start building makes one stop of its own (settled 2026-10-06,
# the round's decisions laid out): the reader, then the round reader writing
# every decision of the round from the question log, then the request's own
# line. The log is read before the line is written, each under its own hold
# of the lock, so the stop may wait at the lock twice. It runs in the stop
# that read the request, since the list must reach the operator with it, and
# no other stop knows the round is over.
#
# The closing loop (settled 2026-10-06) adds no model to the stop that starts
# it: a reply saying the work is done, or a step's report naming no next step,
# is read by the reader alone, and the first look, or "is the whole brief
# done?", is sent from that stop. Each look's reply makes a stop of its own:
# the closing reader alone, then the organizer and git asked where each
# finding to be fixed in passing lies, which ask no model. The second look's
# stop also reads the log to count the rounds and writes the round's line,
# each under its own hold of the lock, so it may wait at the lock twice.
#
# A session woken from a wait (settled 2026-10-06) is sent the look around
# from the mark alone, before the reply is read, so that stop asks no model;
# its report's stop runs the reader alone, as a reply asking nothing does.
derive_jobs_seconds() {
  local stop longest=0
  for stop in \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$CHECKER_SECONDS" "$SORTER_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$MATCHER_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$MATCHER_SECONDS" "$READING_SECONDS" "$SUMMARY_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$SORTER_SECONDS") + LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$READER_SECONDS" "$ROUND_SECONDS") + 2 * LOG_LOCK_SECONDS))" \
    "$(($(derive_stop_seconds "$CLOSING_SECONDS") + 2 * LOG_LOCK_SECONDS))"; do
    [ "$stop" -le "$longest" ] || longest="$stop"
  done
  printf '%s\n' "$longest"
}
