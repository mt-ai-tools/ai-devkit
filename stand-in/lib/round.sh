#!/usr/bin/env bash
# The round's decisions, laid out when the agent closes a round of questions
# and asks to start building (settled 2026-10-06, the operator's idea: one
# look at the whole round shows a decision that seemed fine alone but is
# wrong beside the others). Every decision of the round, one short numbered
# line each in everyday words, saying who decided it: the operator, or the
# stand-in without them. Sourced, never executed.
#
# The lines are a fresh model's, the round reader's, written from the
# question log, never the working agent's, which would make its own choices
# read better. Who decided is code's, read off how each question ended, and
# never the model's to say. Each line carries the decision's number in the
# log, never its place in this list, so "reopen" takes it unchanged, as it
# takes the settled list's.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_ROUND:-}" ] || return 0
STAND_IN_LOADED_ROUND=1
. "$(dirname "${BASH_SOURCE[0]}")/jobs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ask-model.sh"
. "$(dirname "${BASH_SOURCE[0]}")/check-form.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"

# Who decided, as the log line of the request keeps each decision.
ROUND_BY_OPERATOR="operator"
ROUND_BY_STAND_IN="stand-in"

# The line each decision stands under in the round reader's prompt.
ROUND_DECISION_MARKER="=====DECISION"

# The separator between a row's parts: the ASCII unit separator, which no
# question or answer is expected to hold and bash never collapses.
ROUND_US=$'\037'

# --- Transforms.

# The decisions of the session's current round, as a JSON array in log order,
# each {number, by, question, options, recommended, approved, answer}, given
# the log's lines and the session.
#
# The round is the session's questions since it last asked to start building
# or reported a step finished. Either means building began on what was decided
# before, so a decision already built on is not this round's to lay out
# again; and a decision reopened from a list is asked again as a new question,
# so it falls in the round after the request it was reopened from, and the
# next request lays it out anew. Another session's questions are its own
# round. A step's report and a request to build are no decision of a round,
# only where one ends.
derive_round_decisions() {
  local lines="$1" session="$2"
  [ -n "$lines" ] || { printf '[]\n'; return 0; }
  jq -cs --arg session "$session" --arg settled "$OUTCOME_SETTLED" \
    --arg operator "$ROUND_BY_OPERATOR" --arg stand_in "$ROUND_BY_STAND_IN" '
    [.[] | select(.session == $session)] as $own
    | (reduce range(0; $own | length) as $i (-1;
        if ($own[$i].round != null or $own[$i].step != null) then $i else . end)) as $last
    | $own[($last + 1):]
    | map(select(.round == null and .step == null)
      | {number, by: (if .outcome == $settled then $stand_in else $operator end),
         question: (.retold // .question), options: (.ladder.first.options // []),
         recommended: (.summary.recommends_now // .ladder.first.recommended // ""),
         approved, answer})' <<<"$lines"
}

# The round reader's prompt, given the prompt's prose and the decisions as
# derive_round_decisions gives them: each under the line naming its number,
# with who decided it in words the reader can retell from. The decisions
# reach jq through a file descriptor, never as an argument: answers the
# operator typed can outgrow what one argument may hold.
to_round_prompt() {
  local prose="$1" decisions="$2" values
  values="$(jq -cn --rawfile decisions <(to_round_decisions_text "$decisions") '{decisions: $decisions}')"
  to_filled_prompt "$PROMPTS_DIR/round.md" "$prose" "$values"
}

# The decisions as the round reader reads them.
to_round_decisions_text() {
  local decisions="$1" count i decision by answer decided
  count="$(jq 'length' <<<"$decisions")"
  for ((i = 0; i < count; i++)); do
    decision="$(jq -c --argjson i "$i" '.[$i]' <<<"$decisions")"
    by="$(jq -r '.by' <<<"$decision")"
    answer="$(jq -r '.answer' <<<"$decision")"
    if [ "$by" = "$ROUND_BY_STAND_IN" ]; then
      decided="$(round_by_stand_in_prompt_words "$(jq -r '.approved' <<<"$decision")")"
    elif [ -n "$answer" ]; then
      decided="$(round_by_operator_prompt_words "$answer")"
    else
      decided="$(round_unanswered_prompt_words)"
    fi
    jq -r --arg marker "$ROUND_DECISION_MARKER" --arg decided "$decided" '
      "\($marker) \(.number)=====",
      "Question: \(.question)",
      (if (.options | length) > 0 then "Options: \(.options | join(" / "))" else empty end),
      (if .recommended != "" then "The agent recommended: \(.recommended)" else empty end),
      $decided,
      ""' <<<"$decision"
  done
}

# The decisions as the operator is shown them and the log keeps them, as a
# JSON array of {number, by, decision}, given the decisions and the round
# reader's checked answer, empty where it failed: then each decision is the
# question as the log keeps it, with what was answered or settled on, so the
# list never fails to reach the operator.
to_round_shown() {
  local decisions="$1" answer="$2" number by question approved reply text
  while IFS="$ROUND_US" read -r number by question approved reply; do
    [ -n "$number" ] || continue
    if [ -n "$answer" ]; then
      text="$(jq -r --argjson number "$number" '.decisions[] | select(.number == $number) | .decision' <<<"$answer")"
    elif [ "$by" = "$ROUND_BY_STAND_IN" ]; then
      text="$(round_settled_words "$question" "$approved")"
    elif [ -n "$reply" ]; then
      text="$(round_answered_words "$question" "$reply")"
    else
      text="$(round_unanswered_words "$question")"
    fi
    jq -cn --argjson number "$number" --arg by "$by" --arg decision "$text" \
      '{number: $number, by: $by, decision: $decision}'
  done < <(jq -r --arg us "$ROUND_US" \
    '.[] | [(.number | tostring), .by, .question, .approved, .answer] | map(gsub("\\s+"; " ")) | join($us)' \
    <<<"$decisions") | jq -cs .
}

# What the operator is shown, given the decisions as to_round_shown gives
# them and why the round reader failed, empty where it did not: the request,
# every decision under its number and who decided it, and how to answer.
format_round_message() {
  local shown="$1" failed="$2" number by decision
  round_heading
  [ -z "$failed" ] || round_failed_note "$failed"
  if [ "$(jq 'length' <<<"$shown")" -eq 0 ]; then
    round_empty_line
  fi
  while IFS="$ROUND_US" read -r number by decision; do
    [ -n "$number" ] || continue
    if [ "$by" = "$ROUND_BY_STAND_IN" ]; then by="$(round_by_stand_in_words)"; else by="$(round_by_operator_words)"; fi
    round_item_line "$number" "$by" "$decision"
  done < <(jq -r --arg us "$ROUND_US" '.[] | [(.number | tostring), .by, .decision] | map(gsub("\\s+"; " ")) | join($us)' <<<"$shown")
  round_hint
}

# --- Reads.

# The round reader's checked answer for the decisions given, as one line of
# JSON; a refusal naming why on stderr and a non-zero status where the prompt
# cannot be read, the model could not be asked, or its answer does not pass.
get_round_answer() {
  local decisions="$1" prose prompt numbers schema answer
  prose="$(read_prompt round)" || return 1
  prompt="$(to_round_prompt "$prose" "$decisions")" || return 1
  numbers="$(jq -c 'map(.number)' <<<"$decisions")"
  schema="$(round_answer_schema "$numbers")"
  answer="$(get_model_answer "$ROUND_MODEL" "$ROUND_SECONDS" "$schema" <<<"$prompt")" || return 1
  refuse_bad_round_answer "$answer" "$numbers"
}
