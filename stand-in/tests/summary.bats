bats_require_minimum_version 1.5.0

# Behavior tests for the summary reader: asked on its own model, handed the
# whole exchange in order under who wrote each turn, answering in the
# message's fixed parts, and refused where its answer does not pass. Claude Code is the suite's own fake.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/summary.sh"
  exchange='[{"from":"agent","text":"Five retries or ten? I recommend five."},{"from":"stand-in","text":"From the stand-in: Sure?"},{"from":"agent","text":"Yes, five."}]'
}

@test "the summary is written from the whole exchange, each turn under who wrote it, in order" {
  answer_for summary "$(summary_form)"
  run get_summary "$exchange"
  [ "$status" -eq 0 ]
  [ "$output" = "$(summary_form)" ]
  [ "$(calls)" = "summary $SUMMARY_MODEL" ]
  turns="$(grep -xF -e "$SUMMARY_AGENT_MARKER" -e "$SUMMARY_STAND_IN_MARKER" \
    -e "Five retries or ten? I recommend five." -e "From the stand-in: Sure?" -e "Yes, five." "$FAKE_PROMPT.summary")"
  [ "$turns" = "$SUMMARY_AGENT_MARKER
Five retries or ten? I recommend five.
$SUMMARY_STAND_IN_MARKER
From the stand-in: Sure?
$SUMMARY_AGENT_MARKER
Yes, five." ]
}

@test "a summary missing a part, or with a part of no words, is refused, and a model that stopped too" {
  answer_for summary "$(jq -c 'del(.what_moved_it)' <<<"$(summary_form)")"
  run --separate-stderr get_summary "$exchange"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_missing_field_note "$(summary_answer_words)" what_moved_it)" ]
  answer_for summary "$(jq -c '.operators_call = " "' <<<"$(summary_form)")"
  run --separate-stderr get_summary "$exchange"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_summary_part_empty_note operators_call)" ]
  status_for summary 3
  run --separate-stderr get_summary "$exchange"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_model_exit_note "$SUMMARY_MODEL" 3)" ]
}
