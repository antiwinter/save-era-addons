#!/usr/bin/env lua

package.path = "./?.lua;" .. package.path

local fw = dofile("../fake-wow/init.lua")
fw.init("era")
local ns = fw.loadAddon("artisan.toc")
local itemID = 2589

fw.GM.SetAuctions(itemID, {
	{ buyout = 1000, stackCount = 10, owner = "seller" },
	{ buyout = 450, stackCount = 5, owner = "seller2" },
	{ buyout = 900, stackCount = 3, owner = "player" },
	{ buyout = 0, stackCount = 1, owner = "seller3" },
})
fw.GM.OpenAuctionHouse()

local collect = ns.Market.Collect
ns.Market.Collect = function() return { itemID } end
assert(ns.Scanner:scan("tailor"))
assert(not ns.Scanner:scan("tailor"), "a concurrent scan was accepted")
while ns.Scanner.busy do fw.flushTimers() end
ns.Market.Collect = collect

local record = ns.Market:Get(itemID)
assert(record and record.source == "scan")
assert(record.price[1] == 90, "minimum unit buyout was not normalized")
assert(record.price[2] == 100, "maximum unit buyout was not normalized")
assert(record.price[3] == 5, "minimum listing stack count was not retained")
local buyout, cost = ns.db[itemID].buyout, ns.db[itemID].cost
assert(buyout == 90 and cost == 90, "market price was not wired through the DB")

print("native auction scan OK")
