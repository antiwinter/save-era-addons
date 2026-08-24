local addonName, ns = ...

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
UIDropDownMenu_Initialize(planDrop, function(self, level)
	for pk, prof in pairs(ns.store.plans) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = prof
		info.checked = ns.store.cur_pk == pk
		info.func = function()
			ns.store.cur_pk = pk
			ns.ss = ns.CreateSession(prof)
			UIDropDownMenu_Close()
		end
		UIDropDownMenu_AddButton(info, level)
	end
end)
UIDropDownMenu_SetWidth(planDrop, 200)
UIDropDownMenu_SetText(planDrop, "no plan")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", planDrop, "BOTTOM", 0, -4)
status:SetText("No plan — /skm plan <prof> [target]")

local craftBtn = CreateFrame("Button", "SkillMaster_CraftBtn", panel, "UIPanelButtonTemplate")
craftBtn:SetSize(180, 24)
craftBtn:SetPoint("BOTTOM", 0, 12)
craftBtn:SetText("Craft next")
craftBtn:SetScript("OnClick", function()
	status:SetText(ns.Session:DoAction())
end)

ns.hint = function (fmt, ...)
	status:SetText(string.format(fmt, ...))
end

SLASH_SKILLMASTER1 = "/skm"
SlashCmdList.SKILLMASTER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "plan" or msg:match("^plan%s") then
		local pk, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not pk then
			print("|cff00b4ff[skm]|r usage: /skm plan <pk> [target]")
			return
		end
		local p = ns.CreatePlan(pk, target ~= "" and tonumber(target) or nil)
		if p then
			ns.store.cur_pk = pk
			ns.store.plans[pk] = p
			ns.Format.PrintPlan(p)
			panel:Show()
		end
	elseif msg == "hide" then
		panel:Hide()
	else
		panel:Show()
	end
end