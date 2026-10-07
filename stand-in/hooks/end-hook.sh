#!/usr/bin/env bash
# Claude Code SessionEnd hook — the thin orchestrator that switches the
# stand-in off for the ending session and removes the gate's record of it, so
# neither stands longer than its session lives. The record holds nothing the
# session's end needs kept: drops are lines of the question log, which the end
# report and reopen read (settled 2026-10-06), and a record left behind would
# be a held question or a reopened mark nothing could ever reach. Whatever the
# session took through the work organizer is the organizer's own end hook to
# free: the switch and the take are two facts of two tools, and each tool
# ends its own.
#
# The event fires on /exit, on /clear (which ends the session and starts a new
# one under a new id, so the stand-in is off for the new one), at the end of a
# headless run, and when the terminal is closed. A killed process fires
# nothing: its switch and its record stay behind, read by nothing while no
# session runs under its id.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; nothing this
# hook prints reaches the model. Only the session id is taken from the event.
#
# Never holds a session end up: where the event carries no session id it can
# use, or the switch or the record cannot be removed, it says why on stderr
# and exits cleanly. Removing nothing is the safe miss, since a session that
# has ended never reaches the gate again; removing on a guess could switch the
# stand-in off for a session still working.
set -euo pipefail

session=""

# Armed before anything is loaded, as the start hook's is: any way out but a
# clean finish says on stderr that the session was not wholly ended, and
# exits cleanly.
say_not_removed() {
  local status=$?
  [ "$status" -eq 0 ] && return
  if declare -F end_not_removed_note >/dev/null; then
    end_not_removed_note "$session" >&2
  else
    printf 'The stand-in'\''s session-end hook could not be loaded, so no switch or record was removed.\n' >&2
  fi
  exit 0
}
trap say_not_removed EXIT

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/end-event.sh"
. "$tool_root/lib/switch.sh"
. "$tool_root/lib/record.sh"

# Every value below is resolved into a variable before use, never inline as
# an argument, for the reason the gate gives. An event with no session id has
# said why already, and nothing is left to remove.
event="$(cat)"
session="$(to_end_session "$event")" || exit 0
history="$(get_config_path AIDK_STAND_IN_HISTORY)"
# Each is tried whatever the other did: they are two files, and one that
# would not go is no reason to leave the other.
record_file="$(to_record_path "$history" "$session")"
removed=0
remove_switch "$history" "$session" || removed=1
remove_session_record "$record_file" || removed=1
exit "$removed"
