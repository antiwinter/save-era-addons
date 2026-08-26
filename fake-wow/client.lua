-- client.lua — a generic, reusable WoW client shell for running addons under a
-- plain `lua` interpreter. It fakes just enough of the UI + event system that an
-- addon file loads and runs unchanged: CreateFrame widgets, event registration
-- and dispatch, slash commands, UIParent. NOTHING domain-specific lives here —
-- trade-skill APIs are in tradeskill.lua — so other addons can reuse this shell.

local function install(env)
	-- Every frame registers here so __fire can dispatch an event to all listeners.
	local frames = {}

	-- Chainable no-op for the many cosmetic widget methods addons call. Returns
	-- the frame so `frame:SetSize(..):SetPoint(..)` styles keep working.
	local function noop(self) return self end

	local function newFontString()
		return { SetText = function(s, text) s.__text = text end, SetPoint = noop, SetFont = noop,
			SetTextColor = noop, GetText = function(s) return s.__text end,
			__text = "" }
	end

	local function CreateFrame(_, name, _parent, _template)
		local f
		f = {
			__name = name,
			__parent = _parent,
			__addon = env.__loadingAddon,
			__events = {},
			__enabled = true,
			-- layout / cosmetic stubs (chainable, state-free)
			SetSize = function(s, width, height) s.__width, s.__height = width, height end,
			GetWidth = function(s) return s.__width or 0 end,
			GetHeight = function(s) return s.__height or 0 end,
			SetPoint = noop, ClearAllPoints = noop,
			SetWidth = function(s, width) s.__width = width end,
			SetHeight = function(s, height) s.__height = height end,
			SetParent = function(s, parent) s.__parent = parent end,
			GetParent = function(s) return s.__parent end,
			SetID = function(s, id) s.__id = id end,
			GetID = function(s) return s.__id end,
			SetMovable = noop, EnableMouse = noop, RegisterForDrag = noop,
			SetBackdrop = noop, SetBackdropColor = noop,
			SetText = function(s, text) s.__text = text end,
			GetText = function(s) return s.__text or "" end,
			SetTextInsets = noop, SetAutoFocus = noop, SetNumeric = noop,
			SetFocus = noop, HighlightText = noop,
			SetMinMaxValues = function(s, min, max) s.__min, s.__max = min, max end,
			GetMinMaxValues = function(s) return s.__min, s.__max end,
			SetValueStep = function(s, step) s.__step = step end,
			SetValue = function(s, value)
				s.__value = value
				if s.__OnValueChanged then s.__OnValueChanged(s, value) end
			end,
			GetValue = function(s) return s.__value end,
			SetChecked = function(s, checked) s.__checked = checked == true end,
			GetChecked = function(s) return s.__checked == true end,
			SetNormalTexture = noop,
			SetScale = noop, SetAlpha = noop, SetFrameStrata = noop,
			StartMoving = noop, StopMovingOrSizing = noop,
			Enable = function(s) s.__enabled = true end,
			Disable = function(s) s.__enabled = false end,
			IsEnabled = function(s) return s.__enabled end,
			Show = function(s) s.__shown = true end,
			Hide = function(s) s.__shown = false end,
			IsShown = function(s) return s.__shown == true end,
			CreateFontString = function() return newFontString() end,
			-- event plumbing
			RegisterEvent = function(s, e)
				s.__events[e] = true
			end,
			UnregisterEvent = function(s, e) s.__events[e] = nil end,
			SetScript = function(s, kind, fn) s["__" .. kind] = fn end,
			GetScript = function(s, kind) return s["__" .. kind] end,
			-- button click helper for tests (drives OnClick like a player would)
			Click = function(s) if s.__enabled and s.__OnClick then s.__OnClick(s) end end,
		}
		if name then env[name] = f end
		frames[#frames + 1] = f
		return f
	end

	-- Dispatch an event to every frame listening for it. tradeskill.lua's
	-- DoTradeSkill calls this so crafts flow through the addon's real handlers.
	local function fire(event, ...)
		for _, f in ipairs(frames) do
			if f.__events[event] and f.__OnEvent then
				f.__OnEvent(f, event, ...)
			end
		end
	end

	env.CreateFrame = CreateFrame
	env.__fire = fire
	env.__frames = frames
	env.__beginAddon = function(name) env.__loadingAddon = name end
	env.__endAddon = function() env.__loadingAddon = nil end
	env.__unloadAddon = function(name)
		for i = #frames, 1, -1 do
			local frame = frames[i]
			if frame.__addon == name then
				if frame.__name and env[frame.__name] == frame then env[frame.__name] = nil end
				table.remove(frames, i)
			end
		end
	end

	env.UIParent = CreateFrame("Frame", "UIParent")
	env.TradeSkillFrame = CreateFrame("Frame", "TradeSkillFrame", env.UIParent)

	local spellHandlers = {}
	env.__registerSpell = function(name, handler) spellHandlers[name] = handler end
	function env.CastSpellByName(name)
		local handler = spellHandlers[name]
		if handler then return handler() end
	end

	-- The GM console table. Domain modules (tradeskill.lua, ...) attach their own
	-- setup knobs to it; only truly generic ones live here.
	env.GM = env.GM or {}
	function env.GM.SetSeed(seed) math.randomseed(seed) end

	-- Slash-command registry: addons set SLASH_FOO1 = "/foo" and
	-- SlashCmdList.FOO = handler. env.__slash("/foo bar") dispatches.
	env.SlashCmdList = {}
	function env.__slash(line)
		local cmd, rest = line:match("^(%S+)%s*(.*)$")
		for key, handler in pairs(env.SlashCmdList) do
			local i = 1
			while env["SLASH_" .. key .. i] do
				if env["SLASH_" .. key .. i] == cmd then
					return handler(rest)
				end
				i = i + 1
			end
		end
	end

	-- Misc globals addons touch at load / debug time. The sim world is enUS
	-- (era.db carries English names), so GetLocale reports that.
	-- Dropdown stubs (era's UIDropDownMenu API): the sim never opens a menu,
	-- so initialize records the builder and the rest are no-ops.
	env.UIDropDownMenu_Initialize = function(frame, initFn) frame.__menuInit = initFn end
	env.UIDropDownMenu_CreateInfo = function() return {} end
	env.UIDropDownMenu_AddButton = noop
	env.UIDropDownMenu_SetWidth = noop
	env.UIDropDownMenu_SetText = function(frame, text) frame.__text = text end
	env.CloseDropDownMenus = noop
	env.PanelTemplates_SetNumTabs = function(frame, count) frame.__numTabs = count end
	env.PanelTemplates_SetTab = function(frame, id) frame.__selectedTab = id end

	env.GetBuildInfo = function() return "1.15.7", "60000", nil, 11507 end
	env.GetLocale = function() return "enUS" end
	env.date = function(fmt) return os.date(fmt) end
	env.print = print
end

return { install = install }
