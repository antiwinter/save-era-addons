local addonName, ns = ...

ns.defaults = {
	classColor = true,
	reactColor = true,
	blizzColors = false,
	blueShamans = true,
	statusbarTexture = "whoa",
	font = "SystemFont_Outline_Small",
}

-- Units whose health bars we manage. The frame for each is resolved lazily in
-- color.lua, since focus/party frames may not exist on every client or state.
ns.units = {
	"player", "pet", "target", "targettarget",
	"focus", "focustarget",
	"party1", "party2", "party3", "party4",
}

ns.Refresh = function() end -- replaced in color.lua once the color engine loads

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_ENTERING_WORLD")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:RegisterEvent("UNIT_FACTION")
f:RegisterEvent("UNIT_HEALTH")

f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		whoaThickCCDB = whoaThickCCDB or {}
		for k, v in pairs(ns.defaults) do
			if whoaThickCCDB[k] == nil then whoaThickCCDB[k] = v end
		end
		ns.cfg = whoaThickCCDB
	else
		ns.Refresh()
	end
end)
