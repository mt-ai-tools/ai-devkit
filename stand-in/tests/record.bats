bats_require_minimum_version 1.5.0

# Behavior tests for the gate's record of a session: read back as written,
# empty where there is none, refused where it is not one the gate wrote, and
# never left half-written.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/record.sh"
  file="$(to_record_path "$project/aidk-stand-in" session-1)"
}

teardown() {
  [ ! -d "$project/aidk-stand-in/sessions" ] || chmod u+rwx "$project/aidk-stand-in/sessions"
}

@test "a record written is read back, and no draft is left beside it" {
  record="$(with_send_back "$EMPTY_RECORD")"
  write_session_record "$file" "$record"
  run read_session_record "$file"
  [ "$status" -eq 0 ]
  [ "$output" = "$record" ]
  [ "$(ls -A "$(dirname "$file")")" = "session-1.json" ]
}

@test "a session with no record reads as the empty one" {
  run read_session_record "$file"
  [ "$status" -eq 0 ]
  [ "$output" = "$EMPTY_RECORD" ]
}

@test "a record that is not one the gate writes is refused" {
  mkdir -p "$(dirname "$file")"
  for text in 'not json' '{"sent_back":-1,"challenge":null}' '{"sent_back":0,"challenge":"x"}'; do
    printf '%s\n' "$text" >"$file"
    run --separate-stderr read_session_record "$file"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_state_unreadable_note "$file")" ]
  done
}

@test "a record that cannot be written is refused, and leaves nothing behind" {
  mkdir -p "$(dirname "$file")"
  chmod a-w "$(dirname "$file")"
  run --separate-stderr write_session_record "$file" "$EMPTY_RECORD"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_state_unwritable_note "$(dirname "$file")")" ]
  [ -z "$(ls -A "$(dirname "$file")")" ]
}

@test "every decision reopened is marked once, kept through a question let go, and taken off first to last" {
  record="$(with_reopened "$(with_send_back "$EMPTY_RECORD")" 7)"
  record="$(with_reopened "$(with_reopened "$record" 4)" 7)"
  [ "$(jq -c '.reopened' <<<"$record")" = '[7,4]' ]
  [ "$(to_reopened "$record")" = 7 ]
  record="$(with_chain_reset "$record")"
  [ "$(to_reopened "$record")" = 7 ]
  record="$(without_first_reopened "$record")"
  [ "$(to_reopened "$record")" = 4 ]
  [ "$(without_first_reopened "$record")" = "$EMPTY_RECORD" ]
  [ -z "$(to_reopened "$EMPTY_RECORD")" ]
  mkdir -p "$(dirname "$file")"
  for reopened in '"7"' '[]' '["7"]'; do
    jq -c --argjson reopened "$reopened" '.reopened = $reopened' <<<"$EMPTY_RECORD" >"$file"
    run --separate-stderr read_session_record "$file"
    [ "$status" -eq 1 ]
  done
}

@test "a record is removed, none is no failure, and one that cannot be removed is refused" {
  write_session_record "$file" "$EMPTY_RECORD"
  run remove_session_record "$file"
  [ "$status" -eq 0 ]
  [ ! -e "$file" ]
  run remove_session_record "$file"
  [ "$status" -eq 0 ]
  write_session_record "$file" "$EMPTY_RECORD"
  chmod a-w "$(dirname "$file")"
  run --separate-stderr remove_session_record "$file"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_state_unremovable_note "$file")" ]
  [ -f "$file" ]
}

@test "a ladder holds its question, kind, lines, first answer and each pick, and ends any challenge" {
  record="$(with_challenge "$EMPTY_RECORD" '{"name":"naming"}' 1 "$(whole_form)" '{}')"
  record="$(with_ladder "$record" "Five retries or ten?" defaults ladder "- kept" '{"options":["five","ten"],"recommended":"five"}')"
  record="$(with_ladder_pick "$record" '{"pick":"item","item":"ten"}')"
  [ "$(jq -c '.challenge' <<<"$record")" = null ]
  run to_ladder "$record"
  [ "$status" -eq 0 ]
  [ "$output" = '{"question":"Five retries or ten?","kind":"defaults","route":"ladder","lines":"- kept","first":{"options":["five","ten"],"recommended":"five"},"picks":[{"pick":"item","item":"ten"}]}' ]
}

@test "a ladder is let go with the question, and a record holding a broken one is refused" {
  record="$(with_ladder "$(with_send_back "$EMPTY_RECORD")" "Five retries or ten?" defaults ladder "" '{}')"
  [ -z "$(to_ladder "$(with_chain_reset "$record")")" ]
  mkdir -p "$(dirname "$file")"
  jq -c '.ladder = {first: {}, picks: "five"}' <<<"$EMPTY_RECORD" >"$file"
  run --separate-stderr read_session_record "$file"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_state_unreadable_note "$file")" ]
}

@test "the send-backs are spent only at the limit" {
  record="$EMPTY_RECORD"
  for _ in $(seq 1 $((SEND_BACK_LIMIT - 1))); do record="$(with_send_back "$record")"; done
  # Run and its status read, never a negated command: bats does not fail a
  # test on a negated command that is not its last.
  run is_send_back_spent "$record"
  [ "$status" -eq 1 ]
  run is_send_back_spent "$(with_send_back "$record")"
  [ "$status" -eq 0 ]
}

@test "a fixed round is awaited, noted as sent, never counted, and let go with the question" {
  record="$(with_round "$EMPTY_RECORD" plain-retelling)"
  [ "$(to_round "$record")" = plain-retelling ]
  run is_round_sent "$record" plain-retelling
  [ "$status" -eq 0 ]
  run is_round_sent "$record" bigger-look
  [ "$status" -eq 1 ]
  [ "$(jq '.sent_back' <<<"$record")" -eq 0 ]
  record="$(with_chain_reset "$record")"
  [ -z "$(to_round "$record")" ]
  run is_round_sent "$record" plain-retelling
  [ "$status" -eq 1 ]
}

@test "the exchange keeps each turn whole and in order, and the question as asked and the waiting message are kept" {
  long="$(printf 'line %s\n' $(seq 1 20000))"
  record="$(with_turn "$EMPTY_RECORD" "$EXCHANGE_AGENT" "$long")"
  record="$(with_turn "$record" "$EXCHANGE_STAND_IN" "From the stand-in: Sure?")"
  record="$(with_asked "$record" "$(whole_form)")"
  record="$(with_operator "$record" '{"question":"Five retries or ten?"}')"
  [ "$(jq -r '.[0].text' <<<"$(to_exchange "$record")")" = "$long" ]
  [ "$(jq -c '[.[] | .from]' <<<"$(to_exchange "$record")")" = '["agent","stand-in"]' ]
  [ "$(to_asked "$record")" = '{"question":"Five retries or ten?","options":["five","ten"],"recommended":"five"}' ]
  [ "$(to_operator_parts "$record")" = '{"question":"Five retries or ten?"}' ]
  write_session_record "$file" "$record"
  [ "$(read_session_record "$file")" = "$record" ]
  [ "$(with_chain_reset "$record")" = "$EMPTY_RECORD" ]
}

@test "a closing round holds its briefs and every look's findings, and is let go with the question" {
  record="$(with_closing "$EMPTY_RECORD" '["file-trash"]')"
  record="$(with_closing_findings "$record" '[{"finding":"a"}]')"
  record="$(with_closing_findings "$record" '[{"finding":"b"}]')"
  [ "$(to_closing "$record")" = '{"briefs":["file-trash"],"findings":[{"finding":"a"},{"finding":"b"}]}' ]
  record="$(with_closing_finished "$record" $'/p/aidk-plans/file-trash.md\n/p/aidk-plans/waiter.md\n')"
  [ "$(jq -r '.finished' <<<"$(to_closing "$record")")" = $'/p/aidk-plans/file-trash.md\n/p/aidk-plans/waiter.md' ]
  record="$(with_closing_cases "$record" '{"written":2,"skipped":1,"held":1,"failed":0}')"
  [ "$(jq -c '.cases' <<<"$(to_closing "$record")")" = '{"written":2,"skipped":1,"held":1,"failed":0}' ]
  mkdir -p "$(dirname "$file")"
  write_session_record "$file" "$record"
  [ "$(read_session_record "$file")" = "$record" ]
  [ "$(with_chain_reset "$record")" = "$EMPTY_RECORD" ]
  [ -z "$(to_closing "$EMPTY_RECORD")" ]
}

@test "a record holding a broken closing round is refused" {
  mkdir -p "$(dirname "$file")"
  for closing in '{"briefs": "file-trash", "findings": []}' '{"briefs": [], "findings": [], "finished": ["x"]}' \
    '{"briefs": [], "findings": [], "cases": {"written": 1}}' \
    '{"briefs": [], "findings": [], "cases": {"written": -1, "skipped": 0, "held": 0, "failed": 0}}'; do
    jq -c --argjson closing "$closing" '.closing = $closing' <<<"$EMPTY_RECORD" >"$file"
    run --separate-stderr read_session_record "$file"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_state_unreadable_note "$file")" ]
  done
}

@test "the wait a session woke from is kept through a question let go, and let go itself" {
  mark='{"outcome":"over","kind":"brief","on":"media-bucket","why":""}'
  record="$(with_resumed "$(with_send_back "$EMPTY_RECORD")" "$mark")"
  [ "$(to_resumed "$record")" = '{"kind":"brief","on":"media-bucket"}' ]
  record="$(with_chain_reset "$record")"
  [ "$(to_resumed "$record")" = '{"kind":"brief","on":"media-bucket"}' ]
  record="$(without_resumed "$record")"
  [ -z "$(to_resumed "$record")" ]
  mkdir -p "$(dirname "$file")"
  jq -c '.resumed = "media-bucket"' <<<"$EMPTY_RECORD" >"$file"
  run --separate-stderr read_session_record "$file"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_state_unreadable_note "$file")" ]
}

@test "a record is idle only while nothing is in flight" {
  is_record_idle "$EMPTY_RECORD"
  is_record_idle "$(with_resumed "$EMPTY_RECORD" '{"kind":"brief","on":"x"}')"
  ! is_record_idle "$(with_round "$EMPTY_RECORD" plain-retelling)"
  ! is_record_idle "$(with_ladder "$EMPTY_RECORD" "Five or ten?" defaults ladder "" '{"options":["five","ten"],"recommended":"five"}')"
  ! is_record_idle "$(jq -c '.challenge = {} | .operator = null' <<<"$EMPTY_RECORD")"
  ! is_record_idle "$(with_operator "$EMPTY_RECORD" '{"question":"Five or ten?"}')"
}
