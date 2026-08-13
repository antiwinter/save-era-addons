# skillMaster Architecture

skillMaster computes the cheapest/fastest trade-skill leveling plan and drives
the player through it one craft at a time. Its defining idea is a **shared core**
that runs unchanged both in-game and off-client, so the off-client tests exercise
the exact code that ships.

## The two hosts, one core

```
        OFFLINE DATA PIPELINE                      SHARED CORE (pure Lua, no WoW globals)
       ┌───────────────────────┐                 ┌──────────────────────────────────────┐
       │  scripts/dl.js         │                 │  data.lua     recipe-table wrapper     │
       │  (Wowhead scraper)     │──generates──▶   │  planner.lua  BuildPlan(db,opts)       │
       └───────────────────────┘                 │  format.lua   plan → human text        │
                   │                              │  runtime.lua  craft engine (host seam) │
                   ▼                              └──────────────────────────────────────┘
       ┌───────────────────────┐                      ▲                        ▲
       │  data/eng.lua          │                      │ injected `host`        │ injected `host`
       │  data/tailor.lua       │───loaded by both─────┤ + deps                 │ + deps
       │  (generated tables)    │                      │                        │
       └───────────────────────┘             ┌────────┴─────────┐    ┌─────────┴──────────┐
                                              │   IN-GAME HOST   │    │   EMULATOR HOST    │
                                              │                  │    │                    │
                                              │ core.lua  boot   │    │ tests/emu.lua      │
                                              │ ui.lua    panel  │    │  simulated world:  │
                                              │ debug.lua dump   │    │  bag + skill rolls │
                                              │                  │    │ tests/run.sh gate  │
                                              │ wraps real WoW   │    │ drives events +    │
                                              │ APIs + events    │    │ DoAction in a loop │
                                              └──────────────────┘    └────────────────────┘
                                                   WoW client              plain `lua`
```

The core never calls a WoW global and never `dofile`s data — everything
client-specific arrives through an injected `host` (4 methods) and a `deps`
table. That single seam is what lets `tests/emu.lua` drive the same
`runtime.lua` the client runs.

## The host seam

`runtime.lua` reads the world and crafts ONLY through `host`:

```
  host:ReadSkill()    -> name, lvl, cap
  host:ReadRecipes()  -> { [name] = { name, recipe, index } }
  host:ReadBag()      -> { [name] = count }
  host:Craft(index, batch)

  deps = { planner, getDB, getCfg, onUpdate }
```

Events flow the same way on both sides:

```
   in-game: CreateFrame event  ─┐
                                 ├─▶  Runtime:OnTradeSkillUpdate()  ─▶ deps.onUpdate ─▶ UI refresh
   emu:     driver loop        ─┘     Runtime:OnBagUpdate()
                                       Runtime:DoAction()  ─▶ host:Craft ─▶ (real DoTradeSkill | sim rolls)
```

Crafting stays **one click per batch**: `DoAction` runs only from a player
click (`ui.lua`) or the emu driver, so `host:Craft` → `DoTradeSkill` is always
player-initiated (avoids action-blocking taint).

## File roles

### Shared core (pure Lua — loaded in-game via .toc, off-client via dofile)
| File | Role |
|------|------|
| `data.lua` | Wraps a raw recipe array into a queryable `db` (`db[name]`, `db.data`, `db:price`). `NewDB` in-game registers `ns.db.eng`/`ns.db.tailor`; off-client returns the module. |
| `planner.lua` | The solver. `BuildPlan(db, opts) → actions, materials`: ROI recipe pick per level, fractional skill-up allocation, recursive reagent expansion, safety buffer. Zero WoW globals. |
| `format.lua` | Renders the structured plan into the human `PLAN`/`BAG` review text. `Print(actions, materials, printer)` — `print` off-client, chat frame in-game. |
| `runtime.lua` | The craft engine. Pure `Runtime.new(host, deps)`; tracks skill/plan/bag, sizes batches, progresses actions, reacts to events. In-game glue block at the bottom builds the real-API host + event frame (skipped under standalone lua). |

### In-game host (WoW client only — needs WoW globals)
| File | Role |
|------|------|
| `core.lua` | Bootstrap: `ADDON_LOADED`, SavedVariables (`skillMasterDB`), `ns.cfg` defaults. |
| `ui.lua` | Movable panel: shows next action + shopping list, a single "Craft next" button (the only crafting path), and the `/skm` slash command (`plan`, `debug`, `hide`). |
| `debug.lua` | `/skm debug` snapshots planner + runtime state into SavedVariables for off-disk inspection. |
| `skillMaster.toc` | Addon manifest + load order: `core → data/*.lua → data.lua → planner → format → runtime → ui → debug`. |

### Off-client host (plain `lua`)
| File | Role |
|------|------|
| `tests/emu.lua` | Builds a simulated-world host (bag + skill-up rolls) and drives the real `runtime.lua`: fires the events and clicks `DoAction` in a loop. Prints the plan, then reports reach/budget/waste/use-rate. |
| `tests/run.sh` | Regression gate: runs the emulator over eng + tailor at a fixed seed; fails if any plan comes up SHORT. Green here ⇒ the shipped engine reaches target. |

### Data pipeline (offline, Node)
| File | Role |
|------|------|
| `scripts/dl.js` | Scrapes Wowhead for recipe/reagent/price data and emits `data/<prof>.lua`. Supports all 8 professions; only eng + tailor are fine-tuned for now. |
| `scripts/package.json`, `scripts/yarn.lock` | Node deps for the scraper. |
| `data/eng.lua`, `data/tailor.lua` | Generated recipe tables (checked-in artifacts — do not hand-edit). |
