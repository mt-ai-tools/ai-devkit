#!/usr/bin/env bash
# The challenge ladder, decided in code from forms that passed their check:
# what a rung's answer is, whether the answers held, which message each step
# sends, and what the operator is shown. Every function here is a transform.
# Sourced, never executed.
#
# What the operator reads is whether a recommendation holds under challenge:
# the same answer, given again after the standing test and again after "are
# you sure?", is one the agent stands behind. So the ladder compares answers
# and nothing else; it never judges whether the answer is right, and a model
# is never asked whether the answers agree: the matcher says which item each
# reply recommends, and code compares the items.
#
# The light check climbs the same way, with fewer challenges: a name inside
# the code is a formal, cheap-to-change choice (settled 2026-10-06), so it is
# asked "are you sure?" alone, and an answer that moves goes to the operator
# with no bigger look around and no cold reading, which are the ladder's own.
# One climb for both, so how an answer is matched and compared is never
# written twice; a question's ladder holds which route it climbs.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_LADDER:-}" ] || return 0
STAND_IN_LOADED_LADDER=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/preset.sh"

# The messages the stand-in sends from the preset's ladder file, each asked
# for by the short name beside its quote there: the standing test and "are
# you sure?", the two challenges; and the bigger look around, sent once when
# an answer moved. No message asks the agent to retell a question plainly
# before it reaches the operator (dropped 2026-10-07): the summary's parts
# are its plain version.
LADDER_STANDING_TEST="standing-test"
LADDER_ARE_YOU_SURE="are-you-sure"
LADDER_BIGGER_LOOK="bigger-look"

# The fixed round after the bigger look around: "are you sure?" once more, in
# the ladder's own words (settled 2026-10-06, the operator's own sequence). A
# round of its own name rather than the rung's, since the rung is a challenge
# counted toward the send-back limit and this is a fixed round sent at most
# once; one name for both would make either look already sent.
LADDER_SURE_AGAIN="are-you-sure-again"

# Every message the ladder file must hold, all asked for whichever is sent.
LADDER_MESSAGES=("$LADDER_STANDING_TEST" "$LADDER_ARE_YOU_SURE" "$LADDER_BIGGER_LOOK")

# The challenge each rung after the first sends, in rung order. The order is
# held here, never read off the file: a reordered file would otherwise send
# "are you sure?" before the standing test without a word.
LADDER_CHALLENGES=("$LADDER_STANDING_TEST" "$LADDER_ARE_YOU_SURE")

# How many answers a question gives on the ladder: the first recommendation,
# then one after each challenge. Fixed in code rather than read off the
# preset: it is the guard on what may ever approve, and a preset with one
# challenge fewer would approve on less than the operator asks for.
LADDER_RUNGS=$((${#LADDER_CHALLENGES[@]} + 1))

# The challenge the light check sends after the first answer: "are you sure?"
# alone, fixed in code for the reason the ladder's are.
LIGHT_CHALLENGES=("$LADDER_ARE_YOU_SURE")

# What the ladder does next, as derive_ladder_step names it.
LADDER_CLIMB="climb"
LADDER_HELD="held"
LADDER_CHANGED="changed"

# How a list of option labels is shown to the operator on one line.
LADDER_OPTION_SEPARATOR=" / "

# The separator between a row's parts: the ASCII unit separator, which no
# label a model writes is expected to hold and bash never collapses.
LADDER_US=$'\037'

# The first rung's answer out of the reader's form of the question: the
# options it names in its order, and the one it recommends. Every later rung
# is matched against this one list.
to_first_answer() {
  jq -c '{options, recommended}' <<<"$1"
}

# A question that never went up the ladder, as a ladder of its first answer
# alone, so its answer is shown the way a ladder's are.
to_asked_ladder() {
  jq -c '{first: {options, recommended}, picks: []}' <<<"$1"
}

# The message a fixed round sends, by the round's name: its own message, but
# for "are you sure?" sent again, which sends the rung's words unchanged.
to_round_message_name() {
  case "$1" in
    "$LADDER_SURE_AGAIN") printf '%s\n' "$LADDER_ARE_YOU_SURE" ;;
    *) printf '%s\n' "$1" ;;
  esac
}

# The challenges the ladder given sends after its first answer, in order, one
# name a line, by the route it climbs; a refusal on stderr and a non-zero
# status for a route that climbs none, which is a ladder the gate did not
# write.
to_ladder_challenges() {
  local route
  route="$(jq -r '.route' <<<"$1")"
  case "$route" in
    "$ROUTE_LADDER") printf '%s\n' "${LADDER_CHALLENGES[@]}" ;;
    "$ROUTE_LIGHT") printf '%s\n' "${LIGHT_CHALLENGES[@]}" ;;
    *)
      refuse_ladder_route_note "$route" >&2
      return 1
      ;;
  esac
}

# How many answers the ladder given asks for: the first recommendation, then
# one after each of its route's challenges.
to_ladder_rungs() {
  local challenges
  challenges="$(to_ladder_challenges "$1")" || return 1
  printf '%s\n' "$(($(wc -l <<<"$challenges") + 1))"
}

# True if the ladder's answers held: every rung after the first matched to an
# item of the first rung's list, and that item the first rung's
# recommendation, which is not none. The same choice in other words is the
# same item, as the matcher reads it; a choice whose substance changed, an
# option added or dropped, or a reply that no longer asks the question is not
# the item, and has not held. Only the rungs are compared: the picks made
# after them, to the bigger look around and to "are you sure?" once more, are
# shown and never decide. An answer that moved once was unsure, and must never
# earn silence when its kind leaves the trial, however it held afterwards.
is_ladder_held() {
  local rungs
  rungs="$(to_ladder_rungs "$1")" || return 1
  jq -e --argjson rungs "$((rungs - 1))" --arg item "$MATCH_ITEM" '
    .first.recommended as $r
    | (.picks | length) >= $rungs
      and $r != ""
      and all(.picks[:$rungs][]; .pick == $item and .item == $r)' >/dev/null <<<"$1"
}

# True if the answer given to the bigger look around held when "are you
# sure?" was asked once more: both picks an item of the first list, and the
# same one, compared in code as the rungs are. Two new choices are never the
# same: the matcher reads each only against the first list, so nothing says
# the two are one. Never read for approval: see is_ladder_held.
is_look_held() {
  jq -e --argjson look "$((LADDER_RUNGS - 1))" --arg item "$MATCH_ITEM" '
    .picks[$look] as $looked
    | .picks[$look + 1] as $again
    | $looked != null and $again != null
      and $looked.pick == $item and $again.pick == $item
      and $looked.item == $again.item' >/dev/null <<<"$1"
}

# What follows the answers the ladder holds: climb, while a rung is left to
# ask; then held or changed. Every rung is asked even once an answer has
# moved: the operator is told of all of them, and whether the agent came back
# to its first answer is part of what they read.
derive_ladder_step() {
  local rungs picks
  rungs="$(to_ladder_rungs "$1")" || return 1
  picks="$(jq '.picks | length' <<<"$1")" || return 1
  if [ "$picks" -lt "$((rungs - 1))" ]; then
    printf '%s\n' "$LADDER_CLIMB"
  elif is_ladder_held "$1"; then
    printf '%s\n' "$LADDER_HELD"
  else
    printf '%s\n' "$LADDER_CHANGED"
  fi
}

# The name of the challenge the next rung sends: the first of its route's
# after the first answer, and so on.
to_rung_message_name() {
  local picks challenges
  challenges="$(to_ladder_challenges "$1")" || return 1
  picks="$(jq '.picks | length' <<<"$1")" || return 1
  sed -n "$((picks + 1))p" <<<"$challenges"
}

# The lines saying why the question came to the operator: the line given
# first, then those the route gave the ladder, each ending its line.
to_why_lines() {
  local lines extra
  lines="$1"$'\n'
  extra="$(jq -r '.lines' <<<"$2")" || return 1
  [ -z "$extra" ] || lines+="$extra"$'\n'
  printf '%s' "$lines"
}

# Why answers that held still came to the operator.
to_held_why() {
  local kind
  kind="$(jq -r '.kind' <<<"$1")" || return 1
  to_why_lines "$(gate_trial_line "$kind")" "$1"
}

# Why answers that moved came to the operator.
to_changed_why() {
  to_why_lines "$(gate_moved_line)" "$1"
}

# Why answers that moved, then held after the bigger look around, came to the
# operator.
to_looked_held_why() {
  to_why_lines "$(gate_moved_then_held_line)" "$1"
}

# Each answer as the operator reads it, one line each, in order: the first
# rung's recommendation and its list, then each later reply as the matcher
# picked it, those after the rungs marked as the answer to the bigger look
# around and to "are you sure?" once more.
derive_answer_lines() {
  local ladder="$1" recommended options n number pick item picks
  recommended="$(jq -r '.first.recommended' <<<"$ladder")" || return 1
  options="$(jq -r --arg separator "$LADDER_OPTION_SEPARATOR" '.first.options | join($separator) | gsub("\\s+"; " ")' <<<"$ladder")" || return 1
  if [ -z "$recommended" ]; then
    gate_answer_none_line 1 "$options"
  else
    gate_answer_line 1 "$recommended" "$options"
  fi
  n=1
  picks="$(jq -r --arg us "$LADDER_US" '.picks[] | [.pick, .item] | map(gsub("\\s+"; " ")) | join($us)' <<<"$ladder")" || return 1
  while IFS="$LADDER_US" read -r pick item; do
    [ -n "$pick" ] || continue
    n=$((n + 1))
    number="$n"
    if [ "$n" -eq "$((LADDER_RUNGS + 1))" ]; then
      number="$(gate_looked_number "$n")"
    elif [ "$n" -gt "$((LADDER_RUNGS + 1))" ]; then
      number="$(gate_sure_again_number "$n")"
    fi
    case "$pick" in
      "$MATCH_ITEM") gate_pick_line "$number" "$item" ;;
      "$MATCH_NEW") gate_pick_new_line "$number" ;;
      *) gate_answer_gone_line "$number" ;;
    esac
  done <<<"$picks"
}
