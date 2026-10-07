#!/usr/bin/env bash
# The fixed forms the stand-in's agents fill — the reader's, the sorter's and
# its labelling of a step's report, the checker's, the matcher's, the
# reading's, the summary's, the round reader's, the closing reader's, the
# case-writer's and the secret check's — in one place:
# every field and its JSON type, from which both the schema a model answers
# to and the check in code are drawn, so the two can never disagree on what a
# form holds. What each field means is the prompts' to say. Sourced, never
# executed.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_FORMS:-}" ] || return 0
STAND_IN_LOADED_FORMS=1

# The reader's form. asks_operator: the reply puts a question to the operator
# that waits for their answer. question: that question in one sentence.
# options: the option labels the reply names, in its order. recommended: the
# label it recommends. claims_done: it says the whole brief, or all its work,
# is finished, which starts the closing loop (settled 2026-10-06).
# closes_round: it says the round of questions is over and asks the operator
# whether to start building, whose answer is always theirs and reaches them
# with every decision of the round laid out (settled 2026-10-06).
# guidance_answer: its answer to a challenge about proposed guidance.
#
# And, for a reply that reports a step of the work finished (settled
# 2026-10-06, the step go): ends_step: it ends a step and waits for the
# operator's go to the next. problems: each problem it says it found, {problem,
# state}, the state fixed, unfixed, or needing a decision. proof: whether the
# step's proof passed, failed, or neither is said. next_step: the step it
# proposes next, as it names it. next_step_number: that step's number in the
# brief, 0 where it gives none. next_step_from: whether that step is the
# brief's own next one or new work, empty where it says neither.
# next_step_marks: what it says that step does that is always the operator's.
READER_FORM_FIELDS='{
  "asks_operator": "boolean",
  "question": "string",
  "options": "array",
  "recommended": "string",
  "claims_done": "boolean",
  "closes_round": "boolean",
  "guidance_answer": "string",
  "ends_step": "boolean",
  "problems": "array",
  "proof": "string",
  "next_step": "string",
  "next_step_number": "number",
  "next_step_from": "string",
  "next_step_marks": "array"
}'

# The fields of one problem of a step's report, each a string.
PROBLEM_FIELDS='["problem", "state"]'

# The words a problem's state may be. Unfixed is told apart from needing a
# decision because the two go different ways: one is fixed by the agent, the
# other asked of the operator.
PROBLEM_FIXED="fixed"
PROBLEM_UNFIXED="unfixed"
PROBLEM_NEEDS_DECISION="needs-decision"
PROBLEM_STATES="[\"$PROBLEM_FIXED\", \"$PROBLEM_UNFIXED\", \"$PROBLEM_NEEDS_DECISION\"]"

# The words proof may be, the empty one where the reply says neither: a proof
# never mentioned is not one that passed.
STEP_PROOF_PASSED="passed"
STEP_PROOF_FAILED="failed"
STEP_PROOFS="[\"$STEP_PROOF_PASSED\", \"$STEP_PROOF_FAILED\", \"\"]"

# The words next_step_from may be, the empty one where the reply says neither.
STEP_FROM_BRIEF="brief"
STEP_FROM_NEW_WORK="new-work"
STEP_FROMS="[\"$STEP_FROM_BRIEF\", \"$STEP_FROM_NEW_WORK\", \"\"]"

# The words a mark on the next step may be: what makes its go always the
# operator's (settled 2026-10-06): it pushes, syncs or deletes, touches
# another session's work, or is one the brief runs alone at a quiet moment.
# Read off the reply, since no brief marks a step so in a form code could
# read.
STEP_MARKS='["pushes", "syncs", "deletes", "other-session", "runs-alone"]'

# The sorter's labelling of a step's report. majors: every major problem in
# it, fixed or not, each {problem, label}, the label one of the preset's risks
# or one of the two below. unsure: the sorter could not tell whether some
# problem is major, which counts as major.
STEP_SORT_FIELDS='{
  "majors": "array",
  "unsure": "boolean"
}'

# The fields of one major problem, each a string.
MAJOR_FIELDS='["problem", "label"]'

# The two labels a major problem may carry beside the preset's risks: lost
# data, and a check that passed before now failing.
STEP_LOST_DATA="lost-data"
STEP_BROKEN_CHECK="broken-check"

# The separator between a row's parts: the ASCII unit separator, which no
# problem a model writes is expected to hold and bash never collapses.
STEP_US=$'\037'

# The words an answer to a guidance challenge may be, the empty one for a
# reply that answers none. Keeping part of a proposal is told apart from
# keeping all of it so the log shows which, though both count as keeping.
GUIDANCE_DROP="drop"
GUIDANCE_KEEP_PART="keep-part"
GUIDANCE_KEEP_ALL="keep-all"
GUIDANCE_ANSWERS="[\"$GUIDANCE_DROP\", \"$GUIDANCE_KEEP_PART\", \"$GUIDANCE_KEEP_ALL\", \"\"]"

# The sorter's answer. kind: one kind of question from the preset. unsure:
# the sorter could not tell. risks: the preset's risks the recommended option
# carries. defers: the recommended option puts work off — to later, to a
# pending line, or to another session — which a kind whose recommendation
# stands unchallenged still brings to the operator (settled 2026-10-06: their
# own habit is to push toward doing it now). The sorter's to say rather than
# the reader's, since it weighs the recommended option already, for its risks.
SORTER_ANSWER_FIELDS='{
  "kind": "string",
  "unsure": "boolean",
  "risks": "array",
  "defers": "boolean"
}'

# The checker's answer. breaks: the entries an option or the recommendation
# breaks, each {entry, why}. miscalled: what the reply calls a rule, a
# convention or settled that no entry is, each {called, actually}.
# explains_code: the question proposes a convention sentence that tells how
# some code works rather than what must stay true.
CHECKER_ANSWER_FIELDS='{
  "breaks": "array",
  "miscalled": "array",
  "explains_code": "boolean"
}'

# The cold second reading's answer. reading: what the reading found, as it
# writes it for the operator. Never decided from: it is shown beside the
# ladder's answers, and only checked to be there.
READING_ANSWER_FIELDS='{
  "reading": "string"
}'

# The matcher's answer, for a reply on a ladder rung after the first. pick:
# what the reply now recommends, against the first rung's option list — an
# item of that list, a new choice, or no longer asking the question. item: the
# item, exactly as listed, where pick says it is one; empty otherwise. Two
# fields rather than one word that is either an item or a verdict: an option
# a reply happens to call "new" would otherwise read as a verdict.
MATCHER_ANSWER_FIELDS='{
  "pick": "string",
  "item": "string"
}'

# The words pick may be. A choice whose substance changed, or an option added
# to the list or dropped from it, is new: the same choice in other words is
# the same item, and only a model reading both can tell which a rewording is.
MATCH_ITEM="item"
MATCH_NEW="new"
MATCH_NOT_ASKING="not-asking"
MATCH_PICKS="[\"$MATCH_ITEM\", \"$MATCH_NEW\", \"$MATCH_NOT_ASKING\"]"

# The summary reader's answer: the operator's message in fixed parts, each
# told plainly from the whole exchange between the stand-in and the agent
# over one question (settled 2026-10-06). problem: what the question is about,
# with an everyday example. first_recommendation: what the agent first
# recommended. what_moved_it: what moved it and why, in the agent's own
# reasons, or that nothing did. recommends_now: what it recommends at the end.
# operators_call: the call left to the operator, each option with its risk.
# Fixed parts rather than one free paragraph, so every question reaches the
# operator in the same order and a part left out is a refused form, never a
# gap they would have to notice. Never decided from: it is shown, and only
# checked to be there.
SUMMARY_ANSWER_FIELDS='{
  "problem": "string",
  "first_recommendation": "string",
  "what_moved_it": "string",
  "recommends_now": "string",
  "operators_call": "string"
}'

# The round reader's answer, for a reply that closes a round of questions and
# asks to build: decisions, one {number, decision} for every decision of the
# round it was handed, the number as handed and the decision in one short
# everyday line. Numbered rather than listed in order, so a line dropped,
# repeated or moved is a refused form, never a decision shown under another's
# number. Never decided from: it is shown, and only checked to be whole.
ROUND_ANSWER_FIELDS='{
  "decisions": "array"
}'

# The fields of one decision of the round's list.
ROUND_DECISION_FIELDS='["number", "decision"]'

# The closing reader's form, for a reply to one look of the closing loop
# (settled 2026-10-06): findings, every thing the reply says it found, each {finding, sort,
# files, brief}: what it is, the sort the agent gave it by the filter below,
# the files or folders it touches as paths from the project root, and for a
# hand-off the brief it goes to. nothing_left: the reply says nothing that
# belongs to the brief is left. The agent sorts and code checks what it can,
# never a model: a reader only copies the agent's sort, so the filter stays
# the agent's judgement and the checks on it stay in code.
LOOK_FORM_FIELDS='{
  "findings": "array",
  "nothing_left": "boolean"
}'

# The fields of one finding.
FINDING_FIELDS='["finding", "sort", "files", "brief"]'

# The sorts a finding may be, by decision 2's filter: belongs to this brief,
# and goes through the gate as a question; belongs elsewhere and is already
# written down, in another brief or the notes, and is dropped; a place the new
# thing could also be used that is not the same job, and is dropped, since
# the second look adopts the new thing only where it replaces hand-made
# copies of itself; written down nowhere and quick (no decision, a few lines
# in one module, nobody else's uncommitted edits in its files), and fixed in
# passing; a place to use the new thing in an area another session works in,
# handed off into that session's brief; anything else, parked as a line in
# the notes or asked about as a brief of its own. And unsorted, where the
# reply gives none: the reader says so rather than guess, and the check
# refuses the form.
FINDING_HERE="here"
FINDING_WRITTEN_DOWN="written-down"
FINDING_NOT_SAME_JOB="not-same-job"
FINDING_QUICK="quick"
FINDING_HAND_OFF="hand-off"
FINDING_PARK="park"
FINDING_UNSORTED="unsorted"
FINDING_SORTS="[\"$FINDING_HERE\", \"$FINDING_WRITTEN_DOWN\", \"$FINDING_NOT_SAME_JOB\", \"$FINDING_QUICK\", \"$FINDING_HAND_OFF\", \"$FINDING_PARK\", \"$FINDING_UNSORTED\"]"

# The case-writer's form, for one answered question of a finished brief
# (settled 2026-10-06, decision 6). answers: the operator's answer answers the
# question clearly; false for an unclear answer, or one that asks or says
# something else, which is skipped, never guessed. The rest is empty where it
# does not, and otherwise the case in clean words: title, a short name for it;
# summary, one line of what it is about; reply, the agent's question retold
# whole enough to be read, checked and sorted again, or its step's report
# retold as a report, to be read and weighed for the go again; options, its
# option labels; recommended, the one the agent recommended; answered, the
# operator's answer; picked, the option it picks, empty where it picks none of
# them; security_gap, whether they turned the recommendation down because it
# would open a security gap, the mark a kind's score is barred by (decision
# 8: never a pick that would have opened one), read off their answer since
# no other part of a case can say it; why, the operator's reason, empty
# where neither they nor the exchange give one. Retold, never copied: the log holds raw agent text and the
# operator's typing, and a case is committed (settled 2026-10-01/02: meaning
# only, never raw text).
CASE_FORM_FIELDS='{
  "answers": "boolean",
  "title": "string",
  "summary": "string",
  "reply": "string",
  "options": "array",
  "recommended": "string",
  "answered": "string",
  "picked": "string",
  "security_gap": "boolean",
  "why": "string"
}'

# The lines a case file marks the agent's reply with, as the two seed cases
# do: what lies between them is what a replay hands the reader, so a reply
# holding either line is refused, never cut where it would be misread.
CASE_REPLY_START="=====REPLY START====="
CASE_REPLY_END="=====REPLY END====="

# The secret check's answer: whether the case holds anything secret. A yes or
# no alone, never what it found: an answer naming the secret would be one
# more copy of it, kept wherever the answer goes.
SECRET_ANSWER_FIELDS='{
  "holds_secret": "boolean"
}'

# The fields of one item of each of the checker's lists, every one a string.
CHECKER_BREAK_FIELDS='["entry", "why"]'
CHECKER_MISCALLED_FIELDS='["called", "actually"]'

# --- Transforms.

# A schema for the fields given, every one required and nothing else allowed;
# an array is one of strings. The extras, keyed by field, are merged into that
# field's schema.
to_form_schema() {
  jq -cn --argjson fields "$1" --argjson extras "$2" '{
    type: "object",
    properties: ($fields | with_entries(
      .key as $name
      | .value = (
          (if .value == "array" then {type: "array", items: {type: "string"}} else {type: .value} end)
          * ($extras[$name] // {})
        )
    )),
    required: ($fields | keys_unsorted),
    additionalProperties: false
  }'
}

# The schema the reader answers to. A problem's item schema replaces the
# string items every form array has by default.
reader_form_schema() {
  local problem
  problem="$(to_item_schema "$PROBLEM_FIELDS" "$(jq -cn --argjson states "$PROBLEM_STATES" '{state: {enum: $states}}')")" || return 1
  to_form_schema "$READER_FORM_FIELDS" "$(jq -cn --argjson words "$GUIDANCE_ANSWERS" \
    --argjson problem "$problem" --argjson proofs "$STEP_PROOFS" --argjson froms "$STEP_FROMS" \
    --argjson marks "$STEP_MARKS" \
    '{guidance_answer: {enum: $words}, problems: {items: $problem}, proof: {enum: $proofs},
      next_step_number: {type: "integer", minimum: 0}, next_step_from: {enum: $froms},
      next_step_marks: {items: {type: "string", enum: $marks}}}')"
}

# The schema the sorter answers to for a step's report, given the label names
# as a JSON array.
step_sort_schema() {
  local major
  major="$(to_item_schema "$MAJOR_FIELDS" "$(jq -cn --argjson labels "$1" '{label: {enum: $labels}}')")" || return 1
  to_form_schema "$STEP_SORT_FIELDS" "$(jq -cn --argjson major "$major" '{majors: {items: $major}}')"
}

# The schema the sorter answers to, given the kind names and the risk names
# the preset holds, each as a JSON array.
sorter_answer_schema() {
  to_form_schema "$SORTER_ANSWER_FIELDS" "$(jq -cn --argjson kinds "$1" --argjson risks "$2" \
    '{kind: {enum: $kinds}, risks: {items: {type: "string", enum: $risks}}}')"
}

# The schema for one list item whose fields are all strings, given the field
# names as a JSON array; the extras, keyed by field, are merged into that
# field's schema.
to_item_schema() {
  jq -cn --argjson fields "$1" --argjson extras "$2" '{
    type: "object",
    properties: (reduce $fields[] as $name ({}; .[$name] = ({type: "string"} * ($extras[$name] // {})))),
    required: $fields,
    additionalProperties: false
  }'
}

# The schema the checker answers to, given the entry names it was handed as a
# JSON array: a broken entry is named as it was handed, or not at all. The
# item's schema replaces the string items every form array has by default.
checker_answer_schema() {
  local breaks miscalled
  breaks="$(to_item_schema "$CHECKER_BREAK_FIELDS" "$(jq -cn --argjson names "$1" '{entry: {enum: $names}}')")" || return 1
  miscalled="$(to_item_schema "$CHECKER_MISCALLED_FIELDS" '{}')" || return 1
  to_form_schema "$CHECKER_ANSWER_FIELDS" "$(jq -cn --argjson breaks "$breaks" --argjson miscalled "$miscalled" \
    '{breaks: {items: $breaks}, miscalled: {items: $miscalled}}')"
}

# The schema the cold second reading answers to.
reading_answer_schema() {
  to_form_schema "$READING_ANSWER_FIELDS" '{}'
}

# The schema the matcher answers to, given the first rung's option labels as a
# JSON array: an item is one of them as listed, or empty. Each value once, as
# a schema's list of allowed values must be, whatever the reply repeated.
matcher_answer_schema() {
  to_form_schema "$MATCHER_ANSWER_FIELDS" "$(jq -cn --argjson picks "$MATCH_PICKS" --argjson options "$1" \
    '{pick: {enum: $picks}, item: {enum: ($options + [""] | unique)}}')"
}

# The schema the summary reader answers to.
summary_answer_schema() {
  to_form_schema "$SUMMARY_ANSWER_FIELDS" '{}'
}

# The schema the closing reader answers to, given the briefs other sessions
# hold as a JSON array of names: a hand-off goes to one of them, or the brief
# is empty.
look_form_schema() {
  local finding
  finding="$(jq -cn --argjson sorts "$FINDING_SORTS" --argjson briefs "$1" --argjson fields "$FINDING_FIELDS" '{
    type: "object",
    properties: {
      finding: {type: "string"},
      sort: {type: "string", enum: $sorts},
      files: {type: "array", items: {type: "string"}},
      brief: {type: "string", enum: ($briefs + [""] | unique)}
    },
    required: $fields,
    additionalProperties: false
  }')"
  to_form_schema "$LOOK_FORM_FIELDS" "$(jq -cn --argjson finding "$finding" '{findings: {items: $finding}}')"
}

# The schema the round reader answers to, given the decisions' numbers as a
# JSON array: a number is one of them, or not at all.
round_answer_schema() {
  local decision
  decision="$(to_item_schema "$ROUND_DECISION_FIELDS" "$(jq -cn --argjson numbers "$1" \
    '{number: {type: "integer", enum: $numbers}}')")"
  to_form_schema "$ROUND_ANSWER_FIELDS" "$(jq -cn --argjson decision "$decision" '{decisions: {items: $decision}}')"
}

# The schema the case-writer answers to.
case_form_schema() {
  to_form_schema "$CASE_FORM_FIELDS" '{}'
}

# The schema the secret check answers to.
secret_answer_schema() {
  to_form_schema "$SECRET_ANSWER_FIELDS" '{}'
}
