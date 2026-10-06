#!/usr/bin/env bash
# A settled question brought back: shown to the operator in full as its log
# line holds it — the question as retold, what was settled on, the summary's
# parts with the cold reading among them where one ran, and on request every
# turn of the exchange word for word — and handed to the session's agent to
# ask again as a normal question. Every function here is a transform.
# Sourced, never executed.
#
# Shown from the line alone, never written again: the summary and the
# exchange are those the question was settled with, so the operator reads
# what the stand-in read, not a fresh account of it, and the parts in the
# order the gate's own message shows them.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/settled.sh"
. "$(dirname "${BASH_SOURCE[0]}")/ladder.sh"
. "$(dirname "${BASH_SOURCE[0]}")/record.sh"
. "$(dirname "${BASH_SOURCE[0]}")/operator-message.sh"

# The word that asks for the exchange word for word, after the number.
REOPEN_EXCHANGE="exchange"

# What was asked, from the words the skill was loaded with, as JSON {number,
# exchange}: a question's number, and the word for the exchange where it
# follows. Anything else is refused on stderr with a non-zero status: a number
# guessed out of other words could bring back a question nobody asked for.
to_reopen_request() {
  local words number exchange=false
  read -r -a words <<<"$1"
  number="${words[0]:-}"
  if ! [[ "$number" =~ ^[1-9][0-9]*$ ]] || [ "${#words[@]}" -gt 2 ] \
    || { [ "${#words[@]}" -eq 2 ] && [ "${words[1]}" != "$REOPEN_EXCHANGE" ]; }; then
    reopen_usage_note >&2
    return 1
  fi
  [ "${#words[@]}" -eq 1 ] || exchange=true
  jq -cn --argjson number "$number" --argjson exchange "$exchange" '{number: $number, exchange: $exchange}'
}

# The settled line numbered so, from the settled lines given; a refusal on
# stderr and a non-zero status where there is none: nothing settled at all,
# or no settled question of that number.
to_reopened_line() {
  local lines="$1" number="$2" line
  if [ -z "$lines" ]; then
    reopen_nothing_note >&2
    return 1
  fi
  line="$(jq -c --argjson number "$number" 'select(.number == $number)' <<<"$lines")"
  if [ -z "$line" ]; then
    reopen_unknown_note "$number" >&2
    return 1
  fi
  printf '%s\n' "$line"
}

# Every turn of the line's exchange, in order, each whole under who wrote it.
format_reopened_exchange() {
  local line="$1" count i from
  reopen_exchange_heading
  count="$(jq '.exchange | length' <<<"$line")"
  for ((i = 0; i < count; i++)); do
    from="$(jq -r --argjson i "$i" '.exchange[$i].from' <<<"$line")"
    if [ "$from" = "$EXCHANGE_AGENT" ]; then reopen_agent_turn_heading; else reopen_stand_in_turn_heading; fi
    jq -r --argjson i "$i" '.exchange[$i].text' <<<"$line"
  done
}

# The question in full, as the operator is shown it, given its line and
# whether the exchange was asked for. Where the line holds no summary, the
# answers as given stand in its place, as they do in the gate's message.
format_reopened() {
  local line="$1" exchange="$2" number when session briefs ladder summary reading
  number="$(jq -r '.number' <<<"$line")"
  when="$(jq -r --arg format "$SETTLED_DAY_TIME_FORMAT" '.when | fromdateiso8601 | strflocaltime($format)' <<<"$line")"
  session="$(jq -r '.session' <<<"$line")"
  briefs="$(jq -r '(.briefs // []) | join(", ")' <<<"$line")"
  reopen_heading "$number" "$when" "$(format_settled_where "$session" "$briefs")"
  reopen_question_line "$(jq -r '.retold // .question' <<<"$line")"
  reopen_settled_line "$(jq -r '.approved' <<<"$line")"
  summary="$(jq -c '.summary // empty' <<<"$line")"
  ladder="$(jq -c '.ladder // empty' <<<"$line")"
  reading="$(jq -r '.reading // empty' <<<"$line")"
  [ -z "$reading" ] || reading="$(gate_reading_note "$reading")"
  if [ -n "$summary" ]; then
    format_summary_parts "$summary" "$reading"
  else
    if [ -n "$ladder" ]; then
      gate_answers_heading
      derive_answer_lines "$ladder"
    fi
    [ -z "$reading" ] || printf '%s\n' "$reading"
  fi
  if [ "$exchange" = true ]; then
    format_reopened_exchange "$line"
  else
    reopen_exchange_hint
  fi
}

# The note the session's agent is handed: the question open again, in its
# own first words, with the options and what was settled on, to ask as any
# other question.
format_reopened_agent_note() {
  local line="$1"
  reopen_agent_note "$(jq -r '.number' <<<"$line")" "$(jq -r '.question' <<<"$line")" \
    "$(jq -r --arg separator "$LADDER_OPTION_SEPARATOR" '(.ladder.first.options // []) | join($separator)' <<<"$line")" \
    "$(jq -r '.approved' <<<"$line")"
}
