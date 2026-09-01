local PREFIX = "artisanSku"
local MAX_MESSAGE = 180
local sync = { chunks = {}, partyMembers = {} }
ns.Sync = sync
sync.PREFIX = PREFIX

local function sortedItemIDs(data)
	local ids = {}
	for itemID in pairs(data) do
		if tonumber(itemID) then ids[#ids + 1] = tonumber(itemID) end
	end
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

local function send(message)
	C_ChatInfo.SendAddonMessage(PREFIX, message, "PARTY")
end

local function partyRosterChanged()
	local current = {}
	for index = 1, 4 do
		local name = UnitName("party" .. index)
		if name then current[name] = true end
	end
	local joined = false
	for name in pairs(current) do
		if not sync.partyMembers[name] then joined = true end
	end
	sync.partyMembers = current
	return joined
end

function sync.Initialize()
	C_ChatInfo.RegisterAddonMessagePrefix(PREFIX)
end

function sync.Broadcast()
	if ns.cfg.passcode == "" or ns.db.foreign then return end
	local payload = encode(ns.db)
	local pass = escape(ns.cfg.passcode)
	local character = escape(ns.char)
	local chunks = {}
	for start = 1, #payload, MAX_MESSAGE do chunks[#chunks + 1] = payload:sub(start, start + MAX_MESSAGE - 1) end
	if #chunks == 0 then chunks[1] = "" end
	for index, chunk in ipairs(chunks) do
		send(table.concat({ "1", pass, character, ns.db.class, index, #chunks, chunk }, "|"))
	end
end

function sync.OnRosterUpdate()
	if partyRosterChanged() then sync.Broadcast() end
end

function sync.OnAddonMessage(sender, message)
	local version, pass, character, classToken, index, total, payload = message:match("^(%d+)|([^|]*)|([^|]*)|([^|]*)|(%d+)|(%d+)|(.*)$")
	if version ~= "1" or not pass or unescape(pass) ~= ns.cfg.passcode then return end
	index, total = tonumber(index), tonumber(total)
	if not index or not total then return end
	local key = sender .. ":" .. character
	local buffer = sync.chunks[key] or { total = total, parts = {} }
	buffer.total, buffer.parts[index] = total, payload
	sync.chunks[key] = buffer
	local count = 0
	for _ in pairs(buffer.parts) do count = count + 1 end
	if count < total then return end
	local data = {}
	for i = 1, total do data[#data + 1] = buffer.parts[i] or "" end
	local incoming = decode(table.concat(data))
	local characterName = unescape(character)
	local target = artisanSkuDB[characterName] or {}
	for itemID, record in pairs(incoming) do target[itemID] = record end
	for itemID in pairs(target) do if not incoming[itemID] then target[itemID] = nil end end
	target.class = classToken
	target.foreign = true
	artisanSkuDB[characterName] = target
	sync.chunks[key] = nil
end
