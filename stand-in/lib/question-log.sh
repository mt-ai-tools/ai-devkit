#!/usr/bin/env bash
# The question log: one whole JSON line per question the gate let go, in a
# file of the stand-in's own working folder, kept on this machine alone since
# it holds raw agent text and the operator's answers. Every session appends to
# the one file, and the operator's answer is written into its question's line
# afterwards. Sourced, never executed.
#
# Each line holds: id, a stable random id; number, the short handle the
# operator reopens it by, one more than the line before; when, in UTC;
# session; briefs, those the session held as the line was written, empty for
# none and null where they could not be told; question, as first asked;
# retold, the agent's plain retelling, or null; kind, unsure and risks, from
# the sort it was routed on; checks, every checker's answer; ladder, its first
# answer and the matcher's picks, or null; exchange, every turn between the
# stand-in and the agent, whole; outcome; reasons, why it came to the
# operator, a line each; approved, the option the stand-in approved or would
# have; summary, the summary reader's parts as the operator was shown them,
# and reading, the cold second reading, each null where none was written;
# step, for a finished step's report, what it said of its problems, its proof
# and its next step and what the sorter found major, null for a question;
# round, for a request to start building, every decision of the round as the
# operator was shown it, each {number, by, decision}, null otherwise; closing,
# for a round of the closing loop, its number and every finding of its two
# looks as code checked it, null otherwise; dropped, for a proposal the agent
# dropped under its kind's challenge, the options it offered and the one it
# recommended, {options, recommended}, null otherwise; answer, the
# operator's, empty until they give one.
#
# A step's report is logged like a question, its decision being whether to go
# on: the go the stand-in would give is counted toward its kind's trial as a
# held answer is, and one it gave is listed and reopened as a settled one is.
# So is a request to start building, its decision being whether to build on
# the round as listed: its line is where the session's next round begins, and
# the numbers its list holds are ones the operator may reopen. So is a round
# of the closing loop, its decision being whether anything is left that
# belongs to the brief: its line is how the rounds are counted, and what the
# end report lists as fixed in passing, dropped and parked. So is a proposal
# the agent dropped under its kind's challenge, its decision being the one it
# let go: the line is the drop's only home (settled 2026-10-06), so the end
# report lists it and the operator can reopen it, though it never reached
# them.
#
# Every write takes one lock, a file of its own beside the log: two sessions
# letting a question go at once must leave two whole lines, and bash writes a
# long line in several pieces (measured 2026-10-06: one 30 000-byte line went
# out in 13 writes, and two sessions appending 100 such lines each, unlocked,
# left a torn line), so no single append is atomic at the sizes an exchange
# reaches. The lock is never the log file itself: an answer is written by
# moving a new file over the log, and a writer waiting on the old file's lock
# would then append to a file nobody reads. Readers take it shared, so none
# reads a line half-written.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_QUESTION_LOG:-}" ] || return 0
STAND_IN_LOADED_QUESTION_LOG=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The log's folder inside the stand-in's working folder, its file, and its
# lock's file.
LOG_SUBFOLDER="log"
LOG_FILE_NAME="questions.jsonl"
LOG_LOCK_NAME=".questions.jsonl.lock"

# How long a write or a read waits for another session's hold on the log
# before it is refused. A write holds it only for one line, or one copy of
# the log; a lock still held after this long is held by something broken, and
# the gate's own stop must not wait it out.
LOG_LOCK_SECONDS=10

# How a question ended: brought to the operator; brought to them though its
# answer held, while its kind is on trial; settled without them; for a round
# of the closing loop, handed back to the agent with what to do next, which
# never awaits the operator's answer and is never theirs to reopen; or
# dropped by the agent under its kind's challenge, which never reached them,
# so awaits no answer either, but is theirs to reopen.
OUTCOME_TO_OPERATOR="to-operator"
OUTCOME_WOULD_HAVE_APPROVED="would-have-approved"
OUTCOME_SETTLED="settled"
OUTCOME_TO_AGENT="to-agent"
OUTCOME_DROPPED="dropped"

# --- Transforms.

# The log's folder, from the stand-in's working folder.
to_log_dir() {
  printf '%s/%s\n' "$1" "$LOG_SUBFOLDER"
}

# The log's file, from its folder.
to_log_path() {
  printf '%s/%s\n' "$1" "$LOG_FILE_NAME"
}

# The line a question is logged as, from the gate's record of it and the
# operator's message in parts, as record.sh and operator-message.sh keep them,
# and the details only the moment of letting it go knows, as JSON: id, when,
# session, briefs, retold (empty for none), reasons (one per line) and
# summary (the summary's parts, null for none); and, for a step's report
# alone, kind, outcome and step, which no record holds, since the report is
# let go in the stop that read it; for a request to start building, outcome
# and round, for the same reason; for a round of the closing loop, outcome
# and closing; for a proposal dropped under a challenge, outcome and dropped;
# and for a question settled without the operator, its outcome. Its number
# is given as the line is written, and its answer is empty until the operator
# gives one. The record reaches jq on stdin, never as an argument: its
# exchange can outgrow what one may hold.
to_log_line() {
  local record="$1" parts="$2" details="$3"
  jq -c --argjson parts "$parts" --argjson details "$details" \
    --arg held "$OUTCOME_WOULD_HAVE_APPROVED" --arg operator "$OUTCOME_TO_OPERATOR" '
    def text_or_null: if . == null or . == "" then null else . end;
    {
      id: $details.id,
      number: null,
      when: $details.when,
      session: $details.session,
      briefs: $details.briefs,
      question: $parts.question,
      retold: ($details.retold | text_or_null),
      kind: ($details.kind // (if .sort then .sort.kind elif .ladder then .ladder.kind else null end)),
      unsure: (if .sort then .sort.unsure else null end),
      risks: (if .sort then .sort.risks else [] end),
      checks: .checks,
      ladder: (if .ladder then .ladder | {first, picks} else null end),
      exchange: .exchange,
      outcome: ($details.outcome // (if ($parts.approved // "") != "" then $held else $operator end)),
      reasons: ($details.reasons | split("\n") | map(select(. != ""))),
      approved: ($parts.approved // ""),
      summary: $details.summary,
      reading: ($parts.reading_text | text_or_null),
      step: ($details.step // null),
      round: ($details.round // null),
      closing: ($details.closing // null),
      dropped: ($details.dropped // null),
      answer: ""
    }' <<<"$record"
}

# The line with its number given.
with_log_number() {
  jq -c --argjson number "$2" '.number = $number' <<<"$1"
}

# The number the next line takes, given the log's last line, empty for a log
# with none: one more than the last, so a number once given is never given
# again, whatever the lines before it.
derive_next_number() {
  [ -n "$1" ] || { printf '1\n'; return 0; }
  jq -e '.number | if type == "number" then . + 1 else error("no number") end' <<<"$1"
}

# True if the line is a question still waiting for the operator's answer: it
# reached them, and they have not answered it yet. A settled question never
# reached them, so nothing they type answers it.
is_awaiting_answer() {
  jq -e --arg held "$OUTCOME_WOULD_HAVE_APPROVED" --arg operator "$OUTCOME_TO_OPERATOR" \
    '(.outcome == $operator or .outcome == $held) and .answer == ""' >/dev/null <<<"$1"
}

# --- Reads.

# The time now, in UTC, as the log writes it.
get_log_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}

# A fresh id for a line: random, so two sessions writing at once never mint
# the same, and stable, since nothing ever changes it.
mint_log_id() {
  od -An -N8 -tx1 /dev/urandom | tr -d ' \n'
}

# Run the call given under the log's lock, shared or exclusive as the flag
# given says (-s or -x), in the folder given; its status is the call's. A
# lock that cannot be opened, or is not had in time, is refused on stderr
# with a non-zero status, and the call is never run. Closing the descriptor
# is what lets the lock go.
run_under_log_lock() {
  local dir="$1" mode="$2" fd status=0
  shift 2
  if ! { exec {fd}>>"$dir/$LOG_LOCK_NAME"; } 2>/dev/null; then
    refuse_log_unwritable_note "$dir" >&2
    return 1
  fi
  if ! flock "$mode" -w "$LOG_LOCK_SECONDS" "$fd"; then
    exec {fd}>&-
    refuse_log_busy_note "$dir" "$LOG_LOCK_SECONDS" >&2
    return 1
  fi
  "$@" || status=$?
  exec {fd}>&-
  return "$status"
}

# Every line of the log, as written; nothing where there is no log yet, which
# is the state of a project the gate never let a question go in. A line that
# is not one whole JSON object is refused, as the whole log is: a list built
# around a torn line would show the operator part of what happened as all of
# it.
list_log_lines() {
  local dir="$1" file
  file="$(to_log_path "$dir")"
  [ -s "$file" ] || return 0
  run_under_log_lock "$dir" -s read_log_lines "$file"
}

# The log's lines, checked whole; the call list_log_lines runs under the lock.
read_log_lines() {
  local file="$1" lines
  if ! lines="$(jq -ce 'if type == "object" then . else error("not a line") end' "$file" 2>/dev/null)"; then
    refuse_log_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$lines"
}

# --- Writes.

# Add a question's line to the log, given the folder and the line, with the
# number after the last line's. The number is read and the line written under
# one hold of the lock, so no two lines ever share one.
append_log_line() {
  local dir="$1" line="$2"
  if ! mkdir -p "$dir" 2>/dev/null; then
    refuse_log_unwritable_note "$dir" >&2
    return 1
  fi
  run_under_log_lock "$dir" -x append_numbered_line "$(to_log_path "$dir")" "$line"
}

# The line numbered and written; the call append_log_line runs under the
# lock.
append_numbered_line() {
  local file="$1" line="$2" last="" number
  [ ! -s "$file" ] || last="$(tail -n 1 "$file")"
  if ! number="$(derive_next_number "$last" 2>/dev/null)"; then
    refuse_log_unreadable_note "$file" >&2
    return 1
  fi
  if ! { printf '%s\n' "$(with_log_number "$line" "$number")" >>"$file"; } 2>/dev/null; then
    refuse_log_unwritable_note "$(dirname "$file")" >&2
    return 1
  fi
}

# Write the operator's answer into the session's last question, given the
# folder, the session and the answer, where that question is waiting for
# one; anything else is left as it is: the session's last line already
# answered, settled, or no line at all.
#
# The line itself is rewritten, rather than an answer line added beside it,
# so the log stays one whole line per question and every reader reads each
# question from one line, joining nothing. The log is written whole to a
# draft beside it and moved over it, so a reader sees the old log or the new
# one and never half of either; the cost, a copy of the log per answer, is
# one the operator's own typing paces.
write_log_answer() {
  local dir="$1" session="$2" answer="$3" file
  file="$(to_log_path "$dir")"
  [ -e "$file" ] || return 0
  run_under_log_lock "$dir" -x write_answer_line "$file" "$session" "$answer"
}

# The answer written into the session's last line where it waits for one; the
# call write_log_answer runs under the lock. Every line goes through jq, which
# writes them back as jq wrote them, so only the answered line changes.
write_answer_line() {
  local file="$1" session="$2" answer="$3" lines last draft
  # Read whole, then cut: piped straight into tail, a log jq refused would
  # read as one with no line for the session, wherever pipefail is off.
  if ! lines="$(jq -c --arg session "$session" 'select(.session == $session)' "$file" 2>/dev/null)"; then
    refuse_log_unreadable_note "$file" >&2
    return 1
  fi
  [ -n "$lines" ] || return 0
  last="$(tail -n 1 <<<"$lines")"
  is_awaiting_answer "$last" || return 0
  draft="$(dirname "$file")/.$(basename "$file").$$"
  if ! jq -c --arg id "$(jq -r '.id' <<<"$last")" --rawfile answer <(printf '%s' "$answer") \
    'if .id == $id then .answer = $answer else . end' "$file" >"$draft" 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_log_unwritable_note "$(dirname "$file")" >&2
    return 1
  fi
}
