bats_require_minimum_version 1.5.0

# Behavior tests for asking a model: the answer comes back as the structured
# output alone, the call runs with hooks off and no tools unless some are
# given, and every way the call can fail is a refusal naming why; a refusal
# saying Claude is busy alone is asked again, a few times and inside the
# call's time limit. Claude Code is the suite's own fake.

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

@test "settings given are added to the call's, and can never switch the hooks back on" {
  export FAKE_ANSWER='{}'
  get_model_answer some-model 10 "$schema" "Read" '{"disableAllHooks":false,"permissions":{"deny":["Read(//x/**)"]}}' \
    <<<"Which colour?" >/dev/null
  args="$(paste -sd ' ' "$FAKE_ARGS")"
  [[ "$args" == *'--settings {"disableAllHooks":true,"permissions":{"deny":["Read(//x/**)"]}} '* ]]
}

@test "a standing text given is added to Claude Code's own instructions whole, and the prompt stays the message" {
  export FAKE_ANSWER='{}'
  standing="$(printf 'Every rule.\n\nEvery convention.')"
  get_model_answer some-model 10 "$schema" "" "" "$standing" <<<"Which colour?" >/dev/null
  [ "$(cat "$FAKE_STANDING.other")" = "$standing" ]
  [ "$(cat "$FAKE_PROMPT")" = "Which colour?" ]
  rm "$FAKE_STANDING.other"
  get_model_answer some-model 10 "$schema" <<<"Which colour?" >/dev/null
  [ ! -e "$FAKE_STANDING.other" ]
  [ "$(grep -cxF -- --append-system-prompt-file "$FAKE_ARGS")" -eq 0 ]
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

# The calls the fake was asked, counted.
call_count() {
  calls | wc -l
}

@test "a call refused because Claude is busy or rate-limited is asked again, and the answer comes back" {
  ASK_MODEL_BUSY_WAIT=0
  export FAKE_ANSWER='{"colour": "blue"}'
  refusal_for_call other 1 529
  refusal_for_call other 2 429
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$status" -eq 0 ]
  [ "$output" = '{"colour":"blue"}' ]
  [ "$(call_count)" -eq 3 ]
  # Every try is handed the prompt whole.
  [ "$(cat "$FAKE_PROMPT.other.1")" = "Which colour?" ]
  [ "$(cat "$FAKE_PROMPT.other.3")" = "Which colour?" ]
}

@test "a standing text reaches every try whole" {
  ASK_MODEL_BUSY_WAIT=0
  export FAKE_ANSWER='{}'
  refusal_for_call other 1 529
  get_model_answer some-model 10 "$schema" "" "" "Every rule." <<<"Which colour?" >/dev/null
  [ "$(call_count)" -eq 2 ]
  [ "$(cat "$FAKE_STANDING.other")" = "Every rule." ]
}

@test "busy on every try is refused as busy, after the retries named" {
  ASK_MODEL_BUSY_WAIT=0
  for call in $(seq $((ASK_MODEL_BUSY_RETRIES + 2))); do refusal_for_call other "$call" 529; done
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_model_busy_note some-model $((ASK_MODEL_BUSY_RETRIES + 1)))" ]
  [ "$(call_count)" -eq $((ASK_MODEL_BUSY_RETRIES + 1)) ]
}

@test "no try is started that the call's time limit would not leave room for after the wait" {
  ASK_MODEL_BUSY_WAIT=3
  refusal_for_call other 1 529
  run --separate-stderr get_model_answer some-model 2 "$schema" <<<"Which colour?"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_model_busy_note some-model 1)" ]
  [ "$(call_count)" -eq 1 ]
}

@test "a timeout, an answer that cannot be read and another API refusal are never asked again" {
  ASK_MODEL_BUSY_WAIT=0
  export FAKE_ANSWER='{}' FAKE_SLEEP=3
  run --separate-stderr get_model_answer some-model 1 "$schema" <<<"Which colour?"
  [ "$stderr" = "$(refuse_model_timeout_note some-model 1)" ]
  [ "$(call_count)" -eq 1 ]
  unset FAKE_SLEEP
  : >"$FAKE_CALLS"
  export FAKE_ENVELOPE='{"type":"result","is_error":false,"result":"blue"}'
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$stderr" = "$(refuse_model_unreadable_note some-model)" ]
  [ "$(call_count)" -eq 1 ]
  : >"$FAKE_CALLS"
  export FAKE_ENVELOPE='{"type":"result","is_error":true,"api_error_status":404,"result":"No such model."}' FAKE_STATUS=1
  run --separate-stderr get_model_answer some-model 10 "$schema" <<<"Which colour?"
  [ "$stderr" = "$(refuse_model_exit_note some-model 1)" ]
  [ "$(call_count)" -eq 1 ]
}
