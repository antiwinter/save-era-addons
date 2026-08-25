local dir = (debug.getinfo(1, "S").source:gsub("^@", ""):match("^(.*)/[^/]*$") or ".") .. "/"
package.cpath = dir .. "scripts/vendor/?.so;" .. package.cpath
local sqlite3 = require("lsqlite3")

local M = {}
local Data = {}
Data.__index = Data

local function skillRow(statement)
	local skill = {
		pk = statement:get_value(0),
		id = statement:get_value(1),
		name = statement:get_value(2),
		craft_count = statement:get_value(3),
		colors = {},
		learnedat = statement:get_value(5),
		nskillup = statement:get_value(6),
		phaseId = statement:get_value(7),
		scroll_id = statement:get_value(8),
	}
	for value in statement:get_value(4):gmatch("[^,]+") do
		skill.colors[#skill.colors + 1] = tonumber(value)
	end
	return skill
end

local function professionRow(statement)
	local profession = {
		pk = statement:get_value(0),
		name = statement:get_value(1),
		scrollPrefix = statement:get_value(2),
		spellIds = {},
	}
	for value in (statement:get_value(3) or ""):gmatch("[^,]+") do
		profession.spellIds[#profession.spellIds + 1] = tonumber(value)
	end
	return profession
end

local function queryOne(self, sql, row, ...)
	local statement = assert(self.handle:prepare(sql))
	assert(statement:bind_values(...))
	local result
	if statement:step() == sqlite3.ROW then result = row(statement) end
	statement:finalize()
	return result
end

function Data:GetItem(id)
	return queryOne(self, [[
		SELECT id, name, avgbuyout, quality FROM item WHERE id = ?]], function(statement)
		return {
			id = statement:get_value(0),
			name = statement:get_value(1),
			avgbuyout = statement:get_value(2),
			quality = statement:get_value(3),
		}
	end, id)
end

function Data:GetProfession(pk)
	return queryOne(self, [[
		SELECT prof_key, name, scroll_prefix, spell_ids
		FROM professions WHERE prof_key = ?]], professionRow, pk)
end

function Data:FindProfession(name)
	return queryOne(self, [[
		SELECT prof_key, name, scroll_prefix, spell_ids
		FROM professions WHERE name = ?]], professionRow, name)
end

function Data:FindProfessionBySpellId(spellId)
	return queryOne(self, [[
		SELECT prof_key, name, scroll_prefix, spell_ids FROM professions
		WHERE ',' || spell_ids || ',' LIKE '%,' || ? || ',%']], professionRow, tostring(spellId))
end

function Data:GetSkill(pk, index)
	return queryOne(self, [[
		SELECT prof_key, skill_id, skill_name, craft_count, colors, learnedat,
		       nskillup, phaseId, scroll_id
		FROM trade_skill WHERE prof_key = ?
		ORDER BY skill_id LIMIT 1 OFFSET ?]], skillRow, pk, index - 1)
end

function Data:GetSkillCount(pk)
	return queryOne(self, [[SELECT COUNT(*) FROM trade_skill WHERE prof_key = ?]],
		function(statement) return statement:get_value(0) end, pk)
end

function Data:GetSkillById(sid)
	return queryOne(self, [[
		SELECT prof_key, skill_id, skill_name, craft_count, colors, learnedat,
		       nskillup, phaseId, scroll_id
		FROM trade_skill WHERE skill_id = ?]], skillRow, sid)
end

function Data:FindSkillByScrollId(scrollId)
	return queryOne(self, [[
		SELECT prof_key, skill_id, skill_name, craft_count, colors, learnedat,
		       nskillup, phaseId, scroll_id
		FROM trade_skill WHERE scroll_id = ?]], skillRow, scrollId)
end

function Data:GetRecipe(sid)
	local statement = assert(self.handle:prepare([[
		SELECT reagent_id, count FROM recipe
		WHERE skill_id = ? ORDER BY reagent_id]]))
	assert(statement:bind_values(sid))
	local recipe = {}
	while statement:step() == sqlite3.ROW do
		recipe[#recipe + 1] = { id = statement:get_value(0), count = statement:get_value(1) }
	end
	statement:finalize()
	return recipe
end

function Data:ListProfessionKeys()
	local statement = assert(self.handle:prepare([[
		SELECT DISTINCT prof_key FROM trade_skill ORDER BY prof_key]]))
	local keys = {}
	while statement:step() == sqlite3.ROW do keys[#keys + 1] = statement:get_value(0) end
	statement:finalize()
	return keys
end

function Data:ListSkills(pk)
	local statement = assert(self.handle:prepare([[
		SELECT prof_key, skill_id, skill_name, craft_count, colors, learnedat,
		       nskillup, phaseId, scroll_id
		FROM trade_skill WHERE prof_key = ?
		ORDER BY skill_id]]))
	assert(statement:bind_values(pk))
	local skills = {}
	while statement:step() == sqlite3.ROW do skills[#skills + 1] = skillRow(statement) end
	statement:finalize()
	table.sort(skills, function(a, b) return a.learnedat < b.learnedat end)
	return skills
end

function Data:ListProfSpells()
	local statement = assert(self.handle:prepare([[
		SELECT prof_key, name, scroll_prefix, spell_ids FROM professions
		WHERE spell_ids <> '' ORDER BY prof_key]]))
	local professions = {}
	while statement:step() == sqlite3.ROW do
		local profession = professionRow(statement)
		professions[#professions + 1] = { pk = profession.pk, spells = profession.spellIds }
	end
	statement:finalize()
	return professions
end

function Data:Close()
	self.handle:close()
end

function M.load(dbPath)
	return setmetatable({ handle = assert(sqlite3.open(dbPath)) }, Data)
end

return M
