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
