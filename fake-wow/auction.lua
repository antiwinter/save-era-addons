local function install(env, world)
	world.auctions = world.auctions or {}
	world.auctionResults = {}
	world.auctionQueryPending = false

	local frame = env.CreateFrame("Frame", "AuctionFrame", env.UIParent)
	frame:Hide()

	function env.CanSendAuctionQuery()
		return frame:IsShown() and not world.auctionQueryPending
	end

	function env.QueryAuctionItems(name, _, _, page, _, _, _, exact)
		assert(frame:IsShown(), "auction house is closed")
		world.auctionQueryPending = true
		env.C_Timer.NewTimer(0, function()
			local matches = {}
			for itemID, auctions in pairs(world.auctions) do
				local itemName = env.GetItemInfo(itemID)
				local found = exact and itemName == name
					or not exact and itemName and itemName:lower():find(name:lower(), 1, true)
				if found then
					for _, auction in ipairs(auctions) do
						matches[#matches + 1] = {
							itemID = itemID,
							stackCount = auction.stackCount,
							buyout = auction.buyout,
							owner = auction.owner,
							ownerFull = auction.ownerFull,
						}
					end
				end
			end
			local first = (page or 0) * 50 + 1
			world.auctionResults = {}
			for index = first, math.min(first + 49, #matches) do
				world.auctionResults[#world.auctionResults + 1] = matches[index]
			end
			world.auctionQueryPending = false
			env.__fire("AUCTION_ITEM_LIST_UPDATE")
		end)
		return true
	end

	function env.GetNumAuctionItems(kind)
		if kind ~= "list" then return 0, 0 end
		return #world.auctionResults, #world.auctionResults
	end

	function env.GetAuctionItemInfo(kind, index)
		if kind ~= "list" then return nil end
		local auction = world.auctionResults[index]
		if not auction then return nil end
		return env.GetItemInfo(auction.itemID), nil, auction.stackCount,
			nil, nil, nil, nil, nil, nil, auction.buyout,
			nil, nil, nil, auction.owner, auction.ownerFull
	end

	function env.GetAuctionItemLink(kind, index)
		if kind ~= "list" then return nil end
		local auction = world.auctionResults[index]
		if not auction then return nil end
		return "|cff00ff00|Hitem:" .. auction.itemID .. ":0:0:0:0:0:0:0|h["
			.. env.GetItemInfo(auction.itemID) .. "]|h|r"
	end

	function env.GM.OpenAuctionHouse()
		frame:Show()
		env.__fire("AUCTION_HOUSE_SHOW")
	end

	function env.GM.CloseAuctionHouse()
		frame:Hide()
		env.__fire("AUCTION_HOUSE_CLOSED")
	end

	function env.GM.SetAuctions(itemID, auctions)
		world.auctions[itemID] = auctions
	end

	function env.GM.ClearAuctions()
		world.auctions = {}
		world.auctionResults = {}
	end
end

return { install = install }
