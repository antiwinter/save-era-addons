local _, ns = ...
local exchange = {}
ns.trade = nil
ns.Exchange = exchange

local function addMailToCharacter(character, itemID, quantity)
	local target = artisanSkuDB[character]
	if not target then return end
	local record = target[itemID] or { bag = 0, bank = 0 }
	if record.mail then
		record.mail.n = record.mail.n + quantity
	else
		record.mail = { n = quantity, d = ns.MAIL_RETURN_DAYS }
	end
	target[itemID] = record
end

local function addBagToCharacter(character, itemID, quantity)
	local target = artisanSkuDB[character]
	if not target then return end
	local record = target[itemID] or { bag = 0, bank = 0 }
	record.bag = record.bag + quantity
	target[itemID] = record
end

local function itemIDFromLink(link)
	return tonumber(link:match("item:(%d+)"))
end

local function onSendMail(destination)
	for index = 1, 12 do
		local link = GetSendMailItemLink(index)
		if link then
			local _, _, _, quantity = GetSendMailItem(index)
			addMailToCharacter(destination, itemIDFromLink(link), quantity)
		end
	end
end

local function captureTrade(playerAccepted, targetAccepted)
	if playerAccepted ~= 1 and targetAccepted ~= 1 then ns.trade = nil; return end
	ns.trade = { character = UnitName("NPC"), items = {} }
	for index = 1, 6 do
		local link = GetTradePlayerItemLink(index)
		if link then
			local _, _, quantity = GetTradePlayerItemInfo(index)
			local itemID = itemIDFromLink(link)
			ns.trade.items[itemID] = (ns.trade.items[itemID] or 0) + quantity
		end
	end
end

local function finishTrade()
	if ns.trade then
		for itemID, quantity in pairs(ns.trade.items) do addBagToCharacter(ns.trade.character, itemID, quantity) end
		ns.trade = nil
	end
end

function exchange.Initialize()
	hooksecurefunc("SendMail", onSendMail)
end

function exchange.OnAuctionPurchase(itemID, quantity)
	local record = ns.db[itemID] or { bag = 0, bank = 0 }
	if record.mail then
		record.mail.n = record.mail.n + quantity
	else
		record.mail = { n = quantity, d = ns.MAIL_RETURN_DAYS }
	end
	ns.db[itemID] = record
end

function exchange.OnTradeAcceptUpdate(playerAccepted, targetAccepted)
	captureTrade(playerAccepted, targetAccepted)
end

function exchange.OnTradeComplete()
	finishTrade()
end

function exchange.OnTradeClosed()
	ns.trade = nil
end
