#!/usr/bin/env lua
-- tests/emu.lua — off-client driver for the REAL craft engine.
--
-- Instead of re-implementing crafting, this builds a simulated-world `host` and
-- drives the same ns.Runtime that ships in-game: it fires OnTradeSkillUpdate /
-- OnBagUpdate and clicks "DoAction" in a loop, exactly as the client does. So
-- plan progression, batch sizing, and DoAction are all exercised here.
--
-- Usage: ./tests/emu.lua [prof] [target] [start]   (run from the addon root)
--   run from the addon ROOT, not from tests/ — paths below are root-relative
--   prof   : eng | tailor    (default eng)
--   target : skill cap to reach (default 300)
--   start  : starting skill level (default 1)
-- The PLAN/BAG review text prints by default; set SKM_NOPLAN=1 to suppress it.

package.path = "./?.lua;" .. package.path

local DEBUG = os.getenv("SKM_DEBUG") == "1"
local function dbg(...) if DEBUG then print(string.format(...)) end end

local prof = arg[1] or "eng"
local target = tonumber(arg[2]) or 300
local startLvl = tonumber(arg[3]) or 1

dofile("data/" .. prof .. ".lua")
local raw = _G[prof .. "_data"]
assert(raw, "no data table for profession: " .. prof)

local NewDB = dofile("data.lua").NewDB
local db = NewDB(raw)
local BuildPlan = dofile("planner.lua").BuildPlan
local Format = dofile("format.lua")
local Runtime = dofile("runtime.lua")

math.randomseed(tonumber(os.getenv("SKM_SEED") or "") or os.time())

local PROF_NAME = { eng = "Engineering", tailor = "Tailoring" }

-- Simulated world: a bag, a skill level, and the recipe book. Implements the
-- same 4-method host interface the in-game glue provides. This is the ONLY
-- place craft mechanics (skill-up rolls, reagent consumption) live off-client.
local world = {
	skillName = PROF_NAME[prof] or prof,
	lvl = startLvl,
	cap = target,
	bag = setmetatable({}, { __index = function() return 0 end }),
	crafts = 0,
}

-- Recipe book keyed by name, mirroring GetTradeSkillInfo's index-based list.
local book, order = {}, {}
for i, r in ipairs(db.data) do
	book[r.name] = { name = r.name, recipe = r.recipe, index = i }
	order[i] = r.name
end

local host = {}
function host:ReadSkill() return world.skillName, world.lvl, world.cap end
function host:ReadRecipes() return book end
function host:ReadBag()
	local snap = {}
	for k, v in pairs(world.bag) do if v ~= 0 then snap[k] = v end end
	return snap
end

-- The mechanics the in-game DoTradeSkill would trigger: consume reagents (auto-
-- crafting any missing craftable sub-reagent), add output, roll for skill-up.
local function craftOne(name)
	local r = db[name]
	if not r or world.lvl < r.colors[1] then return false end
	for _, rg in ipairs(r.recipe or {}) do
		while world.bag[rg.name] < rg.count do
			if not db[rg.name] then return false end -- leaf material exhausted
			if not craftOne(rg.name) then return false end
		end
	end
	for _, rg in ipairs(r.recipe or {}) do
		world.bag[rg.name] = world.bag[rg.name] - rg.count
	end
	world.bag[r.name] = world.bag[r.name] + (r.craft_count or 1)
	local roll = math.random(100)
	local up = (world.lvl < r.colors[2] and roll <= 100)
		or (world.lvl < r.colors[3] and roll <= 75)
		or (world.lvl < r.colors[4] and roll <= 25)
		or false
	if up then world.lvl = world.lvl + 1 end
	world.crafts = world.crafts + 1
	return true
end

function host:Craft(index, batch)
	local name = order[index]
	for _ = 1, batch do
		if not craftOne(name) then break end
	end
end

-- Build the runtime with the simulated host + real planner/data.
local R = Runtime.new(host, {
	planner = BuildPlan,
	getDB = function() return db end,
	getCfg = function() return { target = target, phase = 3 } end,
})

-- Boot the engine the way the client does: trade window opens, then plan.
R:OnTradeSkillUpdate()
R:BuildPlan()

if os.getenv("SKM_NOPLAN") ~= "1" then
	Format.Print(R.plan, R.material)
	print()
end

-- Stock the bag with the planned shopping list, tracking budget, then re-scan.
local budget = 0
for name, count in pairs(R.material) do
	local c = math.ceil(count)
	world.bag[name] = c
	budget = budget + (db:price(name) or 0) * c
end
R:OnBagUpdate()

-- Drive: click "Craft next" until the plan is done or a craft makes no
-- progress. After each batch, fire the events the client would receive.
local start_lvl = world.lvl
local guard = 0
while world.lvl < target do
	local before = world.lvl
	local msg = R:DoAction()
	dbg("%s | lvl=%d idx=%d", msg, world.lvl, R.idx)
	if msg == "Plan complete" then break end
	R:OnTradeSkillUpdate() -- skill/recipe rescan after crafting
	R:OnBagUpdate()        -- bag changed
	guard = guard + 1
	if world.lvl == before and guard > 100000 then
		print("STALL: no progress"); break
	end
end

-- Tally leftover materials (waste) vs crafted value.
local remain_val = 0
for k, c in pairs(world.bag) do
	if c > 0 and not db[k] then remain_val = remain_val + (db:price(k) or 0) * c end
end

local ok = world.lvl >= target
local use_rate = budget > 0 and math.floor((budget - remain_val) / budget * 100) or 100

print(string.format("prof=%s  %d -> %d/%d  %s", prof, start_lvl, world.lvl, target, ok and "OK" or "SHORT"))
print(string.format("crafts=%d  budget=%.2fg  waste=%.2fg  use_rate=%d%%",
	world.crafts, budget / 10000, remain_val / 10000, use_rate))

os.exit(ok and 0 or 1)
