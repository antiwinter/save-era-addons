local _, ns = ...

local pm = {
	pk = nil,
	active = false,
	frame = CreateFrame("Frame", "artisanpm", UIParent, "BackdropTemplate")
}

function pm:load(pk)
	local prof = ns.getProfName(pk)
	if not prof then return end

	self.pk = pk
	local lo, hi = self:getclamp()
	self.state = ns.store.plans[self.pk] or {
		start = lo,
		target = hi,
		wishlist = {},
		preferExisting = true,
		noAH = false,
		actions = {},
		materials = {}
	}
	self.state.wishlist = self.state.wishlist or {}
	self.state.actions = self.state.actions or {}
	self.state.materials = self.state.materials or {}
	self.state.start = self.state.start or lo
	self.state.target = self:getclamp(self.state.target or hi)
	ns.store.plans[self.pk] = self.state
	self.replan_req = 1
	return true
end

function pm:getclamp(target)
	local _, _, cur = ns.openProfFrame(self.pk)
	local lvl = UnitLevel('player')
	local hardcap = lvl > 34 and 300 or
		lvl > 19 and 225 or
		lvl > 9 and 150 or
		lvl > 4 and 75 or 1
	if target then
		return math.max(cur, math.min(hardcap, math.floor(target + 0.5)))
	else
		return cur or 1, hardcap
	end
end

function pm:settarget(target)
	local tar = self:getclamp(target)
	if tar ~= self.state.target then
		self.state.target = tar
		self.replan_req = 1
	end
end

function pm:replan()
	local st = self.state
	local start = self:getclamp()
	st.start = start
	local actions, materials = ns.Planner.BuildPlan(self:getdb(), {
		start = start,
		target= st.target,
		wishlist = st.wishlist or {},
		existing = st.preferExisting and ns.getExistingMaterials() or {}
	})
	st.actions = actions
	st.materials = materials
	self:resum()
end

function pm:getdb()
	return ns.db[self.pk]
end

function pm:search(query)
	query = (query or ""):lower()
	local db = self:getdb()
	if not db then return {} end
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

function pm:resum()
	local st, db = self.state, self:getdb()
	local plan, existing = st, ns.getExistingMaterials()
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

	local ahReturns, junkReturns, aaj = 0, 0, 0
	for id, count in pairs(crafted) do
		local buyout = db:price(id) or 0
		local vendor = select(11, GetItemInfo(id)) or 0
		if buyout < vendor then
			junkReturns = junkReturns + count * vendor
		else
			aaj = aaj + count * vendor
			ahReturns = ahReturns + count * buyout
		end
	end
	self.sum = {
		existing = existingValue,
		buy = buyValue,
		junk = junkReturns,
		ah = ahReturns,
		aaj = aaj
	}
end

function pm:snapshot()
	ns.store.snaps[self.pk] = ns.copyObj(self.state)
end

ns.pm = pm
