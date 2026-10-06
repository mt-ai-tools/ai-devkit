#!/usr/bin/env bash
# The step go: what follows a reply that reports a step of the work finished,
# asks the operator nothing, and waits for their go to the next step, decided
# in code from the reader's form and the sorter's labelling of the report's
# problems, never from a model's words. Every function here is a transform.
# Sourced, never executed.
#
# Settled 2026-10-06: after a step's report with no question and nothing
# unfixed, the operator always says "go", so the stand-in may say it for
# them, and only where every one of these holds: the reply asks nothing; every
# problem found is fixed; the step's proof passed; and the next step is the
# brief's own next one, not new work.
#
# The order is the point. A major problem goes to the operator first, fixed or
# not: one already fixed is still one they would want to have seen, and
# sending it back to be fixed again would hide it. Then an unfixed problem is
# sent back to the agent before anything else is weighed, so none rides into
# the next step and the operator is never handed a report the agent could
# still have finished. Only a report with nothing left to fix is weighed for
# what is always the operator's, and only one with none of that earns the go.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_STEP_GO:-}" ] || return 0
STAND_IN_LOADED_STEP_GO=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"

# What follows a step's report: back to the agent, to the operator, or the go.
STEP_NEXT_AGENT="agent"
STEP_NEXT_OPERATOR="operator"
STEP_NEXT_GO="go"

# The step a brief starts with. Its go is always the operator's: it is the go
# to start building at all, given once the round's questions are settled.
STEP_FIRST_NUMBER=1

# --- Transforms.

# The labels that make a problem major, as a JSON array of {name, words}: the
# preset's risks, then lost data and a check that passed before now failing.
# The two are fixed in code rather than read off the preset, as the ladder's
# rungs are: they are part of the guard on what may ever pass without the
# operator, and a preset that left them out would let them pass.
list_major_labels() {
  jq -c --arg lost "$STEP_LOST_DATA" --arg lost_words "$(step_lost_data_words)" \
    --arg broken "$STEP_BROKEN_CHECK" --arg broken_words "$(step_broken_check_words)" \
    '. + [{name: $lost, words: $lost_words}, {name: $broken, words: $broken_words}]' <<<"$1"
}

# The lines saying which major problems the report holds, one each, given the
# sorter's checked labelling and the labels as list_major_labels gives them;
# and a line where the sorter could not tell, which counts as major.
derive_major_lines() {
  local sort="$1" labels="$2" problem label words
  while IFS="$STEP_US" read -r problem label; do
    [ -n "$label" ] || continue
    words="$(jq -r --arg label "$label" '.[] | select(.name == $label) | .words' <<<"$labels")"
    gate_major_line "$problem" "$label" "$words"
  done < <(jq -r --arg us "$STEP_US" '.majors[] | [.problem, .label] | map(gsub("\\s+"; " ")) | join($us)' <<<"$sort")
  if jq -e '.unsure' >/dev/null <<<"$sort"; then
    gate_major_unsure_line
  fi
}

# The problems of the reader's form in the state given, one line each.
derive_problem_lines() {
  jq -r --arg state "$2" '.problems[] | select(.state == $state) | .problem | gsub("\\s+"; " ")' <<<"$1" \
    | while IFS= read -r problem; do gate_problem_line "$problem"; done
}

# What the agent is sent back with, given the reader's form: the problems left
# unfixed, to fix before the next step, and those needing a decision, to ask
# the operator as a question, which the gate then takes like any other.
# Nothing where every problem is fixed.
derive_step_sendback() {
  local form="$1" unfixed needs
  unfixed="$(derive_problem_lines "$form" "$PROBLEM_UNFIXED")"
  needs="$(derive_problem_lines "$form" "$PROBLEM_NEEDS_DECISION")"
  if [ -n "$unfixed" ]; then
    gate_fix_first_note
    printf '%s\n' "$unfixed"
    [ -z "$needs" ] || { gate_ask_first_heading; printf '%s\n' "$needs"; }
  elif [ -n "$needs" ]; then
    gate_ask_first_note
    printf '%s\n' "$needs"
  fi
}

# The lines saying why a report with nothing left to fix is still the
# operator's, given the reader's form and the briefs the session holds as a
# JSON array (null where the organizer could not say): a proof that did not
# pass, a next step that is not the brief's own, the brief's first step, and
# whatever the reply says the next step does that is always theirs. Code tells
# what it can: whether a brief is held at all, and whether the step named is
# the first; what the next step does is read off the reply, never guessed.
derive_always_yours_lines() {
  local form="$1" briefs="$2" proof from number mark
  proof="$(jq -r '.proof' <<<"$form")"
  case "$proof" in
    "$STEP_PROOF_PASSED") ;;
    "$STEP_PROOF_FAILED") gate_proof_failed_line ;;
    *) gate_proof_unsaid_line ;;
  esac
  from="$(jq -r '.next_step_from' <<<"$form")"
  case "$from" in
    "$STEP_FROM_BRIEF") ;;
    "$STEP_FROM_NEW_WORK") gate_new_work_line ;;
    *) gate_next_unsaid_line ;;
  esac
  if [ "$briefs" = null ]; then
    gate_briefs_unknown_line
  elif [ "$(jq 'length' <<<"$briefs")" -eq 0 ]; then
    gate_no_brief_line
  fi
  number="$(jq -r '.next_step_number' <<<"$form")"
  if [ "$from" = "$STEP_FROM_BRIEF" ]; then
    if [ "$number" -eq 0 ]; then
      gate_step_number_unsaid_line
    elif [ "$number" -eq "$STEP_FIRST_NUMBER" ]; then
      gate_first_step_line
    fi
  fi
  # What the next step does is read off the report alone, never cut out of
  # the brief: the operator chose to trust the report (2026-10-06), so a
  # report silent about a push or a delete lets that step's go through.
  while IFS= read -r mark; do
    [ -n "$mark" ] || continue
    gate_step_mark_line "$(step_mark_words "$mark")"
  done < <(jq -r '.next_step_marks | unique[]' <<<"$form")
}

# What follows a step's report, as JSON {next, words}: next is "operator",
# the words one line per reason it came to them; "agent", the words it is
# sent back with; or "go". Given the reader's form, the sorter's labelling,
# the briefs the session holds (a JSON array, or null), and the labels.
derive_step_go() {
  local form="$1" sort="$2" briefs="$3" labels="$4" lines words
  lines="$(derive_major_lines "$sort" "$labels")"
  if [ -n "$lines" ]; then
    to_step_next "$STEP_NEXT_OPERATOR" "$lines"$'\n'
    return 0
  fi
  words="$(derive_step_sendback "$form")"
  if [ -n "$words" ]; then
    to_step_next "$STEP_NEXT_AGENT" "$words"$'\n'
    return 0
  fi
  lines="$(derive_always_yours_lines "$form" "$briefs")"
  if [ -n "$lines" ]; then
    to_step_next "$STEP_NEXT_OPERATOR" "$lines"$'\n'
    return 0
  fi
  to_step_next "$STEP_NEXT_GO" ""
}

# One step's next, as JSON.
to_step_next() {
  jq -cn --arg next "$1" --arg words "$2" '{next: $next, words: $words}'
}

# The decision a step's report puts to the operator, as the log keeps it and
# the settled list shows it: whether to go on to the next step the reply
# names.
to_step_question() {
  gate_step_question "$(jq -r '.next_step | gsub("\\s+"; " ")' <<<"$1")"
}

# The lines listing the problems fixed in passing, under their heading;
# nothing where none was.
derive_fixed_lines() {
  local lines
  lines="$(derive_problem_lines "$1" "$PROBLEM_FIXED")"
  [ -n "$lines" ] || return 0
  gate_fixed_heading
  printf '%s\n' "$lines"
}

# The operator's note for a go the stand-in would give, given the decision,
# why it came to them, one reason a line, and the problems fixed in passing as
# derive_fixed_lines gives them, empty for none.
to_go_message() {
  gate_step_trial_note "$1" "$2"
  [ -z "$3" ] || printf '\n%s' "$3"
  printf '\n'
}

# The step's report as the question log keeps it, given the reader's form and
# the sorter's labelling: what the reply said of its problems, its proof and
# its next step, and what the sorter found major. Kept whole so the end report
# can list what was fixed in passing beside each go.
to_step_details() {
  jq -cn --argjson form "$1" --argjson sort "$2" '
    ($form | {problems, proof, next_step, next_step_number, next_step_from, next_step_marks})
    + {majors: $sort.majors, unsure: $sort.unsure}'
}
