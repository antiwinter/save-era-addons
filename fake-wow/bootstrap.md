# fake-wow bootstrap

A **repo-shared** fake WoW client for running addons under a plain `lua`
interpreter. Structured so skillMaster, BugPanel, Peddler, and whoaThickCC can
all reuse the generic client shell (`client.lua`). Domain-specific APIs (e.g.,
trade-skill) are in separate modules so other addons don't inherit unrelated
globals.

## Current API surface (skillMaster-driven)

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
- `GetTradeSkillInfo(i)` → `name, kind`
- `GetTradeSkillNumReagents(i)` → count
- `GetTradeSkillReagentInfo(i, j)` → `name, nil, count`
- `DoTradeSkill(index, batch)` — fires `TRADE_SKILL_UPDATE` + `BAG_UPDATE`
- `GetContainerNumSlots(bag)` → count (only bag 0 is populated)
- `GetContainerItemInfo(bag, slot)` → `nil, count, nil, nil, nil, nil, link`
- `GetItemInfo(link)` → `link` (link == name in the sim)

### GM console — test setup, NOT a WoW API
The shared `GM` table is created by `client.lua`; each domain module attaches
its own knobs (setup helpers live with the domain they mutate).
- `GM.SetSeed(n)` — generic (client.lua)
- `GM.SetTradeSkillLine(name, lvl, cap)` — tradeskill.lua
- `GM.LoadRecipes(raw)` — load a `<prof>_data` array into the book (tradeskill.lua)
- `GM.SetBag(name, count)` or `GM.SetBag({[name]=count, ...})` — tradeskill.lua
- `GM.ResetProgress()` — tradeskill.lua

### Loader (init.lua)
- `loadAddon(tocPath)` → `ns` — parse .toc, run each file with `(addonName, ns)`, fire `ADDON_LOADED`
- `fire(event, ...)` — dispatch an event to all registered frames
- `slash(line)` — dispatch a slash command (e.g., `"/skm plan"`)
- `world` — the mutable sim state (skill, bag, book, crafts)
- `env` — the global table (`_G`)

## Growth path
When other addons need new APIs, add them to `client.lua` (generic) or new
domain modules (quest, combat, auction, etc.). Each domain module owns both its
C-APIs and its `GM.*` setup knobs — the loader and the generic `GM` table stay
in the shell.

## Usage (from a test driver)
```lua
local fw = dofile("fake-wow/init.lua")
fw.GM.SetSeed(1)
fw.GM.SetTradeSkillLine("Engineering", 1, 300)
fw.GM.LoadRecipes(eng_data)
local ns = fw.loadAddon("skillMaster/skillMaster.toc")
fw.fire("TRADE_SKILL_SHOW")
ns.Runtime:DoAction()
```
