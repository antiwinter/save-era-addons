local _, ns = ...

local ceil = math.ceil

local function PrintPlan(plan)
	print("PLAN")
	for _, action in ipairs(plan.actions) do
		local name = GetItemInfo(action.item) or tostring(action.item)
		print(string.format("%s, %d, %d, %d", name, ceil(action.count), action.from, action.to))
	end
	print("BAG")
	local ids = {}
	for id in pairs(plan.materials) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		local name = GetItemInfo(id) or tostring(id)
		print(string.format("%s, %d", name, ceil(plan.materials[id])))
	end
end

ns.Format = { PrintPlan = PrintPlan }
