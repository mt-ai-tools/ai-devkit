#!/usr/bin/env bash
# The drafts: items not yet written out as briefs, each in its level. The list
# counts them and the drafts command lists them in full, both from the rows
# picked here, so a count and the listing beside it never disagree. Sourced,
# never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/names.sh"
. "$(dirname "${BASH_SOURCE[0]}")/flow-list.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# --- Transforms.

# The drafts among the rows, in level order and by name within a level,
# leaving out every one the check found a problem with, as the list leaves out
# every broken brief: what the check cannot vouch for is shown among the
# problems and nowhere else. A draft in no level is one of those.
derive_draft_rows() {
  local problems="$1" rows="$2" broken row name summary after touches creates draft level
  broken="$(cut -d "$HEADER_US" -f 1 <<<"$problems" | paste -sd, -)"
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    IFS="$HEADER_US" read -r name summary after touches creates draft level <<<"$row"
    is_draft_value "$draft" || continue
    has_list_item "$broken" "$name" && continue
    printf '%s\n' "$row"
  done <<<"$(with_level_order "$rows")"
}

# One line per draft, from the rows derive_draft_rows picked; given a level,
# only that level's.
format_drafts() {
  local rows="$1" only="${2:-}" name summary after touches creates draft level
  while IFS="$HEADER_US" read -r name summary after touches creates draft level; do
    [ -n "$name" ] || continue
    [ -z "$only" ] || [ "$level" = "$only" ] || continue
    drafts_line "$name" "$level" "$summary"
  done <<<"$rows"
}

# --- Reads.

# Every draft in full, or a level's alone where one is given: name, level and
# summary, in level order and by name within a level. A level handed in is
# judged before anything is built from it, as every level is, so a value such
# as `../x` is refused as no level rather than looked for; an empty one is
# refused too, never read as all. The status
# is non-zero where the check found any problem, as the list's is, since a
# draft it found one with is left out here; a line on stderr says so and where
# the problems are shown, since this command shows none of them.
list_drafts() {
  local plans="$1" root="$2" marks="$3" only="" problems rows
  if [ "$#" -ge 4 ]; then
    only="$4"
    is_level_name "$only" || { refuse_bad_level_note "$only" "$(format_level_meanings)" >&2; return 1; }
  fi
  problems="$(list_problems "$plans" "$root" "$marks")" || return 1
  rows="$(list_brief_rows "$plans")" || return 1
  format_drafts "$(derive_draft_rows "$problems" "$rows")" "$only"
  [ -n "$problems" ] || return 0
  drafts_problems_note >&2
  return 1
}
