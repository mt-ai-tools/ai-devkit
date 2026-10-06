#!/usr/bin/env bash
# What the operator typed to start the stand-in, read off the prompt as typed:
# whether it is the command at all, and which of its three forms. The command
# is the entry skill's own name after a slash, handed in by the caller, so the
# name Claude Code offers the command by and the name recognised here cannot
# drift apart. Every function here is a transform. Sourced, never executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_START_COMMAND:-}" ] || return 0
STAND_IN_LOADED_START_COMMAND=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The three forms, as the request names them: bare, the organizer's list to
# pick from; with the flag, a session with no brief; with a name, that brief.
START_LIST="list"
START_SESSION="session"
START_BRIEF="brief"

# The word that asks for a session with no brief. The organizer refuses a
# brief's name that starts with a hyphen, so the flag cannot be one.
START_SESSION_FLAG="--session"

# The separator between a request's form and its brief.
START_US=$'\037'

# True if the prompt is the command named: a slash and the name, then nothing,
# or white space and the words after it. A prompt merely mentioning the
# command, or one whose name only begins with it, is not it: whatever else the
# operator types must pass this hook untouched.
is_start_command() {
  [[ "$1" =~ ^/"$2"([[:space:]]|$) ]]
}

# The request the command makes, as "<form><START_US><brief>", the brief
# empty but for the brief form; a refusal on stderr and a non-zero status for
# words the command does not take: more than one, or a flag it does not know.
# Refused rather than guessed at, since a guess here takes a brief or
# switches the stand-in on for a session nobody asked it to.
to_start_request() {
  local rest="${1#/"$2"}" words
  read -r -d '' -a words <<<"$rest" || true
  case "${#words[@]}" in
    0)
      printf '%s%s\n' "$START_LIST" "$START_US"
      return 0
      ;;
    1) ;;
    *)
      refuse_start_usage_note "$2" "$START_SESSION_FLAG" >&2
      return 1
      ;;
  esac
  case "${words[0]}" in
    "$START_SESSION_FLAG") printf '%s%s\n' "$START_SESSION" "$START_US" ;;
    -*)
      refuse_start_usage_note "$2" "$START_SESSION_FLAG" >&2
      return 1
      ;;
    *) printf '%s%s%s\n' "$START_BRIEF" "$START_US" "${words[0]}" ;;
  esac
}
