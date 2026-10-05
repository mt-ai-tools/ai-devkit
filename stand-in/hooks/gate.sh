#!/usr/bin/env bash
# Claude Code Stop hook — the stand-in's gate, a thin orchestrator: at the end
# of every reply in a session the stand-in is switched on for, the reply is
# read into a form; a question to the operator is checked against the
# project's rules and conventions, sorted, challenged where its kind carries
# a challenge, and routed — back to the agent, or on to the operator. In
# every other session it does nothing at all.
#
# The order is the point: the rules and conventions check runs before any
# route, so a question that breaks one never reaches the operator; the
# challenge runs before the routes, so a proposal the agent drops is never
# asked about.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin and carries
# the reply as written, which is handed to the reader unread: the gate never
# reads the conversation itself, and decides from checked forms alone.
# Answering {"decision":"block","reason":…} keeps the agent working with the
# reason as its next instruction, and the stop that follows is marked
# stop_hook_active, which tells a reply to the gate from one to a new turn of
# the operator's. A systemMessage shows the operator its words whole and is
# never seen by the model. Printing nothing lets the reply stop as it is.
#
# Fails toward the operator, never toward the agent: a part that will not
# load, an event, form, preset or record that cannot be read, a model call
# refused or out of time — every refusal ends this script, and the trap below
# lets the reply stop with a message naming why. A gate that held the reply
# on its own failure could hold the agent forever, unseen.
set -euo pipefail

reasons=""

# Armed before anything is loaded, as the organizer's hooks are and for the
# same reason: a part that cannot be loaded ends bash with an ordinary error
# and no ERR trap run. Any way out but a clean finish lets the reply stop and
# tells the operator, with whatever the failing part said; where the words
# themselves could not be loaded, the message has its own.
answer_unjudged() {
  local status=$? why=""
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  if declare -F gate_broken_note >/dev/null && declare -F to_operator_answer >/dev/null; then
    to_operator_answer "$(gate_broken_note "$why")"
  else
    jq -cn --arg why "$why" \
      '{systemMessage: ("Stand-in: a part of the gate could not be loaded, so this reply was not judged.\n" + $why)}' 2>/dev/null \
      || printf '%s\n' '{"systemMessage":"Stand-in: a part of the gate could not be loaded, so this reply was not judged."}'
  fi
  exit 0
}
trap answer_unjudged EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason the operator is shown. Nothing written there reaches Claude Code,
# which shows a stopping hook's stderr only in its verbose mode.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/stop-event.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/record.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/checker.sh"
. "$tool_root/lib/sorter.sh"
. "$tool_root/lib/challenge.sh"
. "$tool_root/lib/routes.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument: a failing command substitution inside an argument does not end
# the script, and the refusal would go unseen.
event="$(cat)"
event="$(refuse_unreadable_event "$event")"
session="$(to_event_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
switch="$(find_switch "$history" "$session")"
[ -n "$switch" ] || exit 0

preset="$(get_config_path AIDK_STAND_IN)"
rules="$(get_config_path AIDK_RULES)"
conventions="$(get_config_path AIDK_CONVENTIONS)"
reply="$(to_event_reply "$event")"
record_file="$(to_record_path "$history" "$session")"
saved="$(read_session_record "$record_file")"
record="$saved"
# A new turn of the operator's lets go of whatever question the gate held.
is_event_continuation "$event" || record="$(with_chain_reset "$record")"

# The record is put in place before any answer is printed, so no answer
# stands on a count or a challenge that was not kept; a session the gate
# never held anything for gets no file.
keep_record() {
  [ "$record" = "$saved" ] || write_session_record "$record_file" "$record"
}

let_stop() {
  record="$(with_chain_reset "$record")"
  keep_record
  exit 0
}

bring_operator() {
  record="$(with_chain_reset "$record")"
  keep_record
  to_operator_answer "$1"
  exit 0
}

# Send the question back to the agent with the words given, unless it has
# been sent back as often as it may be: then it goes to the operator, with
# what would have been sent.
send_back() {
  local words="$1" question="$2"
  if is_send_back_spent "$record"; then
    bring_operator "$(gate_operator_note "$question" "$(gate_loop_line "$SEND_BACK_LIMIT" "$words")")"
  fi
  record="$(with_send_back "$record")"
  keep_record
  to_block_answer "$words"
  exit 0
}

# Take the route the question's forms decide.
route_question() {
  local form="$1" sort="$2" entry="$3" kept="$4" risks route words question
  question="$(jq -r '.question' <<<"$form")"
  risks="$(list_risks "$preset")"
  route="$(derive_route "$form" "$sort" "$entry" "$risks" "$kept")"
  words="$(jq -r '.words' <<<"$route")"
  case "$(jq -r '.route' <<<"$route")" in
    agent) send_back "$words" "$question" ;;
    operator) bring_operator "$(gate_operator_note "$question" "$words")" ;;
    # The ladder is not built yet: until it is, every question it would take
    # comes to the operator, marked so. This line is where the ladder goes.
    ladder) bring_operator "$(gate_operator_note "$question" \
      "$(gate_ladder_not_built_line "$(jq -r '.name' <<<"$entry")")"$'\n'"$words")" ;;
  esac
}

form="$(get_reader_form "$reply")"

challenge="$(to_challenge "$record")"
if [ -n "$challenge" ]; then
  step="$(derive_challenge_step "$challenge" "$form")"
  challenged="$(jq -c '.form' <<<"$challenge")"
  question="$(jq -r '.question' <<<"$challenged")"
  words="$(jq -r '.words' <<<"$step")"
  case "$(jq -r '.next' <<<"$step")" in
    # Dropped: noted, and the reply is read on as any other, since it may
    # go on to ask something else.
    drop) record="$(with_dropped "$record")" ;;
    challenge)
      record="$(with_challenge_step "$record" 2)"
      send_back "$(gate_challenge_note "$words")" "$question"
      ;;
    routes)
      route_question "$challenged" "$(jq -c '.sort' <<<"$challenge")" "$(jq -c '.entry' <<<"$challenge")" true
      ;;
    *) bring_operator "$(gate_operator_note "$question" "$(gate_unanswered_line "$words")")" ;;
  esac
fi

jq -e '.asks_operator' >/dev/null <<<"$form" || let_stop
question="$(jq -r '.question' <<<"$form")"

entries="$(list_check_entries "$rules" "$conventions")"
checked="$(get_checker_answer "$form" "$reply" "$entries")"
sendback="$(derive_checker_sendback "$checked" "$entries")"
[ -z "$sendback" ] || send_back "$sendback" "$question"

sort="$(get_sorter_answer "$form" "$reply" "$preset")"
entry="$(get_kind_entry "$preset" "$(jq -r '.kind' <<<"$sort")")"
first="$(jq -r '.challenge' <<<"$entry")"
if [ -n "$first" ]; then
  record="$(with_challenge "$record" "$entry" 1 "$form" "$sort")"
  send_back "$(gate_challenge_note "$first")" "$question"
fi

route_question "$form" "$sort" "$entry" false
