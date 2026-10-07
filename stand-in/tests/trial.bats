bats_require_minimum_version 1.5.0

# Behavior tests for the trial: a kind is on trial until the operator's yes
# file says otherwise; a plain yes and nothing else is one; a yes that cannot
# be read leaves the kind on trial; the fall-back counts reopens among the
# first silent decisions after the yes alone, and is told only by the reopen
# that reaches it.

load fake-claude
load question-log

setup() {
  setup_fake_claude
  . "$lib/words.sh"
  . "$lib/trial.sh"
  history="$project/aidk-stand-in"
  yes_at="2026-10-05T08:00:00Z"
}

# A settled line of the kind given, by number and when, reopened where a
# moment is given.
settled() {
  jq -c --arg kind "$1" --arg reopened "${4:-}" '.kind = $kind | if $reopened != "" then .reopened = $reopened else . end' \
    <<<"$(log_line "$2" "$OUTCOME_SETTLED" session-1 "$3")"
}

@test "a plain yes is the word alone, in any case, a stop after it at most; anything more is none" {
  for answer in yes Yes "YES." " yes! " $'yes\n'; do
    is_plain_yes "$answer"
  done
  for answer in "" no "yes, but" "yes please" "yess" "y" "ok" "yes.."; do
    ! is_plain_yes "$answer"
  done
}

@test "a kind is on trial until its yes file stands, and switched once it does" {
  is_on_trial "$history" defaults
  write_trust_file "$history" defaults "$yes_at"
  ! is_on_trial "$history" defaults
  is_on_trial "$history" naming
  [ "$(read_trust_given "$history" defaults)" = "$yes_at" ]
  [ "$(list_trusted_kinds "$history")" = defaults ]
}

@test "a yes file that does not say when, or a kind that cannot name one, leaves the kind on trial, refused plainly" {
  mkdir -p "$history/trusted"
  printf -- '---\nkind: defaults\ngiven: yesterday\n---\n' >"$history/trusted/defaults.md"
  run --separate-stderr read_trust_given "$history" defaults
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_trust_unreadable_note "$history/trusted/defaults.md")" ]
  is_on_trial "$history" defaults
  is_every_kind_on_trial "$history"
  run --separate-stderr write_trust_file "$history" "../escape" "$yes_at"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_trust_kind_note "../escape")" ]
  [ ! -e "$project/escape.md" ]
  is_on_trial "$history" "../escape"
}

@test "a log that cannot be read leaves a switched kind on trial" {
  write_trust_file "$history" defaults "$yes_at"
  add_log_lines "$history" '{"torn'
  is_on_trial "$history" defaults
}

@test "proof: two reopens of the first silent decisions after the yes send the kind back; one does not, nor do others' or earlier ones" {
  write_trust_file "$history" defaults "$yes_at"
  add_log_lines "$history" \
    "$(settled defaults 1 2026-10-04T09:00:00Z 2026-10-04T10:00:00Z)" \
    "$(settled naming 2 2026-10-05T09:00:00Z 2026-10-05T10:00:00Z)" \
    "$(settled defaults 3 2026-10-05T09:00:00Z 2026-10-05T10:00:00Z)" \
    "$(settled defaults 4 2026-10-05T09:10:00Z)"
  ! is_on_trial "$history" defaults
  add_log_lines "$history" "$(settled defaults 5 2026-10-05T09:20:00Z 2026-10-05T11:00:00Z)"
  is_on_trial "$history" defaults
  # A newer yes starts the count again.
  write_trust_file "$history" defaults 2026-10-06T00:00:00Z
  ! is_on_trial "$history" defaults
}

@test "only the first twenty silent decisions after the yes count toward the fall-back" {
  lines=""
  for number in $(seq 1 22); do
    lines+="$(settled defaults "$number" "2026-10-05T09:$(printf '%02d' "$number"):00Z")"$'\n'
  done
  marked="$(jq -c 'if .number == 1 or .number == 21 or .number == 22 then .reopened = "2026-10-06T00:00:00Z" else . end' <<<"$lines")"
  [ "$(derive_fallback_reopens "$marked" defaults "$yes_at")" -eq 1 ]
  ! is_fallen_back "$marked" defaults "$yes_at"
  [ "$(derive_fallback_reopens "" defaults "$yes_at")" -eq 0 ]
}

@test "the fall-back is told by the reopen that reaches it, and by no other" {
  one="$(settled defaults 1 2026-10-05T09:00:00Z 2026-10-05T10:00:00Z)"
  two="$(settled defaults 2 2026-10-05T09:10:00Z)"
  two_reopened="$(settled defaults 2 2026-10-05T09:10:00Z 2026-10-05T10:10:00Z)"
  three_reopened="$(settled defaults 3 2026-10-05T09:20:00Z 2026-10-05T10:20:00Z)"
  [ "$(derive_fallback_notice "$one"$'\n'"$two" "$one"$'\n'"$two_reopened" defaults "$yes_at")" = \
    "$(trial_fallback_note defaults 2 20 "$yes_at")" ]
  [ -z "$(derive_fallback_notice "$two" "$one"$'\n'"$two" defaults "$yes_at")" ]
  [ -z "$(derive_fallback_notice "$one"$'\n'"$two_reopened" "$one"$'\n'"$two_reopened"$'\n'"$three_reopened" defaults "$yes_at")" ]
}
