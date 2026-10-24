# ai-devkit

One tool for agentic development, in seven parts:

- The rules a coding agent works under.
- The injector, which puts the rules in front of the agent every turn.
- The workflow, which says how work moves and who decides what.
- The reviewer, which judges the work against the rules.
- The advisor, which gives a choice a cold second reading.
- The builder, which builds one step of a brief, or a small fix.
- The organizer, which keeps the briefs and drafts.

The kit mounts into Claude Code. The parts ship, version and mount as one. What the kit needs from a
project is stated here and nowhere else in it.

The stand-in is not in use: nothing mounts it, and its tests do not run.

## What a project keeps

The kit's config file, at the project root, says where the kit finds
each of the things below. To start one, copy the config example the kit
ships, which lists every setting with its default. Absent, every default
holds. A file the kit cannot read, or a path set in it that does not
exist, stops every turn until it is fixed.

- The rules: the kit ships a set, and a project may bring its own.
- The conventions: the project's written conventions, one per file, named
  for the convention. What an entry holds is the rules' to say. A README
  there is not an entry. A project may have none.
- The plans: the briefs and drafts the organizer keeps, in one folder
  per level of the kit's, made by hand. Worth keeping in version
  control.
- The review notes: the reviewer's own working notes, read by nothing
  else. Worth ignoring from version control, and safe to delete.
- The organizer's working folder: which briefs sessions are working on,
  on this machine only. Worth ignoring from version control.

## Mounting

A project mounts the kit whole:

- Each part's agent and command files are linked from the kit to where
  the host looks for a project's agents and commands.
- The organizer's skill is linked the same way, to where the host looks
  for a project's skills.
- The injector's hook runs at the turn-start event. Without it the rules
  never reach the agent, and the reviewer cannot run.
- The organizer's hook runs after the host's skill tool. The hook is
  what shows the list of briefs; the skill alone only says that it could
  not.
- The organizer's turn reminder runs at the turn-start event. Without it
  a session holding a brief is not told so each turn.
- The organizer's end hook runs at the session-end event. Without it a
  brief stays taken after its session has ended.
- The builder's size hook runs after every tool. Without it a builder
  that has grown long is never told to stop.
- The workflow's hooks run at the subagent-end event and before the
  host's tool for messaging an agent. Without them a session can send
  more work to an agent that has already reported.

GNU parallel is optional: where the machine has it, the kit's tests run
several at a time; without it, one at a time, to the same result.

## Develop

The kit's package file names its test command. The test
command takes test files or folders to run only those.
