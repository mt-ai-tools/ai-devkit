#!/usr/bin/env bash
# The briefs sessions have taken, and which of them work where a path lies:
# asked by whatever must not change a place another session is working in.
# Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/places.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Reads.

# Every taken brief, one "<brief><TAB><session>" line each, in name order;
# given paths, only those working where any of them lies, a brief's places
# being its touches and creates together, as the list reads them. A tab parts
# the two because the lines leave the organizer, as held's do.
#
# Refused, with nothing printed, where an answer could leave out a brief that
# works there: the marks cannot be listed, a mark's holder cannot be read, or
# a taken brief's places cannot be. Whoever asks is deciding whether it may
# change a path, and a brief left out of the answer reads as nobody working
# there. A path that leaves the root is refused too, since no brief can name
# one. A mark whose brief is gone is left out: it names no places, so nothing
# is worked on there, and the check already shows it as a problem.
list_taken_briefs() {
  local plans="$1" marks="$2" path rows brief held since name summary after touches creates places table=""
  local -A held_by
  shift 2
  for path in "$@"; do
    is_inside_root_path "$path" || { refuse_path_outside_note "$path" >&2; return 1; }
  done
  rows="$(list_mark_rows "$marks")" || return 1
  while IFS="$HEADER_US" read -r brief held since; do
    [ -n "$brief" ] || continue
    is_session_id "$held" || { refuse_taken_mark_unreadable_note "$brief" >&2; return 1; }
    held_by[$brief]="$held"
  done <<<"$rows"
  while IFS="$HEADER_US" read -r name summary after touches creates; do
    [ -n "$name" ] && [ -n "${held_by[$name]+held}" ] || continue
    if ! parse_flow_list "$touches" >/dev/null || ! parse_flow_list "$creates" >/dev/null; then
      refuse_places_unreadable_note "$name" >&2
      return 1
    fi
    places="$(derive_places "$touches" "$creates")"
    table+="$name$HEADER_US${held_by[$name]}$HEADER_US$places"$'\n'
  done < <(list_brief_rows "$plans")
  if [ "$#" -gt 0 ]; then
    table="$(printf '%s' "$table" | derive_places_holding "$@")"
  fi
  while IFS="$HEADER_US" read -r name held rest; do
    [ -n "$name" ] || continue
    printf '%s\t%s\n' "$name" "$held"
  done <<<"$table"
}
