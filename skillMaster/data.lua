-- data.lua — recipe-table wrapper, usable both in-game and off-client.
--
-- In-game: the .toc loads data/<prof>.lua (each sets a global <prof>_data) and
-- then this file; ns.NewDB wraps a raw array into the queryable db shape.
-- Off-client: tests dofile('data/<prof>.lua') then call NewDB(<prof>_data).
--
-- No WoW globals here — keep it loadable under a plain `lua` interpreter.

local _, ns = ...

-- Wrap a raw recipe array (as emitted by scripts/gen-data.lua) into a db
-- object, keyed by item id:
--   db[id]      -> recipe table (nil if unknown or has no color thresholds)
--   db.data     -> the underlying array, ordered low->high by learnedat
--   db:price(id)-> avgbuyout for a recipe output, reagent, or teaching item
local function NewDB(data)
	local db = {
		data = data,
		__index = function(self, id)
			if type(id) ~= "number" then return nil end
			for _, item in ipairs(self.data) do
				if item.skill_id == id then
					if not item.colors or #item.colors == 0 then
						return nil
					end
					return item
				end
			end
		end,
		price = function(self, id)
			if type(id) ~= "number" then return nil end
			for _, item in ipairs(self.data) do
				if item.skill_id == id then
					return item.avgbuyout
				end
				for _, rg in ipairs(item.recipe) do
					if rg.id == id then
						return rg.avgbuyout
					end
				end
				if item.teach_id == id then
					return item.teach_price
				end
			end
		end,
	}
	setmetatable(db, db)
	return db
end

ns.NewDB = NewDB
ns.db = ns.db or {}
-- Generated tables are loaded before this file (see .toc) and expose
-- <prof>_data globals; register whichever ones shipped in this build.
if eng_data then ns.db.eng = NewDB(eng_data) end
if tailor_data then ns.db.tailor = NewDB(tailor_data) end