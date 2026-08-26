local _, ns = ...

local Planner = {
	pk = nil,
	active = false,
	frame = CreateFrame("Frame", "artisanPlanner", UIParent, "BackdropTemplate")
}

local function reparent(parent)
	Planner.frame:SetParent(parent)
	Planner.frame:ClearAllPoints()
end

function Planner:State()
	local state = ns.store.plans[self.pk]
	if not state then
		state = {
			wishlist = {},
			preferExisting = false,
			noAH = false,
		}
		ns.store.plans[self.pk] = state
	end
	state.wishlist = state.wishlist or {}
	return state
end

function Planner:Attach()
	local parent = TradeSkillFrame
	local name = GetTradeSkillLine()
	self.pk = ns.getProfKey(name)
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
	if self.Refresh and self.pk then self:Refresh() end
end

function Planner:Close()
	CloseTradeSkill()
	self.frame:Hide()
end

function Planner:Open(pk, active)
	local prof = ns.getProfName(pk)
	if not prof then return end

	self.pk = pk
	self.active = active

	local opened = ns.openProfFrame(pk)
	if not opened then
		reparent(UIParent)
		self.frame:SetPoint("CENTER")
		self.frame:Show()
		if self.Refresh then self:Refresh() end
	end
end

ns.PlannerUI = Planner
