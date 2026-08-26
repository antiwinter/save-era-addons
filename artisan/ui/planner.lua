local _, ns = ...

local Planner = { pk = nil, active = false }
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
title:SetText("Artisan planner")

local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("TOPLEFT", 18, -48)
body:SetText("Planner skeleton\n\nThis is where the pk plan editor will go.\nTarget selection, recipe choices, and material projections\nwill be designed here in a later pass.")

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOM", 0, 14)
footer:SetText("Artisan planner footer")

local function reparent(parent)
	frame:SetParent(parent)
	frame:ClearAllPoints()
end

function Planner:Attach()
	local parent = TradeSkillFrame
	reparent(parent)
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -42)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)

	local skillTab = self.skillTab
	if not skillTab then
		skillTab = CreateFrame("Button", "Artisan_SkillTab", parent, "CharacterFrameTabButtonTemplate")
		skillTab:SetText("Skill")
		skillTab:SetPoint("TOPLEFT", parent, "TOPLEFT", 40, 0)
		skillTab:SetID(1)
		skillTab:SetScript("OnClick", function()
			frame:Hide()
			PanelTemplates_SetTab(parent, skillTab:GetID())
		end)
		self.skillTab = skillTab
	end

	if not self.tab then
		self.tab = CreateFrame("Button", "Artisan_PlannerTab", parent, "CharacterFrameTabButtonTemplate")
		self.tab:SetText("Planner")
		self.tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 116, 0)
		self.tab:SetID(2)
		self.tab:SetScript("OnClick", function()
			frame:Show()
			PanelTemplates_SetTab(parent, self.tab:GetID())
		end)
	end
	parent.numTabs = 2
	PanelTemplates_SetNumTabs(parent, parent.numTabs)

	if self.active then
		frame:Show()
		PanelTemplates_SetTab(parent, self.tab:GetID())
	else
		frame:Hide()
		PanelTemplates_SetTab(parent, skillTab:GetID())
	end
	self.active = false
end

function Planner:Close()
	CloseTradeSkill()
	frame:Hide()
end

function Planner:Open(pk, active)
	local prof = ns.getProfName(pk)
	if not prof then return end

	self.pk = pk
	self.active = active

	local opened = ns.openProfFrame(pk)
	if not opened then
		reparent(UIParent)
		frame:SetPoint("CENTER")
		frame:Show()
	end
end

ns.PlannerUI = Planner
