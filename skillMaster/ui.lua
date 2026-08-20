local addonName, ns = ...

-- ui.lua — minimal panel that shows the next action + shopping list and a
-- single "Craft" button. The button is the ONLY path to crafting, keeping
-- DoTradeSkill player-initiated (one click per batch).

local panel = CreateFrame("Frame", "skillMasterPanel", UIParent, "BackdropTemplate")
panel:SetSize(220, 120)
panel:SetPoint("CENTER")
panel:SetMovable(true)
panel:EnableMouse(true)
panel:RegisterForDrag("LeftButton")
panel:SetScript("OnDragStart", panel.StartMoving)
panel:SetScript("OnDragStop", panel.StopMovingOrSizing)
panel:Hide()

local title = panel:CreateFontString(nil, "OVERLAY", "GameFontNormal")
title:SetPoint("TOP", 0, -8)
title:SetText("skillMaster")

local status = panel:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
status:SetPoint("TOP", title, "BOTTOM", 0, -6)
status:SetText("Open a trade skill.")

local craftBtn = CreateFrame("Button", "SkillMaster_CraftBtn", panel, "UIPanelButtonTemplate")
craftBtn:SetSize(180, 24)
craftBtn:SetPoint("BOTTOM", 0, 12)
craftBtn:SetText("Craft next")
craftBtn:SetScript("OnClick", function()
	status:SetText(ns.Runtime:DoAction())
end)

-- Refresh display from live runtime state. Registered as the runtime callback.
function ns.OnRuntimeUpdate()
	local R = ns.Runtime
	if not R:ProfKey() then
		status:SetText((R.skill.name or "?") .. ": no data")
		return
	end
	if #R.plan == 0 then R:BuildPlan() end
	local ac = R:CurrentAction()
	if ac then
		status:SetText(string.format("%s %d/%d\nNext: %s -> %d",
			R.skill.name, R.skill.lvl, ns.cfg.target or R.skill.cap,
			GetItemInfo(ac.item) or ac.item, ac.to))
	else
		status:SetText(string.format("%s %d — plan complete", R.skill.name, R.skill.lvl))
	end
end

SLASH_SKILLMASTER1 = "/skm"
SlashCmdList.SKILLMASTER = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "debug" then
		if ns.Debug then ns.Debug() end
	elseif msg == "plan" then
		local R = ns.Runtime
		if #R.plan == 0 then R:BuildPlan() end
		ns.Format.Print(R.plan, R.material, GetItemInfo, function(line) print("|cff00b4ff[skm]|r " .. line) end)
	elseif msg == "hide" then
		panel:Hide()
	else
		panel:Show()
		ns.OnRuntimeUpdate()
	end
end

-- TEST: era sources of localized profession names
do
	print("|cff00b4ff[skm]|r locale=" .. (GetLocale() or "?") .. " build=" .. tostring(select(4, GetBuildInfo())))
	print("|cff00b4ff[skm]|r GetTradeSkillLine()=" .. tostring(GetTradeSkillLine()))

	local n = GetNumSkillLines()
	print("|cff00b4ff[skm]|r GetNumSkillLines()=" .. tostring(n))
	for i = 1, n do
		local name, header, _, rank, _, _, maxRank = GetSkillLineInfo(i)
		if not name then break end
		print(string.format("|cff00b4ff[skm]|r   [%d]%s %s  %d/%d",
			i, header and "H:" or "", name, rank or 0, maxRank or 0))
	end

	local bySkill = {}
	for i = 1, n do
		local name, header = GetSkillLineInfo(i)
		if not name then break end
		if not header then bySkill[name] = true end
	end

	-- profession == 4 rank spells (Apprentice..Artisan) with stable classic
	-- ids; GetSpellInfo(id) yields the localized skill-line name regardless
	-- of which rank the player trained (锻造 / Blacksmithing / ...).
	local PROF_SPELL = {
		{ "eng",   {4036, 4037, 4038, 12656} },
		{ "tailor",{3908, 3909, 3910, 12180} },
		{ "alch",  {2259, 3101, 3464, 11611} },
		{ "bs",    {2018, 3100, 3538, 9785} },
		{ "ench",  {7411, 7412, 7413, 13920} },
		{ "cook",  {2550, 3102, 3413, 18260} },
		{ "fish",  {7620, 7731, 7732, 18248} },
		{ "fa",    {3273, 3274, 7924, 10846} },
		{ "herb",  {2366, 2368, 3570, 11993} },
		{ "mine",  {2575, 2576, 3564, 10248} },
		{ "skin",  {8613, 8617, 8618, 10768} },
	}
	print("|cff00b4ff[skm]|r profession spell names (matched against skill list):")
	for _, p in ipairs(PROF_SPELL) do
		for _, sid in ipairs(p[2]) do
			local loc = GetSpellInfo(sid)
			print(string.format("|cff00b4ff[skm]|r   %-6s id=%d -> %s  (in skill list: %s)",
				p[1], sid, tostring(loc), tostring(loc and bySkill[loc] == true)))
		end
	end
end