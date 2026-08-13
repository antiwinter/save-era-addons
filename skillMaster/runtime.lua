local addonName, ns = ...

-- runtime.lua — the craft engine. DUAL-USE like planner.lua: this exact file
-- runs in-game AND under the off-client emulator. It reads the world and crafts
-- ONLY through an injected `host`, and reacts to events via OnTradeSkillUpdate /
-- OnBagUpdate. It touches NO WoW global itself.
--
--   in-game : the glue block at the bottom builds a host that wraps the real
--             GetTradeSkill*/GetContainer*/DoTradeSkill APIs and wires a
--             CreateFrame to fire the event entrypoints.
--   emu     : tests/emu.lua builds a simulated-world host and calls the same
--             entrypoints + DoAction, so plan progression and batch sizing are
--             exercised by the real engine.
--
-- Crafting stays ONE CLICK PER BATCH: DoAction runs only from a player click
-- (ui.lua) or the emu driver, so host:Craft -> DoTradeSkill is player-initiated.
--
-- host interface (4 methods):
--   host:ReadSkill()   -> name, lvl, cap
--   host:ReadRecipes() -> { [name] = { name, recipe={{name,count}...}, index } }
--   host:ReadBag()     -> { [name] = count }
--   host:Craft(index, batch)
-- deps: { planner=BuildPlan, getDB=fn(key)->db, getCfg=fn()->cfg, onUpdate=fn(R) }

local ns_ = ns -- nil under standalone lua

local function makeBag(src)
	local b = setmetatable({}, { __index = function() return 0 end })
	if src then for k, v in pairs(src) do b[k] = v end end
	return b
end

-- Map the live trade-skill name to a data key (ns.db.eng / ns.db.tailor / ...).
local PROF_KEY = {
	Engineering = "eng",
	Tailoring = "tailor",
}

local Runtime = {}
Runtime.__index = Runtime

function Runtime.new(host, deps)
	return setmetatable({
		host = host,
		deps = deps,
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
	local name, lvl, cap = self.host:ReadSkill()
	if name and name ~= "UNKNOWN" then
		self.skill.name, self.skill.lvl, self.skill.cap = name, lvl, cap
	end
end

function Runtime:RefreshRecipes()
	self.data = self.host:ReadRecipes()
end

function Runtime:RefreshBag()
	self.bag = makeBag(self.host:ReadBag())
end

-- Build a plan for the currently open profession using the shared planner.
function Runtime:BuildPlan()
	local db = self.deps.getDB(self:ProfKey())
	if not db then return false, "No data for " .. (self.skill.name or "?") end
	local cfg = (self.deps.getCfg and self.deps.getCfg()) or {}
	self.plan, self.material = self.deps.planner(db, {
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
	self.host:Craft(rec.index, batch)
	return string.format("Crafting %s x%d", ac.item, batch)
end

-- Event entrypoints. In-game: fired by the CreateFrame below. Emu: called by
-- the driver right after a craft to mimic TRADE_SKILL_UPDATE / BAG_UPDATE.
function Runtime:OnTradeSkillUpdate()
	self:RefreshSkill()
	self:RefreshRecipes()
	if self.deps.onUpdate then self.deps.onUpdate(self) end
end

function Runtime:OnBagUpdate()
	self:RefreshBag()
	if self.deps.onUpdate then self.deps.onUpdate(self) end
end

local M = { new = Runtime.new }

-- In-game glue: real-API host + event frame. Skipped under standalone lua
-- (no CreateFrame), so dofile('runtime.lua') stays clean for the emulator.
if ns_ and CreateFrame then
	local host = {}
	function host:ReadSkill()
		local name, _, rank, maxRank = GetTradeSkillLine()
		return name, rank, maxRank
	end
	function host:ReadRecipes()
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
		return data
	end
	function host:ReadBag()
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
		return bag
	end
	function host:Craft(index, batch)
		DoTradeSkill(index, batch)
	end

	local inst = Runtime.new(host, {
		planner = ns_.Planner.BuildPlan,
		getDB = function(key) return ns_.db and ns_.db[key] end,
		getCfg = function() return ns_.cfg end,
		onUpdate = function() if ns_.OnRuntimeUpdate then ns_.OnRuntimeUpdate() end end,
	})
	ns_.Runtime = inst

	local f = CreateFrame("Frame")
	f:RegisterEvent("TRADE_SKILL_SHOW")
	f:RegisterEvent("TRADE_SKILL_UPDATE")
	f:RegisterEvent("BAG_UPDATE")
	f:SetScript("OnEvent", function(_, event)
		if event == "BAG_UPDATE" then
			inst:OnBagUpdate()
		else
			inst:OnTradeSkillUpdate()
		end
	end)
end

return M
