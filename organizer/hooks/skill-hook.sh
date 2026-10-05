#!/usr/bin/env bash
# Claude Code after-tool hook for the Skill tool — the thin orchestrator that
# shows the user the organizer's list when the model loads the organizer's
# own skill, and stays silent for every other skill.
#
# Why the list goes through a hook and not through the model: a skill that
# put the list in the model's context and asked for it to be copied lost the
# last line in one run of six. A hook's systemMessage reaches the user's
# terminal whole, exactly as written, with no model in between.
#
# The model never sees the systemMessage, so it is handed a short note in
# additionalContext saying what was shown. The skill tells it to point at
# the list when the note is there, and to say the hook is not mounted when
# it is not: a project that mounted the skill alone is told so, instead of
# being told "above" with nothing above.
#
# Hook contract (Claude Code): the event arrives as JSON on stdin; the answer
# is JSON on stdout. Whatever the list's own status, the list is shown: the
# organizer exits non-zero whenever its check finds a problem, and the
# problems are already first in what it printed. A refusal goes to its
# stderr and is the answer too. Where the organizer cannot be run at all,
# the user is told so; the list is never silently missing.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/skill-event.sh"

# Both found from this hook's own place in the kit, never from the project's
# layout: the kit names no project folder.
skill_file="$tool_root/skills/whats-next/SKILL.md"
organizer="$tool_root/bin/organizer.sh"

loaded="$(skill_loaded_name)"
[ -n "$loaded" ] || exit 0

# A name that cannot be read is an error, not "some other skill": silence
# here would leave every load of the organizer's skill with no list and no
# reason.
own="$(skill_own_name "$skill_file" 2>/dev/null)" || own=""
if [ -z "$own" ]; then
  skill_name_unreadable_note "$skill_file" >&2
  exit 1
fi
[ "$loaded" = "$own" ] || exit 0

if [ ! -f "$organizer" ] || [ ! -x "$organizer" ]; then
  skill_answer "$(skill_organizer_unrunnable_note "$organizer")" "$(skill_unrunnable_shown_note)"
  exit 0
fi

# The trailing "x" keeps the output's final newline, which a command
# substitution would strip: the user is shown every byte the organizer wrote.
shown="$("$organizer" list 2>&1 || true; printf x)"
shown="${shown%x}"

skill_answer "$shown" "$(skill_list_shown_note "$(count_lines "$shown")")"
