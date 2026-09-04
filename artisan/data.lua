local _, ns = ...

local data, pks = {}, {}
local db = {}

function db:iterate(pk)
	assert(pk == "all" or pks[pk], "invalid profession: " .. tostring(pk))
	local rows = {}
	for _, row in pairs(data) do
		if row.pk and (pk == "all" or row.pk == pk) then rows[#rows + 1] = row end
	end
	return rows
end

function db:init()
	for pk, rows in pairs(skills) do
		pks[pk] = true
		for _, row in ipairs(rows) do
			local recipe = {}
			for _, reagent in ipairs(row[6] or {}) do
				recipe[#recipe + 1] = { id = reagent[1], count = reagent[2] }
			end
			assert(not data[row[1]], "duplicate skill item: " .. row[1])
			data[row[1]] = {
				pk = pk,
				skill_id = row[1],
				name = GetItemInfo(row[1]),
				craft_count = row[2],
				colors = row[3],
				phaseId = row[4],
				scroll_id = row[5],
				recipe = recipe,
			}
		end
	end
	local refs = {}
	for _, row in pairs(data) do
		if row.pk then refs[#refs + 1] = row end
	end
	for _, row in ipairs(refs) do
		for _, reagent in ipairs(row.recipe) do
			if not data[reagent.id] then
				data[reagent.id] = { skill_id = reagent.id, name = GetItemInfo(reagent.id), recipe = {}, colors = {} }
			end
		end
		if row.scroll_id and row.scroll_id > 0 and not data[row.scroll_id] then
			data[row.scroll_id] = { skill_id = row.scroll_id, name = GetItemInfo(row.scroll_id), recipe = {}, colors = {} }
		end
	end
	return self
end

function db:refresh()
	local function cost(id)
		local r = data[id]
		if not r then return ns.Market:GetUnitPrice(id) end
		local total = 0
		for _, g in ipairs(r.recipe) do
			total = total + g.count * (g.id == id and 0 or cost(g.id))
		end
		return total
	end
	for id, r in pairs(data) do
		r.buyout = ns.Market:GetUnitPrice(id)
		r.cost = cost(r.skill_id)
	end
	return self
end

ns.db = setmetatable(db, { __index = data })
