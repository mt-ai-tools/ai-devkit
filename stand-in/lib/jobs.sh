#!/usr/bin/env bash
# Which model does each of the stand-in's reading jobs, and how long it may
# take, in one place. Sourced, never executed.
#
# A job that misreads moves up a model by changing its one line here, and the
# change is measured on the real past cases the stand-in keeps; nothing else
# names a model. Full names, not the CLI's aliases: an alias moves to the next
# release on its own, and a job's model changes only when someone says so.

# The reader turns a finished reply into the fixed form: reading only, so the
# smallest model that reads it right.
READER_MODEL="claude-haiku-4-5"

# The sorter names a question's kind and its option's risks: a judgement
# against the preset's own words, a step up from reading.
SORTER_MODEL="claude-sonnet-5-5"

# How long each job may take before it is refused. Both run inside one
# end-of-reply hook, one after the other, alongside whatever else the gate asks,
# so together they stay well inside the hook's own limit; a job stopped here is
# a refusal the gate can route, where a hook stopped by Claude Code says nothing.
# Measured 2026-10-05: a fresh reader call answered in under 8 s.
READER_SECONDS=30
SORTER_SECONDS=40
