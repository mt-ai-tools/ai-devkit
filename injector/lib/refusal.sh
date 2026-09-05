#!/usr/bin/env bash
# The words the hook hands the operator when it refuses a turn — in one place,
# so the suite asserts the wiring rather than the wording. Sourced, never
# executed.

# Why a turn was refused: the rules directory holds no rule files.
no_rules_note() {
  printf 'No rule files at: %s\n' "$1"
}

# What a refusal means for the operator, whatever caused it.
turn_refused_note() {
  printf 'Rules hook failed: the rules were not put in front of the agent. Nothing runs until this is fixed.\n'
}
