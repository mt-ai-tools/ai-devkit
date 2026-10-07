#!/usr/bin/env bash
# A brief's wait on another: written into its after list, and read back.
# Sourced, never executed.
#
# The after list is the one record of what a brief waits on, whether written
# when the brief was planned or later, by a session that found it must wait
# for another session's brief to be finished: the list, take and the check
# already read it, and finishing the brief waited for takes the name out as it
# takes out any other, so a wait written here ends with no step of its own.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/done.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Transforms.

# The briefs' rows given, with the after list of the brief named replaced by
# the comma-joined list given, every other row as it was.
with_after_row() {
  local rows="$1" brief="$2" items="$3" name summary after rest
  while IFS="$HEADER_US" read -r name summary after rest; do
    [ -n "$name" ] || continue
    [ "$name" != "$brief" ] || after="$(format_flow_list "$items")"
    printf '%s%s%s%s%s%s%s\n' "$name" "$HEADER_US" "$summary" "$HEADER_US" "$after" "$HEADER_US" "$rest"
  done <<<"$rows"
}

# --- Reads.

# The briefs a brief waits on, one a line, in the order its after list names
# them; nothing where it waits on none. Refused, with nothing printed, where
# the brief is unknown, its after list cannot be read, or the list names a
# brief that is not in the folder: whoever asks is deciding whether a wait is
# over, and a name left behind is never read as finished, as the check never
# reads one so either.
list_awaited_briefs() {
  local plans="$1" brief="$2" after items item list=()
  refuse_unknown_brief "$plans" "$brief" || return 1
  after="$(read_header_fields "$(brief_file "$plans" "$brief")" after)"
  if ! items="$(parse_flow_list "$after")"; then
    refuse_header_unreadable_note "$brief" >&2
    return 1
  fi
  IFS=, read -ra list <<<"$items"
  for item in "${list[@]}"; do
    if ! is_brief_name "$item" || [ ! -f "$(brief_file "$plans" "$item")" ]; then
      refuse_awaited_missing_note "$brief" "$item" >&2
      return 1
    fi
  done
  for item in "${list[@]}"; do
    printf '%s\n' "$item"
  done
}

# --- Writes.

# Write a wait into a brief: the brief given to wait on added to the end of
# its after list, and the path changed printed, for whoever called it to
# commit; nothing printed where it already waits on it, since nothing changed.
# Only the after line changes, every other byte copied as it stood, through a
# hidden draft moved into place, as finishing writes a waiter.
#
# Refused, changing nothing, where either brief is unknown, the two are one,
# the after list cannot be read, or the wait would close a cycle: a brief on
# a cycle can never start, and the check would show every brief on it as
# broken, the one whose session waits among them.
write_wait() {
  local plans="$1" brief="$2" on="$3" file after items rows line draft
  refuse_unknown_brief "$plans" "$brief" || return 1
  refuse_unknown_brief "$plans" "$on" || return 1
  if [ "$brief" = "$on" ]; then
    refuse_wait_self_note "$brief" >&2
    return 1
  fi
  file="$(brief_file "$plans" "$brief")"
  after="$(read_header_fields "$file" after)"
  if ! items="$(parse_flow_list "$after")"; then
    refuse_header_unreadable_note "$brief" >&2
    return 1
  fi
  ! has_list_item "$items" "$on" || return 0
  items="${items:+$items,}$on"
  rows="$(list_brief_rows "$plans")" || return 1
  if has_list_item "$(derive_cycle_names "$(with_after_row "$rows" "$brief" "$items")" | paste -sd, -)" "$brief"; then
    refuse_wait_cycle_note "$brief" "$on" >&2
    return 1
  fi
  line="$(find_header_line "$file" after)"
  draft="$plans/.$brief.wait.$$"
  if ! write_with_line "$file" "$line" "after: $(format_flow_list "$items")" "$draft" 2>/dev/null \
    || ! mv "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_wait_unwritten_note "$brief" >&2
    return 1
  fi
  printf '%s\n' "$file"
}
