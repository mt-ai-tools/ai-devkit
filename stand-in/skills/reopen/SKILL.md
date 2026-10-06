---
# The stand-in's skill hook reads this name to know this skill: it is
# written here once, and renaming the skill is the whole of renaming it.
name: devkit-stand-in-reopen
description: >-
  Brings back one question the stand-in settled without the user, or one
  decision of a round it laid out before building, shows it to them in
  full, and opens it again to be asked as a normal question. Use whenever
  the user asks to reopen one by its number from the stand-in's settled
  list or a round's list: "reopen 3", "bring back question 3". Pass
  the number alone as the argument; add the word "exchange" after it
  when the user asks to see the exchange word for word, as in "3
  exchange".
# Asked in plain words, never typed, as the settled list is.
user-invocable: false
# No inline command and no allowed-tools: the stand-in's hook, run after
# this skill loads, shows the question to the user itself and hands you
# the note below.
---

The stand-in's hook has already shown the user what they asked for,
exactly as it printed it. You cannot see it. Do not read the stand-in's
log yourself, and never repeat or summarise what was shown.

The hook also leaves you a note. If the note says a question is open
again, do what it says: ask the user that question now, in plain
conversation, as you would any question of yours, with its options and
your recommendation, and wait for their answer. If the note says the
stand-in could not do what was asked, your whole reply is one short line
pointing at the reason shown above. If there is no note at all, the hook
is not mounted in this project: your whole reply is one short line
saying the question could not be reopened, because the stand-in's skill
hook is not mounted.
