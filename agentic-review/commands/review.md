---
description: Adversarial review — over the repository, an area, or everything since a revision, fixing what it may and queueing the rest
argument-hint: [--scope :all|<path>|<revision>]
---

Run a review.

1. Look first for a run that never finished. A run records the finding it is
   about to fix — in the notes folder, `.agentic-review/state` under the
   project root you run from — and clears that record when the fix is
   committed; a record still standing means the last run died between those
   two moments.

   Do not clean up after it. What sits in the working tree may be that fix, or
   may be work done since by someone else — and nothing on disk tells the two
   apart. Report which finding it stopped on, name the notes holding the
   queue, and start nothing. A half-applied fix costs a minute of the
   operator's attention; a tree reset on a guess costs whatever it destroyed.

2. Read the invocation.

       --scope :all         the whole repository as it stands — the default
       --scope <path>       that area as it stands
       --scope <revision>   everything committed since that revision, plus
                            uncommitted and untracked work

   Bare `/review` means `--scope :all`.

3. Launch the `reviewer` agent with the scope, and with the two locations
   the turn-start digest names: the rules directory, and the conventions
   collection where one was named. The reviewer has no other way to learn
   them — it starts empty, and that is the point. No digest in view means
   the kit is not mounted whole for this project: stop and say so.

   On a re-review add the findings the operator declined, and nothing else:
   it finds the diff and the context itself.

   Every launch is a new reviewer. Never continue one that has already run: the
   empty context is the reason it is a separate agent at all, and one reading
   this range for the fifth time is remembering rather than reading. A round
   that costs far less than the one before it is the sign this went wrong.

4. Relay its report to the operator verbatim. Do not summarize it, soften it,
   or argue with it — the report is the reviewer's, not yours.

5. Then take the `BLOCK` findings in the report's order and settle which the
   run may answer itself. A finding is taken only where the rule or entry it
   cites says — in its frontmatter, under its autonomy key — that a
   fix of that kind may be made without asking, and where the fix in hand is
   of that kind. Everything else is held for the operator.

   Then say the count, on one line, before anything moves: how many rules were
   judged, how many blocked, how many are being taken and how many held. The
   report is a wall of lines and the number is what tells the operator how
   much of their evening this is. The reviewer cannot say it — it knows
   nothing of what may be taken unasked, and must not.

6. One thing is never taken alone, whatever a rule permits: a fix that would
   create a folder, a module or a repository, or move anything between
   modules. Those reshape the project rather than tidy inside it, and the
   shape is the operator's. Held, however small the edit looks.

   A rename is not among them where a rule grants it. Nothing published
   reaches anyone unattended, since releasing is its own deliberate act — so
   a rename staged here is a break the operator still meets before it ships,
   with the note that has to accompany it already written.

   Above all of these stand the run's own laws: the rule files and the
   conventions collection are never edited by the run on any grant, because
   the run is steered by them — an enforcer that writes its mandate is the
   one loop nothing later catches. A law change is a held finding carrying
   the exact text proposed, lands only on the operator's answer, in its own
   commit, and carries nothing the conversation did not cover: a clause
   inferred beyond the answer — however reasonable — is the next proposal,
   not part of the edit. An amendment the operator ratifies then owes a
   sweep of everything it newly reaches, in the same round, since an entry
   binds however old the code is.

7. Write each held finding down as it is held — the rule, the paths, the
   lines, and what the fix would have been — in the notes folder step 1
   names. Never ask mid-run. A run that
   stops for an answer stalls until somebody comes back to it, and the whole
   point of one that fixes what it may is that it does not need anybody
   there. The queue waits; the run does not.

   Key each held finding by its rule and where it sits, and look for that key
   before writing. A later round re-finds what it could not fix, since the
   code still breaks the rule — a re-find updates the entry it matches.
   Written blind, the queue fills with the same question asked five times.

   Keep the notes rather than memory as the queue's one home even where the
   operator is sitting right there. A pass long enough to be worth starting is
   long enough to be compressed before it ends, and a queue held in a
   conversation is a queue that ends the moment the conversation does.

8. Then do the work, in the report's order, one finding at a time. Never two
   at once: a fix landing on ground another is still moving is the one
   failure this ordering exists to prevent. For each — implement it, verify it
   where it landed, and commit it on its own before starting the next.

   A finding annotated `IN MOTION` gets one step before anything else:
   re-read the site as it stands now. Still violating — fix it as any other.
   Gone — concurrent work overtook it: record it in the notes as overtaken,
   with what the site reads now, and move on to the next. Overtaken is a
   visible outcome, never a silent skip, and it is not a settled one — the
   closing re-review reads the same ground fresh and re-finds anything that
   only looked gone.

   Before starting a fix, write it to the notes as the one in hand, and clear
   that line when its commit lands. Between those two writes the run is the
   only thing that should have touched the tree; outside them nothing is
   half-done. That is what lets a later run tell an interrupted fix from
   ordinary uncommitted work.

   Verifying means the fix is watched failing, not merely watched passing.
   Where there is something to break — a value, a condition, a name a test
   asserts — break it, see the suite go red, and put it back. A green run over
   a test that asserts nothing is the same green as a working one, and that is
   how a quoting error can pass every file it broke.

   A verification is only as real as the tool that ran it: reach tools
   through the package's own declared dependencies, never by bare name
   from the network — a wrong tool that exits clean is a pass that
   checked nothing.

   Where nothing can be broken — a rename, a reworded line of prose — say what
   was checked instead, and do not dress a reading up as a verification.

   Read the fix against the rules before committing it, the ones a fix breaks
   most: duplication, placement, naming. Nearly everything a run finds in its
   own earlier work was avoidable here, and the alternative is discovering it
   a full re-read later.

   A fix taken unasked says so in a trailer — `Taken-Under: <rule>` — and
   differs in nothing else: the subject and body say what changed and why, as
   any commit does. The closing report is built by reading those trailers
   rather than by remembering, and a later reader sees which changes went in
   unwatched. Nothing else carries the trailer: a fix the operator asked for
   is not one taken unasked, and a placeholder in that field is counted like
   any other value by whatever reads it next.

9. Stop on the first failure. If a fix will not verify, halt the run and say
   which finding stopped it and what broke. Continuing would stack the rest
   of the work on a state nobody has checked, and that is a batch to throw
   away rather than progress.

10. Hold a finding again when an answer stops fitting. If an earlier fix
    changed what a later one should be, put it back in the queue with what
    changed rather than acting on a picture that has since moved.

11. Then begin again from the top, and keep going until a round surfaces
    nothing that is not already held, or the operator says stop. Not until the
    report is empty: a held finding is never fixed, so it comes back every
    round, and a run waiting for an empty report spins until somebody stops
    it. A round that turns up nothing new has said all it has to say.

    Each round re-reads this file before it starts: hours of output sit
    between a run and the instructions it began with, and a loop that drifts
    from them is worse than one that never ran.

    Told to stop, finish the fix in hand and start no new round. Told to stop
    in the middle of one, leave it and account for the run as it stands —
    an interruption is the operator arriving, and the next thing they should
    read is what happened while they were away.

12. However it ends — stopped, out of anything new to find, or interrupted
    mid-work — say what was taken unasked before anything else is said. This
    comes first because it is the part the operator did not watch, and the
    moment they are back is the moment to account for it. One line each,
    grouped by the rule or entry that raised it, and each line concrete
    enough to picture without opening the diff: the module, and what changed
    — the literal that moved and what it moved to, the name before and after,
    the path renamed from what to what. Then the commit, so any one of them
    can be read whole.

    A summary that says a constant was centralized has told the operator
    nothing they did not already know from the rule's name.

    Then the held findings go to them, one at a time, in the order they were
    raised, read back from the notes rather than from memory. Collect
    decisions only; change nothing until the last is answered.

    Everything needed to decide goes in the question itself, because that is
    the one thing the operator is looking at: above it lies however much
    machine output the run has produced since. Each question carries, in this
    order —

        Finding 3 of 7 — <what is wrong> (<the rule, or the entry where a
        convention was broken>)
        <path:line>, <path:line>…

          <the offending lines>

        Proposed fix: <one or two sentences>. Fix it?

    — and the choices under it carry nothing but which way it goes.

    The rule and the paths always: the rule because a finding is a claim made
    under something, the paths so the operator can look for themselves. Where
    a convention was broken, name the entry rather than the rule that defers
    to it — one rule stands in for a whole collection, and its name says
    nothing about what was broken. The offending lines only where a few of
    them say it plainly; skip them without remark where the finding is
    structural or spread, since a fragment standing in for a change it cannot
    show is worse than no fragment. Where one finding repeats across files,
    quote one site and count the others.

    Quote what is there; do not draft what would replace it. Reading the
    existing lines is nearly free, and writing the replacement is the work
    this step exists to defer.

    Never batch findings into one question — they are decided one by one, but
    in a single unbroken stretch of the operator's attention, so waiting on
    work never interrupts deciding.

    Answer each in the notes as it is settled, fixed or declined and why, so
    the file ends as a record of the run rather than a queue nobody emptied.
    Then do the work as step 8 describes. The run is over when the last held
    finding is answered, and not before.

13. Close with what happened: fixed, taken without asking, held, declined,
    overtaken, and where it stopped if it stopped. Group it by the rule or entry that raised
    each, so a reader sees which kinds of thing this pass was made of, and
    name each fix's commit so any one of them can be read on its own. Write
    the close into the run's notes beside the queue: a report only spoken is a
    report gone by morning.

14. Then, unless the operator stopped the run, run the reviewer again, naming
    any findings they declined — re-review is cheap, and the run is not done
    until the report closes `PASS`. A stop is an answer about what happens
    next, and it outranks this.

15. A finding the operator declines is allowed — record the decline and its
    reason in the notes, so skipping is a visible choice, never a silent one.
