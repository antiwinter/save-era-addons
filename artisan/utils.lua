local _, ns = ...

function ns.getProfName(pk)
	local ids = profs[pk]
	if not ids then return nil end
	for _, spellId in ipairs(ids) do
		local name = GetSpellInfo(spellId)
		if name then return name end
	end
end

function ns.getProfKey(name)
	if not name then return nil end
	for pk in pairs(profs) do
		if ns.getProfName(pk) == name then return pk end
	end
end

function ns.openProfFrame(pk)
	pk = pk or ns.store.cur_pk
	local name = ns.getProfName(pk)
	if not name then return nil end
	local n, _, lvl, cap = GetTradeSkillLine()

	if n ~= name then
		CastSpellByName(name)
		n, _, lvl, cap = GetTradeSkillLine()
	end
	if n ~= name then return nil end
	return name, _, lvl, cap
end

function ns.getTradeSkillRange(pk)
	local _, _, skill, cap = ns.openProfFrame(pk)
	return skill or 1, cap or 150
end

function ns.getExistingMaterials()
	local existing = {}
	for bag = 0, 4 do
		for slot = 1, GetContainerNumSlots(bag) do
			local id = GetContainerItemID(bag, slot)
			if id then existing[id] = (existing[id] or 0) + (select(2, GetContainerItemInfo(bag, slot)) or 0) end
		end
	end
	return existing
end

function ns.craft(itemId, count)
	ns.openProfFrame()
	local name = GetItemInfo(itemId)
	if not name then return end
    local index
	for i = 1, GetNumTradeSkills() do
		local skillName, kind = GetTradeSkillInfo(i)
		if skillName == name and kind and kind ~= "header" then 
            index = i
            break
        end
	end
    
    if not index then return end
    local batch = math.max(1, math.min(count, GetTradeskillRepeatCount()))
    
    ns.hint("Crafting %s x%d", name, batch)
    DoTradeSkill(index, batch)
    return true
end

function ns.learnScrollFor(itemId)
    local db = ns.db[ns.store.cur_pk]
	local recipe = db and db[itemId]
	local sid = recipe and recipe.scroll_id
	if not sid then return ns.hint("Goto trainer") end

	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			if GetContainerItemID(bag, slot) == sid then
                ns.hint("Learning scroll: %s", GetItemInfo(sid))
				UseContainerItem(bag, slot)
				return
			end
		end
	end
    ns.hint("Missing scroll: %s", GetItemInfo(sid))
end

local state
local store = {}

function store:init()
	artisanDB = artisanDB or {}
	local char = UnitName and UnitName("player") or "player"
	char = char and char ~= "" and char or "player"
	artisanDB[char] = artisanDB[char] or {}
	state = artisanDB[char]
	state.plans = state.plans or {}
end

setmetatable(store, {
	__index = function(_, key) return state and state[key] end,
	__newindex = function(_, key, value) state[key] = value end,
})
ns.store = store
