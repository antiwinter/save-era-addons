local _, ns = ...

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
	for pk in pairs(ns.store.plans) do
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

function ns.disable()
	craftBtn:Disable()
end

function ns.enable()
	craftBtn:Enable()
end

function ns.hint(message, ...)
	if select("#", ...) > 0 then message = string.format(message, ...) end
	status:SetText(message)
	UIDropDownMenu_SetText(planDrop, ns.store.cur_pk or "no plan")
end

craftBtn:SetScript("OnClick", function()
	if ns.ss then ns.ss:DoAction() else ns.hint("No plan - /skm plan <pk> [target]") end
end)

SLASH_SKILLMASTER1 = "/skm"
SlashCmdList.SKILLMASTER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "plan" or msg:match("^plan%s") then
		local pk, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not pk then
			print("|cff00b4ff[skm]|r usage: /skm plan <pk> [target]")
			return
		end
		local plan, message = ns.CreatePlan(pk, target ~= "" and tonumber(target) or nil)
		if not plan then
			print("|cff00b4ff[skm]|r " .. message)
			ns.hint(message)
			return
		end
		ns.store:savePlan(plan)
		print("|cff00b4ff[skm]|r " .. message)
		ns.Format.PrintPlan(plan)
		ns.hint(message)
		panel:Show()
	elseif msg == "hide" then
		panel:Hide()
	else
		panel:Show()
	end
end
