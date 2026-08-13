local _, ns = ...

local SHAMAN_BLUE = { 0.0, 0.44, 0.87 }
local SHAMAN_PINK = { 0.96, 0.55, 0.73 }

-- Resolve the Blizzard health bar global for a managed unit. Bar names don't
-- map uniformly from unit tokens (targettarget -> TargetFrameToTHealthBar), so
-- the irregular cases are listed and the rest derived by convention.
local barName = {
	player = "PlayerFrameHealthBar",
	pet = "PetFrameHealthBar",
	target = "TargetFrameHealthBar",
	targettarget = "TargetFrameToTHealthBar",
	focus = "FocusFrameHealthBar",
	focustarget = "FocusFrameToTHealthBar",
}
for i = 1, 4 do barName["party" .. i] = "PartyMemberFrame" .. i .. "HealthBar" end

ns.barNames = barName

local function HealthBar(unit)
	return _G[barName[unit]]
end

-- Single source of truth for health bar color.
function ns.UnitHealthColor(unit)
	local cfg = ns.cfg

	if UnitIsPlayer(unit) then
		if not UnitIsConnected(unit) then
			return 0.5, 0.5, 0.5
		elseif cfg.classColor then
			local _, class = UnitClass(unit)
			local c = (CUSTOM_CLASS_COLORS or RAID_CLASS_COLORS)[class]
			if c then return c.r, c.g, c.b end
		end
	end

	if cfg.reactColor then
		if UnitIsTapDenied(unit) then return 0.5, 0.5, 0.5 end
		if UnitIsCivilian(unit) then return 1.0, 1.0, 1.0 end

		local r, g, b = UnitSelectionColor(unit)
		if cfg.blizzColors then return r, g, b end

		if r >= 0.9 and g >= 0.5 and g <= 0.6 and b == 0 then
			return r, g, b -- orange, keep as-is
		elseif r >= 0.9 and g >= 0.9 and b == 0 then
			return 0.9, 0.75, 0 -- yellow
		elseif r >= 0.9 and g == 0 and b == 0 then
			return 0.8, 0.1, 0 -- red
		end
		return 0, 0.6, 0.1 -- green
	end

	return 0, 0.9, 0
end

local function Colorize(unit)
	local bar = HealthBar(unit)
	if bar and UnitExists(unit) then
		bar:SetStatusBarColor(ns.UnitHealthColor(unit))
	end
end

function ns.Refresh()
	if not ns.cfg then return end
	for _, unit in ipairs(ns.units) do
		Colorize(unit)
	end
end

-- Blue shaman override: swap the shared class color, then recolor.
function ns.ApplyShamanColor()
	local c = ns.cfg.blueShamans and SHAMAN_BLUE or SHAMAN_PINK
	local color = CreateColor(c[1], c[2], c[3])
	color.colorStr = color:GenerateHexColor()
	RAID_CLASS_COLORS.SHAMAN = color
	ns.Refresh()
end

-- Keep Blizzard from resetting our colors: re-apply after its own updates.
hooksecurefunc("UnitFrameHealthBar_Update", function(bar, unit)
	if unit and barName[unit] then Colorize(unit) end
end)

-- Backup and replace HealthBar_OnValueChanged to maintain our colors during combat
local originalHealthBar_OnValueChanged = HealthBar_OnValueChanged
function HealthBar_OnValueChanged(self, value, smooth)
	if not value then return end

	-- Call Blizzard's default behavior first
	if originalHealthBar_OnValueChanged then
		originalHealthBar_OnValueChanged(self, value, smooth)
	end

	-- Now reapply our custom colors
	local unit = self:GetParent() and self:GetParent().unit
	if unit and barName[unit] then
		Colorize(unit)
	elseif self == PlayerFrameHealthBar then
		Colorize("player")
	end
end

-- The unit-frame value-changed handler is UnitFrameHealthBar_OnValueChanged;
-- the old HealthBar_OnValueChanged global now belongs to the game tooltip.
hooksecurefunc("UnitFrameHealthBar_OnValueChanged", function(bar)
	local unit = bar.unit or (bar == PlayerFrameHealthBar and "player")
	if unit and barName[unit] then Colorize(unit) end
end)
