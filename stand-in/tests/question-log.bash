# Lines of the question log written by the suite itself, for the cases the
# gate cannot reach: no question is ever settled while every kind is on
# trial, so a settled line is made here. Loaded by the suites, never run
# alone.

# A log line, given its number, outcome, session, when (UTC), and the answer
# approved; the question, its retelling and the summary's problem are derived
# from the number, so each line is told apart by them.
log_line() {
  jq -cn --argjson number "$1" --arg outcome "$2" --arg session "$3" --arg when "$4" --arg approved "${5:-five}" \
    --argjson briefs "${6:-[]}" '{
      id: ("id-\($number)"), number: $number, when: $when, session: $session, briefs: $briefs,
      question: "Five retries or ten? (\($number))", retold: "Should a call be tried five or ten times? (\($number))",
      kind: "defaults", unsure: false, risks: [], checks: [],
      ladder: {first: {options: ["five", "ten"], recommended: "five"}, picks: [{pick: "item", item: "five"}, {pick: "item", item: "five"}]},
      exchange: [{from: "agent", text: "Five or ten? I recommend five. (\($number))"}, {from: "stand-in", text: "From the stand-in: Sure?"}, {from: "agent", text: "Five."}],
      outcome: $outcome, reasons: [], approved: $approved,
      summary: {problem: "A call fails now and then. (\($number))", first_recommendation: "Five tries.",
        what_moved_it: "Nothing.", recommends_now: "Five tries.", operators_call: "Five or ten; no risk was named."},
      reading: null, answer: ""
    }'
}

# Lines added to the log of the working folder given, as written.
add_log_lines() {
  mkdir -p "$1/log"
  printf '%s\n' "${@:2}" >>"$1/log/questions.jsonl"
}
