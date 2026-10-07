bats_require_minimum_version 1.5.0

# Behavior tests for the question log: lines numbered in order and kept whole
# when sessions write at once, the operator's answer written into the right
# line and only once, and a log that cannot be read or written refused.

load fake-claude
load question-log

setup() {
  setup_fake_claude
  . "$lib/question-log.sh"
  history="$project/aidk-stand-in"
  dir="$(to_log_dir "$history")"
  file="$(to_log_path "$dir")"
}

teardown() {
  [ ! -d "$dir" ] || chmod u+rwx "$dir"
}

# A line as the gate would hand it over, unnumbered, padded with the given
# number of bytes of text so it is written in many pieces.
unnumbered() {
  jq -c --arg pad "$(head -c "$2" /dev/zero | tr '\0' "$3")" '.number = null | .exchange[0].text = $pad' \
    <<<"$(log_line 0 "$OUTCOME_TO_OPERATOR" "$1" 2026-10-06T10:00:00Z)"
}

@test "lines are numbered one after the other, the first one" {
  append_log_line "$dir" "$(unnumbered session-1 10 a)"
  append_log_line "$dir" "$(unnumbered session-1 10 a)"
  [ "$(jq -c '.number' "$file" | paste -sd, -)" = "1,2" ]
}

@test "two sessions writing at once leave only whole lines, each with a number of its own" {
  writer() {
    local i line
    line="$(unnumbered "$1" 30000 "$2")"
    for i in $(seq 1 60); do append_log_line "$dir" "$line"; done
  }
  writer session-1 a &
  writer session-2 b &
  wait
  [ "$(wc -l <"$file")" -eq 120 ]
  # Every line parses on its own, and holds one writer's text whole.
  while IFS= read -r line; do
    jq -e '(.exchange[0].text | test("^(a{30000}|b{30000})$"))' >/dev/null <<<"$line"
  done <"$file"
  [ "$(jq -r '.session' "$file" | sort | uniq -c | awk '{print $1}' | paste -sd, -)" = "60,60" ]
  [ "$(jq -r '.number' "$file" | sort -n | uniq | wc -l)" -eq 120 ]
  [ "$(jq -r '.number' "$file" | sort -n | tail -n 1)" -eq 120 ]
}

@test "the answer goes into the session's last line, and every other line is left byte for byte" {
  add_log_lines "$history" \
    "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T10:00:00Z)" \
    "$(log_line 2 "$OUTCOME_TO_OPERATOR" session-2 2026-10-06T10:01:00Z)" \
    "$(log_line 3 "$OUTCOME_WOULD_HAVE_APPROVED" session-1 2026-10-06T10:02:00Z)" \
    "$(log_line 4 "$OUTCOME_TO_OPERATOR" session-2 2026-10-06T10:03:00Z)"
  cp "$file" "$BATS_TEST_TMPDIR/before"
  write_log_answer "$dir" session-1 "Go with five, and say why next time."
  [ "$(jq -r 'select(.number == 3) | .answer' "$file")" = "Go with five, and say why next time." ]
  diff <(sed -n '1p;2p;4p' "$BATS_TEST_TMPDIR/before") <(sed -n '1p;2p;4p' "$file")
  [ "$(sed -n 3p "$file")" = "$(jq -c '.answer = "Go with five, and say why next time."' <<<"$(sed -n 3p "$BATS_TEST_TMPDIR/before")")" ]
}

@test "a question already answered, or settled, takes no answer, and a session with no line changes nothing" {
  add_log_lines "$history" \
    "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T10:00:00Z)" \
    "$(log_line 2 "$OUTCOME_SETTLED" session-2 2026-10-06T10:01:00Z)"
  write_log_answer "$dir" session-1 "Five."
  write_log_answer "$dir" session-1 "Something typed later."
  write_log_answer "$dir" session-2 "Ten."
  write_log_answer "$dir" session-3 "Nobody asked."
  [ "$(jq -r '.answer' "$file" | paste -sd, -)" = "Five.," ]
}

@test "a log holding a torn line is refused whole, and so is an answer written to it" {
  add_log_lines "$history" "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T10:00:00Z)" '{"number":2,"sess'
  run --separate-stderr list_log_lines "$dir"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_log_unreadable_note "$file")" ]
  run --separate-stderr write_log_answer "$dir" session-1 "Five."
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_log_unreadable_note "$file")" ]
}

@test "no log reads as no lines, and a log that cannot be written is refused" {
  run list_log_lines "$dir"
  [ "$status" -eq 0 ]
  [ -z "$output" ]
  mkdir -p "$dir"
  chmod a-w "$dir"
  run --separate-stderr append_log_line "$dir" "$(unnumbered session-1 10 a)"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_log_unwritable_note "$dir")" ]
}

# regression: the draft's redirect came before stderr's, so the shell's own
# "Permission denied" reached the operator ahead of the refusal.
@test "an answer whose log folder cannot be written is refused with the refusal alone, and the log is left as it was" {
  add_log_lines "$history" "$(log_line 1 "$OUTCOME_TO_OPERATOR" session-1 2026-10-06T10:00:00Z)"
  # The lock file stands from an earlier write, as in any log in use.
  list_log_lines "$dir" >/dev/null
  cp "$file" "$BATS_TEST_TMPDIR/before"
  chmod a-w "$dir"
  run --separate-stderr write_log_answer "$dir" session-1 "Five."
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_log_unwritable_note "$dir")" ]
  diff "$BATS_TEST_TMPDIR/before" "$file"
}

@test "a log held by another session past the wait is refused, and nothing is written" {
  mkdir -p "$dir"
  LOG_LOCK_SECONDS=1
  flock -x "$dir/.questions.jsonl.lock" sleep 5 &
  sleep 0.5
  run --separate-stderr append_log_line "$dir" "$(unnumbered session-1 10 a)"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_log_busy_note "$dir" 1)" ]
  [ ! -e "$file" ]
  kill %1 2>/dev/null || true
}
