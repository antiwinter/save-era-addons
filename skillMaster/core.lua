local addonName, ns = ...

-- Bootstrap: SavedVariables + shared namespace. Mirrors the whoaThickCC pattern.
-- Load order (see .toc): core -> data -> planner -> runtime -> ui -> debug.

ns.defaults = {
	target = nil, -- nil => use the profession's max rank
	phase = 3,
	wishlist = {},
	debug = false,
}

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" and arg1 == addonName then
		skillMasterDB = skillMasterDB or {}
		for k, v in pairs(ns.defaults) do
			if skillMasterDB[k] == nil then skillMasterDB[k] = v end
		end
		ns.cfg = skillMasterDB
	end
end)
