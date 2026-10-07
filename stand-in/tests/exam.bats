bats_require_minimum_version 1.5.0

# Behavior tests for the exam: every test case replayed through the parts
# whose answer code decides from, and judged on how the reader read it, what
# the rules and conventions check found, the kind the sorter gave and where
# the route sent it; a drop — a case that passed the last passing exam and
# fails now — blocks, and a case that never passed does not; with no last
# results kept every failing case blocks; a passing exam keeps its results
# and clears the session's exam owed, a failing one keeps both. Claude Code
# is the suite's own fake, answering each model apart.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/words.sh"
  . "$lib/jobs.sh"
  . "$lib/exam.sh"
  preset "defaults:Defaults. naming:Names." "security-gap workaround"
  kind naming ask
  kind defaults ask
  rules="$project/rules"
  conventions="$project/conventions"
  mkdir -p "$rules" "$conventions"
  printf '# Rule one\n\nRule one body.\n' >"$rules/rule-one.md"
  printf '# Convention one\n\nConvention one body.\n' >"$conventions/convention-one.md"
  printf 'AIDK_RULES=%s\nAIDK_CONVENTIONS=%s\n' "$rules" "$conventions" >>"$project/aidk-config.env"
  history="$project/aidk-stand-in"
  answers="$history/answers"
  results="$history/exam/last-passed.json"
  owed="$history/owed/session-1"
  export CLAUDE_CODE_SESSION_ID=session-1
  answer_for reader "$(whole_form)"
  answer_for checker "$clean_check"
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
}

teardown() {
  [ ! -d "$history" ] || chmod -R u+rwx "$history"
}

clean_check='{"breaks":[],"miscalled":[],"explains_code":false}'

# A kind of question in the suite's preset: name, route, and its challenge
# where it has one.
kind() {
  {
    printf -- '---\nsummary: The %s kind.\nroute: %s\n' "$1" "$2"
    [ -z "${3:-}" ] || printf 'challenge: %s\n' "$3"
    printf -- '---\n\n# %s\n' "$1"
  } >"$preset_dir/questions/$1.md"
}

# A case file in the answers folder, given its name, its header's lines and
# its reply.
write_case() {
  mkdir -p "$answers"
  printf -- '---\n%s\n---\n\n# A case\n\n## Reply\n\n=====REPLY START=====\n%s\n=====REPLY END=====\n\n## The operator'\''s answer\n\nNo.\n' \
    "$2" "$3" >"$answers/$1"
}

# A case as the case-writer writes one, given its name, kind and whether the
# operator picked the option recommended.
question_case() {
  write_case "$1" "$(printf 'summary: A case.\ndate: 2026-10-07\nbrief: file-trash\nkind: %s\nalone: no\npicked-recommended: %s\ntuning: none\nlog-id: id-%s' "$2" "$3" "${1%.md}")" \
    "Five retries or ten? I recommend five."
}

# A case as the seed cases are written: the route it must take, the findings
# the check must give and the entries it must name, its tuning used.
seed_case() {
  write_case "$1" "$(printf 'summary: A seed.\ndate: 2026-10-02\nbrief: users-before-you-go\ntuning: used — the checker was tuned on it\nroute: agent\nfindings: [breaks, miscalled]\nbreaks: [rule-one.md]')" \
    "Wire it in the demo, as the frame's rule says."
}

seed_check='{"breaks":[{"entry":"rule-one.md","why":"It breaks it."}],"miscalled":[{"called":"the frame'"'"'s rule","actually":"A code comment."}],"explains_code":false}'

# The session's exam owed, as the edit hook leaves it.
owe() {
  mkdir -p "$history/owed"
  printf '%s\n' '{"files":["/somewhere/questions/naming.md"],"noted":"2026-10-07T10:00:00.000000000Z"}' >"$owed"
}

# The exam, run; where it printed anything, its last line is the time it
# took, checked and left off, so each test reads what the exam found.
run_exam() {
  run --separate-stderr "$script" exam
  [ -z "$output" ] || {
    [[ "$(tail -n 1 <<<"$output")" =~ ^"$(exam_time_line 0 | sed 's/0 s\.$//')"[0-9]+" s."$ ]]
    output="$(head -n -1 <<<"$output")"
  }
}

# The calls so far, each kind once with how many times it was asked, sorted:
# the replays of a case ask side by side, in no fixed order.
counted_calls() {
  calls | sort | uniq -c | sed 's/^ *//'
}

# Each replay of a case asks every part once.
three() { printf '%s %s\n' "$EXAM_REPLAYS" "$1"; }

@test "a seed case is replayed through the reader and the check alone, and passes where the check finds what it says" {
  seed_case seed.md
  answer_for checker "$seed_check"
  run_exam
  [ "$status" -eq 0 ]
  [ "$output" = "$(exam_no_results_line)
$(exam_passed_line seed.md "$(exam_tuning_used_words)" agent)
$(exam_replays_line 3 3)
$(exam_passed_note 1 1 0)" ]
  [ "$(counted_calls)" = "$(three "checker $CHECKER_MODEL")"$'\n'"$(three "reader $READER_MODEL")" ]
  grep -qF -- "Wire it in the demo, as the frame's rule says." "$FAKE_PROMPT.reader"
  [ "$(jq -c . "$results")" = '{"passed":["seed.md"],"scores":{}}' ]
}

@test "a check that misses what the case expects fails it, and with no last results kept it blocks" {
  seed_case seed.md
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[],"defers":false}'
  run_exam
  [ "$status" -eq 1 ]
  [ "$output" = "$(exam_no_results_line)
$(exam_dropped_unknown_line seed.md "$(exam_tuning_used_words)")
$(exam_replays_line 0 3)
$(exam_detail_line "$(exam_finding_missing_fault breaks)")
$(exam_detail_line "$(exam_finding_missing_fault miscalled)")
$(exam_detail_line "$(exam_breaks_none_fault rule-one.md)")
$(exam_detail_line "$(exam_route_fault operator agent)")
$(exam_failed_note 1 0 1 1)" ]
  [ ! -e "$results" ]
}

@test "proof: a kind whose route is flipped lets a case the operator did not take stand alone, and it drops" {
  question_case naming.md naming no
  run_exam
  [ "$status" -eq 0 ]
  [ "$(jq -c . "$results")" = '{"passed":["naming.md"],"scores":{}}' ]
  [ "$(counted_calls)" = "$(three "checker $CHECKER_MODEL")"$'\n'"$(three "reader $READER_MODEL")"$'\n'"$(three "sorter $SORTER_MODEL")" ]
  kind naming accept
  run_exam
  [ "$status" -eq 1 ]
  [ "$output" = "$(exam_dropped_line naming.md "")
$(exam_replays_line 0 3)
$(exam_detail_line "$(exam_route_alone_fault)")
$(exam_failed_note 1 0 1 1)" ]
  [ "$(jq -c . "$results")" = '{"passed":["naming.md"],"scores":{}}' ]
}

@test "a case never passed before fails without blocking, and is left out of the results" {
  mkdir -p "$history/exam"
  printf '%s\n' '{"passed":["a.md"]}' >"$results"
  question_case a.md naming yes
  question_case b.md defaults yes
  run_exam
  [ "$status" -eq 0 ]
  [ "$output" = "$(exam_passed_line a.md "" operator)
$(exam_replays_line 3 3)
$(exam_failed_new_line b.md "")
$(exam_replays_line 0 3)
$(exam_detail_line "$(exam_kind_fault naming defaults)")
$(exam_passed_note 2 1 1)" ]
  [ "$(jq -c . "$results")" = '{"passed":["a.md"],"scores":{}}' ]
}

@test "a case whose operator took the recommendation passes even settled alone; one they did not take passes sent back to the agent" {
  kind naming accept
  question_case taken.md naming yes
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p <<<"$output")" = "$(exam_passed_line taken.md "" alone)" ]
  answer_for checker "$seed_check"
  question_case not-taken.md naming no
  rm "$results"
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p <<<"$output")" = "$(exam_passed_line not-taken.md "" agent)" ]
}

@test "a step's report case is read as one, labelled, and weighed for the go with its own brief" {
  kind step-go go
  question_case step.md step-go no
  answer_for reader "$(step_form)"
  answer_for step-sorter '{"majors":[],"unsure":false}'
  run_exam
  [ "$status" -eq 1 ]
  [ "$(sed -n 2,4p <<<"$output")" = "$(exam_dropped_unknown_line step.md "")"$'\n'"$(exam_replays_line 0 3)"$'\n'"$(exam_detail_line "$(exam_route_alone_fault)")" ]
  [ "$(counted_calls)" = "$(three "reader $READER_MODEL")"$'\n'"$(three "step-sorter $SORTER_MODEL")" ]
  answer_for step-sorter '{"majors":[{"problem":"a table dropped","label":"lost-data"}],"unsure":false}'
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p <<<"$output")" = "$(exam_passed_line step.md "" operator)" ]
  # The case's brief is the one the session held: without it, the go is the
  # operator's.
  answer_for step-sorter '{"majors":[],"unsure":false}'
  sed -i 's/^brief: file-trash$/brief: /' "$answers/step.md"
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 1p <<<"$output")" = "$(exam_passed_line step.md "" operator)" ]
}

@test "the reader reading a case as something else fails it, and no later part is asked" {
  kind step-go go
  question_case step.md step-go yes
  question_case question.md naming yes
  answer_for reader "$(step_form)"
  run_exam
  [ "$status" -eq 1 ]
  grep -qxF -- "$(exam_detail_line "$(exam_misread_fault "$(exam_question_words)")")" <<<"$output"
  answer_for reader "$(whole_form)"
  rm "$answers/question.md"
  : >"$FAKE_CALLS"
  run_exam
  grep -qxF -- "$(exam_detail_line "$(exam_misread_fault "$(exam_step_words)")")" <<<"$output"
  [ "$(counted_calls)" = "$(three "reader $READER_MODEL")" ]
}

@test "a ladder kind is taken as held: the matcher is never asked, and the case says so" {
  kind defaults ladder
  question_case ladder.md defaults no
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[],"defers":false}'
  run_exam
  [ "$status" -eq 1 ]
  [ "$(sed -n 4,5p <<<"$output")" = "$(exam_detail_line "$(exam_route_alone_fault)")"$'\n'"$(exam_detail_line "$(exam_climb_unreplayed_note ladder)")" ]
  ! grep -q '^matcher ' "$FAKE_CALLS"
}

@test "a kind with a challenge is sent back to the agent, the case told the challenge is not replayed" {
  kind naming ask "Do we need it?"
  question_case challenged.md naming no
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 2,4p <<<"$output")" = "$(exam_passed_line challenged.md "" agent)"$'\n'"$(exam_replays_line 3 3)"$'\n'"$(exam_detail_line "$(exam_challenged_note naming)")" ]
}

@test "a part that cannot answer fails the case with its reason, and the parts after it are not asked" {
  question_case naming.md naming no
  status_for checker 1
  run_exam
  [ "$status" -eq 1 ]
  [ "$(sed -n 4p <<<"$output")" = "$(exam_detail_line "$(exam_part_failed_fault "$(exam_checker_words)" "$(refuse_model_exit_note "$CHECKER_MODEL" 1)")")" ]
  [ "$(counted_calls)" = "$(three "checker $CHECKER_MODEL")"$'\n'"$(three "reader $READER_MODEL")" ]
}

@test "a case that cannot be judged fails, and no model is asked about it" {
  write_case no-reply.md "kind: naming"$'\n'"picked-recommended: no" ""
  sed -i '/=====REPLY END=====/d' "$answers/no-reply.md"
  write_case no-expectation.md "kind: naming" "Five or ten?"
  write_case bad-route.md "route: somewhere" "Five or ten?"
  write_case bad-finding.md "route: agent"$'\n'"findings: [typos]" "Five or ten?"
  run_exam
  [ "$status" -eq 1 ]
  [ "$output" = "$(exam_no_results_line)
$(exam_dropped_unknown_line bad-finding.md "")
$(exam_detail_line "$(exam_unjudgeable_fault "$(exam_case_bad_finding_words typos)")")
$(exam_dropped_unknown_line bad-route.md "")
$(exam_detail_line "$(exam_unjudgeable_fault "$(exam_case_bad_route_words somewhere)")")
$(exam_dropped_unknown_line no-expectation.md "")
$(exam_detail_line "$(exam_unjudgeable_fault "$(exam_case_no_expectation_words)")")
$(exam_dropped_unknown_line no-reply.md "")
$(exam_detail_line "$(exam_unjudgeable_fault "$(exam_case_no_reply_words)")")
$(exam_failed_note 4 0 4 4)" ]
  [ -z "$(calls)" ]
}

@test "a passing exam clears the session's exam owed; a failing one keeps it, saying so" {
  question_case naming.md naming no
  owe
  answer_for sorter '{"kind":"defaults","unsure":false,"risks":[],"defers":false}'
  run_exam
  [ "$status" -eq 1 ]
  [ "$(tail -n 1 <<<"$output")" = "$(exam_mark_kept_line)" ]
  [ -f "$owed" ]
  answer_for sorter '{"kind":"naming","unsure":false,"risks":[],"defers":false}'
  run_exam
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 <<<"$output")" = "$(exam_mark_cleared_line)" ]
  [ ! -e "$owed" ]
}

@test "with no session named, a passing exam clears no exam owed, and says so" {
  question_case naming.md naming no
  owe
  unset CLAUDE_CODE_SESSION_ID
  run_exam
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 <<<"$output")" = "$(exam_no_session_line)" ]
  [ -f "$owed" ]
  export CLAUDE_CODE_SESSION_ID=../on/session-1
  run_exam
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_exam_session_note CLAUDE_CODE_SESSION_ID)" ]
}

@test "an edit noted while the exam runs keeps the session's exam owed" {
  question_case naming.md naming no
  owe
  # A claude that notes an edit as it is asked, as the edit hook would.
  mkdir -p "$BATS_TEST_TMPDIR/editing"
  cat >"$BATS_TEST_TMPDIR/editing/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' '{"files":["x"],"noted":"later"}' >"$owed"
exec "$fakebin/claude" "\$@"
EOF
  chmod +x "$BATS_TEST_TMPDIR/editing/claude"
  export PATH="$BATS_TEST_TMPDIR/editing:$PATH"
  run_exam
  [ "$status" -eq 0 ]
  [ "$(tail -n 1 <<<"$output")" = "$(exam_mark_moved_line)" ]
  [ "$(jq -r '.noted' "$owed")" = later ]
}

@test "no case kept, or last results that cannot be read, refuse the exam, and the exam owed stands" {
  owe
  run_exam
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_exam_no_cases_note "$answers")" ]
  question_case naming.md naming no
  mkdir -p "$history/exam"
  printf 'not json\n' >"$results"
  run_exam
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_exam_results_unreadable_note "$results")" ]
  [ -f "$owed" ]
  [ -z "$(calls)" ]
}

@test "results that cannot be kept fail the exam, and the exam owed stands" {
  question_case naming.md naming no
  owe
  mkdir -p "$history/exam"
  chmod a-w "$history/exam"
  run_exam
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_exam_results_unwritable_note "$history/exam")" ]
  [ -f "$owed" ]
}

@test "best of three: a case passes where two of its three replays pass, and drops where two fail" {
  question_case naming.md naming no
  answer_for_call reader 2 "$(step_form)"
  run_exam
  [ "$status" -eq 0 ]
  [ "$output" = "$(exam_no_results_line)
$(exam_passed_line naming.md "" operator)
$(exam_replays_line 2 3)
$(exam_detail_line "$(exam_misread_fault "$(exam_question_words)")")
$(exam_passed_note 1 1 0)" ]
  [ "$(jq -c . "$results")" = '{"passed":["naming.md"],"scores":{}}' ]
  : >"$FAKE_CALLS"
  answer_for_call reader 3 "$(step_form)"
  run_exam
  [ "$status" -eq 1 ]
  [ "$output" = "$(exam_dropped_line naming.md "")
$(exam_replays_line 1 3)
$(exam_detail_line "$(exam_misread_fault "$(exam_question_words)")")
$(exam_failed_note 1 0 1 1)" ]
}

@test "the replays of a case run side by side, and a replay that stops without a result counts as failed" {
  question_case naming.md naming no
  export FAKE_SLEEP=2
  started="$SECONDS"
  run_exam
  [ "$status" -eq 0 ]
  # Three replays of three calls each, two seconds a call: side by side, six.
  [ "$((SECONDS - started))" -lt 12 ]
  unset FAKE_SLEEP
  # A replay whose process ends without a result, in two replays of three.
  . "$lib/exam-replay.sh"
  replay_case() {
    if mkdir "$BATS_TEST_TMPDIR/first" 2>/dev/null; then
      to_case_result "$1" operator "" ""
    else
      printf 'it fell over\n' >&2
      exit 1
    fi
  }
  result="$(replay_best_of "$(jq -cn '{name: "naming.md", tuning_used: false}')")"
  [ "$(jq -c '{runs, passes, faults}' <<<"$result")" = "$(jq -cn --arg f "$(exam_replay_stopped_fault "it fell over")" \
    '{runs: 3, passes: 1, faults: [$f]}')" ]
  ! is_case_passed "$result"
}

@test "of the entries a case says it breaks, any one named passes; none named fails; a kind of finding missing fails" {
  write_case two.md "$(printf 'route: agent\nfindings: [breaks]\nbreaks: [rule-one.md, convention-one.md]')" "Five or ten?"
  answer_for checker '{"breaks":[{"entry":"convention-one.md","why":"It breaks it."}],"miscalled":[],"explains_code":false}'
  run_exam
  [ "$status" -eq 0 ]
  [ "$(sed -n 2p <<<"$output")" = "$(exam_passed_line two.md "" agent)" ]
  answer_for checker "$seed_check"
  sed -i 's/^breaks: .*/breaks: [convention-one.md]/' "$answers/two.md"
  run_exam
  [ "$status" -eq 1 ]
  grep -qxF -- "$(exam_detail_line "$(exam_breaks_none_fault convention-one.md)")" <<<"$output"
  sed -i 's/^breaks: .*/breaks: [rule-one.md]/; s/^findings: .*/findings: [breaks, explains_code]/' "$answers/two.md"
  run_exam
  [ "$status" -eq 1 ]
  grep -qxF -- "$(exam_detail_line "$(exam_finding_missing_fault explains_code)")" <<<"$output"
  ! grep -qF -- "$(exam_breaks_none_fault rule-one.md)" <<<"$output"
}

# --- The trial's score, kept with a passing exam's results.

# A case as the case-writer writes one, given its name, kind, whether the
# operator picked the option recommended, and whether they turned it down for
# a security gap.
scored_case() {
  write_case "$1" "$(printf 'summary: Case %s.\ndate: 2026-10-07\nbrief: file-trash\nkind: %s\nalone: no\npicked-recommended: %s\nsecurity-gap: %s\ntuning: none\nlog-id: id-%s' \
    "${1%.md}" "$2" "$3" "$4" "${1%.md}")" "Five retries or ten? I recommend five."
}

# Cases of the kind given: how many the operator agreed with, then how many
# they did not, the security gap given for those.
scored_cases() {
  local kind="$1" agreed="$2" missed="$3" security="${4:-no}" i
  for i in $(seq "$agreed"); do scored_case "$kind-agreed-$i.md" "$kind" yes no; done
  for i in $(seq "$missed"); do scored_case "$kind-missed-$i.md" "$kind" no "$security"; done
}

# Last results naming no case, so a case the stand-in gets wrong fails
# without blocking, as one that never passed does, and the exam can pass.
no_case_passed() {
  mkdir -p "$history/exam"
  printf '%s\n' '{"passed":[]}' >"$results"
}

@test "proof: 18 of 20 tries agreed is below the bar, its score kept and printed with each miss" {
  kind naming accept
  scored_cases naming 18 2
  no_case_passed
  run_exam
  [ "$status" -eq 0 ]
  [ "$(tail -n 2 <<<"$output" | head -n 1)" = "$(exam_score_line naming 20 18 0 false)" ]
  [ "$(jq -c '.scores.naming | {tries, agreed, misses: [.misses[] | .name]}' "$results")" = \
    '{"tries":20,"agreed":18,"misses":["naming-missed-1.md","naming-missed-2.md"]}' ]
  . "$lib/score.sh"
  ! is_bar_reached "$(jq -c '.scores.naming' "$results")"
}

@test "proof: 19 of 20 tries agreed reaches the bar; a case tuned on, one sent to the operator and one of no kind never count" {
  kind naming accept
  scored_cases naming 19 1
  seed_case seed.md
  sed -i 's/^route: agent$/kind: naming/' "$answers/seed.md"
  question_case nokind.md unknown yes
  no_case_passed
  run_exam
  [ "$status" -eq 0 ]
  grep -qxF -- "$(exam_score_line naming 20 19 0 true)" <<<"$output"
  [ "$(jq -c '.scores | keys' "$results")" = '["naming"]' ]
  [ "$(jq -c '.scores.naming.misses' "$results")" = \
    '[{"name":"naming-missed-1.md","summary":"Case naming-missed-1.","security":false}]' ]
  . "$lib/score.sh"
  is_bar_reached "$(jq -c '.scores.naming' "$results")"
  # The same cases, sent to the operator by an always-yours route, are no
  # tries at all.
  kind naming ask
  run_exam
  [ "$status" -eq 0 ]
  [ "$(jq -c '.scores' "$results")" = '{}' ]
}

@test "proof: a try the operator turned down for a security gap holds the kind below the bar, whatever the score" {
  kind naming accept
  scored_cases naming 39 1 yes
  no_case_passed
  run_exam
  [ "$status" -eq 0 ]
  grep -qxF -- "$(exam_score_line naming 40 39 1 false)" <<<"$output"
  . "$lib/score.sh"
  ! is_bar_reached "$(jq -c '.scores.naming' "$results")"
  # A miss whose case does not say no counts as one, so a missing mark can
  # only hold a kind back.
  sed -i '/^security-gap: /d' "$answers/naming-missed-1.md"
  run_exam
  grep -qxF -- "$(exam_score_line naming 40 39 1 false)" <<<"$output"
}

@test "a case is a try where most of its replays settled it alone, and no try where most did not" {
  . "$lib/score.sh"
  case_json="$(jq -cn '{name: "a.md", kind: "naming", picked_recommended: "yes", tuning_used: false, security_gap: "no", summary: "A."}')"
  [ "$(to_score_row "$case_json" '{"runs":3,"alone":2}' | jq -c '{kind, agreed, security}')" = \
    '{"kind":"naming","agreed":true,"security":false}' ]
  [ -z "$(to_score_row "$case_json" '{"runs":3,"alone":1}')" ]
  [ -z "$(to_score_row "$(jq -c '.tuning_used = true' <<<"$case_json")" '{"runs":3,"alone":3}')" ]
}
