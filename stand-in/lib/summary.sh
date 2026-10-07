#!/usr/bin/env bash
# The summary reader: the whole exchange between the stand-in and the agent
# over one question, told in everyday words by a fresh model in the fixed
# parts of the operator's message, for the operator to read under the
# question it brought them. It decides nothing: what it writes is shown,
# never routed on, and it neither judges nor recommends. Sourced, never
# executed.
#
# A fresh model, never the working agent: the agent would be summarising its
# own case, and would tell its own wavering. Handed the exchange as the gate
# keeps it in the session's record. The question's log line keeps that same
# exchange, whole, beside the parts written from it, so a reopened question
# shows the same parts and the same full version, never a second summary of
# something else.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SUMMARY:-}" ] || return 0
STAND_IN_LOADED_SUMMARY=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"
. "$(dirname "${BASH_SOURCE[0]}")/record.sh"

# The line each turn of the exchange stands under, by who wrote it.
SUMMARY_AGENT_MARKER="=====FROM THE AGENT====="
SUMMARY_STAND_IN_MARKER="=====FROM THE STAND-IN====="

# --- Transforms.

# The exchange, a JSON array of {from, text}, as one text: each turn whole,
# in order, under the line saying who wrote it.
to_exchange_text() {
  jq -r --arg agent "$EXCHANGE_AGENT" --arg agent_marker "$SUMMARY_AGENT_MARKER" \
    --arg stand_in_marker "$SUMMARY_STAND_IN_MARKER" \
    '.[] | "\(if .from == $agent then $agent_marker else $stand_in_marker end)\n\(.text)\n"' <<<"$1"
}

# The summary reader's prompt, given the prompt's prose and the exchange. The
# exchange reaches jq through a file descriptor, never as an argument: whole
# replies outgrow what one argument to a command may hold.
to_summary_prompt() {
  local prose="$1" exchange="$2" values
  values="$(jq -cn --rawfile exchange <(to_exchange_text "$exchange") '{exchange: $exchange}')" || return 1
  to_filled_prompt "$PROMPTS_DIR/summary.md" "$prose" "$values"
}

# --- Reads.

# The summary of one question's exchange, its parts as the model wrote them,
# as one line of JSON, given the exchange as a JSON array of {from, text}; a
# refusal naming why on stderr and a non-zero status where the prompt cannot
# be read, the model could not be asked, or its answer does not pass.
get_summary() {
  local prose prompt schema answer
  prose="$(read_prompt summary)" || return 1
  prompt="$(to_summary_prompt "$prose" "$1")" || return 1
  schema="$(summary_answer_schema)" || return 1
  answer="$(get_model_answer "$SUMMARY_MODEL" "$SUMMARY_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_summary_answer "$answer"
}
