#!/usr/bin/env bash
# The test cases: which questions of a finished brief become one, what a case
# file says, what it is called, and the folder of them in the stand-in's
# working folder, which the project commits. Sourced, never executed.
#
# A case is one question the operator answered, kept so that a change to the
# stand-in can later be replayed against it, and a kind's trial scored on it
# (settled 2026-10-01/02, decision 6). Its shape is the seed cases': a header
# of one-line fields, then the agent's reply between two marker lines, the
# operator's answer and why. The header holds what code will read: summary;
# date, the day the question was let go; brief; kind, as it was sorted when
# asked; alone, yes where the stand-in would have settled it without the
# operator when it was asked; picked-recommended, yes where the operator
# picked the option the agent recommended, which is what the stand-in settles
# on, so whether it agreed with them; security-gap, yes where they turned the
# recommendation down because it would open a security gap, which no kind's
# score may hold (decision 8); tuning, none until a prompt is adjusted on the
# case, after which it never counts toward a score; and log-id, the line it
# was written from, so no line is written twice. Nothing more: what scoring
# needs beyond these, a replay finds out, whether the stand-in as it now
# stands would have answered alone above all, which is what makes it a try.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_CASES:-}" ] || return 0
STAND_IN_LOADED_CASES=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/forms.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/session-id.sh"

# The entry's command that writes the cases, as the agent types it after the
# entry's path.
CASES_COMMAND="write-cases"

# The cases' folder inside the stand-in's working folder. Unlike the rest of
# that folder it is committed: the cases are the stand-in's exam, worth as
# much on every machine as on the one that wrote them.
CASES_SUBFOLDER="answers"

# The longest a case's name may run after its date, in characters, cut at a
# word: long enough to tell cases apart in a listing, short enough to read.
CASE_SLUG_LENGTH=60

# A case's name where its title holds no letter or digit to name it by.
CASE_SLUG_FALLBACK="case"

# The header fields of a case, each spelled here alone: the case-writer
# writes them and the exam reads them, and a name spelled in each would let
# one be renamed while the other still looks for the old. The line it was
# written from is named by its log id.
CASE_SUMMARY_FIELD="summary"
CASE_DATE_FIELD="date"
CASE_BRIEF_FIELD="brief"
CASE_KIND_FIELD="kind"
CASE_ALONE_FIELD="alone"
CASE_PICKED_FIELD="picked-recommended"
CASE_SECURITY_FIELD="security-gap"
CASE_TUNING_FIELD="tuning"
CASE_LOG_ID_FIELD="log-id"
# The fields only the seed cases hold, written by hand and read alone: the
# route a case must take, the findings the rules and conventions check must
# give, and the entries it must name as broken.
CASE_ROUTE_FIELD="route"
CASE_FINDINGS_FIELD="findings"
CASE_BREAKS_FIELD="breaks"

# --- Transforms.

# The cases' folder, from the stand-in's working folder.
to_cases_dir() {
  printf '%s/%s\n' "$1" "$CASES_SUBFOLDER"
}

# The log's lines that become cases, one per line, in log order, given the
# log's lines and the briefs finished, as a JSON array: every question of
# those briefs that reached the operator and was answered. A request to start
# building, a closing round and the question whether a kind may answer
# alone are no cases: their decision is the operator's whatever any kind's
# trial says, so they are never a try. A
# question settled without the operator, or a proposal dropped, never reached
# them, so holds no answer of theirs to learn from.
to_case_lines() {
  local mine
  mine="$(to_brief_log_lines "$1" "$2")" || return 1
  [ -n "$mine" ] || return 0
  jq -c --arg operator "$OUTCOME_TO_OPERATOR" --arg held "$OUTCOME_WOULD_HAVE_APPROVED" '
    select((.outcome == $operator or .outcome == $held) and (.answer // "") != ""
      and .round == null and .closing == null and .trust == null)' <<<"$mine"
}

# The name a case is called by after its date, from its title: lower-case
# words joined by hyphens, cut at a word.
to_case_slug() {
  jq -rn --arg title "$1" --argjson length "$CASE_SLUG_LENGTH" --arg fallback "$CASE_SLUG_FALLBACK" '
    ($title | ascii_downcase | gsub("[^a-z0-9]+"; "-") | gsub("^-+|-+$"; "")) as $slug
    | (if ($slug | length) > $length then $slug[0:$length] | sub("-[^-]*$"; "") else $slug end) as $cut
    | if $cut == "" then $fallback else $cut end'
}

# The day a log line was written, as a case's date: the first ten characters
# of its time, which the log writes in UTC.
to_case_date() {
  jq -r '.when[0:10]' <<<"$1"
}

# A case file's whole text, given the log line and the case-writer's checked
# form. Every header value is held to one line, whatever the log holds.
to_case_text() {
  local line="$1" form="$2" alone picked_recommended security fields
  alone="$(case_no_words)"
  [ "$(jq -r '.outcome' <<<"$line")" != "$OUTCOME_WOULD_HAVE_APPROVED" ] || alone="$(case_yes_words)"
  picked_recommended="$(case_no_words)"
  ! jq -e '.picked != "" and .picked == .recommended' >/dev/null <<<"$form" || picked_recommended="$(case_yes_words)"
  security="$(case_no_words)"
  ! jq -e '.security_gap' >/dev/null <<<"$form" || security="$(case_yes_words)"
  fields="$(jq -cn --arg summary "$CASE_SUMMARY_FIELD" --arg date "$CASE_DATE_FIELD" --arg brief "$CASE_BRIEF_FIELD" \
    --arg kind "$CASE_KIND_FIELD" --arg alone "$CASE_ALONE_FIELD" --arg picked "$CASE_PICKED_FIELD" \
    --arg security "$CASE_SECURITY_FIELD" --arg tuning "$CASE_TUNING_FIELD" --arg id "$CASE_LOG_ID_FIELD" \
    '$ARGS.named')" || return 1
  jq -rn --argjson line "$line" --argjson form "$form" --arg alone "$alone" --arg picked "$picked_recommended" \
    --arg security "$security" --arg unknown "$(case_kind_unknown_words)" --arg tuning "$(case_tuning_none_words)" \
    --arg no_why "$(case_no_why_words)" --argjson field "$fields" \
    --arg start "$CASE_REPLY_START" --arg end "$CASE_REPLY_END" '
    def one_line: gsub("\\s+"; " ") | gsub("^ | $"; "");
    "---",
    "\($field.summary): \($form.summary | one_line)",
    "\($field.date): \($line.when[0:10] | one_line)",
    "\($field.brief): \(($line.briefs // []) | map(select(type == "string")) | join(", ") | one_line)",
    "\($field.kind): \(($line.kind // $unknown) | one_line)",
    "\($field.alone): \($alone)",
    "\($field.picked): \($picked)",
    "\($field.security): \($security)",
    "\($field.tuning): \($tuning)",
    "\($field.id): \($line.id | one_line)",
    "---",
    "",
    "# \($form.title | one_line)",
    "",
    "## Reply",
    "",
    $start,
    ($form.reply | sub("\\s+$"; "")),
    $end,
    "",
    "## The operator'"'"'s answer",
    "",
    ($form.answered | sub("\\s+$"; "")),
    "",
    "## Why",
    "",
    (if ($form.why | test("^\\s*$")) then $no_why else ($form.why | sub("\\s+$"; "")) end)'
}

# The counts a run of the case-writer leaves, as JSON.
to_case_counts() {
  jq -cn --argjson written "$1" --argjson skipped "$2" --argjson held "$3" --argjson failed "$4" \
    '{written: $written, skipped: $skipped, held: $held, failed: $failed}'
}

# The reply a case file's text holds, for a replay to hand the reader: the
# lines between its two marker lines, as written; nothing where it holds no
# whole pair, since a reply cut off at the end of the file would be a part of
# one read as the whole.
to_case_reply() {
  awk -v start="$CASE_REPLY_START" -v end="$CASE_REPLY_END" '
    inside && $0 == end { whole = 1; exit }
    inside { text = text $0 "\n" }
    !inside && $0 == start { inside = 1 }
    END { if (whole) printf "%s", text }
  ' <<<"$1"
}

# A header list, as a case writes one ("[a, b]"), as a JSON array of its
# items; an empty array for an empty value or "[]".
to_header_list() {
  jq -cn --arg value "$1" '$value | gsub("^\\s*\\[|\\]\\s*$"; "") | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))'
}

# A case as a replay reads it, given its file's name and text and its header
# fields as read_case reads them: kind, picked-recommended, whether its
# tuning is used, its brief or briefs, and, as the seed cases say them, the
# route it must take, the findings the rules and conventions check must give
# and the entries it must name as broken; then security-gap and its summary,
# as written, for its kind's score; then the reply. What a field means for
# the exam, and for the score, is theirs to say.
to_case() {
  local name="$1" text="$2" kind="$3" picked="$4" tuning="$5" brief="$6" route="$7" findings="$8" breaks="$9"
  local security="${10}" summary="${11}"
  jq -cn --arg name "$name" --arg kind "$kind" --arg picked "$picked" --arg tuning "$tuning" \
    --arg security "$security" --arg summary "$summary" \
    --arg used "$(case_tuning_used_words)" --arg brief "$brief" --arg route "$route" \
    --argjson findings "$(to_header_list "$findings")" --argjson breaks "$(to_header_list "$breaks")" \
    --rawfile reply <(to_case_reply "$text") '{
      name: $name, kind: $kind, picked_recommended: $picked,
      tuning_used: (($tuning | split(" ") | .[0] // "") == $used),
      briefs: ($brief | split(",") | map(gsub("^\\s+|\\s+$"; "")) | map(select(. != ""))),
      route: $route, findings: $findings, breaks: $breaks,
      security_gap: $security, summary: $summary, reply: $reply}'
}

# --- Reads.

# The path of the case already written from the log line whose id is given,
# in the folder given; nothing where none is. Read off each case's header, so
# a case renamed or moved by hand within the folder is still found.
find_case_path() {
  local dir="$1" id="$2" file
  [ -d "$dir" ] || return 0
  for file in "$dir"/*.md; do
    [ -f "$file" ] || continue
    if [ "$(read_header_fields "$file" "$CASE_LOG_ID_FIELD")" = "$id" ]; then
      printf '%s\n' "$file"
      return 0
    fi
  done
}

# Every case file in the folder given, one path a line, in name order;
# nothing where the folder holds none or does not exist.
list_case_files() {
  local file
  [ -d "$1" ] || return 0
  for file in "$1"/*.md; do
    [ -f "$file" ] || continue
    printf '%s\n' "$file"
  done
}

# A case file as to_case gives it; a refusal on stderr and a non-zero status
# where it cannot be read. The header's fields are read by the kit's one
# header reader, by the names to_case_text writes them under, and the seed
# cases' route, findings and breaks beside them.
read_case() {
  local file="$1" text kind picked tuning brief route findings breaks security summary
  if ! text="$(cat "$file" 2>/dev/null)"; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  IFS="$HEADER_US" read -r kind picked tuning brief route findings breaks security summary \
    < <(read_header_fields "$file" "$CASE_KIND_FIELD" "$CASE_PICKED_FIELD" "$CASE_TUNING_FIELD" "$CASE_BRIEF_FIELD" \
      "$CASE_ROUTE_FIELD" "$CASE_FINDINGS_FIELD" "$CASE_BREAKS_FIELD" "$CASE_SECURITY_FIELD" "$CASE_SUMMARY_FIELD")
  to_case "$(basename "$file")" "$text" "$kind" "$picked" "$tuning" "$brief" "$route" "$findings" "$breaks" \
    "$security" "$summary"
}

# The path a new case is written at, in the folder given, from its date, its
# title and its log line's id: the date and the title's name, or, where a
# case of that name stands already, with the id after it; a refusal on stderr
# and a non-zero status where that is taken too, or the id could name a path
# outside the folder.
find_free_case_path() {
  local dir="$1" date="$2" slug="$3" id="$4" path
  if ! is_session_id "$id"; then
    refuse_case_bad_id_note "$id" >&2
    return 1
  fi
  path="$dir/$date-$slug.md"
  [ ! -e "$path" ] || path="$dir/$date-$slug-$id.md"
  if [ -e "$path" ]; then
    refuse_cases_unwritable_note "$dir" >&2
    return 1
  fi
  printf '%s\n' "$path"
}

# --- Writes.

# Put a case file in place, given its path and text. Written to a hidden
# draft and moved over, so no reader ever finds half a case; one that cannot
# be written is refused on stderr with a non-zero status, and no draft left.
write_case_file() {
  local path="$1" text="$2" dir draft
  dir="$(dirname "$path")"
  draft="$dir/.$(basename "$path").$$"
  if ! mkdir -p "$dir" 2>/dev/null || ! { printf '%s\n' "$text" >"$draft"; } 2>/dev/null \
    || ! mv -f "$draft" "$path" 2>/dev/null; then
    rm -f "$draft" 2>/dev/null || true
    refuse_cases_unwritable_note "$dir" >&2
    return 1
  fi
}
