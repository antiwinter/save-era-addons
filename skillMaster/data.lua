-- data.lua — recipe-table wrapper, usable both in-game and off-client.
--
-- In-game: the .toc loads data/<prof>.lua (each sets a global <prof>_data) and
-- then this file; ns.NewDB wraps a raw array into the queryable db shape.
-- Off-client: tests dofile('data/<prof>.lua') then call NewDB(<prof>_data).
--
-- No WoW globals here — keep it loadable under a plain `lua` interpreter.

local _, ns = ...

ns.SchemPrefix = {
	eng = "Schematic: ",
	tailor = "Pattern: ",
	bs = "Plans: ",
	lw = "Pattern: ",
	alch = "Recipe: ",
	ench = "Formula: ",
	jc = "Design: ",
	insc = "Formula: ",
}

-- Wrap a raw recipe array (as emitted by scripts/dl.js) into a db object:
--   db[name|id]  -> recipe table (nil if unknown or has no color thresholds)
--   db.data      -> the underlying array, ordered low->high by learnedat
--   db:price(k)  -> avgbuyout for a recipe output, any reagent, or a teaching
--                   item ("Schematic: X"), else nil
local function NewDB(data, key)
	local db = {
		data = data,
		schemPrefix = ns.SchemPrefix[key] or "",
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
			-- Teaching items ("Schematic: X") resolve to the schematic's buyout.
			for _, item in ipairs(self.data) do
				if item.schemid and item.schemid > 0 and self.schemPrefix .. item.name == key then
					return item.schemprice
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
if eng_data then ns.db.eng = NewDB(eng_data, "eng") end
if tailor_data then ns.db.tailor = NewDB(tailor_data, "tailor") end
