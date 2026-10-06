#!/usr/bin/env bash
# The kit's whole suite, as its test command runs it. Given test files or
# folders, it runs only those: while a step is built only the files it
# touches run, and the whole suite once, at the step's end.
#
# Tests run eight at a time where GNU parallel is installed, which bats needs
# for --jobs, and one at a time where it is not, so a project without it still
# runs the kit's tests. Measured 2026-10-06: 394 tests took about 9 minutes one
# at a time and 102 seconds eight at a time. Eight, not every thread a machine
# has: a full load on every thread is not what the suite needs, and on the
# kit's first machine it is untested and the first suspect for a shutdown.
set -euo pipefail

TEST_JOBS=8

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
bats="$here/node_modules/.bin/bats"

if [ "$#" -eq 0 ]; then
  set -- "$here/injector/tests" "$here/lib/tests" "$here/organizer/tests" "$here/stand-in/tests"
fi

if command -v parallel >/dev/null 2>&1; then
  exec "$bats" --jobs "$TEST_JOBS" "$@"
fi
exec "$bats" "$@"
