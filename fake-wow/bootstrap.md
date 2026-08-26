# fake-wow bootstrap

A **repo-shared** fake WoW client for running addons under a plain `lua`
interpreter. Structured so artisan, BugPanel, Peddler, and whoaThickCC can
all reuse the generic client shell (`client.lua`). Domain-specific APIs (e.g.,
trade-skill) are in separate modules so other addons don't inherit unrelated
globals.

## Current API surface (artisan-driven)

### Generic client (client.lua)
- `CreateFrame(type, name, parent, template)` — widget + event stubs
- `UIParent`
- `SlashCmdList` / `SLASH_*` registry
- `GetBuildInfo()` → `"1.15.7", "60000", nil, 11507`
- `date(fmt)`, `print`

Widget methods: `SetSize`, `SetPoint`, `SetMovable`, `EnableMouse`,
`RegisterForDrag`, `Show`, `Hide`, `IsShown`, `CreateFontString`, `SetText`,
`RegisterEvent`, `UnregisterEvent`, `SetScript`, `GetScript`, `Click` (test helper)

### Trade-skill domain (tradeskill.lua)
- `GetTradeSkillLine()` → `name, nil, rank, maxRank`
- `GetNumTradeSkills()` → count
- `GetTradeSkillInfo(i)` → `name, kind` for trainer-taught or learned scroll recipes
- `GetTradeSkillNumReagents(i)` → count
- `GetTradeSkillReagentInfo(i, j)` → `name, nil, count`
- `DoTradeSkill(index, batch)` — fires `TRADE_SKILL_UPDATE` + `BAG_UPDATE`
- `GetContainerNumSlots(bag)` → count (only bag 0 is populated; bag is id-keyed)
- `GetContainerItemInfo(bag, slot)` → `nil, count, nil, nil, nil, nil, link`
- `GetContainerItemID(bag, slot)` → item id
- `GetItemInfo(id)` → item name
- `UseContainerItem(bag, slot)` — a teaching item adds its recipe to `world.learned`, is consumed, and fires trade-skill/bag updates

### Database reader (db.lua)
- `db.lua` — the single reader of a shared versioned SQLite db
  (vendored `lsqlite3` binding, `scripts/vendor/build.sh`). `load(dbPath)`
  returns a SQLite-backed query object; the caller chooses the version filename.

### GM console — test setup, NOT a WoW API
The shared `GM` table is created by `client.lua`; each domain module attaches
its own knobs (setup helpers live with the domain they mutate).
- `GM.SetSeed(n)` — generic (client.lua)
- `GM.SetTradeSkillLine(name, lvl, cap)` — set profession state and open its DB-backed window (tradeskill.lua)
- `GM.LoadDB(dbPath)` — open the database and reset scroll-learned state (tradeskill.lua)
- `GM:ListProfessions()` → `{"eng", "tailor", ...}` — tradeskill.lua
- `GM:ListSkills('eng')` → skills of one `pk`, learnedat order (id, name, craft_count, colors, phaseId, scroll_id) — tradeskill.lua
- `GM:GetRecipe(skill_id)` → `{{id, count}, ...}` — tradeskill.lua
- `GM:GetPrice(item_id)` → avgbuyout (0 if absent) — tradeskill.lua
- `GM.SetBag(id, count)` or `GM.SetBag({[id]=count, ...})` — stock the id-keyed bag (tradeskill.lua)
- `GM.ResetProgress()` — tradeskill.lua

### Loader (init.lua)
- `init(version)` — boot a game version: `GM.LoadDB(dir .. "data/<version>.db")`; drivers and gen-data never touch db.lua or db paths directly
- `loadAddon(tocPath)` → `ns` — parse .toc, run each file with `(addonName, ns)`, fire `ADDON_LOADED`
- `fire(event, ...)` — dispatch an event to all registered frames
- `slash(line)` — dispatch a slash command (e.g., `"/art plan"`)
- `world` — the mutable sim state (skill, bag, scroll-learned recipes, crafts)
- `env` — the global table (`_G`)

## Growth path
When other addons need new APIs, add them to `client.lua` (generic) or new
domain modules (quest, combat, auction, etc.). Each domain module owns both its
C-APIs and its `GM.*` setup knobs — the loader and the generic `GM` table stay
in the shell.

## Usage (from a test driver)
```lua
local fw = dofile("fake-wow/init.lua")
fw.init("era")                       -- load fake-wow/data/era.db
fw.GM.SetSeed(1)
local ns = fw.loadAddon("artisan/artisan.toc")
fw.GM.SetTradeSkillLine("engineering", 1, 300)
fw.slash("/art plan eng 300")
fw.click("Artisan_CraftBtn")
```
