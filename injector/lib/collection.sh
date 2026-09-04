#!/usr/bin/env bash
# Which files count as a collection's entries — in one place, so no two
# collections can disagree on it. Sourced, never executed.

# Every entry file in the directory, one path per line. A README is never an
# entry, wherever a collection happens to keep one — this reader assumes
# nothing about the layout it is pointed at.
list_collection_entries() {
  local dir="$1" f
  for f in "$dir"/*.md; do
    [ -e "$f" ] || continue
    [ "$(basename "$f")" = "README.md" ] && continue
    printf '%s\n' "$f"
  done
}

# True if the directory holds any entries at all — defined by what the
# listing returns, so the two can never disagree on what counts. An
# unset path or a missing directory holds none.
collection_has_entries() {
  local dir="$1"
  [ -n "$dir" ] && [ -d "$dir" ] || return 1
  [ -n "$(list_collection_entries "$dir")" ]
}
