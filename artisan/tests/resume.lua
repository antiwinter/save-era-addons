#!/usr/bin/env lua
-- tests/resume.lua — the next click after a relog resumes from the live skill
-- level and picks the same planned action.

package.path = "./?.lua;" .. package.path

local pk = arg[1] or "eng"
local target = tonumber(arg[2]) or 300
local clicks = tonumber(arg[3]) or 20

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(tonumber(os.getenv("ARTISAN_SEED") or "") or os.time())
fw.init("era")

local ns = fw.loadAddon("artisan.toc")
local profession = ns.getProfName(pk)
fw.GM.SetTradeSkillLine(profession, 1, target)
assert(ns.pm:Open(pk, true))
ns.pm:settarget(target)
ns.pm:Refresh()
ns.store.cur_pk = pk
fw.click("Artisan_StartCrafting")
local plan = ns.store.snaps[pk]
assert(plan, "start crafting did not save a plan snapshot")
ns.CraftUI:Show()

for id, count in pairs(plan.materials) do
	fw.GM.SetBag(id, math.ceil(count))
end
-- Click until the CURRENT action is inside its skill bracket.
local item1
for i = 1, clicks * 10 do
	fw.click("Artisan_CraftBtn")
	item1 = ns.ss:ResovleAction()
	if item1 then break end
	if i == clicks * 10 then error("no mid-craft action after " .. i .. " clicks") end
end

-- Relog and restore the persisted session at the same skill bracket.
local ns2 = fw.loadAddon("artisan.toc")
local item2 = ns2.ss:ResovleAction()
assert(item2 and item2 == item1,
	"resume mismatch: before " .. (item1 or "?")
	.. " after " .. (item2 or "?"))

local guard = 0
while fw.world.skill.lvl < target do
	local before = fw.world.skill.lvl
	fw.click("Artisan_CraftBtn")
	guard = guard + 1
	if fw.world.skill.lvl == before then
		if guard > 500000 then error("STALL: no progress") end
	else
		guard = 0
	end
end

print(string.format("resume %s: resumed action %d, finished %d/%d OK",
	pk, item2, fw.world.skill.lvl, target))
os.exit(0)
