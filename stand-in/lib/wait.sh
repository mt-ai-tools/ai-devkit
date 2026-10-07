#!/usr/bin/env bash
# The watch a session runs while it waits on another session's work: a
# command the agent starts in the background, which looks every so often and
# ends once the wait is over, leaving the mark the gate reads at the session's
# next stop. Claude Code wakes a session when a background command it started
# finishes (proved 2026-10-06, Claude Code 2.1.289), so the watch's end is the
# session's wake, and the gate then sends it the preset's resume look-around.
# Sourced, never executed.
#
# It reads the other session's work and never takes, commits or pushes any of
# it (settled 2026-10-06). A wait on a brief is written into the waiting
# session's own brief before the watch begins, as that brief's after list
# naming the brief waited for, through the work organizer, the list's one
# reader and writer; each look reads it back through the organizer, so the
# wait ends exactly when the organizer finishes the brief waited for, which
# takes the name out of every after list. A wait on a repository is written
# nowhere but its mark: it is no order between briefs, which is all a brief's
# header holds, but a passing state of another session's checkout, which only
# git can read.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_WAIT:-}" ] || return 0
STAND_IN_LOADED_WAIT=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"
. "$(dirname "${BASH_SOURCE[0]}")/briefs.sh"
. "$(dirname "${BASH_SOURCE[0]}")/repository.sh"
. "$(dirname "${BASH_SOURCE[0]}")/woken.sh"

# The entry's two waits, as the agent types them after the entry's path.
WAIT_BRIEF_COMMAND="wait-brief"
WAIT_REPOSITORY_COMMAND="wait-repository"

# How long the watch sleeps between looks, in seconds. A wait lasts minutes
# to hours, so learning it is over up to half a minute late costs nothing;
# each look runs the organizer or git once, and several sessions on one
# machine may each be waiting at once, every one on a watch of its own.
WAIT_LOOK_SECONDS=30

# What a look answers while the wait is not over; over is the mark's own word.
WAIT_WAITING="waiting"

# --- Reads.

# The session's id, from the environment; a refusal on stderr and a non-zero
# status where it is missing, or is no id that may name a file. Read there
# because the agent is never told its session's id, and a mark must be the
# session's own for the gate to read it at that session's stop and no other.
get_wait_session() {
  local session="${!SESSION_ID_VARIABLE:-}"
  if ! is_session_id "$session"; then
    refuse_wait_session_note "$SESSION_ID_VARIABLE" >&2
    return 1
  fi
  printf '%s\n' "$session"
}

# The briefs the session's own briefs wait on, as a JSON array of names, each
# once; empty where none waits on any. Refused as the organizer refuses.
list_session_waits() {
  local session="$1" briefs brief awaited all=""
  briefs="$(get_held_briefs "$session")" || return 1
  while IFS= read -r brief; do
    [ -n "$brief" ] || continue
    awaited="$(list_awaited_briefs "$brief")" || return 1
    all+="$awaited"$'\n'
  done < <(jq -r '.[]' <<<"$briefs")
  printf '%s' "$all" | jq -Rcn '[inputs | select(. != "")] | unique'
}

# Whether the session's wait on briefs is over: over once its briefs wait on
# none, waiting otherwise. Refused as the organizer refuses, never read as
# over.
get_brief_wait_state() {
  local waits
  waits="$(list_session_waits "$1")" || return 1
  if [ "$(jq 'length' <<<"$waits")" -eq 0 ]; then
    printf '%s\n' "$WAIT_OVER"
  else
    printf '%s\n' "$WAIT_WAITING"
  fi
}

# Whether the wait on the repository at the path given, inside the project
# root given, is over: over once it holds nothing uncommitted and nothing
# unpushed, waiting otherwise. Refused as get_repository_state refuses, never
# read as over.
get_repository_wait_state() {
  local state
  state="$(get_repository_state "$1" "$2")" || return 1
  if [ "$state" = "$REPOSITORY_CLEAN" ]; then
    printf '%s\n' "$WAIT_OVER"
  else
    printf '%s\n' "$WAIT_WAITING"
  fi
}

# Run the look given, with its arguments, until it answers over, sleeping
# between looks; its kind is the look's. The first look runs at once, so a
# wait already over ends at once. Refused as the look refuses, at whichever
# look that is.
run_until_over() {
  local state
  while :; do
    state="$("$@")" || return 1
    [ "$state" != "$WAIT_OVER" ] || return 0
    sleep "$WAIT_LOOK_SECONDS"
  done
}

# --- Writes.

# Write the brief given into the after list of every brief the session
# holds, through the organizer, printing every path it changed. Refused where
# the session holds none, as the organizer refuses, and where the organizer
# cannot write it: a wait nobody wrote down would be watched for nothing.
write_session_wait() {
  local session="$1" on="$2" briefs brief
  briefs="$(get_held_briefs "$session")" || return 1
  if [ "$(jq 'length' <<<"$briefs")" -eq 0 ]; then
    refuse_wait_no_brief_note >&2
    return 1
  fi
  while IFS= read -r brief; do
    write_brief_wait "$brief" "$on" || return 1
  done < <(jq -r '.[]' <<<"$briefs")
}

# Watch the session's wait of the kind given, on the brief or the
# repository's path given, until it is over: a wait on a brief written into
# the session's briefs first, the paths changed printed under a line saying
# so. Refused as any part refuses.
watch_wait() {
  local session="$1" kind="$2" on="$3" written
  if [ "$kind" = "$WAIT_BRIEF" ]; then
    written="$(write_session_wait "$session" "$on")" || return 1
    [ -z "$written" ] || { wait_written_line; printf '%s\n' "$written"; }
    run_until_over get_brief_wait_state "$session"
    return
  fi
  run_until_over get_repository_wait_state "$(get_project_root)" "$on"
}

# Run the session's wait to its end and leave its mark: over, printing that it
# is, or refused, with every reason the watch gave, on stderr too, and a
# non-zero status. The reasons are kept in a variable, never a file, so a
# watch stopped from outside, as a session's end stops it, leaves nothing
# behind. A mark that cannot be written is refused as well: the gate then
# cannot learn the wait ended, and the agent, woken, reads why.
run_wait() {
  local history="$1" session="$2" kind="$3" on="$4" reasons mark out status=0
  exec {out}>&1
  reasons="$(watch_wait "$session" "$kind" "$on" 2>&1 >&"$out")" || status=1
  exec {out}>&-
  if [ "$status" -eq 0 ]; then
    mark="$(to_woken_mark "$WAIT_OVER" "$kind" "$on")"
  else
    mark="$(to_woken_mark "$WAIT_REFUSED" "$kind" "$on" "$reasons")"
    printf '%s\n' "$reasons" >&2
  fi
  write_woken_mark "$history" "$session" "$mark" || return 1
  [ "$status" -eq 0 ] || return 1
  wait_over_note "$(format_waited_words "$mark")"
}
