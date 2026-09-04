local _, ns = ...

local data, professions = {}, {}
for pk, rows in pairs(skills) do
	professions[pk] = {}
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
		professions[pk][#professions[pk] + 1] = row[1]
	end
end

local db = {}

function db:iterate(pk)
	assert(pk == "all" or professions[pk], "invalid profession: " .. tostring(pk))
	local rows = {}
	local keys = {}
	if pk == "all" then
		for key in pairs(professions) do keys[#keys + 1] = key end
		table.sort(keys)
	else
		keys[1] = pk
	end
	for _, key in ipairs(keys) do
		for _, itemID in ipairs(professions[key]) do rows[#rows + 1] = data[itemID] end
	end
	return rows
end

function db:price(itemID)
	local vendor = select(11, GetItemInfo(itemID))
	local buyout = ns.Market and ns.Market:GetUnitPrice(ns.realm, itemID)
		or item_prices[itemID]
	return vendor, buyout, data[itemID] and data[itemID].cost or buyout
end

function db:refresh()
	local memo = {}
	local function cost(itemID, visiting)
		if memo[itemID] ~= nil then return memo[itemID] end
		local row = data[itemID]
		if not row then return select(2, self:price(itemID)) end
		visiting = visiting or {}
		if visiting[itemID] then return 0 end
		visiting[itemID] = true
		local total = 0
		for _, reagent in ipairs(row.recipe) do
			local price = cost(reagent.id, visiting)
			if price == nil then
				total = math.huge
				break
			end
			total = total + reagent.count * price
		end
		visiting[itemID] = nil
		memo[itemID] = total
		return total
	end
	for itemID, row in pairs(data) do row.cost = cost(itemID) end
	return self
end

ns.db = setmetatable(db, { __index = data })
