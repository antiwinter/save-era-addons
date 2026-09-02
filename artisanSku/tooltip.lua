local _, ns = ...
local BAG_ICON = "|TInterface\\Buttons\\Button-Backpack-Up:14|t"
local BANK_ICON = "|TInterface\\Icons\\INV_Box_03:14|t"
local MAIL_ICON = "|TInterface\\Icons\\INV_Letter_15:14|t"
local BLUE = "|cff90ccff"
local WHITE = "|cffffffff"
local GRAY = "|cff606060"
local RED = "|cffff0000"
local CLOSE = "|r"
local function colorCode(classToken)
	local color = RAID_CLASS_COLORS[classToken]
	if not color then return "|cffffffff" end
	return ("|cff%02x%02x%02x"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
end
local odd = false
local function addTooltip(tooltip)
	local _, link = tooltip:GetItem()
	local itemID = link and tonumber(link:match("item:(%d+)"))
	if not itemID then return end
	local _, _, _, _, _, classID = C_Item.GetItemInfoInstant(itemID)
	if classID == 9 then
		odd = not odd
		if odd then return end
	end
	local sku = ArtisanGetSku(itemID)
	if sku.total <= 0 then return end
	tooltip:AddLine('\n')
	tooltip:AddDoubleLine("Artisan SKU " .. WHITE .. sku.total .. CLOSE,
		BAG_ICON .. " " .. BANK_ICON .. " " .. MAIL_ICON, 1, 1, 0, 1, 1, 1)
	local characters = {}
	for character in pairs(sku) do
		if character ~= "total" then characters[#characters + 1] = character end
	end
	table.sort(characters)
	for _, character in ipairs(characters) do
		local data = sku[character]
		local record = artisanSkuDB[character][itemID]
		local name = colorCode(artisanSkuDB[character].class) .. character .. "|r"
		local total = data.bag + data.bank + data.mail
		local mailColor = record.mail and record.mail.d < 10 and RED or BLUE
		local counts = BLUE .. data.bag .. CLOSE .. GRAY .. "/" .. CLOSE
			.. BLUE .. data.bank .. CLOSE .. GRAY .. "/" .. CLOSE
			.. mailColor .. data.mail .. CLOSE
		tooltip:AddDoubleLine(name .. " " .. WHITE .. total .. CLOSE, counts, 1, 1, 1, 1, 1, 1)
	end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	GameTooltip:HookScript("OnTooltipSetItem", addTooltip)
	ItemRefTooltip:HookScript("OnTooltipSetItem", addTooltip)
end)
