#!/usr/bin/env bash
# The sorter: one question, already read into a checked reader's form, given
# its kind and the risks on its recommended option by a fresh model, against
# the kinds and risks the preset holds; or one finished step's report, its
# major problems labelled, against the preset's risks and the two labels the
# step go adds to them. Either answer is checked before anything is decided
# from it. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SORTER:-}" ] || return 0
STAND_IN_LOADED_SORTER=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/preset.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"
. "$(dirname "${BASH_SOURCE[0]}")/step-go.sh"

# --- Transforms.

# The sorter's prompt, given the prompt's prose, the reader's form, the reply,
# and the preset's kinds and risks as JSON arrays.
to_sorter_prompt() {
  local prose="$1" form="$2" reply="$3" kinds="$4" risks="$5" kind_lines risk_lines values
  kind_lines="$(to_named_lines "$kinds" summary)" || return 1
  risk_lines="$(to_named_lines "$risks" words)" || return 1
  values="$(printf '%s' "$reply" | jq -Rs \
    --arg form "$form" \
    --arg kinds "$kind_lines" \
    --arg risks "$risk_lines" \
    '{reply: ., form: $form, kinds: $kinds, risks: $risks}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/sorter.md" "$prose" "$values"
}

# The sorter's prompt for a step's report, given the prompt's prose, the
# reader's form, the reply, and the labels as a JSON array of {name, words}.
to_step_sorter_prompt() {
  local prose="$1" form="$2" reply="$3" labels="$4" label_lines values
  label_lines="$(to_named_lines "$labels" words)" || return 1
  values="$(printf '%s' "$reply" | jq -Rs \
    --arg form "$form" \
    --arg labels "$label_lines" \
    '{reply: ., form: $form, labels: $labels}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/step-sorter.md" "$prose" "$values"
}

# --- Reads.

# The checked sorter's answer for one question, as one line of JSON, given the
# reader's form, the reply and the preset's folder; a refusal naming why on
# stderr and a non-zero status where the form cannot be sorted, the preset
# cannot be read, the model could not be asked, or its answer does not pass.
get_sorter_answer() {
  local form reply="$2" preset="$3" kinds risks kind_names risk_names prose prompt schema answer
  form="$(refuse_questionless_form "$1")" || return 1
  kinds="$(list_kinds "$preset")" || return 1
  risks="$(list_risks "$preset")" || return 1
  kind_names="$(to_names "$kinds")" || return 1
  risk_names="$(to_names "$risks")" || return 1
  prose="$(read_prompt sorter)" || return 1
  prompt="$(to_sorter_prompt "$prose" "$form" "$reply" "$kinds" "$risks")" || return 1
  schema="$(sorter_answer_schema "$kind_names" "$risk_names")" || return 1
  answer="$(get_model_answer "$SORTER_MODEL" "$SORTER_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_sorter_answer "$answer" "$kind_names" "$risk_names"
}

# The checked labelling of one step's report, as one line of JSON, given the
# reader's form, the reply and the preset's folder; a refusal naming why on
# stderr and a non-zero status where the form reports no step, the preset
# cannot be read, the model could not be asked, or its answer does not pass.
# The sorter's own model and time, since labelling a problem against the
# risks is the judgement it already makes for a question's option.
get_step_sort() {
  local form reply="$2" preset="$3" risks labels names prose prompt schema answer
  form="$(refuse_stepless_form "$1")" || return 1
  risks="$(list_risks "$preset")" || return 1
  labels="$(list_major_labels "$risks")" || return 1
  prose="$(read_prompt step-sorter)" || return 1
  prompt="$(to_step_sorter_prompt "$prose" "$form" "$reply" "$labels")" || return 1
  names="$(to_names "$labels")" || return 1
  schema="$(step_sort_schema "$names")" || return 1
  answer="$(get_model_answer "$SORTER_MODEL" "$SORTER_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_step_sort "$answer" "$names"
}
