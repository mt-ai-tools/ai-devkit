---
enforce: [before-thinking, before-finishing]
summary: When a shared abstraction almost fits, extend it or wrap it; never fork or copy it.
---

# Extend or wrap, don't duplicate

- Before writing something new, check whether a shared version already exists.
- Never copy an implementation to tweak one detail: duplicates diverge and multiply maintenance.
- Where the addition is not the original's concern, wrap it: a new unit that calls the original and adds around it, copying none of it.
- The original may be bent to take its wrapper, cleanly. The bend is made for the wrapper but shaped so anything else could use it the same way: an option, a pass-through, a hook. It never names the wrapper, and never fits only it.
- Changing what the original does for everyone is extending it, done in the original.
