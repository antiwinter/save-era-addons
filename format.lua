-- format.lua — shared plan formatter. DUAL-USE like planner.lua: pure Lua, no
-- WoW globals, so both tests/emu.lua and the in-game engine render the SAME
-- human-readable plan text. Takes the structured plan from ns.Planner.BuildPlan
-- and returns lines; printing is left to the caller (print off-client, a chat
-- frame in-game).
--
--   Lines(actions, materials) -> { "PLAN", "item, count, from, to", ..., "BAG", ... }
--   Print(actions, materials, printer)   printer defaults to print

local ns = select(2, ...) -- nil under standalone lua

local ceil = math.ceil

-- Reproduces the prototype's original PLAN/BAG review text, one entry per line:
--   PLAN
--   <item>, <count>, <from>, <to>
--   BAG
--   <material>, <count>
local function Lines(actions, materials)
	local out = { "PLAN" }
	for _, ac in ipairs(actions) do
		out[#out + 1] = string.format("%s, %d, %d, %d", ac.item, ceil(ac.count), ac.from, ac.to)
	end
	out[#out + 1] = "BAG"
	-- Stable ordering so review diffs are meaningful.
	local names = {}
	for name in pairs(materials) do names[#names + 1] = name end
	table.sort(names)
	for _, name in ipairs(names) do
		out[#out + 1] = string.format("%s, %d", name, ceil(materials[name]))
	end
	return out
end

local function Print(actions, materials, printer)
	printer = printer or print
	for _, line in ipairs(Lines(actions, materials)) do
		printer(line)
	end
end

local M = { Lines = Lines, Print = Print }
if ns then ns.Format = M end
return M
