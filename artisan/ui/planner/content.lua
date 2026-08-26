local _, ns = ...

local Planner = ns.PlannerUI
local frame = Planner.frame
frame:SetSize(492, 628)
frame:SetPoint("CENTER")
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

local title = text(frame, "GameFontNormal", "TOP", 0, -8, "Artisan planner")
local targetLabel = text(frame, "GameFontNormal", "TOPLEFT", 18, -52, "Target level")
local targetValue = text(frame, "GameFontHighlightSmall", "TOPLEFT", 382, -54)

local target = CreateFrame("Slider", "Artisan_TargetSlider", frame, "OptionsSliderTemplate")
target:SetPoint("TOPLEFT", 186, -48)
target:SetSize(274, 18)
target:SetMinMaxValues(1, 300)
target:SetValueStep(1)

local wishlistLabel = text(frame, "GameFontNormal", "TOPLEFT", 18, -116, "Wishlist")
local search = CreateFrame("EditBox", "Artisan_WishlistSearch", frame, "InputBoxTemplate")
search:SetSize(148, 24)
search:SetPoint("TOPLEFT", 312, -108)
search:SetAutoFocus(false)
search:SetTextInsets(8, 8, 0, 0)
search:SetText("")

local results = CreateFrame("Frame", "Artisan_WishlistResults", frame, "BackdropTemplate")
results:SetSize(148, 160)
results:SetPoint("TOPLEFT", search, "BOTTOMLEFT", 0, -2)
results:Hide()

local wishlist = CreateFrame("Frame", "Artisan_Wishlist", frame)
wishlist:SetSize(440, 42)
wishlist:SetPoint("TOPLEFT", 18, -142)

local craftLabel = text(frame, "GameFontNormal", "TOPLEFT", 18, -202, "Craft")
local bomLabel = text(frame, "GameFontNormal", "TOPLEFT", 280, -202, "BOM")

local preferExisting = CreateFrame("CheckButton", "Artisan_PreferExisting", frame, "UICheckButtonTemplate")
preferExisting:SetPoint("TOPLEFT", 346, -200)
local preferLabel = text(frame, "GameFontDisableSmall", "TOPLEFT", 374, -203, "prefer use existing")

local craftRows = CreateFrame("Frame", "Artisan_CraftRows", frame, "BackdropTemplate")
craftRows:SetSize(236, 247)
craftRows:SetPoint("TOPLEFT", 16, -225)
local bomRows = CreateFrame("Frame", "Artisan_BOMRows", frame, "BackdropTemplate")
bomRows:SetSize(212, 247)
bomRows:SetPoint("TOPLEFT", 264, -225)

local summaryLabel = text(frame, "GameFontNormal", "TOPLEFT", 18, -500, "Summary")
local noAH = CreateFrame("CheckButton", "Artisan_NoAH", frame, "UICheckButtonTemplate")
noAH:SetPoint("TOPLEFT", 128, -496)
local noAHLabel = text(frame, "GameFontDisableSmall", "TOPLEFT", 154, -499, "no AH")
local summary = text(frame, "GameFontHighlightSmall", "TOPLEFT", 26, -524)
local start = CreateFrame("Button", "Artisan_StartCrafting", frame, "UIPanelButtonTemplate")
start:SetSize(140, 24)
start:SetPoint("TOPLEFT", 330, -496)
start:SetText("Start crafting")

local amount = CreateFrame("EditBox", "Artisan_WishlistAmount", frame, "InputBoxTemplate")
amount:SetSize(64, 24)
amount:SetPoint("TOPLEFT", 214, -142)
amount:SetAutoFocus(false)
amount:SetNumeric(true)
amount:Hide()

local updating = false
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

local function setTarget(value)
	local state = Planner:State()
	local skill, cap = ns.getTradeSkillRange(Planner.pk)
	value = math.max(skill, math.min(cap, math.floor(value + 0.5)))
	state.target = value
	targetValue:SetText(tostring(value))
	if not updating then Planner:Refresh() end
end

local function editWishlist(id)
	Planner.editing = id
	amount:SetText(tostring(Planner:State().wishlist[id] or 0))
	amount:Show()
	amount:SetFocus()
	amount:HighlightText()
end

local function commitWishlist()
	local id = Planner.editing
	if not id then return end
	local value = tonumber(amount:GetText()) or 0
	local state = Planner:State()
	if value <= 0 then state.wishlist[id] = nil else state.wishlist[id] = math.floor(value) end
	Planner.editing = nil
	amount:Hide()
	Planner:Refresh()
end

amount:SetScript("OnEnterPressed", commitWishlist)
amount:SetScript("OnEscapePressed", function() Planner.editing = nil; amount:Hide() end)

local function showResults()
	local db = ns.db[Planner.pk]
	local old = Planner.resultButtons or {}
	for _, button in ipairs(old) do button:Hide() end
	Planner.resultButtons = {}
	for i, recipe in ipairs(ns.PlannerModel:Search(db, search:GetText())) do
		if i > 8 then break end
		local button = CreateFrame("Button", nil, results, "UIPanelButtonTemplate")
		button:SetSize(140, 20)
		button:SetPoint("TOPLEFT", 4, -4 - (i - 1) * 20)
		button:SetText(recipe.name)
		button:SetScript("OnClick", function()
			local state = Planner:State()
			local skill, cap = ns.getTradeSkillRange(Planner.pk)
			local nextTarget, err = ns.PlannerModel:ValidateWishlist(db, recipe.skill_id, state.target, cap)
			if not nextTarget then ns.hint(err); return end
			state.target = nextTarget
			editWishlist(recipe.skill_id)
			results:Hide()
		end)
		button:Show()
		Planner.resultButtons[i] = button
	end
	results:Show()
end

search:SetScript("OnTextChanged", showResults)

function Planner:Refresh()
	local state = self:State()
	local result, message = ns.PlannerModel:Build(self.pk, state)
	if not result then summary:SetText(message or "No plan"); return end
	self.result = result
	updating = true
	target:SetValue(result.target)
	updating = false
	targetValue:SetText(tostring(result.target))
	preferExisting:SetChecked(state.preferExisting)
	noAH:SetChecked(state.noAH)

	clear(rows)
	for _, action in ipairs(result.plan.actions) do
		addRow(craftRows, rows, -28 - (#rows) * 20,
			GetItemInfo(action.item) or tostring(action.item), math.ceil(action.count), "  " .. action.to)
	end
	local bomRowsList = self.bomRows or {}
	clear(bomRowsList)
	self.bomRows = bomRowsList
	for id, required in pairs(result.plan.materials) do
		addRow(bomRows, bomRowsList, -28 - (#bomRowsList) * 20,
			GetItemInfo(id) or tostring(id), math.floor(result.existing[id] or 0), "/" .. math.ceil(required))
	end

	clear(wishlistButtons)
	local i = 0
	for id, count in pairs(state.wishlist) do
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

	local s = result.summary
	summary:SetText(string.format(
		"Existing materials\t%s\nBuy materials\t%s\nJunk returns\t%s\nAH returns\t%s\n\nNet cost\t%s",
		gold(s.existing), gold(s.buy), gold(s.junk), gold(s.ah), gold(s.net)))
end

target:SetScript("OnValueChanged", function(_, value) setTarget(value) end)
preferExisting:SetScript("OnClick", function(button)
	Planner:State().preferExisting = button:GetChecked()
	Planner:Refresh()
end)
noAH:SetScript("OnClick", function(button)
	Planner:State().noAH = button:GetChecked()
	Planner:Refresh()
end)
start:SetScript("OnClick", function()
	ns.store.cur_pk = Planner.pk
	ns.CraftUI:Show()
end)
