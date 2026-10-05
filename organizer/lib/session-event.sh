#!/usr/bin/env bash
# What the organizer's session hooks read from an event: the session it
# belongs to, and nothing else. Needs jq, for the reason the skill's hook does:
# an event is JSON written by Claude Code, and parsing it by hand is how an
# escaped character slips through. Sourced, never executed.

# The session id an event carries, read from stdin; nothing where the event has
# none, holds one that is not a string, or is not JSON at all. Only the id is
# taken: a turn's event carries the prompt too, and nothing here reads it.
session_event_id() {
  jq -r '.session_id // empty | strings' 2>/dev/null || true
}
