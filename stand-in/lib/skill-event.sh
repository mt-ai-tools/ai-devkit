#!/usr/bin/env bash
# What the skill hook reads from Claude Code's after-tool event and the answer
# it gives back. Needs jq, for the reason the gate's event reader gives. Every
# function here is a transform. Sourced, never executed.

# The name of the skill the event loaded; nothing where the event is not a
# skill loading, or not JSON at all.
to_skill_loaded() {
  jq -r 'if .tool_name == "Skill" then (.tool_input.skill // "") else "" end | strings' \
    2>/dev/null <<<"$1" || true
}

# The words the skill was loaded with, as the model passed them; nothing where
# it passed none.
to_skill_args() {
  jq -r '.tool_input.args // "" | strings' 2>/dev/null <<<"$1" || true
}

# The hook's answer: the message the user's terminal shows whole, every byte
# as given, and the note the model reads in its place, since it never sees
# the message.
to_skill_answer() {
  jq -cn --arg message "$1" --arg note "$2" '{
    systemMessage: $message,
    hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}
  }'
}
