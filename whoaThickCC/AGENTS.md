# whoaThickCC
we're rewriting whoaThickFrames_Classic with minimum features because the original is out of maintenance.

# Related Projects
ref to original project: ../whoaThickFrames_Classic
ref to wow ui source: ~/src/wow-ui-source

# Debugging
read WTF/Account/CLVHUNT_BC/SavedVariables/whoaThickCC.lua for /wufdebug output

# Design Principles
1. Seek the elegant solution before implementing the obvious one.
2. Reduce complexity instead of relocating it.
3. One concept, one implementation, one source of truth.
4. Eliminate special cases through better design.
5. Prefer generic mechanisms over repeated code.
6. Keep related logic together.
7. Every abstraction must simplify the system.
8. APIs should be orthogonal and composable.
9. Optimize hot paths without compromising the design.
10. Comments explain rationale and trade-offs, never restate the code.
11. Delete obsolete code instead of preserving history.
12. Continuously improve the architecture while implementing changes.

# PNG -> BLP conversion
Adding or replacing addon art? Use the `png2blp` skill
(`.claude/skills/png2blp/`) to convert PNG → BLP.
