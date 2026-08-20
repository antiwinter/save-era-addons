-- format.lua — shared plan formatter. Pure Lua, no WoW globals, so both the
-- emulator and the in-game engine render the SAME human-readable plan text.
-- Takes the structured plan from ns.Planner.BuildPlan and returns lines;
-- printing is left to the caller (print off-client, a chat frame in-game).
--
--   Lines(actions, materials, nameFn) -> { "PLAN", "item, count, from, to", ..., "BAG", ... }
--   Print(actions, materials, nameFn, printer)   printer defaults to print
--   nameFn(id) renders item ids (GetItemInfo in-game, world.item off-client)

local _, ns = ...

local ceil = math.ceil

-- Reproduces the prototype's original PLAN/BAG review text, one entry per line:
--   PLAN
--   <item>, <count>, <from>, <to>
--   BAG
--   <material>, <count>
local function Lines(actions, materials, nameFn)
	nameFn = nameFn or tostring
	local out = { "PLAN" }
	for _, ac in ipairs(actions) do
		out[#out + 1] = string.format("%s, %d, %d, %d", nameFn(ac.item), ceil(ac.count), ac.from, ac.to)
	end
	out[#out + 1] = "BAG"
	-- Stable ordering so review diffs are meaningful.
	local ids = {}
	for id in pairs(materials) do ids[#ids + 1] = id end
	table.sort(ids)
	for _, id in ipairs(ids) do
		out[#out + 1] = string.format("%s, %d", nameFn(id), ceil(materials[id]))
	end
	return out
end

local function Print(actions, materials, nameFn, printer)
	printer = printer or print
	for _, line in ipairs(Lines(actions, materials, nameFn)) do
		printer(line)
	end
end

ns.Format = { Lines = Lines, Print = Print }
