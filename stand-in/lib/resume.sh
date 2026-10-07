#!/usr/bin/env bash
# The resume look-around (settled 2026-10-01/02 and 2026-10-06): once a
# session's wait on another session's work is over, the stand-in sends it the
# preset's look around, and its report reaches the operator, who gives the go.
# Every function here is a transform. Sourced, never executed.
#
# Why: the operator says the same line after a wait, so the agent rechecks
# its ground — its brief, the code it touches, what the other session
# landed — before building on what it knew before; and the operator otherwise
# watches the sessions and types "try now". The report is never weighed for a
# step's go, and never passes on silently: work resumes on the operator's go
# alone, since what the agent decided before the wait may no longer hold.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_RESUME:-}" ] || return 0
STAND_IN_LOADED_RESUME=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/woken.sh"

# The message the stand-in sends from the preset's resume look-around, asked
# for by the short name beside its quote there.
RESUME_LOOK_AROUND="look-around"

# Every message the resume look-around's file must hold, all asked for
# whichever is sent, as the ladder's are.
RESUME_MESSAGES=("$RESUME_LOOK_AROUND")

# --- Transforms.

# What the woken session is sent, given the preset's words and the wait's
# mark: the words as the preset quotes them, what the wait was for, and how
# to report.
format_resume_note() {
  local waited
  waited="$(format_waited_words "$2")" || return 1
  gate_challenge_note "$1"
  wait_over_note "$waited"
  resume_report_note
}

# What the operator is shown under the session's report, given the wait as
# the record keeps it.
format_resumed_note() {
  local waited
  waited="$(format_waited_words "$1")" || return 1
  resume_reported_note "$waited"
}

# What the operator is shown where the wait could not be watched, given its
# mark.
format_wait_refused_note() {
  local waited why
  waited="$(format_waited_words "$1")" || return 1
  why="$(jq -r '.why' <<<"$1")" || return 1
  resume_refused_note "$waited" "$why"
}
