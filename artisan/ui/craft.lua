local _, ns = ...

local Craft = {}
local panel = CreateFrame("Frame", "artisanPanel", UIParent, "BackdropTemplate")
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
title:SetText("artisan")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", title, "BOTTOM", 0, -4)
status:SetText("No plan")

local craftBtn = CreateFrame("Button", "Artisan_CraftBtn", panel, "UIPanelButtonTemplate")
craftBtn:SetSize(180, 24)
craftBtn:SetPoint("BOTTOM", 0, 12)
craftBtn:SetText("Craft next")
craftBtn:SetScript("OnClick", function()
	if ns.ss then ns.ss:DoAction() else ns.hint("No plan") end
end)

function Craft:Show()
	local pk = ns.store.cur_pk
	if not pk then return end
	if ns.pm.pk ~= pk and not ns.pm:load(pk) then return end
	local snapshot = ns.store.snaps[pk]
	if not snapshot then
		ns.hint("Start a plan first")
		return
	end
	ns.ss = ns.CreateSession(snapshot)
	panel:Show()
end

function Craft:Hide()
	panel:Hide()
end

function Craft:SetStatus(message, ...)
	if select("#", ...) > 0 then message = string.format(message, ...) end
	status:SetText(message)
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
