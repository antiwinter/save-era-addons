local _, ns = ...

function ns.CreatePlan(pk, target, opts)
	local db = ns.db[pk]
	if not db then return nil, "Invalid key: " .. pk end
	opts = opts or {}
	local _, _, lvl, cap = ns.openProfFrame(pk)
	if not lvl then lvl, cap = 1, 150 end
	target = target or cap
	if target <= lvl then return nil, "Target must be > " .. lvl end
	local actions, materials = ns.Planner.BuildPlan(db, {
		start = lvl,
		target = target,
		wishlist = opts.wishlist,
		existing = opts.existing,
	})
	local plan = { pk = pk, target = target, actions = {}, materials = materials }
	for _, action in ipairs(actions) do plan.actions[#plan.actions + 1] = action end
	return plan, string.format("%s: %d -> %d, %d actions", pk, lvl, target, #plan.actions)
end

local Model = {}

function Model:Search(db, query)
	query = (query or ""):lower()
	local result = {}
	for _, recipe in ipairs(db.data) do
		if recipe.name and db[recipe.skill_id]
			and recipe.name:lower():find(query, 1, true) then
			result[#result + 1] = recipe
		end
	end
	table.sort(result, function(a, b) return a.name < b.name end)
	return result
end

function Model:ValidateWishlist(db, itemId, target, cap)
	local recipe = db[itemId]
	if not recipe then return nil, "Unknown recipe" end
	local required = recipe.colors[1]
	if required > cap then return nil, "Requires skill " .. required end
	return math.max(target, required)
end

function Model:Build(pk, state)
	local skill, cap = ns.getTradeSkillRange(pk)
	local target = math.max(skill, math.min(cap, state.target or cap))
	state.target = target
	local existing = ns.getExistingMaterials()
	local plan, message = ns.CreatePlan(pk, target, {
		wishlist = state.wishlist,
		existing = state.preferExisting and existing or nil,
	})
	if not plan then return nil, message end
	return {
		skill = skill,
		cap = cap,
		target = target,
		plan = plan,
		existing = existing,
		summary = self:Summary(ns.db[pk], plan, existing, state.noAH),
	}
end

function Model:Summary(db, plan, existing, noAH)
	local existingValue, buyValue = 0, 0
	for id, required in pairs(plan.materials) do
		local have = existing[id] or 0
		local price = db:price(id) or 0
		existingValue = existingValue + math.min(have, required) * price
		buyValue = buyValue + math.max(0, required - have) * price
	end

	local crafted = {}
	for _, action in ipairs(plan.actions) do
		local recipe = db[action.item]
		crafted[action.item] = (crafted[action.item] or 0)
			+ math.ceil(action.count) * (recipe.craft_count or 1)
	end
	for _, action in ipairs(plan.actions) do
		local recipe = db[action.item]
		for _, reagent in ipairs(recipe.recipe) do
			if crafted[reagent.id] then
				crafted[reagent.id] = math.max(0,
					crafted[reagent.id] - math.ceil(action.count) * reagent.count)
			end
		end
	end

	local ahReturns, junkReturns = 0, 0
	for id, count in pairs(crafted) do
		local buyout = db:price(id) or 0
		local vendor = select(11, GetItemInfo(id)) or 0
		if noAH then
			junkReturns = junkReturns + count * vendor
		else
			ahReturns = ahReturns + count * buyout
		end
	end
	return {
		existing = existingValue,
		buy = buyValue,
		junk = junkReturns,
		ah = ahReturns,
		net = buyValue - junkReturns - ahReturns,
	}
end

ns.PlannerModel = Model
