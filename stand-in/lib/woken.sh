#!/usr/bin/env bash
# The mark a session's wait leaves as it ends: one small JSON file per
# session, named for its id, in a folder of the stand-in's own working
# folder, saying the wait is over and what it was for, or why it could not
# be watched. Written by the watch, read and removed by the gate at the
# session's next stop, and removed with the switch when the session ends.
# Sourced, never executed.
#
# A file of its own rather than a field of the gate's record of the session:
# the watch runs beside the session and may end while the gate is reading and
# rewriting that record, which would then put back the record it read and
# lose the mark. A file only the watch writes and only the gate removes has
# no such race.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_WOKEN:-}" ] || return 0
STAND_IN_LOADED_WOKEN=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The marks' folder inside the stand-in's working folder.
WOKEN_SUBFOLDER="woken"

# What a session can wait on: another session's brief to be finished, or a
# repository another session holds to have nothing uncommitted and nothing
# unpushed (settled 2026-10-06).
WAIT_BRIEF="brief"
WAIT_REPOSITORY="repository"

# How a wait ended: over, or refused, where it could not be watched.
WAIT_OVER="over"
WAIT_REFUSED="refused"

# What a mark must be to be read: anything else was not written by the watch,
# or not whole, and is refused rather than repaired.
WOKEN_SHAPE='
  type == "object"
  and (.outcome == $over or .outcome == $refused)
  and (.kind == $brief or .kind == $repository)
  and (.on | type == "string")
  and (.why | type == "string")'

# --- Transforms.

# The mark file for a session, from the stand-in's working folder.
to_woken_path() {
  printf '%s/%s/%s\n' "$1" "$WOKEN_SUBFOLDER" "$2"
}

# A mark, as JSON: how the wait ended, what kind it was, what it was on — the
# briefs waited for, joined, or the repository's path — and why it could not
# be watched, empty where it ended over.
to_woken_mark() {
  jq -cn --arg outcome "$1" --arg kind "$2" --arg on "$3" --arg why "${4:-}" \
    '{outcome: $outcome, kind: $kind, on: $on, why: $why}'
}

# True if the mark says the wait is over.
is_wait_over() {
  jq -e --arg over "$WAIT_OVER" '.outcome == $over' >/dev/null <<<"$1"
}

# What the wait was for, in words, given a mark.
format_waited_words() {
  local on kind
  on="$(jq -r '.on' <<<"$1")" || return 1
  kind="$(jq -r '.kind' <<<"$1")" || return 1
  if [ "$kind" = "$WAIT_BRIEF" ]; then
    wait_brief_words "$on"
  else
    wait_repository_words "$on"
  fi
}

# --- Reads.

# The session's mark, compact, where one stands; nothing where none does, the
# folder missing included, which is the state of every session not waiting.
# One that cannot be read, or is not a mark, is refused on stderr with a
# non-zero status: a wait whose end was lost would leave the session building
# on ground nobody looked at, and the operator never told.
find_woken_mark() {
  local file mark
  file="$(to_woken_path "$1" "$2")"
  [ -e "$file" ] || return 0
  if ! mark="$(jq -ce --arg over "$WAIT_OVER" --arg refused "$WAIT_REFUSED" \
    --arg brief "$WAIT_BRIEF" --arg repository "$WAIT_REPOSITORY" "select($WOKEN_SHAPE)" "$file" 2>/dev/null)" \
    || [ -z "$mark" ]; then
    refuse_woken_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$mark"
}

# --- Writes.

# Put a session's mark in place, through a hidden draft moved over any mark
# before it, so the gate never reads half of one. A mark that cannot be
# written is refused on stderr with a non-zero status.
write_woken_mark() {
  local file dir draft
  file="$(to_woken_path "$1" "$2")"
  dir="$(dirname "$file")"
  draft="$dir/.$(basename "$file").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { printf '%s\n' "$3" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_woken_unwritable_note "$dir" >&2
    return 1
  fi
}

# Remove a session's mark. A session with none is no failure. A mark that
# stands and cannot be removed is refused on stderr with a non-zero status:
# left standing, it would wake the session again at every stop.
remove_woken_mark() {
  local file
  file="$(to_woken_path "$1" "$2")"
  rm -f "$file" 2>/dev/null && [ ! -e "$file" ] && return 0
  refuse_woken_unremovable_note "$file" >&2
  return 1
}
