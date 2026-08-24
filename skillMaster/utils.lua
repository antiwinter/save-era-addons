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

-- The open trade-skill line's display name, or nil when nothing is open.
local function curProfName()
	local name = GetTradeSkillLine()
	return name and name ~= "" and name ~= "UNKNOWN" and name or nil
end
ns.curProfName = curProfName

local function openProfWindow(key)
	local pname = FindProfName(key)
	if pname ~= curProfName() then
		CastSpellByName(pname)
    end
end
ns.openProfWindow = openProfWindow

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

function flush(prof, plan)
    local saved = skillMasterDB or {}
    if not saved.plans then
        saved.plans = {}
    end
    
    saved.plans[prof] = plan
end
ns.flush = flush
