#!/usr/bin/env bash
# The briefs, as the work organizer keeps them: its list, a brief taken for a
# session, and which briefs a session holds. The stand-in asks all of it of
# the organizer's own command, and never reads or writes its marks. Sourced,
# never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The organizer's command, inside the kit.
ORGANIZER_COMMAND="organizer/bin/organizer.sh"

# --- Reads.

# The briefs the session holds, as a JSON array of names, empty for none: a
# session the stand-in was switched on for without a brief holds none, since
# that switch takes nothing. A refusal on stderr and a non-zero status where
# the organizer cannot be run or refuses, as it does in a project with no
# briefs folder.
get_held_briefs() {
  local session="$1" held
  held="$("$(get_kit_dir)/$ORGANIZER_COMMAND" held "$session")" || return 1
  # Empty lines are dropped before they are split: a session holding nothing
  # is one empty line here, and its split has no first part, which read as a
  # brief named null (found live 2026-10-06).
  jq -Rcn '[inputs | select(. != "") | split("\t")[0]]' <<<"$held"
}

# The organizer's list as it printed it, every byte, its refusals among it;
# where the organizer cannot be run at all, a line saying so. Always answers:
# the list is shown whatever its status, since the organizer exits non-zero
# whenever its check finds a problem, and the problems are already first in
# what it printed. The trailing "x" keeps the last newline, which a command
# substitution would strip.
get_organizer_list() {
  local organizer shown
  organizer="$(get_kit_dir)/$ORGANIZER_COMMAND"
  if [ ! -f "$organizer" ] || [ ! -x "$organizer" ]; then
    organizer_unrunnable_note "$organizer"
    return 0
  fi
  shown="$("$organizer" list 2>&1 || true; printf x)"
  printf '%s' "${shown%x}"
}

# --- Writes.

# Take a brief for a session, through the organizer's own take: a brief
# another session holds, or one the organizer does not know, is refused with
# the organizer's own words on stderr and a non-zero status. Whatever it
# prints goes to stderr too, so a caller's stdout carries only its own answer.
take_brief() {
  local organizer
  organizer="$(get_kit_dir)/$ORGANIZER_COMMAND"
  if [ ! -f "$organizer" ] || [ ! -x "$organizer" ]; then
    organizer_unrunnable_note "$organizer" >&2
    return 1
  fi
  "$organizer" take "$1" "$2" >&2
}
