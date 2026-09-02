#!/usr/bin/env bash
# Where the rules live and which files count as rules — in one place, so the
# stages cannot drift on either. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/collection.sh"

# The rules ship in the sibling tool, so there is nothing to configure: the
# two travel together, and a mount taking one without the other has no rules
# to inject. Resolved to an absolute path because every line that names it is
# read by someone who is not standing where this ran.
rules_dir() {
  local dir="$(dirname "${BASH_SOURCE[0]}")/../../agentic-rules/rules"
  if [ -d "$dir" ]; then (cd "$dir" && pwd); else printf '%s' "$dir"; fi
}

# True if the directory holds any rule files at all.
has_rule_files() {
  collection_has_entries "$1"
}

# Every rule file in the directory, one path per line.
list_rule_files() {
  list_collection_entries "$1"
}
