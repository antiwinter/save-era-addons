# artisan

A half-automated leveling assistant for WoW Classic Era trade skills. Given a
profession and a target skill level, it computes the cheapest/fastest craft plan
(which recipes to make, in what order, and the reagents to buy), then drives the
player through it one click at a time using the live trade-skill window and bag
state.

Ported from a WeakAura prototype (`../../../../../Users/warits/code/murmur/wa/0trash/professor-draft`).
The WA proved the concept; artisan is the standalone-addon rewrite.

# Related Projects
See root `AGENTS.md` for shared references (wow-ui-source) and design principles.
- WA prototype (source of the algorithm): `~/code/murmur/wa/0trash/professor-draft`
- addon skeleton reference: `../whoaThickCC`

# Architecture
The prototype splits cleanly into three concerns; artisan keeps that split.

1. Data (offline): `fake-wow/scripts/dl.js` scrapes recipe/reagent/price data
   from Wowhead into versioned SQLite dbs (`fake-wow/data/<version>.db`), and
   `scripts/gen-data.lua <version>` boots fake-wow via `fw.init(version)` and
   emits `data/<version>/skills.lua` + `data/<version>/item_prices.lua`
   (checked-in generated artifacts; do not hand-edit) from the GM schema
   queries. The architecture supports all 8 professions dl.js knows; only ENG
   and Tailoring data are fine-tuned for now.
2. Planner (pure Lua): given a profession's recipe table + a target level + a
   wishlist, produce an ordered action list and a shopping list. Zero WoW
   globals — the caller passes `db`.
3. Session + planner state (craft engine in `core.lua`): planner inputs are
persisted per profession in `artisanDB[char].plans[pk]` (`target`, `wishlist`,
`preferExisting`, `noAH`). Actions, materials, and summary values are derived
from that state and the live bag/skill data; they are not a second source of
truth. The live profession skill is the source of progress, so a relog resumes
at the current skill bracket. The data key ("eng") is the only stable
identifier; the localized window name is derived from it via `FindProfName`
(rank-spell ids), never the other way around. The session (a thin per-session
view: derived actions + live skill line) crafts the next batch on demand (one
click per batch — player-initiated `DoTradeSkill`, no auto-fire, to stay clear
of action-blocking taint). Reacts to events (skill-up, bag change, recipe
learned) rather than looping.

## The shared core runs in both worlds
`data.lua`, `planner.lua`, `format.lua`, and `core.lua` are loaded by BOTH the
in-game runtime (via .toc) AND the off-client emulator (via fake-wow's loader).
They call WoW globals directly (`GetTradeSkillLine`, `DoTradeSkill`, ...);
in-game those are real, off-client they're supplied by `fake-wow/`. This is
deliberate and must be preserved:
- No duplication: the algorithm lives in exactly one place.
- Verified out-of-game ⇒ mostly-correct in-game: `tests/` exercises the same
  bytes that ship in the addon, so the Monte Carlo emulator is a real
  regression gate for live behavior.

Rules that keep it dual-use:
- Core files (`data`, `planner`, `format`, `core`) never branch on "am I
  in-game or off-client?" They just call `CreateFrame`, `GetTradeSkillLine`, etc.
- Off-client those globals are supplied by `fake-wow/` (a generic, reusable Lua
  client shell + trade-skill domain).
- The .toc loader in `fake-wow/init.lua` runs each file with the same
  `(addonName, ns)` varargs the client uses, so `local _, ns = ...` works
  identically in both worlds.
- No top-level `dofile`/`require` of data — the generated `skills` /
  `item_prices` globals are set by the .toc load order (both in-game and via
  fake-wow's loader). Names are version-agnostic: a .toc loads exactly one
  version's files, so `data/era/`, `data/tbc/`, ... can't clash.

## fake-wow: the simulated client
`fake-wow/` is a **repo-shared** fake WoW environment, structured so other
addons (BugPanel, Peddler, whoaThickCC) can reuse the generic client shell.
Currently it only implements what artisan needs (~15 APIs), but the
architecture supports growth. See `ARCH.md` for file roles.

The emulator (`tests/emu.lua`) loads fake-wow, boots it via `fw.init("era")`,
loads the addon from its .toc, seeds the world via `GM.SetTradeSkillLine` /
`GM.SetBag`, builds the plan through the same `ns.CreatePlan` command a player
runs, then clicks the panel's craft button in a loop. fake-wow's `DoTradeSkill`
handles craft mechanics (skill-up rolls, recursive sub-reagent crafting, reagent
consumption) and fires `TRADE_SKILL_UPDATE` + `BAG_UPDATE` synchronously, so the
addon's own event frame drives the refresh — same path as live. fake-wow
emulates `GetSpellInfo` for the profession rank-spell ids, so `FindProfName`
resolves the open line exactly as the client would. `tests/resume.lua` guards
the progress promise: partial progress must survive a reload.

# Debugging
- In-game: `/art debug` dumps session + active plan to
  SavedVariables; read `WTF/Account/<ACCOUNT>/SavedVariables/artisan.lua`.
- Off-client: `lua tests/emu.lua <pk> <target> [start]` replays a plan via
  Monte Carlo and reports budget / material use-rate / total crafts.
- Regression gate: `./tests/run.sh` runs the emulator over eng + tailor at a
  fixed seed plus the resume check; fails if any plan comes up SHORT.

# Conventions
- Core files (`data`, `planner`, `format`, `core`) call WoW globals directly
  but never branch on "am I in-game?" If they need client state, read it from
  the WoW API (fake-wow provides stubs off-client).
- Data files (`data/era/*.lua`) are generated. Do not hand-edit; change
  `fake-wow/scripts/dl.js` or `scripts/gen-data.lua` and regenerate.
  Profession rank-spell ids ship in dl.js's `profs` map (`spellIds`), sync to
  the version db by running `node dl.js` (no arg — the professions upsert),
  and reach `data/era/profs.lua` through gen-data like every other table.
- Skill-up color convention throughout: `colors = {orange, yellow, green, gray}`
  thresholds, chances `{[1]=1.0, [2]=0.75, [3]=0.25, [4]=0}`.
