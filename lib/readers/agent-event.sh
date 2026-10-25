#!/usr/bin/env bash
# What the kit's hooks read from a Claude Code event about an agent, in one
# place: a field of the event, and where the agent that ran a tool keeps its
# own transcript. Needs jq: an event is JSON written by Claude Code, and
# parsing it by hand is how a quoted name slips through. Sourced, never
# executed.

# One top-level field of the event, given whole as the first argument, or
# nothing where the event lacks it. An event from the session itself carries
# no agent fields at all.
agent_event_field() {
  jq -r --arg field "$2" '.[$field] // "" | tostring' <<<"$1"
}

# One field of the tool's input, or nothing where it lacks it.
agent_event_tool_input() {
  jq -r --arg field "$2" '.tool_input[$field] // "" | tostring' <<<"$1"
}

# Succeeds where the event lists a shell command still running in the
# background. The list is the session's, not the agent's: it names agents and
# shell commands alike, and a shell command carries no owner.
agent_event_shell_running() {
  jq -e 'any(.background_tasks[]?; .type == "shell" and .status == "running")' <<<"$1" >/dev/null
}

# Where the agent that ran a tool keeps its own transcript. An agent's event
# names the session's transcript, not its own; Claude Code keeps an agent's
# beside it, in a folder named for the session. Claude Code's layout, not
# ours: it is the one place the kit leans on it, so a change there shows up
# here alone.
agent_event_transcript() {
  local session_transcript session agent
  session_transcript="$(agent_event_field "$1" transcript_path)"
  session="$(agent_event_field "$1" session_id)"
  agent="$(agent_event_field "$1" agent_id)"
  printf '%s/%s/subagents/agent-%s.jsonl' "$(dirname "$session_transcript")" "$session" "$agent"
}
