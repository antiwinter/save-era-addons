-- tests/emu.lua — off-client Monte Carlo evaluator.
--
-- Replays a plan against a simulated bag with random skill-up rolls, using the
-- SAME db + planner that ship in-game. Reports whether the plan reaches target
-- and how efficiently it spends materials.
--
-- Usage: lua tests/emu.lua [prof] [target]      (run from the addon root)
--   prof   : eng | tailor    (default eng)
--   target : skill cap to reach (default 300)

package.path = "./?.lua;" .. package.path

local DEBUG = os.getenv("SKM_DEBUG") == "1"
local function dbg(...) if DEBUG then print(string.format(...)) end end

-- Load shared data + planner exactly as the addon does, minus the .toc.
local prof = arg[1] or "eng"
local target = tonumber(arg[2]) or 300

dofile("data/" .. prof .. ".lua")
local raw = _G[prof .. "_data"]
assert(raw, "no data table for profession: " .. prof)

local NewDB = dofile("data.lua").NewDB
local db = NewDB(raw)
local BuildPlan = dofile("planner.lua").BuildPlan

local actions, materials = BuildPlan(db, { start = 1, target = target, phase = 3 })

-- Simulated bag: defaults missing items to 0.
local bag = setmetatable({}, { __index = function() return 0 end })
local lvl = 1

-- Craft one `name`, recursively crafting missing craftable reagents. Returns
-- false if a reagent leaf is short (would be bought in-game) or skill too low.
local function try_recipe(name)
	local r = db[name]
	if not r then return false end
	if lvl < r.colors[1] then return false end
	for _, rg in ipairs(r.recipe or {}) do
		while bag[rg.name] < rg.count do
			if not db[rg.name] then return false end -- leaf material exhausted
			if not try_recipe(rg.name) then return false end
		end
	end
	for _, rg in ipairs(r.recipe or {}) do
		bag[rg.name] = bag[rg.name] - rg.count
	end
	bag[r.name] = bag[r.name] + (r.craft_count or 1)
	local roll = math.random(100)
	local up = (lvl < r.colors[2] and roll <= 100)
		or (lvl < r.colors[3] and roll <= 75)
		or (lvl < r.colors[4] and roll <= 25)
		or false
	if up then lvl = lvl + 1 end
	return true
end

math.randomseed(tonumber(os.getenv("SKM_SEED") or "") or os.time())

-- Stock the simulated bag with the planned shopping list, tracking budget.
local budget = 0
for name, count in pairs(materials) do
	local c = math.ceil(count)
	bag[name] = c
	budget = budget + (db:price(name) or 0) * c
end

lvl = actions[1] and actions[1].from or 1
local start_lvl = lvl
local total_crafts = 0

for _, ac in ipairs(actions) do
	dbg("AC [%s]x%d [%d,%d]", ac.item, math.ceil(ac.count), ac.from, ac.to)
	local crafted = 0
	while crafted < math.ceil(ac.count) and lvl < ac.to do
		if not try_recipe(ac.item) then break end
		crafted = crafted + 1
		total_crafts = total_crafts + 1
	end
end

-- Tally leftover materials (waste) vs crafted value.
local remain_val, crafted_val = 0, 0
for k, c in pairs(bag) do
	if c > 0 then
		local p = db:price(k) or 0
		if db[k] then crafted_val = crafted_val + p * c else remain_val = remain_val + p * c end
	end
end

local ok = lvl >= target
local use_rate = budget > 0 and math.floor((budget - remain_val) / budget * 100) or 100

print(string.format("prof=%s  %d -> %d/%d  %s", prof, start_lvl, lvl, target, ok and "OK" or "SHORT"))
print(string.format("crafts=%d  budget=%.2fg  waste=%.2fg  use_rate=%d%%",
	total_crafts, budget / 10000, remain_val / 10000, use_rate))

os.exit(ok and 0 or 1)
