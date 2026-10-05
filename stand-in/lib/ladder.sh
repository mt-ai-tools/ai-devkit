#!/usr/bin/env bash
# The challenge ladder, decided in code from forms that passed their check:
# what a rung's answer is, whether the answers held, and what the operator is
# shown. Every function here is a transform. Sourced, never executed.
#
# What the operator reads is whether a recommendation holds under challenge:
# the same answer, given again after the standing test and again after "are
# you sure?", is one the agent stands behind. So the ladder compares answers
# and nothing else; it never judges whether the answer is right, and a model
# is never asked whether the answers agree.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# How many answers a question gives on the ladder: the first recommendation,
# then one after each of the preset's challenges. Fixed here rather than read
# off the preset: it is the guard on what may ever approve, and a preset with
# one challenge fewer would approve on less than the operator asks for.
LADDER_RUNGS=3

# What the ladder does next, as derive_ladder_step names it.
LADDER_CLIMB="climb"
LADDER_HELD="held"
LADDER_CHANGED="changed"

# How a list of option labels is shown to the operator on one line.
LADDER_OPTION_SEPARATOR=" / "

# The separator between a row's parts: the ASCII unit separator, which no
# label a model writes is expected to hold and bash never collapses.
LADDER_US=$'\037'

# One rung's answer out of the reader's form of its reply: whether the reply
# still asks the question, the options it names in its order, and the one it
# recommends. Nothing else of the form is compared.
to_rung_answer() {
  jq -c '{asks_operator, options, recommended}' <<<"$1"
}

# True if the ladder's answers held: every rung answered, each still asking
# the question, each naming the same option list, label for label in the same
# order, and recommending the same label, which is not none. A list reworded
# or reordered is a different list: the agent has changed what it chooses
# between, and a choice from another list is another answer. A rung whose
# reply no longer asks the question has not held its answer; it has let go
# of it.
is_ladder_held() {
  jq -e --argjson rungs "$LADDER_RUNGS" '
    .answers as $a
    | ($a | length) == $rungs
      and $a[0].recommended != ""
      and all($a[]; .asks_operator
        and .options == $a[0].options
        and .recommended == $a[0].recommended)' >/dev/null <<<"$1"
}

# What follows the answers the ladder holds: climb, while a rung is left to
# ask; then held or changed. Every rung is asked even once an answer has
# moved: the operator is shown all of them, and whether the agent came back
# to its first answer is part of what they read.
derive_ladder_step() {
  if [ "$(jq '.answers | length' <<<"$1")" -lt "$LADDER_RUNGS" ]; then
    printf '%s\n' "$LADDER_CLIMB"
  elif is_ladder_held "$1"; then
    printf '%s\n' "$LADDER_HELD"
  else
    printf '%s\n' "$LADDER_CHANGED"
  fi
}

# The challenge the next rung sends, out of the preset's challenges in rung
# order: the first after the first answer, and so on.
to_rung_challenge() {
  jq -r --argjson ladder "$2" '.[($ladder.answers | length) - 1]' <<<"$1"
}

# The lines saying why the question came to the operator: the line given
# first, then those the route gave the ladder, each ending its line.
to_why_lines() {
  local lines extra
  lines="$1"$'\n'
  extra="$(jq -r '.lines' <<<"$2")"
  [ -z "$extra" ] || lines+="$extra"$'\n'
  printf '%s' "$lines"
}

# The operator's message for answers that held: the decision asked for, what
# the stand-in would have approved, and why it still came to them.
to_held_note() {
  local ladder="$1" question recommended
  question="$(jq -r '.question' <<<"$ladder")"
  recommended="$(jq -r '.answers[0].recommended' <<<"$ladder")"
  gate_held_note "$question" "$recommended" "$LADDER_RUNGS" \
    "$(to_why_lines "$(gate_trial_line "$(jq -r '.kind' <<<"$ladder")")" "$ladder")"
}

# Each rung's answer as the operator reads it, one line each, in order.
derive_answer_lines() {
  local n asks recommended options
  while IFS="$LADDER_US" read -r n asks recommended options; do
    if [ "$asks" != true ]; then
      gate_answer_gone_line "$n"
    elif [ -z "$recommended" ]; then
      gate_answer_none_line "$n" "$options"
    else
      gate_answer_line "$n" "$recommended" "$options"
    fi
  done < <(jq -r --arg separator "$LADDER_OPTION_SEPARATOR" --arg us "$LADDER_US" '
    .answers | to_entries[]
    | [(.key + 1 | tostring), (.value.asks_operator | tostring), .value.recommended,
       (.value.options | join($separator))]
    | map(gsub("\\s+"; " ")) | join($us)' <<<"$1")
}

# The operator's message for answers that moved: the decision asked for, why
# it came to them, every answer in order, then the reading part given — the
# cold second reading, or why there is none.
to_changed_note() {
  local ladder="$1" reading="$2" question
  question="$(jq -r '.question' <<<"$ladder")"
  # The substitution strips the last line's end, which the heading needs.
  gate_operator_note "$question" "$(to_why_lines "$(gate_moved_line)" "$ladder")"$'\n'
  gate_answers_heading "$(jq '.answers | length' <<<"$ladder")"
  derive_answer_lines "$ladder"
  printf '%s\n' "$reading"
}
