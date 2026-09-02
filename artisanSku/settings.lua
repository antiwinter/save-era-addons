local addonName, ns = ...
local f = CreateFrame("Frame")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function()
	local category = Settings.RegisterVerticalLayoutCategory("artisanSku")
	local function getDescription()
		if ns.cfg.passcode == "" then return "Passcode\nRun /artsku passcode CODE to enable sync." end
		return ("Passcode\nCurrent passcode: %s\nRun /artsku passcode [CODE] to update/disable sync."):format(ns.cfg.passcode)
	end
	local setting = Settings.RegisterProxySetting(
		category, "artisanSku_sync", Settings.VarType.Boolean, "Enable sync",
		false,
		function() return ns.cfg.passcode ~= "" end,
		function() end)
	local initializer = Settings.CreateCheckbox(category, setting, getDescription)
	initializer:AddModifyPredicate(function() return false end)
	Settings.RegisterAddOnCategory(category)
	ns.settingsCategory = category
end)
SLASH_ARTSKU1 = "/artsku"
SlashCmdList.ARTSKU = function(message)
	local command, value = strtrim(message or ""):match("^(%S+)%s*(.-)$")
	if command == "passcode" then
		ns.cfg.passcode = strtrim(value or "")
		Settings.NotifyUpdate("artisanSku_sync")
		print(ns.cfg.passcode == "" and "artisanSku: sync disabled" or "artisanSku: sync enabled")
	elseif not command and ns.settingsCategory then
		Settings.OpenToCategory(ns.settingsCategory:GetID())
	else
		print("Usage: /artsku passcode [CODE]")
	end
end
