#!/usr/bin/env bash
# What a brief is to the organizer: an entry of the briefs folder, named for
# its file, opening with a header of four fields. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The header fields every brief carries, in the order a row holds them. All
# four are required: an empty list is written `[]`, so a missing line is never
# read as an empty one.
BRIEF_FIELDS=(summary after touches creates)

# --- Transforms.

# A brief's file, from the briefs folder and its name. The name must already
# have passed is_brief_name; nothing here can tell a path from a name.
brief_file() {
  printf '%s/%s.md\n' "$1" "$2"
}

# --- Reads.

# Every brief in the folder, one row each, in name order:
# "<name><US><summary><US><after><US><touches><US><creates>", every value as
# its header wrote it. Which files are entries is the collection reader's to
# say, so a README is never a brief here either. The name is the file's, as
# found, and is judged by the check rather than skipped: a brief nobody can
# address by name is a problem to show, not a file to ignore.
list_brief_rows() {
  local dir="$1" f
  while IFS= read -r f; do
    printf '%s%s%s\n' "$(basename "$f" .md)" "$HEADER_US" "$(read_header_fields "$f" "${BRIEF_FIELDS[@]}")"
  done < <(list_collection_entries "$dir" | LC_ALL=C sort)
}

# Nothing where the briefs folder holds a brief by that name; a refusal on
# stderr and a non-zero status otherwise. The name is judged before any path
# is built from it, so a name such as `../x` never reaches the filesystem.
refuse_unknown_brief() {
  local dir="$1" name="$2"
  is_brief_name "$name" || { refuse_bad_name_note "$name" >&2; return 1; }
  [ -f "$(brief_file "$dir" "$name")" ] || { refuse_no_brief_note "$name" >&2; return 1; }
}
