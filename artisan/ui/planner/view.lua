local _, ns = ...

local pm = ns.pm
local frame = pm.frame
frame:SetSize(384, 512)
frame:SetPoint("CENTER")
frame:SetBackdrop(nil)
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", function(self)
    local parent = self:GetParent()
    local mover = parent and parent ~= UIParent and parent or self
    mover:StartMoving()
end)
frame:SetScript("OnDragStop", function(self)
    local parent = self:GetParent()
    local mover = parent and parent ~= UIParent and parent or self
    mover:StopMovingOrSizing()
end)
frame:Hide()

local ef = ns.easyFrame(frame)
ef:tile('ClassTrainerFrame\\UI-ClassTrainer-TopLeft', {
    layer = "BORDER",
    w = 256,
    h = 256
}):tile('ClassTrainerFrame\\UI-ClassTrainer-TopRight', {
    layer = "BORDER",
    w = 128,
    h = 256,
    point = "TOPRIGHT"
}):tile('TradeSkillFrame\\UI-TradeSkill-BotLeft', {
    layer = "BORDER",
    w = 256,
    h = 256,
    point = "BOTTOMLEFT"
}):tile('ClassTrainerFrame\\UI-ClassTrainer-BotRight', {
    layer = "BORDER",
    w = 128,
    h = 256,
    point = "BOTTOMRIGHT"
})

ef:text('Artisan planner', {
    x = 0,
    y = -17,
	point = "TOP",
	rp = "TOP"
})
:tile("FrameGeneral\\UI-Background-Rock", {
    w = 256,
    h = 256,
    x = 18,
    y = -95
})
:tile("FrameGeneral\\UI-Background-Rock", {
    w = 68,
    h = 256,
    x = 274,
    y = -95,
    r = 68 / 256
})
:tile("FrameGeneral\\UI-Background-Rock", {
    w = 256,
    h = 58,
    x = 18,
    y = -351,
    b = 58 / 256
})
:tile("FrameGeneral\\UI-Background-Rock", {
    w = 66,
    h = 58,
    x = 274,
    y = -351,
    r = 68 / 256,
    b = 58 / 256
})

local _, targetText = ef:text('Target', {
    x = 80,
    y = -40
}):text('', {
    x = 338,
    y = -54,
    font = 'GameFontHighlightSmall'
})
local targetSlider = ef:widget('Slider', {
    x = 144,
    y = -40,
    w = 184,
    h = 18
})
targetSlider:SetMinMaxValues(1, 300)
targetSlider:SetValueStep(5)

local wishBox = ef:text('Wishlist', {
    x = 23,
    y = -74
}):box({
    w = 318,
    h = 42,
    x = 20,
    y = -95
})
local amountBox = ef:widget('EditBox', {
    w = 64,
    h = 24,
    x = 180,
    y = -118,
    numeric = true
})
amountBox:Hide()

local search = ef:widget('EditBox', {
    x = 200,
    y = -68,
    w = 138,
    h = 24
})
search:SetAutoFocus(false)
search:SetTextInsets(8, 8, 0, 0)
search:SetText('')
local resultBox = ef:box({
    w = 148,
    h = 160,
    rp = "BOTTOMLEFT",
    y = -2
})
resultBox:Hide()

local craftBox = ef:text('Craft', {
    x = 23,
    y = -140
}):box({
    w = 154,
    h = 160,
    x = 20,
    y = -159
})
local bom = ef:text('Craft', {
    x = 190,
    y = -140
}):box({
    w = 158,
    h = 160,
    x = 180,
    y = -159
})

local preferExisting = ef:text('u/ existing', {
    x = 265,
    y = -140,
    font = 'GameFontDisableSmall'
}):widget('CheckButton', {
    w = 25,
    h = 25,
    x = 240,
    y = -137
})

local summaryDetails, summary = ef:text('Net cost', {
    x = 23,
    y = -327
}):box({
    x = 20,
    y = -347,
    w = 318,
    h = 55
}):text('', {
    font = 'GameFontHighlightSmall'
})

local noAH = ef:text('no AH', {
    x = 126,
    y = -327,
    font = 'GameFontDisableSmall'
}):widget('CheckButton', {
    w = 25,
    h = 25,
    x = 100,
    y = -325
})

local build = ef:widget('Button', {
    name = 'Artisan_UpdatePlan',
    w = 160,
    h = 22,
    x = 19,
    y = -410,
    text = 'Update plan'
})
local start = ef:widget('Button', {
    name = 'Artisan_StartCrafting',
    w = 160,
    h = 22,
    x = 180,
    y = -410,
    text = 'Start crafting'
})

local function gold(value)
    return string.format("%.1f |TInterface\\MoneyFrame\\UI-GoldIcon:12:12:0:0|t", value / 10000)
end

local function editWishlist(id)
    pm.editing = id
    amountBox:SetText(tostring(pm.state.wishlist[id] or 0))
    amountBox:Show()
    amountBox:SetFocus()
    amountBox:HighlightText()
end

local function updateWish()
    wishBox:clear()
    local i = 0
    for id, count in pairs(pm.state.wishlist) do
        i = i + 1
        local button = wishBox:widget('Button', {
            w = 28,
            h = 28,
            x = i * 30 + 5
        }):tile(select(10, GetItemInfo(id))):text(count, {
            x = 20,
            y = 20
        })

        button:SetScript("OnClick", function()
            editWishlist(id)
        end)
        button:SetScript("OnMouseOver", function()
            -- FIXME: show tooltip, name
        end)
        button:Show()
    end
end

local function commitWishlist()
    local id = pm.editing
    if not id then
        return
    end
    local value = tonumber(amountBox:GetText()) or 0
    value = math.floor(value)

    if value == pm.state.wishlist[id] then
        return
    end

    pm.state.wishlist[id] = value <= 0 and nil or value
    build:Enable()
    pm.editing = nil
    amountBox:Hide()
end

amountBox:SetScript("OnEnterPressed", commitWishlist)
amountBox:SetScript("OnEscapePressed", function()
    pm.editing = nil;
    amountBox:Hide()
end)

local function searchResults()
    if search:GetText() == "" then
        resultBox:clear()
        resultBox:Hide()
        return
    end
    local _, cap = pm:getclamp()
    resultBox:clear()
    for i, r in ipairs(pm:search(search:GetText())) do
        if i > 8 then
            break
        end

        local button = resultBox:widget('Button', {
            w = 140,
            h = 20,
            x = 4,
            y = -4 - (i - 1) * 20
        })
        button:SetText(r.name .. r.req)
        -- FIXME: also show required lvl next to name
        -- item beyond cap should be in red, click on them not adding to wl, not closing the dropdown
        button:SetScript("OnClick", function()
            local st = pm.state
            if r.req > cap then
                return
            elseif r.req > st.target then
                pm:settarget(r.req)
                build:Enable()
            end
            editWishlist(r.skill_id)
            resultBox:Hide()
        end)
        button:Show()
    end
    resultBox:Show()
end

search:SetScript("OnTextChanged", searchResults)

local function updateSummary()
    local st, s = pm.state, pm.sum
    if not s then
        return
    end
    local junk = st.noAH and s.junk + s.aaj or s.junk
    local ah = st.noAH and 0 or s.ah
    summary:SetText(string.format(
        "Existing materials\t%s\nBuy materials\t%s\nJunk returns\t%s\n" .. "AH returns\t%s\n" .. "\nNet cost\t%s",
        gold(s.existing), gold(s.buy), gold(junk), gold(ah), gold(s.buy - junk - ah)))
end

function pm:UpdatePlan()
    local st = self.state
    pm:replan()

    updateWish()
    craftBox:clear()
    bom:clear()

    for _, a in ipairs(st.actions) do
        local row = craftBox:ef({
            h = 20,
            y = -28 - (craftBox:len()) * 20
        })
        row:text(GetItemInfo(a.item) or tostring(a.item), {x = 14})
        row:text(math.ceil(a.count), {point = "TOPRIGHT", x = -50})
        row:text(a.to, {point = "TOPRIGHT", x = -14})
    end
    local existing = ns.getExistingMaterials()
    for id, n in pairs(st.materials) do
        local row = bom:ef({
            h = 20,
            y = -28 - (bom:len()) * 20
        })
        row:text(GetItemInfo(id) or tostring(id), {x = 14})
        row:text(math.floor(existing[id] or 0), {point = "TOPRIGHT", x = -50})
        row:text("/" .. math.ceil(n), {point = "TOPRIGHT", x = -14})
    end

    updateSummary()
    build:Disable()
end

targetSlider:SetScript("OnValueChanged", function(_, value)
    pm:settarget(value)
    build:Enable()
    targetText:SetText(tostring(pm.state.target))
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
