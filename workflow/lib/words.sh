#!/usr/bin/env bash
# Every word the workflow's hooks hand their reader, in one place, so the
# suite asserts the wiring rather than the wording. Sourced, never executed.

# Why a message to an agent was refused: it has already reported.
finished_agent_note() {
  printf '%s has already reported and takes no more work. Start a fresh agent with what it needs.\n' "$1"
}

bad_session_note() {
  printf 'Workflow hook: the session id %s is not plainly a name, so its finished agents are not tracked\n' "$1"
}

# Handed to a session past the size worth compacting, at every turn until it
# is compacted.
compact_hook_note() {
  printf 'Size note: this session is at %s tokens of context, worth compacting. Do as "Pausing to compact" in the workflow says.\n' "$1"
}

compact_hook_no_transcript_note() {
  printf 'Workflow compact hook: the event names no transcript, so this session is not measured\n'
}
