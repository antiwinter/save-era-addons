local addonName, ns = ...

-- core.lua — bootstrap + the craft engine. Session reads the world and crafts
-- directly through WoW globals; off-client those globals are supplied by
-- fake-wow/, so this exact file runs in both worlds with no host/deps seam.
-- Load order (see .toc): data/*.lua -> data -> planner -> format -> core -> ui -> debug.

ns.defaults = {
	plans = {}, -- prof key -> { prof, target, actions={{item,count,from,to,crafted}}, materials }
	debug = false,
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

-- The open trade-skill line's display name, or nil when nothing is open.
local function lineOpen()
	local name = GetTradeSkillLine()
	return name and name ~= "" and name ~= "UNKNOWN" and name or nil
end
ns.LineOpen = lineOpen

-- The trade-skill window must show the line `key`'s data belongs to. Window
-- names are localized; FindProfName resolves `key` to them the same way.
-- Returns true when the right window is already up, else opens it.
local function OpenLine(key)
	local open = lineOpen()
	local pname = FindProfName(key)
	if open == pname then return true end
	if pname then
		CastSpellByName(pname)
		return false, open and ("Switching to " .. key) or ("Opening " .. key)
	end
	return false, "Learn " .. key .. " first"
end

-- ---- Session: the craft engine --------------------------------------------
-- Session holds per-session view state (active plan + live skill line). The
-- plan itself lives in ns.plans (SavedVariables); its `crafted` counters are
-- the single source of progress, so a relog resumes exactly where craft left
-- off. The data key ("eng") is the only stable identifier throughout — the
-- localized name is derived from it, never the other way around.
local Session = {}
Session.__index = Session

function Session.new()
	return setmetatable({
		plan = nil, -- reference into ns.plans; nil until the player picks one
		skill = { name = "", lvl = 0, cap = 0 },
	}, Session)
end

function Session:Select(prof)
	self.plan = ns.plans[prof]
end

function Session:RefreshSkill()
	local name, _, rank, maxRank = GetTradeSkillLine()
	if name and name ~= "" and name ~= "UNKNOWN" then
		self.skill.name, self.skill.lvl, self.skill.cap = name, rank, maxRank
	end
end

-- Oldest action that still needs crafts. An action is done once its count is
-- crafted OR the live skill outran its range (lucky rolls overshoot the plan);
-- both signals must stay or a stalled plan would look done / over-craft.
function Session:CurrentAction()
	local p = self.plan
	if not p then return nil end
	for _, ac in ipairs(p.actions) do
		if ac.crafted < ac.count and self.skill.lvl < ac.to then
			return ac
		end
	end
	return nil
end

function Session:LearnScroll(itemId)
	local name = GetItemInfo(itemId) or itemId
	local db = ns.db[self.plan.prof]
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

function Session:DoAction()
	local p = self.plan
	if not p then return "No plan — /skm plan <prof> [target]" end
	local ok, msg = OpenLine(p.prof)
	if not ok then return msg .. ", click again" end
	self:RefreshSkill()

	local ac = self:CurrentAction()
	if not ac then
		if self.skill.lvl >= p.target then
			return p.prof .. " reached " .. self.skill.lvl .. " — done"
		end
		return "Plan done — re-run /skm plan " .. p.prof .. " " .. p.target
	end

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
		local db = ns.db[p.prof]
		local r = db and db[ac.item]
		if r and r.teach_id and r.teach_id > 0 then
			local smsg = self:LearnScroll(ac.item)
			if smsg then return smsg end
			return "Recipe not learned (scroll missing): " .. want
		end
		return "Go to trainer and learn: " .. want
	end

	-- One click crafts at most the plan count still owed, and never past the
	-- skill range the planner put the batch in. Progress is measured from the
	-- bag, not the batch: a short craft (reagents ran out) must not look done.
	local batch = math.max(1, math.min(math.ceil(ac.count - ac.crafted), ac.to - self.skill.lvl))
	local before = GetItemCount(ac.item)
	DoTradeSkill(index, batch)
	local made = (GetItemCount(ac.item) - before) / (ns.db[p.prof][ac.item].craft_count or 1)
	ac.crafted = ac.crafted + made
	return string.format("Crafting %s x%d (+%d/%d)", ac.item, batch, ac.crafted, math.ceil(ac.count))
end

-- Event entrypoints, fired by the event frame below (and, in-game, by real
-- TRADE_SKILL_UPDATE; off-client by fake-wow's DoTradeSkill).
function Session:OnTradeSkillUpdate()
	self:RefreshSkill()
	if self.pending then
		local p = self.pending
		self.pending = nil
		local ok, msg = ns.CreatePlan(p.prof, p.target, true)
		if ns.OnPlan then ns.OnPlan(ok, msg) end
	end
	if ns.OnSessionUpdate then ns.OnSessionUpdate() end
end

-- Build a persistent plan for `key` covering the journey from the CURRENT
-- skill line to target (no arg = line cap), so crafted=0 always means "about
-- to begin". Needs the right window up; the first call opens it and defers
-- the build to the TRADE_SKILL_SHOW it triggers (retry marks that call).
function ns.CreatePlan(prof, target, retry)
	local db = ns.db[prof]
	if not db then return false, "No data for " .. prof end
	local ok, msg = OpenLine(prof)
	if not ok then
		if retry then return false, msg end
		ns.Session.pending = { prof = prof, target = target }
		return false, msg .. "..."
	end
	local _, _, lvl, cap = GetTradeSkillLine()
	target = target or cap
	local actions, materials = ns.Planner.BuildPlan(db, { start = lvl, target = target })
	local plan = { prof = prof, target = target, actions = {}, materials = materials }
	for _, ac in ipairs(actions) do
		ac.crafted = 0
		plan.actions[#plan.actions + 1] = ac
	end
	ns.plans[prof] = plan
	ns.Session:Select(prof)
	return true, string.format("%s: %d -> %d, %d actions", prof, lvl, target, #plan.actions)
end

ns.NewSession = Session.new

-- ---- Bootstrap: SavedVariables + session + event frame ---------------------
-- Built inside ADDON_LOADED so every .toc file (data, planner, ui callback) has
-- loaded before the session wires up. No .toc reorder needed.
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
		ns.plans = skillMasterDB.plans
		ns.Session = Session.new()
	else
		if ns.Session then ns.Session:OnTradeSkillUpdate() end
	end
end)