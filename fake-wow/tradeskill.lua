local function install(env, world)
	world.skill = world.skill or { name = "", lvl = 1, cap = 1 }
	world.bag = world.bag or setmetatable({}, { __index = function() return 0 end })
	world.crafts = world.crafts or 0
	world.repeatCount = world.repeatCount or 0

	local dir = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or ".") .. "/"
	local db

	local function skillId(index)
		local skill = db:GetSkill(world.skill.pk, index)
		if not skill then return nil end
		local sid = skill.id
		if world.learned[sid] or skill.scroll_id <= 0 then return sid end
	end

	local function OpenProfWindow(pk)
		local profession = db:GetProfession(pk)
		if not profession then return end
		local state = world.profSkill[pk] or { lvl = 1, cap = 300 }
		world.profSkill[pk] = state
		world.skill = { pk = pk, name = profession.name, lvl = state.lvl, cap = state.cap }
		env.__fire("TRADE_SKILL_SHOW")
		env.__fire("TRADE_SKILL_UPDATE")
	end

	local function craftOne(sid)
		local skill = db:GetSkillById(sid)
		if not skill or world.skill.lvl < skill.colors[1] then return false end
		local recipe = db:GetRecipe(sid)
		for _, reagent in ipairs(recipe) do
			while world.bag[reagent.id] < reagent.count do
				local sub = db:GetSkillById(reagent.id)
				if not sub or (sub.scroll_id > 0 and not world.learned[sub.id]) then return false end
				if not craftOne(sub.id) then return false end
			end
		end
		for _, reagent in ipairs(recipe) do
			world.bag[reagent.id] = world.bag[reagent.id] - reagent.count
		end
		world.bag[sid] = world.bag[sid] + (skill.craft_count or 1)
		local roll = math.random(100)
		local up = (world.skill.lvl < skill.colors[2] and roll <= 100)
			or (world.skill.lvl < skill.colors[3] and roll <= 75)
			or (world.skill.lvl < skill.colors[4] and roll <= 25)
			or false
		if up then
			world.skill.lvl = world.skill.lvl + 1
			world.profSkill[world.skill.pk].lvl = world.skill.lvl
		end
		world.crafts = world.crafts + 1
		return true
	end

	function env.GetTradeSkillLine()
		local skill = world.skill
		return skill.name, nil, skill.lvl, skill.cap
	end

	function env.GetNumTradeSkills()
		return world.skill.pk and db:GetSkillCount(world.skill.pk) or 0
	end

	function env.GetTradeSkillInfo(index)
		local sid = skillId(index)
		if not sid then return nil end
		local item = db:GetItem(sid)
		return item and item.name, "optimal"
	end

	function env.GetTradeSkillNumReagents(index)
		local sid = skillId(index)
		return sid and #db:GetRecipe(sid) or 0
	end

	function env.GetTradeSkillReagentInfo(index, reagentIndex)
		local sid = skillId(index)
		if not sid then return nil end
		local reagent = db:GetRecipe(sid)[reagentIndex]
		if not reagent then return nil end
		local item = db:GetItem(reagent.id)
		return item and item.name, nil, reagent.count
	end

	function env.GetItemInfo(id)
		local item = db:GetItem(id)
		return item and item.name
	end

	function env.GetItemCount(id)
		return world.bag[id] or 0
	end

	function env.GetTradeskillRepeatCount()
		return world.repeatCount
	end

	function env.GetNumSkillLines()
		return 0
	end

	function env.GetSkillLineInfo()
		return nil
	end

	function env.GetSpellInfo(spellId)
		local profession = db:FindProfessionBySpellId(spellId)
		return profession and profession.name
	end

	function env.DoTradeSkill(index, batch)
		local sid = skillId(index)
		world.repeatCount = batch or 1
		env.__fire("UPDATE_TRADESKILL_RECAST")
		for _ = 1, world.repeatCount do
			if not sid or not craftOne(sid) then break end
		end
		env.__fire("TRADE_SKILL_UPDATE")
		env.__fire("BAG_UPDATE")
		env.__fire("BAG_UPDATE_DELAYED")
		world.repeatCount = 0
		env.__fire("UPDATE_TRADESKILL_RECAST")
	end

	function env.UseContainerItem(bag, slot)
		if bag ~= 0 then return end
		local id = env.GetContainerItemID(bag, slot)
		local skill = id and db:FindSkillByScrollId(id)
		if not skill then return end
		world.learned[skill.id] = true
		world.bag[id] = 0
		env.__fire("TRADE_SKILL_UPDATE")
		env.__fire("BAG_UPDATE")
		env.__fire("BAG_UPDATE_DELAYED")
	end

	function env.GetContainerNumSlots(bag)
		if bag ~= 0 then return 0 end
		local count = 0
		for _, amount in pairs(world.bag) do if amount > 0 then count = count + 1 end end
		return count
	end

	function env.GetContainerItemInfo(bag, slot)
		if bag ~= 0 then return nil end
		local index = 0
		for id, count in pairs(world.bag) do
			if count > 0 then
				index = index + 1
				if index == slot then
					local item = db:GetItem(id)
					return nil, count, nil, nil, nil, nil, item and item.name
				end
			end
		end
	end

	function env.GetContainerItemID(bag, slot)
		if bag ~= 0 then return nil end
		local index = 0
		for id, count in pairs(world.bag) do
			if count > 0 then
				index = index + 1
				if index == slot then return id end
			end
		end
	end

	local GM = env.GM

	function GM.LoadDB(dbPath)
		if db then db:Close() end
		db = dofile(dir .. "db.lua").load(dbPath)
		world.profSkill = {}
		world.learned = {}
		for _, pk in ipairs(db:ListProfessionKeys()) do
			local pk = pk
			local profession = db:GetProfession(pk)
			env.__registerSpell(profession.name, function() OpenProfWindow(pk) end)
		end
	end

	function GM:ListProfessions()
		return db:ListProfessionKeys()
	end

	function GM:ListSkills(pk)
		return db:ListSkills(pk)
	end

	function GM:ListProfSpells()
		return db:ListProfSpells()
	end

	function GM:GetRecipe(sid)
		return db:GetRecipe(sid)
	end

	function GM:GetPrice(id)
		local item = db:GetItem(id)
		return item and item.avgbuyout or 0
	end

	function GM.SetTradeSkillLine(name, lvl, cap)
		local profession = assert(db:FindProfession(name), "unknown profession " .. tostring(name))
		local pk = profession.pk
		world.profSkill[pk] = { lvl = lvl or 1, cap = cap or lvl or 1 }
		OpenProfWindow(pk)
	end

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
		if changed then env.__fire("BAG_UPDATE_DELAYED") end
	end

	function GM.ResetProgress()
		world.crafts = 0
	end
end

return { install = install }
