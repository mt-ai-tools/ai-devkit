#!/usr/bin/env bash
# The message that brings the operator a question: its parts, kept while the
# agent is asked for its plain retelling, and the message made from them once
# the retelling is in. Every function here is a transform. Sourced, never
# executed.
#
# The order is the operator's (settled 2026-10-04 and 2026-10-05): the
# question as the agent retold it plainly, and why it came to them; then how
# it got there, as the summary reader tells the exchange; then the cold
# second reading where one ran. The retold question opens it because the
# operator reads every question plainly worded; the question as first asked
# stays in the parts, for the record, and is never shown in its place.
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

# The operator's message, given its parts, the question to open it with, a
# line to add to why it came to them (empty for none), and the part telling
# how it got there: the summary, or why there is none and the answers.
to_operator_message() {
  local parts="$1" question="$2" extra="$3" story="$4" approved why reading
  approved="$(jq -r '.approved' <<<"$parts")"
  why="$(jq -r '.why' <<<"$parts")"
  reading="$(jq -r '.reading' <<<"$parts")"
  [ -z "$extra" ] || why="${why:+$why$'\n'}$extra"
  if [ -n "$approved" ]; then
    printf '%s\n' "$(gate_held_note "$question" "$approved" "$LADDER_RUNGS" "$why")"
  else
    printf '%s\n' "$(gate_operator_note "$question" "$why")"
  fi
  printf '%s\n' "$story"
  [ -z "$reading" ] || printf '%s\n' "$reading"
}
