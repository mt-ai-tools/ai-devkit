#!/usr/bin/env bash
# Where the conventions collection lives, and which files count as entries — in
# one place, so the stages cannot drift on either. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"

# Where the collection lives is the project's to say, through the kit's
# config; the default is a folder under the project root. This is the one
# place in the injector that asks: everything else is handed the result. A
# default folder that is missing comes back all the same, and the pointer
# stays silent over it; a config file the reader refuses fails this lookup
# with the reader's own reason, and a caller must let that failure end it.
conventions_dir() {
	get_config_path AIDK_CONVENTIONS
}

# True if the directory holds any entries at all. An empty one is a collection
# that has not been started yet, and pointing an agent at it would promise
# conventions that aren't there.
has_convention_entries() {
	collection_has_entries "$1"
}
