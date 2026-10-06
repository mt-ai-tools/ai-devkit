#!/usr/bin/env bash
# Which paths hold changes nobody committed, as git reads them: a fix made in
# passing there would land inside someone's unfinished work, so the closing
# loop never makes one there. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CHANGES:-}" ] || return 0
STAND_IN_LOADED_CHANGES=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Reads.

# Those of the paths given, each from inside the project root given, that
# hold uncommitted changes or files git does not yet track, one a line, in
# the order given; nothing where none does. A refusal on stderr and a
# non-zero status where git cannot tell for one: an answer of none would let
# a fix in passing land in work nobody can see.
#
# Each path is asked of the repository holding it, found from the nearest
# folder that exists, since a project may hold repositories inside its own
# (each module its own) and the outer one sees only that a pointer moved. A
# path not yet written is asked of the folder it would be written in.
# Optional locks are off: other sessions run git in the same checkout, and a
# status that refreshed the index would take a lock one of them may be
# waiting for.
list_uncommitted_paths() {
  local root="$1" path dir status
  shift
  for path in "$@"; do
    dir="$root/$path"
    while [ ! -d "$dir" ]; do dir="$(dirname "$dir")"; done
    if ! status="$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain --untracked-files=all -- "$root/$path" 2>/dev/null)"; then
      refuse_changes_unknown_note "$path" >&2
      return 1
    fi
    [ -z "$status" ] || printf '%s\n' "$path"
  done
}
