#!/usr/bin/env bash
# Close the turn's advice with the rule for a question, quoted from the rule
# file. Printed every turn rather than on a guess: whether a prompt is a
# question is the model's to judge, with the whole prompt in view, and this
# step only makes sure the rule is in view at that moment — last, where it is
# read closest to the prompt.
#
# The line is the rule's own summary, quoted as every other line this tool
# prints is. Written out here instead it would be a second copy of policy,
# free to drift from the rule while reading as it — which is what it had done.
#
# Usage: <rules-dir>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/rule-format.sh"

# The rule whose moment a question is. A collection that does not hold it gets
# no line: the advice is that rule's, and this step has none of its own.
QUESTION_RULE="answer-dont-implement"

rule_file="${1:-}/$QUESTION_RULE.md"
[ -f "$rule_file" ] || exit 0

IFS="$RULE_US" read -r _ _ summary < <(rule_frontmatter_row "$rule_file")
[ -n "${summary:-}" ] || exit 0

echo
echo "If this prompt is a question, the rule for that moment:"
printf -- '- %s — %s\n' "$QUESTION_RULE" "$summary"
