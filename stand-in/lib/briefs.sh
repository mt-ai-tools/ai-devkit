#!/usr/bin/env bash
# Which briefs a session holds, asked of the work organizer, which keeps that
# fact: the stand-in only reads it, through the organizer's own command, and
# never its marks. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"

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
  jq -Rcn '[inputs | split("\t")[0] | select(. != "")]' <<<"$held"
}
