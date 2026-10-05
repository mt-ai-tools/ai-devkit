#!/usr/bin/env bash
# The stand-in's one entry — a thin orchestrator: it finds the preset, and
# hands each subcommand to the concern that holds it.
#
#   read-reply          the reply on stdin; its checked reader's form on stdout
#   sort <reader form>  the reply on stdin; the question's checked sorter's
#                       answer on stdout
#
# Status: 0 when it answered with a form that passed its check; 1 for a
# refusal, with every reason on stderr, or a usage it does not know. One
# non-zero status throughout, so whatever runs it need only tell a form it may
# decide from apart from anything else: every refusal goes the same way. A config
# file the kit refuses stops it with the config reader's own reason.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/reader.sh"
. "$tool_root/lib/sorter.sh"

usage() {
  refuse_usage_note >&2
  exit 1
}

command="${1:-}"
[ "$#" -gt 0 ] && shift

case "$command" in
  read-reply)
    [ "$#" -eq 0 ] || usage
    reply="$(cat)"
    get_reader_form "$reply"
    ;;
  sort)
    [ "$#" -eq 1 ] || usage
    # Resolved into a variable before use, never inline as an argument: a
    # failing command substitution inside an argument does not end the script,
    # so a refused config file would otherwise reach the sorter as an empty
    # path. A plain assignment does end it.
    preset="$(get_config_path AIDK_STAND_IN)"
    reply="$(cat)"
    get_sorter_answer "$1" "$reply" "$preset"
    ;;
  *)
    usage
    ;;
esac
