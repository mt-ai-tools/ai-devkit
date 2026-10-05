#!/usr/bin/env bash
# What the stand-in reads from its preset: the kinds a question can be, and the
# risks an option can carry. It knows no kind and no risk by name — whatever
# the preset holds is what a sorter is handed and what its answer is checked
# against. Sourced, never executed.
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/collection.sh"
. "$(dirname "${BASH_SOURCE[0]}")/../../lib/readers/header.sh"
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# Where inside a preset each is kept: one file per kind of question, and the
# risks as one list the operator reads in a single file.
PRESET_KINDS_FOLDER="questions"
PRESET_RISKS_FILE="challenges/risks.md"
# The operator's challenge ladder, whose quotes are the words each rung after
# the first sends: read from the file the operator reads, never copied into
# code or a prompt, so the words a project swaps in are the words sent.
PRESET_LADDER_FILE="challenges/challenge-ladder.md"

# The two routes a kind of question may take, as its header writes them: to
# the operator always, or up the challenge ladder.
ROUTE_ASK="ask"
ROUTE_LADDER="ladder"

# --- Transforms.

# A risks file's text as rows, one per bullet, in the order written:
# "risk<US><name><US><words>" for a risk, "unnamed<US><line number>" for a
# bullet that does not open with a short name in backticks. A risk's words run
# on over the indented lines below its bullet.
derive_risk_rows() {
  awk '
    function flush() { if (name != "") printf "risk\037%s\037%s\n", name, words; name = "" }
    /^- / {
      flush()
      if (match($0, /^- `[a-z0-9]+(-[a-z0-9]+)*` +— +/)) {
        name = substr($0, 4)
        sub(/`.*/, "", name)
        words = substr($0, RLENGTH + 1)
      } else {
        printf "unnamed\037%s\n", NR
      }
      next
    }
    /^ +[^ ]/ && name != "" { line = $0; sub(/^ +/, "", line); words = words " " line; next }
    { flush() }
    END { flush() }
  ' <<<"$1"
}

# The risks in a risks file's text, as a JSON array of {name, words}; a
# refusal on stderr and a non-zero status otherwise. The file's path is only
# for the refusal. Every bullet must be a named risk: a bullet with no name
# would otherwise drop out of the list unseen, and a risk the sorter is never
# handed is one no question is ever sent to the operator for. A name written
# twice is refused, since which of the two words it stands for is a guess.
parse_risks() {
  local file="$1" rows row kind name words twice
  rows="$(derive_risk_rows "$2")"
  while IFS=$'\037' read -r kind name words; do
    [ "$kind" = unnamed ] || continue
    refuse_unnamed_risk_note "$file" "$name" >&2
    return 1
  done <<<"$rows"
  if [ -z "$rows" ]; then
    refuse_no_risks_note "$file" >&2
    return 1
  fi
  twice="$(cut -d $'\037' -f 2 <<<"$rows" | sort | uniq -d | head -n 1)"
  if [ -n "$twice" ]; then
    refuse_risk_twice_note "$file" "$twice" >&2
    return 1
  fi
  while IFS=$'\037' read -r kind name words; do
    jq -cn --arg name "$name" --arg words "$words" '{name: $name, words: $words}'
  done <<<"$rows" | jq -cs .
}

# A ladder file's quotes, in the order written, as a JSON array of strings:
# each run of lines opening with ">" is one quote, its lines joined by a
# space. Nothing else in the file is read, so its prose stays the operator's
# to word as they like.
derive_ladder_quotes() {
  awk '
    function flush() { if (open) print quote; open = 0; quote = "" }
    /^[[:space:]]*>/ {
      line = $0
      sub(/^[[:space:]]*>[[:space:]]*/, "", line)
      if (line != "") quote = (quote == "" ? line : quote " " line)
      open = 1
      next
    }
    { flush() }
    END { flush() }
  ' <<<"$1" | jq -Rnc '[inputs]'
}

# The names alone, out of a JSON array of {name, ...}, as a JSON array.
to_names() {
  jq -c 'map(.name)' <<<"$1"
}

# --- Reads.

# The kinds of question in a preset, as a JSON array of {name, summary} in
# file-name order; a refusal on stderr and a non-zero status where there is
# none, or where one has no summary to be sorted by. A kind's name is its
# file's, as the operator sees it in the folder.
list_kinds() {
  local folder="$1/$PRESET_KINDS_FOLDER" entry name summary kinds=""
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    name="$(basename "$entry" .md)"
    summary="$(read_header_fields "$entry" summary)"
    if [ -z "$summary" ]; then
      refuse_kind_summary_note "$name" >&2
      return 1
    fi
    kinds+="$(jq -cn --arg name "$name" --arg summary "$summary" '{name: $name, summary: $summary}')"$'\n'
  done < <(list_collection_entries "$folder")
  if [ -z "$kinds" ]; then
    refuse_no_kinds_note "$folder" >&2
    return 1
  fi
  printf '%s' "$kinds" | jq -cs .
}

# One kind of question's entry, as JSON {name, summary, route, challenge,
# second_challenge}, the challenges empty where it has none; a refusal on
# stderr and a non-zero status where it cannot be read, its route is neither
# of the two, or it has a second challenge with no first. A route that cannot
# be read is never taken for either: the one it was meant to be is a guess,
# and guessing ladder would let a question the operator keeps for themselves
# pass without them.
get_kind_entry() {
  local preset="$1" name="$2" file summary route challenge second
  file="$preset/$PRESET_KINDS_FOLDER/$name.md"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  IFS="$HEADER_US" read -r summary route challenge second < <(read_header_fields "$file" summary route challenge second-challenge)
  if [ "$route" != "$ROUTE_ASK" ] && [ "$route" != "$ROUTE_LADDER" ]; then
    refuse_kind_route_note "$name" "$route" "$ROUTE_ASK" "$ROUTE_LADDER" >&2
    return 1
  fi
  if [ -z "$challenge" ] && [ -n "$second" ]; then
    refuse_second_challenge_alone_note "$name" >&2
    return 1
  fi
  jq -cn --arg name "$name" --arg summary "$summary" --arg route "$route" \
    --arg challenge "$challenge" --arg second "$second" \
    '{name: $name, summary: $summary, route: $route, challenge: $challenge, second_challenge: $second}'
}

# The challenges a preset's ladder sends, in rung order, as a JSON array of
# strings; a refusal on stderr and a non-zero status where the file cannot be
# read or does not hold exactly the count given, an empty quote counting
# against it. A ladder short of a challenge would approve after fewer rungs
# than the operator climbs, and one with a challenge too many would send
# words the operator never meant as a rung.
get_ladder_challenges() {
  local file="$1/$PRESET_LADDER_FILE" count="$2" text quotes found
  if ! text="$(cat "$file" 2>/dev/null)"; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  quotes="$(derive_ladder_quotes "$text")"
  found="$(jq 'map(select(test("\\S"))) | length' <<<"$quotes")"
  if [ "$(jq 'length' <<<"$quotes")" -ne "$count" ] || [ "$found" -ne "$count" ]; then
    refuse_ladder_challenges_note "$file" "$count" "$found" >&2
    return 1
  fi
  printf '%s\n' "$quotes"
}

# The risks in a preset, as parse_risks hands them back.
list_risks() {
  local file="$1/$PRESET_RISKS_FILE" text
  if ! text="$(cat "$file" 2>/dev/null)"; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  parse_risks "$file" "$text"
}
