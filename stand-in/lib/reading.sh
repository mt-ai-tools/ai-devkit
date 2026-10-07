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
#
# The prompt tells it so in words. The advisor's command warns of an anchored
# reading whenever a proposal is in front of it, and handed bare options it
# took them for one: measured 2026-10-06, every reading opened "Anchored"
# though no pick had reached it. The command stays as it is, since sessions
# hand it their own proposals and the warning is right there.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_READING:-}" ] || return 0
STAND_IN_LOADED_READING=1
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

# The settings the reading runs with, given the stand-in's working folder: each
# tool the reading may use denied that folder. Its records hold the whole
# exchange and the agent's answers, its answers folder past cases; a reading
# that could read them would not be cold, though handed nothing. Every tool is
# denied, not Read alone: measured 2026-10-06 on Claude Code 2.1.289, a deny
# per tool refuses Read and a Grep pointed at the folder, and leaves a Grep
# over the whole project and a Glob finding nothing there, where without it a
# Grep found a word in the answers and a Glob listed the records, git-ignored
# or not. The leading "//" is how a rule names an absolute path. A folder that
# is not absolute is refused: as a rule it would name some other place, and
# deny nothing.
to_reading_settings() {
  local dir="$1"
  if [[ "$dir" != /* ]]; then
    refuse_folder_not_absolute_note "$dir" >&2
    return 1
  fi
  jq -cn --arg tools "$READING_TOOLS" --arg dir "$dir" \
    '{permissions: {deny: [$tools | split(",")[] | "\(.)(/\($dir)/**)"]}}'
}

# The reading's prompt, given the prompt's prose, the advisor's command, the
# question, its options as a JSON array, and the rules' and conventions'
# folders, which the advisor reads the laws in.
to_reading_prompt() {
  local prose="$1" command="$2" question="$3" options="$4" rules="$5" conventions="$6" values
  values="$(jq -cn --arg command "$command" --arg question "$question" \
    --arg options "$(jq -r '.[] | "- \(.)"' <<<"$options")" \
    --arg rules "$rules" --arg conventions "$conventions" \
    '{command: $command, question: $question, options: $options, rules: $rules, conventions: $conventions}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/reading.md" "$prose" "$values"
}

# --- Reads.

# The advisor's command, as written; a refusal on stderr and a non-zero status
# where it cannot be read.
read_advisor_command() {
  local path command
  path="$(get_kit_dir)/$ADVISOR_COMMAND_FILE" || return 1
  if ! command="$(cat "$path" 2>/dev/null)"; then
    refuse_unreadable_file_note "$path" >&2
    return 1
  fi
  printf '%s\n' "$command"
}

# The cold second reading of a question, as the model wrote it, given the
# question, its options as a JSON array, the rules' and conventions' folders,
# and the stand-in's working folder, which it is kept out of; a refusal naming
# why on stderr and a non-zero status where the command or the prompt cannot
# be read, the model could not be asked, or its answer does not pass. Run from
# the project's root, so the read-only tools it is given reach the project and
# nothing beyond it.
get_cold_reading() {
  local question="$1" options="$2" rules="$3" conventions="$4" history="$5" command prose prompt root schema settings answer
  settings="$(to_reading_settings "$history")" || return 1
  command="$(read_advisor_command)" || return 1
  prose="$(read_prompt reading)" || return 1
  prompt="$(to_reading_prompt "$prose" "$command" "$question" "$options" "$rules" "$conventions")" || return 1
  root="$(get_project_root)" || return 1
  schema="$(reading_answer_schema)" || return 1
  answer="$(cd "$root" && get_model_answer "$READING_MODEL" "$READING_SECONDS" "$schema" "$READING_TOOLS" \
    "$settings" <<<"$prompt")" || return 1
  answer="$(refuse_bad_reading_answer "$answer")" || return 1
  jq -r '.reading' <<<"$answer"
}
