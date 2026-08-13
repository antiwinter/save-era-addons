local _, ns = ...

-- The thick 2-row look comes from replacing the frame border artwork; the bars
-- then need to grow taller and stack to fill the two slots in that art.
--
-- Anchors mirror Blizzard's current defaults so the bars stay pinned to the
-- correct frame edge (player = TOPLEFT, target = TOPRIGHT). Only the geometry
-- constants below change to produce the thick stacked layout; tune these to fit
-- the artwork rather than the X/anchor.
local MEDIA = "Interface\\AddOns\\whoaThickCC\\media\\light\\"

local HP_HEIGHT = 30
local MP_HEIGHT = 12
local BAR_WIDTH = 119
local HP_Y = -26 -- top of health bar, below the frame's top edge
local MP_Y = HP_Y - HP_HEIGHT -- mana bar stacked directly under health

-- Pin a bar's text regions to the resized bar: percent on the left, value on the
-- right, combined string centered. Blizzard's defaults assume the thin single-bar
-- slot, so they need re-anchoring for the thick layout.
local function AnchorBarText(bar)
	if not bar then return end
	if bar.LeftText then
		bar.LeftText:ClearAllPoints()
		bar.LeftText:SetPoint("LEFT", bar, "LEFT", 5, 0)
	end
	if bar.RightText then
		bar.RightText:ClearAllPoints()
		bar.RightText:SetPoint("RIGHT", bar, "RIGHT", -6, 0)
	end
	if bar.TextString then
		bar.TextString:ClearAllPoints()
		bar.TextString:SetPoint("CENTER", bar, "CENTER", 0, 0)
	end
end

-- Size the health/mana bars into the thick two-row stack, anchor their text, and
-- pin the name above the health bar. Player anchors from the frame's left edge,
-- target/focus mirror from the right, so anchor + x offset are the only per-frame
-- differences. Returns the bars so callers can anchor frame-specific art to them.
local function LayoutBars(self, anchor, x)
	local hb, mb = self.healthbar, self.manabar
	if hb then
		hb:ClearAllPoints()
		hb:SetSize(BAR_WIDTH, HP_HEIGHT)
		hb:SetPoint(anchor, self, anchor, x, HP_Y)
	end
	if mb then
		mb:ClearAllPoints()
		mb:SetSize(BAR_WIDTH, MP_HEIGHT)
		mb:SetPoint(anchor, self, anchor, x, MP_Y)
	end
	AnchorBarText(hb)
	AnchorBarText(mb)
	if self.name then
		self.name:ClearAllPoints()
		self.name:SetPoint("BOTTOM", hb, "TOP", 0, 4)
	end
	return hb, mb
end

-- Player & pet frame layout (feature 2). Player bars anchor from TOPLEFT.
local function CustomizePlayerFrame(self)
	if PlayerFrameTexture then
		PlayerFrameTexture:SetTexture(MEDIA .. "UI-TargetingFrame")
	end

	LayoutBars(self, "TOPLEFT", 90)
	-- Swap the baked rest/combat glow for our own art, which draws the portrait
	-- circle and the bar-slot rectangle already positioned for the thick frame.
	-- Reveal the full content region; the circle keeps its original placement.
	if PlayerStatusTexture then
		PlayerStatusTexture:SetTexture(MEDIA .. "UI-Player-Status")
		PlayerStatusTexture:SetSize(180, 66)
		PlayerStatusTexture:SetTexCoord(0, 0.7656, 0, 0.5156)
		PlayerStatusTexture:ClearAllPoints()
		PlayerStatusTexture:SetPoint("TOPLEFT", PlayerFrame, "TOPLEFT", 30, -18)
	end
	if PlayerFrameGroupIndicatorText then
		PlayerFrameGroupIndicatorText:ClearAllPoints()
		PlayerFrameGroupIndicatorText:SetPoint("CENTER", PlayerFrame, "TOP", -41, -6)
	end
end
hooksecurefunc("PlayerFrame_ToPlayerArt", CustomizePlayerFrame)

-- Raid subgroup indicator ("G1"-"G8").
hooksecurefunc("PlayerFrame_UpdateGroupIndicator", function()
	if not IsInRaid() then return end
	for i = 1, GetNumGroupMembers() do
		local name, _, subgroup = GetRaidRosterInfo(i)
		if name == UnitName("player") and PlayerFrameGroupIndicatorText then
			PlayerFrameGroupIndicatorText:SetText("G" .. subgroup)
			PlayerFrameGroupIndicator:SetWidth(PlayerFrameGroupIndicatorText:GetWidth())
			PlayerFrameGroupIndicator:Show()
			return
		end
	end
end)

-- Target & focus frame layout (feature 3).
--
-- The 2026 Classic client converted these frames to the retail Mixin pattern:
-- TargetFrame_CheckClassification is no longer a global, so hooking it by name
-- silently does nothing. CheckClassification is now a method on TargetFrameMixin
-- (shared by TargetFrame and FocusFrame), hooked per-instance below.
-- Target bars anchor from TOPRIGHT (mirror of the player).
local function CustomizeTargetFrame(self)
	-- Set frame texture based on unit classification (normal/elite/rare/rareelite)
	if self.borderTexture and self.unit then
		local classification = UnitClassification(self.unit)
		if classification == "worldboss" or classification == "elite" then
			self.borderTexture:SetTexture(MEDIA .. "UI-TargetingFrame-Elite")
		elseif classification == "rareelite" then
			self.borderTexture:SetTexture(MEDIA .. "UI-TargetingFrame-Rare-Elite")
		elseif classification == "rare" then
			self.borderTexture:SetTexture(MEDIA .. "UI-TargetingFrame-Rare")
		else
			self.borderTexture:SetTexture(MEDIA .. "UI-TargetingFrame")
		end
	end

	local hb, mb = LayoutBars(self, "TOPRIGHT", -90)
	-- Hide the name background bar (whoa style has no name bg)
	if self.nameBackground then
		self.nameBackground:Hide()
	end
	-- The frame backdrop (shown through the unfilled part of a bar) defaults to
	-- the thin single-bar slot; span it across the whole thick stack.
	if self.Background and hb and mb then
		self.Background:ClearAllPoints()
		self.Background:SetPoint("TOPRIGHT", hb, "TOPRIGHT", 0, 0)
		self.Background:SetPoint("BOTTOMLEFT", mb, "BOTTOMLEFT", 0, 0)
	end
end

for _, frame in ipairs({ TargetFrame, FocusFrame }) do
	if frame and frame.CheckClassification then
		hooksecurefunc(frame, "CheckClassification", CustomizeTargetFrame)
	end
end

-- Buffs-on-top overlap fix.
--
-- When auras mirror above the frame, Blizzard anchors the first (topmost) aura
-- of a column to the frame's TOP at startY = AURA_START_Y_MIRROR (-19), which
-- lands on our relocated name. The whole column and the buffs/debuffs containers
-- anchor live off that first aura, so nudging it up lifts the entire stack clear
-- of the name in one move. We only touch the aura that anchors to the frame
-- itself (index 1, starting on top) and leave everything else to Blizzard.
local AURA_TOP_START_Y = 6 -- above the frame's top edge, clearing the name
local AURA_START_X = 25 -- matches Blizzard's left inset for the first aura
local function LiftTopAura(self, name, index, _, _, _, _, _, mirrorVertically)
	if not mirrorVertically or index ~= 1 then return end
	local buff = _G[name .. index]
	if not buff then return end
	local _, rel = buff:GetPoint()
	if rel ~= self then return end -- only the frame-anchored (topmost) aura
	buff:SetPoint("BOTTOMLEFT", self, "TOPLEFT", AURA_START_X, AURA_TOP_START_Y)
end

for _, frame in ipairs({ TargetFrame, FocusFrame }) do
	if frame and frame.UpdateBuffAnchor then
		hooksecurefunc(frame, "UpdateBuffAnchor", LiftTopAura)
		hooksecurefunc(frame, "UpdateDebuffAnchor", LiftTopAura)
	end
end
