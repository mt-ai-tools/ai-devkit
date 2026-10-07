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
#
# A step's report is told to the model as one, with what the reader read of
# it, and kept a report in its case, never retold as a question: the exam
# replays a case of the step go's kind as a step's report, and its reader
# check fails one that asks something (found 2026-10-07).

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

# True if the log line is a step's report: the gate logs one with what the
# reader read of the step, and a question with none. Told from the line, as
# reopen tells it, so the case-writer needs no preset to find the go's kind.
is_step_line() {
  jq -e '.step != null' >/dev/null <<<"$1"
}

# What the agent put to the operator, as the case-writer is told it.
to_case_shape_text() {
  if is_step_line "$1"; then
    case_shape_step_words
  else
    case_shape_question_words
  fi
  printf '\n'
}

# What the reader read of a step's report, as lines for a model to read: the
# next step it names, how its proof went and each problem with what became
# of it; the words for none for a question, or a part the reader left empty.
to_case_step_text() {
  local text
  text="$(jq -r '.step // empty
    | (if .next_step != "" then "Next step: \(.next_step)" else empty end),
      (if .proof != "" then "Proof: \(.proof)" else empty end),
      (if (.problems | length) > 0 then "Problems:", (.problems[] | "- \(.problem) (\(.state))") else empty end)' <<<"$1")"
  [ -n "$text" ] || text="$(case_none_kept_words)"
  printf '%s\n' "$text"
}

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
#
# The question is the one the log's other readers show: a line written before
# the gate stopped asking for a plain retelling shows that retelling, which is
# also the last agent turn of its exchange, and any later line the question as
# asked. One slot for both, rather than a retelling slot every new line would
# hand over empty.
to_case_prompt() {
  local prose="$1" line="$2" values
  values="$(jq -cn --rawfile shape <(to_case_shape_text "$line") \
    --rawfile question <(jq -j '.retold // .question' <<<"$line") \
    --rawfile step <(to_case_step_text "$line") \
    --rawfile options <(to_case_options_text "$line") --rawfile summary <(to_case_summary_text "$line") \
    --rawfile exchange <(to_exchange_text "$(jq -c '.exchange' <<<"$line")") \
    --rawfile answer <(jq -j '.answer' <<<"$line") \
    '{shape: $shape, question: $question, step: $step, options: $options, summary: $summary,
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
