#!/usr/bin/env bash
# Asking a model, in one place: Claude Code run headless, once, fresh, with a
# time limit, made to answer to a JSON schema. Sourced, never executed.
#
# Needs the claude CLI on the path; the stand-in reaches a model through
# nothing else.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The settings each call runs with. Hooks off is what stops a reader, started
# from the stand-in's own end-of-reply hook, from starting a stand-in of its
# own on its answer, and so on without end.
ASK_MODEL_SETTINGS='{"disableAllHooks":true}'

# Safe mode leaves out everything the project and the operator configured —
# CLAUDE.md, memory, skills, agents, MCP servers: a reader judges a reply by
# what it is handed and nothing else, and no project instruction may steer it.
# Measured 2026-10-05 from the project root: about a sixth of the cost of a
# call that loads them ($0.004 against $0.025). Not `--bare`, which also
# skips reading the login and so cannot run on the operator's plan.
ASK_MODEL_ISOLATION="--safe-mode"

# The statuses `timeout` ends with when the time ran out, as against the
# command's own: 124 when the call stopped on being asked, 137 when it had to be
# killed.
ASK_MODEL_TIMEOUT_STATUSES=" 124 137 "

# How long a call that ignored its time limit is given to stop before it is
# killed, so a stuck call never holds the hook past its own limit.
ASK_MODEL_KILL_AFTER=5

# --- Transforms.

# The settings a call runs with: those every call runs with, over any the
# caller adds, so a caller's settings can add a rule but never switch the
# hooks back on.
to_call_settings() {
  jq -cn --argjson base "$ASK_MODEL_SETTINGS" --argjson extra "${1:-{\}}" '$extra * $base'
}

# The answer the model gave to the schema, as one line of JSON, out of the
# envelope Claude Code prints; a refusal naming why on stderr and a non-zero
# status where there is none. The answer is read only from the structured
# output Claude Code checked against the schema, never from the reply text: a
# model asked for JSON alone still sometimes wraps it in words.
to_model_answer() {
  local model="$1" envelope="$2" answer
  if ! jq -e 'type == "object"' >/dev/null 2>&1 <<<"$envelope"; then
    refuse_model_unreadable_note "$model" >&2
    return 1
  fi
  if jq -e '.is_error == true' >/dev/null <<<"$envelope"; then
    refuse_model_error_note "$model" >&2
    return 1
  fi
  if ! answer="$(jq -ce '.structured_output | select(type == "object")' <<<"$envelope")"; then
    refuse_model_unreadable_note "$model" >&2
    return 1
  fi
  printf '%s\n' "$answer"
}

# --- Reads.

# The model's answer to the prompt on stdin, as one line of JSON shaped by the
# schema given; a refusal naming why on stderr and a non-zero status where the
# time ran out, Claude Code stopped with an error, or what it printed cannot
# be read. No tools unless a comma-separated list is given: a job that only
# reads what it is handed has nothing to reach. A read-only tool given reaches
# no further than the folder the call runs in, which is the caller's to
# choose: a headless call with nothing allowed is refused a read outside its
# working directory (measured 2026-10-05). Settings given, as a JSON object,
# are added to those every call runs with, as to_call_settings merges them.
get_model_answer() {
  local model="$1" seconds="$2" schema="$3" tools="${4:-}" settings envelope status=0
  settings="$(to_call_settings "${5:-}")" || return 1
  envelope="$(timeout -k "$ASK_MODEL_KILL_AFTER" "$seconds" \
    claude -p "$ASK_MODEL_ISOLATION" --model "$model" --settings "$settings" --tools "$tools" \
    --output-format json --json-schema "$schema" 2>/dev/null)" || status=$?
  if [[ "$ASK_MODEL_TIMEOUT_STATUSES" == *" $status "* ]]; then
    refuse_model_timeout_note "$model" "$seconds" >&2
    return 1
  fi
  if [ "$status" -ne 0 ]; then
    refuse_model_exit_note "$model" "$status" >&2
    return 1
  fi
  to_model_answer "$model" "$envelope"
}
