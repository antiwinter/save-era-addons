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

-- Data key -> localized skill-line name for CastSpellByName; ranks the
-- player hasn't trained may read as nil, so probe all four.
local function FindProfName(key)
	local ids = profs[key]
	if not ids then return nil end
	for _, sid in ipairs(ids) do
		local name = GetSpellInfo(sid)
		if name then return name end
	end
end
ns.FindProfName = FindProfName

-- ---- Runtime: the craft engine -------------------------------------------
local Runtime = {}
Runtime.__index = Runtime

function Runtime.new()
	return setmetatable({
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

function Runtime:LearnScroll(itemId)
	local name = GetItemInfo(itemId) or itemId
	local db = ns.db[self:ProfKey()]
	local r = db and db[itemId]
	if not r or not r.teach_id or r.teach_id <= 0 then return nil end
	local tid = r.teach_id
	for b = 0, 4 do
		for slot = 1, (GetContainerNumSlots(b) or 0) do
			if GetContainerItemID(b, slot) == tid then
				UseContainerItem(b, slot)
				return "Learned " .. name .. ", craft again"
			end
		end
	end
	return "Need scroll (id " .. tid .. ") to learn " .. name
end

function Runtime:DoAction()
	local name = self.skill.name
	if not name or name == "" then
		local openName = GetTradeSkillLine()
		if not openName or openName == "UNKNOWN" then
			local prof = self:ProfKey() or (ns.cfg and ns.cfg.profession)
			local pname = FindProfName(prof)
			if pname then
				CastSpellByName(pname)
				return "Opening " .. (prof or "profession") .. " window, click again"
			end
			return "Learn the profession first, then click again"
		end
		self.skill.name = openName
		name = openName
	end

	local ac = self:CurrentAction()
	if not ac then return "Plan complete" end

	-- The window reports localized names; the plan is id-keyed, so resolve the
	-- crafted item's name the same way the client does (GetItemInfo(id)).
	local want = GetItemInfo(ac.item) or ac.item
	local index
	for i = 1, GetNumTradeSkills() do
		local n, kind = GetTradeSkillInfo(i)
		if n == want and kind and kind ~= "header" then
			index = i
			break
		end
	end

	if not index then
		local db = ns.db[self:ProfKey()]
		local r = db and db[ac.item]
		if r and r.teach_id and r.teach_id > 0 then
			local smsg = self:LearnScroll(ac.item)
			if smsg then return smsg end
			return "Recipe not learned (scroll missing): " .. want
		end
		return "Go to trainer and learn: " .. want
	end

	local batch = math.max(1, math.min(math.ceil(ac.count), ac.to - self.skill.lvl))
	DoTradeSkill(index, batch)
	return string.format("Crafting %s x%d", ac.item, batch)
end

-- Event entrypoints, fired by the event frame below (and, in-game, by real
-- TRADE_SKILL_UPDATE; off-client by fake-wow's DoTradeSkill).
function Runtime:OnTradeSkillUpdate()
	self:RefreshSkill()
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
f:SetScript("OnEvent", function(_, event, arg1)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		skillMasterDB = skillMasterDB or {}
		for k, v in pairs(ns.defaults) do
			if skillMasterDB[k] == nil then skillMasterDB[k] = v end
		end
		ns.cfg = skillMasterDB
		ns.Runtime = Runtime.new()
	else
		if ns.Runtime then ns.Runtime:OnTradeSkillUpdate() end
	end
end)
