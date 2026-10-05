#!/usr/bin/env bash
# Claude Code SessionEnd hook — the thin orchestrator that frees every brief
# the ending session holds, so a brief stays taken only while a session works
# on it.
#
# The event fires on /exit, on /clear (which ends the session and starts a new
# one under a new id), at the end of a headless run, and when the terminal is
# closed. A killed process fires nothing: its mark stays, the list shows its
# age, and the operator frees it.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; nothing this
# hook prints reaches the model. Only the session id is taken from the event.
#
# Never holds a session end up: where the event carries no session id, or the
# organizer cannot free the marks, it says why on stderr and exits cleanly.
# Freeing nothing is the safe miss, since the mark stays in the list with its
# age; freeing on a guess could free a brief another session is working on.
set -euo pipefail

session=""

# Armed before anything is loaded, as the turn reminder's is: any way out but
# a clean finish says on stderr that nothing was freed, and exits cleanly.
say_not_freed() {
  local status=$?
  [ "$status" -eq 0 ] && return
  if declare -F end_not_freed_note >/dev/null; then
    end_not_freed_note "$session" >&2
  else
    printf 'The organizer'\''s session-end hook could not be loaded, so no brief was freed.\n' >&2
  fi
  exit 0
}
trap say_not_freed EXIT

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/session-event.sh"

# Found from this hook's own place in the kit, never from the project's
# layout: the kit names no project folder.
organizer="$tool_root/bin/organizer.sh"

session="$(session_event_id)"
if [ -z "$session" ]; then
  end_no_session_note >&2
  exit 0
fi

"$organizer" free "$session"
