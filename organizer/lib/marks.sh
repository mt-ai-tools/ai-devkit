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

# The marks folder's state, by name: `missing`, the normal state of no marks
# yet; `unlistable`, where it exists but its marks cannot be listed, or is not
# a folder at all; `unwritable`, where they can be listed but none can be
# added or removed; `usable` otherwise. Unlistable wins over unwritable, since
# a folder that cannot be listed cannot be written safely either. Always
# answers, so it is a get, never a find.
get_marks_dir_state() {
  if [ ! -e "$1" ]; then
    printf 'missing\n'
  elif ! [ -d "$1" ] || ! [ -r "$1" ] || ! [ -x "$1" ]; then
    printf 'unlistable\n'
  elif ! [ -w "$1" ]; then
    printf 'unwritable\n'
  else
    printf 'usable\n'
  fi
}

# Nothing where the marks folder can be listed or is missing; a refusal on
# stderr and a non-zero status otherwise. A folder that exists but cannot be
# listed reads to a glob as one holding no marks, which would offer taken
# briefs as ready, let a held brief be taken, and make freeing do nothing
# without a word. What cannot be told is refused, here in one place: reading
# the marks goes through it, and so does every write, by way of the writable
# check below, since a write may never be preceded by a read. A state it does
# not know is refused too, so a state added later fails closed until placed.
refuse_unreadable_marks_dir() {
  case "$(get_marks_dir_state "$1")" in
    missing | usable | unwritable) return 0 ;;
  esac
  refuse_marks_unreadable_note "$1" >&2
  return 1
}

# Nothing where marks can be added to and removed from the folder, or it is
# missing, which taking makes and freeing has nothing to remove from; a
# refusal on stderr and a non-zero status otherwise. Every write calls it
# before changing anything, so none can forget it: let through, taking and
# freeing failed with the shell's own words, and finishing deleted the brief
# before failing on its mark, leaving a mark that names a brief now gone.
refuse_unwritable_marks_dir() {
  refuse_unreadable_marks_dir "$1" || return 1
  case "$(get_marks_dir_state "$1")" in
    missing | usable) return 0 ;;
  esac
  refuse_marks_unwritable_note "$1" >&2
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
  refuse_unwritable_marks_dir "$dir" || return 1
  mark="$dir/$brief"
  if [ -e "$mark" ]; then
    IFS="$HEADER_US" read -r held since < <(read_mark "$mark")
    refuse_held_mark "$brief" "$session" "$held" "$since"
    return
  fi
  # A folder that is missing passed the check, and one that cannot be made, or
  # was closed since the check, is refused in the organizer's own words.
  if ! mkdir -p "$dir" 2>/dev/null; then
    refuse_marks_unwritable_note "$dir" >&2
    return 1
  fi
  draft="$dir/.$brief.$$"
  if ! { printf 'session: %s\nsince: %s\n' "$session" "$now" >"$draft"; } 2>/dev/null; then
    refuse_marks_unwritable_note "$dir" >&2
    return 1
  fi
  # A draft that cannot be removed is said, never left unmentioned, but it
  # does not undo a take: the mark stands, and a hidden draft is never read
  # as one.
  if ln "$draft" "$mark" 2>/dev/null; then
    remove_draft "$draft" || true
    return 0
  fi
  # Where the link failed and no mark stands, something other than a race
  # stopped it; that is refused as it is, never taken for success, and the
  # refusal is said before anything about the draft.
  if [ ! -e "$mark" ]; then
    refuse_mark_not_placed_note "$brief" >&2
    remove_draft "$draft" || true
    return 1
  fi
  remove_draft "$draft" || true
  IFS="$HEADER_US" read -r held since < <(read_mark "$mark")
  refuse_held_mark "$brief" "$session" "$held" "$since"
}

# Remove a mark's hidden draft. One that cannot be removed, the folder closed
# since it was written, is named on stderr in the organizer's own words with a
# non-zero status, rather than left behind with only rm's message, or none.
remove_draft() {
  rm -f "$1" 2>/dev/null && return 0
  refuse_draft_left_note "$1" >&2
  return 1
}

# Free every brief a session holds. Holding none is not a failure: a session
# ending without having taken anything is the common case.
free_session() {
  local dir="$1" session="$2" rows brief held since
  is_session_id "$session" || { refuse_bad_session_note "$session" >&2; return 1; }
  refuse_unwritable_marks_dir "$dir" || return 1
  rows="$(list_mark_rows "$dir")" || return 1
  while IFS="$HEADER_US" read -r brief held since; do
    [ -n "$brief" ] && [ "$held" = "$session" ] || continue
    remove_mark "$dir" "$brief" || return 1
  done <<<"$rows"
}

# Free one brief's mark, whoever holds it. The brief need not exist any more:
# a mark left behind by a brief since finished is exactly what this clears.
free_brief() {
  local dir="$1" brief="$2"
  is_brief_name "$brief" || { refuse_bad_name_note "$brief" >&2; return 1; }
  refuse_unwritable_marks_dir "$dir" || return 1
  remove_mark "$dir" "$brief"
}

# Remove one brief's mark, where there is one. A removal that fails all the
# same, the folder closed since the check, is refused in the organizer's own
# words and with a non-zero status, which finishing relies on to stop before
# it changes any brief.
remove_mark() {
  local dir="$1" brief="$2"
  rm -f "$dir/$brief" 2>/dev/null && return 0
  refuse_marks_unwritable_note "$dir" >&2
  return 1
}
