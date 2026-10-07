---
summary: How a session waits on another session's work, and the big look around once the wait is over, reported before work resumes.
---

# The resume look-around

A session that must wait on another session's work waits for one of two
things:

- Another brief to be finished. The wait is written into its own brief,
  as that brief waiting on the other, and is over once the other is
  finished and gone from the plans.
- A repository another session holds, in a module this session must
  touch, to have neither uncommitted changes nor commits not yet pushed.
  The wait is over once it has neither.

Either way the session starts the stand-in's wait as a background
command, says what it waits on, and stops. It never takes, commits or
pushes the other session's work. When the wait is over, the session is
woken and sent:

- `look-around` — once the wait is over:
  > A lot changed. Take a big look around and report back.

The agent rechecks its ground — its brief, the code it touches, what
the other session landed — before building on what it knew before the
wait. It reports what landed and which earlier answers may no longer
hold, asks again any decision the wait shook, one at a time, and waits
for the operator's go: work resumes only after the report.

Each message the stand-in sends is the quote under its name, word for
word.
