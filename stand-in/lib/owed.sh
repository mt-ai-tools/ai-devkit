#!/usr/bin/env bash
# The exam owed: which files hold what the stand-in judges by, and the mark an
# edit of one leaves for the session that made it, until an exam passes.
# One small JSON file per session, named for its id, in a folder of the
# stand-in's own working folder. Sourced, never executed.
#
# What the stand-in judges by is its preset, its prompts and its model list
# (settled 2026-10-06, decision 7 of the stand-in's loops): a change to any of
# them changes what its readers answer or how code routes on it, and only a
# replay of the real cases shows whether a case the stand-in got right before
# now goes wrong. The rules and the conventions change what the checker finds
# too, but are the project's own and owe no exam; the stand-in's code is held
# by its suite instead.
#
# Noted by an after-tool hook of Claude Code's file-editing tools, never by a
# git hook (the operator's call, 2026-10-06). So an edit made by any other
# way, through the shell or by hand outside Claude Code, leaves no mark: the
# hook sees the tools it is registered for, and never reads a shell command
# for what it might write.
#
# A file of its own rather than a field of the gate's record of the session:
# the edit hook writes it in the middle of a turn, while the gate may be
# reading and rewriting that record, which would then put back the record it
# read and lose the mark — the race the wait's mark avoids the same way.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_OWED:-}" ] || return 0
STAND_IN_LOADED_OWED=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/prompts.sh"

# The marks' folder inside the stand-in's working folder.
OWED_SUBFOLDER="owed"

# The stand-in's model list: which model does each reading job, and how long
# it may take.
OWED_MODELS_FILE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/jobs.sh"

# What a mark must be to be read: the files edited, and when the last edit was
# noted, to the nanosecond. The time is what tells an exam that an edit came
# in while it ran: every note rewrites it, even of a file already listed.
OWED_SHAPE='
  type == "object"
  and (.files | type == "array" and all(.[]; type == "string"))
  and (.noted | type == "string")'

# --- Transforms.

# The mark file for a session, from the stand-in's working folder.
to_owed_path() {
  printf '%s/%s/%s\n' "$1" "$OWED_SUBFOLDER" "$2"
}

# True if the path given lies at or under one of the paths given after it,
# every one canonical, as get_canonical_path gives them.
is_judgement_path() {
  local path="$1" judged
  shift
  for judged in "$@"; do
    [ "$path" != "$judged" ] || return 0
    [[ "$path" != "$judged"/* ]] || return 0
  done
  return 1
}

# The mark with the file given noted, at the time given: the file listed
# once, whatever came before, and the time the latest. The mark given may be
# empty, for a session that owed nothing yet.
with_owed_file() {
  jq -cn --argjson mark "${1:-null}" --arg file "$2" --arg noted "$3" \
    '{files: ((($mark // {}).files // []) + [$file] | unique), noted: $noted}'
}

# The files a mark lists, one line each as the agent is shown them.
format_owed_files() {
  local file files
  files="$(jq -r '.files[]' <<<"$1")" || return 1
  while IFS= read -r file; do
    [ -n "$file" ] || continue
    owed_file_line "$file"
  done <<<"$files"
}

# --- Reads.

# A path made canonical: absolute, every link and every "." or ".." resolved,
# whether or not it exists yet. A file written for the first time is an edit
# too.
get_canonical_path() {
  realpath -m -- "$1"
}

# What the stand-in judges by, given the preset's folder: the preset, the
# prompts' folder and the model list, each canonical, one a line.
list_judgement_paths() {
  get_canonical_path "$1"
  get_canonical_path "$PROMPTS_DIR"
  get_canonical_path "$OWED_MODELS_FILE"
}

# The time an edit is noted at, in UTC, to the nanosecond.
get_owed_now() {
  date -u +%Y-%m-%dT%H:%M:%S.%NZ
}

# The session's mark, compact, where one stands; nothing where none does, the
# folder missing included, which is the state of every session that edited
# nothing the stand-in judges by. One that cannot be read, or is not a mark,
# is refused on stderr with a non-zero status: an exam owed read as none would
# let a change through unexamined.
find_owed_mark() {
  local file mark
  file="$(to_owed_path "$1" "$2")"
  [ -e "$file" ] || return 0
  if ! mark="$(jq -ce "select($OWED_SHAPE)" "$file" 2>/dev/null)" || [ -z "$mark" ]; then
    refuse_owed_unreadable_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$mark"
}

# --- Writes.

# Put a session's mark in place, through a hidden draft moved over any mark
# before it, so nobody reads half of one. Two edits noted at once, from tools
# Claude Code runs side by side, may each put back the mark it read, and one
# file then goes unlisted; the mark itself stands either way, which is all
# the gate and the reminder ask of it. A mark that cannot be written is
# refused on stderr with a non-zero status.
write_owed_mark() {
  local file dir draft
  file="$(to_owed_path "$1" "$2")"
  dir="$(dirname "$file")"
  draft="$dir/.$(basename "$file").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { printf '%s\n' "$3" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$file" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_owed_unwritable_note "$dir" >&2
    return 1
  fi
}

# Remove a session's mark. A session with none is no failure. A mark that
# stands and cannot be removed is refused on stderr with a non-zero status:
# left standing, it would send the session's reports back after the exam
# passed, or outlive the session.
remove_owed_mark() {
  local file
  file="$(to_owed_path "$1" "$2")"
  rm -f "$file" 2>/dev/null && [ ! -e "$file" ] && return 0
  refuse_owed_unremovable_note "$file" >&2
  return 1
}
