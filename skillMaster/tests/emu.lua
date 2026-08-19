#!/usr/bin/env lua
-- tests/emu.lua — off-client driver for the REAL addon. Instead of a bespoke
-- host, it boots the fake-wow client, loads skillMaster from its .toc exactly as
-- the game would, seeds the simulated world via GM.*, then clicks DoAction in a
-- loop while fake-wow's DoTradeSkill drives the same event path the client uses.
--
-- Usage: ./tests/emu.lua [prof] [target] [start]   (run from the addon root)
--   prof   : eng | tailor    (default eng)
--   target : skill cap to reach (default 300)
--   start  : starting skill level (default 1)
-- The PLAN/BAG review text prints by default; set SKM_NOPLAN=1 to suppress it.

package.path = "./?.lua;" .. package.path

local prof = arg[1] or "eng"
local target = tonumber(arg[2]) or 300
local startLvl = tonumber(arg[3]) or 1
local PROF_NAME = { eng = "Engineering", tailor = "Tailoring" }

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(tonumber(os.getenv("SKM_SEED") or "") or os.time())

-- Load the addon the way the client does: run every .toc file, fire ADDON_LOADED.
-- This also sets the <prof>_data globals and builds ns.db.
local ns = fw.loadAddon("skillMaster.toc")

-- Seed the world: load the recipe catalog (trainer-taught load learned,
-- scroll-taught unlearned — the addon learns those from their teaching item
-- mid-run) and open the skill line at the start level.
local raw = _G[prof .. "_data"]
assert(raw, "no data table for profession: " .. prof)
fw.GM.LoadRecipes(raw)
fw.GM.SetTradeSkillLine(PROF_NAME[prof] or prof, startLvl, target)

-- Boot the engine: trade window opens -> runtime scans -> build the plan.
fw.fire("TRADE_SKILL_SHOW")
local R = ns.Runtime
R:BuildPlan()

if os.getenv("SKM_NOPLAN") ~= "1" then
	ns.Format.Print(R.plan, R.material)
	print()
end

-- Stock the bag with the planned shopping list, tracking budget, then rescan.
local db = ns.db[prof]
local budget = 0
for name, count in pairs(R.material) do
	local c = math.ceil(count)
	fw.GM.SetBag(name, c)
	budget = budget + (db:price(name) or 0) * c
end
fw.fire("BAG_UPDATE")

-- Drive: click "Craft next" until the plan is done or a craft makes no progress.
-- DoTradeSkill inside fake-wow fires TRADE_SKILL_UPDATE + BAG_UPDATE itself, so
-- the runtime refreshes through its own event frame — no manual pumping here.
local world = fw.world
local start_lvl = world.skill.lvl
local guard = 0
while world.skill.lvl < target do
	local before = world.skill.lvl
	local msg = R:DoAction()
	if msg == "Plan complete" then break end
	guard = guard + 1
	if world.skill.lvl == before and guard > 100000 then
		print("STALL: no progress"); break
	end
end

-- Tally leftover materials (waste) vs crafted value.
local remain_val = 0
for k, c in pairs(world.bag) do
	if c > 0 and not db[k] then remain_val = remain_val + (db:price(world.item[k]) or 0) * c end
end

local ok = world.skill.lvl >= target
local use_rate = budget > 0 and math.floor((budget - remain_val) / budget * 100) or 100

print(string.format("prof=%s  %d -> %d/%d  %s", prof, start_lvl, world.skill.lvl, target, ok and "OK" or "SHORT"))
print(string.format("crafts=%d  budget=%.2fg  waste=%.2fg  use_rate=%d%%",
	world.crafts, budget / 10000, remain_val / 10000, use_rate))

os.exit(ok and 0 or 1)
