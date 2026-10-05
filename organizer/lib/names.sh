#!/usr/bin/env bash
# What counts as a brief's name and a session's id, in one place. Sourced,
# never executed.
#
# Both reach file paths: a brief's name is its file in the briefs folder and
# its mark in the marks folder, and a session id is written into a mark. A
# name holding a slash or a dot could address a file outside either folder
# (`../x`), so every name is checked here before any path is built from it,
# and anything else is refused rather than cleaned up.

# True if the value is a brief's name: lower-case letters, digits and hyphens,
# not starting with a hyphen, so it can never be read as an option either.
is_brief_name() {
  [[ "$1" =~ ^[a-z0-9][a-z0-9-]*$ ]]
}

# True if the value is a session id as the agent's host hands it out: letters,
# digits and hyphens. Nothing else may land in a mark's session line, since
# the mark is read back line by line.
is_session_id() {
  [[ "$1" =~ ^[A-Za-z0-9-]+$ ]]
}
