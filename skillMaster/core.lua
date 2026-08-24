local addonName, ns = ...

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

function Session:DoAction()
	local p = self.plan
	if not p then return "No plan — /skm plan <prof> [target]" end
	local ok, msg = openProfWindow(p.prof)
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
			local s = ns.learnScroll(r.teach_id)
			if s then return "Recipe learned: " .. s else
				return "Recipe not learned (scroll missing): " .. want
			end
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

function ns.CreatePlan(prof, target, retry)
	local db = ns.db[prof]
	if not db then return false, "No data for " .. prof end
	openProfWindow(prof)
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
		skillMasterDB = skillMasterDB or {plans={}}
		ns.plans = skillMasterDB.plans
		ns.Session = Session.load(skillMasterDB.prof)
	else
		if ns.Session then ns.Session:OnTradeSkillUpdate() end
	end
end)