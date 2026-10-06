# ai-devkit

One tool for agentic development, in seven parts: the rules a coding agent
works under, the injector that puts them in front of it every turn, the
reviewer that judges the work against them, the advisor that gives a
single finding a second, independent reading, the builder that carries
out one step of a written brief, the organizer that says which briefs
are ready, waiting or taken, and writes a new one on the operator's yes,
and the stand-in that reads the questions an agent puts to the operator
and sorts them against the operator's own judgement.

The parts ship, version and mount as one. What the kit needs from a
project is stated here and nowhere else in it.

## What a project keeps, and where

The kit finds a project's own material under the project root, each at a
default place the config file can move, and this is where the operator
learns their names.

- `aidk-conventions` holds the project's written conventions. One convention
  per file, named for the convention; what an entry holds is the
  follow-conventions rule's to say. An entry may declare, in its
  frontmatter, what an unattended run is allowed to put right without
  asking; silence there means nothing is taken unasked. A README in that
  folder is not an entry. The folder may be absent: a project without a
  collection has nothing to point at.
- `aidk-config.env` says where the kit finds what it reads, where that is
  not the default: the rules among them, so a project may bring its own in
  place of the set the kit ships. To start one, copy the example at the
  kit's root, which lists every setting with its default. Absent, every
  default holds. A file the kit cannot read, or a path set in it that does
  not exist, stops every turn until it is fixed.
- `aidk-review` holds the reviewer's own working notes, read by
  nothing else: worth ignoring from version control, and safe to
  delete. The config file can move it, as it can the collection.
- `aidk-organizer` is the organizer's working folder: which briefs
  sessions are working on, on this machine only. Worth ignoring from
  version control. The config file can move it.
- `aidk-stand-in` is the stand-in's working folder. Its `answers` holds
  real past cases, worth keeping in version control. Its `on` (which
  sessions the stand-in is switched on for), `sessions` (where the gate
  stands with each) and `log` (every question it let go, with the
  operator's answer) are this machine's alone and worth ignoring; the last
  two may hold raw agent text. The config file can move
  it.

## Mounting

A project mounts the kit whole. It registers the injector's hook script
for the turn-start event, and exposes the agent and command files the
reviewer, the advisor, the builder and the organizer ship, where Claude Code looks for a
project's agents and commands, and the skill the organizer ships, where it
looks for a project's skills. Without the hook the reviewer cannot run,
the advisor cannot say whether a finding matters, and the builder is not
told where the rules it builds under live. Beside the skill, the project
registers the organizer's hook script for the after-tool event of the
Skill tool: the hook is what shows the list, and the skill alone only
says that it could not. For the briefs sessions take, it registers the
organizer's turn reminder for the turn-start event, beside the injector's
hook, and its end hook for the session-end event: without the one a
session holding a brief is not told so each turn, and without the other
a brief stays taken after its session has ended. For the stand-in, it
registers the stand-in's gate for the end-of-reply event, with a time
limit no shorter than the one the gate declares: without the gate no
question is caught, and a gate stopped by its time limit lets a reply
pass unjudged and unsaid. Beside it, the project registers the
stand-in's answer hook for the turn-start event, without which the log
never learns what the operator answered, and exposes the stand-in's two
skills where Claude Code looks for a project's skills, with its skill
hook registered for the after-tool event of the Skill tool: as with the
organizer's, the hook is what shows the settled questions and a
reopened one, and the skills alone only say that they could not. It
exposes the stand-in's entry skill there too, with the stand-in's start
hook registered for the turn-start event and its end hook for the
session-end event: the skill offers the command that switches the
stand-in on, the start hook is what carries it out, and without the end
hook a session's switch outlives it.

## Develop

```sh
pnpm install
pnpm test
```
