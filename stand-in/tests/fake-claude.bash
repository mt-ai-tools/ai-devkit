# A throwaway project and a `claude` of the suite's own, so no suite ever asks
# a real model: the fake prints the envelope Claude Code prints, around an
# answer the test chooses, and keeps the arguments and the prompt it was given
# for the test to look at. Loaded by the suites, never run alone.

setup_fake_claude() {
  script="$BATS_TEST_DIRNAME/../bin/stand-in.sh"
  lib="$BATS_TEST_DIRNAME/../lib"
  project="$BATS_TEST_TMPDIR/project"
  mkdir -p "$project" "$BATS_TEST_TMPDIR/elsewhere"
  export CLAUDE_PROJECT_DIR="$project"
  cd "$BATS_TEST_TMPDIR/elsewhere"
  fakebin="$BATS_TEST_TMPDIR/fakebin"
  mkdir -p "$fakebin"
  export FAKE_ARGS="$BATS_TEST_TMPDIR/claude-args"
  export FAKE_PROMPT="$BATS_TEST_TMPDIR/claude-prompt"
  export FAKE_STANDING="$BATS_TEST_TMPDIR/claude-standing"
  export FAKE_CALLS="$BATS_TEST_TMPDIR/claude-calls"
  export FAKE_ANSWERS="$BATS_TEST_TMPDIR/claude-answers"
  mkdir -p "$FAKE_ANSWERS"
  # FAKE_ENVELOPE, when set, is printed as it stands in place of the envelope;
  # FAKE_STATUS is the status the fake ends with; FAKE_SLEEP holds it up. Where
  # one run asks several jobs, each job's answer and status may be given apart,
  # by answer_for and status_for, and a job asked several times in one run
  # may be given an answer for each call apart, by answer_for_call: the job
  # is told by the first field its schema requires, since two jobs may run on
  # one model. Every call is logged
  # in turn as "<job> <model>", and its arguments, its prompt, the text added
  # to Claude Code's own instructions where one was, and the folder it ran in
  # kept under the job's name.
  cat >"$fakebin/claude" <<'FAKE'
#!/usr/bin/env bash
model="" schema="" standing="" previous=""
for arg in "$@"; do
  [ "$previous" = --model ] && model="$arg"
  [ "$previous" = --json-schema ] && schema="$arg"
  [ "$previous" = --append-system-prompt-file ] && standing="$arg"
  previous="$arg"
done
case "$(jq -r '.required[0] // empty' <<<"$schema" 2>/dev/null)" in
  asks_operator) job=reader ;;
  breaks) job=checker ;;
  kind) job=sorter ;;
  reading) job=reading ;;
  pick) job=matcher ;;
  problem) job=summary ;;
  majors) job=step-sorter ;;
  decisions) job=round ;;
  findings) job=closing ;;
  answers) job=case-writer ;;
  holds_secret) job=secret ;;
  *) job=other ;;
esac
# Logged, counted and kept under a lock: the exam asks a part several times
# side by side, and two calls counting at once would take the same turn, or
# one call's kept prompt be read half-written by another's copy.
exec 9>>"$FAKE_CALLS.lock"
flock 9
printf '%s %s\n' "$job" "$model" >>"$FAKE_CALLS"
turn="$(grep -c "^$job " "$FAKE_CALLS")"
printf '%s\n' "$@" >"$FAKE_ARGS"
cp "$FAKE_ARGS" "$FAKE_ARGS.$job"
cat >"$FAKE_PROMPT"
cp "$FAKE_PROMPT" "$FAKE_PROMPT.$job"
[ -z "$standing" ] || cat "$standing" >"$FAKE_STANDING.$job"
pwd >"$FAKE_ARGS.$job.pwd"
flock -u 9
[ -n "${FAKE_SLEEP:-}" ] && sleep "$FAKE_SLEEP"
[ -f "$FAKE_ANSWERS/$job.status" ] && exit "$(cat "$FAKE_ANSWERS/$job.status")"
if [ -n "${FAKE_ENVELOPE+set}" ]; then
  printf '%s' "$FAKE_ENVELOPE"
else
  answer="${FAKE_ANSWER:-null}"
  [ -f "$FAKE_ANSWERS/$job" ] && answer="$(cat "$FAKE_ANSWERS/$job")"
  [ -f "$FAKE_ANSWERS/$job.$turn" ] && answer="$(cat "$FAKE_ANSWERS/$job.$turn")"
  jq -cn --argjson answer "$answer" \
    '{type: "result", is_error: false, result: ($answer | tojson), structured_output: $answer}'
fi
exit "${FAKE_STATUS:-0}"
FAKE
  chmod +x "$fakebin/claude"
  export PATH="$fakebin:$PATH"
}

# The answer the fake gives when the job named is asked: reader, checker,
# sorter, reading, matcher, summary, step-sorter, round, closing, case-writer
# or secret.
answer_for() {
  printf '%s' "$2" >"$FAKE_ANSWERS/$1"
}

# The answer the fake gives the job named on its call of the number given,
# counted from 1, over the job's answer for every call.
answer_for_call() {
  printf '%s' "$3" >"$FAKE_ANSWERS/$1.$2"
}

# The status the fake ends with when the job named is asked, answering
# nothing.
status_for() {
  printf '%s' "$2" >"$FAKE_ANSWERS/$1.status"
}

# The calls so far, one "<job> <model>" line each, in order.
calls() {
  cat "$FAKE_CALLS" 2>/dev/null || true
}

# A preset of the suite's own, with the kinds and risks given, so no suite
# leans on the kit's own preset: the stand-in must hand over whatever a
# project's preset holds. Kinds as "name:summary" words, a summary of one
# word; risks as names. Its ladder file holds the three messages below, and
# its closing loop the three after them, and its resume look-around the one
# after those, each under the short name the stand-in asks for it by.
preset() {
  local kinds="$1" risks="$2" kind name
  preset_dir="$BATS_TEST_TMPDIR/preset"
  mkdir -p "$preset_dir/questions" "$preset_dir/challenges"
  for kind in $kinds; do
    printf -- '---\nsummary: %s\nroute: ask\n---\n\n# %s\n' "${kind#*:}" "${kind%%:*}" \
      >"$preset_dir/questions/${kind%%:*}.md"
  done
  {
    printf -- '---\nsummary: Risks.\n---\n\n# Risks\n\n'
    for name in $risks; do printf -- '- `%s` — The %s risk.\n' "$name" "$name"; done
  } >"$preset_dir/challenges/risks.md"
  ladder_file "$standing_test" "$are_you_sure" "$bigger_look" \
    >"$preset_dir/challenges/challenge-ladder.md"
  closing_file "$cleanup_look" "$use_look" "$whole_done" >"$preset_dir/challenges/closing-loop.md"
  resume_file "$look_around" >"$preset_dir/challenges/resume-look-around.md"
  printf 'AIDK_STAND_IN=%s\n' "$preset_dir" >"$project/aidk-config.env"
}

# A closing loop file's text holding the three messages given, in the order
# the kit's own file holds them, each quoted under its short name.
closing_file() {
  printf -- '---\nsummary: Closing.\n---\n\n# Closing\n\n'
  printf -- '- `whole-brief-done` — first:\n  > %s\n\n' "$3"
  printf -- '1. `cleanup-look` — the cleanup:\n   > %s\n' "$1"
  printf -- '2. `use-look` — then:\n   > %s\n' "$2"
}

# A resume look-around file's text holding the message given, quoted under
# its short name.
resume_file() {
  printf -- '---\nsummary: Resume.\n---\n\n# Resume\n\n'
  printf -- '- `look-around` — once the wait is over:\n  > %s\n' "$1"
}

# A ladder file's text holding the three messages given, in the order the
# kit's own file holds them, each quoted under its short name.
ladder_file() {
  printf -- '---\nsummary: Ladder.\n---\n\n# Ladder\n\n1. First.\n'
  printf -- '2. `standing-test` — the test:\n   > %s\n' "$1"
  printf -- '3. `are-you-sure` — then:\n   > %s\n\n' "$2"
  printf -- '- `bigger-look` — when it moved:\n  > %s\n' "$3"
}

# The messages the suite's preset ladder sends.
standing_test="Is it the clean way?"
are_you_sure="Sure?"
bigger_look="Look around more."

# The messages the suite's preset closing loop sends.
cleanup_look="Anything to tidy?"
use_look="Use the new thing everywhere?"
whole_done="All of it done?"

# The message the suite's preset resume look-around sends.
look_around="Things moved. Look again."

# A whole summary's answer, each part told apart by its words.
summary_form() {
  printf '%s' '{"problem":"A call fails now and then. Like redialling a busy number.","first_recommendation":"Five tries.","what_moved_it":"Nothing.","recommends_now":"Five tries.","operators_call":"Five or ten; no risk was named for either."}'
}

# A whole reader's form asking which of two options, recommending the first.
whole_form() {
  printf '%s' '{"asks_operator":true,"question":"Five retries or ten?","options":["five","ten"],"recommended":"five","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":false,"problems":[],"proof":"","next_step":"","next_step_number":0,"next_step_from":"","next_step_marks":[]}'
}

# A whole reader's form of a reply that ends a step and asks nothing: no
# problem, the proof passed, the brief's own step 9 next. A jq filter given is
# applied to it.
step_form() {
  jq -c "${1:-.}" <<<'{"asks_operator":false,"question":"","options":[],"recommended":"","claims_done":false,"closes_round":false,"guidance_answer":"","ends_step":true,"problems":[],"proof":"passed","next_step":"step 9, the round list","next_step_number":9,"next_step_from":"brief","next_step_marks":[]}'
}
