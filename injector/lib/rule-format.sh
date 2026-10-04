#!/usr/bin/env bash
# The rule-file format, in one place: a rule's header holds `enforce:` and
# `summary:`, read by the kit's shared header reader. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"

# The field separator for rule rows. It is the header reader's own, not one of
# this file's: a row is the name joined to what that reader hands back, so any
# other separator would split the row in the wrong places.
RULE_US="$HEADER_US"

# One rule's frontmatter as "<name><RULE_US><tags><RULE_US><summary>". A
# missing field comes back empty rather than dropping the row, so the caller
# decides what to do about it.
rule_frontmatter_row() {
  local f="$1"
  printf '%s%s%s\n' "$(basename "$f" .md)" "$RULE_US" "$(read_header_fields "$f" enforce summary)"
}
