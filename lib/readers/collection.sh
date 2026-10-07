#!/usr/bin/env bash
# Which files count as a collection's entries — in one place, so no two
# collections can disagree on it. Sourced, never executed.

# --- The words a refusal hands the operator — in one place, so the suite
# asserts the wiring rather than the wording.

# Why a collection was refused: something is at its path, but it cannot be
# listed as a folder.
collection_unreadable_note() {
  printf '%s is there but cannot be listed as a folder, so what it holds cannot be told.\n' "$1"
}

# Every entry file in the directory, one path per line. A README is never an
# entry, wherever a collection happens to keep one — this reader assumes
# nothing about the layout it is pointed at. An unset path, or one where
# nothing is, holds no entries: a collection a project never made is one
# several callers allow. Anything else at the path that cannot be listed — a
# folder without read or search permission, a file, a link to nowhere — is
# refused on stderr with a non-zero status, never read as empty: the glob
# below finds nothing in such a path, and an empty answer would let a caller
# treat a collection it never saw as one holding nothing, failing open: a
# caller deciding "nothing applies" would let through what an entry it could
# not read was there to stop.
list_collection_entries() {
  local dir="$1" f
  [ -n "$dir" ] || return 0
  if [ ! -e "$dir" ] && [ ! -L "$dir" ]; then
    return 0
  fi
  if [ ! -d "$dir" ] || [ ! -r "$dir" ] || [ ! -x "$dir" ]; then
    collection_unreadable_note "$dir" >&2
    return 1
  fi
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    printf '%s\n' "$f"
  done
}

# Whether the directory holds any entries at all — defined by what the
# listing returns, so the two can never disagree on what counts: 0 where it
# holds one, 1 where it holds none, and 2 with the listing's refusal on
# stderr where it cannot be listed. The refusal has a status of its own so a
# caller asking "none?" never takes a folder it could not read for an empty
# one; the listing is assigned before it is tested for the same reason, since
# a failed substitution inside a test reads as an empty answer.
collection_has_entries() {
  local entries
  entries="$(list_collection_entries "$1")" || return 2
  [ -n "$entries" ]
}
