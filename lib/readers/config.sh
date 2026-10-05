#!/usr/bin/env bash
# Where the kit finds the material it reads, in one place: the config file's
# name, the defaults, and the reader that resolves each key to a path. Sourced,
# never executed.
#
# The file is read every turn by every session, so it is read line by line as
# `KEY=value` and never sourced or run: anyone able to edit it would otherwise
# run any command on every turn. Whatever falls outside that grammar is refused
# with a message rather than guessed at, since a guess is how a typo or a
# planted line slips through.

# The file a project keeps at its root. Absent, every key is its default.
CONFIG_FILE_NAME="aidk-config.env"

# The one token a value may hold: where the kit itself is mounted, found from
# this file's own location. A `{root}` token was dropped on purpose: it only
# repeated what a plain path already means.
CONFIG_KIT_TOKEN="{ai-devkit}"

# Every key the kit reads, with its default, in the order the example lists
# them. This is the defaults' one home; the shipped example repeats them for
# the operator to copy, and a test keeps the two equal.
CONFIG_DEFAULTS=(
  "AIDK_RULES={ai-devkit}/presets/rules"
  "AIDK_STAND_IN={ai-devkit}/presets/stand-in"
  "AIDK_CONVENTIONS=aidk-conventions"
  "AIDK_PLANS=aidk-plans"
  "AIDK_NOTES=aidk-notes"
  "AIDK_STAND_IN_HISTORY=aidk-stand-in"
  "AIDK_REVIEW=aidk-review"
  "AIDK_ORGANIZER=aidk-organizer"
)

# The separator between the parts of a row this reader hands back: the ASCII
# unit separator, which no line of the file can hold unnoticed and which bash
# never collapses the way it collapses a run of tabs.
CONFIG_US=$'\037'

# --- The words a refusal hands the operator — in one place, so the suite
# asserts the wiring rather than the wording. Each names the line, and the key
# or path, so the operator never has to guess which line was meant.

config_not_a_setting_note() {
  printf '%s, line %s: not a KEY=value setting.\n' "$CONFIG_FILE_NAME" "$1"
}

config_bad_key_note() {
  printf '%s, line %s: the key "%s" is not upper-case letters, digits and underscores.\n' "$CONFIG_FILE_NAME" "$1" "$2"
}

config_empty_value_note() {
  printf '%s, line %s: %s has no value.\n' "$CONFIG_FILE_NAME" "$1" "$2"
}

config_padded_value_note() {
  printf '%s, line %s: the value of %s starts or ends with white space.\n' "$CONFIG_FILE_NAME" "$1" "$2"
}

config_shell_value_note() {
  printf '%s, line %s: the value of %s holds a quote, a dollar sign, a backtick or a backslash; the file is never run by a shell, so none of them would do what a shell does with it.\n' "$CONFIG_FILE_NAME" "$1" "$2"
}

config_unknown_key_note() {
  printf '%s, line %s: %s is not a key the kit reads.\n' "$CONFIG_FILE_NAME" "$1" "$2"
}

config_unknown_token_note() {
  printf '%s, line %s: %s holds %s; the only token is %s.\n' "$CONFIG_FILE_NAME" "$1" "$2" "$3" "$CONFIG_KIT_TOKEN"
}

config_key_twice_note() {
  printf '%s, line %s: %s is set again; line %s set it already.\n' "$CONFIG_FILE_NAME" "$1" "$2" "$3"
}

config_path_missing_note() {
  printf '%s, line %s: %s is set to %s, which does not exist.\n' "$CONFIG_FILE_NAME" "$1" "$2" "$3"
}

config_unreadable_note() {
  printf '%s cannot be read as a file.\n' "$1"
}

config_unasked_key_note() {
  printf 'The kit reads no configuration key named %s.\n' "$1"
}

# --- Transforms: values in, values out.

# True if the key is one the kit reads. Read off the defaults, so a key gains
# its place in the file the moment it gains a default, and never otherwise.
is_config_key() {
  local default
  for default in "${CONFIG_DEFAULTS[@]}"; do
    [ "${default%%=*}" = "$1" ] && return 0
  done
  return 1
}

# One line of the file, given its number: nothing for a blank line or a
# comment, "<KEY><CONFIG_US><value>" for a setting, and a refusal on stderr with
# a non-zero status for anything else. Only a line starting with `#` is a
# comment; a `#` later in a line is part of the value, and a path that does not
# exist is refused further on.
parse_config_line() {
  local number="$1" line="$2" key value
  [ -z "$line" ] && return 0
  [ "${line:0:1}" = "#" ] && return 0
  case "$line" in
    *=*) ;;
    *) config_not_a_setting_note "$number" >&2; return 1 ;;
  esac
  key="${line%%=*}"
  value="${line#*=}"
  [ -n "$key" ] || { config_not_a_setting_note "$number" >&2; return 1; }
  # `export KEY`, `KEY ` and lower-case keys all land here: the grammar has no
  # room for a shell's spelling of a setting, so none is half-understood.
  [[ "$key" =~ ^[A-Z][A-Z0-9_]*$ ]] || { config_bad_key_note "$number" "$key" >&2; return 1; }
  is_config_key "$key" || { config_unknown_key_note "$number" "$key" >&2; return 1; }
  [ -n "$value" ] || { config_empty_value_note "$number" "$key" >&2; return 1; }
  # White space at either end is invisible in an editor, and a stray carriage
  # return from another platform's line endings is one of them.
  [[ "$value" =~ ^[[:space:]]|[[:space:]]$ ]] && { config_padded_value_note "$number" "$key" >&2; return 1; }
  # Quotes, `$`, backticks and backslashes are what a shell would act on. The
  # file is never run, so a value holding one cannot mean what its writer
  # likely meant by it; refusing says so instead of taking it literally.
  case "$value" in
    *\"* | *\'* | *\`* | *\$* | *\\*)
      config_shell_value_note "$number" "$key" >&2; return 1 ;;
  esac
  local rest="${value//"$CONFIG_KIT_TOKEN"/}"
  case "$rest" in
    *[{}]*)
      config_unknown_token_note "$number" "$key" "$(config_brace_part "$rest")" >&2; return 1 ;;
  esac
  printf '%s%s%s\n' "$key" "$CONFIG_US" "$value"
}

# The brace-bearing part of a value, for naming it in a refusal: the first
# `{…}` it holds, or the value itself where a brace stands unpaired.
config_brace_part() {
  if [[ "$1" =~ \{[^{}]*\} ]]; then printf '%s' "${BASH_REMATCH[0]}"; else printf '%s' "$1"; fi
}

# The file's text, on stdin, as its settings: one "<line><CONFIG_US><KEY><CONFIG_US><value>"
# per setting, in the order written. Any line refused refuses the whole text,
# and so does a key set twice — which of the two was meant would be a guess.
parse_config_settings() {
  local number=0 line setting settings="" first
  while IFS= read -r line || [ -n "$line" ]; do
    number=$((number + 1))
    setting="$(parse_config_line "$number" "$line")" || return 1
    [ -n "$setting" ] || continue
    first="$(config_setting_for "${setting%%"$CONFIG_US"*}" "$settings")"
    if [ -n "$first" ]; then
      config_key_twice_note "$number" "${setting%%"$CONFIG_US"*}" "${first%%"$CONFIG_US"*}" >&2
      return 1
    fi
    settings+="$number$CONFIG_US$setting"$'\n'
  done
  printf '%s' "$settings"
}

# The setting for one key among parsed settings, as "<line><CONFIG_US><value>",
# or nothing where the key is not set.
config_setting_for() {
  local key="$1" settings="$2" row number rest
  while IFS= read -r row; do
    [ -n "$row" ] || continue
    number="${row%%"$CONFIG_US"*}"
    rest="${row#*"$CONFIG_US"}"
    [ "${rest%%"$CONFIG_US"*}" = "$key" ] || continue
    printf '%s%s%s\n' "$number" "$CONFIG_US" "${rest#*"$CONFIG_US"}"
    return 0
  done <<<"$settings"
}

# A value as an absolute path: the kit token becomes the kit's own location,
# as a plain string, and then a path beginning with `/` is taken as written
# while any other is read from the project root, as every common config reads
# its paths.
resolve_config_value() {
  local value="$1" kit="$2" root="$3"
  value="${value//"$CONFIG_KIT_TOKEN"/$kit}"
  case "$value" in
    /*) printf '%s\n' "$value" ;;
    *) printf '%s/%s\n' "$root" "$value" ;;
  esac
}

# --- Reads: they look at the world and change nothing.

# The kit's own root, absolute, found from where this file sits, because every
# line naming it is read by someone not standing where this ran.
get_kit_dir() {
  (cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
}

# The project the kit is run for; on a machine with no such variable set, the
# working directory stands in.
get_project_root() {
  printf '%s\n' "${CLAUDE_PROJECT_DIR:-$PWD}"
}

# The settings in the file at the given path, parsed; nothing where there is no
# file. Something at that path that cannot be read as a file is refused rather
# than taken for no file: it was meant to say something, and nobody can tell
# what.
find_config_settings() {
  local file="$1"
  [ -e "$file" ] || return 0
  [ -f "$file" ] && [ -r "$file" ] || { config_unreadable_note "$file" >&2; return 1; }
  parse_config_settings <"$file"
}

# Every key the kit reads, as "<KEY><CONFIG_US><absolute path>", in the
# defaults' order. The whole file is judged on every call, so no caller acts on
# a file another caller would refuse.
#
# A path set in the file must exist: a typo must not pass. A default whose
# folder is missing is handed back all the same, and staying silent about it is
# the caller's — no key is special here, so whether one is required is decided
# by whoever looks it up. Since a missing set path never gets this far, a path
# that does not exist is always a default. The rows are handed back only once
# every key has passed, so a refusal never leaves a caller holding half a list.
list_config_paths() {
  local root kit settings default key found number value path rows=""
  root="$(get_project_root)"
  kit="$(get_kit_dir)"
  settings="$(find_config_settings "$root/$CONFIG_FILE_NAME")" || return 1
  for default in "${CONFIG_DEFAULTS[@]}"; do
    key="${default%%=*}"
    found="$(config_setting_for "$key" "$settings")"
    if [ -n "$found" ]; then
      number="${found%%"$CONFIG_US"*}"
      value="${found#*"$CONFIG_US"}"
    else
      number=""
      value="${default#*=}"
    fi
    path="$(resolve_config_value "$value" "$kit" "$root")"
    if [ -n "$number" ] && [ ! -e "$path" ]; then
      config_path_missing_note "$number" "$key" "$path" >&2
      return 1
    fi
    rows+="$key$CONFIG_US$path"$'\n'
  done
  printf '%s' "$rows"
}

# The absolute path for one key. Refused where the file is refused, whichever
# key it is wrong about, and where the key is not one the kit reads.
get_config_path() {
  local key="$1" paths row
  is_config_key "$key" || { config_unasked_key_note "$key" >&2; return 1; }
  paths="$(list_config_paths)" || return 1
  while IFS= read -r row; do
    [ "${row%%"$CONFIG_US"*}" = "$key" ] || continue
    printf '%s\n' "${row#*"$CONFIG_US"}"
    return 0
  done <<<"$paths"
}
