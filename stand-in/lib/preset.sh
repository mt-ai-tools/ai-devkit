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
# The operator's challenge ladder, whose named quotes are the words the
# stand-in sends: read from the file the operator reads, never copied into
# code or a prompt, so the words a project swaps in are the words sent.
PRESET_LADDER_FILE="challenges/challenge-ladder.md"
# What a session started under the stand-in with a brief is told first: read
# from the file the operator reads and swaps, never copied into code.
PRESET_OPENER_FILE="challenges/opener.md"

# The routes a kind may take, as its header writes them: to the operator
# always, or up the challenge ladder; or, for a finished step's report waiting
# for the operator's go, the step go. The step go is found by its route and
# never by its kind's name, so the stand-in knows no kind by name and a
# project's preset may call it what it likes.
ROUTE_ASK="ask"
ROUTE_LADDER="ladder"
ROUTE_GO="go"
ROUTES=("$ROUTE_ASK" "$ROUTE_LADDER" "$ROUTE_GO")

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

# A ladder file's text as rows, one per quote, in the order written:
# "message<US><name><US><words>" for a quote that directly follows a line
# opening with a short name in backticks, as a risk opens ("2. `name` — …" or
# "- `name` — …"), or the indented lines that line runs on over;
# "unnamed<US><line number>" for a quote that follows anything else. Each run
# of lines opening with ">" is one quote, its lines joined by a space. Nothing
# else in the file is read, so its prose stays the operator's to word as they
# like.
derive_message_rows() {
  awk '
    function flush() {
      if (open) {
        if (name != "") printf "message\037%s\037%s\n", name, quote
        else printf "unnamed\037%s\n", start
      }
      open = 0; quote = ""; name = ""
    }
    /^[[:space:]]*>/ {
      if (!open) { open = 1; start = NR; name = pending }
      pending = ""
      line = $0
      sub(/^[[:space:]]*>[[:space:]]*/, "", line)
      if (line != "") quote = (quote == "" ? line : quote " " line)
      next
    }
    {
      flush()
      if (pending != "" && $0 ~ /^[[:space:]]+[^[:space:]]/) next
      pending = ""
      if (match($0, /^[[:space:]]*([0-9]+\.|-) +`[a-z0-9]+(-[a-z0-9]+)*` +— /)) {
        pending = substr($0, index($0, "`") + 1)
        sub(/`.*/, "", pending)
      }
    }
    END { flush() }
  ' <<<"$1"
}

# A ladder file's messages, as one JSON object of name to words; a refusal on
# stderr and a non-zero status otherwise. The file's path is only for the
# refusal. A quote with no name is refused, not skipped: words the operator
# wrote to be sent would otherwise never be, unseen. A name written twice is
# refused, since which of its two quotes is meant is a guess.
parse_messages() {
  local file="$1" rows kind name words twice
  rows="$(derive_message_rows "$2")"
  while IFS=$'\037' read -r kind name words; do
    [ "$kind" = unnamed ] || continue
    refuse_unnamed_message_note "$file" "$name" >&2
    return 1
  done <<<"$rows"
  twice="$(cut -d $'\037' -f 2 <<<"$rows" | sed '/^$/d' | sort | uniq -d | head -n 1)"
  if [ -n "$twice" ]; then
    refuse_message_twice_note "$file" "$twice" >&2
    return 1
  fi
  while IFS=$'\037' read -r kind name words; do
    [ -n "$name" ] || continue
    jq -cn --arg name "$name" --arg words "$words" '{($name): $words}'
  done <<<"$rows" | jq -cs 'add // {}'
}

# True if the word given is one of the routes.
is_route() {
  local route
  for route in "${ROUTES[@]}"; do
    [ "$1" != "$route" ] || return 0
  done
  return 1
}

# The routes, joined into one line for a refusal to name them.
to_routes_line() {
  local joined
  printf -v joined '%s, ' "${ROUTES[@]}"
  printf '%s\n' "${joined%, }"
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
# stderr and a non-zero status where it cannot be read, its route is none of
# the routes, or it has a second challenge with no first. A route that cannot
# be read is never taken for any: the one it was meant to be is a guess, and
# guessing ladder would let a question the operator keeps for themselves pass
# without them.
get_kind_entry() {
  local preset="$1" name="$2" file summary route challenge second
  file="$preset/$PRESET_KINDS_FOLDER/$name.md"
  if [ ! -f "$file" ] || [ ! -r "$file" ]; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  IFS="$HEADER_US" read -r summary route challenge second < <(read_header_fields "$file" summary route challenge second-challenge)
  if ! is_route "$route"; then
    refuse_kind_route_note "$name" "$route" "$(to_routes_line)" >&2
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

# The messages a preset's ladder holds under the names given, as one JSON
# object of name to words; a refusal on stderr and a non-zero status where the
# file cannot be read, or lacks any of them or holds one with no words. Every
# name the caller sends is asked for each time, whichever one it needs now: a
# message is sent by its name, never by its place in the file, where a
# reordering would silently send the wrong words, and a preset missing one is
# found on the first question rather than half-way up a ladder.
get_ladder_messages() {
  local file="$1/$PRESET_LADDER_FILE" text messages name
  shift
  if ! text="$(cat "$file" 2>/dev/null)"; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  messages="$(parse_messages "$file" "$text")" || return 1
  for name in "$@"; do
    if ! jq -e --arg name "$name" '.[$name] // "" | test("\\S")' >/dev/null <<<"$messages"; then
      refuse_ladder_message_missing_note "$file" "$name" >&2
      return 1
    fi
  done
  jq -c --args '. as $all | reduce $ARGS.positional[] as $name ({}; .[$name] = $all[$name])' "$@" <<<"$messages"
}

# A preset's opener, as its file holds it, header included: handed over whole,
# as the checker hands over an entry. The kit's header reader reads fields
# only, and cutting the body out here would be a second reader of the
# header's shape, free to drift from the first. A refusal on stderr and a
# non-zero status where it cannot be read or holds nothing.
read_opener() {
  local file="$1/$PRESET_OPENER_FILE" text
  if ! text="$(cat "$file" 2>/dev/null)" || [ -z "$text" ]; then
    refuse_unreadable_file_note "$file" >&2
    return 1
  fi
  printf '%s\n' "$text"
}

# The entry of the kind whose route is the step go, as get_kind_entry gives
# it; nothing where the preset holds none, which is a project that wants no
# step go: its step reports stop as any reply asking nothing, and reach the
# operator as they would without the stand-in. A refusal on stderr and a
# non-zero status where an entry cannot be read, or more than one kind takes
# the route: which of them a step is would be a guess.
find_go_kind() {
  local preset="$1" folder="$1/$PRESET_KINDS_FOLDER" entry route found=""
  while IFS= read -r entry; do
    [ -n "$entry" ] || continue
    route="$(read_header_fields "$entry" route)"
    [ "$route" = "$ROUTE_GO" ] || continue
    if [ -n "$found" ]; then
      refuse_go_kind_twice_note "$ROUTE_GO" "$folder" >&2
      return 1
    fi
    found="$(basename "$entry" .md)"
  done < <(list_collection_entries "$folder")
  [ -n "$found" ] || return 0
  get_kind_entry "$preset" "$found"
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
