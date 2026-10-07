#!/usr/bin/env bash
# The reader: one finished reply turned into the reader's form by a fresh
# model, and the form checked before anything is decided from it. It reads
# only; what follows from the form is decided elsewhere, in code. Sourced,
# never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_READER:-}" ] || return 0
STAND_IN_LOADED_READER=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# --- Transforms.

# The reader's prompt for one reply, given the prompt's prose.
to_reader_prompt() {
  local values
  values="$(printf '%s' "$2" | jq -Rs '{reply: .}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/reader.md" "$1" "$values"
}

# --- Reads.

# The checked reader's form for one reply, as one line of JSON; a refusal
# naming why on stderr and a non-zero status where the model could not be
# asked or its form does not pass.
get_reader_form() {
  local prose prompt schema answer
  prose="$(read_prompt reader)" || return 1
  prompt="$(to_reader_prompt "$prose" "$1")" || return 1
  schema="$(reader_form_schema)" || return 1
  answer="$(get_model_answer "$READER_MODEL" "$READER_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_reader_form "$answer"
}
