local _, ns = ...

local Planner = { pk = nil }
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

function Planner:Attach(active)
	local parent = TradeSkillFrame
	reparent(parent)
	frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -42)
	frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)

	if not self.tab then
		self.tab = CreateFrame("Button", "Artisan_PlannerTab", parent, "CharacterFrameTabButtonTemplate")
		self.tab:SetText("Planner")
		self.tab:SetPoint("TOPLEFT", parent, "TOPLEFT", 116, 0)
		self.tab:SetScript("OnClick", function() self:Select() end)
		local tabId = (parent.numTabs or 1) + 1
		parent.numTabs = tabId
		PanelTemplates_SetNumTabs(parent, tabId)
		self.tab:SetID(tabId)
	end
	if active then
		PanelTemplates_SetTab(parent, self.tab:GetID())
	end
end

function Planner:Select()
end

function Planner:Close()
	if frame:GetParent() == TradeSkillFrame then
		CloseTradeSkill()
	end
	frame:Hide()
end

function Planner:Open(pk, active)
	local prof = ns.getProfName(pk)
	if not prof then return end

	self.pk = pk

	local opened = ns.openProfFrame(pk)
	if opened then
		self:Attach(active)
	else
		reparent(UIParent)
		frame:SetPoint("CENTER")
	end
	frame:Show()
end

ns.PlannerUI = Planner
