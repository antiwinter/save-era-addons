# skillMaster Architecture

skillMaster computes the cheapest/fastest trade-skill leveling plan and drives
the player through it one craft at a time. Its defining idea is a **shared core**
that runs unchanged both in-game and off-client. The off-client emulator loads
skillMaster from its .toc through a fake WoW client, so the tests exercise the
exact code that ships.

## One core, two clients

```
       OFFLINE DATA PIPELINE                        SHARED CORE (pure Lua, no WoW globals)
       ┌────────────────────────┐                   ┌──────────────────────────────────────┐
       │ fake-wow/scripts/dl.js   │                   │  data.lua     recipe-table wrapper     │
       │ (Wowhead scraper)      │                   │  planner.lua  BuildPlan(db,opts)       │
       └────────────────────────┘                   │  format.lua   plan → human text        │
                 │                                  │  core.lua     Session + plans + bootstrap │
                 ▼                                  └──────────────────────────────────────┘
       ┌────────────────────────┐                        ▲                        ▲
       │ fake-wow/data/era.db    │                        │ real WoW APIs          │ fake WoW APIs
       │ (SQLite, normalized)    │──db.lua──              │ (CreateFrame,          │ (from fake-wow/,
       └────────────────────────┘   (the reader;         │  GetTradeSkill*, ...)  │  incl. db.lua)
                 │                   init('era')          │                        │
                 ▼                  resolves it)          │                        │
       ┌────────────────────────┐                        │                        │
       │ scripts/gen-data.lua    │                        │                        │
       │ (addon data emitter)    │                        │                        │
       └────────────────────────┘                        │                        │
                 │                                       │                        │
                 ▼                                       │                        │
       ┌────────────────────────┐                        │                        │
       │ data/era/skills.lua     │──loaded by both────────┤                        │
       │ data/era/item_prices.lua│ (via .toc load order)  │                        │
       │ data/era/profs.lua      │                        │                        │
       │ (checked-in, generated) │                        │                        │
       └────────────────────────┘               ┌────────┴─────────┐    ┌─────────┴──────────┐
                                              │   IN-GAME        │    │   EMULATOR         │
                                              │                  │    │                    │
                                              │ ui.lua    panel  │    │ tests/emu.lua      │
                                              │ debug.lua dump   │    │  loads fake-wow,   │
                                              │                  │    │  loads .toc,       │
                                              │ WoW client       │    │  seeds world via   │
                                              │                  │    │  GM.*, clicks      │
                                              │                  │    │  DoAction in loop  │
                                              └──────────────────┘    └────────────────────┘
                                                   WoW client              plain `lua`
```

The core never branches on "am I in-game or off-client?" — it just calls
`CreateFrame`, `GetTradeSkillLine`, `DoTradeSkill`, and reads `ns.db` /
`ns.Planner`. In-game those are real. Off-client they're supplied by fake-wow/
(a generic, reusable Lua client shell + trade-skill domain). That single swap
is what lets `tests/emu.lua` drive the same code the client runs.

## fake-wow: the simulated client

`fake-wow/` is a **repo-shared** fake WoW environment, structured so other
addons (BugPanel, Peddler, whoaThickCC) can reuse the generic client shell.
Currently it only implements what skillMaster needs (~15 APIs), but the
architecture supports growth.

| File | Role |
|------|------|
| `init.lua` | Entry point: installs globals into `_G`, provides a .toc loader that runs an addon exactly as the game would (each file gets `(addonName, ns)` varargs, backslashes are normalized, `ADDON_LOADED` fires after all files load), and exposes `GM.*` for test setup. |
| `client.lua` | Generic client shell: `CreateFrame` + widget stubs, event registration + dispatch, slash commands, dropdown API stubs (`UIDropDownMenu_*`), `UIParent`, and the shared `GM` table (with generic `GM.SetSeed`). The **reusable** part, no trade-skill specifics. |
| `tradeskill.lua` | Trade-skill world state + C-APIs: `GetTradeSkillLine`, `GetNumTradeSkills`, `GetTradeSkillInfo`, `GetTradeSkillNumReagents`, `GetTradeSkillReagentInfo`, `DoTradeSkill`, `GetContainerNumSlots`, `GetContainerItemInfo`, `GetItemInfo`, `GetItemCount`, `GetSpellInfo` (profession rank-spell ids from the db's `professions` table → localized display name, mirroring the client), `GetBuildInfo`, `date`. This is where craft **mechanics** (skill-up rolls, recursive sub-reagent crafting, reagent consumption) live off-client. It also attaches its own GM knobs (`GM.LoadDB`, the schema queries `GM:ListProfessions` / `GM:ListSkills` / `GM:ListProfSpells` / `GM:GetRecipe` / `GM:GetPrice`, `GM.SetTradeSkillLine`, `GM.SetBag`, `GM.ResetProgress`) — setup helpers live with the domain they mutate, not in a catch-all. |
| `db.lua` | The single reader of a shared versioned SQLite db (`fake-wow/data/<version>.db`), vendored `lsqlite3` binding included. Returns normalized `{skills, recipe, items, professions}` — consumed by `GM.LoadDB` and, through the GM schema queries, by `scripts/gen-data.lua`, so db access and table semantics live in one place. |

`DoTradeSkill` in fake-wow fires `TRADE_SKILL_UPDATE` + `BAG_UPDATE`
synchronously, so the addon's own event frame drives the refresh in both worlds.
No manual pumping.

## How events flow

```
   in-game: player clicks craft button ──▶  ui.lua OnClick  ─┐
                                                               ├─▶  Session:DoAction()  ─▶  DoTradeSkill(...)
   emu:     driver loop                  ──▶  ns.Session:DoAction()  ─┘
                                                               │
                                              ┌────────────────┘
                                              ▼
                                    (real | fake) DoTradeSkill
                                              │
                                              ├─▶ TRADE_SKILL_UPDATE event
                                              └─▶ BAG_UPDATE event
                                              │
                                              ▼
                                  Session:OnTradeSkillUpdate()
                                              │  (consumes a deferred
                                              │   /skm plan auto-open)
                                              ▼
                                     ns.OnSessionUpdate() (ui refresh)
```

Crafting stays **one click per batch**: `DoAction` runs only from a player
click (`ui.lua`) or the emu driver, so `DoTradeSkill` is always
player-initiated (avoids action-blocking taint).

## File roles

### Shared core (pure Lua — loaded in-game via .toc, off-client via fake-wow's loader)
| File | Role |
|------|------|
| `data.lua` | Wraps the generated `skills` / `item_prices` globals into per-prof queryable `db` objects (`db[id]`, `db.data`, `db:price`) and derives each recipe's craft cost (memoized, self-reference-safe) from `item_prices` at load. In-game registers `ns.db.eng`/`ns.db.tailor`; off-client does the same via the loader. |
| `planner.lua` | The solver. `BuildPlan(db, opts) → actions, materials`: ROI recipe pick per level, fractional skill-up allocation, recursive reagent expansion, safety buffer. Zero WoW globals, caller passes `db`. |
| `format.lua` | Renders the structured plan into the human `PLAN`/`BAG` review text. `Print(actions, materials, printer)` — `print` off-client, chat frame in-game. |
| `core.lua` | Session + plan lifecycle. Plans live in the SavedVariables (`skillMasterDB.plans[prof] = {prof, target, actions, materials}`) with per-action `crafted` counters as the single source of progress — a relog resumes mid-action, no live-skill re-derivation. `ns.CreatePlan(prof, target)` solves from the *current* skill line (window auto-opens if needed; `TRADE_SKILL_SHOW` defers the build). `Session` holds the active plan + live skill line and crafts through `DoAction`; batch is capped by what the plan still owes AND the skill range, progress measured from the bag (`GetItemCount` delta / craft_count), never assumed from the batch. Event frame built inside the `ADDON_LOADED` handler so every .toc file has loaded first. No .toc reorder needed. |

### In-game host (WoW client only — needs WoW globals)
| File | Role |
|------|------|
| `ui.lua` | Movable panel: a dropdown of stored plans (select activates execution), status line (profession, lvl/target, next action with crafted progress, plan-exhausted hint), a single "Craft next" button (the only crafting path), and the `/skm` slash command (`plan <prof> [target]` builds + prints a plan, `debug`, `hide`). |
| `debug.lua` | `/skm debug` snapshots session + active plan (incl. crafted counters) into SavedVariables for off-disk inspection. |
| `skillMaster.toc` | Addon manifest + load order: `data/era/*.lua → data.lua → planner → format → core → ui → debug`. Core loads last (before ui) so `ns.db`/`ns.Planner` exist when `ADDON_LOADED` builds the runtime. |

### Off-client host (plain `lua`)
| File | Role |
|------|------|
| `tests/emu.lua` | Loads fake-wow, boots it via `fw.init("era")`, loads the addon from its .toc, seeds the world via `GM.SetTradeSkillLine` / `GM.SetBag`, builds the plan through the same `ns.CreatePlan` command a player runs, then clicks `SkillMaster_CraftBtn` in a loop. Prints the plan, then reports reach/budget/waste/use-rate; also asserts the plan never over-counts crafts vs the world. |
| `tests/resume.lua` | Guards the progress promise: crafts partway, reloads the addon (SavedVariables persist), replays the window, asserts the session resumes the SAME action at the SAME `crafted` counter, then still reaches target. |
| `tests/run.sh` | Regression gate: runs the emulator over eng + tailor at a fixed seed plus the resume check; fails if any plan comes up SHORT. Green here ⇒ the shipped engine reaches target. |

### Data pipeline (offline)
| File | Role |
|------|------|
| `fake-wow/scripts/dl.js` | Scrapes Wowhead into `fake-wow/data/era.db` (normalized SQLite: `trade_skill` / `recipe` / `item`). Supports all 8 professions; only eng + tailor are fine-tuned for now. Also owns the `profs` map (rank-spell ids, scroll prefix, display name) and syncs it to the `professions` table when run with no prof argument. |
| `fake-wow/data/<version>.db` | The versioned db — source of truth. Consumed only through `db.lua` (resolved by `fw.init(version)`). |
| `fake-wow/db.lua` | Canonical reader (see the fake-wow table above). |
| `scripts/gen-data.lua` | `lua gen-data.lua <version>` (default `era`): boots fake-wow via `fw.init(version)`, then walks the schema through GM — for every skill `GM:GetRecipe` (inlined into the row) and `GM:GetPrice` for the output, its reagents, and its teach item, plus `GM:ListProfSpells` for the rank-spell ids — and emits `data/<version>/skills.lua` + `data/<version>/item_prices.lua` + `data/<version>/profs.lua`. |
| `fake-wow/scripts/vendor/` | Vendored `lsqlite3` binding (`build.sh`; the `.so` is a gitignored local build). |
| `data/era/skills.lua` | Generated: `skills` (per-prof skill rows as positional arrays, learnedat order, recipe inlined per row). Checked in — do not hand-edit. |
| `data/era/item_prices.lua` | Generated: `item_prices` (item id → avgbuyout for the closure). The single price source — costs derive from it at load, nothing else ships prices. Checked in — do not hand-edit. |
| `data/era/profs.lua` | Generated: `profs` (prof key → rank-spell ids, from the `professions` table). `FindProfName` maps a data key to the localized window name via these. Checked in — do not hand-edit. |

## Load order

**In-game** (.toc order):
1. `data/era/skills.lua`, `data/era/item_prices.lua`, `data/era/profs.lua` — set the `skills` / `item_prices` / `profs` globals (bare names are safe: a .toc loads exactly one version's files)
2. `data.lua` — wraps the `skills` / `item_prices` globals into `ns.db.eng` / `ns.db.tailor`
3. `planner.lua` — attaches `ns.Planner`
4. `format.lua` — attaches `ns.Format`
5. `core.lua` — registers `ADDON_LOADED` handler
6. `ui.lua` — registers `ns.OnSessionUpdate` callback
7. `debug.lua` — registers `ns.Debug`
8. → `ADDON_LOADED` fires → `core.lua` builds `ns.Session` + event frame

**Off-client** (fake-wow loader):
1. `fake-wow/init.lua` installs globals, provides `.toc` parser + loader
2. emu calls `fw.loadAddon("skillMaster.toc")` → fake-wow runs each .toc file with `(addonName, ns)` varargs → fires `ADDON_LOADED`
3. emu seeds world via `GM.*`, runs `CreatePlan`, clicks `SkillMaster_CraftBtn`
