#!/usr/bin/env bash
# The first challenge: a kind of question whose entry carries a challenge is
# sent it before anything else, and the agent's answer, as the reader's form
# gives it, decides what follows. Every function here is a transform.
# Sourced, never executed.
#
# Dropping the proposal ends it: it is noted and the work goes on. Keeping
# all or part of it earns the second challenge where the entry has one, and
# otherwise goes on to the routes; keeping part counts as keeping. A reply
# that answers neither way is not guessed at.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CHALLENGE:-}" ] || return 0
STAND_IN_LOADED_CHALLENGE=1
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"

# What follows the reply to a challenge, given the challenge the record holds
# and the reader's form of the reply, as JSON {next, words}: next is "drop";
# "challenge", with the second challenge's words; "routes", for the question
# as it stood when challenged; or "unanswered", with the words of the
# challenge the reply did not answer.
derive_challenge_step() {
  local challenge="$1" form="$2" answer step second asked
  answer="$(jq -r '.guidance_answer' <<<"$form")"
  step="$(jq -r '.step' <<<"$challenge")"
  second="$(jq -r '.entry.second_challenge' <<<"$challenge")"
  case "$answer" in
    "$GUIDANCE_DROP")
      to_challenge_step drop ""
      ;;
    "$GUIDANCE_KEEP_PART" | "$GUIDANCE_KEEP_ALL")
      if [ "$step" = 1 ] && [ -n "$second" ]; then
        to_challenge_step challenge "$second"
      else
        to_challenge_step routes ""
      fi
      ;;
    *)
      asked="$(jq -r '.entry.challenge' <<<"$challenge")"
      [ "$step" = 1 ] || asked="$second"
      to_challenge_step unanswered "$asked"
      ;;
  esac
}

# One step's JSON.
to_challenge_step() {
  jq -cn --arg next "$1" --arg words "$2" '{next: $next, words: $words}'
}
