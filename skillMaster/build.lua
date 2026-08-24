function ns.CreatePlan(pk, target, retry)
	local db = ns.db[pk]
	if not db then return false, "No data for " .. pk end
	local lvl, cap = ns.skillLvl()
	target = target or cap
	local actions, materials = ns.Planner.BuildPlan(db, { start = lvl, target = target })
	local plan = { pk = pk, target = target, actions = {}, materials = materials }
	for _, ac in ipairs(actions) do
		ac.crafted = 0
		plan.actions[#plan.actions + 1] = ac
	end
	return plan
end
