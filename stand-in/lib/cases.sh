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
# operator when it was asked, which is what makes it a try; picked-recommended,
# yes where the operator picked the option the agent recommended, which is
# what the stand-in settles on, so whether it agreed with them; tuning, none
# until a prompt is adjusted on the case, after which it never counts toward
# a score; and log-id, the line it was written from, so no line is written
# twice. Nothing more: what scoring needs beyond these, a replay finds out.

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

# The header field a case names the log line it was written from by.
CASE_LOG_ID_FIELD="log-id"

# --- Transforms.

# The cases' folder, from the stand-in's working folder.
to_cases_dir() {
  printf '%s/%s\n' "$1" "$CASES_SUBFOLDER"
}

# The log's lines that become cases, one per line, in log order, given the
# log's lines and the briefs finished, as a JSON array: every question of
# those briefs that reached the operator and was answered. A request to start
# building and a closing round are no cases: their decision is the
# operator's whatever any kind's trial says, so they are never a try. A
# question settled without the operator, or a proposal dropped, never reached
# them, so holds no answer of theirs to learn from.
to_case_lines() {
  local mine
  mine="$(to_brief_log_lines "$1" "$2")"
  [ -n "$mine" ] || return 0
  jq -c --arg operator "$OUTCOME_TO_OPERATOR" --arg held "$OUTCOME_WOULD_HAVE_APPROVED" '
    select((.outcome == $operator or .outcome == $held) and (.answer // "") != ""
      and .round == null and .closing == null)' <<<"$mine"
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
  local line="$1" form="$2" alone picked_recommended
  alone="$(case_no_words)"
  [ "$(jq -r '.outcome' <<<"$line")" != "$OUTCOME_WOULD_HAVE_APPROVED" ] || alone="$(case_yes_words)"
  picked_recommended="$(case_no_words)"
  ! jq -e '.picked != "" and .picked == .recommended' >/dev/null <<<"$form" || picked_recommended="$(case_yes_words)"
  jq -rn --argjson line "$line" --argjson form "$form" --arg alone "$alone" --arg picked "$picked_recommended" \
    --arg unknown "$(case_kind_unknown_words)" --arg tuning "$(case_tuning_none_words)" \
    --arg no_why "$(case_no_why_words)" --arg id_field "$CASE_LOG_ID_FIELD" \
    --arg start "$CASE_REPLY_START" --arg end "$CASE_REPLY_END" '
    def one_line: gsub("\\s+"; " ") | gsub("^ | $"; "");
    "---",
    "summary: \($form.summary | one_line)",
    "date: \($line.when[0:10] | one_line)",
    "brief: \(($line.briefs // []) | map(select(type == "string")) | join(", ") | one_line)",
    "kind: \(($line.kind // $unknown) | one_line)",
    "alone: \($alone)",
    "picked-recommended: \($picked)",
    "tuning: \($tuning)",
    "\($id_field): \($line.id | one_line)",
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
