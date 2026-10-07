#!/usr/bin/env bash
# Name where the project's conventions live, so an agent follows the written
# ones instead of rediscovering or reinventing them. The location only — the
# entries are read when a decision actually needs one, which is why this costs
# three lines a turn instead of the collection's full text.
#
# Silent when nothing is configured. A project without a collection has nothing
# to point at, and a line saying so every turn is noise, not policy. A folder
# that is there but cannot be listed is not that: it fails with the reader's
# reason on stderr, since staying silent would drop the conventions from every
# turn with nothing to show why.
#
# Usage: <conventions-dir>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/conventions-dir.sh"

found=0
has_convention_entries "${1:-}" || found=$?
[ "$found" -ne 1 ] || exit 0
[ "$found" -eq 0 ] || exit 2

# The moment named is any of the three, not writing alone: an agent proposing
# or asking about something it has not yet built reads "shaping" as "writing"
# and skips the entry, and the operator then has to answer a question the
# entry had already settled.
echo
echo "Written conventions live in: $1"
echo "Read the entry that covers what you are shaping before you shape it, propose it or ask about it."
