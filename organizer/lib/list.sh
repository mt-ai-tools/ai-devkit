#!/usr/bin/env bash
# The organizer's list: the check's problems first, so they are seen, then the
# briefs ready now, those waiting and on what, those taken and for how long,
# and how many drafts each level holds. Sourced, never executed.
#
# The order is the operator's, read off the levels: every section below the
# problems is in level order and by name within a level, and every line says
# its level. A broken brief appears among the problems only, never in a
# section below them, since whatever the check could not vouch for must not be
# offered as work. Nor is a draft, which is an item not yet written out as a
# brief; drafts are counted, never offered.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/places.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/clock.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/drafts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# How much of a session id the list shows: enough to tell the sessions on one
# machine apart, short enough to read at a glance.
SESSION_SHOWN_LENGTH=8

# --- Transforms.

# The list, from the check's problems, the briefs' rows, the marks' rows and
# now. Each section is left out where it would be empty, and sections are
# parted by a blank line. Where the marks could not be read, a fifth argument
# says so, and no brief is offered as ready or shown as taken: any of them may
# be taken, and nobody can tell which. A waiting brief is still shown waiting,
# since what it waits on is read from the briefs alone.
format_list() {
  local problems="$1" rows="$2" marks="$3" now="$4" marks_unknown="${5:-}"
  local broken subject text brief session since name summary after touches creates draft level items
  local ready=() waiting=() taken=() places_lines="" same="" opened="" unwritten
  local -A held_by since_of age_of summary_of after_of level_of
  broken="$(cut -d "$HEADER_US" -f 1 <<<"$problems" | paste -sd, -)"

  while IFS="$HEADER_US" read -r brief session since; do
    [ -n "$brief" ] || continue
    held_by[$brief]="$session"
    since_of[$brief]="$since"
  done <<<"$marks"

  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] || continue
    has_list_item "$broken" "$name" && continue
    is_draft_value "$draft" && continue
    items="$(parse_flow_list "$after")"
    level_of[$name]="$level"
    summary_of[$name]="$summary"
    after_of[$name]="$items"
    if [ -n "$marks_unknown" ]; then
      [ -z "$items" ] || waiting+=("$name")
    elif [ -n "${held_by[$name]+held}" ]; then
      taken+=("$name")
      age_of[$name]="$(format_age "${since_of[$name]}" "$now")"
      places_lines+="taken$HEADER_US$name$HEADER_US$(derive_places "$touches" "$creates")$HEADER_US${age_of[$name]}"$'\n'
    elif [ -z "$items" ]; then
      ready+=("$name")
      places_lines+="ready$HEADER_US$name$HEADER_US$(derive_places "$touches" "$creates")$HEADER_US"$'\n'
    else
      waiting+=("$name")
    fi
  done <<<"$(with_level_order "$rows")"
  same="$(printf '%s' "$places_lines" | derive_same_places)"

  if [ -n "$problems" ]; then
    opened=1
    list_problems_heading
    while IFS="$HEADER_US" read -r subject text; do
      list_problem_line "$text"
    done <<<"$problems"
  fi

  if [ "${#ready[@]}" -gt 0 ]; then
    [ -n "$opened" ] && echo
    opened=1
    list_ready_heading
    for name in "${ready[@]}"; do
      list_ready_line "$name" "${level_of[$name]}" "${summary_of[$name]}"
      format_same_places "$name" "$same"
    done
  fi

  if [ "${#waiting[@]}" -gt 0 ]; then
    [ -n "$opened" ] && echo
    opened=1
    list_waiting_heading
    for name in "${waiting[@]}"; do
      list_waiting_line "$name" "${level_of[$name]}" "${after_of[$name]//,/, }"
    done
  fi

  if [ "${#taken[@]}" -gt 0 ]; then
    [ -n "$opened" ] && echo
    opened=1
    list_taken_heading
    for name in "${taken[@]}"; do
      list_taken_line "$name" "${level_of[$name]}" "${age_of[$name]}" "${held_by[$name]:0:$SESSION_SHOWN_LENGTH}"
    done
  fi

  unwritten="$(derive_draft_rows "$problems" "$rows")"
  if [ -n "$unwritten" ]; then
    [ -n "$opened" ] && echo
    list_unwritten_heading
    format_unwritten "$unwritten"
  fi
}

# One line per level with how many drafts it holds, from the rows
# derive_draft_rows picked; the first level's drafts are named too. Named
# because an unwritten critical item is work the operator must see; only
# counted elsewhere because the list is shown whole whenever the next work is
# asked for, and every draft named would bury what can be started now. The
# drafts command lists them all.
format_unwritten() {
  local rows="$1" level name summary after touches creates draft at names
  local -A count_of names_of
  while IFS="$HEADER_US" read -r name summary after touches creates draft at; do
    [ -n "$name" ] || continue
    count_of[$at]="$((${count_of[$at]:-0} + 1))"
    names_of[$at]+="${names_of[$at]:+, }$name"
  done <<<"$rows"
  for level in "${BRIEF_LEVEL_NAMES[@]}"; do
    names="${names_of[$level]:-}"
    if [ "$level" = "${BRIEF_LEVEL_NAMES[0]}" ] && [ -n "$names" ]; then
      list_unwritten_named_line "$level" "${count_of[$level]}" "$names"
    else
      list_unwritten_count_line "$level" "${count_of[$level]:-0}"
    fi
  done
}

# The same-place lines under one ready brief, from what derive_same_places
# found.
format_same_places() {
  local name="$1" same="$2" ready taken age
  while IFS="$HEADER_US" read -r ready taken age; do
    [ "$ready" = "$name" ] || continue
    list_same_place_taken_line "$taken" "$age"
  done <<<"$same"
}

# --- Reads.

# The list for the briefs folder, the project root and the marks folder, as
# of now. The list is printed whatever the check found; the status is
# non-zero where it found anything, so a caller can tell a clean folder from
# one that needs fixing without reading the words.
list_briefs() {
  local plans="$1" root="$2" marks="$3" now="$4" problems rows mark_rows marks_unknown=""
  problems="$(list_problems "$plans" "$root" "$marks")" || return 1
  rows="$(list_brief_rows "$plans")" || return 1
  # The refusal's reason is already among the problems, so it is not said twice.
  mark_rows="$(list_mark_rows "$marks" 2>/dev/null)" || marks_unknown=1
  format_list "$problems" "$rows" "$mark_rows" "$now" "$marks_unknown"
  [ -z "$problems" ]
}
