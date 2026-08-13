local addonName, ns = ...

-- debug.lua — /skm debug snapshots planner + runtime state into the
-- SavedVariable so it survives /reload and can be read off-disk at
-- WTF/Account/<ACCOUNT>/SavedVariables/skillMaster.lua.

function ns.Debug()
	local R = ns.Runtime
	local plan = {}
	for i, ac in ipairs(R.plan) do
		plan[i] = string.format("%s x%d [%d->%d]", ac.item, math.ceil(ac.count), ac.from, ac.to)
	end
	local material = {}
	for name, count in pairs(R.material) do
		material[name] = math.ceil(count)
	end
	skillMasterDB.debug = {
		when = date("%Y-%m-%d %H:%M:%S"),
		build = select(4, GetBuildInfo()),
		skill = R.skill,
		prof = R:ProfKey(),
		idx = R.idx,
		plan = plan,
		material = material,
	}
	print("|cff00b4ff[skillMaster]|r debug snapshot saved. /reload then read the SavedVariables file.")
end
