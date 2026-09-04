---
enforce: [before-acting, before-finishing]
summary: A function transforms values, reads the world, or changes it — never two at once; a factory constructs and hands back ones that do.
---

# One kind per function

Every function is one kind, and no function is two.

- A transform takes values and returns values. It reaches for nothing: no
  clock, no client, no filesystem, no global.
- A read touches the world and leaves it as it found it.
- A write changes something.
- A factory is the fourth, and the only one: it constructs, and what it hands
  back carries the three. Building may reach outside — a client has to come
  from somewhere — but what comes back must not blur the kinds it exposes.

Each kind is worth telling apart because each can be trusted differently. A
transform is tested by calling it, and no stand-in has to exist. A read is safe
to repeat, to cache, to run out of order. A write is none of those, and only
where it stands alone can the order it runs in, and what a retry does, be
reasoned about at all.

- The tell is a name that needs "and". A function called for what it fetches
  and what it then stores is two functions sharing a body.
- Where the deciding and the reaching are tangled, the deciding comes out. It
  is the half holding the thinking, and the half a test can reach without a
  double.
- Not at any cost. If separating means handing the new function dependencies it
  never needed, the two were not separate, and forcing them apart buys a worse
  read for no test.

Related:
- [compose-dont-merge](compose-dont-merge.md) — the same seam one level up: concerns in their own files, wired by a thin orchestrator.
- [ship-tests](ship-tests.md) — why this is worth the trouble: it decides what a test costs before the test is written.
- [split-at-seams](split-at-seams.md) — a function doing two kinds is a seam, whatever its length.
