local addonName, ns = ...
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	local category = Settings.RegisterVerticalLayoutCategory("artisanSku")
	local setting = Settings.RegisterProxySetting(
		category, "artisanSku_passcode", Settings.VarType.String, "Party sync passcode",
		ns.defaults.passcode,
		function() return ns.cfg.passcode end,
		function(value) ns.cfg.passcode = value end)
	Settings.CreateInput(category, setting, "Use the same non-empty passcode on characters that should share item data.")
	Settings.RegisterAddOnCategory(category)
	ns.settingsCategory = category
end)
SLASH_ARTISANSKU1 = "/artisansku"
SlashCmdList.ARTISANSKU = function()
	Settings.OpenToCategory(ns.settingsCategory:GetID())
end
