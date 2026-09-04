#!/usr/bin/env bash
# Build the digest of rules that must be in view before work starts: every rule
# tagged `premise` or `before-thinking`, one line each, from its own frontmatter.
#
# Summaries, not full rule text. A digest that small is cheap enough to run
# every turn,
# and running every turn is the whole point — it is what a CLAUDE.md pointer,
# read once at session start, cannot do. The pointer at the end is how the agent
# reaches the full text when a rule actually bites.
#
# A rule missing `enforce:` or `summary:` is named at the end rather than left
# out in silence. Dropping it quietly would mean a rule that exists, reads as
# policy, and is never once put in front of anyone — with nothing to show that
# had happened.
#
# Usage: <rules-dir>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/rules-dir.sh"
. "$tool_root/lib/rule-format.sh"

rules_from="$1"

# The rules live outside this repo, so they can simply be absent. Printing
# "Rules in force" over an empty list would be the worst of both — the agent
# told that rules apply, and shown none of them.
if ! has_rule_files "$rules_from"; then
  echo "## No rules loaded"
  echo
  echo "No rule files at: $rules_from"
  echo "Nothing is enforcing any rules this turn."
  exit 0
fi

# Read every rule's frontmatter once. One parse, so the digest and the report
# of broken rules can never disagree about what a file contains.
scan_rules() {
  local f
  while IFS= read -r f; do
    rule_frontmatter_row "$f"
  done < <(list_rule_files "$rules_from")
}

RULES="$(scan_rules)"

emit_tagged() {
  local want="$1" name tags summary
  while IFS="$RULE_US" read -r name tags summary; do
    [ -n "$name" ] || continue
    case "$tags" in *"$want"*) ;; *) continue ;; esac
    [ -n "$summary" ] || continue
    printf -- '- %s — %s\n' "$name" "$summary"
  done <<<"$RULES"
}

emit_unreadable() {
  local name tags summary missing out=""
  while IFS="$RULE_US" read -r name tags summary; do
    [ -n "$name" ] || continue
    missing=""
    [ -n "$tags" ] || missing="enforce:"
    [ -n "$summary" ] || missing="${missing:+$missing and }summary:"
    [ -n "$missing" ] || continue
    out="${out}- ${name} — no ${missing}"$'\n'
  done <<<"$RULES"
  [ -n "$out" ] || return 0
  echo
  echo "These rule files are missing frontmatter, so they appear nowhere above."
  echo "They are still policy — read them, and fix the file:"
  printf '%s' "$out"
}

echo "## Rules in force"
echo
echo "These shape how the work is approached, so they are decided before you plan,"
echo "not caught afterwards. Full text: $rules_from"
echo
echo "Premises — the lens for everything below:"
emit_tagged premise
echo
echo "Approach — settle these before you write anything:"
emit_tagged before-thinking
emit_unreadable
