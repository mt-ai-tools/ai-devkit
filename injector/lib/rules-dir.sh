#!/usr/bin/env bash
# Where the rules live and which files count as rules — in one place, so the
# stages cannot drift on either. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/config.sh"

# Where the rules live is the project's to say, through the kit's config: a
# project may bring its own rulebook, and the one the kit ships is a preset it
# falls back on, not a part of its machinery. Unlike other folders the kit
# reads, the rules are required, so a missing one is not made silent here: the
# path is handed on all the same, and the digest refuses the turn over it. A
# config file the reader refuses fails this lookup, with the reader's own
# reason already on stderr; a caller must let that failure end it, or the
# operator is shown the wrong reason.
rules_dir() {
  get_config_path AIDK_RULES
}

# True if the directory holds any rule files at all.
has_rule_files() {
  collection_has_entries "$1"
}

# Every rule file in the directory, one path per line.
list_rule_files() {
  list_collection_entries "$1"
}
