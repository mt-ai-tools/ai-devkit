bats_require_minimum_version 1.5.0

# Behavior tests for the form check: a whole form passes as it stands, and
# every way a form can be broken is refused with its reason named — never
# repaired. The check is pure, so no model is asked here.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/check-form.sh"
  kinds='["defaults","naming"]'
  risks='["security-gap","workaround"]'
}

# The whole form with one field set to the JSON value given.
form_with() {
  jq -c --argjson value "$2" ".$1 = \$value" <<<"$(whole_form)"
}

# The whole form without the field given.
form_without() {
  jq -c "del(.$1)" <<<"$(whole_form)"
}

@test "a whole reader's form passes as it stands" {
  run refuse_bad_reader_form "$(whole_form)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(whole_form)" ]
}

@test "a reply asking nothing passes with an empty form" {
  form='{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":true,"guidance_answer":""}'
  run refuse_bad_reader_form "$form"
  [ "$status" -eq 0 ]
}

@test "each missing field is refused by name" {
  for field in asks_operator question options recommended claims_done guidance_answer; do
    run --separate-stderr refuse_bad_reader_form "$(form_without "$field")"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_missing_field_note "$(reader_form_words)" "$field")" ]
  done
}

@test "a field of the wrong type is refused, never coerced" {
  run --separate-stderr refuse_bad_reader_form "$(form_with asks_operator '"true"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wrong_type_note "$(reader_form_words)" asks_operator boolean)" ]
  run --separate-stderr refuse_bad_reader_form "$(form_with options '"five, ten"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wrong_type_note "$(reader_form_words)" options array)" ]
}

@test "a field the form does not have is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with confidence '0.9')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_field_note "$(reader_form_words)" confidence)" ]
}

@test "a recommendation outside the options is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with recommended '"seven"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_recommended_outside_note seven)" ]
}

@test "a recommendation that differs from its option only in case is outside it" {
  run --separate-stderr refuse_bad_reader_form "$(form_with recommended '"Five"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_recommended_outside_note Five)" ]
}

@test "a recommendation from a single option is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with options '["five"]')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_single_option_note)" ]
}

@test "an option with no words is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with options '["five","ten"," "]')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_option_note)" ]
}

@test "an option label marked as recommended is refused, in any case" {
  for label in "five (recommended)" "Recommended: five" "five (RECOMMENDED, safest)" "we recommend five"; do
    form="$(jq -c --arg label "$label" '.options = ["ten", $label] | .recommended = "ten"' <<<"$(whole_form)")"
    run --separate-stderr refuse_bad_reader_form "$form"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_marked_option_note "$label")" ]
  done
  # Marked and recommended both: the recommendation matches its label, and
  # the mark is refused all the same.
  form="$(jq -c '.options = ["five (recommended)", "ten"] | .recommended = "five (recommended)"' <<<"$(whole_form)")"
  run --separate-stderr refuse_bad_reader_form "$form"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_marked_option_note "five (recommended)")" ]
}

@test "a question to the operator with no question is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with question '""')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_question_missing_note)" ]
}

@test "a form asking nothing yet holding a question is refused" {
  run --separate-stderr refuse_bad_reader_form "$(form_with asks_operator false)"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_question_but_note)" ]
}

@test "a guidance answer outside its words is refused" {
  for word in keep "keep part" Drop maybe; do
    run --separate-stderr refuse_bad_reader_form "$(form_with guidance_answer "$(jq -cn --arg w "$word" '$w')")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_guidance_outside_note "$word")" ]
  done
  for word in drop keep-part keep-all; do
    run refuse_bad_reader_form "$(form_with guidance_answer "\"$word\"")"
    [ "$status" -eq 0 ]
  done
}

@test "every problem is named, not only the first" {
  form='{"asks_operator":true,"question":"Which?","options":["a","b"],"recommended":"c","claims_done":false,"guidance_answer":"maybe"}'
  run --separate-stderr refuse_bad_reader_form "$form"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_recommended_outside_note c)
$(refuse_guidance_outside_note maybe)" ]
}

@test "anything that is not one JSON object is refused" {
  label="$(reader_form_words)"
  for text in "" "Here is the form: {}" "$(whole_form) $(whole_form)" '{"asks_operator":'; do
    run --separate-stderr refuse_bad_reader_form "$text"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_not_json_note "$label")" ]
  done
  run --separate-stderr refuse_bad_reader_form '["five","ten"]'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_not_object_note "$label")" ]
}

@test "a sorter's answer naming known kinds and risks passes" {
  answer='{"kind":"defaults","unsure":false,"risks":["workaround"]}'
  run refuse_bad_sorter_answer "$answer" "$kinds" "$risks"
  [ "$status" -eq 0 ]
  [ "$output" = "$answer" ]
}

@test "an unknown kind is refused, never matched to the nearest" {
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"default","unsure":false,"risks":[]}' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_kind_note default)" ]
}

@test "an unknown risk is refused" {
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"naming","unsure":false,"risks":["workaround","Security gap"]}' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_risk_note "Security gap")" ]
}

@test "a sorter's answer missing a field or not JSON is refused" {
  label="$(sorter_answer_words)"
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"naming","risks":[]}' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_missing_field_note "$label" unsure)" ]
  run --separate-stderr refuse_bad_sorter_answer 'naming' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_not_json_note "$label")" ]
}

@test "a cold reading's answer with words passes" {
  run refuse_bad_reading_answer '{"reading": "Ten is safer."}'
  [ "$status" -eq 0 ]
  [ "$output" = '{"reading":"Ten is safer."}' ]
}

@test "a cold reading's answer with no words, or not its shape, is refused" {
  run --separate-stderr refuse_bad_reading_answer '{"reading":" "}'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_reading_empty_note)" ]
  run --separate-stderr refuse_bad_reading_answer '{"reading":3}'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wrong_type_note "$(reading_answer_words)" reading string)" ]
}

@test "a matcher's answer picking an item as listed, a new choice, or no longer asking passes" {
  for answer in '{"pick":"item","item":"five"}' '{"pick":"new","item":""}' '{"pick":"not-asking","item":""}'; do
    run refuse_bad_matcher_answer "$answer" '["five","ten"]'
    [ "$status" -eq 0 ]
    [ "$output" = "$answer" ]
  done
}

@test "a matcher's answer with an unknown pick, an item off the list, or an item with no pick is refused" {
  run --separate-stderr refuse_bad_matcher_answer '{"pick":"same","item":""}' '["five","ten"]'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_pick_outside_note same)" ]
  run --separate-stderr refuse_bad_matcher_answer '{"pick":"item","item":"5 attempts"}' '["five","ten"]'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_item_outside_note "5 attempts")" ]
  run --separate-stderr refuse_bad_matcher_answer '{"pick":"new","item":"ten"}' '["five","ten"]'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_item_unasked_note ten)" ]
  run --separate-stderr refuse_bad_matcher_answer '{"pick":"item"}' '["five","ten"]'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_missing_field_note "$(matcher_answer_words)" item)" ]
}

@test "an option a reply calls new is an item, never the verdict" {
  run refuse_bad_matcher_answer '{"pick":"item","item":"new"}' '["new","old"]'
  [ "$status" -eq 0 ]
}

@test "a summary's answer with words in every part passes, and one missing a part, with a part of none, or not its shape, is refused" {
  whole='{"problem":"Calls fail.","first_recommendation":"Five.","what_moved_it":"Nothing.","recommends_now":"Five.","operators_call":"Five or ten."}'
  run refuse_bad_summary_answer "$whole"
  [ "$status" -eq 0 ]
  [ "$output" = "$whole" ]
  for part in problem first_recommendation what_moved_it recommends_now operators_call; do
    run --separate-stderr refuse_bad_summary_answer "$(jq -c --arg part "$part" 'del(.[$part])' <<<"$whole")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_missing_field_note "$(summary_answer_words)" "$part")" ]
    run --separate-stderr refuse_bad_summary_answer "$(jq -c --arg part "$part" '.[$part] = "  "' <<<"$whole")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_summary_part_empty_note "$part")" ]
  done
  run --separate-stderr refuse_bad_summary_answer "$(jq -c '.verdict = "held"' <<<"$whole")"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_field_note "$(summary_answer_words)" verdict)" ]
}
