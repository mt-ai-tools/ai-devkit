#!/usr/bin/env bash
# The closing loop, decided in code from forms that passed their check: what
# each finding of a look becomes once code has checked what it can, how a
# round is numbered and counted, and what the agent and the operator are told.
# Every function here is a transform. Sourced, never executed.
#
# Settled 2026-10-06, the operator's own routine: for them "done" means the
# sweep has come back empty, not that the steps ran. A round is two looks,
# the cleanup first, then every place the new thing should now be used;
# rounds repeat until a round finds nothing that belongs to the brief, which
# is the one end code can see rather than the agent's say-so. The agent sorts
# what it finds; code checks what it can of the sort, and decides from the
# sorts alone.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CLOSING:-}" ] || return 0
STAND_IN_LOADED_CLOSING=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"

# The messages the stand-in sends from the preset's closing loop, each asked
# for by the short name beside its quote there: the two looks of a round, and
# the question a step's report naming no next step is sent. Each look's
# name is also the fixed round whose reply the gate awaits.
CLOSING_CLEANUP_LOOK="cleanup-look"
CLOSING_USE_LOOK="use-look"
CLOSING_WHOLE_DONE="whole-brief-done"

# Every message the closing loop's file must hold, all asked for whichever is
# sent, as the ladder's are.
CLOSING_MESSAGES=("$CLOSING_CLEANUP_LOOK" "$CLOSING_USE_LOOK" "$CLOSING_WHOLE_DONE")

# The fixed round awaiting the reply after a round came back empty and the
# briefs were finished: the agent commits what finishing printed and says how
# the full check went, and its reply brings the end report. The stand-in's
# own round, never the preset's: nothing in it is the operator's words.
CLOSING_FINISHED="brief-finished"

# How many rounds finding something that belongs to the brief the loop runs
# before the operator is told, with the list (settled 2026-10-06). Fixed in
# code rather than read off the preset, as the ladder's rungs are: it is the
# guard on a loop the agent could otherwise keep going unseen. Only rounds
# finding something that belongs here count: one whose findings all belong
# elsewhere is the sweep working, not the brief failing to close.
CLOSING_NOTICE_ROUNDS=3

# Why code took a finding the agent would fix in passing out of its hands
# (settled 2026-10-06): another session's taken brief works where its files
# lie, and it is handed off into that brief; or its files hold changes nobody
# committed, whose owner nothing names, and it is parked.
CLOSING_MOVED_HELD="held"
CLOSING_MOVED_UNCOMMITTED="uncommitted"

# The separator between a row's parts: the ASCII unit separator, which no
# finding a model writes is expected to hold and bash never collapses.
CLOSING_US=$'\037'

# --- Transforms.

# The findings code checks, out of the closing reader's checked form: those
# the agent would fix in passing, each {index, files}, as a JSON array, the
# index being the finding's place in the form.
to_quick_files() {
  jq -c --arg quick "$FINDING_QUICK" \
    '[.findings | to_entries[] | select(.value.sort == $quick) | {index: .key, files: .value.files}]' <<<"$1"
}

# The names of the briefs other sessions hold, as a JSON array, given the
# taken briefs as the organizer lists them and this session's id.
to_other_briefs() {
  jq -c --arg session "$2" '[.[] | select(.session != $session) | .brief] | unique' <<<"$1"
}

# A finding's check, as JSON {held, uncommitted}, given the briefs other
# sessions hold where its files lie, as a JSON array, and the files among
# them holding changes nobody committed, one a line.
to_finding_check() {
  jq -cn --argjson held "$1" --argjson uncommitted "$([ -n "$2" ] && echo true || echo false)" \
    '{held: $held, uncommitted: $uncommitted}'
}

# The checks given, a JSON object keyed by a finding's index, with one more.
with_finding_check() {
  jq -c --arg index "$2" --argjson check "$3" '.[$index] = $check' <<<"$1"
}

# The look's findings as the round keeps them, given the closing reader's
# checked form, the look, and the checks keyed by index: each {look, finding,
# files, sort, briefs, moved}. A finding the agent would fix in passing whose
# files another session works in becomes a hand-off into those briefs; one
# whose files hold changes nobody committed is parked; moved says which, and
# is empty for every finding kept as the agent sorted it.
to_checked_findings() {
  jq -c --arg look "$2" --argjson checks "$3" --arg quick "$FINDING_QUICK" \
    --arg hand_off "$FINDING_HAND_OFF" --arg park "$FINDING_PARK" \
    --arg held "$CLOSING_MOVED_HELD" --arg uncommitted "$CLOSING_MOVED_UNCOMMITTED" '
    [.findings | to_entries[] | (.key | tostring) as $i | .value as $f
      | ($checks[$i] // {held: [], uncommitted: false}) as $c
      | (if $f.sort != $quick then ""
         elif ($c.held | length) > 0 then $held
         elif $c.uncommitted then $uncommitted
         else "" end) as $moved
      | {look: $look, finding: $f.finding, files: $f.files,
         sort: (if $moved == $held then $hand_off elif $moved == $uncommitted then $park else $f.sort end),
         briefs: (if $moved == $held then $c.held elif $f.brief != "" then [$f.brief] else [] end),
         moved: $moved}]' <<<"$1"
}

# True if any of the round's findings belongs to the brief.
is_closing_here() {
  jq -e --arg here "$FINDING_HERE" 'any(.[]; .sort == $here)' >/dev/null <<<"$1"
}

# The round's number and how many rounds count toward the notice, as JSON
# {number, counted}, given the log's lines, the session, the briefs swept
# for as a JSON array, and this round's findings. A round is the session's
# for the same briefs: another session's rounds, and this session's for
# another brief, are other sweeps. Counted are those finding something that
# belongs here, this one among them where it does.
derive_closing_tally() {
  jq -cs --arg session "$2" --argjson briefs "$3" --argjson findings "$4" --arg here "$FINDING_HERE" '
    def here: any(.[]; .sort == $here);
    ($briefs | sort) as $mine
    | [.[] | select(.session == $session and .closing != null and ((.closing.briefs // []) | sort) == $mine)] as $own
    | {number: (($own | length) + 1),
       counted: (($own | map(select(.closing.findings | here)) | length) + (if ($findings | here) then 1 else 0 end))}' \
    <<<"$1"
}

# The round as its log line keeps it, as JSON {number, briefs, findings}.
to_closing_details() {
  jq -cn --argjson number "$1" --argjson briefs "$2" --argjson findings "$3" \
    '{number: $number, briefs: $briefs, findings: $findings}'
}

# The report note sent under each look, its sort words the form's own.
to_closing_report_note() {
  closing_report_note "$FINDING_HERE" "$FINDING_WRITTEN_DOWN" "$FINDING_NOT_SAME_JOB" "$FINDING_QUICK" \
    "$FINDING_HAND_OFF" "$FINDING_PARK"
}

# The round's findings of the sort given, one row each:
# "<finding><US><briefs joined><US><moved>".
derive_finding_rows() {
  jq -r --arg sort "$2" --arg us "$CLOSING_US" \
    '.[] | select(.sort == $sort) | [.finding, (.briefs | join(", ")), .moved] | map(gsub("\\s+"; " ")) | join($us)' <<<"$1"
}

# Why a finding was moved, in words; nothing for one kept as sorted.
format_moved_words() {
  case "$1" in
    "$CLOSING_MOVED_HELD") closing_moved_held_words ;;
    "$CLOSING_MOVED_UNCOMMITTED") closing_moved_uncommitted_words ;;
  esac
}

# What the agent is to do with the round's findings that do not belong here:
# fix the quick ones in passing, write the hand-offs into their briefs, and
# park the rest. Each part under its heading, left out where it is empty;
# the dropped ones ask nothing of it.
format_closing_tasks() {
  local findings="$1" rows finding briefs moved
  rows="$(derive_finding_rows "$findings" "$FINDING_QUICK")"
  if [ -n "$rows" ]; then
    closing_quick_heading
    while IFS="$CLOSING_US" read -r finding briefs moved; do gate_problem_line "$finding"; done <<<"$rows"
  fi
  rows="$(derive_finding_rows "$findings" "$FINDING_HAND_OFF")"
  if [ -n "$rows" ]; then
    closing_hand_off_heading
    while IFS="$CLOSING_US" read -r finding briefs moved; do
      closing_hand_off_line "$finding" "$briefs" "$(format_moved_words "$moved")"
    done <<<"$rows"
  fi
  rows="$(derive_finding_rows "$findings" "$FINDING_PARK")"
  if [ -n "$rows" ]; then
    closing_park_heading
    while IFS="$CLOSING_US" read -r finding briefs moved; do
      if [ -n "$moved" ]; then
        closing_moved_line "$finding" "$(format_moved_words "$moved")"
      else
        gate_problem_line "$finding"
      fi
    done <<<"$rows"
  fi
}

# What the agent is told once a round is over, given its findings, what
# finishing the briefs printed, and the case-writer's command as the agent
# types it: where something belongs here, to ask about each, one question at
# a time, through the gate as any question; where nothing does, that the
# sweep is done, to run the case-writer, and to commit exactly what finishing
# the briefs printed and the cases it wrote, run the full check and say how
# it went. Either way, what to do with the rest.
format_closing_agent_note() {
  local findings="$1" finished="$2" cases_command="$3" rows finding briefs moved
  if is_closing_here "$findings"; then
    closing_here_note
    rows="$(derive_finding_rows "$findings" "$FINDING_HERE")"
    while IFS="$CLOSING_US" read -r finding briefs moved; do gate_problem_line "$finding"; done <<<"$rows"
    format_closing_tasks "$findings"
    return 0
  fi
  closing_swept_note
  format_closing_tasks "$findings"
  closing_commit_line "$cases_command"
  printf '%s' "$finished"
}

# What the operator is told where finishing the briefs failed, given why, as
# the organizer said, what it printed before it failed, and the round's
# findings: the reply stops, and the paths already changed are theirs to see,
# since nobody has been told to commit them.
format_finish_failed() {
  local why="$1" finished="$2" findings="$3"
  closing_finish_failed_note "$why"
  if [ -n "$finished" ]; then
    closing_finish_partial_heading
    printf '%s' "$finished"
  fi
  closing_round_findings_heading
  format_closing_findings "$findings"
}

# The round's findings as the operator reads them, each with its sort in
# words and, for a hand-off, the briefs it goes into.
format_closing_findings() {
  local findings="$1" finding sort briefs words
  while IFS="$CLOSING_US" read -r finding sort briefs; do
    [ -n "$finding" ] || continue
    words="$(closing_sort_words "$sort")"
    [ -z "$briefs" ] || words+=", $(closing_into_words "$briefs")"
    closing_finding_line "$finding" "$words"
  done < <(jq -r --arg us "$CLOSING_US" '.[] | [.finding, .sort, (.briefs | join(", "))] | map(gsub("\\s+"; " ")) | join($us)' <<<"$findings")
}
