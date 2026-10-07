#!/usr/bin/env bash
# The case-writer's run, a thin orchestrator: once the stand-in has finished
# a session's brief, every question of it the operator answered is written
# into a test case by the case-writer, read for secrets by the scanner and by
# the secret check's agent, and saved only where both find nothing; the
# paths written are printed for the agent to commit, and how many were
# written, skipped, held back and failed to write are kept in the session's
# record, where the end report reads them. Sourced, never executed.
#
# Run by the agent, as a command of the stand-in's entry, never in a stop of
# the gate (settled 2026-10-07): one Opus call and one check per case, a
# brief's cases outgrow any stop's time limit. It writes cases for the briefs
# the gate finished alone, read off the session's record, so nobody can point
# it at another brief's answers.
#
# Fails closed for each case: a writer, a scanner or a check that cannot run
# holds the case back, counted apart from those held for a secret, and the
# reasons go to stderr, never the case's text.
#
# The questions are drafted side by side through the kit's side-by-side
# runner (settled with the operator 2026-10-07), each in a process of its own
# that asks the models and writes nothing; their files are then put in place
# one after another, in the log's order, and the record written once, at the
# end. So nothing a draft does touches another's: two cases of one day and
# title take the same names they would one at a time, the first in the log
# the plain one, and the counts are counted by the run alone, from the
# drafts in order, never by drafts adding to a shared record, which would
# need a lock for no gain.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_WRITE_CASES:-}" ] || return 0
STAND_IN_LOADED_WRITE_CASES=1
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/runners/side-by-side.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"
. "$(dirname "${BASH_SOURCE[0]}")/record.sh"
. "$(dirname "${BASH_SOURCE[0]}")/question-log.sh"
. "$(dirname "${BASH_SOURCE[0]}")/cases.sh"
. "$(dirname "${BASH_SOURCE[0]}")/case-writer.sh"
. "$(dirname "${BASH_SOURCE[0]}")/secret-check.sh"
. "$(dirname "${BASH_SOURCE[0]}")/scanner.sh"

# How one question ended, as get_case_draft gives it: written, already or
# now; skipped; held back for a secret; failed to write; or clean, read and
# found to hold no secret, its file still to be put in place.
CASE_WRITTEN="written"
CASE_SKIPPED="skipped"
CASE_HELD="held"
CASE_FAILED="failed"
CASE_CLEAN="clean"

# The reasons a part gave on stderr, under the line naming the question whose
# case was not written. The file given holds the reasons.
tell_case_unwritten() {
  refuse_case_unwritten_note "$1" >&2
  cat "$2" >&2
}

# Whether the case's text holds a secret, by the scanner, then the secret
# check's agent: found, clean, or a refusal on stderr and a non-zero status
# where either could not run. The scanner first: it asks no model, and a
# secret it finds needs no second opinion. Its folder is made empty here and
# removed after, whatever it answered.
check_case_secrets() {
  local text="$1" folder state status=0 answer
  if ! folder="$(mktemp -d)"; then
    refuse_scanner_folder_note >&2
    return 1
  fi
  state="$(get_scan_state "$text" "$folder")" || status=$?
  rm -rf "$folder"
  [ "$status" -eq 0 ] || return 1
  if [ "$state" = "$SCAN_FOUND" ]; then
    printf '%s\n' "$SCAN_FOUND"
    return 0
  fi
  answer="$(get_secret_answer "$text")" || return 1
  if jq -e '.holds_secret' >/dev/null <<<"$answer"; then
    printf '%s\n' "$SCAN_FOUND"
  else
    printf '%s\n' "$SCAN_CLEAN"
  fi
}

# One question's case drafted, given the cases' folder, the file holding the
# log lines that become cases, one a line, and the line's place in it,
# counted from 1: what its case-writer and the secret checks made of it, as
# one line of JSON {ended, path, text, date, slug, id, number}, path set for
# a case already written and the rest for a clean one. It asks the models and
# writes nothing: the call the case-writer's runner makes for each line. A
# case already written from the line is not drafted again, and counts as
# written: its path is printed again, for a run that stopped half-way to be
# run again whole. A draft that could not be made says why on stderr, under
# the line naming its question.
get_case_draft() {
  local dir="$1" lines="$2" place="$3" line number id path form text state date title slug why
  line="$(sed -n "${place}p" "$lines")"
  number="$(jq -r '.number' <<<"$line")"
  id="$(jq -r '.id' <<<"$line")"
  path="$(find_case_path "$dir" "$id")"
  if [ -n "$path" ]; then
    to_case_draft "$CASE_WRITTEN" "$number" --arg path "$path"
    return 0
  fi
  why="$(mktemp)"
  if ! form="$(get_case_form "$line" 2>"$why")"; then
    tell_case_unwritten "$number" "$why"
    rm -f "$why"
    to_case_draft "$CASE_FAILED" "$number"
    return 0
  fi
  if ! jq -e '.answers' >/dev/null <<<"$form"; then
    rm -f "$why"
    to_case_draft "$CASE_SKIPPED" "$number"
    return 0
  fi
  if ! text="$(to_case_text "$line" "$form" 2>"$why")" \
    || ! state="$(check_case_secrets "$text" 2>"$why")"; then
    tell_case_unwritten "$number" "$why"
    rm -f "$why"
    to_case_draft "$CASE_FAILED" "$number"
    return 0
  fi
  if [ "$state" = "$SCAN_FOUND" ]; then
    rm -f "$why"
    to_case_draft "$CASE_HELD" "$number"
    return 0
  fi
  if ! date="$(to_case_date "$line" 2>"$why")" || ! title="$(jq -r '.title' <<<"$form" 2>"$why")" \
    || ! slug="$(to_case_slug "$title" 2>"$why")"; then
    tell_case_unwritten "$number" "$why"
    rm -f "$why"
    to_case_draft "$CASE_FAILED" "$number"
    return 0
  fi
  rm -f "$why"
  # The text reaches jq through a file descriptor, never as an argument: a
  # whole case can outgrow what one argument may hold.
  to_case_draft "$CASE_CLEAN" "$number" --rawfile text <(printf '%s' "$text") --arg date "$date" --arg slug "$slug" \
    --arg id "$id"
}

# A draft as get_case_draft prints it, given how it ended, its question's
# number, and the fields it carries as jq's named arguments.
to_case_draft() {
  local ended="$1" number="$2"
  shift 2
  jq -cn --arg ended "$ended" --arg number "$number" "$@" '$ARGS.named'
}

# Put a clean draft's case file in place, given the cases' folder and the
# draft: its path printed; where it cannot be put in place, the reasons on
# stderr under the line naming its question, and a non-zero status.
write_case_draft() {
  local dir="$1" draft="$2" number date slug id text path why
  number="$(jq -r '.number' <<<"$draft")" || return 1
  date="$(jq -r '.date' <<<"$draft")" || return 1
  slug="$(jq -r '.slug' <<<"$draft")" || return 1
  id="$(jq -r '.id' <<<"$draft")" || return 1
  text="$(jq -r '.text' <<<"$draft")" || return 1
  why="$(mktemp)"
  if ! path="$(find_free_case_path "$dir" "$date" "$slug" "$id" 2>"$why")" \
    || ! write_case_file "$path" "$text" 2>"$why"; then
    tell_case_unwritten "$number" "$why"
    rm -f "$why"
    return 1
  fi
  rm -f "$why"
  printf '%s\n' "$path"
}

# Write the cases of the briefs the session's record says the gate finished,
# given the stand-in's working folder and the session: each path written
# printed, and the counts kept in the record. Refused on stderr with a
# non-zero status, writing nothing, where no brief was finished, or the
# record or the log cannot be read; and where the counts cannot be kept,
# after the cases are written, since the end report would then say none was.
# A draft that ended without one counts as a case that failed to write, with
# what it said.
run_write_cases() {
  local history="$1" session="$2" record_file record closing briefs lines dir work count place draft ended path
  local counts status=0 written=0 skipped=0 held=0 failed=0
  record_file="$(to_record_path "$history" "$session")"
  record="$(read_session_record "$record_file")" || return 1
  closing="$(to_closing "$record")"
  if [ -z "$closing" ] || ! jq -e '.finished | type == "string"' >/dev/null <<<"$closing"; then
    refuse_cases_unfinished_note >&2
    return 1
  fi
  briefs="$(jq -c '.briefs' <<<"$closing")"
  lines="$(list_log_lines "$(to_log_dir "$history")")" || return 1
  lines="$(to_case_lines "$lines" "$briefs")" || return 1
  dir="$(to_cases_dir "$history")"
  work="$(mktemp -d)" || return 1
  if ! mkdir "$work/runs"; then
    rm -rf "$work"
    return 1
  fi
  printf '%s\n' "$lines" | sed '/^$/d' >"$work/lines"
  count="$(wc -l <"$work/lines")"
  seq "$count" | run_side_by_side "$SIDE_BY_SIDE_JOBS" "$work/runs" "$(dirname "${BASH_SOURCE[0]}")/write-cases.sh" \
    get_case_draft "$dir" "$work/lines" || status=$?
  if [ "$status" -eq "$SIDE_BY_SIDE_REFUSED" ]; then
    rm -rf "$work"
    return 1
  fi
  for place in $(seq "$count"); do
    cat "$(to_side_by_side_errors "$work/runs" "$place")" >&2 2>/dev/null || true
    draft="$(jq -ce 'select(type == "object")' "$(to_side_by_side_output "$work/runs" "$place")" 2>/dev/null)" || draft=""
    ended="$(jq -r '.ended // empty' <<<"${draft:-null}")"
    if [ "$ended" = "$CASE_CLEAN" ]; then
      if path="$(write_case_draft "$dir" "$draft")"; then
        ended="$CASE_WRITTEN"
      else
        ended="$CASE_FAILED"
      fi
    elif [ "$ended" = "$CASE_WRITTEN" ]; then
      path="$(jq -r '.path' <<<"$draft")"
    fi
    case "$ended" in
      "$CASE_WRITTEN") written=$((written + 1)); printf '%s\n' "$path" ;;
      "$CASE_SKIPPED") skipped=$((skipped + 1)) ;;
      "$CASE_HELD") held=$((held + 1)) ;;
      *) failed=$((failed + 1)) ;;
    esac
  done
  rm -rf "$work"
  counts="$(to_case_counts "$written" "$skipped" "$held" "$failed")" || return 1
  record="$(with_closing_cases "$record" "$counts")" || return 1
  write_session_record "$record_file" "$record"
}
