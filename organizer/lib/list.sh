#!/usr/bin/env bash
# The organizer's list: the check's problems first, so they are seen, then the
# briefs ready now, those waiting and on what, and those taken and for how
# long. Sourced, never executed.
#
# Order among ready briefs is the operator's pick, so the list ranks nothing:
# every section is in name order. A broken brief appears among the problems
# only, never in a section below them, since whatever the check could not
# vouch for must not be offered as work.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/places.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/clock.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# How much of a session id the list shows: enough to tell the sessions on one
# machine apart, short enough to read at a glance.
SESSION_SHOWN_LENGTH=8

# --- Transforms.

# A brief's places: its touches and creates together, comma-joined, since a
# brief that brings a folder into being works there as surely as one that
# edits it.
derive_places() {
  local touches creates
  touches="$(parse_flow_list "$1")" || touches=""
  creates="$(parse_flow_list "$2")" || creates=""
  printf '%s' "$touches${touches:+${creates:+,}}$creates"
}

# The list, from the check's problems, the briefs' rows, the marks' rows and
# now. Each section is left out where it would be empty, and sections are
# parted by a blank line.
format_list() {
  local problems="$1" rows="$2" marks="$3" now="$4"
  local broken subject text brief session since name summary after touches creates items
  local ready=() waiting=() taken=() places_lines="" same="" opened=""
  local -A held_by since_of age_of summary_of after_of
  broken="$(cut -d "$HEADER_US" -f 1 <<<"$problems" | paste -sd, -)"

  while IFS="$HEADER_US" read -r brief session since; do
    [ -n "$brief" ] || continue
    held_by[$brief]="$session"
    since_of[$brief]="$since"
  done <<<"$marks"

  while IFS="$HEADER_US" read -r name summary after touches creates; do
    [ -n "$name" ] || continue
    has_list_item "$broken" "$name" && continue
    items="$(parse_flow_list "$after")"
    summary_of[$name]="$summary"
    after_of[$name]="$items"
    if [ -n "${held_by[$name]+held}" ]; then
      taken+=("$name")
      age_of[$name]="$(format_age "${since_of[$name]}" "$now")"
      places_lines+="taken$HEADER_US$name$HEADER_US$(derive_places "$touches" "$creates")$HEADER_US${age_of[$name]}"$'\n'
    elif [ -z "$items" ]; then
      ready+=("$name")
      places_lines+="ready$HEADER_US$name$HEADER_US$(derive_places "$touches" "$creates")$HEADER_US"$'\n'
    else
      waiting+=("$name")
    fi
  done <<<"$rows"
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
      list_ready_line "$name" "${summary_of[$name]}"
      format_same_places "$name" "$same"
    done
  fi

  if [ "${#waiting[@]}" -gt 0 ]; then
    [ -n "$opened" ] && echo
    opened=1
    list_waiting_heading
    for name in "${waiting[@]}"; do
      list_waiting_line "$name" "${after_of[$name]//,/, }"
    done
  fi

  if [ "${#taken[@]}" -gt 0 ]; then
    [ -n "$opened" ] && echo
    list_taken_heading
    for name in "${taken[@]}"; do
      list_taken_line "$name" "${age_of[$name]}" "${held_by[$name]:0:$SESSION_SHOWN_LENGTH}"
    done
  fi
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
  local plans="$1" root="$2" marks="$3" now="$4" problems
  problems="$(list_problems "$plans" "$root" "$marks")"
  format_list "$problems" "$(list_brief_rows "$plans")" "$(list_mark_rows "$marks")" "$now"
  [ -z "$problems" ]
}
