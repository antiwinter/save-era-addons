
local function install(env, world)
	world.skill = world.skill or { name = "", lvl = 1, cap = 1 }
	world.bag = world.bag or setmetatable({}, { __index = function() return 0 end })
	world.catalog = world.catalog or {} -- array: {id, name, recipe, colors, craft_count, learned}
	world.item = world.item or {}       -- item id -> name (populated by SetBag)
	world.crafts = world.crafts or 0

	local nameToId = {} -- item name -> id; setup-only, for SetBag

	local function find(name)
		for _, r in ipairs(world.catalog) do
			if r.name == name then return r end
		end
		return nil
	end

	local function craftOne(r)
		if world.skill.lvl < r.colors[1] then return false end
		for _, rg in ipairs(r.recipe or {}) do
			while world.bag[rg.id] < rg.count do
				local sub = find(rg.name)
				if not sub or sub.learned ~= 1 then return false end
				if not craftOne(sub) then return false end
			end
		end
		for _, rg in ipairs(r.recipe or {}) do
			world.bag[rg.id] = world.bag[rg.id] - rg.count
		end
		world.bag[r.id] = world.bag[r.id] + (r.craft_count or 1)
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
		return #world.catalog
	end

	-- Unlearned recipes report kind "header" so the addon skips them; the slot
	-- index is the catalog array position, stable across learns.
	function env.GetTradeSkillInfo(i)
		local r = world.catalog[i]
		if not r then return nil end
		return r.name, r.learned == 1 and "optimal" or "header"
	end

	function env.GetTradeSkillNumReagents(i)
		local r = world.catalog[i]
		return r and #(r.recipe or {}) or 0
	end

	function env.GetTradeSkillReagentInfo(i, j)
		local r = world.catalog[i]
		local rg = r and r.recipe and r.recipe[j]
		if not rg then return nil end
		return rg.name, nil, rg.count
	end

	function env.DoTradeSkill(index, batch)
		local r = world.catalog[index]
		for _ = 1, (batch or 1) do
			if not r or not craftOne(r) then break end
		end
		env.__fire("TRADE_SKILL_UPDATE")
		env.__fire("BAG_UPDATE")
	end

	local TEACH_PREFIXES = { "Schematic: ", "Pattern: ", "Plans: ", "Plan: ",
		"Recipe: ", "Formula: ", "Design: ", "Blueprint: " }

	-- The addon finds the teaching item by id (locale-independent); here we parse
	-- its name to locate the recipe — sim-only, the data is English.
	function env.UseContainerItem(bag, slot)
		if bag ~= 0 then return end
		local id = env.GetContainerItemID(bag, slot)
		local name = world.item[id]
		if not name then return end
		for _, p in ipairs(TEACH_PREFIXES) do
			if name:sub(1, #p) == p then
				local r = find(name:sub(#p + 1))
				if r then
					r.learned = 1
					world.bag[id] = 0
					env.__fire("TRADE_SKILL_UPDATE")
					env.__fire("BAG_UPDATE")
				end
				return
			end
		end
	end

	-- ---- Container / item C-API (bag is id->count, one virtual bag) ----------
	function env.GetContainerNumSlots(bag)
		if bag ~= 0 then return 0 end
		local n = 0
		for _, c in pairs(world.bag) do if c > 0 then n = n + 1 end end
		return n
	end

	function env.GetContainerItemInfo(bag, slot)
		if bag ~= 0 then return nil end
		local i = 0
		for id, count in pairs(world.bag) do
			if count > 0 then
				i = i + 1
				if i == slot then
					return nil, count, nil, nil, nil, nil, world.item[id]
				end
			end
		end
		return nil
	end

	function env.GetItemInfo(link) return link end

	function env.GetContainerItemID(bag, slot)
		if bag ~= 0 then return nil end
		local i = 0
		for id, count in pairs(world.bag) do
			if count > 0 then
				i = i + 1
				if i == slot then return id end
			end
		end
		return nil
	end

	-- ---- GM console (test setup, NOT WoW APIs) -----------------------------
	local GM = env.GM

	function GM.SetTradeSkillLine(name, lvl, cap)
		world.skill.name = name
		world.skill.lvl = lvl or 1
		world.skill.cap = cap or lvl or 1
		env.__fire("TRADE_SKILL_UPDATE")
	end

	-- Open the trade-skill window — equivalent to the player clicking the
	-- tradeskill button. Fires TRADE_SKILL_SHOW so the addon's TRADE_SKILL_SHOW
	-- handler runs RefreshSkill.
	function GM.OpenTradeSkill()
		env.__fire("TRADE_SKILL_SHOW")
	end

	function env.CastSpellByID(id)
		env.__fire("TRADE_SKILL_SHOW")
	end

	-- Stock by item name: resolve name->id, store the count, and record the name
	-- so GetContainerItemInfo can return it (the addon's bag is name-keyed).
	function GM.SetBag(a, b)
		local changed = false
		if type(a) == "table" then
			for name, count in pairs(a) do
				local id = nameToId[name]
				if id then world.bag[id] = count; world.item[id] = name; changed = true end
			end
		else
			local id = nameToId[a]
			if id then
				world.bag[id] = (world.bag[id] or 0) + (b or 0)
				world.item[id] = a
				changed = true
			end
		end
		if changed then env.__fire("BAG_UPDATE") end
	end

	function GM.LoadRecipes(raw)
		world.catalog = {}
		world.item = {}
		nameToId = {}
		for _, r in ipairs(raw) do
			world.catalog[#world.catalog + 1] = {
				id = r.id, name = r.name, recipe = r.recipe,
				colors = r.colors, craft_count = r.craft_count,
				learned = (r.schem_id and r.schem_id > 0) and 0 or 1,
			}
			nameToId[r.name] = r.id
			for _, rg in ipairs(r.recipe or {}) do
				nameToId[rg.name] = rg.id
			end
			if r.schem_id and r.schem_id > 0 then
				for _, p in ipairs(TEACH_PREFIXES) do
					nameToId[p .. r.name] = r.schem_id
				end
			end
		end
		env.__fire("TRADE_SKILL_UPDATE")
	end

	function GM.ResetProgress()
		world.crafts = 0
	end
end

return { install = install }
