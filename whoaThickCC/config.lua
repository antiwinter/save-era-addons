local addonName, ns = ...

local MEDIA = "Interface\\AddOns\\whoaThickCC\\media\\statusbar\\"

local toggles = {
	{ "classColor", "Class colors", "Color player health bars by class." },
	{ "reactColor", "Reaction colors", "Color NPC health bars by reaction." },
	{ "blizzColors", "Blizzard reaction palette", "Use Blizzard's brighter reaction colors." },
	{ "blueShamans", "Blue shamans", "Use blue instead of pink for the shaman class color." },
}

local textures = {
	{ value = "whoa", label = "Whoa" },
	{ value = "smooth", label = "Smooth" },
	{ value = "blizzard", label = "Blizzard" },
	{ value = "aluminium", label = "Aluminium" },
	{ value = "banto", label = "Banto" },
	{ value = "glaze", label = "Glaze" },
	{ value = "otravi", label = "Otravi" },
	{ value = "perl", label = "Perl" },
	{ value = "striped", label = "Striped" },
	{ value = "ace", label = "Ace" },
	{ value = "liteStep", label = "LiteStep" },
	{ value = "swag", label = "Swag" },
	{ value = "shiny", label = "Shiny" },
	{ value = "metal", label = "Metal" },
	{ value = "neon", label = "Neon" },
	{ value = "cracked", label = "Cracked" },
	{ value = "65", label = "65" },
	{ value = "status", label = "Status" },
}

local fonts = {
	{ value = "SystemFont_Outline_Small", label = "Small" },
	{ value = "SystemFont_Outline", label = "Normal" },
	{ value = "Game15Font_o1", label = "Big" },
	{ value = "NumberFontNormalSmall", label = "Mono" },
}

function ns.ApplyStatusbarTexture()
	local texture = MEDIA .. ns.cfg.statusbarTexture
	for _, unit in ipairs(ns.units) do
		-- Apply to health bar
		local barName = ns.barNames and ns.barNames[unit]
		local bar = barName and _G[barName]
		if bar and bar.SetStatusBarTexture then
			bar:SetStatusBarTexture(texture)
		end
	end
	-- Apply to mana bars directly (like the original project does)
	local manaBars = {
		"PlayerFrameManaBar",
		"PetFrameManaBar",
		"TargetFrameManaBar",
		"TargetFrameToTManaBar",
		"FocusFrameManaBar",
		"FocusFrameToTManaBar",
	}
	for i = 1, 4 do
		table.insert(manaBars, "PartyMemberFrame" .. i .. "ManaBar")
	end
	for _, barName in ipairs(manaBars) do
		local bar = _G[barName]
		if bar and bar.SetStatusBarTexture then
			bar:SetStatusBarTexture(texture)
		end
	end
end

-- Hook mana bar updates to reapply texture when power type changes
hooksecurefunc("UnitFrameManaBar_UpdateType", function(manaBar)
	if not ns.cfg then return end
	local texture = MEDIA .. ns.cfg.statusbarTexture
	local powerType, powerToken = UnitPowerType(manaBar.unit)
	local info = PowerBarColor[powerToken]
	if info and not info.atlas and not manaBar.lockColor then
		manaBar:SetStatusBarTexture(texture)
	end
end)

local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	local category = Settings.RegisterVerticalLayoutCategory("Whoa Thick CC")

	for _, t in ipairs(toggles) do
		local key, label, tooltip = t[1], t[2], t[3]
		local setting = Settings.RegisterProxySetting(
			category, "whoaThickCC_" .. key, Settings.VarType.Boolean, label,
			ns.defaults[key],
			function() return ns.cfg[key] end,
			function(value)
				ns.cfg[key] = value
				if key == "blueShamans" then
					ns.ApplyShamanColor()
				else
					ns.Refresh()
				end
			end)
		Settings.CreateCheckbox(category, setting, tooltip)
	end

	-- Statusbar texture dropdown
	local function GetOptions()
		local container = Settings.CreateControlTextContainer()
		for _, t in ipairs(textures) do
			container:Add(t.value, t.label)
		end
		return container:GetData()
	end

	local setting = Settings.RegisterProxySetting(
		category, "whoaThickCC_statusbarTexture", Settings.VarType.String, "Statusbar Texture",
		ns.defaults.statusbarTexture,
		function() return ns.cfg.statusbarTexture end,
		function(value)
			ns.cfg.statusbarTexture = value
			ns.ApplyStatusbarTexture()
		end)
	Settings.CreateDropdown(category, setting, GetOptions, "Choose the statusbar texture for health and mana bars.")

	-- Font dropdown
	local function GetFontOptions()
		local container = Settings.CreateControlTextContainer()
		for _, t in ipairs(fonts) do
			container:Add(t.value, t.label)
		end
		return container:GetData()
	end

	local fontSetting = Settings.RegisterProxySetting(
		category, "whoaThickCC_font", Settings.VarType.String, "Font",
		ns.defaults.font,
		function() return ns.cfg.font end,
		function(value)
			ns.cfg.font = value
			ns.ApplyFont()
		end)
	Settings.CreateDropdown(category, fontSetting, GetFontOptions, "Choose the font for health and mana bar text.")

	Settings.RegisterAddOnCategory(category)
	ns.settingsCategory = category

	if ns.cfg.blueShamans then ns.ApplyShamanColor() end
	ns.ApplyStatusbarTexture()
	ns.ApplyFont()
end)

SLASH_WUF1 = "/wuf"
SlashCmdList.WUF = function()
	if ns.settingsCategory then
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	end
end
