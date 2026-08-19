# save-era-addons

A collection of WoW Classic Era addons, each in its own subdirectory:
- `Peddler` — auto-sell unwanted items at vendors.
- `skillMaster` — half-automated trade-skill leveling assistant.
- `whoaThickCC` — minimal rewrite of whoaThickFrames_Classic.
- `BugPanel` — current-session Lua error viewer (reads !BugGrabber's DB).

Each subproject has its own `AGENTS.md` with project-specific details. This
file holds the conventions common to all of them.

# Related Projects
- wow ui source: `~/src/wow-ui-source`
- $GAME_DIR: `/Applications/World of Warcraft/_classic_era_`

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

# About comments in code
don't write verbose comments!
don't write verbose comments!
don't write verbose comments!
don't write verbose comments!
only explain unormal 'why', when really necessary, readers are not ideats, when really necessary, when really necessary, not 'what' or 'how'.

# Skills
- `png2blp` (`.claude/skills/png2blp/`) — convert PNG → BLP for addon art.
  Run from the repo root: `python3 .claude/skills/png2blp/png2blp.py <src.png> <dst.blp>`.
