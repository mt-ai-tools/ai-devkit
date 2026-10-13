#!/usr/bin/env bash
# Every word the builder's tools hand their reader, in one place, so the suite
# asserts the wiring rather than the wording. Sourced, never executed.

break_check_usage_note() {
  printf 'usage: break-check.sh <file> <old text> <new text> <test name> -- <test command> [<argument>...]\n'
}

# The proof held: the break made the named test fail.
break_check_red_note() {
  printf 'red: %s failed with %s broken\n' "$1" "$2"
}

# The command passed with the break in place: the test catches nothing there.
break_check_green_note() {
  printf 'not red: the command passed with %s broken, so "%s" does not catch this break\n' "$1" "$2"
}

# The command failed, but not by the named test failing: a build or type error,
# or another test, which proves nothing about the one named.
break_check_other_failure_note() {
  printf 'not red: the command failed with %s broken, but no failing test line names "%s" — a build or type error, or another test, proves nothing about it; its last lines:\n' "$1" "$2"
}

break_check_missing_file_note() {
  printf 'refused: %s is not a file\n' "$1"
}

break_check_old_text_count_note() {
  printf 'refused: the old text is found %s times in %s; it must be found exactly once\n' "$2" "$1"
}

break_check_empty_old_text_note() {
  printf 'refused: the old text is empty\n'
}

break_check_restore_failed_note() {
  printf 'RESTORE FAILED: %s differs from what it held before the break; its copy is at %s\n' "$1" "$2"
}

# The session has grown past the size worth compacting at a clean point.
session_size_compact_note() {
  printf 'compact: %s tokens\n' "$1"
}

session_size_fine_note() {
  printf 'fine: %s tokens\n' "$1"
}

session_size_no_session_note() {
  printf 'refused: no session id in %s, so there is no transcript to read\n' "$1"
}

session_size_no_transcript_note() {
  printf 'refused: no transcript for session %s under %s\n' "$1" "$2"
}

session_size_usage_note() {
  printf 'usage: session-size.sh [<transcript>]\n'
}
