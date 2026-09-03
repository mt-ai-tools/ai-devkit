# ai-devkit

Tooling for agentic development: the rules a coding agent works under,
what puts them in front of it, and what judges the work against them.

Each folder here is one tool, standing on its own. What one needs from a
project, it states in its own README.

## What a project keeps, and where

The tools here find a project's own material at fixed places under the
project root, and nothing declares those places anywhere else.

- `tools/ai-devkit` is where this kit is mounted.
- `conventions` holds the project's written conventions. One convention
  per file, named for the convention, stating what to do — never what
  currently exists where. An entry is written when a convention is
  decided, or when one had to be inferred and was worth keeping. It may
  declare, in its frontmatter, what an unattended run is allowed to put
  right without asking; silence there means nothing is taken unasked. A
  README in that folder is not an entry. The folder may be absent: a
  project without a collection has nothing to point at.
