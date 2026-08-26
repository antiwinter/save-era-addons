local _, ns = ...

SLASH_ARTISAN1 = "/art"
SlashCmdList.ARTISAN = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "plan" or msg:match("^plan%s") then
		local pk, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not pk then
			print("|cff00b4ff[art]|r usage: /art plan <pk> [target]")
			return
		end
		ns.PlannerUI:Open(pk, true)
	elseif msg == "hide" then
		ns.CraftUI:Hide()
		ns.PlannerUI:Close()
	else
		ns.PlannerUI:Open(ns.store.cur_pk, true)
	end
end
