local _, ns = ...

local Scanner = { busy = false }
local frame = CreateFrame("Frame")
frame:RegisterEvent("AUCTION_ITEM_LIST_UPDATE")
frame:RegisterEvent("AUCTION_HOUSE_CLOSED")

local function cancel(timer)
	if timer then timer:Cancel() end
end

local function itemIDFromLink(link)
	return link and tonumber(link:match("item:(%d+)"))
end

function Scanner.NormalizeRows(rows, now)
	local min, max, minStack
	local player = UnitName("player")
	for _, row in ipairs(rows or {}) do
		if type(row.buyout) == "number" and row.buyout > 0
			and type(row.stackCount) == "number" and row.stackCount > 0
			and row.owner ~= player and row.ownerFull ~= player then
			local unit = math.floor(row.buyout / row.stackCount)
			if unit > 0 then
				if not min or unit < min then min, minStack = unit, row.stackCount end
				if not max or unit > max then max = unit end
			end
		end
	end
	if not min then return nil, "no-auction" end
	return { min = min, max = max, stackCount = minStack, updatedAt = now or time() }
end

function Scanner:IsAvailable()
	return AuctionFrame and AuctionFrame:IsShown()
		and type(QueryAuctionItems) == "function"
		and type(CanSendAuctionQuery) == "function"
		and type(GetNumAuctionItems) == "function"
		and type(GetAuctionItemInfo) == "function"
		and type(GetAuctionItemLink) == "function"
end

function Scanner:finish(status)
	cancel(self.nextTimer)
	cancel(self.resultTimer)
	local done = self.done
	self.busy = false
	self.itemIDs = nil
	self.callback = nil
	self.done = nil
	self.current = nil
	self.nextTimer = nil
	self.resultTimer = nil
	if done then done(status) end
end

function Scanner:complete(result)
	result.itemID = self.current
	result.position = self.index
	result.total = #self.itemIDs
	self.callback(result)
	self.current = nil
	self.index = self.index + 1
	self.nextTimer = C_Timer.NewTimer(0, function()
		self.nextTimer = nil
		self:queryNext()
	end)
end

function Scanner:queryNext()
	if not self.busy then return end
	if not self:IsAvailable() then return self:finish("unavailable") end
	if self.index > #self.itemIDs then return self:finish("complete") end
	if not CanSendAuctionQuery() then
		self.nextTimer = C_Timer.NewTimer(0.2, function()
			self.nextTimer = nil
			self:queryNext()
		end)
		return
	end

	local itemID = self.itemIDs[self.index]
	local name = GetItemInfo(itemID)
	if not name then
		self.current = itemID
		self:complete({ status = "failed" })
		return
	end

	self.current = itemID
	QueryAuctionItems(name, nil, nil, 0, false, nil, false, true)
	self.resultTimer = C_Timer.NewTimer(10, function()
		self.resultTimer = nil
		if self.current == itemID then self:complete({ status = "failed" }) end
	end)
end

function Scanner:readResults()
	if not self.busy or not self.current then return end
	cancel(self.resultTimer)
	self.resultTimer = nil
	local rows = {}
	local count = GetNumAuctionItems("list")
	for index = 1, count do
		if itemIDFromLink(GetAuctionItemLink("list", index)) == self.current then
			local _, _, stackCount, _, _, _, _, _, _, buyout, _, _, _, owner, ownerFull = GetAuctionItemInfo("list", index)
			rows[#rows + 1] = { buyout = buyout, stackCount = stackCount, owner = owner, ownerFull = ownerFull }
		end
	end
	local result, status = self.NormalizeRows(rows)
	result = result or { status = status }
	result.status = result.status or "updated"
	self:complete(result)
end

function Scanner:Start(itemIDs, callback, done)
	if self.busy then return false, "busy" end
	if not self:IsAvailable() then return false, "unavailable" end
	self.busy = true
	self.itemIDs = itemIDs
	self.callback = callback
	self.done = done
	self.index = 1
	self:queryNext()
	return true
end

local function validScope(scope)
	return pcall(ns.db.iterate, ns.db, scope)
end

function Scanner:scan(scope)
	if not validScope(scope) then
		print("|cff00b4ff[art]|r usage: /art scan [all|profession]")
		return false, "invalid"
	end
	if self.busy then
		print("|cff00b4ff[art]|r scanner busy")
		return false, "busy"
	end
	if not self:IsAvailable() then
		print("|cff00b4ff[art]|r open the auction house before scanning")
		return false, "unavailable"
	end

	local itemIDs = ns.Market:Collect(scope)
	local totals = { updated = 0, skipped = 0, ["no-auction"] = 0, failed = 0 }
	print(string.format("|cff00b4ff[art]|r scanning %s (%d items)", scope, #itemIDs))
	return self:Start(itemIDs, function(result)
		if result.min then
			local updated = ns.Market:Put(result.itemID, {
				price = { result.min, result.max, result.stackCount }, source = "scan", updatedAt = result.updatedAt,
			})
			local status = updated and "updated" or "skipped"
			totals[status] = totals[status] + 1
			if ns.DEBUG and updated then
				print(string.format("[art] %d min=%d max=%d stack=%d source=scan updatedAt=%d",
					result.itemID, result.min, result.max, result.stackCount, result.updatedAt))
			end
		else
			local status = result.status or "failed"
			totals[status] = (totals[status] or 0) + 1
		end
		if result.position % 25 == 0 or result.position == result.total then
			print(string.format("|cff00b4ff[art]|r scan %d/%d", result.position, result.total))
		end
	end, function(status)
		print(string.format("|cff00b4ff[art]|r scan %s: updated=%d skipped=%d no-auction=%d failed=%d",
			status, totals.updated, totals.skipped, totals["no-auction"], totals.failed))
	end)
end

frame:SetScript("OnEvent", function(_, event)
	if event == "AUCTION_ITEM_LIST_UPDATE" then
		Scanner:readResults()
	elseif Scanner.busy then
		Scanner:finish("auction-house-closed")
	end
end)

ns.Scanner = Scanner
