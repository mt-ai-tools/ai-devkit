#!/usr/bin/env bash
# The gate's record of one session: where the question it is holding stands,
# and whether the operator reopened a decision the session's next question
# must bring them. One small JSON file per session in a folder of the
# stand-in's own working folder, beside the switches rather than among them,
# so a switch folder holds switches alone; removed with the switch when the
# session ends, since nothing in it is worth anything once no reply of the
# session's can reach the gate. Sourced, never executed.
#
# The record holds, for the question the gate is holding: sent_back, how
# many times in a row it has sent the question back to the agent to rethink
# it, since a reply last stopped. challenge: the challenge the agent has yet
# to answer — the kind's entry, the step it is at, and the question's form and
# sort as they stood when it was sent — or null. ladder: the question on the
# ladder — its words, its kind, the route it climbs (the ladder, or the light
# check's one challenge), the lines the operator is to be shown beside it, the
# first rung's options and recommendation, and the matcher's pick of each
# later reply in order — or null; never held together with a challenge.
# round: the fixed round whose reply the gate is waiting for, or null.
# rounds_sent: every fixed round sent for the question. asked: the question
# as the reader last read it, its options and recommendation, or null.
# exchange: every reply the gate held and every message it sent the
# agent over the question, in order, each {from, text}, whole. checks: the
# checker's answer each time the question was checked, in order. sort: the
# sorter's answer the question was routed on, or null. closing: the closing
# loop's round under way — the briefs it sweeps for, every finding its looks
# have brought so far, each as code checked it, once a round came back empty
# and the briefs were finished, what finishing them printed, and once the
# agent ran the case-writer, how many cases it wrote, skipped, held back and
# failed to write — or null; the look whose reply is awaited is the round, as
# a fixed round's is. The case-writer writes those counts here, the one part
# of the record not written by the gate: it runs as the agent's command
# between two stops, while the gate is not running, and the end report at the
# next stop reads them (settled 2026-10-07).
#
# And, across questions: reopened, the numbers of the decisions the operator
# reopened that the session has not asked again yet, in the order reopened,
# or null for none. Each question the session asks reaches them while one
# waits, whatever its kind and route, and takes one off (settled 2026-10-06):
# a reopened decision asked again would otherwise go through the gate as any
# question, and once its kind is switched be settled without them a second
# time. One per reopen rather than one mark for all: two reopened in one turn
# are asked as two questions, and one mark would let the second through.
# Drops are kept in the question log, never here: this record goes with its
# session, and the end report and reopen read the log. And resumed: the wait
# the session woke from, {kind, on}, once it was sent the resume look-around,
# or null. While it stands, a reply that asks the operator nothing reaches
# them as the session's report, and is never weighed for a step's go: work
# resumes on their go alone (settled 2026-10-06). It outlives a new turn, as
# reopened does, since the report may first ask again a decision the wait
# shook, and the go waits behind it.
#
# The question log is written from this record as a question is let go:
# everything it holds of the exchange, the question as asked, its checks, its
# sort and the answers is the log line's source until then, and is gone after.
# The checks and the sort are kept for that line alone: the gate decides from
# them in the stop they arrive in, and never reads them back.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_RECORD:-}" ] || return 0
STAND_IN_LOADED_RECORD=1
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
EMPTY_RECORD='{"sent_back":0,"challenge":null,"ladder":null,"round":null,"rounds_sent":[],"asked":null,"exchange":[],"checks":[],"sort":null,"closing":null,"reopened":null,"resumed":null}'

# What a record must be to be read: anything else was not written by the gate,
# or not whole, and is refused rather than repaired.
RECORD_SHAPE='
  type == "object"
  and (.sent_back | type == "number" and . >= 0)
  and (.challenge | type == "null" or type == "object")
  and (.ladder | type == "null"
    or (type == "object" and (.route | type == "string") and (.first | type == "object")
      and (.picks | type == "array")))
  and (.round | type == "null" or type == "string")
  and (.rounds_sent | type == "array")
  and (.asked | type == "null" or type == "object")
  and (.exchange | type == "array")
  and (.checks | type == "array")
  and (.sort | type == "null" or type == "object")
  and (.closing | type == "null"
    or (type == "object" and (.briefs | type == "array") and (.findings | type == "array")
      and (.finished | type == "null" or type == "string")
      and (.cases | type == "null"
        or (type == "object" and ([.written, .skipped, .held, .failed] | all(.[]; type == "number" and . >= 0))))))
  and (.reopened | type == "null" or (type == "array" and length > 0 and all(.[]; type == "number")))
  and (.resumed | type == "null"
    or (type == "object" and (.kind | type == "string") and (.on | type == "string")))'

# --- Transforms.

# The record file for a session, from the stand-in's working folder.
to_record_path() {
  printf '%s/%s/%s.json\n' "$1" "$RECORD_SUBFOLDER" "$2"
}

# The record with the question it was holding let go: a reply stopped, or a
# new turn of the operator's began. A ladder in progress goes with it, as a
# challenge, a round and the exchange do: a new turn may have changed what the
# agent is asking, and rungs climbed before it would be compared with answers
# to something else. So does a closing round under way: its looks' findings
# were sorted against the work as it stood before the operator spoke. A
# reopened decision's mark stays: it waits for the session's next question,
# whenever that comes.
with_chain_reset() {
  jq -c '.sent_back = 0 | .challenge = null | .ladder = null | .round = null | .rounds_sent = []
    | .asked = null | .exchange = [] | .checks = [] | .sort = null | .closing = null' <<<"$1"
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

# The record with the fixed round named noted as sent for the question, its
# reply awaiting no round of its own: read as any reply, since what it says
# decides what follows.
with_round_sent() {
  jq -c --arg name "$2" '.rounds_sent += [$name]' <<<"$1"
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

# The record with one more checker's answer for the question it holds.
with_check() {
  jq -c --argjson check "$2" '.checks += [$check]' <<<"$1"
}

# The record holding the sorter's answer the question is routed on.
with_sort() {
  jq -c --argjson sort "$2" '.sort = $sort' <<<"$1"
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
# name, the route it climbs, the lines the operator is to be shown beside it,
# and its first rung's answer, {options, recommended}. The question's
# challenge, if it had one, is over.
with_ladder() {
  jq -c --arg question "$2" --arg kind "$3" --arg route "$4" --arg lines "$5" --argjson first "$6" \
    '.challenge = null
      | .ladder = {question: $question, kind: $kind, route: $route, lines: $lines, first: $first, picks: []}' <<<"$1"
}

# The record with the matcher's pick of one more reply on the ladder it holds.
with_ladder_pick() {
  jq -c --argjson pick "$2" '.ladder.picks += [$pick]' <<<"$1"
}

# The ladder the record holds, as JSON; nothing where there is none.
to_ladder() {
  jq -c '.ladder // empty' <<<"$1"
}

# The record holding a closing round begun for the briefs given, as a JSON
# array, with no finding yet.
with_closing() {
  jq -c --argjson briefs "$2" '.closing = {briefs: $briefs, findings: []}' <<<"$1"
}

# The record with the findings given, a JSON array, added to its closing
# round's.
with_closing_findings() {
  jq -c --argjson findings "$2" '.closing.findings += $findings' <<<"$1"
}

# The closing round the record holds, as JSON; nothing where there is none.
to_closing() {
  jq -c '.closing // empty' <<<"$1"
}

# The record with what finishing the swept briefs printed kept on its closing
# round, as printed.
with_closing_finished() {
  jq -c --arg finished "$2" '.closing.finished = $finished' <<<"$1"
}

# The record with the case-writer's counts kept on its closing round, given
# as JSON {written, skipped, held, failed}.
with_closing_cases() {
  jq -c --argjson cases "$2" '.closing.cases = $cases' <<<"$1"
}

# The record marked with the number of one more decision the operator
# reopened; one already waiting is not marked twice.
with_reopened() {
  jq -c --argjson number "$2" \
    '.reopened = ((.reopened // []) | if any(.[]; . == $number) then . else . + [$number] end)' <<<"$1"
}

# The record with the first reopened decision taken off: a question has been
# brought to the operator for it.
without_first_reopened() {
  jq -c '.reopened = ((.reopened // [])[1:] | if length == 0 then null else . end)' <<<"$1"
}

# The number of the first reopened decision the record waits on; nothing
# where it waits on none.
to_reopened() {
  jq -r '.reopened[0] // empty' <<<"$1"
}

# The record marked with the wait the session woke from, out of the wait's
# mark: its kind and what it was on.
with_resumed() {
  jq -c --argjson mark "$2" '.resumed = ($mark | {kind, on})' <<<"$1"
}

# The record with the wait it woke from let go: its report reached the
# operator.
without_resumed() {
  jq -c '.resumed = null' <<<"$1"
}

# The wait the record's session woke from, as JSON {kind, on}; nothing where
# it woke from none.
to_resumed() {
  jq -c '.resumed // empty' <<<"$1"
}

# True if the record holds nothing in flight: no fixed round awaited, no
# question on the ladder, or under a challenge.
is_record_idle() {
  jq -e '.round == null and .ladder == null and .challenge == null' >/dev/null <<<"$1"
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

# Remove a session's record. A session the gate never held anything for has
# none, which is no failure. A record that stands and cannot be removed is
# refused on stderr with a non-zero status.
remove_session_record() {
  local file="$1"
  rm -f "$file" 2>/dev/null && [ ! -e "$file" ] && return 0
  refuse_state_unremovable_note "$file" >&2
  return 1
}
