#!/usr/bin/env bash
# The fixed forms the stand-in's agents fill — the reader's, the sorter's, the
# checker's, the matcher's, the reading's and the summary's — in one place:
# every field and its JSON type, from which both the schema a model answers
# to and the check in code are drawn, so the two can never disagree on what a
# form holds. What each field means is the prompts' to say. Sourced, never
# executed.

# The reader's form. asks_operator: the reply puts a question to the operator
# that waits for their answer. question: that question in one sentence.
# options: the option labels the reply names, in its order. recommended: the
# label it recommends. claims_done: it says the work is finished.
# guidance_answer: its answer to a challenge about proposed guidance.
READER_FORM_FIELDS='{
  "asks_operator": "boolean",
  "question": "string",
  "options": "array",
  "recommended": "string",
  "claims_done": "boolean",
  "guidance_answer": "string"
}'

# The words an answer to a guidance challenge may be, the empty one for a
# reply that answers none. Keeping part of a proposal is told apart from
# keeping all of it so the log shows which, though both count as keeping.
GUIDANCE_DROP="drop"
GUIDANCE_KEEP_PART="keep-part"
GUIDANCE_KEEP_ALL="keep-all"
GUIDANCE_ANSWERS="[\"$GUIDANCE_DROP\", \"$GUIDANCE_KEEP_PART\", \"$GUIDANCE_KEEP_ALL\", \"\"]"

# The sorter's answer. kind: one kind of question from the preset. unsure:
# the sorter could not tell. risks: the preset's risks the recommended option
# carries.
SORTER_ANSWER_FIELDS='{
  "kind": "string",
  "unsure": "boolean",
  "risks": "array"
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

# The summary reader's answer. summary: the exchange between the stand-in and
# the agent over one question, told short and plain for the operator. Never
# decided from: it is shown, and only checked to be there.
SUMMARY_ANSWER_FIELDS='{
  "summary": "string"
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

# The schema the reader answers to.
reader_form_schema() {
  to_form_schema "$READER_FORM_FIELDS" "$(jq -cn --argjson words "$GUIDANCE_ANSWERS" \
    '{guidance_answer: {enum: $words}}')"
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
  breaks="$(to_item_schema "$CHECKER_BREAK_FIELDS" "$(jq -cn --argjson names "$1" '{entry: {enum: $names}}')")"
  miscalled="$(to_item_schema "$CHECKER_MISCALLED_FIELDS" '{}')"
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
