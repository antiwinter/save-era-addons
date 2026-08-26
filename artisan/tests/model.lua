#!/usr/bin/env lua

package.path = "./?.lua;" .. package.path

local fw = dofile("../fake-wow/init.lua")
fw.init("era")
local ns = fw.loadAddon("artisan.toc")

assert(ns.store.savePlan == nil, "store.savePlan must be removed")
assert(ns.store.state == nil, "store must not create a nested state table")
local direct = { target = 42, wishlist = {}, preferExisting = false, noAH = false }
ns.store.plans.eng = direct
assert(ns.store.plans.eng == direct, "profession plan is not stored in the plans table")
assert(artisanDB.player.plans.eng == direct, "profession plan is not stored directly on SavedVariables")
assert(artisanDB.player.eng == nil, "profession plan leaked outside SavedVariables plans")
assert(artisanDB.player.state == nil, "nested SavedVariables state table was created")

local db = ns.db.eng
local matches = ns.PlannerModel:Search(db, "dummy")
assert(#matches == 3, "dummy search did not find all recipes")
assert(matches[1].name == "Advanced Target Dummy")
assert(matches[2].name == "Masterwork Target Dummy")
assert(matches[3].name == "Target Dummy")

local target = db[4366]
local value, err = ns.PlannerModel:ValidateWishlist(db, 4366, 50, 300)
assert(value == target.colors[1], err)
local rejected = ns.PlannerModel:ValidateWishlist(db, 4366, 50, target.colors[1] - 1)
assert(not rejected, "wishlist accepted a recipe above the cap")

fw.GM.SetTradeSkillLine(ns.getProfName("eng"), 1, 150)
local captured
local buildPlan = ns.Planner.BuildPlan
ns.Planner.BuildPlan = function(_, opts)
	captured = opts
	return {}, {}
end
local state = { target = 100, wishlist = {}, preferExisting = true, noAH = false }
assert(ns.PlannerModel:Build("eng", state))
assert(captured and captured.existing, "existing materials were not passed to planner")
ns.Planner.BuildPlan = buildPlan

local oldGetItemInfo = GetItemInfo
GetItemInfo = function() return "item", nil, nil, nil, nil, nil, nil, nil, nil, nil, 3 end
local summary = ns.PlannerModel:Summary({
	price = function(_, id) return id * 10 end,
	[2] = { craft_count = 1, recipe = {{ id = 1, count = 1 }} },
}, {
	materials = {[1] = 5},
	actions = {{item = 2, count = 2}},
}, {[1] = 3}, true)
GetItemInfo = oldGetItemInfo
assert(summary.existing == 30 and summary.buy == 20)
assert(summary.junk == 6 and summary.ah == 0 and summary.net == 14)

print("planner model OK")
