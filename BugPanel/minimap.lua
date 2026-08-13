local addonName, ns = ...

local button

-- Park the button on the minimap edge at the stored angle (degrees).
local function updatePosition()
	local a = math.rad(ns.db.minimapAngle or 220)
	button:SetPoint("CENTER", Minimap, "CENTER", 80 * math.cos(a), 80 * math.sin(a))
end

local function onDrag()
	local mx, my = Minimap:GetCenter()
	local scale = Minimap:GetEffectiveScale()
	local px, py = GetCursorPosition()
	ns.db.minimapAngle = math.deg(math.atan2(py / scale - my, px / scale - mx))
	updatePosition()
end

local function tooltip(self)
	local n = #ns.SessionErrors()
	GameTooltip:SetOwner(self, "ANCHOR_LEFT")
	GameTooltip:AddLine("Bug Panel")
	if n > 0 then
		GameTooltip:AddLine(("|cffff4411%d|r errors this session"):format(n), 1, 1, 1)
	else
		GameTooltip:AddLine("|cff44ff44No errors|r", 1, 1, 1)
	end
	GameTooltip:AddLine("Click: open panel", 0.7, 0.7, 0.7)
	GameTooltip:AddLine("Shift-Click: reload UI", 0.7, 0.7, 0.7)
	GameTooltip:Show()
end

-- Red when the session holds bugs, green when clean.
function ns.RefreshIcon()
	if not button then return end
	local hasBugs = #ns.SessionErrors() > 0
	button.icon:SetTexture(hasBugs and "Interface\\COMMON\\Indicator-Red" or "Interface\\COMMON\\Indicator-Green")
	if GameTooltip:IsOwned(button) then tooltip(button) end
end

function ns.InitMinimap()
	button = CreateFrame("Button", "BugPanelMinimapButton", Minimap)
	button:SetSize(31, 31)
	button:SetFrameStrata("MEDIUM")
	button:SetFrameLevel(8)
	button:RegisterForClicks("LeftButtonUp")
	button:RegisterForDrag("LeftButton")
	button:SetMovable(true)

	button.icon = button:CreateTexture(nil, "BACKGROUND")
	button.icon:SetSize(18, 18)
	button.icon:SetPoint("CENTER", 0, 1)

	local border = button:CreateTexture(nil, "OVERLAY")
	border:SetSize(53, 53)
	border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	border:SetPoint("TOPLEFT")

	button:SetScript("OnClick", function()
		if IsShiftKeyDown() then
			ReloadUI()
		else
			ns.Toggle()
		end
	end)
	button:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDrag) end)
	button:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
	button:SetScript("OnEnter", tooltip)
	button:SetScript("OnLeave", function() GameTooltip:Hide() end)

	updatePosition()
	ns.RefreshIcon()
end
