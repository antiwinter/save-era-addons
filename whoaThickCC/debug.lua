local _, ns = ...

-- Snapshot live geometry into the SavedVariable so it survives /reload and can
-- be read from WTF/.../SavedVariables/whoaThickCC.lua on disk.

local function pointsOf(region)
	local t = {}
	if not region or not region.GetNumPoints then return t end
	for i = 1, region:GetNumPoints() do
		local p, rel, rp, x, y = region:GetPoint(i)
		local relName = rel and (rel.GetName and rel:GetName()) or tostring(rel)
		t[i] = string.format("%s -> %s.%s (%.1f, %.1f)", p or "?", relName or "?", rp or "?", x or 0, y or 0)
	end
	return t
end

local function dumpRegion(region)
	if not region then return "nil" end
	local d = {}
	d.name = region.GetName and region:GetName() or "(anon)"
	d.parent = region.GetParent and region:GetParent() and region:GetParent():GetName() or "?"
	if region.GetSize then
		local w, h = region:GetSize()
		d.size = string.format("%.1f x %.1f", w or 0, h or 0)
	end
	if region.GetLeft and region:GetLeft() then
		d.rect = string.format("L%.1f R%.1f T%.1f B%.1f",
			region:GetLeft(), region:GetRight(), region:GetTop(), region:GetBottom())
	end
	if region.GetScale then d.scale = region:GetScale() end
	if region.GetEffectiveScale then d.effScale = region:GetEffectiveScale() end
	if region.IsShown then d.shown = region:IsShown() end
	d.points = pointsOf(region)
	return d
end

local function snapshotFrame(frame)
	if not frame then return "missing" end
	return {
		frame = dumpRegion(frame),
		healthbar = dumpRegion(frame.healthbar),
		manabar = dumpRegion(frame.manabar),
		name = dumpRegion(frame.name),
		border = dumpRegion(frame.borderTexture),
	}
end

-- Report which bar text regions resolve (by property vs global name) and the
-- font each currently carries. Confirms whether ApplyFont is reaching them and
-- whether the configured font object exists in this client.
local function fontOf(fs)
	if not fs or not fs.GetFont then return "nil" end
	local file, height, flags = fs:GetFont()
	return string.format("%s @ %.1f [%s]", file or "?", height or 0, flags or "")
end

local function fontReport()
	local report = { configured = ns.cfg and ns.cfg.font, exists = ns.cfg and _G[ns.cfg.font] ~= nil }

	-- Resolve each preset font object directly, to see if they actually differ.
	local presets = {}
	for _, name in ipairs({ "SystemFont_Outline_Small", "SystemFont_Outline", "Game15Font_o1", "NumberFontNormalSmall" }) do
		presets[name] = fontOf(_G[name])
	end
	report.presets = presets

	local bars = { "PlayerFrameHealthBar", "PlayerFrameManaBar", "TargetFrameHealthBar", "TargetFrameManaBar" }
	for _, barName in ipairs(bars) do
		local bar = _G[barName]
		local entry = { barExists = bar ~= nil }
		if bar then
			for _, k in ipairs({ "TextString", "LeftText", "RightText" }) do
				entry["prop." .. k] = fontOf(bar[k])
			end
		end
		for _, suffix in ipairs({ "Text", "TextLeft", "TextRight" }) do
			entry["glob." .. suffix] = fontOf(_G[barName .. suffix])
		end
		report[barName] = entry
	end
	return report
end

SLASH_WUFDEBUG1 = "/wufdebug"
SlashCmdList.WUFDEBUG = function()
	whoaThickCCDB.debug = {
		when = date("%Y-%m-%d %H:%M:%S"),
		build = select(4, GetBuildInfo()),
		uiScale = UIParent:GetEffectiveScale(),
		fonts = fontReport(),
		player = snapshotFrame(PlayerFrame),
		playerTexture = dumpRegion(PlayerFrameTexture),
		playerHealthBar = dumpRegion(PlayerFrameHealthBar),
		playerManaBar = dumpRegion(PlayerFrameManaBar),
		target = UnitExists("target") and snapshotFrame(TargetFrame) or "no target",
	}
	print("|cffe6cc80[whoaThickCC]|r debug snapshot saved. Type /rl, then read the SavedVariables file.")
end
