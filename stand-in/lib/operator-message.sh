#!/usr/bin/env bash
# The message that brings the operator a question: its parts, kept while the
# agent is asked for its plain retelling, and the message made from them once
# the retelling is in. Every function here is a transform. Sourced, never
# executed.
#
# The order is the operator's (settled 2026-10-04, 2026-10-05 and
# 2026-10-06): the question as the agent retold it plainly, and why it came
# to them; then the summary reader's fixed parts — the problem, the first
# recommendation, what moved it and why, what it recommends now — then the
# cold second reading where one ran, and last the operator's call, so the
# call is read with everything that bears on it already in view. The retold
# question opens it because the operator reads every question plainly
# worded; the question as first asked stays in the parts, for the record, and
# is never shown in its place. The agent's own retelling never tells the
# story: it would tell its own wavering, so the parts are a fresh reader's.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ladder.sh"

# The parts of a message for the operator, as JSON: the question as first
# asked; the label the stand-in would have approved, empty where it would not;
# the lines saying why it came to them, each ending its line; the cold second
# reading's part, empty where none ran; the answers as given, heading and
# lines, shown in place of a summary that failed; and the reading's own words,
# empty where none was written, kept for the question log apart from the part
# around them.
to_operator_message_parts() {
  jq -cn --arg question "$1" --arg approved "$2" --arg why "$3" --arg reading "$4" --arg answers "$5" \
    --arg reading_text "${6:-}" \
    '{question: $question, approved: $approved, why: $why, reading: $reading, answers: $answers,
      reading_text: $reading_text}'
}

# The summary reader's parts, each under its heading, in the operator's order,
# given the summary's checked form and the cold reading's part (empty where
# none ran). Shared by the gate's message and a reopened question, so both
# show the operator the same parts in the same order.
format_summary_parts() {
  local summary="$1" reading="$2"
  gate_problem_part "$(jq -r '.problem' <<<"$summary")"
  gate_first_recommendation_part "$(jq -r '.first_recommendation' <<<"$summary")"
  gate_what_moved_part "$(jq -r '.what_moved_it' <<<"$summary")"
  gate_recommends_now_part "$(jq -r '.recommends_now' <<<"$summary")"
  [ -z "$reading" ] || printf '%s\n' "$reading"
  gate_operator_call_part "$(jq -r '.operators_call' <<<"$summary")"
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

# The operator's message, given its parts, the question to open it with, a
# line to add to why it came to them (empty for none), and what follows: the
# story, as to_operator_story makes it.
to_operator_message() {
  local parts="$1" question="$2" extra="$3" story="$4" approved why
  approved="$(jq -r '.approved' <<<"$parts")"
  why="$(jq -r '.why' <<<"$parts")"
  [ -z "$extra" ] || why="${why:+$why$'\n'}$extra"
  if [ -n "$approved" ]; then
    printf '%s\n' "$(gate_held_note "$question" "$approved" "$LADDER_RUNGS" "$why")"
  else
    printf '%s\n' "$(gate_operator_note "$question" "$why")"
  fi
  printf '%s\n' "$story"
}
