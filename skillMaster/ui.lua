local addonName, ns = ...

-- ui.lua — minimal panel that shows the next action + shopping list and a
-- single "Craft" button. The button is the ONLY path to crafting, keeping
-- DoTradeSkill player-initiated (one click per batch).

local panel = CreateFrame("Frame", "skillMasterPanel", UIParent, "BackdropTemplate")
panel:SetSize(220, 120)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("skillMaster")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", title, "BOTTOM", 0, -6)
status:SetText("Open a trade skill.")

local craftBtn = CreateFrame("Button", "SkillMaster_CraftBtn", panel, "UIPanelButtonTemplate")
craftBtn:SetSize(180, 24)
craftBtn:SetPoint("BOTTOM", 0, 12)
craftBtn:SetText("Craft next")
craftBtn:SetScript("OnClick", function()
	status:SetText(ns.Runtime:DoAction())
end)

-- Refresh display from live runtime state. Registered as the runtime callback.
function ns.OnRuntimeUpdate()
	local R = ns.Runtime
	if not R:ProfKey() then
		status:SetText((R.skill.name or "?") .. ": no data")
		return
	end
	if #R.plan == 0 then R:BuildPlan() end
	local ac = R:CurrentAction()
	if ac then
		status:SetText(string.format("%s %d/%d\nNext: %s -> %d",
			R.skill.name, R.skill.lvl, ns.cfg.target or R.skill.cap,
			GetItemInfo(ac.item) or ac.item, ac.to))
	else
		status:SetText(string.format("%s %d — plan complete", R.skill.name, R.skill.lvl))
	end
end

SLASH_SKILLMASTER1 = "/skm"
SlashCmdList.SKILLMASTER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "debug" then
		if ns.Debug then ns.Debug() end
	elseif msg == "plan" then
		local R = ns.Runtime
		if #R.plan == 0 then R:BuildPlan() end
		ns.Format.Print(R.plan, R.material, GetItemInfo, function(line) print("|cff00b4ff[skm]|r " .. line) end)
	elseif msg == "hide" then
		panel:Hide()
	else
		panel:Show()
		ns.OnRuntimeUpdate()
	end
end

