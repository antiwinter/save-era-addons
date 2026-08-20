-- era.lua — the single reader of the shared era database (fake-wow/data/era.db).
-- Returns the canonical normalized tables; the emulator (tradeskill.lua's
-- GM.LoadEra) and the addon data generator (skillMaster/scripts/gen-data.lua)
-- both consume this shape, so db access and the table semantics live in one place.

local dir = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or ".") .. "/"
package.cpath = dir .. "scripts/vendor/?.so;" .. package.cpath
local sqlite3 = require("lsqlite3")

local M = {}

function M.load(dbPath)
	local db = assert(sqlite3.open(dbPath))
	local out = { skills = {}, recipe = {}, items = {} }
	local bySkill = {}

	local st = assert(db:prepare([[
		SELECT prof_key, skill_id, skill_name, craft_count, colors, learnedat,
		       nskillup, phaseId, teach_id
		FROM trade_skill
		ORDER BY prof_key, skill_id]]))
	while st:step() == sqlite3.ROW do
		local s = {
			prof = st:get_value(0),
			id = st:get_value(1),
			name = st:get_value(2),
			craft_count = st:get_value(3),
			colors = {},
			learnedat = st:get_value(5),
			nskillup = st:get_value(6),
			phaseId = st:get_value(7),
			teach_id = st:get_value(8),
		}
		local csv = st:get_value(4)
		if csv ~= "" then
			for n in csv:gmatch("[^,]+") do s.colors[#s.colors + 1] = tonumber(n) end
		end
		out.skills[#out.skills + 1] = s
		bySkill[s.id] = s
	end

	st = assert(db:prepare([[
		SELECT prof_key, skill_id, reagent_id, count FROM recipe
		ORDER BY prof_key, skill_id, reagent_id]]))
	while st:step() == sqlite3.ROW do
		out.recipe[#out.recipe + 1] = {
			prof = st:get_value(0),
			skill_id = st:get_value(1),
			reagent_id = st:get_value(2),
			count = st:get_value(3),
		}
	end
	for _, r in ipairs(out.recipe) do
		assert(bySkill[r.skill_id], "recipe for unknown skill " .. r.skill_id)
	end

	st = assert(db:prepare("SELECT id, name, avgbuyout, quality FROM item"))
	while st:step() == sqlite3.ROW do
		out.items[st:get_value(0)] = {
			name = st:get_value(1),
			avgbuyout = st:get_value(2),
			quality = st:get_value(3),
		}
	end
	db:close()
	return out
end

return M