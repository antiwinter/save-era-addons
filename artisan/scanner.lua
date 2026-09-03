local _, ns = ...

local Scanner = { busy = false }

function Scanner.NormalizeRows(rows, now)
	local min, max, minStack
	for i, row in ipairs(rows or {}) do
		if i > 50 then break end
		local total = row.buyout or row.totalBuyout or row[1]
		local stack = row.stackCount or row.quantity or row.stack or row[2] or 1
		local owner = row.owner or row[3]
		if type(total) == "number" and total > 0
			and type(stack) == "number" and stack > 0
			and owner ~= UnitName("player") then
			local unit = math.floor(total / stack)
			if unit > 0 then
				if not min or unit < min then min, minStack = unit, stack end
				if not max or unit > max then max = unit end
			end
		end
	end
	if not min then return nil, "no-auction" end
	return { min = min, max = max, stackCount = minStack, updatedAt = now or time() }
end

function Scanner:Start(itemIDs, callback, provider)
	if self.busy then return false, "busy" end
	self.busy = true
	for _, itemID in ipairs(itemIDs or {}) do
		if not provider or type(provider.Scan) ~= "function" then
			callback({ itemID = itemID, providerStatus = "unavailable" })
		else
			local result, status = Scanner.NormalizeRows(provider:Scan(itemID))
			result = result or { providerStatus = status }
			result.itemID = itemID
			result.providerStatus = result.providerStatus or "updated"
			callback(result)
		end
	end
	self.busy = false
	return true
end

local function selectedKeys(scope)
	if scope == "all" then
		local keys = {}
		for pk in pairs(ns.db) do keys[#keys + 1] = pk end
		table.sort(keys)
		return keys
	end
	if ns.db[scope] then return { scope } end
end

function Scanner:scan(scope)
	local keys = selectedKeys(scope)
	if not keys then
		print("|cff00b4ff[art]|r usage: /art scan [all|profession]")
		return false, "invalid"
	end
	if self.busy then
		print("|cff00b4ff[art]|r scanner busy")
		return false, "busy"
	end

	local itemIDs = ns.Market:Collect(keys)
	local totals = { updated = 0, skipped = 0, ["no-auction"] = 0, unavailable = 0, failed = 0 }
	local provider = ns.ScanProvider
	local providerName = provider and (provider.name or "live") or "unavailable"
	print(string.format("|cff00b4ff[art]|r scanning %s (%d items, %s)",
		table.concat(keys, ","), #itemIDs, providerName))

	self:Start(itemIDs, function(result)
		if result.min then
			local updated = ns.Market:Put(ns.Market:RealmKey(), result.itemID, {
				price = { result.min, result.max, result.stackCount },
				source = "scan",
				updatedAt = result.updatedAt,
			})
			local status = updated and "updated" or "skipped"
			totals[status] = totals[status] + 1
			if ns.DEBUG and updated then
				print(string.format("[art] %d min=%d max=%d stack=%d source=scan updatedAt=%d",
					result.itemID, result.min, result.max, result.stackCount, result.updatedAt))
			end
		else
			local status = result.providerStatus or "failed"
			totals[status] = (totals[status] or 0) + 1
		end
	end, provider)

	print(string.format("|cff00b4ff[art]|r scan complete: updated=%d skipped=%d no-auction=%d unavailable=%d failed=%d",
		totals.updated, totals.skipped, totals["no-auction"], totals.unavailable, totals.failed))
	return true, totals
end

ns.Scanner = Scanner
