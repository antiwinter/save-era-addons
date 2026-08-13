# skillMaster

A half-automated leveling assistant for WoW Classic Era trade skills. Given a
profession and a target skill level, it computes the cheapest/fastest craft plan
(which recipes to make, in what order, and the reagents to buy), then drives the
player through it one click at a time using the live trade-skill window and bag
state.

Ported from a WeakAura prototype (`../../../../../Users/warits/code/murmur/wa/0trash/professor-draft`).
The WA proved the concept; skillMaster is the standalone-addon rewrite.

# Related Projects
- WA prototype (source of the algorithm): `~/code/murmur/wa/0trash/professor-draft`
- addon skeleton reference: `../whoaThickCC`
- wow ui source: `~/src/wow-ui-source`

# Architecture
The prototype splits cleanly into three concerns; skillMaster keeps that split.

1. Data (offline): a Node scraper pulls recipe/reagent/price data from Wowhead
   and emits per-profession Lua tables (`data/<prof>.lua`). Checked in as
   generated artifacts; regenerated with the pipeline in `scripts/`. The
   architecture supports all 8 professions dl.js knows; only ENG and Tailoring
   data are fine-tuned for now.
2. Planner (pure Lua, ONE file used both in and out of game): given a
   profession's recipe table + a target level + a wishlist, produce an ordered
   action list and a shopping list.
3. Runtime (craft engine, dual-use via a host seam): tracks progress against
   the plan and crafts the next batch on demand (one click per batch —
   player-initiated `DoTradeSkill`, no auto-fire, to stay clear of
   action-blocking taint). Reacts to events (skill-up, bag change, recipe
   learned) rather than looping.

## The planner is a single dual-use file (load-bearing constraint)
`planner.lua` is consumed unchanged by BOTH the in-game runtime AND the
off-client test harness. This is deliberate and must be preserved:
- No duplication: the algorithm lives in exactly one place.
- Verified out-of-game ⇒ mostly-correct in-game: `tests/` exercises the same
  bytes that ship in the addon, so the Monte Carlo emulator is a real
  regression gate for live behavior.

Rules that keep it dual-use:
- Zero WoW globals in `planner.lua` (`CreateFrame`, `GetTradeSkill*`, `wipe`,
  `WeakAuras`, …). Anything client-specific is passed in as an argument.
- No top-level `dofile`/`require` of data — the caller supplies `db`.
- Export both ways: read the `local _, ns = ...` vararg (nil under standalone
  `lua`) and, when absent, `return` the module table. In-game it attaches to
  `ns.Planner`; off-client `tests/emu.lua` grabs the returned table.
- `data.lua` follows the same dual-loader pattern for recipe tables (in-game:
  loaded via the .toc; off-client: `dofile`d by the test).

## The runtime is dual-use too, via a host seam
`runtime.lua` is the event-driven craft engine and — like the planner — runs
unchanged in-game and under the emulator. It never touches a WoW global
directly; it reads the world and crafts through an injected `host`, and reacts
to `OnTradeSkillUpdate` / `OnBagUpdate` entrypoints.

- `host` is a 4-method interface: `ReadSkill()`, `ReadRecipes()`, `ReadBag()`,
  `Craft(index, batch)`. In-game the host wraps the real
  `GetTradeSkill*`/`GetContainer*`/`DoTradeSkill` APIs; in emu it is a
  simulated world (the ONLY place off-client craft mechanics — skill-up rolls,
  reagent consumption — live).
- `Runtime.new(host, deps)` is pure; `deps` supplies `planner`, `getDB`,
  `getCfg`, `onUpdate`. The in-game glue at the bottom of the file is guarded by
  `if ns and CreateFrame`, so `dofile('runtime.lua')` stays clean off-client.
- Why: the emulator drives the SAME engine the client runs — `DoAction`, batch
  sizing, and plan progression are all under test, not re-implemented. Bugs in
  ordering/advancement surface off-client instead of only in-game.

# Debugging
- In-game: `/skm debug` dumps planner + runtime state to SavedVariables; read
  `WTF/Account/<ACCOUNT>/SavedVariables/skillMaster.lua`.
- Off-client: `lua tests/emu.lua < fixture` replays a plan via Monte Carlo and
  reports budget / material use-rate / total crafts.

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

# Conventions
- The planner must not reference any WoW global (`CreateFrame`, `GetTradeSkill*`,
  etc.). If it needs client data, take it as a function argument so tests can
  supply a fixture.
- Recipe data files (`data/*.lua`) are generated. Do not hand-edit; change the
  scraper in `scripts/` and regenerate.
- Skill-up color convention throughout: `colors = {orange, yellow, green, gray}`
  thresholds, chances `{[1]=1.0, [2]=0.75, [3]=0.25, [4]=0}`.
