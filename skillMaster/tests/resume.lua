#!/usr/bin/env lua
-- tests/resume.lua — progress survives a relog. Crafts partway through a plan,
-- loads the addon again (SavedVariables persist, window replays), and asserts
-- the session resumes the SAME action at the SAME crafted counter, then still
-- reaches target. This guards the design's core promise: `crafted` is the
-- single source of progress, so a plan outlives any session.

package.path = "./?.lua;" .. package.path

local prof = arg[1] or "eng"
local target = tonumber(arg[2]) or 300
local clicks = tonumber(arg[3]) or 20

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(tonumber(os.getenv("SKM_SEED") or "") or os.time())

local ns = fw.loadAddon("skillMaster.toc")
fw.init("era")
fw.GM.SetTradeSkillLine(ns.FindProfName(prof), 1, target)
assert(ns.CreatePlan(prof, target))

local name = ns.FindProfName(prof)
for id, count in pairs(ns.plans[prof].materials) do
	fw.GM.SetBag(id, math.ceil(count))
end
-- Click until the CURRENT action is mid-craft: the plan leaves actions
-- untouched until their bracket comes up, so a fixed click count can land on
-- one that has done nothing yet.
local ac1
for i = 1, clicks * 10 do
	fw.click("SkillMaster_CraftBtn")
	ac1 = ns.Session:CurrentAction()
	if ac1 and ac1.crafted > 0 and ac1.crafted < ac1.count then break end
	if i == clicks * 10 then error("no mid-craft action after " .. i .. " clicks") end
end

-- Relog: fresh addon load (SavedVariables persist), window replays on open.
local ns2 = fw.loadAddon("skillMaster.toc")
fw.GM.SetTradeSkillLine(ns2.FindProfName(prof), fw.world.skill.lvl, target)
ns2.Session:Select(prof)
local ac2 = ns2.Session:CurrentAction()
assert(ac2 and ac2.item == ac1.item and ac2.crafted == ac1.crafted,
	"resume mismatch: before " .. (ac1 and ac1.item or "?") .. "/" .. (ac1 and ac1.crafted or "?")
	.. " after " .. (ac2 and ac2.item or "?") .. "/" .. (ac2 and ac2.crafted or "?"))

local guard = 0
while fw.world.skill.lvl < target do
	local before = fw.world.skill.lvl
	fw.click("SkillMaster_CraftBtn")
	guard = guard + 1
	if fw.world.skill.lvl == before then
		if guard > 500000 then error("STALL: no progress") end
	else
		guard = 0
	end
end

print(string.format("resume %s: resumed action %d at %d/%d, finished %d/%d OK",
	prof, ac2.item, ac2.crafted, math.ceil(ac2.count), fw.world.skill.lvl, target))
os.exit(0)