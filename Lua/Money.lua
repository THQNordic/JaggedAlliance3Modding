GameVar("gv_MoneyLog", {})
--[[
	{
		amount = number, 	
		reason = string,
		time = number
	}
]]

--[[
	MoneyReasons = {
		"system",
		"income",		+
		"salary",		-
		"deposit",	+
		"expense",	-
		"operation"	-
	}
]]

function CanPay(amount)
	return amount <= 0 or Game.Money >= amount
end

function AddMoney(amount, logReason, noCombatLog)
	if amount == 0 then return end
	
	local previousBalance = Game.Money
	Game.Money = Game.Money + amount

	if logReason then
		local log = {
			amount = amount,
			reason = logReason,
			time = Game.CampaignTime
		}
		gv_MoneyLog[#gv_MoneyLog+1] = log
	end
	
	if not noCombatLog then
		if amount < 0 then
			CombatLog("short", T{227020362130, "Spent <em><money(amount)></em>", amount = -amount})
		else
			CombatLog("short", T{945065893315, "Gained <em><money(amount)></em>", amount = amount})
		end
	end
	
	local pda = GetDialog("PDADialog")
	if pda and pda.window_state ~= "destroying" then
		pda:AnimateMoneyChange(amount)
	end
	
	pda = GetDialog("PDADialogSatellite")
	if pda and pda.window_state ~= "destroying" then
		pda:AnimateMoneyChange(amount)
	end
	
	ObjModified(Game)
	Msg("MoneyChanged", amount, logReason, previousBalance)
end

function NetSyncEvents.CheatGetMoney()
	AddMoney(100000, "system")
end

function GetForgivingModeDailyIncome()
	if IsGameRuleActive("ForgivingMode") then
		return GameRuleDefs.ForgivingMode:ResolveValue("DailyIncome") or 0
	end
	return 0
end

function GetIncome(days)
	local income = 0
	days = days or 1
	
	for id, sector in sorted_pairs(gv_Sectors) do
		income = income + (GetMineIncome(id) or 0)
	end
	
	income =  income + GetForgivingModeDailyIncome()
	
	return income * days
end

function GetDailyIncome()
	return GetIncome(1)
end

function OnMsg.NewDay()
	AddMoney(GetForgivingModeDailyIncome(),"ForgivingMode")
end

-- Log the previous day income
function OnMsg.NewDay()
	local moneyLog = GetPastMoneyTransfers(const.Scale.day)
	local pastDayIncome = moneyLog.income or 0
	if pastDayIncome > 0 then
		CombatLog("short", T{363617642603, "Daily income: <em><money(amount)></em>", amount = pastDayIncome})
	end
end

function GetMercCurrentDailySalary(id)
	local unitData = gv_UnitData[id]
	if unitData.HiredUntil then
		return GetMercStateFlag(id, "CurrentDailySalary") or GetMercPrice(unitData, 1)
	else
		return 0
	end
end

function GetBurnRate()
	local burnRate = 0
	local mercIds = GetHiredMercIds()
	
	for _, id in ipairs(mercIds) do
		burnRate = burnRate + GetMercCurrentDailySalary(id)
	end
	
	return burnRate
end

function GetMoneyProjection(days)
	if not type(days) == "number" then return end
	
	local income = GetIncome(days)
	local burn = 0
	
	local mercIds = GetHiredMercIds()
	for _, id in ipairs(mercIds) do
		local unitData = gv_UnitData[id]
		local HiredUntil = unitData.HiredUntil
		if HiredUntil then
			local timeAfterExpiration = (Game.CampaignTime + const.Scale.day * days) - HiredUntil
			if timeAfterExpiration > 0 then
				burn = burn + GetMercPrice(unitData, DivRound(timeAfterExpiration, const.Scale.day))
			end
		end
	end
	
	local projection = Game.Money + income - burn
	return projection
end

function GetPastMoneyTransfers(time)
	local result = {}
	
	for i=#gv_MoneyLog, 1, -1 do
		local log = gv_MoneyLog[i]
		if Game.CampaignTime - log.time <= time then
			result[log.reason] = (result[log.reason] or 0) + log.amount
		else
			break
		end
	end
	
	return result
end

function TFormat.GetDailyMoneyChange()
	local dailyIncome = GetDailyIncome()
	local burnRate = GetBurnRate(1)
	local change = dailyIncome - burnRate
	return T{780491782250, "<moneyWithSign(amount)>", amount = change}
end