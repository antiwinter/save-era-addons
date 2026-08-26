local _, ns = ...

local Planner = { attached = false, profession = nil }
local frame = CreateFrame("Frame", "artisanPlanner", UIParent, "BackdropTemplate")
frame:SetSize(430, 280)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -12)

local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("TOPLEFT", 18, -48)
body:SetText("Planner skeleton\n\nThis is where the profession plan editor will go.\nTarget selection, recipe choices, and material projections\nwill be designed here in a later pass.")

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOM", 0, 14)

local function reparent(parent)
	if frame.SetParent then frame:SetParent(parent) end
	if frame.ClearAllPoints then frame:ClearAllPoints() end
end

function Planner:Attach()
	local parent = _G and _G.TradeSkillFrame
	if not parent then
		parent = CreateFrame("Frame", "TradeSkillFrame", UIParent, "BackdropTemplate")
	end
	reparent(parent)
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -42)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)
	self.attached = true
	footer:SetText("Attached to the trade-skill window")

	if not self.tab then
		self.tab = CreateFrame("Button", "Artisan_PlannerTab", parent, "CharacterFrameTabButtonTemplate")
		self.tab:SetText("Planner")
		self.tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 116, 0)
		self.tab:SetScript("OnClick", function() self:Select() end)
		local tabId = (parent.numTabs or 1) + 1
		parent.numTabs = tabId
		if PanelTemplates_SetNumTabs then PanelTemplates_SetNumTabs(parent, tabId) end
		if self.tab.SetID then self.tab:SetID(tabId) end
	end
	return true
end

function Planner:Select()
	local parent = _G and _G.TradeSkillFrame
	if parent and parent.Show then parent:Show() end
	frame:Show()
	if parent and self.tab and PanelTemplates_SetTab and self.tab.GetID then
		PanelTemplates_SetTab(parent, self.tab:GetID())
	end
end

function Planner:Show(pk, plan)
	self.profession = pk
	title:SetText((ns.getProfName(pk) or pk) .. " planner")
	if plan then
		body:SetText(string.format("Planner skeleton\n\nTarget: %d\n\nThe plan editor will replace this placeholder.", plan.target))
	else
		body:SetText("Planner skeleton\n\nThis is where the profession plan editor will go.\nTarget selection, recipe choices, and material projections\nwill be designed here in a later pass.")
	end
	frame:Show()
end

function Planner:Hide()
	frame:Hide()
end

function Planner:Open(pk, plan)
	self.profession = pk
	reparent(UIParent)
	frame:SetPoint("CENTER")
	self.attached = false
	footer:SetText("Standalone planner - learn the profession to attach it")
	self:Show(pk, plan)
	return "standalone"
end

function Planner:OnTradeSkillShow()
	self.profession = ns.store.cur_pk
	if not self.profession then return end
	self:Attach()
	self:Show(self.profession)
	self:Select()
end

ns.PlannerUI = Planner
