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
  form='{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":true,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
  run refuse_bad_reader_form "$form"
  [ "$status" -eq 0 ]
}

@test "each missing field is refused by name" {
  for field in asks_operator question options recommended claims_done closes_round guidance_answer \
    ends_step problems proof next_step next_step_number next_step_from next_step_marks; do
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
  form='{"asks_operator":true,"question":"Which?","options":["a","b"],"recommended":"c","claims_done":false,"closes_round":false,"guidance_answer":"maybe","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
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
  answer='{"kind":"defaults","unsure":false,"risks":["workaround"],"defers":false}'
  run refuse_bad_sorter_answer "$answer" "$kinds" "$risks"
  [ "$status" -eq 0 ]
  [ "$output" = "$answer" ]
}

@test "an unknown kind is refused, never matched to the nearest" {
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"default","unsure":false,"risks":[],"defers":false}' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_kind_note default)" ]
}

@test "an unknown risk is refused" {
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"naming","unsure":false,"risks":["workaround","Security gap"],"defers":false}' "$kinds" "$risks"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_risk_note "Security gap")" ]
}

@test "a sorter's answer missing a field or not JSON is refused" {
  label="$(sorter_answer_words)"
  run --separate-stderr refuse_bad_sorter_answer '{"kind":"naming","risks":[],"defers":false}' "$kinds" "$risks"
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

@test "a step's report passes whole, its problems in each state and every mark on the next step" {
  run refuse_bad_reader_form "$(step_form)"
  [ "$status" -eq 0 ]
  [ "$output" = "$(step_form)" ]
  form="$(step_form '.problems = [{problem: "a typo", state: "fixed"}, {problem: "slow", state: "unfixed"},
    {problem: "which name", state: "needs-decision"}]
    | .next_step_marks = ["pushes", "syncs", "deletes", "other-session", "runs-alone"]')"
  run refuse_bad_reader_form "$form"
  [ "$status" -eq 0 ]
  run refuse_bad_reader_form "$(step_form '.proof = "" | .next_step = "" | .next_step_number = 0 | .next_step_from = ""')"
  [ "$status" -eq 0 ]
}

@test "a step's word outside its own is refused, never read as the nearest" {
  run --separate-stderr refuse_bad_reader_form "$(step_form '.problems = [{problem: "slow", state: "open"}]')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_state_outside_note open)" ]
  run --separate-stderr refuse_bad_reader_form "$(step_form '.proof = "green"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_proof_outside_note green)" ]
  run --separate-stderr refuse_bad_reader_form "$(step_form '.next_step_from = "the brief"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_from_outside_note "the brief")" ]
  run --separate-stderr refuse_bad_reader_form "$(step_form '.next_step_marks = ["push"]')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_mark_outside_note push)" ]
  for number in -1 2.5; do
    run --separate-stderr refuse_bad_reader_form "$(step_form ".next_step_number = $number")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_bad_step_number_note "$number")" ]
  done
}

@test "a step's problem that is not what was found and its state is refused" {
  for problem in '"slow"' '{"problem":"slow"}' '{"problem":" ","state":"fixed"}' '{"problem":"slow","state":"fixed","why":"x"}'; do
    run --separate-stderr refuse_bad_reader_form "$(step_form ".problems = [$problem]")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_bad_problem_note)" ]
  done
}

@test "a form ending no step yet saying what a step found, proved or comes next is refused" {
  for filter in '.problems = [{problem: "slow", state: "fixed"}]' '.proof = "passed"' '.next_step = "step 9"' \
    '.next_step_number = 9' '.next_step_from = "brief"' '.next_step_marks = ["pushes"]'; do
    run --separate-stderr refuse_bad_reader_form "$(jq -c "$filter" <<<"$(whole_form)")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_no_step_but_note)" ]
  done
  # The full check, said of the whole work done, is no step's proof.
  run refuse_bad_reader_form "$(jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = ""
    | .claims_done = true | .proof = "passed"' <<<"$(whole_form)")"
  [ "$status" -eq 0 ]
  run --separate-stderr refuse_bad_reader_form "$(jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = ""
    | .claims_done = true | .next_step = "step 9"' <<<"$(whole_form)")"
  [ "$status" -eq 1 ]
}

@test "the sorter's labelling of a step passes with labels it was handed, and is refused with any other" {
  labels='["workaround","lost-data","broken-check"]'
  answer='{"majors":[{"problem":"a table dropped","label":"lost-data"}],"unsure":false}'
  run refuse_bad_step_sort "$answer" "$labels"
  [ "$status" -eq 0 ]
  [ "$output" = "$answer" ]
  run --separate-stderr refuse_bad_step_sort '{"majors":[{"problem":"a table dropped","label":"data-loss"}],"unsure":false}' "$labels"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_label_note data-loss)" ]
  run --separate-stderr refuse_bad_step_sort '{"majors":["a table dropped"],"unsure":false}' "$labels"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_bad_major_note)" ]
  run --separate-stderr refuse_bad_step_sort '{"majors":[]}' "$labels"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_missing_field_note "$(step_sort_words)" unsure)" ]
}

@test "a form both closing the round of questions and ending a step is refused; a question beside either is not" {
  step="$(jq -c '.asks_operator = false | .question = "" | .options = [] | .recommended = ""
    | .ends_step = true | .proof = "passed"' <<<"$(whole_form)")"
  run --separate-stderr refuse_bad_reader_form "$(jq -c '.closes_round = true' <<<"$step")"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_round_and_step_note)" ]
  run refuse_bad_reader_form "$(jq -c '.closes_round = true' <<<"$(whole_form)")"
  [ "$status" -eq 0 ]
}

@test "the round reader's answer passes with every decision handed once, and is refused otherwise" {
  numbers='[3,5]'
  answer='{"decisions":[{"number":5,"decision":"Ten tries."},{"number":3,"decision":"Five seconds."}]}'
  run refuse_bad_round_answer "$answer" "$numbers"
  [ "$status" -eq 0 ]
  [ "$output" = "$answer" ]
  run --separate-stderr refuse_bad_round_answer '{"decisions":[{"number":3,"decision":"Five seconds."}]}' "$numbers"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_decision_missing_note 5)" ]
  run --separate-stderr refuse_bad_round_answer \
    '{"decisions":[{"number":3,"decision":"A."},{"number":3,"decision":"B."},{"number":5,"decision":"C."},{"number":4,"decision":"D."}]}' "$numbers"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_decision_outside_note 4; refuse_decision_twice_note 3)" ]
  for item in '{"number":5,"decision":" "}' '{"number":"5","decision":"C."}' '{"number":5}' '"five"'; do
    run --separate-stderr refuse_bad_round_answer "{\"decisions\":[{\"number\":3,\"decision\":\"A.\"},$item]}" "$numbers"
    [ "$status" -eq 1 ]
    [[ "$stderr" == "$(refuse_bad_decision_note)"* ]]
  done
  run --separate-stderr refuse_bad_round_answer '{"decisions":[]}' '[]'
  [ "$status" -eq 0 ]
}

# --- The closing reader's form.

# One finding: what it is, its sort, its files as a JSON array, its brief.
look_finding() {
  jq -cn --arg f "$1" --arg sort "$2" --argjson files "${3:-[]}" --arg brief "${4:-}" \
    '{finding: $f, sort: $sort, files: $files, brief: $brief}'
}

# A closing reader's form holding the findings given, a JSON array, and
# nothing_left as given.
look_with() {
  jq -cn --argjson findings "$1" --argjson left "$2" '{findings: $findings, nothing_left: $left}'
}

others='["frozen-account"]'

@test "a closing reader's form passes whole, a finding of every sort among it" {
  findings="[$(look_finding "README" here '["aidk-plans/x.md"]'),$(look_finding "noted" written-down),$(look_finding "logging" not-same-job),$(look_finding "copy" quick '["src/a.ts","src/"]'),$(look_finding "theirs" hand-off '[]' frozen-account),$(look_finding "screen" park)]"
  run refuse_bad_look_form "$(look_with "$findings" false)" "$others"
  [ "$status" -eq 0 ]
  [ "$output" = "$(look_with "$findings" false)" ]
  run refuse_bad_look_form "$(look_with '[]' true)" '[]'
  [ "$status" -eq 0 ]
}

@test "a finding that is not its four fields, or sorted outside the filter, is refused" {
  for bad in '{"finding":"x","sort":"park","files":[]}' '{"finding":" ","sort":"park","files":[],"brief":""}' \
    '{"finding":"x","sort":"park","files":[""],"brief":""}' '{"finding":"x","sort":"park","files":"a","brief":""}' '"x"'; do
    run --separate-stderr refuse_bad_look_form "$(look_with "[$bad]" true)" "$others"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_bad_finding_note)" ]
  done
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x maybe)]" true)" "$others"
  [ "$stderr" = "$(refuse_sort_outside_note maybe)" ]
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding "a  thing" unsorted)]" true)" "$others"
  [ "$stderr" = "$(refuse_unsorted_note "a thing")" ]
}

@test "a path leaving the project root is refused" {
  for path in /etc/passwd ../x a/../../b ..; do
    run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x park "[\"$path\"]")]" true)" "$others"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_file_outside_note "$path")" ]
  done
}

@test "a hand-off to a brief no other session holds, or a brief beside another sort, is refused" {
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x hand-off '[]' file-trash)]" true)" "$others"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_brief_outside_note file-trash)" ]
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x hand-off)]" true)" "$others"
  [ "$stderr" = "$(refuse_brief_outside_note "")" ]
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x park '[]' frozen-account)]" true)" "$others"
  [ "$stderr" = "$(refuse_brief_unasked_note frozen-account)" ]
}

@test "a quick finding naming no files is refused, since where it lies could not be checked" {
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding "a copy" quick)]" true)" "$others"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_quick_no_files_note "a copy")" ]
}

@test "nothing left beside a finding that belongs here, or something left beside none, is refused" {
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x here)]" true)" "$others"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_left_but_here_note)" ]
  run --separate-stderr refuse_bad_look_form "$(look_with "[$(look_finding x park)]" false)" "$others"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_here_none_but_left_note)" ]
}

@test "a closing reader's form missing a field, holding another, or not JSON is refused" {
  run --separate-stderr refuse_bad_look_form '{"findings":[]}' "$others"
  [ "$stderr" = "$(refuse_missing_field_note "$(look_form_words)" nothing_left)" ]
  run --separate-stderr refuse_bad_look_form '{"findings":[],"nothing_left":true,"why":"x"}' "$others"
  [ "$stderr" = "$(refuse_unknown_field_note "$(look_form_words)" why)" ]
  run --separate-stderr refuse_bad_look_form 'nope' "$others"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_not_json_note "$(look_form_words)")" ]
}

# A whole case-writer's form: an answer that picks the recommended option,
# with a reason. A jq filter given is applied to it.
case_form() {
  jq -c "${1:-.}" <<<'{"answers":true,"title":"How many retries","summary":"How many times a failing call is tried.","reply":"A call fails now and then. Should it be tried five times or ten? I recommend five: ten holds the page too long.","options":["Five tries","Ten tries"],"recommended":"Five tries","answered":"Five tries.","picked":"Five tries","security_gap":false,"why":"Ten holds the page too long."}'
}

# The case-writer's form for an answer that does not answer.
skipped_form='{"answers":false,"title":"","summary":"","reply":"","options":[],"recommended":"","answered":"","picked":"","security_gap":false,"why":""}'

@test "a case-writer's form passes whole, with a pick or none, no recommendation, no why, or skipped" {
  for filter in . '.picked = ""' '.recommended = ""' '.why = ""'; do
    run refuse_bad_case_form "$(case_form "$filter")"
    [ "$status" -eq 0 ]
    [ "$output" = "$(case_form "$filter")" ]
  done
  run refuse_bad_case_form "$skipped_form"
  [ "$status" -eq 0 ]
}

@test "a case-writer's form that skips yet holds a case, or holds one with a part missing, is refused" {
  run --separate-stderr refuse_bad_case_form "$(jq -c '.why = "Because."' <<<"$skipped_form")"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_skipped_but_note)" ]
  for part in title summary reply answered; do
    run --separate-stderr refuse_bad_case_form "$(case_form ".$part = \"  \"")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_case_part_empty_note "$part")" ]
  done
}

@test "a case's header part over two lines, or a reply holding a marker line, is refused" {
  for part in title summary; do
    run --separate-stderr refuse_bad_case_form "$(case_form ".$part = \"One\\nTwo\"")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_case_line_note "$part")" ]
  done
  for marker in "=====REPLY START=====" "=====REPLY END====="; do
    run --separate-stderr refuse_bad_case_form "$(case_form ".reply = \"Five or ten?\\n$marker\\nYes.\"")"
    [ "$status" -eq 1 ]
    [ "$stderr" = "$(refuse_case_marker_note)" ]
  done
}

@test "a case's options, recommendation and pick are held to the list, never matched to the nearest" {
  run --separate-stderr refuse_bad_case_form "$(case_form '.options = ["Five tries"] | .recommended = "" | .picked = ""')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_options_few_note)" ]
  run --separate-stderr refuse_bad_case_form "$(case_form '.options += [" "]')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_option_note)" ]
  run --separate-stderr refuse_bad_case_form "$(case_form '.recommended = "Five"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_recommended_note Five)" ]
  run --separate-stderr refuse_bad_case_form "$(case_form '.picked = "five tries"')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_picked_note "five tries")" ]
}

@test "a case's security gap passes where the operator turned the recommendation down; a skipped case or a pick of it holding one is refused" {
  run refuse_bad_case_form "$(case_form '.picked = "Ten tries" | .security_gap = true')"
  [ "$status" -eq 0 ]
  run refuse_bad_case_form "$(case_form '.picked = "" | .security_gap = true')"
  [ "$status" -eq 0 ]
  run --separate-stderr refuse_bad_case_form "$(case_form '.security_gap = true')"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_security_taken_note)" ]
  run --separate-stderr refuse_bad_case_form "$(jq -c '.security_gap = true' <<<"$skipped_form")"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_case_skipped_but_note)" ]
}

@test "a case-writer's form missing a field, holding another, or not JSON is refused" {
  run --separate-stderr refuse_bad_case_form "$(case_form 'del(.why)')"
  [ "$stderr" = "$(refuse_missing_field_note "$(case_form_words)" why)" ]
  run --separate-stderr refuse_bad_case_form "$(case_form '.secret = "x"')"
  [ "$stderr" = "$(refuse_unknown_field_note "$(case_form_words)" secret)" ]
  run --separate-stderr refuse_bad_case_form 'not json'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_not_json_note "$(case_form_words)")" ]
}

@test "the secret check's answer passes as a yes or a no, and is refused as anything else" {
  for answer in '{"holds_secret":true}' '{"holds_secret":false}'; do
    run refuse_bad_secret_answer "$answer"
    [ "$status" -eq 0 ]
    [ "$output" = "$answer" ]
  done
  run --separate-stderr refuse_bad_secret_answer '{"holds_secret":"no"}'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_wrong_type_note "$(secret_answer_words)" holds_secret boolean)" ]
  run --separate-stderr refuse_bad_secret_answer '{"holds_secret":false,"what":"a key"}'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unknown_field_note "$(secret_answer_words)" what)" ]
}
