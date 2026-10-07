#!/usr/bin/env bash
# Running one call over many items, a bounded number at a time, in one place:
# through GNU parallel where it is installed, and one at a time where it is
# not, so a machine without it still runs every item. Sourced, never
# executed.
#
# Each item runs in a fresh bash of its own, both ways, loading the file that
# holds the call and calling it with the item last. A fresh process is what
# GNU parallel can start: a function of the caller's shell reaches none of
# its jobs. Running the fallback the same way keeps the two ways one: an
# item never sees a variable or a function the other way would not hand it.
#
# Each item writes only its own output: its stdout and its stderr go to two
# files of its own in a folder the caller hands over, numbered by the item's
# place in the list, so whatever reads them reads them in the list's order,
# however the items finished.

# How many items run at once, where the caller has no reason to choose. Eight,
# not every thread a machine has: a full load on every thread is not what the
# work needs, and on the kit's first machine it is untested and the first
# suspect for a shutdown. Measured 2026-10-06 on the kit's own suite: 394
# tests took about 9 minutes one at a time and 102 seconds eight at a time.
SIDE_BY_SIDE_JOBS=8

# The program that runs items side by side, and what its version line begins
# with: another program of the same name (moreutils ships one) takes a
# different command line, and taken for GNU parallel would run something else.
SIDE_BY_SIDE_PROGRAM="parallel"
SIDE_BY_SIDE_PROGRAM_VERSION="GNU parallel"

# The file in the caller's folder holding the call every item makes: the file
# to load, the function and its arguments, separated by NUL. Kept in a file
# rather than on GNU parallel's command line, which reads braces there as
# places to put the item: a JSON argument holding `{}` would be rewritten.
SIDE_BY_SIDE_CALL_NAME="call"

# The statuses run_side_by_side ends with beside 0: an item whose call ended
# with any other status, and the items not run at all.
SIDE_BY_SIDE_ITEM_FAILED=1
SIDE_BY_SIDE_REFUSED=2

# What one item runs, in a bash of its own, given the folder, its place and
# the item. It sets what an entry of the kit sets, so a call behaves as it
# does under the entry that loads it; its stdin is empty, as GNU parallel
# leaves a job's when the items arrive on its own.
SIDE_BY_SIDE_ITEM_SCRIPT='
set -euo pipefail
shopt -s inherit_errexit
folder="$1"
place="$2"
item="$3"
mapfile -d "" -t call <"$folder/'"$SIDE_BY_SIDE_CALL_NAME"'"
exec </dev/null >"$folder/$place.out" 2>"$folder/$place.err"
. "${call[0]}"
"${call[@]:1}" "$item"
'

# --- The words a refusal hands the operator — in one place, so the suite
# asserts the wiring rather than the wording.

side_by_side_jobs_note() {
  printf '%s is not a number of items to run at once.\n' "$1"
}

side_by_side_folder_note() {
  printf '%s is not a folder the items'\'' output can be written to.\n' "$1"
}

side_by_side_library_note() {
  printf '%s cannot be read as a file to load.\n' "$1"
}

side_by_side_program_note() {
  printf 'GNU parallel stopped with status %s before every item had run.\n' "$1"
}

# --- Transforms.

# Where an item's stdout and stderr are kept, given the folder and the item's
# place in the list, counted from 1.
to_side_by_side_output() {
  printf '%s/%s.out\n' "$1" "$2"
}

to_side_by_side_errors() {
  printf '%s/%s.err\n' "$1" "$2"
}

# --- Reads.

# The path of GNU parallel where it is installed; nothing where it is not, or
# where the program of its name is another.
find_side_by_side_program() {
  local path version
  path="$(type -P "$SIDE_BY_SIDE_PROGRAM")" || return 0
  # Read whole, then cut: a pipe closed early would fail the read of a
  # program that is there.
  version="$("$path" --version </dev/null 2>/dev/null)" || return 0
  [[ "${version%%$'\n'*}" == "$SIDE_BY_SIDE_PROGRAM_VERSION"* ]] || return 0
  printf '%s\n' "$path"
}

# --- Runs.

# Run the function given, loaded from the file given, once for each item on
# stdin, one item a line, at most the number given at once, with the
# arguments given and the item last; an empty line is no item. Item n's stdout
# and stderr are kept where to_side_by_side_output and to_side_by_side_errors
# say, in the folder given, which must exist; the call is kept there too.
#
# Ends 0 where every item's call ended 0, SIDE_BY_SIDE_ITEM_FAILED where any
# did not — every item still run, so a caller may read each one's output and
# judge the failure itself — and SIDE_BY_SIDE_REFUSED, with the reason on
# stderr, where the items could not be run. An item is one line, handed as one
# argument: anything larger is handed by a path.
run_side_by_side() {
  local jobs="$1" folder="$2" library="$3" program items=() item place=0 status=0
  shift 3
  if ! [[ "$jobs" =~ ^[1-9][0-9]*$ ]]; then
    side_by_side_jobs_note "$jobs" >&2
    return "$SIDE_BY_SIDE_REFUSED"
  fi
  if [ ! -d "$folder" ] || [ ! -w "$folder" ]; then
    side_by_side_folder_note "$folder" >&2
    return "$SIDE_BY_SIDE_REFUSED"
  fi
  if [ ! -f "$library" ] || [ ! -r "$library" ]; then
    side_by_side_library_note "$library" >&2
    return "$SIDE_BY_SIDE_REFUSED"
  fi
  while IFS= read -r item || [ -n "$item" ]; do
    [ -z "$item" ] || items+=("$item")
  done
  [ "${#items[@]}" -gt 0 ] || return 0
  if ! { printf '%s\0' "$library" "$@" >"$folder/$SIDE_BY_SIDE_CALL_NAME"; } 2>/dev/null; then
    side_by_side_folder_note "$folder" >&2
    return "$SIDE_BY_SIDE_REFUSED"
  fi
  program="$(find_side_by_side_program)"
  if [ -n "$program" ]; then
    printf '%s\n' "${items[@]}" \
      | "$program" --jobs "$jobs" --quote bash -c "$SIDE_BY_SIDE_ITEM_SCRIPT" _ "$folder" '{#}' '{}' \
      || status=$?
    # GNU parallel ends with how many jobs failed, up to 101, and above that
    # where it could not run them.
    [ "$status" -eq 0 ] && return 0
    if [ "$status" -le 101 ]; then
      return "$SIDE_BY_SIDE_ITEM_FAILED"
    fi
    side_by_side_program_note "$status" >&2
    return "$SIDE_BY_SIDE_REFUSED"
  fi
  for item in "${items[@]}"; do
    place=$((place + 1))
    bash -c "$SIDE_BY_SIDE_ITEM_SCRIPT" _ "$folder" "$place" "$item" || status="$SIDE_BY_SIDE_ITEM_FAILED"
  done
  return "$status"
}
