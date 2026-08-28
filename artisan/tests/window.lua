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

assert(ns.pm:Open(pk, true))
ns.pm:settarget(150)
ns.pm:UpdatePlan()
local plan = ns.pm.state
assert(GetTradeSkillLine() == profession, "skill wrapper did not switch professions")
ns.store.cur_pk = nil
ns.pm:UpdatePlan()
fw.click("Artisan_StartCrafting")
assert(ns.store.cur_pk == pk, "start crafting did not select the profession")
assert(artisanPanel:IsShown(), "start crafting did not show the craft panel")
assert(ns.ss, "start crafting did not create a session")
assert(ns.ss.plan == ns.store.snaps[pk], "craft session did not use a snapshot")

for id, count in pairs(plan.materials) do
	fw.GM.SetBag(id, math.ceil(count))
end
fw.GM.SetTradeSkillLine(ns.getProfName(otherPk), 42, 75)
local crafts = fw.world.crafts
fw.click("Artisan_CraftBtn")
assert(GetTradeSkillLine() == profession, "craft wrapper did not switch professions")
assert(fw.world.crafts > crafts, "craft click stopped after switching professions")
assert(Artisan_CraftBtn:IsEnabled(), "craft button stayed disabled after batch")

local snapshot = ns.ss.plan
ns.pm.state.target = 100
ns.pm:UpdatePlan()
assert(ns.ss.plan == snapshot, "craft session was not isolated from planner edits")

print("window wrappers and plan snapshot OK")
