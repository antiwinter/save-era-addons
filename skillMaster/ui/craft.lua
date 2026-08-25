local _, ns = ...

local Craft = {}
local panel = CreateFrame("Frame", "skillMasterPanel", UIParent, "BackdropTemplate")
panel:SetSize(240, 150)
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

local planDrop = CreateFrame("Frame", "SkillMaster_PlansDrop", panel, "UIDropDownMenuTemplate")
planDrop:SetPoint("TOP", title, "BOTTOM", 0, -4)
UIDropDownMenu_Initialize(planDrop, function(_, level)
	for pk in pairs(ns.store.plans or {}) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = pk
		info.checked = ns.store.cur_pk == pk
		info.func = function()
			ns.store:select(pk)
			CloseDropDownMenus()
			ns.hint("Selected " .. pk)
		end
		UIDropDownMenu_AddButton(info, level)
	end
end)
UIDropDownMenu_SetWidth(planDrop, 200)
UIDropDownMenu_SetText(planDrop, "no plan")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", planDrop, "BOTTOM", 0, -4)
status:SetText("No plan - /skm plan <pk> [target]")

local craftBtn = CreateFrame("Button", "SkillMaster_CraftBtn", panel, "UIPanelButtonTemplate")
craftBtn:SetSize(180, 24)
craftBtn:SetPoint("BOTTOM", 0, 12)
craftBtn:SetText("Craft next")
craftBtn:SetScript("OnClick", function()
	if ns.ss then ns.ss:DoAction() else ns.hint("No plan - /skm plan <pk> [target]") end
end)

function Craft:Show()
	panel:Show()
end

function Craft:Hide()
	panel:Hide()
end

function Craft:SetStatus(message, ...)
	if select("#", ...) > 0 then message = string.format(message, ...) end
	status:SetText(message)
	UIDropDownMenu_SetText(planDrop, ns.store.cur_pk or "no plan")
end

function ns.disable()
	craftBtn:Disable()
end

function ns.enable()
	craftBtn:Enable()
end

function ns.hint(message, ...)
	Craft:SetStatus(message, ...)
end

ns.CraftUI = Craft
