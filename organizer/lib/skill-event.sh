#!/usr/bin/env bash
# What the skill's hook reads and answers: which skill an event loaded, the
# organizer's own skill's name, and the answer Claude Code takes from the
# hook. Needs jq, which the kit takes for reading and writing hook JSON: an
# event is JSON written by Claude Code, and parsing it by hand is how a
# quoted name or an escaped character slips through. Sourced, never executed.

# The name of the skill an after-tool event loaded, or nothing when the
# event is not a skill loading. The event is read from stdin.
skill_loaded_name() {
  jq -r 'if .tool_name == "Skill" then (.tool_input.skill // "") else "" end'
}

# The skill's name as its own file declares it. Read from the file rather
# than written here a second time, so the name Claude Code loads the skill by
# and the name the hook answers to cannot drift apart.
skill_own_name() {
  read_header_fields "$1" name
}

# The hook's answer: the message the user's terminal shows whole, and the
# note the model reads in its place. The message goes as given, every byte.
skill_answer() {
  jq -n --arg message "$1" --arg note "$2" '{
    systemMessage: $message,
    hookSpecificOutput: {hookEventName: "PostToolUse", additionalContext: $note}
  }'
}

# How many lines a text holds, a last line without its newline counted too.
count_lines() {
  printf '%s' "$1" | awk 'END { print NR }'
}
