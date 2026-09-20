# ai-devkit

One tool for agentic development, in four parts: the rules a coding agent
works under, the injector that puts them in front of it every turn, the
reviewer that judges the work against them, and the advisor that gives a
single finding a second, independent reading.

The parts ship, version and mount as one. What the kit needs from a
project is stated here and nowhere else in it.

## What a project keeps, and where

The kit finds a project's own material at fixed places under the project
root, and this is where the operator learns their names.

- `conventions` holds the project's written conventions. One convention
  per file, named for the convention; what an entry holds is the
  follow-conventions rule's to say. An entry may declare, in its
  frontmatter, what an unattended run is allowed to put right without
  asking; silence there means nothing is taken unasked. A README in that
  folder is not an entry. The folder may be absent: a project without a
  collection has nothing to point at.
- `.agentic-review` holds the reviewer's own working notes, read by
  nothing else: worth ignoring from version control, and safe to
  delete.

## Mounting

A project mounts the kit whole. It registers the injector's hook script
for the turn-start event, and exposes the agent and command files the
reviewer and the advisor ship, where Claude Code looks for a project's
agents and commands. Without the hook the reviewer cannot run, and the
advisor cannot say whether a finding matters.

## Develop

```sh
pnpm install
pnpm test
```
