#!/usr/bin/env bash
# The rule-file format, in one place: frontmatter is the leading block
# delimited by `---` lines, holding `enforce:` and `summary:`; everything after
# is the body. Sourced, never executed.

# The field separator for frontmatter rows: the ASCII unit separator. Not a
# tab: bash treats tab as IFS whitespace and collapses a run of them, so an
# empty middle field would silently shift the ones after it — which is the
# exact failure callers exist to report.
RULE_US=$'\037'

# One rule's frontmatter as "<name><RULE_US><tags><RULE_US><summary>". A
# missing field comes back empty rather than dropping the row, so the caller
# decides what to do about it.
rule_frontmatter_row() {
  local f="$1"
  awk -v name="$(basename "$f" .md)" -v US="$RULE_US" '
    NR == 1 && $0 != "---" { printed = 1; print name US US; exit }
    /^enforce:/ { sub(/^enforce:[[:space:]]*/, ""); tags = $0; next }
    /^summary:/ { sub(/^summary:[[:space:]]*/, ""); summary = $0; next }
    NR > 1 && /^---$/ { printed = 1; print name US tags US summary; exit }
    END { if (!printed) print name US tags US summary }
  ' "$f"
}
