# A `mise` of the suite's own, so the scanner's handling is proved without the
# real scanner: it keeps the arguments, the environment, the folder and the
# text it was given, and ends as the scanner would: with the found status
# where the text holds the suite's fake key mark, cleanly otherwise, or with
# the status the test gives. Loaded by the suites, never run alone; the
# suites load fake-claude first, which makes the folder it goes in.

# What marks a text as holding a key-shaped secret, for the fake alone.
fake_key_mark="FAKE-KEY-SHAPED"

setup_fake_mise() {
  export FAKE_MISE="$BATS_TEST_TMPDIR/mise"
  mkdir -p "$FAKE_MISE"
  cat >"$fakebin/mise" <<'FAKE'
#!/usr/bin/env bash
dir="${BASH_SOURCE[0]%/*}/../mise"
printf '%s\n' "$@" >"$dir/args"
env >"$dir/env"
pwd >"$dir/pwd"
ls -A >"$dir/folder"
cat >"$dir/stdin"
[ -f "$dir/status" ] && exit "$(cat "$dir/status")"
grep -q "FAKE-KEY-SHAPED" "$dir/stdin" && exit 7
exit 0
FAKE
  chmod +x "$fakebin/mise"
}

# The status the fake mise ends with, whatever it was given.
mise_status() {
  printf '%s' "$1" >"$FAKE_MISE/status"
}
