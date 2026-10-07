bats_require_minimum_version 1.5.0

# Behavior tests for the secret scanner: a text with a key-shaped secret is
# found and one without is clean, read through the pinned release run
# offline in an empty folder of its own on a cleared environment; a scanner
# that cannot run, or a folder that is not empty, is refused, never read as
# clean. The suite's own mise stands in for the scanner, but in the last
# test, where the real release scans a fake key.

load fake-claude
load fake-mise

setup() {
  setup_fake_claude
  . "$lib/scanner.sh"
  folder="$BATS_TEST_TMPDIR/scan"
  mkdir -p "$folder"
}

@test "a text holding a key-shaped secret is found, and one without is clean" {
  setup_fake_mise
  run get_scan_state "token: $fake_key_mark" "$folder"
  [ "$status" -eq 0 ]
  [ "$output" = "$SCAN_FOUND" ]
  run get_scan_state "Five tries, not ten." "$folder"
  [ "$status" -eq 0 ]
  [ "$output" = "$SCAN_CLEAN" ]
  [ "$(cat "$FAKE_MISE/stdin")" = "Five tries, not ten." ]
}

@test "the pinned release is run through mise, offline, reading no settings file, and told what keeps a secret from passing" {
  setup_fake_mise
  export BETTERLEAKS_CONFIG="$BATS_TEST_TMPDIR/rules.toml" GITLEAKS_CONFIG="$BATS_TEST_TMPDIR/rules.toml"
  run get_scan_state "text" "$folder"
  [ "$status" -eq 0 ]
  [ "$(sed -n '1,4p' "$FAKE_MISE/args")" = $'exec\nbetterleaks@1.9.0\n--\nbetterleaks' ]
  grep -qxF -- stdin "$FAKE_MISE/args"
  grep -qxF -- --ignore-gitleaks-allow "$FAKE_MISE/args"
  grep -qxF -- --redact "$FAKE_MISE/args"
  run ! grep -q -- --validation "$FAKE_MISE/args"
  grep -qxF MISE_OFFLINE=1 "$FAKE_MISE/env"
  grep -q '^MISE_GLOBAL_CONFIG_FILE=/dev/null/' "$FAKE_MISE/env"
  grep -q '^MISE_SYSTEM_CONFIG_FILE=/dev/null/' "$FAKE_MISE/env"
  grep -q '^MISE_OVERRIDE_CONFIG_FILENAMES=/dev/null/' "$FAKE_MISE/env"
  # A variable naming other rules never reaches it, and its folder is empty.
  run ! grep -q '_CONFIG=.*rules.toml' "$FAKE_MISE/env"
  [ "$(cat "$FAKE_MISE/pwd")" = "$folder" ]
  [ ! -s "$FAKE_MISE/folder" ]
}

@test "a scanner that cannot run is refused with how to install it, never read as clean" {
  setup_fake_mise
  for code in 1 2 127; do
    mise_status "$code"
    run --separate-stderr get_scan_state "text" "$folder"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
    [ "$stderr" = "$(refuse_scanner_unrun_note betterleaks@1.9.0 "$code")" ]
  done
}

@test "a folder holding anything, or none, is refused before the scanner runs" {
  setup_fake_mise
  printf 'x\n' >"$folder/.betterleaks.toml"
  run --separate-stderr get_scan_state "text" "$folder"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_scanner_folder_note)" ]
  run --separate-stderr get_scan_state "text" "$BATS_TEST_TMPDIR/none"
  [ "$status" -eq 1 ]
  [ ! -e "$FAKE_MISE/args" ]
}

# The real release, on a fake key of a well-known shape, built here so no
# file of the kit holds one. Run where the release is installed; a machine
# without it skips this proof, naming the command that installs it, and the
# case-writer there holds every case back.
@test "the real pinned release finds a fake key-shaped secret offline, and passes a plain-word password" {
  if ! MISE_OFFLINE=1 mise where "$SCANNER_TOOL" </dev/null >/dev/null 2>&1; then
    skip "$SCANNER_TOOL is not installed: mise install $SCANNER_TOOL"
  fi
  key="ghp_$(printf 'aB3dE5fG7hJ9kL1mN3pQ5rS7tU9vW1xY3zA5')"
  run get_scan_state "The token is $key, kept for the build." "$folder"
  [ "$status" -eq 0 ]
  [ "$output" = "$SCAN_FOUND" ]
  # Its allow comment hides nothing.
  run get_scan_state "token: $key # betterleaks:allow" "$folder"
  [ "$output" = "$SCAN_FOUND" ]
  run get_scan_state "The password is correct horse battery staple." "$folder"
  [ "$status" -eq 0 ]
  [ "$output" = "$SCAN_CLEAN" ]
}
