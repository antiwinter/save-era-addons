-- planner.lua — the craft-plan solver. Pure Lua: no WoW globals, and the caller
-- passes `db` in (no dofile/require of data). Runs identically in-game and under
-- fake-wow, so tests exercise the shipped algorithm. See AGENTS.md.
--
-- BuildPlan(db, opts) -> actions, materials
--   db       : a db object from data.lua (NewDB)
--   opts     : { start=1, target=<cap>, phase=3, pGain=0, wishlist={}, debug=false }
--   actions  : ordered list of { item, count, from, to }
--   materials: map of reagent name -> count to buy (non-craftable leaves)

local _, ns = ...

local sqrt, floor, ceil, pow = math.sqrt, math.floor, math.ceil, function(a, b) return a ^ b end

-- Faithful port of the prototype's rolls(): expected crafts to gain (b-a)
-- skill points at per-craft skill-up chance p. NOTE: this is a normal-ish
-- approximation carried over verbatim so off-client results match the WA
-- baseline. The exact-binomial replacement from scripts/../buffer-research is a
-- planned follow-up; swap it in only alongside a refreshed test baseline.
local function rolls(a, b, p)
	local n = b - a
	if n <= 0 then return 0 end
	if p == 1 then return n end
	return n + n * (1 - p) / p + 2 * sqrt(n * (1 - p)) / p
end

local function BuildPlan(db, opts)
	opts = opts or {}
	local START = opts.start or 1
	local PHASE = opts.phase or 3
	local p_gain = opts.pGain or 0
	local wishlist = opts.wishlist or {}
	local DEBUG = opts.debug or false
	-- END grows as recipes get pushed to higher levels; seed from target/cap.
	local END = opts.target or 0

	local function dbg(fmt, ...)
		if DEBUG then print(string.format(fmt, ...)) end
	end

	-- Skill-up chance for `item` at skill `lvl`, plus the color index hit.
	local CHANCE = { 0, 1, 0.75, 0.25 }
	local function chance(item, lvl)
		local r = db[item]
		if not r or not r.colors or #r.colors == 0 then return 0 end
		for i, l in ipairs(r.colors) do
			if l > lvl then return CHANCE[i], i end
		end
		return 0
	end

	-- Pick the best recipe to spam at skill `lvl`, scored by ROI per skill-up.
	local function find(lvl)
		local res, best, frac
		for _, r in ipairs(db.data) do
			local p, i = chance(r.name, lvl)
			if p ~= 0 and r.phaseId <= PHASE then
				local m, n = r.colors[i - 1], r.colors[i]
				local p1 = (n - m) / rolls(m, n, p)
				local roi = (r.avgbuyout * p_gain - r.cost) / p1
				local perf = roi * pow(#r.recipe, 0.5)
				if not best or perf > best then
					best, res, frac = perf, r, 1 / p
				end
			end
		end
		if not res then return nil, 0 end
		return res, frac
	end

	-- Per-level allocation buckets. slot.data[lvl] tracks how much crafting is
	-- assigned at that level and how much skill-up "point" budget remains.
	local slot = { data = {} }
	function slot:push(lvl, item, frac)
		if not self.data[lvl] then self.data[lvl] = { point = 1 } end
		local s = self.data[lvl]
		if not s[item] then s[item] = 0 end
		local p = s.point
		local p1 = chance(item, lvl) * frac
		if p1 <= p then
			s[item] = s[item] + frac
			s.point = math.max(0, p - p1)
			return 0
		else
			s[item] = s[item] + p / p1 * frac
			s.point = 0
			return (p1 - p) / p1 * frac
		end
	end

	local material = {}

	-- Assign `frac` crafts of recipe r at `lvl`, recursively pushing the crafts
	-- needed to produce its craftable reagents; non-craftable reagents accrue
	-- into `material`. `force` spills overflow up to the next level.
	local function try_push(lvl, r, frac, force, indent)
		dbg(string.rep("  ", indent) .. "[%d] << [%s]x%.1f", lvl, r.name, frac)
		local p = chance(r.name, lvl)
		local remain = frac
		if not slot.data[lvl] or slot.data[lvl].point > 0 or p == 0 then
			END = math.max(END, lvl)
			remain = slot:push(lvl, r.name, frac)
			local placed = frac - remain
			if placed > 0 then
				for _, reagent in ipairs(r.recipe) do
					local rg = db[reagent.name]
					if rg then
						try_push(rg.colors[1], rg, placed * reagent.count, true, indent + 1)
					else
						material[reagent.name] = (material[reagent.name] or 0) + placed * reagent.count
					end
				end
			end
		end
		if remain > 0 then
			if force then
				try_push(lvl + 1, r, remain, true, indent)
			else
				dbg(string.rep("  ", indent) .. "skip %.1f", remain)
			end
		end
	end

	-- Inflate action counts so a run has a safety margin against unlucky rolls,
	-- and propagate the extra reagent demand down to leaves.
	local function fix_buffer(actions)
		local function add(r, m)
			for _, ac in ipairs(actions) do
				if ac.item == r.name then
					ac.count = ac.count + m
					break
				end
			end
			for _, rg in ipairs(r.recipe) do
				local _r = db[rg.name]
				if _r then
					add(_r, m * rg.count / (_r.craft_count or 1))
				else
					material[rg.name] = (material[rg.name] or 0) + m * rg.count
				end
			end
		end
		for _, ac in ipairs(actions) do
			local c = db[ac.item].colors
			local n = rolls(math.max(c[2], ac.from), math.min(c[3], ac.to), 0.75)
				+ rolls(math.max(c[3], ac.from), math.min(c[4], ac.to), 0.25)
				+ rolls(math.max(c[1], ac.from), math.min(c[2], ac.to), 1)
			if n > ac.count then
				add(db[ac.item], n - ac.count)
			end
		end
	end

	-- Seed the wishlist (make N of each requested item regardless of ROI).
	for name, count in pairs(wishlist) do
		local r = db[name]
		if r then
			for _ = 1, count do
				try_push(r.colors[1], r, 1, true, 0)
			end
		end
	end

	-- Fill every level from the top down with the best ROI recipe.
	for i = END - 1, START, -1 do
		local r, frac = find(i)
		if r then try_push(i, r, frac, false, 0) end
	end

	-- Collapse per-level slots into contiguous actions.
	local function gen_plan()
		local temp, actions = {}, {}
		for lvl = START, END + 1 do
			local s = slot.data[lvl] or {}
			local log = {}
			for k, entry in pairs(temp) do
				if s[k] then
					entry.count = entry.count + s[k]
					log[k] = true
				else
					table.insert(actions, {
						item = k,
						count = entry.count,
						from = entry.appear,
						to = math.min(lvl, db[k].colors[4]),
					})
					temp[k] = nil
				end
			end
			for k, count in pairs(s) do
				if k ~= "point" and not log[k] then
					temp[k] = { count = count, appear = lvl }
				end
			end
		end
		table.sort(actions, function(a, b) return a.to > b.to end)
		fix_buffer(actions)
		table.sort(actions, function(a, b) return a.from < b.from end)
		return actions
	end

	return gen_plan(), material
end

ns.Planner = { BuildPlan = BuildPlan, rolls = rolls }
