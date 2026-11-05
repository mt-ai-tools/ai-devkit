#!/usr/bin/env bash
# Whether a test command's run shows the named test failing, read from what
# it printed. Sourced, never executed.
#
# A failing command is not yet a failing test: a break that stops the code
# compiling fails every test file at once, or the build before them, and
# proves nothing about the one test it was aimed at. So a break counts only
# where a line the test runner prints for a failed test names that test, or,
# for a test named by its file and line, where a type error stands at that line.

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

# A test named by where it stands rather than what it is called: a TypeScript
# test file, a colon, and a line. A type-level test breaks only as a type error
# at its own line, and no runner prints a failed-test line for it.
BREAK_CHECK_PLACE_SHAPE='^.+\.(ts|tsx|mts|cts):[0-9]+$'

# Succeeds where a line of the output, read on stdin, is a TypeScript
# diagnostic, "<path>(<line>,<column>): error TS<number>", at the named test
# file's own line. The path must end with the test file at a folder boundary,
# compared as plain text: a type error anywhere else stops the build, which
# proves nothing about this test.
names_type_error_at() {
  awk -v file="$1" -v line="$2" '
    function bare(path) {
      sub(/^[[:space:]]+/, "", path)
      while (substr(path, 1, 2) == "./") path = substr(path, 3)
      return path
    }
    BEGIN { file = bare(file) }
    match($0, /\([0-9]+,[0-9]+\): error TS[0-9]+/) {
      path = bare(substr($0, 1, RSTART - 1))
      at = substr($0, RSTART + 1)
      at = substr(at, 1, index(at, ",") - 1)
      tail = length(path) - length(file)
      if (at + 0 == line + 0 && tail >= 0 && substr(path, tail + 1) == file &&
          (tail == 0 || substr(path, tail, 1) == "/")) found = 1
    }
    END { exit found ? 0 : 1 }
  '
}

# Succeeds where the output, read on stdin, shows the named test failing: by a
# type error at its place where it is named as one, else by a failed-test line.
shows_test_failing() {
  if [[ "$1" =~ $BREAK_CHECK_PLACE_SHAPE ]]; then
    names_type_error_at "${1%:*}" "${1##*:}"
  else
    names_failed_test "$1"
  fi
}
