#!/usr/bin/env bash
# The cold second reading: a question whose answer moved on the ladder, worked
# by a fresh model through the advisor's own command, for the operator to read
# beside the agent's answers. It decides nothing: what it says is shown, never
# routed on. Sourced, never executed.
#
# Cold means it is handed the question and its options and nothing of the
# agent's: not the recommendation, not the answers on the ladder, not the
# reply. A reading that saw what the agent chose would be anchored to it, and
# an agreement it then reached would be worth less than one it reached alone.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# The advisor's command, inside the kit. Read whole each time, never copied
# into a prompt: the reading is the operator's own last rung only while it is
# the advisor as the advisor stands. Its header goes with it, as it says what
# the command is for and what it is handed.
ADVISOR_COMMAND_FILE="advisor/commands/advise.md"

# --- Transforms.

# The reading's prompt, given the prompt's prose, the advisor's command, the
# question, its options as a JSON array, and the rules' and conventions'
# folders, which the advisor reads the laws in.
to_reading_prompt() {
  local prose="$1" command="$2" question="$3" options="$4" rules="$5" conventions="$6" values
  values="$(jq -cn --arg command "$command" --arg question "$question" \
    --arg options "$(jq -r '.[] | "- \(.)"' <<<"$options")" \
    --arg rules "$rules" --arg conventions "$conventions" \
    '{command: $command, question: $question, options: $options, rules: $rules, conventions: $conventions}')"
  to_filled_prompt "$PROMPTS_DIR/reading.md" "$prose" "$values"
}

# --- Reads.

# The advisor's command, as written; a refusal on stderr and a non-zero status
# where it cannot be read.
read_advisor_command() {
  local path command
  path="$(get_kit_dir)/$ADVISOR_COMMAND_FILE"
  if ! command="$(cat "$path" 2>/dev/null)"; then
    refuse_unreadable_file_note "$path" >&2
    return 1
  fi
  printf '%s\n' "$command"
}

# The cold second reading of a question, as the model wrote it, given the
# question, its options as a JSON array, and the rules' and conventions'
# folders; a refusal naming why on stderr and a non-zero status where the
# command or the prompt cannot be read, the model could not be asked, or its
# answer does not pass. Run from the project's root, so the read-only tools it
# is given reach the project and nothing beyond it.
get_cold_reading() {
  local question="$1" options="$2" rules="$3" conventions="$4" command prose prompt root schema answer
  command="$(read_advisor_command)" || return 1
  prose="$(read_prompt reading)" || return 1
  prompt="$(to_reading_prompt "$prose" "$command" "$question" "$options" "$rules" "$conventions")" || return 1
  root="$(get_project_root)"
  schema="$(reading_answer_schema)"
  answer="$(cd "$root" && get_model_answer "$READING_MODEL" "$READING_SECONDS" "$schema" "$READING_TOOLS" \
    <<<"$prompt")" || return 1
  answer="$(refuse_bad_reading_answer "$answer")" || return 1
  jq -r '.reading' <<<"$answer"
}
