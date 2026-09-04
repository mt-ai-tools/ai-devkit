# ai-devkit

One tool for agentic development, in three parts: the rules a coding agent
works under, the injector that puts them in front of it every turn, and the
reviewer that judges the work against them.

The parts do not separate. The rules carry frontmatter only the other two
read, the reviewer learns where things are from what the injector prints,
and the kit ships, versions and is mounted as one. What it needs from a
project is stated here and nowhere else in it.

## What a project keeps, and where

The kit finds a project's own material at a fixed place under the project
root, and nothing declares that place anywhere else.

- `conventions` holds the project's written conventions. One convention
  per file, named for the convention, stating what to do — never what
  currently exists where. An entry is written when a convention is
  decided, or when one had to be inferred and was worth keeping. It may
  declare, in its frontmatter, what an unattended run is allowed to put
  right without asking; silence there means nothing is taken unasked. A
  README in that folder is not an entry. The folder may be absent: a
  project without a collection has nothing to point at.

## Mounting

A project mounts the kit whole. It registers the injector's hook script
for the turn-start event, and exposes the reviewer's agent and command
files where Claude Code looks for a project's agents and commands. The
hook is what tells the agent, every turn, where the rules and the
conventions are; the reviewer runs on what that hook has said, so a mount
without the hook has no reviewer either.

## Develop

```sh
pnpm install
pnpm test
```
