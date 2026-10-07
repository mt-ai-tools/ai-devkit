#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — the thin orchestrator that reminds a
# session it owes the exam: where the session edited what the stand-in judges
# by and no exam has passed since, the agent is told at the start of every
# turn to run it before it reports a step or says the brief is done, with the
# command and the files. Only in a session the stand-in is off for: where it
# is on, the gate sends those reports back itself, and a reminder each turn
# would say it twice. Every other turn it lets go untouched and unsaid.
#
# Why each turn (settled 2026-10-06, decision 7): with the stand-in off,
# nothing reads the session's replies, so the turn's start is the one moment
# the stand-in has the agent's ear.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; stdout is
# added to the model's context before the turn begins. A systemMessage shows
# the operator its words whole, beside the note added for the model. Never
# blocks a turn, as the answer hook never does: where whether an exam is owed
# cannot be told, the operator and the agent are both told why, and the turn
# goes on.
set -euo pipefail

reasons=""

# Armed before anything is loaded, as the gate's trap is and for the same
# reason: a part that cannot be loaded ends bash with an ordinary error and
# no ERR trap run.
tell_unread() {
  local status=$? why="" note
  if [ -n "$reasons" ]; then
    why="$(cat "$reasons" 2>/dev/null || true)"
    rm -f "$reasons"
  fi
  [ "$status" -eq 0 ] && return
  # Nothing below may end the trap before the operator is told.
  set +e
  if declare -F exam_reminder_unread_note >/dev/null && declare -F to_prompt_answer >/dev/null; then
    note="$(exam_reminder_unread_note "$why")"
    to_prompt_answer "$note" "$note"
  else
    printf 'The stand-in'\''s reminder hook could not be loaded, so whether this session owes the exam was not checked.\n'
  fi
  exit 0
}
trap tell_unread EXIT

# Every part says why it refused on stderr; gathered here, it becomes the
# reason given.
reasons="$(mktemp)"
exec 2>"$reasons"

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/prompt-event.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/owed.sh"
. "$tool_root/lib/exam.sh"

# The exam's command, as the agent is told to type it: the entry by its whole
# path, since the agent runs it from wherever its shell stands.
exam_command="$tool_root/bin/stand-in.sh $EXAM_COMMAND"

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives.
event="$(cat)"
session="$(to_prompt_session "$event")"
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
mark="$(find_owed_mark "$history" "$session")"
[ -n "$mark" ] || exit 0
switch="$(find_switch "$history" "$session")"
[ -z "$switch" ] || exit 0

files="$(format_owed_files "$mark")"
exam_reminder_note "$exam_command" "$files"
