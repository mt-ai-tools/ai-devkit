#!/usr/bin/env bash
# The end report: what the operator is shown once the closing sweep came back
# empty and the brief was finished — whether the full check passed, the
# decisions the stand-in settled without them, what was fixed in passing,
# what was dropped, what was parked, how many test cases were written from
# the brief's answers, what finishing the brief changed, and, where a kind
# reached the trial's bar, whether it may now answer alone.
# Every function here is a transform. Sourced, never executed.
#
# Made from the question log and the work organizer's own output alone, never
# retold by a model (settled 2026-10-01/02): a list a model copies can lose
# lines, and one it words can read better than what happened. Every part is
# there even where it holds nothing, so a part left out is never mistaken for
# one with nothing in it. What was built stays in the agent's own words, in
# the reply the report stands under: no form holds it, and a model retelling
# the work would tell the operator how it sounded rather than what it was.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_END_REPORT:-}" ] || return 0
STAND_IN_LOADED_END_REPORT=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/closing.sh"

# The separator between a row's parts: the ASCII unit separator, which no
# question or answer is expected to hold and bash never collapses.
END_US=$'\037'

# Every finding of the closing rounds among the lines given, as one JSON
# array, in log order.
to_closing_findings() {
  [ -n "$1" ] || { printf '[]\n'; return 0; }
  jq -cs '[.[] | (.closing.findings // [])[]]' <<<"$1"
}

# The lines given that ended as the outcome given, one row each:
# "<number><US><question as retold, or as asked><US><approved>".
derive_outcome_rows() {
  [ -n "$1" ] || return 0
  jq -r --arg outcome "$2" --arg us "$END_US" \
    'select(.outcome == $outcome) | [(.number | tostring), (.retold // .question), .approved]
      | map(gsub("\\s+"; " ")) | join($us)' <<<"$1"
}

# Whether the full check passed, as code reads the reader's form of the
# agent's last reply, empty where it could not be read; then why not.
format_end_check() {
  local form="$1" failed="$2" proof
  if [ -z "$form" ]; then
    end_check_unread_line "$failed"
    return 0
  fi
  proof="$(jq -r '.proof' <<<"$form")" || return 1
  case "$proof" in
    "$STEP_PROOF_PASSED") end_check_passed_line ;;
    "$STEP_PROOF_FAILED") end_check_failed_line ;;
    *) end_check_unsaid_line ;;
  esac
}

# The decisions settled without the operator, each with how to reopen it.
format_end_silent() {
  local rows number question approved
  end_silent_heading
  rows="$(derive_outcome_rows "$1" "$OUTCOME_SETTLED")"
  [ -n "$rows" ] || { end_none_line; return 0; }
  while IFS="$END_US" read -r number question approved; do
    end_silent_line "$number" "$question" "$approved"
  done <<<"$rows"
}

# What the closing rounds fixed in passing.
format_end_fixed() {
  local rows finding briefs moved
  gate_fixed_heading
  rows="$(derive_finding_rows "$1" "$FINDING_QUICK")"
  [ -n "$rows" ] || { end_none_line; return 0; }
  while IFS="$CLOSING_US" read -r finding briefs moved; do gate_problem_line "$finding"; done <<<"$rows"
}

# What was dropped: the findings the rounds dropped, each with why, then the
# proposals the agent dropped under a challenge, each with how to reopen it.
format_end_dropped() {
  local lines="$1" findings="$2" sort rows finding briefs moved number question approved any=""
  end_dropped_heading
  for sort in "$FINDING_WRITTEN_DOWN" "$FINDING_NOT_SAME_JOB"; do
    rows="$(derive_finding_rows "$findings" "$sort")"
    [ -n "$rows" ] || continue
    any=1
    while IFS="$CLOSING_US" read -r finding briefs moved; do
      closing_finding_line "$finding" "$(closing_sort_words "$sort")"
    done <<<"$rows"
  done
  rows="$(derive_outcome_rows "$lines" "$OUTCOME_DROPPED")"
  if [ -n "$rows" ]; then
    any=1
    while IFS="$END_US" read -r number question approved; do
      end_dropped_line "$number" "$question"
    done <<<"$rows"
  fi
  [ -n "$any" ] || end_none_line
}

# What the closing rounds parked, each moved by code saying why.
format_end_parked() {
  local rows finding briefs moved
  end_parked_heading
  rows="$(derive_finding_rows "$1" "$FINDING_PARK")"
  [ -n "$rows" ] || { end_none_line; return 0; }
  while IFS="$CLOSING_US" read -r finding briefs moved; do
    if [ -n "$moved" ]; then
      closing_moved_line "$finding" "$(format_moved_words "$moved")"
    else
      gate_problem_line "$finding"
    fi
  done <<<"$rows"
}

# How many test cases the case-writer wrote from the brief's answers,
# skipped, held back and failed to write, as it kept them on the closing
# round; or, where it kept nothing, that it never ran (settled 2026-10-07):
# the agent is told to run it, and only code reading the record can say it
# did.
format_end_cases() {
  local cases written skipped held failed
  cases="$(jq -c '.cases // empty' <<<"$1")" || return 1
  if [ -z "$cases" ]; then
    end_cases_never_line
    return 0
  fi
  written="$(jq -r '.written' <<<"$cases")" || return 1
  skipped="$(jq -r '.skipped' <<<"$cases")" || return 1
  held="$(jq -r '.held' <<<"$cases")" || return 1
  failed="$(jq -r '.failed' <<<"$cases")" || return 1
  end_cases_line "$written" "$skipped" "$held" "$failed"
}

# The question whether a kind may answer alone (settled 2026-10-01/02,
# decision 9), given the kind due as find_switch_kind gives it, empty for
# none, and why none could be found, empty where nothing failed: the kind's
# score, each case it got wrong, plainly, and the question last, saying the
# one answer that switches it. Nothing where none is due.
format_end_switch() {
  local switch="$1" failed="$2" kind score tries agreed count name summary misses
  if [ -n "$failed" ]; then
    end_switch_unread_line "$failed"
    return 0
  fi
  [ -n "$switch" ] || return 0
  kind="$(jq -r '.kind' <<<"$switch")" || return 1
  score="$(jq -c '.score' <<<"$switch")" || return 1
  tries="$(jq -r '.tries' <<<"$score")" || return 1
  agreed="$(jq -r '.agreed' <<<"$score")" || return 1
  count="$(jq '.misses | length' <<<"$score")" || return 1
  end_switch_heading "$kind" "$tries" "$agreed"
  end_switch_misses_heading
  if [ "$count" -eq 0 ]; then
    end_none_line
  else
    misses="$(jq -r --arg us "$END_US" '.misses[] | [.name, (.summary | gsub("\\s+"; " "))] | join($us)' <<<"$score")" || return 1
    while IFS="$END_US" read -r name summary; do
      [ -n "$name" ] || continue
      end_switch_miss_line "$name" "$summary"
    done <<<"$misses"
  fi
  end_switch_question "$kind" "$(trial_yes_words)"
}

# The end report, given the log's lines, the closing round as the record
# keeps it — the briefs swept for and what finishing them printed — the
# reader's form of the agent's last reply with why it failed, the form empty
# where it did, and the kind due to be asked about with why none could be
# found, as format_end_switch takes them.
format_end_report() {
  local lines="$1" closing="$2" form="$3" failed="$4" switch="${5:-}" switch_failed="${6:-}" briefs names mine findings
  briefs="$(jq -c '.briefs' <<<"$closing")" || return 1
  names="$(jq -r 'join(", ")' <<<"$briefs")" || return 1
  mine="$(to_brief_log_lines "$lines" "$briefs")" || return 1
  findings="$(to_closing_findings "$mine")" || return 1
  end_report_heading "$names"
  end_built_line
  format_end_check "$form" "$failed"
  format_end_silent "$mine"
  format_end_fixed "$findings"
  format_end_dropped "$mine" "$findings"
  format_end_parked "$findings"
  format_end_cases "$closing"
  # Shown as the organizer printed it, every byte: the list of what finishing
  # freed is its own, and a list made from it here would be a second copy.
  end_freed_heading
  jq -j '.finished // ""' <<<"$closing"
  # Last, where the operator has read how the brief went (settled
  # 2026-10-01/02).
  format_end_switch "$switch" "$switch_failed"
}
