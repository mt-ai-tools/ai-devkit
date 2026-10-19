bats_require_minimum_version 1.5.0

# Behavior tests for the break check: a break made and run, read as red only
# where the runner's failed-test line names the test, and the file always put
# back byte for byte — after a red, a pass, a failure of another kind, and an
# interruption — while every refusal leaves the file alone and runs nothing.

setup() {
  script="$BATS_TEST_DIRNAME/../bin/break-check.sh"
  . "$BATS_TEST_DIRNAME/../lib/words.sh"
  cd "$BATS_TEST_TMPDIR"
  target="$BATS_TEST_TMPDIR/code.txt"
  printf 'answer = 42\nother = 1\n' >"$target"
  chmod 640 "$target"
  cp -p "$target" "$BATS_TEST_TMPDIR/before"
  ran="$BATS_TEST_TMPDIR/ran"
}

# A stand-in test command: records that it ran, then prints what it is handed
# and ends with the status handed — whatever the file now holds.
command_saying() {
  local status="$1" said="$2"
  printf '#!/usr/bin/env bash\ntouch "%s"\nprintf "%%s\\n" "%s"\nexit %s\n' "$ran" "$said" "$status" >"$BATS_TEST_TMPDIR/test-command"
  chmod +x "$BATS_TEST_TMPDIR/test-command"
}

# A stand-in that fails only where the break stands, as a real test would.
command_catching_break() {
  printf '#!/usr/bin/env bash\nif grep -q "answer = 0" "%s"; then printf "not ok 1 %s\\n"; exit 1; fi\nprintf "ok 1 %s\\n"\n' "$target" "$1" "$1" >"$BATS_TEST_TMPDIR/test-command"
  chmod +x "$BATS_TEST_TMPDIR/test-command"
}

check() {
  run --separate-stderr "$script" "$target" "answer = 42" "answer = 0" "$1" -- "$BATS_TEST_TMPDIR/test-command"
}

file_untouched() {
  cmp -s "$target" "$BATS_TEST_TMPDIR/before" && [ -n "$(find "$target" -perm 640)" ]
}

@test "a break the named test catches is red, and the file is put back" {
  command_catching_break "the answer is kept"
  check "the answer is kept"
  [ "$status" -eq 0 ]
  [ "$output" = "$(break_check_red_note "the answer is kept" "$target")" ]
  file_untouched
}

@test "a break the command passes with is not red, and the file is put back" {
  command_saying 0 "all passed"
  check "the answer is kept"
  [ "$status" -eq 1 ]
  [ "$output" = "$(break_check_green_note "$target" "the answer is kept")" ]
  file_untouched
}

@test "a command failing with no failed-test line naming the test is not red, and shows its last lines" {
  command_saying 1 "error TS2345: the build broke"
  check "the answer is kept"
  [ "$status" -eq 1 ]
  [ "${lines[0]}" = "$(break_check_other_failure_note "$target" "the answer is kept")" ]
  [ "${lines[1]}" = "error TS2345: the build broke" ]
  file_untouched
}

@test "another test failing is not red for the one named" {
  command_saying 1 "not ok 3 some other test"
  check "the answer is kept"
  [ "$status" -eq 1 ]
  file_untouched
}

@test "a failed-test line from vitest is read as red" {
  command_saying 1 "   × suite > the answer is kept 3ms"
  check "the answer is kept"
  [ "$status" -eq 0 ]
}

@test "a failed-test line from vitest's summary is read as red" {
  command_saying 1 " FAIL  src/code.test.ts > suite > the answer is kept"
  check "the answer is kept"
  [ "$status" -eq 0 ]
}

@test "a failed-test line from playwright is read as red" {
  command_saying 1 "  ✘  1 [chromium] › case.ts › the answer is kept"
  check "the answer is kept"
  [ "$status" -eq 0 ]
}

@test "the name is read as plain text, never as a pattern" {
  command_saying 1 "not ok 1 answerXkept"
  check "answer.kept"
  [ "$status" -eq 1 ]
}

@test "the file is put back when the run is interrupted" {
  printf '#!/usr/bin/env bash\ngrep -q "answer = 0" "%s" && touch "%s"\nkill -TERM "$PPID"\nsleep 1\n' "$target" "$ran" >"$BATS_TEST_TMPDIR/test-command"
  chmod +x "$BATS_TEST_TMPDIR/test-command"
  check "the answer is kept"
  [ "$status" -ne 0 ]
  [ -e "$ran" ]
  file_untouched
}

@test "the file is put back newer than a build made while the break stood" {
  touch -t 200001010000 "$target"
  cp -p "$target" "$BATS_TEST_TMPDIR/before"
  built="$BATS_TEST_TMPDIR/built"
  # Fixed dates, the build's after the file's: the clock ticks coarser than a
  # run, so a build stamped now could share the restore's time and -nt flake.
  printf '#!/usr/bin/env bash\ncp "%s" "%s"\ntouch -t 200101010000 "%s"\nexit 0\n' "$target" "$built" "$built" >"$BATS_TEST_TMPDIR/test-command"
  chmod +x "$BATS_TEST_TMPDIR/test-command"
  check "the answer is kept"
  grep -q "answer = 0" "$built"
  [ "$target" -nt "$built" ]
  file_untouched
}

@test "the old and new text are taken as plain text, newlines and replacement marks included" {
  printf 'a & b/c\nend\n\n' >"$target"
  cp -p "$target" "$BATS_TEST_TMPDIR/before"
  printf '#!/usr/bin/env bash\ncp "%s" "%s/seen"\nexit 0\n' "$target" "$BATS_TEST_TMPDIR" >"$BATS_TEST_TMPDIR/test-command"
  chmod +x "$BATS_TEST_TMPDIR/test-command"
  run "$script" "$target" $'a & b/c\nend' $'x & \\1\nend' "a test" -- "$BATS_TEST_TMPDIR/test-command"
  [ "$(cat "$BATS_TEST_TMPDIR/seen"; printf x)" = $'x & \\1\nend\n\nx' ]
  cmp -s "$target" "$BATS_TEST_TMPDIR/before"
}

@test "old text found twice is refused, and nothing runs" {
  printf 'answer = 42\nanswer = 42\n' >"$target"
  cp -p "$target" "$BATS_TEST_TMPDIR/before"
  command_saying 0 "ran"
  check "the answer is kept"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(break_check_old_text_count_note "$target" 2)" ]
  [ ! -e "$ran" ]
  cmp -s "$target" "$BATS_TEST_TMPDIR/before"
}

@test "old text not found is refused, and nothing runs" {
  command_saying 0 "ran"
  run --separate-stderr "$script" "$target" "nowhere" "x" "a test" -- "$BATS_TEST_TMPDIR/test-command"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(break_check_old_text_count_note "$target" 0)" ]
  [ ! -e "$ran" ]
  file_untouched
}

@test "a missing file is refused" {
  command_saying 0 "ran"
  run --separate-stderr "$script" "$BATS_TEST_TMPDIR/absent" "a" "b" "a test" -- "$BATS_TEST_TMPDIR/test-command"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(break_check_missing_file_note "$BATS_TEST_TMPDIR/absent")" ]
  [ ! -e "$ran" ]
}

@test "a call without the command after -- is refused with the usage" {
  run --separate-stderr "$script" "$target" "answer = 42" "answer = 0" "a test"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(break_check_usage_note)" ]
  file_untouched
}
