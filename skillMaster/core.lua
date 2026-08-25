local addonName, ns = ...

local Session = {}
Session.__index = Session

function ns.CreateSession(plan)
	if not plan then return nil end
	return setmetatable({ plan = plan }, Session)
end

function Session:ResovleAction()
	local _, _, lvl, cap = ns.openProfFrame()
	if not lvl then 
		ns.hint("Learn " .. self.plan.pk .. " first")
		return
	end

	if lvl >= cap and lvl < self.plan.target then
		ns.hint("Train the next " .. self.plan.pk .. " rank")
		return
	end

	for _, action in ipairs(self.plan.actions) do
		if lvl < action.to then
			local count = math.max(1, math.min(math.ceil(action.count), action.to - lvl))
			return action.item, count
		end
	end
	ns.hint("Done")
end

function Session:DoAction()
	local itemId, count = self:ResovleAction()
	if not itemId then return end
	ns.disable()
	local ok = ns.craft(itemId, count)
	if not ok then -- try learn scroll
		ns.learnScrollFor(itemId)
		ns.enable()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("UPDATE_TRADESKILL_RECAST")
frame:RegisterEvent("TRADE_SKILL_CLOSE")
frame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
frame:RegisterEvent("UNIT_SPELLCAST_FAILED")
frame:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		ns.store:init()
		ns.store:select(ns.store.cur_pk)
		return
	end
	if event == "TRADE_SKILL_SHOW" then
		if ns.PlannerUI then ns.PlannerUI:OnTradeSkillShow() end
		return
	end
	if event == "UPDATE_TRADESKILL_RECAST" and GetTradeskillRepeatCount() == 0 then
		ns.enable()
	elseif event == "TRADE_SKILL_CLOSE" then
		ns.enable()
	elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
		and arg1 == "player" then
		ns.enable()
	end
end)
