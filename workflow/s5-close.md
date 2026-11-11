---
description: Reviewing and closing a brief, and pausing or ending the session.
---

# Close

## Reviewing a brief
When: the last step of a brief is committed.
Do, in this order:
1. The session asks the operator: "Review before closing? <steps>
   steps, <repositories> repositories, <reviewers> reviewers." The
   reviewers are counted as the review command sizes them.
2. On yes, the session runs the review command over the brief's
   commits, as the brief records them, with the brief's decisions.
Don't:
- No review runs without the operator's yes.

## Reviewing small fixes
When: small fixes committed outside any brief reach five, or the
  session is about to end with any.
Do:
- The session asks the operator: "Review the <count> small fixes?
  <reviewers> reviewers."
- On yes, the session runs the review command over their commits.

## Closing a brief
When: the operator said no to a review, or the review's fixes are
  committed.
Do:
- The session finishes the brief with the organizer's done
  command, and commits what it changed.
- The session tells the operator what the brief built, as short as
  it allows.

## Pausing to compact
When: the kit's size note says the session is worth compacting, at
  any stage, and the session is at a clean point: nothing is
  mid-change and no subagent is running.
Do:
- The session ends its reply with: "Good point to compact:
  everything is written down. Type /compact, then go."
- Where a settled answer is not written yet, the session names it in
  the same reply and asks where it goes.
- The session carries on at the operator's go.
Don't:
- The session doesn't say it again until the note's size is a
  hundred thousand tokens past where it last said it: the note comes
  every turn, and the operator may choose to go on.
- The session doesn't write answers away on its own to make a clean
  point.

## Ending a session
When: a brief is closed, or a draft taken as small work is
  finished.
Do:
- The session tells the operator it can end; after a draft, also
  that the draft is deleted.
Don't:
- The session doesn't start the next brief; the next brief starts
  in a fresh session.
