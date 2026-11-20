#!/usr/bin/env bash
# Build the digest of rules that must be in view before work starts: every rule
# and every shape tagged `premise` or `before-thinking`, one line each, from its
# own frontmatter. Both folders share the same groups, in one order by name: a
# reader settling what applies before planning needs one list, not two.
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
# Usage: <rules-dir> <shapes-dir>
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/rules-dir.sh"
. "$tool_root/lib/rule-format.sh"
. "$tool_root/lib/refusal.sh"

rules_from="$1"
shapes_from="$2"

# A directory with no entries is a refused turn, not an empty digest. The
# reason goes to the operator on stderr, and the exit code is the one the hook
# refuses with, so this step means the same thing run alone as run from it. A
# directory that cannot be listed has already said so on stderr, and is
# refused without the no-entries note, which would give the operator the wrong
# reason.
require_entries() {
  local dir="$1" note="$2" found=0
  has_rule_files "$dir" || found=$?
  if [ "$found" -eq 1 ]; then
    "$note" "$dir" >&2
    exit 2
  fi
  [ "$found" -eq 0 ] || exit 2
}
require_entries "$rules_from" no_rules_note
require_entries "$shapes_from" no_shapes_note

# Read every rule's frontmatter once. One parse, so the digest and the report
# of broken rules can never disagree about what a file contains. The listing
# is taken before the loop rather than fed to it from a process substitution,
# whose failure nothing would see: a folder that stopped being readable since
# the check above must refuse the turn, not empty the digest.
scan_rules() {
  local f files shapes
  files="$(list_rule_files "$rules_from")" || return 1
  shapes="$(list_rule_files "$shapes_from")" || return 1
  files+=$'\n'"$shapes"
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    rule_frontmatter_row "$f"
  done <<<"$files" | sort -t "$RULE_US" -k1,1
}

RULES="$(scan_rules)" || exit 2

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
  echo "These rule or shape files are missing frontmatter, so they appear nowhere above."
  echo "They are still policy — read them, and fix the file:"
  printf '%s' "$out"
}

echo "## Rules in force"
echo
echo "These shape how the work is approached, so they are decided before you plan,"
echo "not caught afterwards. Full text: $rules_from and $shapes_from"
echo
echo "Premises — the lens for everything below:"
emit_tagged premise
echo
echo "Approach — settle these before you write anything:"
emit_tagged before-thinking
emit_unreadable
