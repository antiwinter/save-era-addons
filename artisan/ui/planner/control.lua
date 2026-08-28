local _, ns = ...

local pm = ns.pm
local function attachPlanner(parent)
	pm.frame:SetParent(parent)
	pm.frame:ClearAllPoints()
	pm.frame:SetAllPoints(parent)
	pm.frame:SetFrameLevel(parent:GetFrameLevel() + 10)
end

function pm:Attach()
	local parent = TradeSkillFrame
	local name = GetTradeSkillLine()
	local pk = ns.getProfKey(name)
	pm:load(pk)
	attachPlanner(parent)

	local skillTab = self.skillTab
	if not skillTab then
		skillTab = CreateFrame("Button", "Artisan_SkillTab", parent, "CharacterFrameTabButtonTemplate")
		skillTab:SetText("Skill")
		skillTab:SetID(1)
		skillTab:SetScript("OnClick", function()
			self.frame:Hide()
			PanelTemplates_SetTab(parent, skillTab:GetID())
		end)
		self.skillTab = skillTab
	end
	skillTab:ClearAllPoints()
	skillTab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 40, 76)
	skillTab:Show()

	local plannerTab = self.tab
	if not plannerTab then
		plannerTab = CreateFrame("Button", "Artisan_PlannerTab", parent, "CharacterFrameTabButtonTemplate")
		plannerTab:SetText("Plan")
		plannerTab:SetID(2)
		plannerTab:SetScript("OnClick", function()
			self.frame:Show()
			PanelTemplates_SetTab(parent, plannerTab:GetID())
		end)
		self.tab = plannerTab
	end
	plannerTab:ClearAllPoints()
	plannerTab:SetPoint("TOPLEFT", parent, "BOTTOMLEFT", 100, 76)
	plannerTab:Show()

	parent.Tabs = parent.Tabs or {}
	parent.Tabs[1] = skillTab
	parent.Tabs[2] = plannerTab
	parent.numTabs = 2
	PanelTemplates_SetNumTabs(parent, parent.numTabs)

	if self.active then
		self.frame:Show()
		PanelTemplates_SetTab(parent, plannerTab:GetID())
	else
		self.frame:Hide()
		PanelTemplates_SetTab(parent, skillTab:GetID())
	end
	self.active = false
end

function pm:Hide()
	self.frame:Hide()
	if self.arrow then self.arrow:Hide() end
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
		self.frame:SetParent(UIParent)
		self.frame:ClearAllPoints()
		self.frame:SetPoint("CENTER")
		self.frame:Show()
	end
	return true
end
