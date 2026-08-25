#!/usr/bin/env lua
-- tests/emu.lua — off-client driver for the REAL addon. Instead of a bespoke
-- host, it boots the fake-wow client, loads skillMaster from its .toc exactly as
-- the game would, seeds the simulated world via GM.*, then clicks DoAction in a
-- loop while fake-wow's DoTradeSkill drives the same event path the client uses.
--
-- Usage: ./tests/emu.lua [pk] [target] [start]   (run from the addon root)
--   pk     : eng | tailor    (default eng)
--   target : skill cap to reach (default 300)
--   start  : starting skill level (default 1)
-- The PLAN/BAG review text prints by default; set SKM_NOPLAN=1 to suppress it.

package.path = "./?.lua;" .. package.path

local pk = arg[1] or "eng"
local target = tonumber(arg[2]) or 300
local startLvl = tonumber(arg[3]) or 1

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(tonumber(os.getenv("SKM_SEED") or "") or os.time())
fw.init("era")

-- Load the addon the way the client does: run every .toc file, fire ADDON_LOADED.
-- This also loads generated profession data and builds ns.db.
local ns = fw.loadAddon("skillMaster.toc")

-- Seed the requested profession at the requested starting level.
local profession = ns.FindProfName(pk)
fw.GM.SetTradeSkillLine(profession, startLvl, target)

-- Build and persist/select it as the slash command does.
local plan, msg = ns.CreatePlan(pk, target)
assert(plan, msg)
ns.store:savePlan(plan)

if os.getenv("SKM_NOPLAN") ~= "1" then
	ns.Format.PrintPlan(plan)
	print()
end

-- Stock the bag with the planned shopping list, tracking budget, then rescan.
-- SetBag fires BAG_UPDATE itself, so no manual pump is needed.
local db = ns.db[pk]
local budget = 0
for id, count in pairs(plan.materials) do
	local c = math.ceil(count)
	fw.GM.SetBag(id, c)
	budget = budget + (db:price(id) or 0) * c
end
local world = fw.world
local start_lvl = world.skill.lvl
local guard = 0
while world.skill.lvl < target do
	local before = world.skill.lvl
	fw.click("SkillMaster_CraftBtn")
	guard = guard + 1
	if world.skill.lvl == before then
		if guard > 100000 then print("STALL: no progress"); break end
	else
		guard = 0
	end
end

-- Tally leftover materials (waste) vs crafted value.
local remain_val = 0
for k, c in pairs(world.bag) do
	if c > 0 and not db[k] then remain_val = remain_val + (db:price(k) or 0) * c end
end

local rc = world.skill.lvl >= target
local use_rate = budget > 0 and math.floor((budget - remain_val) / budget * 100) or 100

print(string.format("pk=%s  %d -> %d/%d  %s", pk, start_lvl, world.skill.lvl, target, rc and "OK" or "SHORT"))
print(string.format("crafts=%d  budget=%.2fg  waste=%.2fg  use_rate=%d%%",
	world.crafts, budget / 10000, remain_val / 10000, use_rate))

os.exit(rc and 0 or 1)
