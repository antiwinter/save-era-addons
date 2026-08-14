-- gm.lua — the "game master" console for the emulator. These are NOT real WoW
-- APIs; they are the knobs a test/driver uses to set up the simulated world
-- before loading an addon: skill line, bag contents, the recipe book, rng seed.

local function install(env, world)
	local GM = {}

	-- Set the open trade-skill line the addon will read via GetTradeSkillLine.
	function GM.SetTradeSkillLine(name, lvl, cap)
		world.skill.name = name
		world.skill.lvl = lvl or 1
		world.skill.cap = cap or lvl or 1
	end

	-- Replace/patch bag contents. Passing a table sets counts by item name;
	-- name+count form adds a single stack.
	function GM.SetBag(a, b)
		if type(a) == "table" then
			for name, count in pairs(a) do world.bag[name] = count end
		else
			world.bag[a] = (world.bag[a] or 0) + (b or 0)
		end
	end

	-- Load a raw recipe array (as data/<prof>.lua emits) into the book, keyed by
	-- name and mirrored by index so GetTradeSkillInfo(i) works. Records keep their
	-- colors/craft_count fields so craft mechanics can read them.
	function GM.LoadRecipes(raw)
		world.book, world.order = {}, {}
		for i, r in ipairs(raw) do
			world.book[r.name] = {
				name = r.name, recipe = r.recipe, index = i,
				colors = r.colors, craft_count = r.craft_count,
			}
			world.order[i] = r.name
		end
	end

	function GM.SetSeed(seed) math.randomseed(seed) end

	-- Reset counters/skill between runs without dropping the loaded book.
	function GM.ResetProgress()
		world.crafts = 0
	end

	env.GM = GM
end

return { install = install }
