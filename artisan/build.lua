local _, ns = ...

function ns.CreatePlan(pk, target)
	local db = ns.db[pk]
	if not db then return nil, "Invalid key: " .. pk end
	ns.store:set("cur_pk", pk)
	local _, _, lvl, cap = ns.openProfFrame()
	if not lvl then lvl, cap = 1, 150 end
	target = target or cap
	if target <= lvl then return nil, "Target must be > " .. lvl end
	local actions, materials = ns.Planner.BuildPlan(db, { start = lvl, target = target })
	local plan = { pk = pk, target = target, actions = {}, materials = materials }
	for _, action in ipairs(actions) do plan.actions[#plan.actions + 1] = action end
	return plan, string.format("%s: %d -> %d, %d actions", pk, lvl, target, #plan.actions)
end
