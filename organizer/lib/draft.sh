#!/usr/bin/env bash
# Writing a new draft: an item decided on but not yet written out as a brief,
# put in the level its caller picks. Written here rather than by hand, so the
# draft's shape has one home, in the kit, and its level and name are judged
# before any path is built from them, as taking and finishing judge theirs.
# Sourced, never executed.
#
# What is handed in, on stdin: the summary on the first line, then the
# draft's text as it is to stand below the header, opening with its `# `
# title line. The title is handed in rather than made from the name: a name
# is a few hyphenated words, and a title says what the item is.
#
# It writes one file and stops there: it prints the path it wrote, and
# committing it is left to whoever called it, as after finishing a brief.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/levels.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Transforms.

# The summary, from what was handed in: its first line.
derive_draft_summary() {
  printf '%s' "${1%%$'\n'*}"
}

# The text, from what was handed in: every line after the first, as it came;
# nothing where only a summary came.
derive_draft_text() {
  [[ "$1" == *$'\n'* ]] || return 0
  printf '%s' "${1#*$'\n'}"
}

# True if a value can stand on a header's one line and be read back as it was
# written, which is what the check then judges. A line break would end the
# field early, and any other control character could reach a row of the
# organizer's own, whose fields are parted by one; the header reader drops a
# leading space, so a value opening with one would not read back as written;
# and a lone folded-block marker reads as the marker, for the reason
# is_folded_marker gives.
is_header_line_value() {
  [ -n "$1" ] || return 1
  [[ "$1" != *[[:cntrl:]]* ]] || return 1
  [[ "$1" != [[:space:]]* ]] || return 1
  ! is_folded_marker "$1"
}

# True if a draft's text opens with its title line: `# ` and a title, on one
# line. Every draft holds a title, since a draft and the brief it becomes are
# one file, and a brief opens with its title below the header.
is_titled_text() {
  local first="${1%%$'\n'*}"
  [[ "$first" =~ ^#\ [^[:space:]] ]] && [[ "$first" != *[[:cntrl:]]* ]]
}

# A draft's file, from its summary and text: the summary and the draft mark,
# nothing else in its header, then the text.
format_draft() {
  printf -- '---\nsummary: %s\n%s: %s\n---\n\n%s\n' "$1" "$DRAFT_FIELD" "$DRAFT_VALUE" "$2"
}

# --- Writes.

# Write a new draft by that name into that level, from what stdin hands in,
# and print the path written.
#
# Refused, writing nothing, where the level is none of the kit's, the name is
# no brief's name, the level folder is missing, the name already stands in any
# level or directly in the briefs folder, or what was handed in has no summary
# the header can hold or no title. The level and the name are judged first,
# before any path is built from them, so a value such as `../x` never reaches
# the filesystem; stdin is read only once both are judged, so a refusal of
# either never waits on it. A missing level folder is refused, never made:
# the levels are made by hand, and one made here from a typo would be a
# folder the check then shows as no level. A name standing elsewhere is
# refused, since by-name operations could not tell two files apart.
write_draft() {
  local plans="$1" level="$2" name="$3" levels input summary text file
  is_level_name "$level" || { refuse_bad_level_note "$level" "$(format_level_meanings)" >&2; return 1; }
  is_brief_name "$name" || { refuse_bad_name_note "$name" >&2; return 1; }
  [ -d "$plans/$level" ] || { refuse_no_level_folder_note "$level" "$plans" >&2; return 1; }
  levels="$(list_brief_levels "$plans" "$name")"
  [ -z "$levels" ] || { refuse_draft_name_taken_note "$name" "${levels//$'\n'/, }" >&2; return 1; }
  file="$(brief_path "$plans" "" "$name")"
  [ ! -e "$file" ] && [ ! -L "$file" ] || { refuse_draft_name_in_no_level_note "$name" >&2; return 1; }

  input="$(cat)"
  summary="$(derive_draft_summary "$input")"
  text="$(derive_draft_text "$input")"
  [ -n "$summary" ] || { refuse_draft_no_summary_note >&2; return 1; }
  is_header_line_value "$summary" || { refuse_draft_bad_summary_note >&2; return 1; }
  is_titled_text "$text" || { refuse_draft_no_title_note >&2; return 1; }

  file="$(brief_path "$plans" "$level" "$name")"
  place_new_draft "$file" "$name" "$level" "$(format_draft "$summary" "$text")" || return 1
  printf '%s\n' "$file"
}

# Put a draft's contents at its path only where nothing stands there yet.
# Written whole to a hidden copy beside it, then linked into place: a link
# fails where the name already exists, so two sessions writing one name at
# the same moment cannot overwrite each other, and nobody reads a half-written
# draft. A move does neither: it replaces what stands, and its no-clobber
# flag reports success in some versions when it moved nothing. The loser is
# answered as if the winner had been there first. The hidden copy's name
# never ends as an entry's does, so it is never read as a brief. Two sessions
# writing one name into two levels at once both succeed; the check then shows
# the name in two levels, as it shows any.
place_new_draft() {
  local file="$1" name="$2" level="$3" content="$4" hidden
  hidden="$(dirname "$file")/.$name.draft.$$"
  if ! { printf '%s\n' "$content" >"$hidden"; } 2>/dev/null; then
    rm -f "$hidden" 2>/dev/null || true
    refuse_draft_not_written_note "$file" >&2
    return 1
  fi
  if ln "$hidden" "$file" 2>/dev/null; then
    remove_hidden_copy "$hidden" || true
    return 0
  fi
  if [ -e "$file" ] || [ -L "$file" ]; then
    refuse_draft_name_taken_note "$name" "$level" >&2
  else
    refuse_draft_not_written_note "$file" >&2
  fi
  remove_hidden_copy "$hidden" || true
  return 1
}
