#!/usr/bin/env bash
# The trial: until the operator switches a kind, whatever the stand-in would
# settle without them still comes to them, marked with what it would have
# done, and is counted toward the kind's trial; trust is gained on their yes,
# never assumed. Asked by every path that can settle anything — a step's go,
# a question accepted with no challenge, an answer that held under its
# challenges — so all of them learn to tell a switched kind apart at once.
# Every function here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_TRIAL:-}" ] || return 0
STAND_IN_LOADED_TRIAL=1

# True while the kind named is on trial. Every kind is, until the operator
# switches it, and nothing switches one yet. This is the one place that will
# learn to tell a switched kind apart, the day one can be; until then a suite
# proves the switched paths by flipping this answer in a copy of the kit.
is_on_trial() {
  return 0
}
