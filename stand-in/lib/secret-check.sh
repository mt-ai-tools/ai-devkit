#!/usr/bin/env bash
# The secret check's agent: one case's whole text read by a fresh model, in
# context, for anything secret, before the case is saved. Sourced, never
# executed.
#
# A model beside the scanner, never instead of it (settled 2026-10-06 by
# expect-an-attacker): a password in plain words, or a person's address,
# has no shape a scanner can see, and only a reader of the sentence around
# it tells it from an ordinary word. Its answer is a yes or a no, never what
# it found.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SECRET_CHECK:-}" ] || return 0
STAND_IN_LOADED_SECRET_CHECK=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"

# --- Transforms.

# The secret check's prompt for one case's text, given the prompt's prose.
to_secret_prompt() {
  local values
  values="$(jq -cn --rawfile case <(printf '%s' "$2") '{case: $case}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/secret-check.md" "$1" "$values"
}

# --- Reads.

# The checked secret check's answer for one case's text, as one line of
# JSON; a refusal naming why on stderr and a non-zero status where the
# prompt cannot be read, the model could not be asked, or its answer does
# not pass.
get_secret_answer() {
  local prose prompt schema answer
  prose="$(read_prompt secret-check)" || return 1
  prompt="$(to_secret_prompt "$prose" "$1")" || return 1
  schema="$(secret_answer_schema)" || return 1
  answer="$(get_model_answer "$SECRET_MODEL" "$SECRET_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_secret_answer "$answer"
}
