bats_require_minimum_version 1.5.0

# Behavior tests for reading the preset: the kinds and risks come from
# whatever preset is pointed at, every risk is named, and a preset that cannot
# be read whole is refused rather than read in part.

load fake-claude

setup() {
  setup_fake_claude
  . "$lib/preset.sh"
}

@test "the kinds are every entry's name and summary" {
  preset "alpha:First. beta:Second." "one"
  printf '# Not an entry\n' >"$preset_dir/questions/README.md"
  run list_kinds "$preset_dir"
  [ "$status" -eq 0 ]
  [ "$output" = '[{"name":"alpha","summary":"First."},{"name":"beta","summary":"Second."}]' ]
}

@test "a kind with no summary is refused" {
  preset "alpha:First." "one"
  printf -- '---\nroute: ask\n---\n' >"$preset_dir/questions/bare.md"
  run --separate-stderr list_kinds "$preset_dir"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_kind_summary_note bare)" ]
}

@test "a preset with no kinds is refused" {
  preset "" "one"
  run --separate-stderr list_kinds "$preset_dir"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_kinds_note "$preset_dir/questions")" ]
}

@test "the risks are every bullet's name and words, run on over its lines" {
  text=$'---\nsummary: Risks.\n---\n\n# Risks\n\nSome prose.\n\n- `first-risk` — The first,\n  running on.\n- `second` — The second.\n\nMore prose.\n'
  run parse_risks risks.md "$text"
  [ "$status" -eq 0 ]
  [ "$output" = '[{"name":"first-risk","words":"The first, running on."},{"name":"second","words":"The second."}]' ]
}

@test "a bullet with no name is refused, never dropped" {
  text=$'# Risks\n\n- `first` — The first.\n- The second, unnamed.\n'
  run --separate-stderr parse_risks risks.md "$text"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unnamed_risk_note risks.md 4)" ]
}

@test "a risk named twice, or none at all, is refused" {
  run --separate-stderr parse_risks risks.md $'- `one` — A.\n- `one` — B.\n'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_risk_twice_note risks.md one)" ]
  run --separate-stderr parse_risks risks.md $'# Risks\n\nNone yet.\n'
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_no_risks_note risks.md)" ]
}

@test "a preset with no risks file is refused" {
  preset "alpha:First." "one"
  rm "$preset_dir/challenges/risks.md"
  run --separate-stderr list_risks "$preset_dir"
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_unreadable_file_note "$preset_dir/challenges/risks.md")" ]
}

@test "the kit's own preset reads whole" {
  run list_kinds "$BATS_TEST_DIRNAME/../../presets/stand-in"
  [ "$status" -eq 0 ]
  run list_risks "$BATS_TEST_DIRNAME/../../presets/stand-in"
  [ "$status" -eq 0 ]
}

@test "a kind's entry holds its route and its challenges" {
  preset "alpha:First." "one"
  printf -- '---\nsummary: First.\nroute: ladder\nchallenge: Sure?\nsecond-challenge: Read them?\n---\n' >"$preset_dir/questions/alpha.md"
  run get_kind_entry "$preset_dir" alpha
  [ "$status" -eq 0 ]
  [ "$output" = '{"name":"alpha","summary":"First.","route":"ladder","challenge":"Sure?","second_challenge":"Read them?"}' ]
}

@test "a kind with no known route, or a second challenge alone, is refused" {
  preset "alpha:First." "one"
  printf -- '---\nsummary: First.\n---\n' >"$preset_dir/questions/alpha.md"
  run --separate-stderr get_kind_entry "$preset_dir" alpha
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_kind_route_note alpha "" ask ladder)" ]
  printf -- '---\nsummary: First.\nroute: ask\nsecond-challenge: Read them?\n---\n' >"$preset_dir/questions/alpha.md"
  run --separate-stderr get_kind_entry "$preset_dir" alpha
  [ "$status" -eq 1 ]
  [ "$stderr" = "$(refuse_second_challenge_alone_note alpha)" ]
}

@test "every kind of the kit's own preset reads whole" {
  for entry in "$BATS_TEST_DIRNAME/../../presets/stand-in/questions/"*.md; do
    run get_kind_entry "$BATS_TEST_DIRNAME/../../presets/stand-in" "$(basename "$entry" .md)"
    [ "$status" -eq 0 ]
  done
}
