local addonName, ns = ...

-- core.lua — bootstrap + the craft engine (Runtime). Runtime reads the world and
-- crafts directly through WoW globals; off-client those globals are supplied by
-- fake-wow/, so this exact file runs in both worlds with no host/deps seam.
-- Load order (see .toc): data/*.lua -> data -> planner -> format -> core -> ui -> debug.

ns.defaults = {
	target = nil, -- nil => use the profession's max rank
	phase = 3,
	wishlist = {},
	debug = false,
}

-- Map the live trade-skill name to a data key (ns.db.eng / ns.db.tailor / ...).
local PROF_KEY = {
	Engineering = "eng",
	Tailoring = "tailor",
}

local function makeBag(src)
	local b = setmetatable({}, { __index = function() return 0 end })
	if src then for k, v in pairs(src) do b[k] = v end end
	return b
end

-- ---- Runtime: the craft engine -------------------------------------------
local Runtime = {}
Runtime.__index = Runtime

function Runtime.new()
	return setmetatable({
		data = {},          -- recipe name -> { name, recipe, index }
		bag = makeBag(),    -- item name -> count (defaults to 0)
		plan = {},          -- ordered actions from the planner
		material = {},      -- shopping list from the planner
		idx = 1,
		skill = { name = "", lvl = 0, cap = 0 },
	}, Runtime)
end

function Runtime:ProfKey()
	return PROF_KEY[self.skill.name]
end

function Runtime:RefreshSkill()
	local name, _, rank, maxRank = GetTradeSkillLine()
	if name and name ~= "UNKNOWN" then
		self.skill.name, self.skill.lvl, self.skill.cap = name, rank, maxRank
	end
end

function Runtime:RefreshRecipes()
	local data = {}
	for i = 1, GetNumTradeSkills() do
		local name, kind = GetTradeSkillInfo(i)
		if kind and kind ~= "header" then
			local recipe = {}
			for j = 1, GetTradeSkillNumReagents(i) do
				local rname, _, rcount = GetTradeSkillReagentInfo(i, j)
				recipe[#recipe + 1] = { name = rname, count = rcount }
			end
			data[name] = { name = name, recipe = recipe, index = i }
		end
	end
	self.data = data
end

function Runtime:RefreshBag()
	local bag = {}
	for b = 0, 4 do
		for slot = 1, (GetContainerNumSlots(b) or 0) do
			local _, count, _, _, _, _, link = GetContainerItemInfo(b, slot)
			if link then
				local name = GetItemInfo(link)
				if name then bag[name] = (bag[name] or 0) + count end
			end
		end
	end
	self.bag = makeBag(bag)
end

-- Build a plan for the currently open profession using the shared planner.
function Runtime:BuildPlan()
	local db = ns.db and ns.db[self:ProfKey()]
	if not db then return false, "No data for " .. (self.skill.name or "?") end
	local cfg = ns.cfg or {}
	self.plan, self.material = ns.Planner.BuildPlan(db, {
		start = 1,
		target = cfg.target or self.skill.cap,
		phase = cfg.phase,
		wishlist = cfg.wishlist,
	})
	self.idx = 1
	return true
end

-- Current action, advancing past any already finished relative to live skill.
function Runtime:CurrentAction()
	local ac = self.plan[self.idx]
	while ac and self.skill.lvl >= ac.to do
		self.idx = self.idx + 1
		ac = self.plan[self.idx]
	end
	return ac
end

-- Craft the next batch for the current action. Player/driver-initiated only.
function Runtime:DoAction()
	local ac = self:CurrentAction()
	if not ac then return "Plan complete" end
	local rec = self.data[ac.item]
	if not rec then return "Recipe not learned: " .. ac.item end
	local batch = math.max(1, math.min(math.ceil(ac.count), ac.to - self.skill.lvl))
	DoTradeSkill(rec.index, batch)
	return string.format("Crafting %s x%d", ac.item, batch)
end

-- Event entrypoints, fired by the event frame below (and, in-game, by real
-- TRADE_SKILL_UPDATE / BAG_UPDATE; off-client by fake-wow's DoTradeSkill).
function Runtime:OnTradeSkillUpdate()
	self:RefreshSkill()
	self:RefreshRecipes()
	if ns.OnRuntimeUpdate then ns.OnRuntimeUpdate() end
end

function Runtime:OnBagUpdate()
	self:RefreshBag()
	if ns.OnRuntimeUpdate then ns.OnRuntimeUpdate() end
end

ns.NewRuntime = Runtime.new

-- ---- Bootstrap: SavedVariables + runtime instance + event frame -----------
-- Built inside ADDON_LOADED so every .toc file (data, planner, ui callback) has
-- loaded before the runtime wires up. No .toc reorder needed.
local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("TRADE_SKILL_SHOW")
f:RegisterEvent("TRADE_SKILL_UPDATE")
f:RegisterEvent("BAG_UPDATE")
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		skillMasterDB = skillMasterDB or {}
		for k, v in pairs(ns.defaults) do
			if skillMasterDB[k] == nil then skillMasterDB[k] = v end
		end
		ns.cfg = skillMasterDB
		ns.Runtime = Runtime.new()
	elseif event == "BAG_UPDATE" then
		if ns.Runtime then ns.Runtime:OnBagUpdate() end
	else
		if ns.Runtime then ns.Runtime:OnTradeSkillUpdate() end
	end
end)
