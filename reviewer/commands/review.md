---
description: Adversarial review — over the repository, an area, or everything since a revision; fixes what it may, asks the rest
argument-hint: [--scope :all|<path>|<revision>|<commits>]
---

Run a review.

1. Look first for a run that never finished. A run records the finding it is
   about to fix in the reviewer's notes folder, which the kit's config reader
   names, and clears that record when the fix is committed; a record still
   standing means the last run died between those two moments.

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
       --scope <commits>    exactly those commits, each named with its
                            repository, and nothing else

3. Size the review. A revision or commits scope gets one reviewer for each 1,500
   changed lines, at least one and at most four, each over a part of about
   equal size, split along modules where it can be. A scope with no
   revision gets one reviewer. Where the operator's yes named a number, use
   theirs.

4. Launch the `reviewer` agents at once, each with its part, the decisions
   the work was built under where there are any, and the two locations the
   turn-start digest names: the rules directory, and the conventions
   collection where one was named. The reviewer has no other way to learn
   them — it starts empty, and that is the point. No digest in view means
   the kit is not mounted whole for this project: stop and say so.

   On a confirming review add the findings already declined, and nothing
   else: it finds the diff and the context itself.

   Every launch is a new reviewer. Never continue one that has already run: the
   empty context is the reason it is a separate agent at all.

5. Relay each report to the operator verbatim. Do not summarize it, soften it,
   or argue with it — the report is the reviewer's, not yours.

6. Then sort the `BLOCK` findings, in the reports' order, by the workflow's
   decisions.md: its Fixes table says who decides each kind of fix, and a
   kind it does not name falls to its first table.

   - Silent and Told: taken by the run.
   - Advisor: one advisor for each such finding, all started together; its
     answer is taken as the decision.
   - Operator: held for the operator.
   - Too big to fix here, however it is decided: held, to be written down
     as the workflow's s2-route.md says, never fixed by this run.

   Then say the count, on one line, before anything moves: how many rules were
   judged, how many blocked, how many are taken and how many held. The
   report is a wall of lines and the number is what tells the operator how
   much of their evening this is.

7. The run's own laws stand above every level: the rule files and the
   conventions collection are never edited by the run, because the run is
   steered by them — an enforcer that writes its mandate is the one loop
   nothing later catches. A law change is a held finding carrying the exact
   text proposed, lands only on the operator's answer, in its own commit,
   and carries nothing the conversation did not cover: a clause inferred
   beyond the answer — however reasonable — is the next proposal, not part
   of the edit.

8. Write each held finding down as it is held — the rule, the paths, the
   lines, and what the fix would have been — in the notes folder step 1
   names. Never ask mid-run: the queue waits; the run does not.

   Key each held finding by its rule and where it sits, and look for that key
   before writing: a re-find updates the entry it matches. Keep the notes
   rather than memory as the queue's one home: a queue held in a
   conversation ends the moment the conversation is compacted.

9. Then do the work, in the reports' order, one finding at a time. Never two
   at once: a fix landing on ground another is still moving is the one
   failure this ordering exists to prevent. For each — plan the fix, hand it
   to a fixer, judge what came back, and commit it on its own before starting
   the next.

   The plan is the run's: what changes, where, and what will be broken to
   watch it fail. Write it down, rather than leave the shape of the fix to
   whoever types it.

   The fix is made by the `fixer` agent. Launch it with the finding, the
   plan, the two locations step 4 passed on, where the kit is mounted from,
   and the decision the fix rests
   on. Every finding gets a new fixer: one carrying the last fix in its
   context reads this site through it.

   It returns what it changed and how it watched the change fail. Read that
   beside the diff: a report of red that does not say what was broken is a
   claim, not a verification. A fixer that could not verify is a failure under
   step 10. One that found the plan did not fit the code comes back with
   nothing changed: plan again from what it saw, or hold the finding where
   the new plan is no longer what was decided.

   A finding annotated `IN MOTION` gets one step before anything else:
   re-read the site as it stands now. Still violating — fix it as any other.
   Gone — concurrent work overtook it: record it in the notes as overtaken,
   with what the site reads now, and move on. Overtaken is a visible outcome,
   never a silent skip.

   Before starting a fix, write it to the notes as the one in hand, and clear
   that line when its commit lands. Between those two writes the run is the
   only thing that should have touched the tree; outside them nothing is
   half-done.

   Read the fix against the rules before committing it, the ones a fix breaks
   most: duplication, placement, naming.

   A fix the run took without asking says so in a trailer —
   `Taken-Under: <rule>` — and differs in nothing else. The closing report
   is built by reading those trailers rather than by remembering. A fix the
   operator decided carries no trailer.

10. Stop on the first failure. If a fix will not verify, halt the run and say
    which finding stopped it and what broke. Continuing would stack the rest
    of the work on a state nobody has checked.

11. Hold a finding again when an answer stops fitting. If an earlier fix
    changed what a later one should be, put it back in the queue with what
    changed rather than acting on a picture that has since moved.

12. Once the taken fixes are in, show the operator, before anything else,
    each Told or Advisor fix taken without asking, laid out as the
    workflow's decisions.md says, with its commit. Silent fixes are not
    shown.

    Then put the held findings to the operator, as many in one message as
    s2-route.md allows, in the order they were raised, read back from the
    notes. Each carries:

        Finding 3 of 7, §R13.52 — <what is wrong> (<the rule, or the entry
        where a convention was broken>)

        <what is wrong and what it costs, in everyday words>

        <path:line>, <path:line>…

          <the offending lines>

        Proposed fix: <one or two sentences>. Fix it?

    The plain block is for a reader who has not read the law: one or two
    sentences, no rule names, no identifiers, no vocabulary from the tools.
    Every block stands apart, with a blank line between it and the next. The
    key from the notes always; the rule and the paths always; where a
    convention was broken, the entry rather than the rule that defers to it.
    The offending lines only where a few of them say it plainly. Quote what
    is there; do not draft what would replace it.

    A held finding too big to fix here is not put as "fix it?": it is
    routed as s2-route.md says.

    Answer each in the notes as it is settled, fixed or declined and why.
    Then do the answered fixes as step 9 describes.

13. Where a fix of this run changed behaviour or security, run one confirming
    reviewer over the fixes alone. What it finds is sorted once more as step
    6 says, and never reviewed again.

14. Close with what happened: fixed, taken without asking, decided by an
    advisor, held, declined, written down, overtaken, and where it stopped if
    it stopped. Group it by the rule or entry that raised each, and name each
    fix's commit. Write the close into the run's notes beside the queue: a
    report only spoken is a report gone by morning.
