local _, ns = ...

-- Skill row (positions match gen-data's emitter): [1]=id [2]=craft_count
-- [3]=colors [4]=phaseId [5]=teach_id [6]=recipe {{reagent_id, count}, ...}.
local function Build(prof)
	local db = { data = {} }
	local all = {} -- every skill row id-keyed, incl. color-less (their recipes
	               -- still feed costs and the planner's ordered scan)
	for _, row in ipairs(skills[prof]) do
		local r = {
			skill_id = row[1],
			craft_count = row[2],
			colors = row[3],
			phaseId = row[4],
			teach_id = row[5],
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
	db.price = function(_, id) return item_prices[id] end

	local memo = {}
	local function cost(sid)
		if memo[sid] then return memo[sid] end
		local r = all[sid]
		if not r then return 0 end
		memo[sid] = -1
		local total = 0
		for _, rg in ipairs(r.recipe) do
			local sub = all[rg.id]
			total = total + rg.count * (sub and cost(rg.id) or (item_prices[rg.id] or 0))
		end
		memo[sid] = total
		return total
	end
	for _, r in ipairs(db.data) do
		r.avgbuyout = item_prices[r.skill_id] or 0
		r.cost = cost(r.skill_id)
	end
	return db
end

ns.db = ns.db or {}
-- The era files ship in this .toc; register whichever professions they hold.
for prof in pairs(skills) do
	ns.db[prof] = Build(prof)
end