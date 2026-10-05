#!/usr/bin/env bash
# The organizer's one entry — a thin orchestrator: it finds the briefs folder,
# the project root and the marks folder, asks the clock where an operation
# needs now, and hands each subcommand to the concern that holds it.
#
#   list                      the check's problems, then ready, waiting, taken
#   check                     the check's problems alone
#   take <brief> <session>    mark a brief taken by a session
#   free <session>            free every brief a session holds
#   free-brief <brief>        free one brief, whoever holds it
#   done <brief>              finish a brief, printing every path it changed
#
# Status: 0 when it did what was asked and found nothing wrong; 1 for a
# refusal, a problem the check found, or a usage it does not know. One
# non-zero status throughout, so whatever runs it need tell only success from
# anything else. A config file the kit refuses stops it with the config
# reader's own reason, before any operation runs.
set -euo pipefail

here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
tool_root="$(cd "$here/.." && pwd)"
. "$tool_root/../lib/readers/config.sh"
. "$tool_root/lib/words.sh"
. "$tool_root/lib/clock.sh"
. "$tool_root/lib/briefs.sh"
. "$tool_root/lib/marks.sh"
. "$tool_root/lib/check.sh"
. "$tool_root/lib/list.sh"
. "$tool_root/lib/done.sh"

usage() {
  refuse_usage_note >&2
  exit 1
}

# Each resolved into a variable before use, never inline as an argument: a
# failing command substitution inside an argument does not end the script,
# so a refused config file would otherwise reach an operation as an empty
# path. A plain assignment does end it.
plans="$(get_config_path AIDK_PLANS)"
root="$(get_project_root)"
organizer_dir="$(get_config_path AIDK_ORGANIZER)"
marks="$(marks_dir "$organizer_dir")"

# A missing briefs folder is refused rather than listed as empty: an empty
# list would read as nothing to do, when the folder was never found.
if [ ! -d "$plans" ]; then
  refuse_no_briefs_folder_note "$plans" >&2
  exit 1
fi

command="${1:-}"
[ "$#" -gt 0 ] && shift

case "$command" in
  list)
    [ "$#" -eq 0 ] || usage
    now="$(get_now)"
    list_briefs "$plans" "$root" "$marks" "$now"
    ;;
  check)
    [ "$#" -eq 0 ] || usage
    list_problem_lines "$plans" "$root" "$marks"
    ;;
  take)
    [ "$#" -eq 2 ] || usage
    refuse_unknown_brief "$plans" "$1" || exit 1
    now="$(get_now)"
    take_brief "$marks" "$1" "$2" "$now"
    ;;
  free)
    [ "$#" -eq 1 ] || usage
    free_session "$marks" "$1"
    ;;
  free-brief)
    [ "$#" -eq 1 ] || usage
    free_brief "$marks" "$1"
    ;;
  done)
    [ "$#" -eq 1 ] || usage
    finish_brief "$plans" "$marks" "$1"
    ;;
  *)
    usage
    ;;
esac
