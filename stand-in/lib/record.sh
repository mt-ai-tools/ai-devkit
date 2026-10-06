#!/usr/bin/env bash
# The gate's record of one session: where the question it is holding stands,
# and what it has seen dropped. One small JSON file per session in a folder of
# the stand-in's own working folder, beside the switches rather than among
# them, so a switch folder holds switches alone. Sourced, never executed.
#
# The record holds, for the question the gate is holding: sent_back, how
# many times in a row it has sent the question back to the agent to rethink
# it, since a reply last stopped. challenge: the challenge the agent has yet
# to answer — the kind's entry, the step it is at, and the question's form and
# sort as they stood when it was sent — or null. ladder: the question on the
# ladder — its words, its kind, the lines the operator is to be shown beside
# it, the first rung's options and recommendation, and the matcher's pick of
# each later reply in order — or null; never held together with a challenge.
# round: the fixed round whose reply the gate is waiting for, or null.
# rounds_sent: every fixed round sent for the question. asked: the question
# as the reader last read it, its options and recommendation, or null.
# operator: the message waiting for the agent's plain retelling, in parts, or
# null. exchange: every reply the gate held and every message it sent the
# agent over the question, in order, each {from, text}, whole.
#
# And, across questions: dropped, every proposal the agent dropped under a
# challenge, {question, kind}, kept for the session's end report.
#
# The question log is written from this record, just before a question is let
# go: everything it holds of the exchange, the question as asked and the
# answers is its source until then, and is gone after.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The records' folder inside the stand-in's working folder.
RECORD_SUBFOLDER="sessions"

# How many times in a row the gate may send one question back before it hands
# it to the operator instead. A gate that holds a reply forever is a broken
# gate, and one nobody sees: the agent keeps answering it and the operator is
# never asked. Kept small, since each send-back is a whole reply of the
# agent's spent on one question.
SEND_BACK_LIMIT=3

# Who a turn of the exchange is from.
EXCHANGE_AGENT="agent"
EXCHANGE_STAND_IN="stand-in"

# The record of a session the gate has not held anything for.
EMPTY_RECORD='{"sent_back":0,"challenge":null,"ladder":null,"round":null,"rounds_sent":[],"asked":null,"operator":null,"exchange":[],"dropped":[]}'

# What a record must be to be read: anything else was not written by the gate,
# or not whole, and is refused rather than repaired.
RECORD_SHAPE='
  type == "object"
  and (.sent_back | type == "number" and . >= 0)
  and (.challenge | type == "null" or type == "object")
  and (.ladder | type == "null"
    or (type == "object" and (.first | type == "object") and (.picks | type == "array")))
  and (.round | type == "null" or type == "string")
  and (.rounds_sent | type == "array")
  and (.asked | type == "null" or type == "object")
  and (.operator | type == "null" or type == "object")
  and (.exchange | type == "array")
  and (.dropped | type == "array")'

# --- Transforms.

# The record file for a session, from the stand-in's working folder.
to_record_path() {
  printf '%s/%s/%s.json\n' "$1" "$RECORD_SUBFOLDER" "$2"
}

# The record with the question it was holding let go: a reply stopped, or a
# new turn of the operator's began. A ladder in progress goes with it, as a
# challenge, a round and the exchange do: a new turn may have changed what the
# agent is asking, and rungs climbed before it would be compared with answers
# to something else. What was dropped stays.
with_chain_reset() {
  jq -c '.sent_back = 0 | .challenge = null | .ladder = null | .round = null | .rounds_sent = []
    | .asked = null | .operator = null | .exchange = []' <<<"$1"
}

# The record with one more send-back counted.
with_send_back() {
  jq -c '.sent_back += 1' <<<"$1"
}

# True if the record has sent its question back as many times as it may.
is_send_back_spent() {
  jq -e --argjson limit "$SEND_BACK_LIMIT" '.sent_back >= $limit' >/dev/null <<<"$1"
}

# The record with the fixed round named sent: its reply awaited, and the round
# noted as sent for the question. Never counted as a send-back.
with_round() {
  jq -c --arg name "$2" '.round = $name | .rounds_sent += [$name]' <<<"$1"
}

# True if the fixed round named was sent for the question the record holds.
is_round_sent() {
  jq -e --arg name "$2" 'any(.rounds_sent[]; . == $name)' >/dev/null <<<"$1"
}

# The fixed round whose reply the record awaits; nothing where there is none.
to_round() {
  jq -r '.round // empty' <<<"$1"
}

# The record with one more turn of the exchange, from whoever is named, its
# text whole. The text reaches jq through a file descriptor, never as an
# argument: a whole reply can outgrow what one argument may hold.
with_turn() {
  jq -c --arg from "$2" --rawfile text <(printf '%s' "$3") \
    '.exchange += [{from: $from, text: $text}]' <<<"$1"
}

# The exchange the record holds, as a JSON array of {from, text}.
to_exchange() {
  jq -c '.exchange' <<<"$1"
}

# The record holding the question as the reader's form given has it: its
# words, its options and its recommendation.
with_asked() {
  jq -c --argjson form "$2" '.asked = ($form | {question, options, recommended})' <<<"$1"
}

# The question as the record last had it read, as JSON; nothing where there
# is none.
to_asked() {
  jq -c '.asked // empty' <<<"$1"
}

# The record holding the operator's message in parts, waiting for the agent's
# plain retelling.
with_operator() {
  jq -c --argjson parts "$2" '.operator = $parts' <<<"$1"
}

# The operator's message the record holds in parts, as JSON; nothing where
# there is none.
to_operator_parts() {
  jq -c '.operator // empty' <<<"$1"
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

# The record holding a question put on the ladder: its words, its kind's
# name, the lines the operator is to be shown beside it, and its first rung's
# answer, {options, recommended}. The question's challenge, if it had one, is
# over.
with_ladder() {
  jq -c --arg question "$2" --arg kind "$3" --arg lines "$4" --argjson first "$5" \
    '.challenge = null | .ladder = {question: $question, kind: $kind, lines: $lines, first: $first, picks: []}' <<<"$1"
}

# The record with the matcher's pick of one more reply on the ladder it holds.
with_ladder_pick() {
  jq -c --argjson pick "$2" '.ladder.picks += [$pick]' <<<"$1"
}

# The ladder the record holds, as JSON; nothing where there is none.
to_ladder() {
  jq -c '.ladder // empty' <<<"$1"
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
