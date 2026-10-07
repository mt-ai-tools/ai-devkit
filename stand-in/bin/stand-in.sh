#!/usr/bin/env bash
# The stand-in's one entry — a thin orchestrator: it finds the preset, and
# hands each subcommand to the concern that holds it.
#
#   read-reply          the reply on stdin; its checked reader's form on stdout
#   sort <reader form>  the reply on stdin; the question's checked sorter's
#                       answer on stdout
#   wait-brief <brief>  the session's wait for another brief to be finished,
#                       written into its own and watched until it is over
#   wait-repository <path>
#                       the session's wait for the repository at the path,
#                       from the project root, to hold nothing uncommitted and
#                       nothing unpushed, watched until it does
#
# Each wait is run by the agent as a background command, inside the session
# it waits for, and leaves the mark the gate reads at that session's next
# stop.
#
# Status: 0 when it answered with a form that passed its check, or a wait is
# over; 1 for a refusal, with every reason on stderr, or a usage it does not
# know. One non-zero status throughout, so whatever runs it need only tell a
# form it may decide from, or a wait over, apart from anything else: every
# refusal goes the same way. A config file the kit refuses stops it with the
# config reader's own reason.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/sorter.sh"
. "$tool_root/lib/wait.sh"

usage() {
  refuse_usage_note "$WAIT_BRIEF_COMMAND" "$WAIT_REPOSITORY_COMMAND" >&2
  exit 1
}

# A wait of the kind given, on the brief or path given, for the session the
# command runs in, resolved into variables first, as sort's preset is. Where
# the session or the working folder cannot be told no mark can be left, so
# the refusal reaches the agent alone, on stderr, when the session wakes.
run_session_wait() {
  local session history
  session="$(get_wait_session)"
  history="$(get_config_path AIDK_STAND_IN_HISTORY)"
  run_wait "$history" "$session" "$1" "$2"
}

command="${1:-}"
[ "$#" -gt 0 ] && shift

case "$command" in
  read-reply)
    [ "$#" -eq 0 ] || usage
    reply="$(cat)"
    get_reader_form "$reply"
    ;;
  sort)
    [ "$#" -eq 1 ] || usage
    # Resolved into a variable before use, never inline as an argument: a
    # failing command substitution inside an argument does not end the script,
    # so a refused config file would otherwise reach the sorter as an empty
    # path. A plain assignment does end it.
    preset="$(get_config_path AIDK_STAND_IN)"
    reply="$(cat)"
    get_sorter_answer "$1" "$reply" "$preset"
    ;;
  "$WAIT_BRIEF_COMMAND")
    [ "$#" -eq 1 ] || usage
    run_session_wait "$WAIT_BRIEF" "$1"
    ;;
  "$WAIT_REPOSITORY_COMMAND")
    [ "$#" -eq 1 ] || usage
    run_session_wait "$WAIT_REPOSITORY" "$1"
    ;;
  *)
    usage
    ;;
esac
