#!/usr/bin/env bash
# The case-writer: one answered question of a finished brief, as its log line
# keeps it, turned by a fresh model into the case-writer's form, and the form
# checked before a case is made from it. It reads only; whether a case is
# made, and what it says beyond the form, is decided in code. Sourced, never
# executed.
#
# A fresh model rather than the working agent: the agent would retell its
# own question, and tell it the way it argued it. Handed what the log keeps
# of the question, the exchange whole, and the operator's answer as typed;
# what comes back is meaning only, since the log is raw text and the case is
# committed (settled 2026-10-01/02).

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CASE_WRITER:-}" ] || return 0
STAND_IN_LOADED_CASE_WRITER=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"
. "$(dirname "${BASH_SOURCE[0]}")/summary.sh"

# --- Transforms.

# What the stand-in kept of a line's options, as lines for a model to read:
# the first rung's, or a dropped proposal's, with the one recommended; the
# words for none where neither was kept, as for a question that never climbed
# a ladder, whose options live in its exchange alone.
to_case_options_text() {
  local text
  text="$(jq -r '(.ladder.first // .dropped // empty)
    | (.options[] | "- \(.)"), (if .recommended != "" then "Recommended: \(.recommended)" else empty end)' <<<"$1")"
  [ -n "$text" ] || text="$(case_none_kept_words)"
  printf '%s\n' "$text"
}

# The summary the operator was shown, its parts one after the other; the
# words for none where none was written.
to_case_summary_text() {
  local text
  text="$(jq -r '.summary // empty | to_entries[] | "\(.key): \(.value)"' <<<"$1")"
  [ -n "$text" ] || text="$(case_none_kept_words)"
  printf '%s\n' "$text"
}

# The case-writer's prompt for one log line, given the prompt's prose. Every
# value reaches jq through a file descriptor, never as an argument: an
# exchange can outgrow what one argument may hold.
to_case_prompt() {
  local prose="$1" line="$2" values retold
  retold="$(jq -r '.retold // empty' <<<"$line")"
  [ -n "$retold" ] || retold="$(case_none_kept_words)"
  values="$(jq -cn --rawfile question <(jq -j '.question' <<<"$line") --arg retold "$retold" \
    --rawfile options <(to_case_options_text "$line") --rawfile summary <(to_case_summary_text "$line") \
    --rawfile exchange <(to_exchange_text "$(jq -c '.exchange' <<<"$line")") \
    --rawfile answer <(jq -j '.answer' <<<"$line") \
    '{question: $question, retold: $retold, options: $options, summary: $summary,
      exchange: $exchange, answer: $answer}')"
  to_filled_prompt "$PROMPTS_DIR/case-writer.md" "$prose" "$values"
}

# --- Reads.

# The checked case-writer's form for one log line, as one line of JSON; a
# refusal naming why on stderr and a non-zero status where the prompt cannot
# be read, the model could not be asked, or its form does not pass.
get_case_form() {
  local prose prompt schema answer
  prose="$(read_prompt case-writer)" || return 1
  prompt="$(to_case_prompt "$prose" "$1")" || return 1
  schema="$(case_form_schema)"
  answer="$(get_model_answer "$CASE_MODEL" "$CASE_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_case_form "$answer"
}
