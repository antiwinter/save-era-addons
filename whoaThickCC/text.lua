local _, ns = ...

-- Abbreviate a value: raw under 10k, N.Nk under a million, else N.NNm.
local function Abbrev(v)
	if v < 1e4 then return tostring(v) end
	if v < 1e6 then return format("%.1fk", v / 1e3) end
	return format("%.2fm", v / 1e6)
end

-- Humanized status-bar text. The 2026 Classic client converted TextStatusBar to
-- the retail Mixin pattern: TextStatusBar_UpdateTextStringWithValues is no longer a
-- global, so hooking it by name silently does nothing. UpdateTextStringWithValues is
-- now a method on each bar, hooked per-instance below (same story as frames.lua's
-- CheckClassification). Runs as a post-hook: we overwrite Blizzard's freshly-set text
-- with the abbreviated form and reassert our font, which Blizzard's update clobbers.
local function FormatStatusBarText(statusFrame, textString, value, _, valueMax)
	if not (value and valueMax and valueMax > 0) then return end
	if statusFrame.pauseUpdates then return end

	local left, right = statusFrame.LeftText, statusFrame.RightText

	-- Blizzard resets fontstrings to their default object on every text update, so
	-- reassert ours here -- this hook is the single point every managed bar's text
	-- passes through. SetFontObject is a no-op when already correct.
	if ns.cfg and ns.cfg.font then
		local font = _G[ns.cfg.font] and ns.cfg.font or ns.defaults.font
		if textString then textString:SetFontObject(font) end
		if left then left:SetFontObject(font) end
		if right then right:SetFontObject(font) end
	end

	local percent = math.ceil(value / valueMax * 100) .. "%"
	local display = GetCVar("statusTextDisplay")

	if display == "BOTH" and left and right then
		-- Percent on the left (mana-type bars only, matching the original), value on the right.
		if not statusFrame.powerToken or statusFrame.powerToken == "MANA" then
			left:SetText(value == 0 and "" or percent)
			left:Show()
		end
		right:SetText(value == 0 and "" or Abbrev(value))
		right:Show()
		textString:SetText("")
		textString:Hide()
		return
	end

	if left then left:SetText(""); left:Hide() end
	if right then right:SetText(""); right:Hide() end

	if value == 0 then
		textString:SetText("")
	elseif display == "PERCENT" then
		textString:SetText(percent)
	elseif display == "NUMERIC" then
		textString:SetText(Abbrev(value))
	else
		textString:SetText(Abbrev(value) .. " / " .. Abbrev(valueMax))
	end
	textString:Show()
end

-- Apply the configured font object to every managed bar's text regions. Text
-- regions are reachable two ways depending on the frame: as frame properties
-- (bar.TextString / .LeftText / .RightText) or as named globals (barTextLeft,
-- ...). Cover both so retail-Mixin frames (Target/Focus) get styled too.
local function BarNames()
	local names = {}
	for _, name in pairs(ns.barNames) do names[#names + 1] = name end
	local manaBars = {
		"PlayerFrameManaBar", "PetFrameManaBar",
		"TargetFrameManaBar", "TargetFrameToTManaBar",
		"FocusFrameManaBar", "FocusFrameToTManaBar",
	}
	for i = 1, 4 do manaBars[#manaBars + 1] = "PartyMemberFrame" .. i .. "ManaBar" end
	for _, name in ipairs(manaBars) do names[#names + 1] = name end
	return names
end

local propSuffixes = { "TextString", "LeftText", "RightText" }
local globalSuffixes = { "Text", "TextLeft", "TextRight" }

local function StyleFontString(fs, font)
	if fs and fs.SetFontObject then fs:SetFontObject(font) end
end

function ns.ApplyFont()
	if not ns.cfg then return end
	local font = _G[ns.cfg.font] and ns.cfg.font or ns.defaults.font
	for _, barName in ipairs(BarNames()) do
		local bar = _G[barName]
		if bar then
			for _, suffix in ipairs(propSuffixes) do
				StyleFontString(bar[suffix], font)
			end
		end
		for _, suffix in ipairs(globalSuffixes) do
			StyleFontString(_G[barName .. suffix], font)
		end
	end
end

-- Register the per-instance text hook on every managed bar. UpdateTextStringWithValues
-- is a TextStatusBarMixin method, not a global, so it must be hooked on each frame.
local hooked = {}
local function HookBars()
	for _, barName in ipairs(BarNames()) do
		local bar = _G[barName]
		if bar and bar.UpdateTextStringWithValues and not hooked[bar] then
			hooksecurefunc(bar, "UpdateTextStringWithValues", FormatStatusBarText)
			hooked[bar] = true
		end
	end
end

-- Bars for target/focus and party members are created on demand, so re-scan on the
-- events that bring them into existence rather than only once at login.
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_TARGET_CHANGED")
f:RegisterEvent("PLAYER_FOCUS_CHANGED")
f:RegisterEvent("GROUP_ROSTER_UPDATE")
f:SetScript("OnEvent", HookBars)
