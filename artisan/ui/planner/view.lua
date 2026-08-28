local _, ns = ...

local pm = ns.pm
local frame = pm.frame
frame:SetSize(384, 512)
frame:SetPoint("CENTER")
frame:SetBackdrop(nil)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local function text(parent, template, point, x, y, value)
	local font = parent:CreateFontString(nil, "OVERLAY", template)
	font:SetPoint(point, x, y)
	font:SetText(value or "")
	return font
end

local function artwork(texture, width, height, point, relativePoint, x, y)
	local layer = frame:CreateTexture(nil, "BORDER")
	layer:SetTexture(texture)
	layer:SetSize(width, height)
	layer:SetPoint(point, frame, relativePoint or point, x or 0, y or 0)
	return layer
end

artwork("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopLeft", 256, 256, "TOPLEFT")
artwork("Interface\\ClassTrainerFrame\\UI-ClassTrainer-TopRight", 128, 256, "TOPRIGHT")
artwork("Interface\\TradeSkillFrame\\UI-TradeSkill-BotLeft", 256, 256, "BOTTOMLEFT")
artwork("Interface\\ClassTrainerFrame\\UI-ClassTrainer-BotRight", 128, 256, "BOTTOMRIGHT")

local function rockTile(width, height, x, y, right, bottom)
	local tile = frame:CreateTexture(nil, "ARTWORK")
	tile:SetTexture("Interface\\FrameGeneral\\UI-Background-Rock")
	tile:SetSize(width, height)
	tile:SetPoint("TOPLEFT", frame, "TOPLEFT", x, -y)
	tile:SetTexCoord(0, right or 1, 0, bottom or 1)
end

rockTile(256, 256, 18, 95)
rockTile(66, 256, 274, 95, 66 / 256)
rockTile(256, 49, 18, 351, 1, 49 / 256)
rockTile(66, 49, 274, 351, 66 / 256, 49 / 256)

local function blackPanel(panel)
	panel:SetBackdrop({
		bgFile = "Interface\\ChatFrame\\ChatFrameBackground",
		edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
		tile = true,
		tileSize = 16,
		tileEdge = true,
		edgeSize = 8,
		insets = { left = 5, right = 5, top = 5, bottom = 5 },
	})
	panel:SetBackdropColor(0, 0, 0, 1)
end

local title = text(frame, "GameFontNormal", "TOP", 0, -17, "Artisan planner")
local targetLabel = text(frame, "GameFontNormal", "TOPLEFT", 80, -40, "Target")
local targetValue = text(frame, "GameFontHighlightSmall", "TOPLEFT", 338, -54)

local target = CreateFrame("Slider", "Artisan_TargetSlider", frame, "OptionsSliderTemplate")
target:SetPoint("TOPLEFT", 144, -40)
target:SetSize(184, 18)
target:SetMinMaxValues(1, 300)
target:SetValueStep(5)

local wishlistLabel = text(frame, "GameFontNormal", "TOPLEFT", 23, -74, "Wishlist")
local search = CreateFrame("EditBox", "Artisan_WishlistSearch", frame, "InputBoxTemplate")
search:SetSize(138, 24)
search:SetPoint("TOPLEFT", 200, -68)
search:SetAutoFocus(false)
search:SetTextInsets(8, 8, 0, 0)
search:SetText("")

local results = CreateFrame("Frame", "Artisan_WishlistResults", frame, "BackdropTemplate")
results:SetSize(148, 160)
results:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -2)
blackPanel(results)
results:Hide()

local wishlist = CreateFrame("Frame", "Artisan_Wishlist", frame, "BackdropTemplate")
wishlist:SetSize(325, 42)
wishlist:SetPoint("TOPLEFT", 18, -95)
blackPanel(wishlist)

local craftLabel = text(frame, "GameFontNormal", "TOPLEFT", 23, -140, "Craft")
local bomLabel = text(frame, "GameFontNormal", "TOPLEFT", 190, -140, "BOM")

local preferExisting = CreateFrame("CheckButton", "Artisan_PreferExisting", frame, "UICheckButtonTemplate")
preferExisting:SetSize(25, 25)
preferExisting:SetPoint("TOPLEFT", 240, -137)
local preferLabel = text(frame, "GameFontDisableSmall", "TOPLEFT", 265, -140, "u/ existing")

local craftRows = CreateFrame("Frame", "Artisan_CraftRows", frame, "BackdropTemplate")
craftRows:SetSize(154, 160)
craftRows:SetPoint("TOPLEFT", 16, -157)
blackPanel(craftRows)
local bomRows = CreateFrame("Frame", "Artisan_BOMRows", frame, "BackdropTemplate")
bomRows:SetSize(163, 160)
bomRows:SetPoint("TOPLEFT", 180, -157)
blackPanel(bomRows)

local summaryLabel = text(frame, "GameFontNormal", "TOPLEFT", 23, -320, "Net cost")
local noAH = CreateFrame("CheckButton", "Artisan_NoAH", frame, "UICheckButtonTemplate")
noAH:SetSize(25, 25)
noAH:SetPoint("TOPLEFT", 100, -317)
local noAHLabel = text(frame, "GameFontDisableSmall", "TOPLEFT", 126, -320, "no AH")
local summary = text(frame, "GameFontHighlightSmall", "TOPLEFT", 18, -400)
local build = CreateFrame("Button", "Artisan_UpdatePlan", frame, "UIPanelButtonTemplate")
build:SetSize(160, 22)
build:SetPoint("TOPLEFT", 19, -410)
build:SetText("Update plan")
local start = CreateFrame("Button", "Artisan_StartCrafting", frame, "UIPanelButtonTemplate")
start:SetSize(160, 22)
start:SetPoint("TOPLEFT", 180, -410)
start:SetText("Start crafting")

local amount = CreateFrame("EditBox", "Artisan_WishlistAmount", frame, "InputBoxTemplate")
amount:SetSize(64, 24)
amount:SetPoint("TOPLEFT", 180, -118)
amount:SetAutoFocus(false)
amount:SetNumeric(true)
amount:Hide()

local rows = {}
local wishlistButtons = {}

local function gold(value)
	return string.format("%.1f |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t", value / 10000)
end

local function clear(list)
	for _, row in ipairs(list) do row:Hide() end
	for i = #list, 1, -1 do list[i] = nil end
end

local function addRow(parent, list, y, name, value, tail)
	local row = CreateFrame("Frame", nil, parent)
	row:SetSize(parent:GetWidth(), 20)
	row:SetPoint("TOPLEFT", 0, y)
	row.name = text(row, "GameFontHighlightSmall", "TOPLEFT", 14, 0)
	row.value = text(row, "GameFontHighlightSmall", "TOPRIGHT", -14, 0)
	row.name:SetText(name)
	row.value:SetText(tail and value .. tail or value)
	row:Show()
	list[#list + 1] = row
	return row
end

local function editWishlist(id)
	pm.editing = id
	amount:SetText(tostring(pm.state.wishlist[id] or 0))
	amount:Show()
	amount:SetFocus()
	amount:HighlightText()
end

local function commitWishlist()
	local id = pm.editing
	if not id then return end
	local value = tonumber(amount:GetText()) or 0
	value = math.floor(value)

	if value == pm.state.wishlist[id] then
		return
	end

	pm.state.wishlist[id] = value <= 0 and nil or value
	build:Enable()
	pm.editing = nil
	amount:Hide()
end

amount:SetScript("OnEnterPressed", commitWishlist)
amount:SetScript("OnEscapePressed", function() pm.editing = nil; amount:Hide() end)

local function showResults()
	local old = pm.resultButtons or {}
	for _, button in ipairs(old) do button:Hide() end
	pm.resultButtons = {}
	if search:GetText() == "" then
		results:Hide()
		return
	end
	local db = ns.db[pm.pk]
	local _, cap = pm:getclamp()
	for i, recipe in ipairs(pm:search(search:GetText())) do
		if i > 8 then break end
		local button = CreateFrame("Button", nil, results, "UIPanelButtonTemplate")
		button:SetSize(140, 20)
		button:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
		button:SetText(recipe.name)
		-- FIXME: also show required lvl next to name
		-- item beyond cap should be in red, click on them not adding to wl, not closing the dropdown
		button:SetScript("OnClick", function()
			local st = pm.state
			local required = db[recipe.skill_id].colors[1]
			if required > cap then return
			elseif required > st.target then
				pm:settarget(required)
				build:Enable()
			end
			editWishlist(recipe.skill_id)
			results:Hide()
		end)
		button:Show()
		pm.resultButtons[i] = button
	end
	results:Show()
end

search:SetScript("OnTextChanged", showResults)

local function updateSummary()
	local st, s = pm.state, pm.sum
	if not s then return end
	local junk = st.noAH and s.junk + s.aaj or s.junk
	local ah = st.noAH and 0 or s.ah
	summary:SetText(string.format(
		"Existing materials\t%s\nBuy materials\t%s\nJunk returns\t%s\n"
		.. "AH returns\t%s\n" .. "\nNet cost\t%s",
		gold(s.existing),
		gold(s.buy),
		gold(junk),
		gold(ah),
		gold(s.buy - junk - ah)))
end

function pm:UpdatePlan()
	local st = self.state
	local db = pm:getdb()
	if not db or not st then return end
	pm:replan()

	clear(rows)
	for _, a in ipairs(st.actions) do
		addRow(craftRows, rows, -28 - (#rows) * 20,
			GetItemInfo(a.item) or tostring(a.item), math.ceil(a.count), "  " .. a.to)
	end
	local bomRowsList = self.bomRows or {}
	clear(bomRowsList)
	self.bomRows = bomRowsList
	local existing = ns.getExistingMaterials()
	for id, n in pairs(st.materials) do
		addRow(bomRows, bomRowsList, -28 - (#bomRowsList) * 20,
			GetItemInfo(id) or tostring(id), math.floor(existing[id] or 0), "/" .. math.ceil(n))
	end

	clear(wishlistButtons)
	local i = 0
	for id, count in pairs(st.wishlist) do
		i = i + 1
		local button = CreateFrame("Button", nil, wishlist, "UIPanelButtonTemplate")
		button:SetSize(72, 32)
		button:SetPoint("TOPLEFT", (i - 1) * 76, 0)
		local icon = button:CreateTexture(nil, "ARTWORK")
		icon:SetSize(28, 28)
		icon:SetPoint("LEFT", button, "LEFT", 2, 0)
		icon:SetTexture(select(10, GetItemInfo(id)))
		button.icon = icon
		button:SetText((GetItemInfo(id) or tostring(id)) .. " " .. count)
		button:SetScript("OnClick", function() editWishlist(id) end)
		button:Show()
		wishlistButtons[i] = button
	end

	updateSummary()
	build:Disable()
end

target:SetScript("OnValueChanged", function(_, value)
	pm:settarget(value)
	build:Enable()
	targetValue:SetText(tostring(pm.state.target))
end)
preferExisting:SetScript("OnClick", function(button)
	pm.state.preferExisting = button:GetChecked()
	build:Enable()
	preferExisting:SetChecked(pm.state.preferExisting)
end)
noAH:SetScript("OnClick", function(button)
	pm.state.noAH = button:GetChecked()
	noAH:SetChecked(pm.state.noAH)
	updateSummary()
end)
build:SetScript("OnClick", function()
	pm:UpdatePlan()
end)
start:SetScript("OnClick", function()
	ns.store.cur_pk = pm.pk
	pm:replan()
	pm:snapshot()
	ns.CraftUI:Show()
end)
