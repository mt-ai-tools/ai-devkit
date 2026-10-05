#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — the thin orchestrator for the turn
# reminder: while a session holds a brief, every turn carries one line per
# brief saying which, how long ago it was taken, and that it is finished with
# the organizer's done. A session holding none gets nothing.
#
# Why every turn: a long session's summary may lose which brief it is working
# on, and a line repeated each turn rests on no memory at all.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; stdout is
# added to the model's context before the turn begins. Only the session id is
# taken from the event and the prompt is never read: which brief a session
# holds is the organizer's marks' to say, never a guess at what was typed.
#
# Never blocks a turn. Where the session or its marks cannot be read, or any
# part here fails, the turn gets one line saying the organizer could not tell,
# and goes on: a reminder that fails must not stop the operator's work. The
# rules' injector, on the same event, does the opposite and refuses a turn its
# rules did not reach — the rules are the point of a turn, a reminder is not.
set -euo pipefail

# Armed before anything is loaded, as the injector's refusal is and for the
# same reason: a part that cannot be loaded ends bash with an ordinary error
# and no ERR trap run. Here any way out but a clean finish becomes the
# could-not-tell line and a clean exit, never a refusal. Where the words file
# itself is what is missing, the line has its own.
tell_unknown() {
  local status=$?
  [ "$status" -eq 0 ] && return
  if declare -F turn_unknown_note >/dev/null; then
    turn_unknown_note
  else
    printf 'The organizer'\''s turn reminder could not be loaded, so which brief this session holds is not known.\n'
  fi
  exit 0
}
trap tell_unknown EXIT

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/session-event.sh"

# Found from this hook's own place in the kit, never from the project's
# layout: the kit names no project folder.
organizer="$tool_root/bin/organizer.sh"

session="$(session_event_id)"
if [ -z "$session" ]; then
  turn_unknown_note
  exit 0
fi

# A refusal from the organizer ends the script here, and the trap answers with
# the could-not-tell line; the organizer's own reason stays on stderr.
held="$("$organizer" held "$session")"

reminder=""
while IFS=$'\t' read -r brief age; do
  [ -n "$brief" ] || continue
  reminder+="$(turn_held_note "$brief" "$age")"$'\n'
done <<<"$held"
printf '%s' "$reminder"
