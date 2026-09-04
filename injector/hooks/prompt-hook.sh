#!/usr/bin/env bash
# Claude Code UserPromptSubmit hook — the thin orchestrator for turn-start.
#
# It wires three concerns and holds none of their logic:
#   1. digest      — put the approach rules in front of the model before it plans.
#   2. conventions — name where the written ones live, so they are followed
#                    rather than rediscovered.
#   3. question    — close with the rule for a question turn, so it is the last
#                    thing read before the prompt.
#
# All three are advice. Nothing here blocks, and that is deliberate: a stage
# that acted on a guess about what the operator meant would block work they
# asked for.
#
# Hook contract (Claude Code): a JSON event arrives on stdin; stdout is added to
# the model's context before the turn begins. The event is never read. Nothing
# printed depends on the prompt, so no JSON parser is needed and none can be
# missing. Whether a turn is a question is the model's to judge with the whole
# prompt in view — a word-list guess here missed often enough to be noise.
#
# Fail open: nothing here enforces, it only advises — so a broken turn-start
# hook must not make the session unusable.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/rules-dir.sh"
. "$tool_root/lib/conventions-dir.sh"

# Drain the event so the writer never meets a closed pipe. Skipped on a
# terminal, where there is nothing to drain and cat would wait for a keypress.
[ -t 0 ] || cat >/dev/null

"$tool_root/steps/rules-digest.sh" "$(rules_dir)"

"$tool_root/steps/conventions-pointer.sh" "$(conventions_dir)"

"$tool_root/steps/question-rule.sh" "$(rules_dir)"
exit 0
