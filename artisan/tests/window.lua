#!/usr/bin/env lua

package.path = "./?.lua;" .. package.path

local fw = dofile("../fake-wow/init.lua")
fw.GM.SetSeed(8)
fw.init("era")

local ns = fw.loadAddon("artisan.toc")
local pk, otherPk = "eng", "tailor"
local profession = ns.getProfName(pk)

fw.GM.SetTradeSkillLine(profession, 75, 150)
fw.GM.SetTradeSkillLine(ns.getProfName(otherPk), 42, 75)

local result, message = ns.PlannerModel:Build(pk, { target = 150 })
assert(result, message)
local plan = result.plan
assert(message:find("eng: 75 -> 150", 1, true), message)
assert(GetTradeSkillLine() == profession, "skill wrapper did not switch professions")
ns.store.plans[pk] = { target = plan.target, wishlist = {}, preferExisting = false, noAH = false }
ns.store.cur_pk = nil
ns.PlannerUI:Refresh()
fw.click("Artisan_StartCrafting")
assert(ns.store.cur_pk == pk, "start crafting did not select the profession")
assert(artisanPanel:IsShown(), "start crafting did not show the craft panel")
assert(ns.ss, "start crafting did not create a session")

for id, count in pairs(plan.materials) do
	fw.GM.SetBag(id, math.ceil(count))
end
fw.GM.SetTradeSkillLine(ns.getProfName(otherPk), 42, 75)
local crafts = fw.world.crafts
fw.click("Artisan_CraftBtn")
assert(GetTradeSkillLine() == profession, "craft wrapper did not switch professions")
assert(fw.world.crafts > crafts, "craft click stopped after switching professions")
assert(Artisan_CraftBtn:IsEnabled(), "craft button stayed disabled after batch")

local castSpellByName = CastSpellByName
CastSpellByName = function() end
fw.GM.SetTradeSkillLine(ns.getProfName(otherPk), 42, 75)
local fallbackResult, fallbackMessage = ns.PlannerModel:Build(pk, {})
local fallback = fallbackResult and fallbackResult.plan
CastSpellByName = castSpellByName
assert(fallback, fallbackMessage)
assert(fallback.target == 150, "fallback cap is not 150")
assert(fallbackMessage:find("eng: 1 -> 150", 1, true), fallbackMessage)

print("window wrappers and plan fallback OK")
