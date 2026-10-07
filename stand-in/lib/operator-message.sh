#!/usr/bin/env bash
# The message that brings the operator a question: its parts, and the message
# made from them and the summary. Every function here is a transform.
# Sourced, never executed.
#
# The order is the operator's (settled 2026-10-04, 2026-10-05, 2026-10-06
# and 2026-10-07): the question as the agent asked it, and why it came to
# them; then the summary reader's fixed parts — the problem, the first
# recommendation, what moved it and why, what it recommends now — then the
# cold second reading where one ran, and last the operator's call, so the
# call is read with everything that bears on it already in view. The
# question opens it in the agent's own words, never retold: the summary's
# parts, written by a fresh model in everyday words, are its plain version,
# and the agent is never asked to retell it (dropped 2026-10-07). The agent
# never tells the story either: it would tell its own wavering, so the parts
# are a fresh reader's.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_OPERATOR_MESSAGE:-}" ] || return 0
STAND_IN_LOADED_OPERATOR_MESSAGE=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ladder.sh"

# The parts of a message for the operator, as JSON: the question as first
# asked; the label the stand-in would have approved, empty where it would not;
# the lines saying why it came to them, each ending its line; the cold second
# reading's part, empty where none ran; the answers as given, heading and
# lines, shown in place of a summary that failed; the reading's own words,
# empty where none was written, kept for the question log apart from the part
# around them; and how many times the approved label held under challenge,
# empty where it would have stood with no challenge at all, as a kind whose
# recommendation is accepted does.
to_operator_message_parts() {
  jq -cn --arg question "$1" --arg approved "$2" --arg why "$3" --arg reading "$4" --arg answers "$5" \
    --arg reading_text "${6:-}" --arg held "${7:-}" \
    '{question: $question, approved: $approved, why: $why, reading: $reading, answers: $answers,
      reading_text: $reading_text, held: $held}'
}

# The summary reader's parts, each under its heading, in the operator's order,
# given the summary's checked form and the cold reading's part (empty where
# none ran). Shared by the gate's message and a reopened question, so both
# show the operator the same parts in the same order.
format_summary_parts() {
  local summary="$1" reading="$2" problem first moved now call
  problem="$(jq -r '.problem' <<<"$summary")" || return 1
  first="$(jq -r '.first_recommendation' <<<"$summary")" || return 1
  moved="$(jq -r '.what_moved_it' <<<"$summary")" || return 1
  now="$(jq -r '.recommends_now' <<<"$summary")" || return 1
  call="$(jq -r '.operators_call' <<<"$summary")" || return 1
  gate_problem_part "$problem"
  gate_first_recommendation_part "$first"
  gate_what_moved_part "$moved"
  gate_recommends_now_part "$now"
  [ -z "$reading" ] || printf '%s\n' "$reading"
  gate_operator_call_part "$call"
}

# What follows why the question came to the operator, given the message's
# parts, the summary's form (empty where it failed) and why it failed: the
# summary's parts with the reading among them; or why there is none, the
# answers as given, and the reading after them.
to_operator_story() {
  local parts="$1" summary="$2" failed="$3" reading
  reading="$(jq -r '.reading' <<<"$parts")"
  if [ -n "$summary" ]; then
    format_summary_parts "$summary" "$reading"
    return 0
  fi
  gate_summary_failed_note "$failed"
  jq -r '.answers' <<<"$parts"
  [ -z "$reading" ] || printf '%s\n' "$reading"
}

# The operator's message, given its parts and what follows why it came to
# them: the story, as to_operator_story makes it. It opens with the question
# as the parts hold it, as asked.
to_operator_message() {
  local parts="$1" story="$2" question approved held why
  question="$(jq -r '.question' <<<"$parts")"
  approved="$(jq -r '.approved' <<<"$parts")"
  held="$(jq -r '.held' <<<"$parts")"
  why="$(jq -r '.why' <<<"$parts")"
  if [ -n "$approved" ] && [ -n "$held" ]; then
    printf '%s\n' "$(gate_held_note "$question" "$approved" "$held" "$why")"
  elif [ -n "$approved" ]; then
    printf '%s\n' "$(gate_accepted_note "$question" "$approved" "$why")"
  else
    printf '%s\n' "$(gate_operator_note "$question" "$why")"
  fi
  printf '%s\n' "$story"
}
