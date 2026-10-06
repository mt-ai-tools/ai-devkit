---
# The stand-in's start hook reads this name to know its command: it is
# written here once, and renaming the skill is the whole of renaming the
# command.
name: devkit-stand-in
description: >-
  Starts the stand-in for this session: with a brief's name, takes that
  brief and switches the stand-in on; with --session, switches it on
  with no brief; bare, shows the briefs to pick from.
argument-hint: "[brief | --session]"
# Typed by the user only. The stand-in's start hook acts on the command as
# typed, with the session's id, which the model does not know; loaded by
# the model instead, the command would reach no hook and switch nothing on.
disable-model-invocation: true
# No inline command and no allowed-tools: the hook has done everything
# before this skill loads, and leaves you the note below.
---

The stand-in's start hook has already acted on the user's command before
you read this. Do not run the work organizer, and do not write or remove
anything in the stand-in's folders yourself.

The hook leaves you a note in your context. If the note hands you the
stand-in's opener, follow the opener now: that is your work from here.
If the note says the work organizer's list was shown, your whole reply
is one short line saying the list is above, and that the user starts a
brief by typing this command again with its name. If the note says the
stand-in was switched on with no brief, your whole reply is one short
line saying so. If there is no such note, the hook did not act on the
command — it is not mounted in this project, or could not run: your
whole reply is one short line saying the stand-in was not started, for
that reason.
