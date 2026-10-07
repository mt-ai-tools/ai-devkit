#!/usr/bin/env bash
# Where the work in a repository stands, as git reads it: changes nobody
# committed, commits its upstream does not hold yet, or neither. A session
# waiting on a repository another session holds waits until it is neither:
# the other session's work is then recorded and published, and nothing of it
# can still move under the waiting one (settled 2026-10-06). Sourced, never
# executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_REPOSITORY:-}" ] || return 0
STAND_IN_LOADED_REPOSITORY=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The states a repository's work can be in, the first that holds named:
# changes nobody committed, then commits not yet pushed, then neither.
REPOSITORY_UNCOMMITTED="uncommitted"
REPOSITORY_UNPUSHED="unpushed"
REPOSITORY_CLEAN="clean"

# --- Transforms.

# True if the path stays inside the project root: relative, and never
# stepping up out of it. A repository outside the project is no module this
# session must touch, and the folder git would be asked about is not one the
# caller can name for certain.
is_inside_root_path() {
  case "$1" in
    "" | /*) return 1 ;;
    .. | ../* | */.. | */../*) return 1 ;;
  esac
  return 0
}

# --- Reads.

# The state of the repository holding the path given, inside the project root
# given: uncommitted, unpushed or clean. A refusal on stderr and a non-zero
# status where it cannot be told: the path leaves the root or is no folder,
# git cannot read it, or its branch has no upstream to compare with, a branch
# that tracks none and a checkout on no branch alike. None of those is ever
# read as clean, since a wait read as over there would let the waiting session
# build on work still moving.
#
# Asked of the repository as a whole, never of the path alone: another
# session's unfinished work anywhere in it is what the wait is for. Compared
# with what this checkout last saw of its upstream, never fetched: a session
# pushing from this checkout moves that at once, and a fetch would reach the
# network on every look. Optional locks are off, for the reason the
# uncommitted paths give: other sessions run git in the same checkout.
# Untracked files count as uncommitted, as they do there.
get_repository_state() {
  local root="$1" path="$2" dir status ahead
  if ! is_inside_root_path "$path" || [ ! -d "$root/$path" ]; then
    refuse_repository_missing_note "$path" >&2
    return 1
  fi
  dir="$root/$path"
  if ! status="$(GIT_OPTIONAL_LOCKS=0 git -C "$dir" status --porcelain 2>/dev/null)"; then
    refuse_repository_unreadable_note "$path" >&2
    return 1
  fi
  if [ -n "$status" ]; then
    printf '%s\n' "$REPOSITORY_UNCOMMITTED"
    return 0
  fi
  if ! git -C "$dir" rev-parse --verify --quiet '@{upstream}' >/dev/null 2>&1; then
    refuse_repository_no_upstream_note "$path" >&2
    return 1
  fi
  if ! ahead="$(git -C "$dir" rev-list --count '@{upstream}..HEAD' 2>/dev/null)"; then
    refuse_repository_unreadable_note "$path" >&2
    return 1
  fi
  if [ "$ahead" -gt 0 ]; then
    printf '%s\n' "$REPOSITORY_UNPUSHED"
    return 0
  fi
  printf '%s\n' "$REPOSITORY_CLEAN"
}
