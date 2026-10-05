#!/usr/bin/env bash
# The gate's record of one session: where the question it is holding stands,
# and what it has seen dropped. One small JSON file per session in a folder of
# the stand-in's own working folder, beside the switches rather than among
# them, so a switch folder holds switches alone. Sourced, never executed.
#
# The record holds three things. sent_back: how many times in a row the gate
# has held a reply and sent it back to the agent, since a reply last stopped.
# challenge: the challenge the agent has yet to answer — the kind's entry, the
# step it is at, and the question's form and sort as they stood when it was
# sent — or null. dropped: every proposal the agent dropped under a
# challenge, {question, kind}, kept for the session's end report.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The records' folder inside the stand-in's working folder.
RECORD_SUBFOLDER="sessions"

# How many times in a row the gate may send one question back before it hands
# it to the operator instead. A gate that holds a reply forever is a broken
# gate, and one nobody sees: the agent keeps answering it and the operator is
# never asked. Kept small, since each send-back is a whole reply of the
# agent's spent on one question.
SEND_BACK_LIMIT=3

# The record of a session the gate has not held anything for.
EMPTY_RECORD='{"sent_back":0,"challenge":null,"dropped":[]}'

# What a record must be to be read: anything else was not written by the gate,
# or not whole, and is refused rather than repaired.
RECORD_SHAPE='
  type == "object"
  and (.sent_back | type == "number" and . >= 0)
  and (.challenge | type == "null" or type == "object")
  and (.dropped | type == "array")'

# --- Transforms.

# The record file for a session, from the stand-in's working folder.
to_record_path() {
  printf '%s/%s/%s.json\n' "$1" "$RECORD_SUBFOLDER" "$2"
}

# The record with the question it was holding let go: a reply stopped, or a
# new turn of the operator's began. What was dropped stays.
with_chain_reset() {
  jq -c '.sent_back = 0 | .challenge = null' <<<"$1"
}

# The record with one more send-back counted.
with_send_back() {
  jq -c '.sent_back += 1' <<<"$1"
}

# True if the record has sent its question back as many times as it may.
is_send_back_spent() {
  jq -e --argjson limit "$SEND_BACK_LIMIT" '.sent_back >= $limit' >/dev/null <<<"$1"
}

# The record holding a challenge sent, at the step given, for the kind's entry
# and the question's form and sort given.
with_challenge() {
  jq -c --argjson entry "$2" --argjson step "$3" --argjson form "$4" --argjson sort "$5" \
    '.challenge = {entry: $entry, step: $step, form: $form, sort: $sort}' <<<"$1"
}

# The record with the challenge it holds moved on to the step given.
with_challenge_step() {
  jq -c --argjson step "$2" '.challenge.step = $step' <<<"$1"
}

# The challenge the record is waiting on an answer to, as JSON; nothing where
# there is none.
to_challenge() {
  jq -c '.challenge // empty' <<<"$1"
}

# The record with the challenged proposal noted as dropped and the question
# let go.
with_dropped() {
  with_chain_reset "$(jq -c '.dropped += [{question: .challenge.form.question, kind: .challenge.entry.name}]' <<<"$1")"
}

# --- Reads.

# A session's record, compact; the empty record where there is none yet. One
# that cannot be read, or is not a record, is refused on stderr with a
# non-zero status: a send-back count read as nothing would let the gate hold
# a reply past its limit.
read_session_record() {
  local file="$1" record
  [ -e "$file" ] || { printf '%s\n' "$EMPTY_RECORD"; return 0; }
  if ! record="$(jq -ce "select($RECORD_SHAPE)" "$file" 2>/dev/null)" || [ -z "$record" ]; then
    refuse_state_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$record"
}

# --- Writes.

# Put a session's record in place. Written to a hidden draft and moved over
# the old one, so nobody ever reads a half-written record; a record that
# cannot be written is refused, never left half-done.
write_session_record() {
  local file="$1" record="$2" dir draft
  dir="$(dirname "$file")"
  draft="$dir/.$(basename "$file").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { printf '%s\n' "$record" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_state_unwritable_note "$dir" >&2
    return 1
  fi
}
