#!/usr/bin/env bash
# Whether a test command's run shows the named test failing, read from what
# it printed. Sourced, never executed.
#
# A failing command is not yet a failing test: a break that stops the code
# compiling fails every test file at once, or the build before them, and
# proves nothing about the one test it was aimed at. So a break counts only
# where a line the test runner prints for a failed test names that test.

# How each runner the kit's projects use marks a failed test on its own line:
# vitest's failure mark and its summary's FAIL, playwright's cross, and the TAP
# "not ok" that bats prints. The runners' own spellings, which are not ours to
# choose; a runner marking failures some other way needs its mark added here.
BREAK_CHECK_FAILURE_MARKS='×|✗|✘|FAIL'
BREAK_CHECK_TAP_FAILURE='^not ok '

# Succeeds where a line of the output, read on stdin, is a failed-test line
# that holds the name. The name is matched as plain text, never as a pattern.
names_failed_test() {
  awk -v name="$1" -v marks="(^|[[:space:]])(${BREAK_CHECK_FAILURE_MARKS})([[:space:]]|$)" -v tap="$BREAK_CHECK_TAP_FAILURE" '
    index($0, name) && ($0 ~ marks || $0 ~ tap) { found = 1 }
    END { exit found ? 0 : 1 }
  '
}
