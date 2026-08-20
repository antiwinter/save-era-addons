local function install(env, world)
	world.skill = world.skill or { name = "", lvl = 1, cap = 1 }
	world.bag = world.bag or setmetatable({}, { __index = function() return 0 end })
	world.catalog = world.catalog or {} -- array: {id, recipe, colors, craft_count, learned, teach_id}
	world.item = world.item or {}       -- item id -> name
	world.price = world.price or {}     -- item id -> avgbuyout
	world.crafts = world.crafts or 0

	local byId = {} -- item id -> catalog row; setup-only

	-- db.lua is the single sqlite reader (sets up the vendor binding itself).
	local dir = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or ".") .. "/"

	local function find(id)
		return byId[id]
	end

	local function craftOne(r)
		if world.skill.lvl < r.colors[1] then return false end
		for _, rg in ipairs(r.recipe or {}) do
			while world.bag[rg.id] < rg.count do
				local sub = find(rg.id)
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
		return world.item[r.id], r.learned == 1 and "optimal" or "header"
	end

	function env.GetTradeSkillNumReagents(i)
		local r = world.catalog[i]
		return r and #(r.recipe or {}) or 0
	end

	function env.GetTradeSkillReagentInfo(i, j)
		local r = world.catalog[i]
		local rg = r and r.recipe and r.recipe[j]
		if not rg then return nil end
		return world.item[rg.id], nil, rg.count
	end

	function env.GetItemInfo(id)
		return world.item[id]
	end

	-- Skill-line / spell lookups: the sim only models the open tradeskill line,
	-- so the skill list is empty and spell names are unknown.
	function env.GetNumSkillLines()
		return 0
	end

	function env.GetSkillLineInfo()
		return nil
	end

	function env.GetSpellInfo()
		return nil
	end

	function env.DoTradeSkill(index, batch)
		local r = world.catalog[index]
		for _ = 1, (batch or 1) do
			if not r or not craftOne(r) then break end
		end
		env.__fire("TRADE_SKILL_UPDATE")
		env.__fire("BAG_UPDATE")
	end

	-- The addon finds the teaching item by id (locale-independent); a teach item
	-- click marks its recipe learned.
	function env.UseContainerItem(bag, slot)
		if bag ~= 0 then return end
		local id = env.GetContainerItemID(bag, slot)
		for _, r in ipairs(world.catalog) do
			if r.teach_id == id then
				r.learned = 1
				world.bag[id] = 0
				env.__fire("TRADE_SKILL_UPDATE")
				env.__fire("BAG_UPDATE")
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

	-- Load a versioned database into the world: catalog + names + prices. The
	-- raw schema is kept on world.schema for the GM query API below.
	function GM.LoadDB(dbPath)
		local data = dofile(dir .. "db.lua").load(dbPath)
		world.schema = data
		world.catalog = {}
		world.item = {}
		world.price = {}
		byId = {}
		for _, s in ipairs(data.skills) do
			local r = {
				id = s.id,
				recipe = {},
				colors = s.colors,
				craft_count = s.craft_count,
				learned = s.teach_id > 0 and 0 or 1,
				teach_id = s.teach_id,
			}
			world.catalog[#world.catalog + 1] = r
			byId[r.id] = r
		end
		for _, rc in ipairs(data.recipe) do
			local r = assert(byId[rc.skill_id])
			r.recipe[#r.recipe + 1] = { id = rc.reagent_id, count = rc.count }
		end
		for id, it in pairs(data.items) do
			world.item[id] = it.name
			world.price[id] = it.avgbuyout
		end
		env.__fire("TRADE_SKILL_UPDATE")
	end

	-- ---- GM schema queries (read-only windows onto world.schema) -------------
	function GM:ListProfessions()
		local seen, out = {}, {}
		for _, s in ipairs(world.schema.skills) do
			if not seen[s.prof] then
				seen[s.prof] = true
				out[#out + 1] = s.prof
			end
		end
		return out
	end

	-- learnedat order — the addon data emitter adopts it as the planner's level
	-- ordering (the field itself is not shipped).
	function GM:ListSkills(prof)
		local rows = {}
		for _, s in ipairs(world.schema.skills) do
			if s.prof == prof then rows[#rows + 1] = s end
		end
		table.sort(rows, function(a, b) return a.learnedat < b.learnedat end)
		return rows
	end

	function GM:GetRecipe(skill_id)
		local out = {}
		for _, r in ipairs(world.schema.recipe) do
			if r.skill_id == skill_id then out[#out + 1] = { id = r.reagent_id, count = r.count } end
		end
		return out
	end

	function GM:GetPrice(id)
		local it = world.schema.items[id]
		return it and it.avgbuyout or 0
	end

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

	-- Stock the bag by item id (see GM.LoadDB: ids come from the version db).
	function GM.SetBag(a, b)
		local changed = false
		if type(a) == "table" then
			for id, count in pairs(a) do
				world.bag[id] = count
				changed = true
			end
		else
			world.bag[a] = (world.bag[a] or 0) + (b or 0)
			changed = a ~= nil
		end
		if changed then env.__fire("BAG_UPDATE") end
	end

	function GM.ResetProgress()
		world.crafts = 0
	end
end

return { install = install }