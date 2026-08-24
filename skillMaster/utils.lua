local addonName, ns = ...

local function FindProfName(key)
	local ids = profs[key]
	if not ids then return nil end
	for _, sid in ipairs(ids) do
		local name = GetSpellInfo(sid)
		if name then return name end
	end
end
ns.FindProfName = FindProfName

local function openProfWindow()
	local pname = FindProfName(ns.store.cur_pk)
	if pname ~= curProfName() then
		CastSpellByName(pname)
    end
end

-- The open trade-skill line's display name, or nil when nothing is open.
ns.curProfName = function()
    openProfWindow()
	local name = GetTradeSkillLine()
	return name and name ~= "" and name ~= "UNKNOWN" and name or nil
end

ns.skillLvl = function()
    openProfWindow()
    local name, _, lvl, cap = GetTradeSkillLine()
    return lvl, cap
end

ns.skillIndex = function(itemId)
    openProfWindow()
    local name = GetItemInfo(itemId)
    	for i = 1, GetNumTradeSkills() do
		local n, kind = GetTradeSkillInfo(i)
		if n == name and kind and kind ~= "header" then
			return i
		end
	end
end

ns.skillScroll = function(itemId)
	local db = ns.db[ns.store.cur_pk]
    local r = db and db[itemId]
    local sid = r and r.teach_id
    local name = sid and GetItemInfo(sid)
    return sid, name
end

function learnScroll(itemId)
	local name = GetItemInfo(itemId)
    if not name then return false end
	for b = 0, 4 do
		for slot = 1, (GetContainerNumSlots(b) or 0) do
			if GetContainerItemID(b, slot) == itemId then
				UseContainerItem(b, slot)
				return true
			end
		end
	end
end
ns.learnScroll = learnScroll

ns.store = setmetatable(skillMasterDB, { 
    __index = function(key) return self[key] end,
    set = function(key, value) self[key] = value end,
    init = function()
        if not self.plans then
            self.plans = {}
        end
    end
})
