local _, ns = ...

local pm = ns.pm
local function attachPlanner(parent)
	pm.frame:SetParent(UIParent)
	pm.frame:ClearAllPoints()
	pm.frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 8, 0)
	pm.frame:SetSize(492, 628)
end

function pm:Attach()
	local parent = TradeSkillFrame
	local name = GetTradeSkillLine()
	local pk = ns.getProfKey(name)
	pm:load(pk)
	attachPlanner(parent)

	local arrow = self.arrow
	if not arrow then
		arrow = CreateFrame("Button", "Artisan_PlannerArrow", parent)
		arrow:SetSize(32, 32)
		arrow:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Up")
		arrow:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Down")
		arrow:SetHighlightTexture("Interface\\Buttons\\UI-SpellbookIcon-NextPage-Highlight")
		arrow:SetScript("OnClick", function()
			if self.frame:IsShown() then self.frame:Hide() else self.frame:Show() end
		end)
		self.arrow = arrow
	end
	arrow:ClearAllPoints()
	arrow:SetPoint("LEFT", parent, "RIGHT", 0, 0)
	arrow:Show()

	if self.active then
		self.frame:Show()
	else
		self.frame:Hide()
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
