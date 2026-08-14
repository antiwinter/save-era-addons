-- data.lua — recipe-table wrapper, usable both in-game and off-client.
--
-- In-game: the .toc loads data/<prof>.lua (each sets a global <prof>_data) and
-- then this file; ns.NewDB wraps a raw array into the queryable db shape.
-- Off-client: tests dofile('data/<prof>.lua') then call NewDB(<prof>_data).
--
-- No WoW globals here — keep it loadable under a plain `lua` interpreter.

local _, ns = ...

-- Wrap a raw recipe array (as emitted by scripts/dl.js) into a db object:
--   db[name|id]  -> recipe table (nil if unknown or has no color thresholds)
--   db.data      -> the underlying array, ordered low->high by learnedat
--   db:price(k)  -> avgbuyout for a recipe output or any reagent, else nil
local function NewDB(data)
	local db = {
		data = data,
		__index = function(self, key)
			for _, item in ipairs(self.data) do
				if item.id == key or item.name == key then
					if not item.colors or #item.colors == 0 then
						return nil
					end
					return item
				end
			end
			return nil
		end,
		price = function(self, key)
			for _, item in ipairs(self.data) do
				if item.name == key then
					return item.avgbuyout
				end
				for _, rg in ipairs(item.recipe) do
					if rg.name == key then
						return rg.avgbuyout
					end
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
