local addonName, ns = ...

-- debug.lua — /skm debug snapshots the session + active plan into the
-- SavedVariable so it survives /reload and can be read off-disk at
-- WTF/Account/<ACCOUNT>/SavedVariables/skillMaster.lua.

function ns.Debug()
	skillMasterDB.debug = {
		when = date("%Y-%m-%d %H:%M:%S"),
		build = select(4, GetBuildInfo()),
		skill = ns.Session and ns.Session.skill,
		active = ns.Session and ns.Session.plan,
	}
	print("|cff00b4ff[skillMaster]|r debug snapshot saved. /reload then read the SavedVariables file.")
end