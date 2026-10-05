#!/usr/bin/env bash
# Which briefs sessions are working on: one mark file per taken brief, named
# for the brief, in a folder of the organizer's own. Sourced, never executed.
#
# A mark holds two lines, `session: <id>` and `since: <UTC stamp>`. Its age is
# read from the since line, never from the file's modification time, which a
# copy, a checkout or a backup restore would quietly reset.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/clock.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The marks' folder inside the organizer's working folder; whatever else the
# organizer keeps there later sits beside it rather than among the marks.
MARKS_SUBFOLDER="taken"

# --- Transforms.

# The marks folder, from the organizer's working folder.
marks_dir() {
  printf '%s/%s\n' "$1" "$MARKS_SUBFOLDER"
}

# True if a mark's two values are what a mark is written with.
is_readable_mark() {
  is_session_id "$1" && is_utc_stamp "$2"
}

# Nothing where a brief's standing mark, given by its two values, is held by
# the given session; a refusal on stderr and a non-zero status where another
# session holds it, or where it cannot be read and so nobody can say who does.
refuse_held_mark() {
  local brief="$1" session="$2" held="$3" since="$4"
  if ! is_readable_mark "$held" "$since"; then
    refuse_mark_unreadable_note "$brief" >&2
    return 1
  fi
  [ "$held" = "$session" ] && return 0
  refuse_taken_note "$brief" "$held" "$since" >&2
  return 1
}

# --- Reads.

# One mark's values as "<session><US><since>", each empty where its line is
# missing.
read_mark() {
  awk -v US="$HEADER_US" '
    index($0, "session: ") == 1 { session = substr($0, 10) }
    index($0, "since: ") == 1 { since = substr($0, 8) }
    END { print session US since }
  ' "$1"
}

# True if the marks folder can be listed, or is not there at all: a missing
# folder is the normal state of no marks yet.
is_listable_marks_dir() {
  [ ! -e "$1" ] && return 0
  [ -d "$1" ] && [ -r "$1" ] && [ -x "$1" ]
}

# Nothing where the marks folder can be listed; a refusal on stderr and a
# non-zero status otherwise. A folder that exists but cannot be listed reads
# to a glob as one holding no marks, which would offer taken briefs as ready,
# let a held brief be taken, and make freeing do nothing without a word. What
# cannot be told is refused, here in one place: reading the marks goes through
# it, and so does every write, which may never be preceded by a read.
refuse_unreadable_marks_dir() {
  is_listable_marks_dir "$1" && return 0
  refuse_marks_unreadable_note "$1" >&2
  return 1
}

# Every mark in the folder as "<brief><US><session><US><since>", in name
# order; nothing where the folder is missing, and refused where it cannot be
# read. A file whose name starts with a dot is never a mark: that is where a
# mark is written before it is put in place, and a half-written one must not
# be read.
list_mark_rows() {
  local dir="$1" f
  refuse_unreadable_marks_dir "$dir" || return 1
  [ -d "$dir" ] || return 0
  for f in "$dir"/*; do
    [ -f "$f" ] || continue
    printf '%s%s%s\n' "$(basename "$f")" "$HEADER_US" "$(read_mark "$f")"
  done | LC_ALL=C sort
}

# The briefs one session holds, one line each as "<brief><TAB><age>", in name
# order, the age as of the given stamp; nothing where it holds none. A tab
# parts the two because the lines leave the organizer for whatever runs it,
# and an age holds a space.
#
# Refused, with nothing printed, where the folder cannot be listed, or where a
# mark cannot be read and might be this session's: its holder unreadable, or
# its since unreadable on a mark this session holds. Answering "none" then
# would tell a session holding a brief that it holds nothing.
list_held_briefs() {
  local dir="$1" session="$2" now="$3" rows brief held since age lines=""
  is_session_id "$session" || { refuse_bad_session_note "$session" >&2; return 1; }
  rows="$(list_mark_rows "$dir")" || return 1
  while IFS="$HEADER_US" read -r brief held since; do
    [ -n "$brief" ] || continue
    is_session_id "$held" || { refuse_held_unreadable_note "$brief" >&2; return 1; }
    [ "$held" = "$session" ] || continue
    age="$(format_age "$since" "$now")" || { refuse_held_unreadable_note "$brief" >&2; return 1; }
    lines+="$brief"$'\t'"$age"$'\n'
  done <<<"$rows"
  printf '%s' "$lines"
}

# --- Writes.

# Mark a brief taken by a session, as of the given stamp. Taking a brief the
# same session already holds leaves its mark, and its since, as they are; one
# another session holds is refused.
#
# The mark is written to a hidden file and then linked into place, because a
# link fails where the name already exists: two sessions taking the same brief
# at the same moment cannot both win, and nobody ever reads a half-written
# mark. The loser is answered as if the winner had been there first.
take_brief() {
  local dir="$1" brief="$2" session="$3" now="$4" mark draft held since
  is_brief_name "$brief" || { refuse_bad_name_note "$brief" >&2; return 1; }
  is_session_id "$session" || { refuse_bad_session_note "$session" >&2; return 1; }
  refuse_unreadable_marks_dir "$dir" || return 1
  mark="$dir/$brief"
  if [ -e "$mark" ]; then
    IFS="$HEADER_US" read -r held since < <(read_mark "$mark")
    refuse_held_mark "$brief" "$session" "$held" "$since"
    return
  fi
  mkdir -p "$dir"
  draft="$dir/.$brief.$$"
  printf 'session: %s\nsince: %s\n' "$session" "$now" >"$draft"
  if ln "$draft" "$mark" 2>/dev/null; then
    rm -f "$draft"
    return 0
  fi
  rm -f "$draft"
  # Where the link failed and no mark stands, something other than a race
  # stopped it; that is refused as it is, never taken for success.
  [ -e "$mark" ] || return 1
  IFS="$HEADER_US" read -r held since < <(read_mark "$mark")
  refuse_held_mark "$brief" "$session" "$held" "$since"
}

# Free every brief a session holds. Holding none is not a failure: a session
# ending without having taken anything is the common case.
free_session() {
  local dir="$1" session="$2" rows brief held since
  is_session_id "$session" || { refuse_bad_session_note "$session" >&2; return 1; }
  rows="$(list_mark_rows "$dir")" || return 1
  while IFS="$HEADER_US" read -r brief held since; do
    [ -n "$brief" ] && [ "$held" = "$session" ] || continue
    rm -f "$dir/$brief"
  done <<<"$rows"
}

# Free one brief's mark, whoever holds it. The brief need not exist any more:
# a mark left behind by a brief since finished is exactly what this clears.
free_brief() {
  local dir="$1" brief="$2"
  is_brief_name "$brief" || { refuse_bad_name_note "$brief" >&2; return 1; }
  refuse_unreadable_marks_dir "$dir" || return 1
  rm -f "$dir/$brief"
}
