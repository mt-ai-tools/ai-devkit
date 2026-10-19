#!/usr/bin/env bash
# Proves a test catches a break: changes one place in a file, runs the test
# command, and says whether the named test failed — then always puts the file
# back as it was, however the run ended.
#
#   break-check.sh <file> <old text> <new text> <test name> -- <test command> [<argument>...]
#
# The old text must stand in the file exactly once, and is replaced as plain
# text, never as a pattern. Red means a line the test runner prints for a
# failed test names the test: a command that failed only to build proves
# nothing about the test, and is reported as not red with its last lines.
#
# Status: 0 when the named test went red; 1 for anything else — passed,
# failed some other way, or refused. One non-zero status throughout, so
# whatever runs it need tell only a proof from anything else; the line it
# prints says which.
#
# One shared tool rather than a script each builder writes for itself:
# written fresh each time, some counted a build error as red, and a script
# that died half way left the break in place.
set -euo pipefail
shopt -s inherit_errexit

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
. "$here/../lib/words.sh"
. "$here/../lib/verdict.sh"

# How many of the command's last lines a run that was not red shows: enough
# to see a build or type error, not the whole run.
BREAK_CHECK_TAIL_LINES=20

refuse() {
  printf '%s' "$1" >&2
  exit 1
}

if [ "$#" -lt 6 ] || [ "$5" != "--" ]; then
  refuse "$(break_check_usage_note)"$'\n'
fi
file="$1"
old="$2"
new="$3"
name="$4"
shift 5

[ -f "$file" ] || refuse "$(break_check_missing_file_note "$file")"$'\n'
[ -n "$old" ] || refuse "$(break_check_empty_old_text_note)"$'\n'

# Read whole, trailing newlines included: a command substitution drops them,
# so a mark is added after the file and taken off again.
content="$(cat -- "$file"; printf x)"
content="${content%x}"
without="${content//"$old"/}"
count=$(((${#content} - ${#without}) / ${#old}))
[ "$count" -eq 1 ] || refuse "$(break_check_old_text_count_note "$file" "$count")"$'\n'

work="$(mktemp -d)"
copy="$work/original"
cp -p -- "$file" "$copy"

# Puts the file back from its copy on every ending a script can see — done,
# failed, interrupted, terminated, hung up on: bash runs its exit trap on each
# of those signals too, so no trap of their own is set — and says so loudly,
# keeping the copy, where what stands afterwards is not what stood before. A
# kill cannot be caught; the copy then stays in the temporary folder.
restore() {
  cp -p -- "$copy" "$file"
  # Written now, as an undo by hand leaves it: a build tool sees write times,
  # not bytes, and the time the copy carried back would make a build made
  # during the break look fresh, so what links it would test the break.
  touch -- "$file"
  if cmp -s -- "$copy" "$file"; then
    rm -rf -- "$work"
  else
    break_check_restore_failed_note "$file" "$copy" >&2
  fi
}
trap restore EXIT

printf '%s' "${content/"$old"/"$new"}" >"$file"

output="$work/output"
status=0
"$@" >"$output" 2>&1 || status=$?

if [ "$status" -ne 0 ] && names_failed_test "$name" <"$output"; then
  break_check_red_note "$name" "$file"
  exit 0
fi
if [ "$status" -eq 0 ]; then
  break_check_green_note "$file" "$name"
  exit 1
fi
break_check_other_failure_note "$file" "$name"
tail -n "$BREAK_CHECK_TAIL_LINES" "$output"
exit 1
