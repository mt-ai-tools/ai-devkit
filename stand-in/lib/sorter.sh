#!/usr/bin/env bash
# The sorter: one question, already read into a checked reader's form, given
# its kind and the risks on its recommended option by a fresh model, against
# the kinds and risks the preset holds; the answer checked before anything is
# decided from it. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/preset.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# --- Transforms.

# The sorter's prompt, given the prompt's prose, the reader's form, the reply,
# and the preset's kinds and risks as JSON arrays.
to_sorter_prompt() {
  local prose="$1" form="$2" reply="$3" kinds="$4" risks="$5" values
  values="$(printf '%s' "$reply" | jq -Rs \
    --arg form "$form" \
    --arg kinds "$(to_named_lines "$kinds" summary)" \
    --arg risks "$(to_named_lines "$risks" words)" \
    '{reply: ., form: $form, kinds: $kinds, risks: $risks}')"
  to_filled_prompt "$PROMPTS_DIR/sorter.md" "$prose" "$values"
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
  kind_names="$(to_names "$kinds")"
  risk_names="$(to_names "$risks")"
  prose="$(read_prompt sorter)" || return 1
  prompt="$(to_sorter_prompt "$prose" "$form" "$reply" "$kinds" "$risks")" || return 1
  schema="$(sorter_answer_schema "$kind_names" "$risk_names")"
  answer="$(get_model_answer "$SORTER_MODEL" "$SORTER_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_sorter_answer "$answer" "$kind_names" "$risk_names"
}
