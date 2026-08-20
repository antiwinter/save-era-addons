#!/usr/bin/env lua
-- gen-data.lua — read fake-wow/data/era.db, emit the addon's trimmed recipe
-- tables into skillMaster/data/<prof_key>.lua. Drops everything the game
-- provides via GetItemInfo(id) (names); keeps player economy facts the client
-- cannot tell us (buyouts, teach items, skill-up thresholds).

-- Resolve repo paths from THIS file's location (works under any cwd).
local here = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or ".") .. "/"
local root = here .. "../.."

package.cpath = root .. "/fake-wow/scripts/vendor/?.so;" .. package.cpath
local sqlite3 = require("lsqlite3")

local db = assert(sqlite3.open(root .. "/fake-wow/data/era.db"))

local price = {}
local st = assert(db:prepare("SELECT id, avgbuyout FROM item"))
while st:step() == sqlite3.ROW do price[st:get_value(0)] = st:get_value(1) end

local recipes = {} -- prof_key -> array of {recipe row, reagents = {{id, count}}}
local byId = {}    -- (prof,skill_id) -> recipe entry
st = assert(db:prepare("SELECT prof_key, skill_id, craft_count, colors, learnedat, nskillup, phaseId, teach_id FROM trade_skill"))
while st:step() == sqlite3.ROW do
	local prof = st:get_value(0)
	local entry = {
		skill_id = st:get_value(1),
		craft_count = st:get_value(2),
		colors = {},
		learnedat = st:get_value(4),
		nskillup = st:get_value(5),
		phaseId = st:get_value(6),
		teach_id = st:get_value(7),
		reagents = {},
	}
	for n in st:get_value(3):gmatch("[^,]+") do entry.colors[#entry.colors + 1] = tonumber(n) end
	recipes[prof] = recipes[prof] or {}
	recipes[prof][#recipes[prof] + 1] = entry
	byId[prof .. ":" .. entry.skill_id] = entry
end

st = assert(db:prepare("SELECT prof_key, skill_id, reagent_id, count FROM recipe"))
while st:step() == sqlite3.ROW do
	local entry = assert(byId[st:get_value(0) .. ":" .. st:get_value(1)])
	entry.reagents[#entry.reagents + 1] = { id = st:get_value(2), count = st:get_value(3) }
end
db:close()

-- Craft cost = sum over reagents of (craftable recipe's cost | item price) * count.
local costMemo = {}
local function cost(prof, skill_id)
	local key = prof .. ":" .. skill_id
	if costMemo[key] then return costMemo[key] end
	local entry = byId[key]
	if not entry then return 0 end
	costMemo[key] = -1 -- guard against reagent cycles
	local total = 0
	for _, rg in ipairs(entry.reagents) do
		local sub = byId[prof .. ":" .. rg.id]
		total = total + rg.count * (sub and cost(prof, rg.id) or (price[rg.id] or 0))
	end
	costMemo[key] = total
	return total
end

local function emit(prof)
	local rows = recipes[prof] or {}
	table.sort(rows, function(a, b) return (a.learnedat or 0) < (b.learnedat or 0) end)
	local out = {}
	out[#out + 1] = prof .. "_data = {"
	for _, r in ipairs(rows) do
		local c = cost(prof, r.skill_id)
		local teach = r.teach_id > 0 and string.format("teach_price = %d, ", price[r.teach_id] or 0) or ""
		out[#out + 1] = string.format(
			"  {skill_id = %d, craft_count = %d, colors = {%s}, learnedat = %d, nskillup = %d, phaseId = %d, teach_id = %d, %savgbuyout = %d, cost = %d, recipe = {",
			r.skill_id, r.craft_count, table.concat(r.colors, ","), r.learnedat, r.nskillup,
			r.phaseId, r.teach_id, teach, price[r.skill_id] or 0, c)
		for i, rg in ipairs(r.reagents) do
			out[#out + 1] = string.format("    {id = %d, count = %d, avgbuyout = %d}%s",
				rg.id, rg.count, price[rg.id] or 0, i < #r.reagents and "," or "")
		end
		out[#out + 1] = "  }},"
	end
	out[#out + 1] = "}"
	local dir = root .. "/skillMaster/data"
	os.execute("mkdir -p " .. dir)
	local f = assert(io.open(dir .. "/" .. prof .. ".lua", "w"))
	f:write(table.concat(out, "\n"), "\n")
	f:close()
	print("wrote " .. dir .. "/" .. prof .. ".lua (" .. #rows .. " recipes)")
end

local keys = {}
for k in pairs(recipes) do keys[#keys + 1] = k end
table.sort(keys)
for _, k in ipairs(keys) do emit(k) end