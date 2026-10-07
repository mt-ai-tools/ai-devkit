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
#   write-cases         the test cases of the brief the stand-in finished in
#                       the session, written from the operator's answers;
#                       each case file's path on stdout
#   exam                every test case replayed against the stand-in as it
#                       now stands, each case's result on stdout; a pass
#                       clears the session's exam owed
#
# Each wait is run by the agent as a background command, inside the session
# it waits for, and leaves the mark the gate reads at that session's next
# stop. The case-writer is run by the agent in the foreground, inside the
# session whose brief was finished, before it commits what finishing changed:
# its cases are committed with those paths. The exam is run by the agent in
# the foreground, inside the session that edited what the stand-in judges by,
# or by the operator anywhere.
#
# Status: 0 when it answered with a form that passed its check, a wait is
# over, the cases were written, those it held back counted, or the exam
# passed; 1 for a refusal, with every reason on stderr, a failed exam, or a
# usage it does not know. One non-zero status throughout, so whatever runs it need only tell a
# form it may decide from, or a wait over, apart from anything else: every
# refusal goes the same way. A config file the kit refuses stops it with the
# config reader's own reason.
set -euo pipefail
# Errexit kept inside command substitutions; why beside the gate's own line.
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/sorter.sh"
. "$tool_root/lib/wait.sh"
. "$tool_root/lib/cases.sh"
. "$tool_root/lib/exam.sh"

usage() {
  refuse_usage_note "$WAIT_BRIEF_COMMAND" "$WAIT_REPOSITORY_COMMAND" "$CASES_COMMAND" "$EXAM_COMMAND" >&2
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

# The cases of the session's finished brief, for the session the command runs
# in, its id read where the wait reads it. The writer is loaded only here: it
# brings the model jobs no other command runs.
run_session_cases() {
  local session history
  if ! is_session_id "${!SESSION_ID_VARIABLE:-}"; then
    refuse_cases_session_note "$SESSION_ID_VARIABLE" >&2
    exit 1
  fi
  session="${!SESSION_ID_VARIABLE}"
  history="$(get_config_path AIDK_STAND_IN_HISTORY)"
  . "$tool_root/lib/write-cases.sh"
  run_write_cases "$history" "$session"
}

# The exam, for the session the command runs in, its id read where the wait
# reads it; or for none, where the environment names none, as when the
# operator runs it by hand: it then clears no session's exam owed. An id that
# cannot name a file is refused rather than taken for none, since the exam
# owed it should clear would then stand unseen. The replay is loaded only
# here: it brings the model jobs no other command runs.
run_session_exam() {
  local session="${!SESSION_ID_VARIABLE:-}" history preset rules conventions
  if [ -n "$session" ] && ! is_session_id "$session"; then
    refuse_exam_session_note "$SESSION_ID_VARIABLE" >&2
    exit 1
  fi
  history="$(get_config_path AIDK_STAND_IN_HISTORY)"
  preset="$(get_config_path AIDK_STAND_IN)"
  rules="$(get_config_path AIDK_RULES)"
  conventions="$(get_config_path AIDK_CONVENTIONS)"
  . "$tool_root/lib/run-exam.sh"
  run_exam "$history" "$session" "$preset" "$rules" "$conventions"
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
  "$CASES_COMMAND")
    [ "$#" -eq 0 ] || usage
    run_session_cases
    ;;
  "$EXAM_COMMAND")
    [ "$#" -eq 0 ] || usage
    run_session_exam
    ;;
  *)
    usage
    ;;
esac
