local addonName, ns = ...

local Market = {}
Market.__index = Market

local function validID(id)
	return type(id) == "number" and id > 0 and id % 1 == 0
end

local function validRecord(record)
	if type(record) ~= "table" or type(record.price) ~= "table" then return false end
	local min, max, count = record.price[1], record.price[2], record.price[3]
	if type(min) ~= "number" or min <= 0 or min % 1 ~= 0 then return false end
	if type(max) ~= "number" or max < min or max % 1 ~= 0 then return false end
	if count ~= nil and (type(count) ~= "number" or count <= 0 or count % 1 ~= 0) then return false end
	if record.source ~= "at" and record.source ~= "tsm" and record.source ~= "scan" then return false end
	return type(record.updatedAt) == "number" and record.updatedAt > 0 and record.updatedAt % 1 == 0
end

local function professionKeys()
	local keys = {}
	for pk in pairs(ns.db) do keys[#keys + 1] = pk end
	table.sort(keys)
	return keys
end

function Market:deferRefreshCost()
	if self.refreshTimer then self.refreshTimer:Cancel() end
	self.refreshTimer = C_Timer.NewTimer(1, function()
		self.refreshTimer = nil
		for _, pk in ipairs(professionKeys()) do ns.db[pk]:refreshCost() end
	end)
end

function Market:Init()
	artisanDB.market = type(artisanDB.market) == "table" and artisanDB.market or {}
	artisanDB.market[ns.realm] = type(artisanDB.market[ns.realm]) == "table"
		and artisanDB.market[ns.realm] or {}
	self.records = artisanDB.market[ns.realm]

	local ids = self:Collect(professionKeys())
	local result = self:LoadCached(ids)
	self:deferRefreshCost()

	if ns.DEBUG then
		print(string.format("[art] market: Auctionator=%s TSM=%s imported=%d",
			tostring(result.providers.auctionator), tostring(result.providers.tsm), result.updated))
	end
	return self
end

function Market:Put(realm, itemID, record)
	if type(realm) ~= "string" or realm == "" or not validID(itemID) or not validRecord(record) then
		return false, "invalid"
	end
	local old = artisanDB.market[realm][itemID]
	if old and record.updatedAt <= old.updatedAt then return false, "older" end

	artisanDB.market[realm][itemID] = {
		price = { record.price[1], record.price[2], record.price[3] },
		source = record.source,
		updatedAt = record.updatedAt,
	}
	if realm == ns.realm then
		self.records = artisanDB.market[realm]
		self:deferRefreshCost()
	end
	return true, "updated"
end

function Market:Get(realm, itemID)
	local bucket = artisanDB.market[realm or ns.realm]
	return bucket and bucket[itemID]
end

function Market:GetUnitPrice(realm, itemID, now)
	local record = self:Get(realm, itemID)
	if not record then return nil end
	return record.price[1], record.source, record.updatedAt, (now or time()) - record.updatedAt
end

function Market:Collect(keys)
	local ids, seen, rows = {}, {}, {}
	for _, pk in ipairs(keys or {}) do
		rows[pk] = {}
		for _, row in ipairs(skills[pk] or {}) do rows[pk][row[1]] = row end
	end

	local function add(id)
		if validID(id) and not seen[id] then
			seen[id] = true
			ids[#ids + 1] = id
		end
	end
	local function walk(pk, itemID, active)
		add(itemID)
		local row = rows[pk] and rows[pk][itemID]
		if not row or active[itemID] then return end
		active[itemID] = true
		if row[5] and row[5] > 0 then add(row[5]) end
		for _, reagent in ipairs(row[6] or {}) do walk(pk, reagent[1], active) end
		active[itemID] = nil
	end

	for _, pk in ipairs(keys or {}) do
		for _, row in ipairs(skills[pk] or {}) do walk(pk, row[1], {}) end
	end
	return ids
end

local function auctionatorValue(itemID)
	local api = Auctionator and Auctionator.API and Auctionator.API.v1
	if not api or type(api.GetAuctionPriceByItemID) ~= "function" then return nil end
	local value = api.GetAuctionPriceByItemID(addonName, itemID)
	if type(value) ~= "number" or value <= 0 then return nil end
	local age = type(api.GetAuctionAgeByItemID) == "function"
		and api.GetAuctionAgeByItemID(addonName, itemID) or 0
	return {
		price = { math.floor(value), math.floor(value), nil },
		source = "at",
		updatedAt = time() - (type(age) == "number" and age or 0),
	}
end

local function tsmValue(itemID)
	if not TSM_API or type(TSM_API.GetCustomPriceValue) ~= "function" then return nil end
	local value = TSM_API.GetCustomPriceValue("DBMinBuyout", "i:" .. itemID)
	if type(value) ~= "number" or value <= 0 then return nil end
	return {
		price = { math.floor(value), math.floor(value), nil },
		source = "tsm",
		updatedAt = time(),
	}
end

function Market:LoadCached(itemIDs)
	local result = {
		updated = 0,
		providers = {
			auctionator = Auctionator and Auctionator.API and Auctionator.API.v1 ~= nil,
			tsm = TSM_API ~= nil,
		},
	}
	for _, itemID in ipairs(itemIDs or {}) do
		local record = auctionatorValue(itemID) or tsmValue(itemID)
		if record and self:Put(ns.realm, itemID, record) then
			result.updated = result.updated + 1
		end
	end
	return result
end

ns.Market = setmetatable({}, Market)
