local _, ns = ...

local function openPlan(pk, target)
	ns.PlannerUI:Open(pk, true)

	local plan, message = ns.CreatePlan(pk, target)
	if not plan then
		print("|cff00b4ff[art]|r " .. message)
		ns.hint(message)
		ns.PlannerUI:Open(pk, true)
		return
	end

	ns.store:savePlan(plan)
	print("|cff00b4ff[art]|r " .. message)
	ns.Format.PrintPlan(plan)
	ns.PlannerUI:Open(pk, true)
	ns.CraftUI:Show()
	ns.hint(message)
end

SLASH_ARTISAN1 = "/art"
SlashCmdList.ARTISAN = function(msg)
	msg = (msg or ""):lower():gsub("^%s+", "")
	if msg == "plan" or msg:match("^plan%s") then
		local pk, target = msg:match("^plan%s+(%S+)%s*(%d*)")
		if not pk then
			print("|cff00b4ff[art]|r usage: /art plan <pk> [target]")
			return
		end
		openPlan(pk, target ~= "" and tonumber(target) or nil)
	elseif msg == "hide" then
		ns.CraftUI:Hide()
		ns.PlannerUI:Close()
	else
		ns.CraftUI:Show()
	end
end
