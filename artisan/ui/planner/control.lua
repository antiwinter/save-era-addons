local _, ns = ...

local pm = ns.pm
local function reparent(parent)
	pm.frame:SetParent(parent)
	pm.frame:ClearAllPoints()
end

function pm:Attach()
	local parent = TradeSkillFrame
	local name = GetTradeSkillLine()
	local pk = ns.getProfKey(name)
	pm:load(pk)
	reparent(parent)
	self.frame:SetPoint("TOPLEFT", parent, "TOPLEFT", 8, -42)
	self.frame:SetPoint("BOTTOMRIGHT", parent, "BOTTOMRIGHT", -8, 8)

	local skillTab = self.skillTab
	if not skillTab then
		skillTab = CreateFrame("Button", "Artisan_SkillTab", parent, "CharacterFrameTabButtonTemplate")
		skillTab:SetText("Skill")
		skillTab:SetPoint("TOPLEFT", parent, "TOPLEFT", 40, 0)
		skillTab:SetID(1)
		skillTab:SetScript("OnClick", function()
			self.frame:Hide()
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
			self.frame:Show()
			PanelTemplates_SetTab(parent, self.tab:GetID())
		end)
	end
	parent.numTabs = 2
	PanelTemplates_SetNumTabs(parent, parent.numTabs)

	if self.active then
		self.frame:Show()
		PanelTemplates_SetTab(parent, self.tab:GetID())
	else
		self.frame:Hide()
		PanelTemplates_SetTab(parent, skillTab:GetID())
	end
	self.active = false
end

function pm:Close()
	CloseTradeSkill()
	self.frame:Hide()
end

function pm:Open(pk, active)
	self.active = active
	if not self:load(pk) then self.active = false; return end
	local opened = ns.openProfFrame(pk)
	if not opened then
		reparent(UIParent)
		self.frame:SetPoint("CENTER")
		self.frame:Show()
	end
	return true
end
