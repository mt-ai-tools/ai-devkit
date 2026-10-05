#!/usr/bin/env bash
# How a reading job's prompt is made: its prose, read from the stand-in's own
# prompts, with what the job is handed put in place of its placeholders.
# Sourced, never executed.
#
# The prose holds no kind and no risk: they come from the preset each time, so
# a project's own preset is what its sorter is handed, and no copy in a prompt
# can drift from it.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The prompts' folder, beside this one.
PROMPTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../prompts" && pwd)"

# A placeholder, as the prose writes one: a lower-case name in double braces.
PROMPT_PLACEHOLDER='\\{\\{(?<name>[a-z]+)\\}\\}'

# --- Transforms.

# The prompt's prose with each placeholder replaced by its value from the JSON
# object given, in one pass: a value is never searched for placeholders, so a
# reply that happens to hold one is handed over as written. A placeholder with
# no value is refused rather than left in or emptied, since either would ask
# the model about something it was never shown. The path given is only for
# the refusal. The values reach jq on stdin, never as an argument: a reply can
# outgrow what one argument to a command may hold.
to_filled_prompt() {
  local path="$1" prose="$2" values="$3"
  if ! jq -e --arg prose "$prose" \
    "[\$prose | scan(\"$PROMPT_PLACEHOLDER\") | .[0]] - keys | length == 0" >/dev/null <<<"$values"; then
    refuse_unknown_placeholder_note "$path" >&2
    return 1
  fi
  jq -r --arg prose "$prose" \
    ". as \$values | \$prose | gsub(\"$PROMPT_PLACEHOLDER\"; \$values[.name])" <<<"$values"
}

# A JSON array of {name, <words field>} as lines of "- name: words", for a
# model to read.
to_named_lines() {
  jq -r --arg field "$2" '.[] | "- \(.name): \(.[$field])"' <<<"$1"
}

# --- Reads.

# A prompt's prose, by its name among the stand-in's prompts; a refusal on
# stderr and a non-zero status where it cannot be read.
read_prompt() {
  local path="$PROMPTS_DIR/$1.md" prose
  if ! prose="$(cat "$path" 2>/dev/null)"; then
    refuse_unreadable_file_note "$path" >&2
    return 1
  fi
  printf '%s\n' "$prose"
}
