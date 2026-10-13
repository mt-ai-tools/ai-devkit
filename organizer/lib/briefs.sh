#!/usr/bin/env bash
# What a brief is to the organizer: an entry of one of the briefs folder's
# level folders, named for its file, opening with a header of four fields, or
# a draft, marked so in its header and held to less. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/levels.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The header fields every brief carries, in the order a row holds them. All
# four are required: an empty list is written `[]`, so a missing line is never
# read as an empty one.
BRIEF_FIELDS=(summary after touches creates)

# The header field that marks a draft, and the one value that does. Explicit
# rather than told by what a file lacks: a half-written brief, missing its
# steps too, would otherwise read as a draft, offered nothing and hiding the
# problem.
DRAFT_FIELD="draft"
DRAFT_VALUE="true"

# --- Transforms.

# A brief's file, from the briefs folder, its level and its name; directly in
# the briefs folder where the level is empty, which is where a file in no
# level lies. Both must already have passed is_level_name and is_brief_name;
# nothing here can tell a path from a name.
brief_path() {
  local plans="$1" level="$2" name="$3"
  printf '%s/%s%s.md\n' "$plans" "${level:+$level/}" "$name"
}

# True if a draft field's value, as the header wrote it, marks a draft.
is_draft_value() {
  [ "$1" = "$DRAFT_VALUE" ]
}

# True if a header value, as the header wrote it, is a folded-block marker
# (`>` or `|`, with its chomping and indent signs). The header reader hands
# back only a field's first line, so such a field reads as the marker alone,
# and a list would show the marker in place of the value.
is_folded_marker() {
  [[ "$1" =~ ^[\>\|][-+0-9]*$ ]]
}

# The rows given, in level order and by name within a level; rows in no level
# first, as they are listed first. The order is the levels' own, never the
# names' spelling, so the order shown is the operator's, read off the folders
# a file was put in, and the organizer ranks nothing itself.
with_level_order() {
  local rows="$1" i row level at
  local -A rank
  for i in "${!BRIEF_LEVEL_NAMES[@]}"; do
    rank[${BRIEF_LEVEL_NAMES[$i]}]="$((i + 1))"
  done
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    level="${row##*"$HEADER_US"}"
    # An empty key is no subscript bash takes, so a row in no level is ranked
    # without asking.
    at=0
    [ -z "$level" ] || at="${rank[$level]:-0}"
    printf '%s%s%s\n' "$at" "$HEADER_US" "$row"
  done <<<"$rows" | LC_ALL=C sort -s -t "$HEADER_US" -k1,1n -k2,2 | cut -d "$HEADER_US" -f 2-
}

# --- Reads.

# Every entry file of the briefs folder, as "<level><US><path>": those lying
# directly in it first, their level empty, then each level's in level order.
# Which files are entries is the collection reader's to say, once per folder,
# so a README is never a brief here either. A level folder the project has not
# made holds none. A folder that cannot be listed is the collection reader's
# refusal, on stderr with a non-zero status: read as holding no briefs, it
# would show nothing to do and free no waiter. Each listing is taken into a
# variable before it is used, never fed from a process substitution, whose
# failure nothing would see.
list_brief_entries() {
  local plans="$1" level entries f
  entries="$(list_collection_entries "$plans")" || return 1
  while IFS= read -r f; do
    [ -n "$f" ] && printf '%s%s\n' "$HEADER_US" "$f"
  done <<<"$entries"
  for level in "${BRIEF_LEVEL_NAMES[@]}"; do
    entries="$(list_collection_entries "$plans/$level")" || return 1
    while IFS= read -r f; do
      [ -n "$f" ] && printf '%s%s%s\n' "$level" "$HEADER_US" "$f"
    done <<<"$entries"
  done
  return 0
}

# Every brief and draft, one row each, in name order:
# "<name><US><summary><US><after><US><touches><US><creates><US><draft><US><level>",
# every header value as its header wrote it, the level that of the folder it
# lies in and empty for one lying directly in the briefs folder. Those in no
# level are rows too: the check shows them, and a brief waiting on one still
# finds it rather than being told of a brief gone. The name is the file's, as
# found, and is judged by the check rather than skipped: a brief nobody can
# address by name is a problem to show, not a file to ignore. One name in two
# places is two rows, in the order the entries came, for the check to show.
# Every caller takes the rows into a variable and lets a failure end it, as
# the entries are taken here.
list_brief_rows() {
  local plans="$1" entries level f rows=""
  entries="$(list_brief_entries "$plans")" || return 1
  while IFS="$HEADER_US" read -r level f; do
    [ -n "$f" ] || continue
    rows+="$(basename "$f" .md)$HEADER_US$(read_header_fields "$f" "${BRIEF_FIELDS[@]}" "$DRAFT_FIELD")$HEADER_US$level"$'\n'
  done <<<"$entries"
  printf '%s' "$rows" | LC_ALL=C sort -s -t "$HEADER_US" -k1,1
}

# Every folder in the briefs folder that is not a level, by name, in name
# order. A hidden folder is never one: version control and editors keep
# theirs there, and the glob passes them by.
list_unknown_level_folders() {
  local plans="$1" d
  for d in "$plans"/*/; do
    [ -d "$d" ] || continue
    d="$(basename "$d")"
    is_level_name "$d" || printf '%s\n' "$d"
  done | LC_ALL=C sort
}

# Every level holding a brief or draft by that name, one a line, in level
# order. The name must already have passed is_brief_name. A file lying
# directly in the briefs folder is in no level and is never found by name: it
# is a problem the check shows, and taking or finishing it would act on what
# the check could not vouch for.
list_brief_levels() {
  local plans="$1" name="$2" level
  for level in "${BRIEF_LEVEL_NAMES[@]}"; do
    [ -f "$(brief_path "$plans" "$level" "$name")" ] && printf '%s\n' "$level"
  done
  return 0
}

# The file of the brief or draft by that name, wherever among the levels it
# lies; nothing where no level holds it, or more than one does, since which
# was meant cannot be told. The name must already have passed is_brief_name.
find_brief_file() {
  local plans="$1" name="$2" levels
  levels="$(list_brief_levels "$plans" "$name")"
  [ -n "$levels" ] && [[ "$levels" != *$'\n'* ]] || return 0
  brief_path "$plans" "$levels" "$name"
}

# Nothing where exactly one level holds a brief or draft by that name; a
# refusal on stderr and a non-zero status otherwise. The name is judged before
# any path is built from it, so a name such as `../x` never reaches the
# filesystem. A name in two levels is refused naming both, rather than one
# picked: an operation by name would act on whichever it happened to find.
refuse_unknown_brief() {
  local plans="$1" name="$2" levels
  is_brief_name "$name" || { refuse_bad_name_note "$name" >&2; return 1; }
  levels="$(list_brief_levels "$plans" "$name")"
  [ -n "$levels" ] || { refuse_no_brief_note "$name" >&2; return 1; }
  [[ "$levels" != *$'\n'* ]] || { refuse_name_in_levels_note "$name" "${levels//$'\n'/, }" >&2; return 1; }
}

# Nothing where the brief is no draft; a refusal on stderr and a non-zero
# status otherwise. A draft is work not yet written out, so nobody can start
# it; the operator's yes turns it into a brief first. The name must already
# have passed refuse_unknown_brief.
refuse_draft_brief() {
  local plans="$1" name="$2" draft
  draft="$(read_header_fields "$(find_brief_file "$plans" "$name")" "$DRAFT_FIELD")"
  ! is_draft_value "$draft" || { refuse_draft_note "$name" >&2; return 1; }
}

# Nothing where the brief waits on no other; a refusal naming what it waits on
# on stderr and a non-zero status otherwise. A brief taken early builds on
# ground that is not there yet, or will still change under it; starting one
# early is a deliberate edit of its header, never a take. An after list that
# cannot be read is refused too, since a half-written list must not make a
# brief look ready. The name must already have passed refuse_unknown_brief.
refuse_waiting_brief() {
  local plans="$1" name="$2" after items
  after="$(read_header_fields "$(find_brief_file "$plans" "$name")" after)"
  if ! items="$(parse_flow_list "$after")"; then
    refuse_header_unreadable_note "$name" >&2
    return 1
  fi
  [ -z "$items" ] || { refuse_waiting_note "$name" "${items//,/, }" >&2; return 1; }
}
