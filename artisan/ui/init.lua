local _, ns = ...

local function openPlan(pk, target)
	ns.store:set("cur_pk", pk)
	if not ns.openProfFrame() then
		ns.PlannerUI:Open(pk)
		return
	end

	local plan, message = ns.CreatePlan(pk, target)
	if not plan then
		print("|cff00b4ff[art]|r " .. message)
		ns.hint(message)
		ns.PlannerUI:Show(pk)
		return
	end

	ns.store:savePlan(plan)
	print("|cff00b4ff[art]|r " .. message)
	ns.Format.PrintPlan(plan)
	ns.PlannerUI:Show(pk, plan)
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
		ns.PlannerUI:Hide()
	else
		ns.CraftUI:Show()
	end
end
