local addonName, ns = ...

function CreateSession(plan)
	if not plan then return nil end
	return setmetatable({
		plan = plan,
	}, Session)
end

function Session:CurrentAction()
	for _, ac in ipairs(self.plan.actions) do
		if ac.crafted < ac.count and ns.skillLvl() < ac.to then
			return ac
		end
	end
	return nil
end

function Session:DoAction()
	local p = self.plan
	local ac = self:CurrentAction()
	if not ac then
		ns.hint('Done')
		return
	end

	-- The window reports localized names; the plan is id-keyed, so resolve the
	-- crafted item's name the same way the client does (GetItemInfo(id)).
	local want = GetItemInfo(ac.item) or ac.item
	local index = ns.skillIndex(ac.item)

	if not index then
		local sid, sname = ns.skillScroll(ac.item)
		if sid then
			ns.hint("Learn scroll: " .. sname)
			local ok = ns.learnScroll(sid)
			return
		end
		ns.hint("Go to trainer")
	end

	local batch = math.max(1, math.min(math.ceil(ac.count - ac.crafted), ac.to - ns.skillLvl()))
	ns.disable()
	ns.hint(want .. " x" .. batch)
	DoTradeSkill(index, batch)
end

-- ---- Bootstrap: SavedVariables + session + event frame ---------------------
-- Built inside ADDON_LOADED so every .toc file (data, planner, ui callback) has
-- loaded before the session wires up. No .toc reorder needed.
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_UPDATE")
f:RegisterEvent("BAG_UPDATE")
f:RegisterEvent("UNIT_SPELLCAST_INTERRUPTED")
f:RegisterEvent("skill_batch_done")
f:RegisterEvent("item_crafted")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		ns.store.init()
	else if event == "skill_batch_done" or event == "UNIT_SPELLCAST_INTERRUPTED" then
		ns.enable()
	else if event == "item_crafted" then
		ac = self.plan.actions.find(function(ac) return ac.item == arg1 end, self.plan.actions)
		ac = ac + 1
	end
end)
