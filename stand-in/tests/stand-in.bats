bats_require_minimum_version 1.5.0

# Behavior tests for the entry: a reply read into a checked form, a question
# sorted against the project's own preset, and every form or answer the check
# refuses kept off stdout. Claude Code is the suite's own fake.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/words.sh"
  . "$lib/forms.sh"
  . "$lib/jobs.sh"
  preset "defaults:Defaults. naming:Names." "security-gap workaround"
  reply="Should we use five retries or ten? I recommend five."
}

@test "read-reply hands back the reader's checked form, asked of the reader's model" {
  export FAKE_ANSWER="$(whole_form)"
  run --separate-stderr "$script" read-reply <<<"$reply"
  [ "$status" -eq 0 ]
  [ "$output" = "$(whole_form)" ]
  grep -qx -- "$READER_MODEL" "$FAKE_ARGS"
  grep -qxF -- "$(reader_form_schema)" "$FAKE_ARGS"
  grep -qF -- "$reply" "$FAKE_PROMPT"
}

@test "read-reply refuses a form the check refuses, and prints none" {
  export FAKE_ANSWER='{"asks_operator":true,"question":"Five or ten?","options":["five","ten"],"recommended":"seven","claims_done":false,"guidance_answer":""}'
  run --separate-stderr "$script" read-reply <<<"$reply"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_recommended_outside_note seven)" ]
}

@test "sort hands back the sorter's checked answer, the preset's kinds and risks in its prompt" {
  export FAKE_ANSWER='{"kind":"defaults","unsure":false,"risks":["workaround"]}'
  run --separate-stderr "$script" sort "$(whole_form)" <<<"$reply"
  [ "$status" -eq 0 ]
  [ "$output" = '{"kind":"defaults","unsure":false,"risks":["workaround"]}' ]
  grep -qx -- "$SORTER_MODEL" "$FAKE_ARGS"
  grep -qxF -- "- defaults: Defaults." "$FAKE_PROMPT"
  grep -qxF -- "- security-gap: The security-gap risk." "$FAKE_PROMPT"
  grep -qF -- "$(whole_form)" "$FAKE_PROMPT"
  grep -qF -- "$reply" "$FAKE_PROMPT"
}

@test "sort refuses a kind or a risk the project's preset does not hold" {
  export FAKE_ANSWER='{"kind":"technical-choice","unsure":false,"risks":[]}'
  run --separate-stderr "$script" sort "$(whole_form)" <<<"$reply"
  [ "$status" -eq 1 ]
  [ -z "$output" ]
  [ "$stderr" = "$(refuse_unknown_kind_note technical-choice)" ]
  export FAKE_ANSWER='{"kind":"naming","unsure":false,"risks":["tangled"]}'
  run --separate-stderr "$script" sort "$(whole_form)" <<<"$reply"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_risk_note tangled)" ]
}

@test "sort asks no model about a broken form, or one holding no question" {
  run --separate-stderr "$script" sort '{"asks_operator":true}' <<<"$reply"
  [ "$status" -eq 1 ]
  [ ! -e "$FAKE_ARGS" ]
  form='{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":true,"guidance_answer":""}'
  run --separate-stderr "$script" sort "$form" <<<"Done."
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_nothing_to_sort_note)" ]
  [ ! -e "$FAKE_ARGS" ]
}

@test "an unknown command or a wrong count of arguments is refused with the usage" {
  for args in "" "judge" "read-reply extra" "sort"; do
    run --separate-stderr "$script" $args </dev/null
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_usage_note)" ]
  done
}
