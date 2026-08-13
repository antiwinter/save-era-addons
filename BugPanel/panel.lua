local addonName, ns = ...

local window, scroll, content, title
local rows = {}
local expanded = {} -- errorObject -> true while its body is open
local copyBox

local ROW_W = 320
local PAD = 12

-- Path + line + one-line reason, pulled from the raw message. Message looks
-- like "AddOns/Foo/bar.lua:12: attempt to ...". We split on the first colon
-- pair so path:line and reason can be colored separately.
local function headerText(e)
	local msg = tostring(e.message or "?"):gsub("\n.*", "")
	msg = msg:gsub("Interface/AddOns/", ""):gsub("%.?%.?%.?/?AddOns/", "")
	local path, line, reason = msg:match("^(.-):(%d+): (.*)$")
	local when = e.time and date("%H:%M:%S", e.time) or "?"
	local locus = path and ("|cffffffff%s|r:|cff00ff00%s|r"):format(path, line) or ("|cffffffff%s|r"):format(msg)
	local header = ("|cffff4411%dx|r  %s  |cffaaaaaa%s|r"):format(e.counter or 1, locus, when)
	if reason then header = header .. "\n|cffffd200" .. reason .. "|r" end
	return header
end

-- Full stack + locals for the expanded body, lightly colored for scanning.
-- Locals are capped: a single FontString has a max rendered height, and a large
-- dump (multi-KB) overflows it, leaving a blank gap where glyphs stop laying
-- out. The full text is always available via right-click copy (rawText).
local LOCALS_CAP = 1500
local function bodyText(e)
	local s = tostring(e.stack or "")
	s = s:gsub("Interface/AddOns/", ""):gsub("%.?%.?%.?/?AddOns/", "")
	s = s:gsub(":(%d+)", ":|cff00ff00%1|r")
	local l = ""
	if e.locals then
		local lo = tostring(e.locals)
		if #lo > LOCALS_CAP then
			lo = lo:sub(1, LOCALS_CAP) .. "\n|cff888888…(truncated, right-click to copy)|r"
		end
		l = "\n\n|cffaaaaaaLocals:|r\n" .. lo
	end
	return "|cffcccccc" .. s .. "|r" .. l
end

-- Uncolored, complete text for copy-out.
local function rawText(e)
	local parts = { tostring(e.message or "") }
	if e.stack then parts[#parts + 1] = tostring(e.stack) end
	if e.locals then parts[#parts + 1] = "\nLocals:\n" .. tostring(e.locals) end
	return table.concat(parts, "\n")
end

local function showCopy(e)
	if not copyBox then
		local frame = CreateFrame("Frame", nil, window, "BackdropTemplate")
		frame:SetPoint("TOPLEFT", 8, -8)
		frame:SetPoint("BOTTOMRIGHT", -8, 8)
		frame:SetFrameStrata("DIALOG")
		frame:SetFrameLevel(window:GetFrameLevel() + 20)
		frame:SetBackdrop({ bgFile = "Interface\\ChatFrame\\ChatFrameBackground" })
		frame:SetBackdropColor(0, 0, 0, 0.95)
		frame:EnableMouse(true)

		local hint = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
		hint:SetPoint("TOP", 0, -6)
		hint:SetText("Ctrl+C to copy, Esc to close")

		local sf = CreateFrame("ScrollFrame", nil, frame, "UIPanelScrollFrameTemplate")
		sf:SetPoint("TOPLEFT", 10, -24)
		sf:SetPoint("BOTTOMRIGHT", -30, 10)
		local eb = CreateFrame("EditBox", nil, sf)
		eb:SetMultiLine(true)
		eb:SetFontObject(ChatFontNormal)
		eb:SetAutoFocus(false)
		eb:SetWidth(ROW_W - 40)
		eb:SetScript("OnEscapePressed", function() frame:Hide() end)
		sf:SetScrollChild(eb)
		frame.editBox = eb
		copyBox = frame
	end
	copyBox.editBox:SetText(rawText(e))
	copyBox.editBox:HighlightText()
	copyBox.editBox:SetFocus()
	copyBox:Show()
end

local function acquireRow(i)
	local row = rows[i]
	if row then return row end

	row = CreateFrame("Button", nil, content)
	row:SetWidth(ROW_W)
	row:RegisterForClicks("LeftButtonUp", "RightButtonUp")

	local bg = row:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetColorTexture(1, 1, 1, 0.05)
	row.bg = bg
	row:SetScript("OnEnter", function() bg:SetColorTexture(1, 1, 1, 0.12) end)
	row:SetScript("OnLeave", function() bg:SetColorTexture(1, 1, 1, 0.05) end)

	local head = row:CreateFontString(nil, "OVERLAY", "GameFontNormalLeft")
	head:SetPoint("TOPLEFT", PAD, -4)
	head:SetWidth(ROW_W - PAD * 2)
	head:SetJustifyH("LEFT")
	row.head = head

	local body = row:CreateFontString(nil, "OVERLAY", "GameFontDisableSmallLeft")
	body:SetPoint("TOPLEFT", head, "BOTTOMLEFT", 0, -4)
	body:SetWidth(ROW_W - PAD * 2)
	body:SetJustifyH("LEFT")
	body:SetNonSpaceWrap(true) -- break tokens wider than the column (long global names)
	row.body = body

	row:SetScript("OnClick", function(self, button)
		if button == "RightButton" then
			showCopy(self.err)
		else
			expanded[self.err] = not expanded[self.err] or nil
			ns.Refresh()
		end
	end)

	rows[i] = row
	return row
end

-- Height comes from the FontStrings' rendered bottoms, not from a summed
-- GetStringHeight(): the latter over-reports for word-wrapped text queried in
-- the same frame SetText ran, which left a growing gap below the header as the
-- window narrowed. We anchor each row's height/position to what actually got
-- laid out, one frame after the text is set.
local function reposition()
	local errors = ns.SessionErrors()
	local y = 0
	for i = #errors, 1, -1 do -- newest first
		local e = errors[i]
		local row = rows[#errors - i + 1]
		if not row then break end

		local h = row.head:GetStringHeight() + 8
		if expanded[e] and row.body:IsShown() then
			h = h + row.body:GetStringHeight() + 8
		end

		row:SetHeight(h)
		row:ClearAllPoints()
		row:SetPoint("TOPLEFT", content, "TOPLEFT", 0, -y)
		y = y + h + 2
	end
	content:SetHeight(math.max(y, 1))
end

local function layout(errors)
	for i = #errors, 1, -1 do -- newest first
		local e = errors[i]
		local row = acquireRow(#errors - i + 1)
		row.err = e
		row.head:SetText(headerText(e))
		if expanded[e] then
			row.body:SetText(bodyText(e))
			row.body:Show()
		else
			row.body:Hide()
		end
		row:Show()
	end

	for i = #errors + 1, #rows do
		rows[i]:Hide()
	end

	-- Let the engine wrap/lay out the strings, then size rows next frame.
	reposition()
	C_Timer.After(0, reposition)
end

local function build()
	window = CreateFrame("Frame", "BugPanelFrame", UIParent, "BackdropTemplate")
	window:Hide()
	window:SetFrameStrata("DIALOG")
	window:SetSize(ROW_W + 60, 520)
	window:SetPoint(ns.db.point, UIParent, ns.db.point, ns.db.x, ns.db.y)
	window:SetMovable(true)
	window:EnableMouse(true)
	window:RegisterForDrag("LeftButton")
	window:SetClampedToScreen(true)
	window:SetScript("OnDragStart", window.StartMoving)
	window:SetScript("OnDragStop", function(self)
		self:StopMovingOrSizing()
		local p, _, _, x, yy = self:GetPoint()
		ns.db.point, ns.db.x, ns.db.y = p, x, yy
	end)
	window:SetBackdrop({
		bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
		edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
		tile = true, tileSize = 32, edgeSize = 32,
		insets = { left = 8, right = 8, top = 8, bottom = 8 },
	})

	title = window:CreateFontString(nil, "OVERLAY", "GameFontNormal")
	title:SetPoint("TOPLEFT", 16, -14)

	local close = CreateFrame("Button", nil, window, "UIPanelCloseButton")
	close:SetPoint("TOPRIGHT", -6, -6)

	scroll = CreateFrame("ScrollFrame", "BugPanelScroll", window, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 14, -36)
	scroll:SetPoint("BOTTOMRIGHT", -32, 14)

	content = CreateFrame("Frame", nil, scroll)
	content:SetSize(ROW_W, 1)
	scroll:SetScrollChild(content)
end

function ns.Refresh()
	if not window or not window:IsShown() then return end
	local errors = ns.SessionErrors()
	title:SetText(("Bug Panel  |cffff4411%d|r  |cffaaaaaasession %d|r")
		:format(#errors, BugGrabber and BugGrabber:GetSessionId() or -1))
	layout(errors)
end

function ns.Toggle()
	if not window then build() end
	if window:IsShown() then
		window:Hide()
	else
		if copyBox then copyBox:Hide() end
		window:Show()
		ns.Refresh()
	end
end
