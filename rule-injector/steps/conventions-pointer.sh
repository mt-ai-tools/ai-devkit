#!/usr/bin/env bash
# Name where the project's conventions live, so an agent follows the written
# ones instead of rediscovering or reinventing them. The location only — the
# entries are read when a decision actually needs one, which is why this costs
# three lines a turn instead of the collection's full text.
#
# Silent when nothing is configured. A project without a collection has nothing
# to point at, and a line saying so every turn is noise, not policy.
#
# Usage: <conventions-dir>
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/lib/conventions-dir.sh"

has_convention_entries "${1:-}" || exit 0

echo
echo "Written conventions live in: $1"
echo "Read the entry that covers what you are shaping before you shape it."
