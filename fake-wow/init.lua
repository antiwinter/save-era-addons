-- Resolve THIS file's directory (works under dofile, where arg[0] is the
-- caller's path, not ours) so the sibling modules load regardless of cwd.
local src = debug.getinfo(1, "S").source:gsub("^@", "")
local dir = (src:match("^(.*)/[^/]*$") or ".") .. "/"

local world = {}
local env = _G

-- client.lua first: it seeds the generic env (incl. the shared GM table).
-- Domain modules then attach their own C-APIs + GM knobs to that same env.
dofile(dir .. "client.lua").install(env)
dofile(dir .. "tradeskill.lua").install(env, world)

-- Parse a .toc for its ordered .lua file list (ignores ## directives + blanks),
-- resolving paths relative to the .toc's own directory and normalizing the
-- Windows backslashes WoW .tocs use.
local function tocFiles(tocPath)
	local base = tocPath:match("^(.*)/[^/]*$") or "."
	local files = {}
	for line in io.lines(tocPath) do
		line = line:gsub("%s+$", "")
		if line ~= "" and not line:match("^%s*#") then
			files[#files + 1] = base .. "/" .. (line:gsub("\\", "/"))
		end
	end
	return files
end

-- Load an addon from its .toc: run each file with (addonName, ns) varargs, then
-- fire ADDON_LOADED so the addon's bootstrap (SavedVariables etc.) runs. Returns
-- the shared `ns` table so the driver can reach ns.Runtime, ns.db, ...
local function loadAddon(tocPath)
	local addonName = tocPath:match("([^/]+)%.toc$")
	local ns = {}
	for _, file in ipairs(tocFiles(tocPath)) do
		local chunk = assert(loadfile(file))
		chunk(addonName, ns)
	end
	env.__fire("ADDON_LOADED", addonName)
	return ns
end

return {
	GM = env.GM,
	loadAddon = loadAddon,
	fire = env.__fire,
	slash = env.__slash,
	click = function(name) env[name]:Click() end,
	world = world,
	env = env,
}
