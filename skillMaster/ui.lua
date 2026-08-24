local addonName, ns = ...

-- ui.lua — minimal panel: a dropdown to pick a stored plan, the next action +
-- shopping list, and a single "Craft" button. The button is the ONLY path to
-- crafting, keeping DoTradeSkill player-initiated (one click per batch).

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
	local keys = {}
	for prof in pairs(ns.plans) do keys[#keys + 1] = prof end
	table.sort(keys)
	for _, prof in ipairs(keys) do
		local info = UIDropDownMenu_CreateInfo()
		info.text = prof
		info.checked = ns.Session.plan and ns.Session.plan.prof == prof
		info.func = function()
			ns.Session:Select(prof)
			UIDropDownMenu_Close()
			ns.OnSessionUpdate()
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

-- Build followups land here, including CreatePlan's deferred open-window retry.
ns.OnPlan = function(ok, msg)
	print("|cff00b4ff[skm]|r " .. msg)
	if ok then
		panel:Show()
		ns.OnSessionUpdate()
	end
end

-- Refresh display from live session state. Registered as the session callback.
function ns.OnSessionUpdate()
	UIDropDownMenu_SetText(planDrop, ns.Session.plan and ns.Session.plan.prof or "no plan")
	local S = ns.Session
	local p = S.plan
	if not p then
		status:SetText("No plan — /skm plan <prof> [target]")
		return
	end
	if not ns.curProfName() then
		status:SetText(string.format("%s %d/%d — window closed, click Craft",
			p.prof, S.skill.lvl, p.target))
		return
	end
	local ac = S:CurrentAction()
	if ac then
		status:SetText(string.format("%s %d/%d\nNext: %s x%d (%d/%d)",
			p.prof, S.skill.lvl, p.target, GetItemInfo(ac.item) or ac.item,
			math.ceil(ac.count - ac.crafted), ac.crafted, math.ceil(ac.count)))
	elseif S.skill.lvl >= p.target then
		status:SetText(string.format("%s reached %d — done", p.prof, S.skill.lvl))
	else
		status:SetText(string.format("%s %d/%d — plan done, re-run /skm plan %s %d",
			p.prof, S.skill.lvl, p.target, p.prof, p.target))
	end
end

SLASH_SKILLMASTER1 = "/skm"
SlashCmdList.SKILLMASTER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "debug" then
		if ns.Debug then ns.Debug() end
	elseif msg == "plan" or msg:match("^plan%s") then
		local prof, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not prof then
			print("|cff00b4ff[skm]|r usage: /skm plan <prof> [target]")
			return
		end
		local ok, out = ns.CreatePlan(prof, target ~= "" and tonumber(target) or nil)
		print("|cff00b4ff[skm]|r " .. out)
		if ok then
			local p = ns.plans[prof]
			ns.Format.Print(p.actions, p.materials, GetItemInfo, function(line) print("|cff00b4ff[skm]|r " .. line) end)
			panel:Show()
			ns.OnSessionUpdate()
		end
	elseif msg == "hide" then
		panel:Hide()
	else
		panel:Show()
		ns.OnSessionUpdate()
	end
end