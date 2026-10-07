#!/usr/bin/env bash
# The secret scanner, in one place: a text handed to Betterleaks on stdin,
# and whether it found a key-shaped secret in it. The only part of the
# stand-in that knows the scanner, or the tool installer it is reached
# through. Sourced, never executed.
#
# Betterleaks rather than gitleaks (the operator's pick, 2026-10-07): the two
# share their author, and gitleaks is in security-patches-only mode, learning
# no new key formats. It sees secrets by their shape alone, so a password in
# plain words passes it; the secret check's agent reads for those.
#
# Reached through mise, called for this one command and never activated
# (the host's own rule: no tool of its on the machine's path), at one release
# pinned here. Run offline: mise never fetches at a scan, so a scan reaches
# nothing, and a machine without the release installed refuses the scan,
# naming the command that installs it, rather than fetching it unasked.

# Loaded once, however many of the stand-in's parts source it, as words.sh is.
[ -z "${STAND_IN_LOADED_SCANNER:-}" ] || return 0
STAND_IN_LOADED_SCANNER=1
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# The scanner's one pin: its source as mise names it, and the release. 1.9.0,
# never the 2.0 release candidate published a day after it (the operator,
# 2026-10-07). Checked when installed: mise held its download to the
# release's checksums and their Sigstore signature, it is one static binary,
# and nothing ran at install (2026-10-07).
SCANNER_TOOL="betterleaks@1.9.0"
SCANNER_PROGRAM="betterleaks"
SCANNER_INSTALLER="mise"

# The status the scanner is told to end with when it finds something; any
# other status but 0 is the scanner failing, which never reads as clean.
SCANNER_FOUND_STATUS=7

# How long a scan may take before it is refused. Measured 2026-10-07: under
# half a second for a short text.
SCANNER_SECONDS=30

# Its words for a scan of stdin. Each one closes a way a text could pass
# unseen or be sent somewhere:
# --ignore-gitleaks-allow: an allow comment on a line, gitleaks' or its own,
#   otherwise hides that line's secret (measured 2026-10-07), and a case's
#   text is written from what an agent typed.
# --redact, and its output thrown away: what it found is never printed.
# No --validation: that sends what it found to the issuer's live service.
SCANNER_WORDS=(stdin --no-banner --no-color --redact --log-level error --ignore-gitleaks-allow
  --exit-code "$SCANNER_FOUND_STATUS")

# mise's settings for the call, over a cleared environment (the same ways in
# mf-toolchain closes for its runs, measured there 2026-10-06): no settings
# file of the folder, its parents, the user or the machine is read, so none
# can turn a check off or name another release; offline, so nothing is
# fetched. The scanner itself reads its rules from a variable or from a file
# in its folder where one is there (measured 2026-10-07), so it runs on a
# cleared environment, in an empty folder of its own.
SCANNER_NOWHERE="/dev/null/stand-in-none"
SCANNER_SETTINGS=(
  "MISE_OFFLINE=1"
  "MISE_QUIET=1"
  "MISE_GLOBAL_CONFIG_FILE=$SCANNER_NOWHERE"
  "MISE_SYSTEM_CONFIG_FILE=$SCANNER_NOWHERE"
  "MISE_OVERRIDE_CONFIG_FILENAMES=$SCANNER_NOWHERE"
  "MISE_OVERRIDE_TOOL_VERSIONS_FILENAMES=$SCANNER_NOWHERE"
  "MISE_ENV="
  "MISE_AUTO_ENV=false"
)

# What a scan answers.
SCAN_CLEAN="clean"
SCAN_FOUND="found"

# --- Reads.

# Whether the text given holds a key-shaped secret, scanned in the empty
# folder given: found or clean; a refusal on stderr and a non-zero status
# where the scanner could not run, ran out of time, or ended in any other
# way, never read as clean. The folder is the caller's to make and remove:
# a read leaves it as it found it.
get_scan_state() {
  local text="$1" folder="$2" status=0 carried=() listed
  if [ ! -d "$folder" ] || ! listed="$(ls -A "$folder" 2>/dev/null)" || [ -n "$listed" ]; then
    refuse_scanner_folder_note >&2
    return 1
  fi
  # Where mise keeps what it installed, where the operator moved it: a
  # cleared environment would otherwise look in the default place and miss it.
  [ -z "${MISE_DATA_DIR:-}" ] || carried+=("MISE_DATA_DIR=$MISE_DATA_DIR")
  [ -z "${XDG_DATA_HOME:-}" ] || carried+=("XDG_DATA_HOME=$XDG_DATA_HOME")
  (cd "$folder" && printf '%s' "$text" | timeout -k 5 "$SCANNER_SECONDS" \
    env -i HOME="$HOME" PATH="$PATH" "${carried[@]}" "${SCANNER_SETTINGS[@]}" \
    "$SCANNER_INSTALLER" exec "$SCANNER_TOOL" -- "$SCANNER_PROGRAM" "${SCANNER_WORDS[@]}" \
    >/dev/null 2>&1) || status=$?
  case "$status" in
    0) printf '%s\n' "$SCAN_CLEAN" ;;
    "$SCANNER_FOUND_STATUS") printf '%s\n' "$SCAN_FOUND" ;;
    *)
      refuse_scanner_unrun_note "$SCANNER_TOOL" "$status" >&2
      return 1
      ;;
  esac
}
