#!/usr/bin/env bash
# The header check: every way a brief's header can be wrong, and every mark
# naming a brief that is gone. Sourced, never executed.
#
# A problem travels as "<brief><US><line>", the line being the words shown to
# the operator. A brief with any problem is broken, and a broken brief is never
# offered as ready: what the check cannot vouch for is refused, per brief, so
# one bad header does not hide the rest of the folder. A mark's problem carries
# no brief where the brief it names is not there to be broken.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/places.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/marks.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Transforms.

# One problem row.
problem_row() {
  printf '%s%s%s\n' "$1" "$HEADER_US" "$2"
}

# What is wrong with one brief's row, judged alone: its name, a field missing
# or not in form, an after entry that is no name, a path that leaves the root.
# A summary's folded-block marker (`>` or `|`) is refused, since the header
# reader hands back only a field's first line and the list would show the
# marker in place of the summary.
derive_brief_problems() {
  local name summary after touches creates field value items item list
  IFS="$HEADER_US" read -r name summary after touches creates <<<"$1"
  is_brief_name "$name" || problem_row "$name" "$(problem_bad_name_note "$name")"
  if [ -z "$summary" ]; then
    problem_row "$name" "$(problem_missing_field_note "$name" summary)"
  elif [[ "$summary" =~ ^[\>\|][-+0-9]*$ ]]; then
    problem_row "$name" "$(problem_folded_summary_note "$name")"
  fi
  for field in after touches creates; do
    value="${!field}"
    if [ -z "$value" ]; then
      problem_row "$name" "$(problem_missing_field_note "$name" "$field")"
      continue
    fi
    if ! items="$(parse_flow_list "$value")"; then
      problem_row "$name" "$(problem_not_a_list_note "$name" "$field")"
      continue
    fi
    list=()
    IFS=, read -ra list <<<"$items"
    for item in "${list[@]}"; do
      if [ "$field" = after ]; then
        is_brief_name "$item" || problem_row "$name" "$(problem_bad_after_name_note "$name" "$item")"
      else
        is_inside_root_path "$item" || problem_row "$name" "$(problem_path_outside_note "$name" "$field" "$item")"
      fi
    done
  done
}

# Every after entry, across the rows, that is a name but names no brief among
# them. A missing name is always a problem and never read as built: finishing a
# brief takes its name out of every after list, so one still there is a typo or
# an edit gone wrong, and reading it as done would offer blocked work as ready.
derive_missing_after_problems() {
  local rows="$1" names name summary after rest items item list
  names="$(cut -d "$HEADER_US" -f 1 <<<"$rows" | paste -sd, -)"
  while IFS="$HEADER_US" read -r name summary after rest; do
    [ -n "$name" ] || continue
    items="$(parse_flow_list "$after")" || continue
    list=()
    IFS=, read -ra list <<<"$items"
    for item in "${list[@]}"; do
      is_brief_name "$item" || continue
      has_list_item "$names" "$item" && continue
      problem_row "$name" "$(problem_after_missing_note "$name" "$item")"
    done
  done <<<"$rows"
}

# The names of every brief on a cycle of after entries, each once, in the
# order the rows came in. A cycle can never start, so each brief on it is
# reported rather than only the first found, and none of them is offered.
derive_cycle_names() {
  local rows="$1" name summary after rest items
  while IFS="$HEADER_US" read -r name summary after rest; do
    [ -n "$name" ] || continue
    items="$(parse_flow_list "$after")" || items=""
    printf '%s%s%s\n' "$name" "$HEADER_US" "$items"
  done <<<"$rows" | awk -F "$HEADER_US" '
    { count++; name[count] = $1; known[$1] = 1; after[count] = $2 }
    END {
      for (i = 1; i <= count; i++) {
        n = split(after[i], wants, ",")
        for (k = 1; k <= n; k++) if (wants[k] in known) reach[name[i], wants[k]] = 1
      }
      # Which brief leads to which, closed over every step (Warshall); a brief
      # that leads back to itself sits on a cycle.
      for (k = 1; k <= count; k++)
        for (i = 1; i <= count; i++) {
          if (!((name[i], name[k]) in reach)) continue
          for (j = 1; j <= count; j++)
            if ((name[k], name[j]) in reach) reach[name[i], name[j]] = 1
        }
      for (i = 1; i <= count; i++) if ((name[i], name[i]) in reach) print name[i]
    }
  '
}

# A problem row for every brief on a cycle.
derive_cycle_problems() {
  local name
  while IFS= read -r name; do
    [ -n "$name" ] || continue
    problem_row "$name" "$(problem_cycle_note "$name")"
  done < <(derive_cycle_names "$1")
}

# What is wrong with each mark: one naming no brief among the names given, or
# one whose lines are not a session and a since. The second is a problem of
# the brief it names too: nobody can say whether that brief is taken, so it is
# not offered as ready until the mark is freed.
derive_mark_problems() {
  local marks="$1" names="$2" brief session since
  while IFS="$HEADER_US" read -r brief session since; do
    [ -n "$brief" ] || continue
    if ! is_brief_name "$brief" || ! has_list_item "$names" "$brief"; then
      problem_row "" "$(problem_mark_orphan_note "$brief")"
    elif ! is_readable_mark "$session" "$since"; then
      problem_row "$brief" "$(problem_mark_unreadable_note "$brief")"
    fi
  done <<<"$marks"
}

# --- Reads.

# Every touches path that does not exist under the root, and every creates
# path whose folder does not. A path leaving the root is never looked at: it
# is already a problem, and looking would answer a question about a file the
# brief has no business naming.
list_place_problems() {
  local rows="$1" root="$2" name summary after touches creates items item list
  while IFS="$HEADER_US" read -r name summary after touches creates; do
    [ -n "$name" ] || continue
    if items="$(parse_flow_list "$touches")"; then
      list=()
      IFS=, read -ra list <<<"$items"
      for item in "${list[@]}"; do
        is_inside_root_path "$item" || continue
        [ -e "$root/$item" ] || problem_row "$name" "$(problem_touches_missing_note "$name" "$item")"
      done
    fi
    if items="$(parse_flow_list "$creates")"; then
      list=()
      IFS=, read -ra list <<<"$items"
      for item in "${list[@]}"; do
        is_inside_root_path "$item" || continue
        [ -d "$root/$(dirname "$item")" ] || problem_row "$name" "$(problem_creates_folder_missing_note "$name" "$item")"
      done
    fi
  done <<<"$rows"
}

# Every problem in the briefs folder and the marks folder: the briefs' grouped
# by brief in name order, the marks' after them. A marks folder that cannot be
# read is one problem naming no brief, shown in place of the marks' own: what
# a mark says cannot be told when the marks cannot be read.
list_problems() {
  local plans="$1" root="$2" marks="$3" rows row names mark_rows
  rows="$(list_brief_rows "$plans")" || return 1
  names="$(cut -d "$HEADER_US" -f 1 <<<"$rows" | paste -sd, -)"
  {
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      derive_brief_problems "$row"
    done <<<"$rows"
    derive_missing_after_problems "$rows"
    derive_cycle_problems "$rows"
    list_place_problems "$rows" "$root"
  } | LC_ALL=C sort -s -t "$HEADER_US" -k1,1
  if mark_rows="$(list_mark_rows "$marks" 2>/dev/null)"; then
    derive_mark_problems "$mark_rows" "$names"
  else
    problem_row "" "$(problem_marks_unreadable_note "$marks")"
  fi
}

# Every problem's line, as list_problems found them; the status is non-zero
# where there is any, so a caller can tell a clean folder from one that needs
# fixing without reading the words.
list_problem_lines() {
  local problems
  problems="$(list_problems "$1" "$2" "$3")" || return 1
  [ -n "$problems" ] || return 0
  cut -d "$HEADER_US" -f 2- <<<"$problems"
  return 1
}
