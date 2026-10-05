# Behavior tests for the clock: a mark's stamp read from the calendar, and an
# age said in minutes, hours or days at the right edges.

setup() {
  . "$BATS_TEST_DIRNAME/../lib/clock.sh"
}

@test "a stamp is seconds since the epoch, leap days counted" {
  run to_epoch_seconds 1970-01-01T00:00:00Z
  [ "$output" = "0" ]
  run to_epoch_seconds 2024-02-29T12:34:56Z
  [ "$output" = "1709210096" ]
  run to_epoch_seconds 2026-10-04T21:30:00Z
  [ "$output" = "1791149400" ]
}

@test "anything but a UTC stamp is refused" {
  for value in '' 2026-10-04 '2026-10-04 21:30:00' 2026-10-04T21:30:00+02:00 2026-10-04T21:30:00; do
    run to_epoch_seconds "$value"
    [ "$status" -eq 1 ]
    [ -z "$output" ]
  done
}

@test "an age is minutes under an hour, hours under two days, days beyond" {
  now=2026-10-04T21:30:00Z
  run format_age 2026-10-04T21:15:01Z "$now"
  [ "$output" = "$(age_minutes_words 14)" ]
  run format_age 2026-10-04T20:30:01Z "$now"
  [ "$output" = "$(age_minutes_words 59)" ]
  run format_age 2026-10-04T20:30:00Z "$now"
  [ "$output" = "$(age_hours_words 1)" ]
  run format_age 2026-10-02T21:30:01Z "$now"
  [ "$output" = "$(age_hours_words 47)" ]
  run format_age 2026-10-02T21:30:00Z "$now"
  [ "$output" = "$(age_days_words 2)" ]
}

@test "a stamp ahead of now is no time at all, and a bad one is refused" {
  run format_age 2026-10-05T00:00:00Z 2026-10-04T21:30:00Z
  [ "$output" = "$(age_minutes_words 0)" ]
  run format_age yesterday 2026-10-04T21:30:00Z
  [ "$status" -eq 1 ]
}

@test "now is a UTC stamp" {
  run get_now
  [ "$status" -eq 0 ]
  run is_utc_stamp "$output"
  [ "$status" -eq 0 ]
}
