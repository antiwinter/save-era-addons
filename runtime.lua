local addonName, ns = ...

-- runtime.lua — the in-client half of the prototype's `pf` object. Scans the
-- open trade-skill window and bags, tracks progress against a plan produced by
-- ns.Planner (planner.lua), and crafts the next batch on demand.
--
-- Crafting is ONE CLICK PER BATCH: ns.Runtime.DoAction is only ever called from
-- a player click (see ui.lua), so DoTradeSkill stays a hardware-initiated,
-- untainted action. No timers auto-fire crafts.

local R = {
	data = {},      -- recipe name -> scanned live recipe info (index, reagents)
	bag = nil,      -- item name -> count (metatable defaults to 0)
	plan = {},      -- ordered actions from the planner
	material = {},  -- shopping list from the planner
	idx = 1,
	skill = { name = "", lvl = 0, cap = 0 },
}
ns.Runtime = R

local function makeBag()
	return setmetatable({}, { __index = function() return 0 end })
end

function R:UpdateSkillInfo()
	local name, _, rank, maxRank = GetTradeSkillLine()
	if name and name ~= "UNKNOWN" then
		self.skill.name, self.skill.lvl, self.skill.cap = name, rank, maxRank
	end
end

function R:ScanTradeSkill()
	wipe(self.data)
	for i = 1, GetNumTradeSkills() do
		local name, kind = GetTradeSkillInfo(i)
		if kind and kind ~= "header" then
			local recipe = {}
			for j = 1, GetTradeSkillNumReagents(i) do
				local rname, _, rcount = GetTradeSkillReagentInfo(i, j)
				recipe[#recipe + 1] = { name = rname, count = rcount }
			end
			self.data[name] = { name = name, recipe = recipe, index = i }
		end
	end
end

function R:ScanBags()
	self.bag = makeBag()
	for bag = 0, 4 do
		for slot = 1, (GetContainerNumSlots(bag) or 0) do
			local _, count, _, _, _, _, link = GetContainerItemInfo(bag, slot)
			if link then
				local name = GetItemInfo(link)
				if name then self.bag[name] = self.bag[name] + count end
			end
		end
	end
end

-- Build a plan for the currently open profession using the shared planner.
function R:BuildPlan()
	local db = ns.db and ns.db[self:ProfKey()]
	if not db then return false, "No data for " .. (self.skill.name or "?") end
	self.plan, self.material = ns.Planner.BuildPlan(db, {
		start = 1,
		target = ns.cfg.target or self.skill.cap,
		phase = ns.cfg.phase,
		wishlist = ns.cfg.wishlist,
	})
	self.idx = 1
	return true
end

-- Map the live trade-skill name to a data key (ns.db.eng / ns.db.tailor / ...).
local PROF_KEY = {
	Engineering = "eng",
	Tailoring = "tailor",
}
function R:ProfKey()
	return PROF_KEY[self.skill.name]
end

function R:CurrentAction()
	return self.plan[self.idx]
end

-- Craft the next batch for the current action. Player-initiated only.
function R:DoAction()
	local ac = self:CurrentAction()
	if not ac then return "Plan complete" end
	local rec = self.data[ac.item]
	if not rec then return "Recipe not learned: " .. ac.item end

	-- Advance past finished actions relative to live skill level.
	while ac and self.skill.lvl >= ac.to do
		self.idx = self.idx + 1
		ac = self:CurrentAction()
	end
	if not ac then return "Plan complete" end

	local remaining = math.ceil(ac.count)
	local batch = math.max(1, math.min(remaining, ac.to - self.skill.lvl))
	DoTradeSkill(rec.index, batch)
	return string.format("Crafting %s x%d", ac.item, batch)
end

local f = CreateFrame("Frame")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_UPDATE")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function(_, event)
	if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
		R:UpdateSkillInfo()
		R:ScanTradeSkill()
		if ns.OnRuntimeUpdate then ns.OnRuntimeUpdate() end
	elseif event == "BAG_UPDATE" then
		R:ScanBags()
		if ns.OnRuntimeUpdate then ns.OnRuntimeUpdate() end
	end
end)
