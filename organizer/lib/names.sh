#!/usr/bin/env bash
# What counts as a brief's name, a level's name and a session's id, in one
# place. Sourced, never executed.
#
# All three reach file paths: a brief's name is its file in its level folder
# and its mark in the marks folder, a level's name is a folder inside the
# briefs folder, and a session id is written into a mark. A name holding a
# slash or a dot could address a file outside any of them (`../x`), so every
# name is checked here before any path is built from it, and anything else is
# refused rather than cleaned up.
. "$(dirname "${BASH_SOURCE[0]}")/levels.sh"

# True if the value is a brief's name: lower-case letters, digits and hyphens,
# not starting with a hyphen, so it can never be read as an option either.
is_brief_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# True if the value is one of the levels, exactly. A level handed in as text
# takes part in building a path, as a brief's name does, so `../x` must never
# get that far; and only the kit's own names pass, so a typo such as
# `p2-requried` is refused rather than made into a fifth level.
is_level_name() {
  local level
  for level in "${BRIEF_LEVEL_NAMES[@]}"; do
    [ "$level" = "$1" ] && return 0
  done
  return 1
}

# True if the value is a level a draft may lie in, exactly.
is_draft_level_name() {
  local level
  for level in "${DRAFT_LEVEL_NAMES[@]}"; do
    [ "$level" = "$1" ] && return 0
  done
  return 1
}

# True if the value is a session id as the agent's host hands it out: letters,
# digits and hyphens. Nothing else may land in a mark's session line, since
# the mark is read back line by line.
is_session_id() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]]
}
