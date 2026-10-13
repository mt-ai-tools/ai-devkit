---
enforce: [before-acting, before-finishing]
summary: A function transforms values, reads the world, or changes it — never two at once; a factory constructs and hands back ones that do.
---

# One kind per function

- A transform takes values and returns values. It reaches for nothing: no
  clock, no client, no filesystem, no global.
- A read touches the world and leaves it as it found it. A line it logs
  or a figure it reports changes nothing the program reads back, so
  neither makes it a write.
- A write changes something.
- A factory is the fourth kind: it constructs, and what it hands back
  carries the three. Building may reach outside, but what comes back must
  not blur the kinds it exposes.

The kinds are trusted differently. A transform is tested by calling it, with
no stand-in. A read is safe to repeat, to cache, to run out of order. A write
is none of those, and only where it stands alone can its order and its
retries be reasoned about.

- The tell is a name that needs "and".
- Where the deciding and the reaching are tangled, the deciding comes out.
- Not at any cost. If separating means handing the new function dependencies
  it never needed, the two were one.
