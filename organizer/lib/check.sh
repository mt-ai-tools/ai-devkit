#!/usr/bin/env bash
# The header check: every way a brief's header can be wrong, every way the
# briefs folder can hold a file or folder outside its levels, and every mark
# naming a brief that is gone. Sourced, never executed.
#
# A problem travels as "<brief><US><line>", the line being the words shown to
# the operator. A brief with any problem is broken, and a broken brief is never
# offered as ready: what the check cannot vouch for is refused, per brief, so
# one bad header does not hide the rest of the folder. A mark's problem carries
# no brief where the brief it names is not there to be broken, and so does a
# folder that is no level.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/levels.sh"
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

# Level names handed in, as one line for the operator to read.
format_level_names() {
  local joined
  printf -v joined '%s, ' "$@"
  printf '%s' "${joined%, }"
}

# Every level with what it means, as one line for the operator to read, read
# off the kit's level list. Parted by semicolons, since a meaning may hold a
# comma. Where a level is refused, this is where the operator learns what the
# levels mean: the README names the folders and leaves their meanings here.
format_level_meanings() {
  local joined entry
  for entry in "${BRIEF_LEVELS[@]}"; do
    joined+="${entry%%=*} (${entry#*=}); "
  done
  printf '%s' "${joined%; }"
}

# What is wrong with one brief's row, judged alone: its name, lying in no
# level, a field missing or not in form, an after entry that is no name, a
# path that leaves the root. A summary written as a folded block is refused,
# for the reason is_folded_marker gives.
#
# A file in no level is a problem rather than a brief allowed beside the
# levels: a folder holds files or folders, never a mix, and a pile let lie
# there grows back into the unsorted list the levels replace. A draft is held
# to its summary and its level alone: it is an item not yet written out, which
# has no after, touches or creates to judge until the operator's yes makes it
# a brief. One lying where no draft may lie is a problem, for the reason
# DRAFT_LEVEL_NAMES gives; one in no level is a problem already.
derive_brief_problems() {
  local name summary after touches creates draft level field value items item list
  IFS="$HEADER_US" read -r name summary after touches creates draft level <<<"$1"
  is_brief_name "$name" || problem_row "$name" "$(problem_bad_name_note "$name")"
  [ -n "$level" ] || problem_row "$name" "$(problem_in_no_level_note "$name")"
  if [ -z "$summary" ]; then
    problem_row "$name" "$(problem_missing_field_note "$name" summary)"
  elif is_folded_marker "$summary"; then
    problem_row "$name" "$(problem_folded_summary_note "$name")"
  fi
  if is_draft_value "$draft"; then
    [ -z "$level" ] || is_draft_level_name "$level" ||
      problem_row "$name" "$(problem_draft_level_note "$name" "$level" "$(format_level_names "${DRAFT_LEVEL_NAMES[@]}")")"
    return 0
  fi
  # Any other value fails closed: whether `draft: yes` meant a draft or a brief
  # cannot be told, and read as a brief it would be offered as work. Its other
  # fields are not judged here: a missing after or touches would assume the
  # brief reading nobody chose, and bury the one line that needs fixing.
  if [ -n "$draft" ]; then
    problem_row "$name" "$(problem_bad_draft_value_note "$name" "$draft")"
    return 0
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
# A draft's after list is never judged; derive_brief_problems says why.
derive_missing_after_problems() {
  local rows="$1" names name summary after touches creates draft level items item list
  names="$(cut -d "$HEADER_US" -f 1 <<<"$rows" | paste -sd, -)"
  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] || continue
    ! is_draft_value "$draft" || continue
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
# reported rather than only the first found, and none of them is offered. A
# draft's after list is read as empty, since it is never judged.
derive_cycle_names() {
  local rows="$1" name summary after touches creates draft level items
  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] || continue
    items="$(parse_flow_list "$after")" || items=""
    ! is_draft_value "$draft" || items=""
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

# A problem row for every name found in more than one level, naming each, in
# the order the rows came in. Operations address a brief by name alone, so
# with two files under one name they could not tell which was meant. A file
# in no level is left out: it is never found by name, and is a problem of its
# own already.
derive_name_in_levels_problems() {
  local rows="$1" name summary after touches creates draft level order=()
  local -A levels_of
  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] && [ -n "$level" ] || continue
    [ -n "${levels_of[$name]+found}" ] || order+=("$name")
    levels_of[$name]+="${levels_of[$name]:+, }$level"
  done <<<"$rows"
  for name in "${order[@]}"; do
    [[ "${levels_of[$name]}" == *", "* ]] || continue
    problem_row "$name" "$(problem_name_in_levels_note "$name" "${levels_of[$name]}")"
  done
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
# brief has no business naming. A draft names no places that are judged.
list_place_problems() {
  local rows="$1" root="$2" name summary after touches creates draft level items item list
  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] || continue
    ! is_draft_value "$draft" || continue
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

# Every problem in the briefs folder and the marks folder: each folder that
# is no level first, then the briefs' grouped by brief in name order, the
# marks' after them. A folder that is no level is never looked into: what it
# holds is in no level, and a typo in its name would otherwise show as a level
# of its own. A marks folder that cannot be read is one problem naming no
# brief, shown in place of the marks' own: what a mark says cannot be told
# when the marks cannot be read.
list_problems() {
  local plans="$1" root="$2" marks="$3" rows row names mark_rows folders folder
  rows="$(list_brief_rows "$plans")" || return 1
  names="$(cut -d "$HEADER_US" -f 1 <<<"$rows" | paste -sd, -)"
  folders="$(list_unknown_level_folders "$plans")"
  while IFS= read -r folder; do
    [ -n "$folder" ] || continue
    problem_row "" "$(problem_unknown_level_folder_note "$folder" "$(format_level_names "${BRIEF_LEVEL_NAMES[@]}")")"
  done <<<"$folders"
  {
    while IFS= read -r row; do
      [ -n "$row" ] || continue
      derive_brief_problems "$row"
    done <<<"$rows"
    derive_missing_after_problems "$rows"
    derive_name_in_levels_problems "$rows"
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
