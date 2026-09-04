local _, ns = ...

local data, pks = {}, {}
for pk, rows in pairs(skills) do
	pks[pk] = (pks[pk] or 0) + 1
	for _, row in ipairs(rows) do
		local recipe = {}
		for _, reagent in ipairs(row[6] or {}) do
			recipe[#recipe + 1] = { id = reagent[1], count = reagent[2] }
		end
		assert(not data[row[1]], "duplicate skill item: " .. row[1])
		local name, _, _, _, _, _, _, _, _, _, vendor = GetItemInfo(row[1])
		data[row[1]] = {
			pk = pk,
			skill_id = row[1],
			name = name,
			craft_count = row[2],
			colors = row[3],
			phaseId = row[4],
			scroll_id = row[5],
			recipe = recipe,
			vendor = vendor,
			buyout = ns.Market:GetUnitPrice(row[1]),
			cost = nil,
		}
	end
end

local db = {}

function db:iterate(pk)
	assert(pk == "all" or pks[pk], "invalid profession: " .. tostring(pk))
	local rows = {}
	for id, d in pairs(data) do
		if d.pk == pk or pk == "all" then
			rows[#rows + 1] = data[id]
		end
	end
	return rows
end

function db:refresh()
	local function cost(r)
		local total = 0
		for _, g in ipairs(r.recipe) do
			local price = data[g.id] and cost(g.id) or ns.Market:GetUnitPrice(id)
			total = total + g.count * price
		end
		return total
	end
	for id, r in pairs(data) do
		r.buyout = ns.Market:GetUnitPrice(id) or r.buyout
		r.cost = cost(r)
	end
	return self
end

ns.db = setmetatable(db, { __index = data })
