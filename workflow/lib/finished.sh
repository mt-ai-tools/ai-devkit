#!/usr/bin/env bash
# Which of a session's agents have reported, in one place: the agent-end hook
# writes it and the message hook reads it. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"

# The agents that report once and end: a builder, a fixer, a reviewer and the
# brief writer. Sending one more work after it has reported makes it carry
# its whole earlier run into the next, which costs more and reads worse than
# a fresh one handed what it needs. Named by their own files, so the names
# Claude Code starts them by and the names guarded cannot drift. Any other
# agent may be continued.
ONE_REPORT_AGENT_FILES=(
  builder/agents/builder.md
  reviewer/agents/fixer.md
  reviewer/agents/reviewer.md
  organizer/agents/brief-writer.md
)

# Succeeds where the agent type named is one that reports once.
is_one_report_agent() {
  local kit file
  kit="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
  for file in "${ONE_REPORT_AGENT_FILES[@]}"; do
    [ "$(read_header_fields "$kit/$file" name)" != "$1" ] || return 0
  done
  return 1
}

# Where a session's finished agents are listed, one id a line. Under the
# machine's temporary folder: it matters only while the session runs, and a
# list lost to a restart only leaves older agents unguarded. A session id
# that is not plainly a name is refused rather than built into a path.
finished_list() {
  [[ "$1" =~ ^[A-Za-z0-9_-]+$ ]] || return 1
  printf '%s/ai-devkit-finished-agents/%s' "${TMPDIR:-/tmp}" "$1"
}
