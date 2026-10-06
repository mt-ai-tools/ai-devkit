#!/usr/bin/env bash
# Whether the stand-in is on for a session: one file per session, named for
# its id, in a folder of the stand-in's own working folder. Written when the
# stand-in is switched on for a session and removed when that session ends.
# Sourced, never executed.
#
# The switch is the stand-in's own fact, never read off which brief a session
# has taken: the stand-in may be on for a session holding no brief, and a
# brief may be taken with the stand-in off.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The switches' folder inside the stand-in's working folder.
SWITCH_SUBFOLDER="on"

# --- Reads.

# The session's switch file where it stands; nothing where it does not, the
# folder missing included, which is the normal state of a project where the
# stand-in was never switched on. A folder that exists but cannot be searched
# is refused on stderr with a non-zero status: a test on a file inside it
# answers "not there" either way, which would take every session for one the
# stand-in is off for, without a word.
find_switch() {
  local dir="$1/$SWITCH_SUBFOLDER" session="$2"
  if [ -e "$dir" ] && { ! [ -d "$dir" ] || ! [ -x "$dir" ]; }; then
    refuse_switch_unknown_note "$dir" >&2
    return 1
  fi
  [ -f "$dir/$session" ] || return 0
  printf '%s\n' "$dir/$session"
}

# --- Writes.

# Switch the stand-in on for a session. A session it is already on for keeps
# its switch as it stands. A switch that cannot be written is refused on
# stderr with a non-zero status, in the stand-in's own words.
write_switch() {
  local dir="$1/$SWITCH_SUBFOLDER" session="$2"
  if ! { mkdir -p "$dir" && : >>"$dir/$session"; } 2>/dev/null; then
    refuse_switch_unwritable_note "$dir" >&2
    return 1
  fi
}

# Switch the stand-in off for a session. A session it is not on for is not a
# failure: most sessions never had it switched on. A switch that stands and
# cannot be removed is refused on stderr with a non-zero status: left unsaid,
# the gate would go on judging a session everyone takes for one it is off for.
remove_switch() {
  local file="$1/$SWITCH_SUBFOLDER/$2"
  rm -f "$file" 2>/dev/null && [ ! -e "$file" ] && return 0
  refuse_switch_unremovable_note "$file" >&2
  return 1
}
