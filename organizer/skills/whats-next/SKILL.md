---
# The organizer's skill hook reads this name to know its own skill: it is
# written here once, and renaming the skill is the whole of renaming it.
name: devkit-whats-next
description: >-
  Shows the user the work organizer's list of briefs (ready now, waiting
  and on what, taken, same place as a taken one). Use whenever the user
  asks in plain words what to work on: "what's next?", "what can I
  start?", "what's ready?", "what is waiting?", "what is taken?".
# Asked in plain words, never typed: the list has no command of its own,
# so the skill stays out of the slash-command menu while the model may
# still reach it by its description.
user-invocable: false
# No inline command and no allowed-tools: the organizer's hook, run after
# this skill loads, shows the list to the user itself. Inlining the list
# here and asking the model to copy it lost the last line in one run of
# six. With nothing to run, the skill also loads without an approval
# prompt, so a headless session needs no grant for it.
---

The organizer's hook has already shown the user its list of briefs,
exactly as the organizer printed it. You cannot see that list. Do not
run the organizer yourself, and never repeat, summarise, reorder or pick
from the list: which ready brief comes first is the user's choice.

The hook also leaves you a note saying what it showed. If that note is
in your context, your whole reply is one short line saying what the note
says has been shown above. If there is no such note, the hook is not
mounted in this project: your whole reply is one short line saying the
list could not be shown, because the organizer's hook is not mounted.
