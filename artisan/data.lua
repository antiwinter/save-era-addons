local _, ns = ...

-- Skill row (positions match gen-data's emitter): [1]=id [2]=craft_count
-- [3]=colors [4]=phaseId [5]=scroll_id [6]=recipe {{reagent_id, count}, ...}.
local function Build(pk)
	local db = { data = {} }
	local all = {} -- every skill row id-keyed, incl. color-less (their recipes
	               -- still feed costs and the planner's ordered scan)
	for _, row in ipairs(skills[pk]) do
		local r = {
			skill_id = row[1],
			name = GetItemInfo(row[1]),
			craft_count = row[2],
			colors = row[3],
			phaseId = row[4],
			scroll_id = row[5],
			recipe = {},
		}
		for _, rg in ipairs(row[6] or {}) do
			r.recipe[#r.recipe + 1] = { id = rg[1], count = rg[2] }
		end
		all[r.skill_id] = r
		db.data[#db.data + 1] = r
		-- Only color-bearing rows are craftable and addressable via db[id];
		-- planner probes that to decide buy-vs-craft for a reagent.
		if #r.colors > 0 then db[r.skill_id] = r end
	end
	db.price = function(_, id)
		local market = ns.Market and ns.Market:GetUnitPrice(ns.realm, id)
		return market or item_prices[id]
	end
	function db:refreshCost()
		local memo = {}
		local function cost(sid, visiting)
			if memo[sid] ~= nil then return memo[sid] end
			local r = all[sid]
			if not r then return self:price(sid) end
			visiting = visiting or {}
			if visiting[sid] then return 0 end
			visiting[sid] = true
			local total = 0
			for _, rg in ipairs(r.recipe) do
				local value = all[rg.id] and cost(rg.id, visiting) or self:price(rg.id)
				if value == nil then return math.huge end
				total = total + rg.count * value
			end
			visiting[sid] = nil
			memo[sid] = total
			return total
		end
		for _, r in ipairs(self.data) do
			r.avgbuyout = self:price(r.skill_id) or 0
			r.cost = cost(r.skill_id)
		end
	end
	return db
end

ns.db = ns.db or {}
-- The era files ship in this .toc; register whichever professions they hold.
for pk in pairs(skills) do
	ns.db[pk] = Build(pk)
end
