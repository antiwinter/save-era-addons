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
		return { SetText = noop, SetPoint = noop, SetFont = noop,
			SetTextColor = noop, GetText = function(s) return s.__text end,
			__text = "" }
	end

	local function CreateFrame(_, name, _parent, _template)
		local f
		f = {
			__events = {},
			-- layout / cosmetic stubs (chainable, state-free)
			SetSize = noop, SetPoint = noop, SetWidth = noop, SetHeight = noop,
			SetMovable = noop, EnableMouse = noop, RegisterForDrag = noop,
			SetBackdrop = noop, SetBackdropColor = noop, SetText = noop,
			SetScale = noop, SetAlpha = noop, SetFrameStrata = noop,
			StartMoving = noop, StopMovingOrSizing = noop,
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
			Click = function(s) if s.__OnClick then s.__OnClick(s) end end,
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

	env.UIParent = CreateFrame("Frame", "UIParent")

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

	-- Misc globals addons touch at load / debug time.
	env.GetBuildInfo = function() return "1.15.7", "60000", nil, 11507 end
	env.date = function(fmt) return os.date(fmt) end
	env.print = print
end

return { install = install }
