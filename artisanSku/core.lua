local addonName, ns = ...

ns.MAIL_RETURN_DAYS = 30
ns.defaults = { passcode = "" }
ns.db = nil
ns.cfg = nil
ns.char = nil
ns.sources = { bag = {}, bank = {}, mail = {} }
local function charKey() return UnitName("player") end
local function setCount(target, itemID, count)
	if itemID and count and count > 0 then target[itemID] = (target[itemID] or 0) + count end
end
local function bagSnapshot(firstBag, lastBag)
	local result = {}
	for bag = firstBag, lastBag do
		local slots = C_Container.GetContainerNumSlots(bag)
		for slot = 1, slots do
			local info = C_Container.GetContainerItemInfo(bag, slot)
			if info then setCount(result, info.itemID, info.stackCount) end
		end
	end
	return result
end
local function mailSnapshot()
	local result = {}
	local total = GetInboxNumItems()
	for index = 1, total do
		local header = { GetInboxHeaderInfo(index) }
		local daysLeft = header[7]
		local wasReturned = header[10] == true or header[10] == 1
		local days = math.max(0, math.ceil(daysLeft))
		if wasReturned then days = days + ns.MAIL_RETURN_DAYS end
		local attachments = GetInboxNumAttachments(index)
		for attachment = 1, attachments do
			local _, itemID, count = GetInboxItem(index, attachment)
			if itemID then
				local previous = result[itemID]
				if previous then
					previous.n = previous.n + count
					if days < previous.d then previous.d = days end
				else
					result[itemID] = { n = count, d = days }
				end
			end
		end
	end
	return result
end
local function rebuild()
	local records = {}
	for source, values in pairs(ns.sources) do
		for itemID in pairs(values) do records[itemID] = true end
	end
	for itemID in pairs(records) do
		local bag = ns.sources.bag[itemID] or 0
		local bank = ns.sources.bank[itemID] or 0
		local mail = ns.sources.mail[itemID]
		if bag > 0 or bank > 0 or mail then
			ns.db[itemID] = { bag = bag, bank = bank, mail = mail }
		else
			ns.db[itemID] = nil
		end
	end
end
local function seedSources()
	for itemID, record in pairs(ns.db) do
		if type(record) == "table" then
			if tonumber(record.bag) and record.bag > 0 then ns.sources.bag[tonumber(itemID)] = record.bag end
			if tonumber(record.bank) and record.bank > 0 then ns.sources.bank[tonumber(itemID)] = record.bank end
			if type(record.mail) == "table" and tonumber(record.mail.n) and record.mail.n > 0 then
				ns.sources.mail[tonumber(itemID)] = { n = record.mail.n, d = tonumber(record.mail.d) or 0 }
			end
		end
	end
end
function ns.ScanBags()
	local snapshot = bagSnapshot(0, 4)
	ns.sources.bag = snapshot; rebuild()
end
function ns.ScanBank()
	local snapshot = bagSnapshot(-1, 11)
	ns.sources.bank = snapshot; rebuild()
end
function ns.ScanMail()
	local snapshot = mailSnapshot()
	ns.sources.mail = snapshot; rebuild()
end
function ArtisanGetSku(itemID)
	itemID = tonumber(itemID)
	local result = { total = 0 }
	if not itemID then return result end
	local characters = artisanSkuDB
	for character, data in pairs(characters) do
		if character ~= "__config" and type(data) == "table" and type(data[itemID]) == "table" then
			local record = data[itemID]
			local mail = record.mail and (record.mail.n or 0) or 0
			result[character] = { bag = record.bag or 0, bank = record.bank or 0, mail = mail }
			result.total = result.total + result[character].bag + result[character].bank + mail
		end
	end
	return result
end
ns.ArtisanGetSku = ArtisanGetSku
local frame = CreateFrame("Frame")
for _, event in ipairs({
	"ADDON_LOADED", "BAG_OPEN", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED", "MAIL_INBOX_UPDATE", "MAIL_SHOW",
	"GROUP_ROSTER_UPDATE", "TRADE_ACCEPT_UPDATE", "TRADE_CLOSED", "UI_INFO_MESSAGE",
	"CHAT_MSG_ADDON",
}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		artisanSkuDB = artisanSkuDB or {}
		ns.char = charKey()
		artisanSkuDB[ns.char] = artisanSkuDB[ns.char] or {}
		ns.db, ns.cfg = artisanSkuDB[ns.char], artisanSkuDB.__config or {}
		ns.db.class = select(2, UnitClass("player"))
		for key, value in pairs(ns.defaults) do if ns.cfg[key] == nil then ns.cfg[key] = value end end
		artisanSkuDB.__config = ns.cfg
		seedSources(); rebuild(); ns.ScanBags()
		ns.Sync.Initialize()
		ns.Exchange.Initialize()
	elseif event == "BAG_OPEN" or event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then ns.ScanBags()
	elseif event == "BANKFRAME_OPENED" then ns.ScanBank()
	elseif event == "PLAYERBANKSLOTS_CHANGED" then ns.ScanBank()
	elseif event == "MAIL_SHOW" then ns.ScanMail()
	elseif event == "MAIL_INBOX_UPDATE" then ns.ScanMail()
	elseif event == "GROUP_ROSTER_UPDATE" then ns.Sync.OnRosterUpdate()
	elseif event == "TRADE_ACCEPT_UPDATE" then ns.Exchange.OnTradeAcceptUpdate(arg1, arg2)
	elseif event == "UI_INFO_MESSAGE" and arg1 == LE_GAME_ERR_TRADE_COMPLETE then ns.Exchange.OnTradeComplete()
	elseif event == "TRADE_CLOSED" then ns.Exchange.OnTradeClosed()
	elseif event == "CHAT_MSG_ADDON" and arg1 == ns.Sync.PREFIX then ns.Sync.OnAddonMessage(arg4, arg2) end
end)
