#!/usr/bin/env bash
# Where the conventions collection lives, and which files count as entries — in
# one place, so the stages cannot drift on either. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/collection.sh"

# The collection sits at a fixed place under the project root — the kit's
# README states it, and nothing declares it a second time. The root is the one
# the hook is run for; on a machine with no such variable set, the working
# directory stands in.
conventions_dir() {
	printf '%s/conventions' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# True if the directory holds any entries at all. An empty one is a collection
# that has not been started yet, and pointing an agent at it would promise
# conventions that aren't there.
has_convention_entries() {
	collection_has_entries "$1"
}
