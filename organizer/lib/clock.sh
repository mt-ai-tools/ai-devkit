#!/usr/bin/env bash
# When now is, and how long ago a stamp was, in one place. Sourced, never
# executed.
. "$(dirname "${BASH_SOURCE[0]}")/words.sh"

# Under this many seconds an age is said in minutes, under the next in hours,
# beyond it in days: a mark minutes old is a session at work, one hours old may
# be a long step, and one days old is most likely a crash nobody freed.
AGE_MINUTES_BELOW=3600
AGE_HOURS_BELOW=172800

# --- Transforms.

# True if the value is a UTC stamp in the one form a mark is written in.
is_utc_stamp() {
  [[ "$1" =~ ^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$ ]]
}

# A UTC stamp as seconds since the epoch, worked out in awk from the calendar
# rather than handed to `date`: only GNU `date` parses a given time, and the
# kit needs nothing but bash and awk. Refused for anything but a stamp.
to_epoch_seconds() {
  is_utc_stamp "$1" || return 1
  awk -v stamp="$1" '
    # Days from 1970-01-01 to a civil date, by the proleptic Gregorian count
    # (Howard Hinnant, "chrono-Compatible Low-Level Date Algorithms").
    function days(y, m, d,   era, yoe, doy, doe) {
      y -= (m <= 2)
      era = int((y >= 0 ? y : y - 399) / 400)
      yoe = y - era * 400
      doy = int((153 * (m > 2 ? m - 3 : m + 9) + 2) / 5) + d - 1
      doe = yoe * 365 + int(yoe / 4) - int(yoe / 100) + doy
      return era * 146097 + doe - 719468
    }
    BEGIN {
      y = substr(stamp, 1, 4) + 0; mo = substr(stamp, 6, 2) + 0; d = substr(stamp, 9, 2) + 0
      h = substr(stamp, 12, 2) + 0; mi = substr(stamp, 15, 2) + 0; s = substr(stamp, 18, 2) + 0
      printf "%d\n", days(y, mo, d) * 86400 + h * 3600 + mi * 60 + s
    }
  '
}

# How long ago a stamp was, as of another, in whole units: minutes under an
# hour, hours under two days, days beyond. A stamp later than now reads as no
# time at all rather than a negative age; a mark is written from the same
# clock it is read against, so only a hand-edited one can be ahead.
format_age() {
  local since now seconds
  since="$(to_epoch_seconds "$1")" || return 1
  now="$(to_epoch_seconds "$2")" || return 1
  seconds=$((now - since))
  [ "$seconds" -ge 0 ] || seconds=0
  if [ "$seconds" -lt "$AGE_MINUTES_BELOW" ]; then
    age_minutes_words $((seconds / 60))
  elif [ "$seconds" -lt "$AGE_HOURS_BELOW" ]; then
    age_hours_words $((seconds / 3600))
  else
    age_days_words $((seconds / 86400))
  fi
}

# --- Reads.

# Now, as a UTC stamp. The one place the organizer asks the clock, so a suite
# pins every age and every mark's since by standing a `date` of its own first
# on the path, and the organizer itself carries no switch for faking time.
get_now() {
  date -u +%Y-%m-%dT%H:%M:%SZ
}
