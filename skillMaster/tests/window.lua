#!/usr/bin/env lua

package.path = "./?.lua;" .. package.path

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(8)
fw.init("era")

local ns = fw.loadAddon("skillMaster.toc")
local pk, otherPk = "eng", "tailor"
local profession = ns.FindProfName(pk)

fw.GM.SetTradeSkillLine(profession, 75, 150)
fw.GM.SetTradeSkillLine(ns.FindProfName(otherPk), 42, 75)

local plan, message = ns.CreatePlan(pk, 150)
assert(plan, message)
assert(message:find("eng: 75 -> 150", 1, true), message)
assert(GetTradeSkillLine() == profession, "skill wrapper did not switch professions")
ns.store:savePlan(plan)

for id, count in pairs(plan.materials) do
	fw.GM.SetBag(id, math.ceil(count))
end
fw.GM.SetTradeSkillLine(ns.FindProfName(otherPk), 42, 75)
local crafts = fw.world.crafts
fw.click("SkillMaster_CraftBtn")
assert(GetTradeSkillLine() == profession, "craft wrapper did not switch professions")
assert(fw.world.crafts > crafts, "craft click stopped after switching professions")
assert(SkillMaster_CraftBtn:IsEnabled(), "craft button stayed disabled after batch")

local castSpellByName = CastSpellByName
CastSpellByName = function() end
fw.GM.SetTradeSkillLine(ns.FindProfName(otherPk), 42, 75)
local fallback, fallbackMessage = ns.CreatePlan(pk)
CastSpellByName = castSpellByName
assert(fallback, fallbackMessage)
assert(fallback.target == 150, "fallback cap is not 150")
assert(fallbackMessage:find("eng: 1 -> 150", 1, true), fallbackMessage)

print("window wrappers and plan fallback OK")
