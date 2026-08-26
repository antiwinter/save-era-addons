local _, ns = ...
local frame = ns.PlannerUI.frame

frame:SetSize(430, 280)
frame:SetPoint("CENTER")
frame:SetMovable(true)
frame:EnableMouse(true)
frame:RegisterForDrag("LeftButton")
frame:SetScript("OnDragStart", frame.StartMoving)
frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
frame:Hide()

local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -12)
title:SetText("Artisan planner")

local body = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
body:SetPoint("TOPLEFT", 18, -48)
body:SetText("Planner skeleton\n\nThis is where the pk plan editor will go.\nTarget selection, recipe choices, and material projections\nwill be designed here in a later pass.")

local footer = frame:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
footer:SetPoint("BOTTOM", 0, 14)
footer:SetText("Artisan planner footer")
