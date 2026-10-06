---
# The stand-in's skill hook reads this name to know this skill: it is
# written here once, and renaming the skill is the whole of renaming it.
name: devkit-stand-in-settled
description: >-
  Shows the user the questions the stand-in settled without them, each
  with its number, the answer settled on, when, and in which session and
  brief. Use whenever the user asks in plain words what passed silently:
  "what passed silently today?", "what did the stand-in settle?", "what
  was decided without me?". Today's by default; pass "all" as the
  argument when the user asks for every one, whatever the day.
# Asked in plain words, never typed: the list has no command of its own,
# so the skill stays out of the slash-command menu while the model may
# still reach it by its description.
user-invocable: false
# No inline command and no allowed-tools: the stand-in's hook, run after
# this skill loads, shows the list to the user itself, for the reason the
# organizer's list goes that way: a list a model copies can lose lines.
# With nothing to run, the skill loads without an approval prompt.
---

The stand-in's hook has already shown the user its list of settled
questions, exactly as it printed it. You cannot see that list. Do not
read the stand-in's log yourself, and never repeat, summarise or reorder
the list.

The hook also leaves you a note saying what it showed. If that note is
in your context, your whole reply is one short line saying what the note
says has been shown above. If there is no such note, the hook is not
mounted in this project: your whole reply is one short line saying the
list could not be shown, because the stand-in's skill hook is not
mounted.
