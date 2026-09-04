#!/usr/bin/env lua

package.path = "./?.lua;" .. package.path

local fw = dofile("../fake-wow/init.lua")
fw.init("era")
local ns = fw.loadAddon("artisan.toc")

assert(ns.store.savePlan == nil, "store.savePlan must be removed")
assert(ns.PlannerModel == nil, "PlannerModel must stay removed")
assert(ns.store.state == nil, "store must not create a nested state table")
local direct = { target = 42, wishlist = {}, preferExisting = false, noAH = false }
ns.store.plans.eng = direct
assert(ns.store.plans.eng == direct, "profession plan is not stored in the plans table")
assert(artisanDB.player.plans.eng == direct, "profession plan is not stored directly on SavedVariables")
assert(artisanDB.player.eng == nil, "profession plan leaked outside SavedVariables plans")
assert(artisanDB.player.state == nil, "nested SavedVariables state table was created")

local db = ns.db
assert(db.data == nil, "internal data leaked through the DB API")
local eng = db:iterate("eng")
local all = db:iterate("all")
assert(#eng > 0 and #all > #eng, "profession iteration did not select rows")
assert(db[eng[1].skill_id] == eng[1], "item lookup did not resolve through the DB metatable")
local buyout, cost = db[eng[1].skill_id].buyout, db[eng[1].skill_id].cost
assert(buyout and cost, "price did not return buyout and cost")
fw.GM.SetTradeSkillLine(ns.getProfName("eng"), 1, 150)
assert(ns.pm:load("eng"))
local matches = ns.pm:search("dummy")
assert(#matches == 3, "dummy search did not find all recipes")
assert(matches[1].name == "Advanced Target Dummy")
assert(matches[2].name == "Masterwork Target Dummy")
assert(matches[3].name == "Target Dummy")

fw.GM.SetUnitLevel(10)
assert(ns.pm:getclamp(300) == 150, "level cap was not applied")
fw.GM.SetUnitLevel(60)
local captured
local buildPlan = ns.Planner.BuildPlan
ns.Planner.BuildPlan = function(_, opts)
	captured = opts
	return {}, {}
end
ns.pm.state.preferExisting = true
ns.pm:replan()
assert(captured and captured.existing, "existing materials were not passed to planner")
ns.Planner.BuildPlan = buildPlan

print("planner model OK")
