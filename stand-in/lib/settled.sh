#!/usr/bin/env bash
# The list of questions the stand-in settled without the operator, as the
# operator reads it: each by its number, the question as the agent retold it
# where its line kept a retelling and as asked otherwise, the option settled
# on, when, and in which session and brief. Made from the question log's
# lines alone. Every function here is a transform. Sourced, never executed.
#
# The numbers are the log's own, never a position in this list: a number seen
# today still reopens the same question tomorrow, whatever was settled since.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SETTLED:-}" ] || return 0
STAND_IN_LOADED_SETTLED=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"

# What the list may be asked for: today's questions, the default, or every
# one; the word that asks for every one.
SETTLED_TODAY="today"
SETTLED_ALL="all"

# The separator between a row's parts: the ASCII unit separator, which no
# question or label is expected to hold and bash never collapses.
SETTLED_US=$'\037'

# How a moment is shown: the time alone in today's list, the day too in the
# whole list. Shown in the machine's own zone, as "today" is read, while the
# log keeps UTC.
SETTLED_TIME_FORMAT="%H:%M"
SETTLED_DAY_TIME_FORMAT="%Y-%m-%d %H:%M"
SETTLED_DAY_FORMAT="%Y-%m-%d"

# The list asked for, from the words the skill was loaded with: nothing for
# today's, the word for every one; anything else is refused on stderr with a
# non-zero status rather than guessed at.
to_settled_scope() {
  local words="${1//[[:space:]]/}"
  case "$words" in
    "") printf '%s\n' "$SETTLED_TODAY" ;;
    "$SETTLED_ALL") printf '%s\n' "$SETTLED_ALL" ;;
    *) settled_usage_note >&2; return 1 ;;
  esac
}

# The settled lines among the log's lines given, one per line, in log order.
to_settled_lines() {
  [ -n "$1" ] || return 0
  jq -c --arg settled "$OUTCOME_SETTLED" 'select(.outcome == $settled)' <<<"$1"
}

# Where a question was settled, in words: the session, and the briefs it held
# where it held any.
format_settled_where() {
  local session="$1" briefs="$2"
  if [ -n "$briefs" ]; then
    settled_where_brief_words "$session" "$briefs"
  else
    settled_where_session_words "$session"
  fi
}

# The list the operator is shown, given the settled lines, today's date in
# the machine's zone, and the scope asked for. Empty, it says so plainly.
# While every kind is on trial nothing can be settled, and nothing yet takes a
# kind off it, so the empty list says the trial is why; the day a kind can be
# switched, that line must learn to tell the two apart.
format_settled_list() {
  local lines="$1" today="$2" scope="$3" format="$SETTLED_TIME_FORMAT" rows number question approved when session briefs
  [ "$scope" = "$SETTLED_TODAY" ] || format="$SETTLED_DAY_TIME_FORMAT"
  rows=""
  if [ -n "$lines" ]; then
    rows="$(jq -r --arg today "$today" --arg today_scope "$SETTLED_TODAY" --arg asked "$scope" \
      --arg day "$SETTLED_DAY_FORMAT" --arg format "$format" --arg us "$SETTLED_US" '
      (.when | fromdateiso8601) as $t
      | select($asked != $today_scope or ($t | strflocaltime($day)) == $today)
      | [(.number | tostring), (.retold // .question), .approved, ($t | strflocaltime($format)),
         .session, ((.briefs // []) | join(", "))]
      | map(gsub("\\s+"; " ")) | join($us)' <<<"$lines")"
  fi
  if [ -z "$rows" ]; then
    settled_empty_note
    return 0
  fi
  if [ "$scope" = "$SETTLED_TODAY" ]; then settled_today_heading; else settled_all_heading; fi
  while IFS="$SETTLED_US" read -r number question approved when session briefs; do
    settled_item_line "$number" "$question"
    settled_detail_line "$approved" "$when" "$(format_settled_where "$session" "$briefs")"
  done <<<"$rows"
  settled_reopen_hint
}
