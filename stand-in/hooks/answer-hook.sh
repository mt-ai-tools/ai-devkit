#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — the thin orchestrator that keeps the
# operator's answer: in a session the stand-in is switched on for, the first
# prompt typed after the gate let a question go to the operator is that
# question's answer, and is written into its line in the question log. Where
# that question asked whether a kind may answer alone, and the answer is a
# plain yes, the yes is kept as the kind's file in the project's stand-in
# folder, and the operator and the agent are told, the agent to commit it.
# In every other session it does nothing at all.
#
# Why the next prompt: the gate lets a question go by letting the reply stop
# with the question shown, so whatever the operator types next is what they
# said to it. Only the session's last question can take an answer, and only
# once, so a later prompt never overwrites it, and a question settled without
# the operator never takes one. A command typed instead is not what they
# said to it, so it is skipped, and the next prompt that is not one still
# answers.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; stdout is
# added to the model's context before the turn begins. Never blocks a turn,
# as the organizer's turn reminder never does: where the answer cannot be
# kept, the model is told so in one line, and the turn goes on. A log that
# misses an answer is worth a line; a turn refused for it would cost the
# operator their work.
set -euo pipefail
# Errexit kept inside command substitutions; why beside the gate's own line.
shopt -s inherit_errexit

reasons=""

# Armed before anything is loaded, as the gate's trap is and for the same
# reason: a part that cannot be loaded ends bash with an ordinary error and no
# ERR trap run. Any way out but a clean finish becomes one line naming why,
# and a clean exit.
tell_unrecorded() {
  local status=$? why=""
  if [ -n "$reasons" ]; then
    why="$(tr '\n' ' ' <"$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  if declare -F answer_unrecorded_note >/dev/null; then
    answer_unrecorded_note "${why% }"
  else
    printf 'The stand-in'\''s answer hook could not be loaded, so the user'\''s reply was not kept as an answer.\n'
  fi
  exit 0
}
trap tell_unrecorded EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# line the model is told.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/prompt-event.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/question-log.sh"
. "$tool_root/lib/trial.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives.
event="$(cat)"
session="$(to_prompt_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
switch="$(find_switch "$history" "$session")"
[ -n "$switch" ] || exit 0

prompt="$(to_prompt_text "$event")"
! is_command_prompt "$prompt" || exit 0
log_dir="$(to_log_dir "$history")"
# Read before the answer is written: only the question waiting for this
# prompt takes it as its answer, so an earlier yes, already kept on a line
# answered before, is never read as given again.
lines="$(list_log_lines "$log_dir")"
waiting="$(to_awaiting_line "$lines" "$session")"
write_log_answer "$log_dir" "$session" "$prompt"

# The operator's yes, the one switch a kind has (settled 2026-10-01/02,
# decision 9): kept only for the kind the question named, and only for a
# plain yes; anything else typed leaves the kind on trial, and it is asked
# again at the next end report. When it was given is this moment, as the log
# writes one, so the fall-back counts the decisions settled after it.
[ -n "$waiting" ] || exit 0
kind="$(jq -r '.trust.kind // empty' <<<"$waiting")"
[ -n "$kind" ] || exit 0
is_plain_yes "$prompt" || exit 0
given="$(get_log_now)"
if write_trust_file "$history" "$kind" "$given"; then
  path="$(to_trust_path "$history" "$kind")"
  to_prompt_answer "$(trust_given_note "$kind" "$path")" "$(trust_given_agent_note "$kind" "$path")"
else
  why="$(cat "$reasons")"
  to_prompt_answer "$(trust_unkept_note "$kind" "$why")" "$(trust_unkept_agent_note "$kind")"
fi
