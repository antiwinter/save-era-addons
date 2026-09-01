local _, ns = ...
local BAG_ICON = "|TInterface\\ContainerFrame\\UI-Icon-Backpack:14|t"
local BANK_ICON = "|TInterface\\Icons\\INV_Misc_Bag_10:14|t"
local MAIL_ICON = "|TInterface\\Icons\\INV_Letter_15:14|t"
local function colorCode(classToken)
	local color = RAID_CLASS_COLORS[classToken]
	if not color then return "|cffffffff" end
	return ("|cff%02x%02x%02x"):format(math.floor(color.r * 255 + 0.5), math.floor(color.g * 255 + 0.5), math.floor(color.b * 255 + 0.5))
end
local function addTooltip(tooltip)
	local _, link = tooltip:GetItem()
	local itemID = link and tonumber(link:match("item:(%d+)"))
	if not itemID then return end
	local sku = ArtisanGetSku(itemID)
	if sku.total <= 0 then return end
	tooltip:AddLine("Artisan SKU", 1, 1, 0)
	local characters = {}
	for character in pairs(sku) do
		if character ~= "total" then characters[#characters + 1] = character end
	end
	table.sort(characters)
	for _, character in ipairs(characters) do
		local data = sku[character]
		local record = artisanSkuDB[character][itemID]
		local mailText = MAIL_ICON .. " " .. data.mail
		if record.mail and record.mail.d < 10 then mailText = "|cffff0000" .. mailText .. "|r" end
		local name = colorCode(artisanSkuDB[character].class) .. character .. "|r"
		tooltip:AddLine(name .. "    " .. BAG_ICON .. " " .. data.bag .. "  " .. BANK_ICON .. " " .. data.bank .. "  " .. mailText, 1, 1, 1)
	end
end
local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
	GameTooltip:HookScript("OnTooltipSetItem", addTooltip)
	ItemRefTooltip:HookScript("OnTooltipSetItem", addTooltip)
end)
