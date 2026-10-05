bats_require_minimum_version 1.5.0

# Behavior tests for asking a model: the answer comes back as the structured
# output alone, the call runs with hooks off and no tools unless some are
# given, and every way the call can fail is a refusal naming why. Claude Code is the suite's own fake.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/ask-model.sh"
  schema='{"type":"object"}'
}

@test "the model's structured answer comes back as one line" {
  export FAKE_ANSWER='{"colour": "blue"}'
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$status" -eq 0 ]
  [ "$output" = '{"colour":"blue"}' ]
  [ "$(cat "$FAKE_PROMPT")" = "Which colour?" ]
}

@test "the call runs fresh, hooks off, no tools, on the model and schema given" {
  export FAKE_ANSWER='{}'
  get_model_answer some-model 10 "$schema" <<<"Which colour?" >/dev/null
  args="$(paste -sd ' ' "$FAKE_ARGS")"
  [[ "$args" == *"-p "* ]]
  [[ "$args" == *"--model some-model "* ]]
  [[ "$args" == *'--settings {"disableAllHooks":true} '* ]]
  [[ "$args" == *"--safe-mode "* ]]
  [[ "$args" == *"--tools  "* ]]
  [[ "$args" == *"--output-format json "* ]]
  [[ "$args" == *"--json-schema $schema"* ]]
}

@test "the tools given are the only ones the call may use" {
  export FAKE_ANSWER='{}'
  get_model_answer some-model 10 "$schema" "Read,Grep" <<<"Which colour?" >/dev/null
  args="$(paste -sd ' ' "$FAKE_ARGS")"
  [[ "$args" == *"--tools Read,Grep "* ]]
}

@test "a call past its time limit is refused as a timeout" {
  export FAKE_ANSWER='{}' FAKE_SLEEP=5
  run --separate-stderr get_model_answer some-model 1 "$schema" <<<"Which colour?"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_model_timeout_note some-model 1)" ]
}

@test "Claude Code stopping with an error status is refused with the status" {
  export FAKE_ANSWER='{}' FAKE_STATUS=3
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_model_exit_note some-model 3)" ]
}

@test "an envelope marked as an error is refused, whatever it holds" {
  export FAKE_ENVELOPE='{"type":"result","is_error":true,"structured_output":{"colour":"blue"}}'
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_model_error_note some-model)" ]
}

@test "output that is not an envelope, or holds no structured answer, is refused" {
  for envelope in 'not json' '{"type":"result","is_error":false,"result":"{\"colour\":\"blue\"}"}' \
    '{"type":"result","is_error":false,"structured_output":"blue"}'; do
    export FAKE_ENVELOPE="$envelope"
    run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_model_unreadable_note some-model)" ]
  done
}
