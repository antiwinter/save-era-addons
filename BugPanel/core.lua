local addonName, ns = ...

ns.defaults = {
	point = "CENTER",
	x = 0,
	y = 0,
	minimapAngle = 220,
}

-- Filled in by panel.lua / minimap.lua once the UI loads.
ns.Toggle = function() end
ns.Refresh = function() end
ns.RefreshIcon = function() end

-- Errors captured this login session, newest last. BugGrabber owns capture and
-- cross-session persistence; we only ever read the slice for the live session.
function ns.SessionErrors()
	local out = {}
	if not BugGrabber then return out end
	local sid = BugGrabber:GetSessionId()
	for _, e in next, BugGrabber:GetDB() do
		if e.session == sid then out[#out + 1] = e end
	end
	return out
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(_, _, loaded)
	if loaded ~= addonName then return end
	f:UnregisterEvent("ADDON_LOADED")

	BugPanelDB = BugPanelDB or {}
	for k, v in pairs(ns.defaults) do
		if BugPanelDB[k] == nil then BugPanelDB[k] = v end
	end
	ns.db = BugPanelDB

	-- Tell BugGrabber a display exists so it stops echoing errors to chat, and
	-- refresh whenever a new bug is grabbed. v12 BugGrabber speaks through the
	-- Blizzard EventRegistry, not the old BugGrabber.RegisterCallback method
	-- BugSack still calls (the source of its core.lua:166 nil-call crash).
	if EventRegistry then
		EventRegistry:TriggerEvent("BugGrabber.DisplayRegistered")
		EventRegistry:RegisterCallback("BugGrabber.BugGrabbed", function()
			ns.Refresh()
			ns.RefreshIcon()
		end, ns)
	end

	ns.InitMinimap()

	SLASH_BUGPANEL1 = "/bugpanel"
	SLASH_BUGPANEL2 = "/bugs"
	SlashCmdList.BUGPANEL = function() ns.Toggle() end
end)
