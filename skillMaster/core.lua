local addonName, ns = ...

local Session = {}
Session.__index = Session

function ns.CreateSession(plan)
	if not plan then return nil end
	return setmetatable({ plan = plan }, Session)
end

function Session:CurrentAction()
	local _, _, lvl = ns.openProfWindow()
	if not lvl then return nil end
	for _, action in ipairs(self.plan.actions) do
		if lvl < action.to then return action end
	end
end

function Session:DoAction()
	local prof, _, lvl, cap = ns.openProfWindow()
	if not lvl then return ns.hint("Learn " .. self.plan.pk .. " first") end
	if lvl >= cap and lvl < self.plan.target then
		return ns.hint("Train the next " .. self.plan.pk .. " rank")
	end

	local action = self:CurrentAction()
	if not action then
		return ns.hint("Done")
	end

	local batch = math.max(1, math.min(math.ceil(action.count), action.to - lvl))
	ns.disable()
	local ok = ns.craft(action.item, batch)
	if not ok then -- try learn scroll
		ns.learnScrollFor(action.item)
		ns.enable()
	end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
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
	if event == "UPDATE_TRADESKILL_RECAST" and GetTradeskillRepeatCount() == 0 then
		ns.enable()
	elseif event == "TRADE_SKILL_CLOSE" then
		ns.enable()
	elseif (event == "UNIT_SPELLCAST_INTERRUPTED" or event == "UNIT_SPELLCAST_FAILED")
		and arg1 == "player" then
		ns.enable()
	end
end)
