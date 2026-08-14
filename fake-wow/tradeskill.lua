-- tradeskill.lua — the simulated game world for trade-skill leveling plus the
-- WoW C-APIs skillMaster reads. This is where craft *mechanics* live off-client:
-- skill-up rolls, recursive sub-reagent crafting, reagent consumption. In-game
-- these are the client's job; here they are ours.
--
-- Installs into the shared world table (see init.lua) and registers its globals
-- through the passed `env`. Kept separate from client.lua so the generic client
-- shell stays reusable by other addons that don't touch trade skills.

local function install(env, world)
	-- world holds all mutable sim state; GM.* mutates it, C-APIs read it.
	world.skill = world.skill or { name = "", lvl = 1, cap = 1 }
	world.bag = world.bag or setmetatable({}, { __index = function() return 0 end })
	world.book = world.book or {}   -- name -> { name, recipe, index, ... }
	world.order = world.order or {} -- index -> name (mirrors GetTradeSkillInfo)
	world.crafts = world.crafts or 0

	-- Look up the raw recipe record (with colors/craft_count) behind a book entry.
	local function rec(name) return world.book[name] end

	-- One craft: auto-produce missing craftable sub-reagents, consume reagents,
	-- add output, roll for a skill-up. Returns false if it can't proceed (recipe
	-- not learnable yet or a leaf material is exhausted).
	local function craftOne(name)
		local r = rec(name)
		if not r or world.skill.lvl < r.colors[1] then return false end
		for _, rg in ipairs(r.recipe or {}) do
			while world.bag[rg.name] < rg.count do
				if not rec(rg.name) then return false end -- leaf material exhausted
				if not craftOne(rg.name) then return false end
			end
		end
		for _, rg in ipairs(r.recipe or {}) do
			world.bag[rg.name] = world.bag[rg.name] - rg.count
		end
		world.bag[r.name] = world.bag[r.name] + (r.craft_count or 1)
		local roll = math.random(100)
		local up = (world.skill.lvl < r.colors[2] and roll <= 100)
			or (world.skill.lvl < r.colors[3] and roll <= 75)
			or (world.skill.lvl < r.colors[4] and roll <= 25)
			or false
		if up then world.skill.lvl = world.skill.lvl + 1 end
		world.crafts = world.crafts + 1
		return true
	end

	-- ---- Trade-skill C-API -------------------------------------------------
	function env.GetTradeSkillLine()
		local s = world.skill
		return s.name, nil, s.lvl, s.cap
	end

	function env.GetNumTradeSkills()
		return #world.order
	end

	function env.GetTradeSkillInfo(i)
		local name = world.order[i]
		if not name then return nil end
		return name, "optimal" -- kind: never "header" in the sim
	end

	function env.GetTradeSkillNumReagents(i)
		local r = rec(world.order[i])
		return r and #(r.recipe or {}) or 0
	end

	function env.GetTradeSkillReagentInfo(i, j)
		local r = rec(world.order[i])
		local rg = r and r.recipe and r.recipe[j]
		if not rg then return nil end
		return rg.name, nil, rg.count
	end

	-- The one mutating API: craft `batch` times, then fire the events the client
	-- would, so the addon's own event frame drives the refresh (same path as live).
	function env.DoTradeSkill(index, batch)
		local name = world.order[index]
		for _ = 1, (batch or 1) do
			if not craftOne(name) then break end
		end
		env.__fire("TRADE_SKILL_UPDATE")
		env.__fire("BAG_UPDATE")
	end

	-- ---- Container / item C-API (bag lives as name->count, one virtual bag) --
	function env.GetContainerNumSlots(bag)
		if bag ~= 0 then return 0 end
		local n = 0
		for _, c in pairs(world.bag) do if c > 0 then n = n + 1 end end
		return n
	end

	function env.GetContainerItemInfo(bag, slot)
		if bag ~= 0 then return nil end
		local i = 0
		for name, count in pairs(world.bag) do
			if count > 0 then
				i = i + 1
				if i == slot then
					-- returns: texture, count, ..., link  (link == name in the sim)
					return nil, count, nil, nil, nil, nil, name
				end
			end
		end
		return nil
	end

	function env.GetItemInfo(link) return link end
end

return { install = install }
