#!/usr/bin/env bash
# What a brief is to the organizer: an entry of the briefs folder, named for
# its file, opening with a header of four fields. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
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
# address by name is a problem to show, not a file to ignore. A folder that
# cannot be listed is the collection reader's refusal, on stderr with a
# non-zero status: read as holding no briefs, it would show nothing to do and
# free no waiter. The listing is taken before the loop, never fed to it from a
# process substitution, whose failure nothing would see; every caller takes
# the rows into a variable and lets a failure end it, for the same reason.
list_brief_rows() {
  local dir="$1" f entries
  entries="$(list_collection_entries "$dir")" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    printf '%s%s%s\n' "$(basename "$f" .md)" "$HEADER_US" "$(read_header_fields "$f" "${BRIEF_FIELDS[@]}")"
  done < <(LC_ALL=C sort <<<"$entries")
}

# Nothing where the briefs folder holds a brief by that name; a refusal on
# stderr and a non-zero status otherwise. The name is judged before any path
# is built from it, so a name such as `../x` never reaches the filesystem.
refuse_unknown_brief() {
  local dir="$1" name="$2"
  is_brief_name "$name" || { refuse_bad_name_note "$name" >&2; return 1; }
  [ -f "$(brief_file "$dir" "$name")" ] || { refuse_no_brief_note "$name" >&2; return 1; }
}

# Nothing where the brief waits on no other; a refusal naming what it waits on
# on stderr and a non-zero status otherwise. A brief taken early builds on
# ground that is not there yet, or will still change under it; starting one
# early is a deliberate edit of its header, never a take. An after list that
# cannot be read is refused too, since a half-written list must not make a
# brief look ready. The name must already have passed refuse_unknown_brief.
refuse_waiting_brief() {
  local dir="$1" name="$2" after items
  after="$(read_header_fields "$(brief_file "$dir" "$name")" after)"
  if ! items="$(parse_flow_list "$after")"; then
    refuse_header_unreadable_note "$name" >&2
    return 1
  fi
  [ -z "$items" ] || { refuse_waiting_note "$name" "${items//,/, }" >&2; return 1; }
}
