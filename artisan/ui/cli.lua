local _, ns = ...

SLASH_ARTISAN1 = "/art"
SlashCmdList.ARTISAN = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "scan" or msg:match("^scan%s") then
		local scope = msg:match("^scan%s*(.-)%s*$")
		ns.Scanner:scan(scope == "" and "all" or scope)
	elseif msg == "plan" or msg:match("^plan%s") then
		local pk, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not pk then
			print("|cff00b4ff[art]|r usage: /art plan <pk> [target]")
			return
		end
		if ns.pm:Open(pk, true) and target ~= "" then ns.pm:settarget(tonumber(target)) end
	elseif msg == "hide" then
		ns.CraftUI:Hide()
		ns.pm:Close()
	else
		ns.pm:Open(ns.store.cur_pk, true)
	end
end
