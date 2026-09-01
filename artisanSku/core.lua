local addonName, ns = ...
local PREFIX = "artisanSku"
local MAIL_RETURN_DAYS = 30
local MAX_MESSAGE = 180
ns.defaults = { passcode = "" }
ns.db = nil
ns.cfg = nil
ns.account = nil
ns.char = nil
ns.sources = { bag = {}, bank = {}, mail = {} }
ns.sync = {}
local function accountKey() return "account" end
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
		if wasReturned then days = days + MAIL_RETURN_DAYS end
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
local function sortedItemIDs(data)
	local ids = {}
	for itemID in pairs(data) do if tonumber(itemID) then ids[#ids + 1] = tonumber(itemID) end end
	table.sort(ids)
	return ids
end
local function escape(value)
	return tostring(value):gsub("%%", "%%25"):gsub("|", "%%7C")
end
local function unescape(value)
	return (value:gsub("%%7C", "|"):gsub("%%25", "%%"))
end
local function encode(data)
	local fields = {}
	for _, itemID in ipairs(sortedItemIDs(data)) do
		local record = data[itemID]
		local mail = record.mail or {}
		fields[#fields + 1] = table.concat({ itemID, record.bag or 0, record.bank or 0, mail.n or 0, mail.d or 0 }, ",")
	end
	return table.concat(fields, ";")
end
local function decode(payload)
	local result = {}
	for entry in payload:gmatch("[^;]+") do
		local itemID, bag, bank, mailN, mailD = entry:match("^(%d+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+),([%d%.%-]+)$")
		if itemID then
			itemID, bag, bank, mailN, mailD = tonumber(itemID), tonumber(bag), tonumber(bank), tonumber(mailN), tonumber(mailD)
			if bag > 0 or bank > 0 or mailN > 0 then
				result[itemID] = { bag = bag, bank = bank, mail = mailN > 0 and { n = mailN, d = mailD } or nil }
			end
		end
	end
	return result
end
local function send(message) C_ChatInfo.SendAddonMessage(PREFIX, message, "PARTY") end
function ns.Broadcast()
	if ns.cfg.passcode == "" then return end
	local payload = encode(ns.db)
	local pass = escape(ns.cfg.passcode)
	local character = escape(ns.char)
	local chunks = {}
	for start = 1, #payload, MAX_MESSAGE do chunks[#chunks + 1] = payload:sub(start, start + MAX_MESSAGE - 1) end
	if #chunks == 0 then chunks[1] = "" end
	for index, chunk in ipairs(chunks) do
		send(table.concat({ "1", pass, character, index, #chunks, chunk }, "|"))
	end
end
local function merge(sender, message)
	local version, pass, character, index, total, payload = message:match("^(%d+)|([^|]*)|([^|]*)|(%d+)|(%d+)|(.*)$")
	if version ~= "1" or not pass or unescape(pass) ~= ns.cfg.passcode then return end
	index, total = tonumber(index), tonumber(total)
	if not index or not total then return end
	local key = sender .. ":" .. character
	local buffer = ns.sync[key] or { total = total, chunks = {} }
	buffer.total, buffer.chunks[index] = total, payload
	ns.sync[key] = buffer
	local count = 0
	for _ in pairs(buffer.chunks) do count = count + 1 end
	if count < total then return end
	local data = {}
	for i = 1, total do data[#data + 1] = buffer.chunks[i] or "" end
	local incoming = decode(table.concat(data))
	local target = artisanSkuDB[ns.account][unescape(character)] or {}
	for itemID, record in pairs(incoming) do target[itemID] = record end
	for itemID in pairs(target) do if not incoming[itemID] then target[itemID] = nil end end
	artisanSkuDB[ns.account][unescape(character)] = target
	ns.sync[key] = nil
end
function ArtisanGetSku(itemID)
	itemID = tonumber(itemID)
	local result = { total = 0 }
	if not itemID then return result end
	local account = artisanSkuDB[ns.account]
	for character, data in pairs(account) do
		if type(data) == "table" and type(data[itemID]) == "table" then
			local record = data[itemID]
			local mail = record.mail and (record.mail.n or 0) or 0
			result[character] = { bag = record.bag or 0, bank = record.bank or 0, mail = mail }
			result.total = result.total + result[character].bag + result[character].bank + mail
		end
	end
	return result
end
ns.ArtisanGetSku = ArtisanGetSku
local function addTooltip(tooltip)
	local _, link = tooltip:GetItem()
	local itemID = link and tonumber(link:match("item:(%d+)"))
	if not itemID then return end
	local sku = ArtisanGetSku(itemID)
	if sku.total <= 0 then return end
	local bag, bank, mail = 0, 0, 0
	for character, record in pairs(sku) do
		if character ~= "total" then bag, bank, mail = bag + record.bag, bank + record.bank, mail + record.mail end
	end
	tooltip:AddLine(("artisanSku: %d total (bag %d, bank %d, mail %d)"):format(sku.total, bag, bank, mail), 0.6, 0.8, 1)
end
local frame = CreateFrame("Frame")
for _, event in ipairs({
	"ADDON_LOADED", "PLAYER_LOGIN", "BAG_UPDATE", "BAG_UPDATE_DELAYED", "PLAYERBANKSLOTS_CHANGED", "BANKFRAME_OPENED", "MAIL_INBOX_UPDATE", "MAIL_SHOW", "MAIL_SEND_SUCCESS",
	"AUCTION_HOUSE_ITEM_PURCHASED", "GROUP_ROSTER_UPDATE",
	"CHAT_MSG_ADDON",
}) do frame:RegisterEvent(event) end
frame:SetScript("OnEvent", function(_, event, arg1, arg2, arg3, arg4)
	if event == "ADDON_LOADED" then
		if arg1 ~= addonName then return end
		artisanSkuDB = artisanSkuDB or {}
		ns.account, ns.char = accountKey(), charKey()
		artisanSkuDB[ns.account] = artisanSkuDB[ns.account] or {}
		artisanSkuDB[ns.account][ns.char] = artisanSkuDB[ns.account][ns.char] or {}
		ns.db, ns.cfg = artisanSkuDB[ns.account][ns.char], artisanSkuDB.__config or {}
		for key, value in pairs(ns.defaults) do if ns.cfg[key] == nil then ns.cfg[key] = value end end
		artisanSkuDB.__config = ns.cfg
		seedSources(); rebuild(); ns.ScanBags()
		C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
	elseif event == "PLAYER_LOGIN" then
		GameTooltip:HookScript("OnTooltipSetItem", addTooltip)
		ItemRefTooltip:HookScript("OnTooltipSetItem", addTooltip)
	elseif event == "BAG_UPDATE" or event == "BAG_UPDATE_DELAYED" then ns.ScanBags()
	elseif event == "BANKFRAME_OPENED" then ns.ScanBank()
	elseif event == "PLAYERBANKSLOTS_CHANGED" then ns.ScanBank()
	elseif event == "MAIL_SHOW" then ns.ScanMail()
	elseif event == "MAIL_INBOX_UPDATE" then ns.ScanMail()
	elseif event == "MAIL_SEND_SUCCESS" then ns.ScanMail()
	elseif event == "AUCTION_HOUSE_ITEM_PURCHASED" then ns.ScanBags()
	elseif event == "GROUP_ROSTER_UPDATE" then ns.Broadcast()
	elseif event == "CHAT_MSG_ADDON" and arg1 == PREFIX then merge(arg4, arg2) end
end)
