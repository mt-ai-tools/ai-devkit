#!/usr/bin/env bash
# Name where the workflow lives, and what each of its files covers, so an
# agent reads the one for the stage it is in rather than working from
# memory of it. One line a file, taken from the file's own header, so the
# index can never drift from what the files say; the files themselves are
# read only when a stage needs one.
#
# The workflow is the kit's own, found from this step's place in the kit,
# never configured. A workflow folder that is missing, or a file in it with
# no description, refuses the turn with the reason on stderr: an index with
# a hole would send an agent working without the stage it is in.
#
# Usage: <workflow-dir>
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/header.sh"
. "$tool_root/lib/refusal.sh"

workflow="$1"
if [ ! -d "$workflow" ]; then
  no_workflow_note "$workflow" >&2
  exit 2
fi

# Listed before printing, so a refusal leaves no half-printed index.
lines=""
while IFS= read -r file; do
  description="$(read_header_fields "$file" description)"
  if [ -z "$description" ]; then
    workflow_file_undescribed_note "$file" >&2
    exit 2
  fi
  lines+="- $(basename "$file") — $description"$'\n'
done < <(LC_ALL=C find "$workflow" -maxdepth 1 -type f -name '*.md' | LC_ALL=C sort)

echo
echo "How work moves, and who decides what, lives in: $workflow"
printf '%s' "$lines"
echo "Read the file for the stage you are in before acting."
