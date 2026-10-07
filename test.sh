#!/usr/bin/env bash
# The kit's whole suite, as its test command runs it. Given test files or
# folders, it runs only those: while a step is built only the files it
# touches run, and the whole suite once, at the step's end.
#
# Tests run side by side, as many at once as the kit's runner allows, where
# GNU parallel is installed, which bats needs for --jobs, and one at a time
# where it is not, so a project without it still runs the kit's tests. Bats
# runs them itself, so only the count and the finding of the program are the
# runner's.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/lib/runners/side-by-side.sh"
bats="$here/node_modules/.bin/bats"

if [ "$#" -eq 0 ]; then
  set -- "$here/injector/tests" "$here/lib/tests" "$here/organizer/tests" "$here/stand-in/tests"
fi

program="$(find_side_by_side_program)"
if [ -n "$program" ]; then
  exec "$bats" --jobs "$SIDE_BY_SIDE_JOBS" "$@"
fi
exec "$bats" "$@"
