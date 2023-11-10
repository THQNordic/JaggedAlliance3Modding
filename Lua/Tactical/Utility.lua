UndefineClass("CheckTime")
-- UI

table.iappend(XRollover.properties, {
	{ category = "Rollover", id = "RolloverTitle", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverDisabledTitle", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverHint", editor = "text", default = "", translate = true, },
	{ category = "Rollover", id = "RolloverHintGamepad", editor = "text", default = "", translate = true, },
})

XGenerateGetSetFuncs(XRollover)

local prev_XPropControl_UpdatePropertyNames = XPropControl.UpdatePropertyNames
function XPropControl:UpdatePropertyNames(prop_meta)
	if prop_meta.help and editor ~= "help" then
		self:SetRolloverTitle(prop_meta.name or prop_meta.id)
	end
	return prev_XPropControl_UpdatePropertyNames(self, prop_meta)
end

function OnMsg.InitSatelliteView()
	BlinkStartButtonAndSatellite(false)
end

function OnMsg.ConflictEnd(sector)
	local campaignPreset = GetCurrentCampaignPreset()
	if not sector or not campaignPreset then return end
	local questVarState = GetQuestVar("01_Landing", "TCE_InitialConflictLock")
	if sector.Id == campaignPreset.InitialSector and not TutorialHintsState.TravelPlaced and questVarState == "done" then
		BlinkStartButtonAndSatellite(true)
	end
end

function BlinkStartButtonAndSatellite(on)
	local igi = GetInGameInterfaceModeDlg()
	local startBut = igi and igi:ResolveId("idStartButton")
	if not startBut then return end
	
	startBut:DeleteThread("blink")
	if not on then
		if startBut.idLargeText then
			startBut.idLargeText:SetTextStyle("HUDHeaderBigger")
		end
		return
	end

	startBut:CreateThread("blink", function()
		local textWnd = startBut.idLargeText
		local tick = 0
		while true do
			local startMenuOpen = startBut.desktop.modal_window
			startMenuOpen = startMenuOpen and startMenuOpen.Id == "idStartMenu" and startMenuOpen
			if startMenuOpen then
				local contentTemplate = startMenuOpen.idContent
				if contentTemplate then
					-- Prevents messing with the blink, and it only matters in sat view
					contentTemplate.RespawnOnContext = false
				end
				
				local satButton = startMenuOpen:ResolveId("actionToggleSatellite")
				if satButton and not satButton.rollover then
					local style = tick % 2 ~= 0 and "SatelliteContextMenuText" or "PDACursorHint"
					satButton:SetTextStyle(style)
					satButton:Invalidate()
				end
			end
			
			local textStyleButton = tick % 2 ~= 0 and "HUDHeaderBigger" or "MMButtonText"
			if startMenuOpen or startBut.rollover then textStyleButton = "HUDHeaderBigger" end
			textWnd:SetTextStyle(textStyleButton)
			
			tick = tick + 1
			Sleep(300)
		end
	end)
end

local prev_time
local prev_table
local prev_timeType
function GetTimeAsTable(time, real_time)
	if prev_time ~= time or prev_timeType ~= real_time then
		prev_timeType = real_time
		prev_time = time
		prev_table = os.date(real_time and "*t" or "!*t", time)
	end
	return prev_table
end

function GetCampaignDay(time)
	local t = time or Game.CampaignTime
	local campaignStartHour = GetTimeAsTable(Game.CampaignTimeStart).hour
	local campaignHour = (t - Game.CampaignTimeStart) / const.Scale.h
	return ((campaignHour + campaignStartHour) / 24) + 1
end

function GetCampaignWeek(time)
	local campaignDays = GetCampaignDay(time)
	return (campaignDays / 7) + 1
end

local days = {
	T(815763551374, "SUN"),
	T(400037616455, "MON"),
	T(935033754448, "TUE"),
	T(101979463778, "WED"),
	T(441351859413, "THU"),
	T(653126156790, "FRI"),
	T(488038247478, "SAT"),
}

TFormat.day = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return t and t.day or 1
end

TFormat.day_name = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return days[t and t.wday or 1]
end

TFormat.day_name_number = function(context_obj, dayIdx)
	--%w - Weekday as decimal number (1 - 7; Sunday is 1)
	local actualDay = dayIdx and dayIdx + 1
	if dayIdx and dayIdx == 7 then
		dayIdx = 1
	elseif dayIdx then
		dayIdx = dayIdx + 1
	end
	
	return days[dayIdx or 1]
end

function TFormat.Multiply(context_obj, m1, m2)
	local result = m1*m2
	return T{263297552624, "<result>", result = result}
end

function GetDamageRangeText(min, max)
	if min == max then
		return T{263148752783, "<min>", min = min}
	else
		return T{451168511282, "<minDamage>-<maxDamage>", minDamage = min, maxDamage = max}
	end
end

local months = {
	T(386097767149, "JAN"),
	T(496426864332, "FEB"),
	T(650065772304, "MAR"),
	T(732475195762, "APR"),
	T(807996486426, "MAY"),
	T(807327180752, "JUN"),
	T(396147045845, "JUL"),
	T(855339557928, "AUG"),
	T(560140242221, "SEP"),
	T(757023515681, "OCT"),
	T(542161812894, "NOV"),
	T(235231286112, "DEC")
}
TFormat.month = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return months[t and t.month or 1]
end

TFormat.date = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	local month = string.format("%02d", t and t.month or 1)
	local day = string.format("%02d", t and t.day or 1)
	local year = tostring(t and t.year or 1)

	-- This is called in just one place, so its fine I guess.
	-- Might make sense to cache the format though.
	local systemDateFormat = GetDateTimeOrder()
	for i, unit in ipairs(systemDateFormat) do
		systemDateFormat[i] = "<u(" .. unit .. ")>"
	end
	systemDateFormat = table.concat(systemDateFormat, ".")
	return T{systemDateFormat, month = month, day = day, year = year}
end

TFormat.date_mdy = function(context_obj, month, day, year)
	local systemDateFormat = GetDateTimeOrder()
	for i, unit in ipairs(systemDateFormat) do
		systemDateFormat[i] = "<u(" .. unit .. ")>"
	end
	systemDateFormat = table.concat(systemDateFormat, "-")
	return T{systemDateFormat, month = month, day = day, year = year}
end

TFormat.time = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	local mins = string.format("%02d", t.min)
	local hours = string.format("%02d", t.hour)
	return T{109987777732, "<hours>:<mins>", hours = Untranslated(hours), mins = Untranslated(mins) }
end

TFormat.timeSecs = function(context_obj, time)
	local minNum = time / 1000 / 60
	local mins = string.format("%01d", minNum)
	local secs = string.format("%02d", (time - minNum * 1000 * 60) / 1000)
	return T{537833878288, "<mins>:<secs>", mins = Untranslated(mins), secs = Untranslated(secs) }
end

TFormat.timeDuration = function(context_obj, time)
	-- Satellite time is stored in seconds, not milliseconds
	local minutes = time / 60
	local hours = minutes / 60
	local days = hours / 24
	if days > 0 then
		local hoursLeft = hours - days * 24
		if hoursLeft > 0 then
			return T{407759704918, "<days>D <hours>h", days = days, hours = hoursLeft}
		else
			return T{582737918674, "<days>D", days = days}
		end
	end
	if hours > 0 then
		local minutesLeft = minutes - hours * 60
		if minutesLeft > 0 then
			return T{310898452498, "<hours>h <minutes>m", hours = hours, minutes = minutesLeft}
		else
			return T{527198904622, "<hours>h", hours = hours}
		end
	else
		return T{880672979292, "<mins>m", mins = minutes}
	end
end

TFormat.year = function(context_obj, time)
	local t = GetTimeAsTable(time or Game.CampaignTime)
	return Untranslated(t.year)
end

TFormat.money = function(context_obj, value)
	if value >= 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{259741266711, --[[currency formatting negative]] "-$<money>", money = FormatNumber(abs(value), false)}
	end
end

TFormat.balanceDisplay = function(context_obj, value)
	if value >= 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{212953538446, --[[currency formatting negative]] "<red>-$<money></red>", money = FormatNumber(abs(value), false)}
	end
end

TFormat.moneyRounded = function(context_obj, value, granularity)
	granularity = granularity or 500
	value = round(value, granularity)
	return T{729420047388, "~<money(value)>", value = value}
end

TFormat.moneyWithSign = function(context_obj, value)
	if value > 0 then
		return T{950883598077, --[[currency formatting positive with sign]] "+$<money>", money = FormatNumber(value, false)}
	elseif value == 0 then
		return T{114756924541, --[[currency formatting positive]] "$<money>", money = FormatNumber(value, false)}
	else
		return T{464630604806, --[[currency formatting negative with sign]] "-$<money>", money = FormatNumber(abs(value), false)}
	end
end

TFormat.moneyWithIcon = function(context_obj, value)
	return T{581847052427, --[[currency formatting]] "<money><image UI/SectorOperations/T_Icon_Money 2000>", money = FormatNumber(value, true)}
end

TFormat.numberWithSign = function(context_obj, value)
	return FormatNumber(value, true)
end

TFormat.countCtx = function(context_obj)
	return context_obj and #context_obj
end

function FormatNumber(value, withSign)
	if not value then
		value = 0
	end

	local prefix = ""
	if withSign then
		if value > 0 then
			prefix = "+"
		end
	end
	
	return T{269645844644, "<prefix><value>", prefix = prefix, value = value}
end

TFormat.GetMercOperationText = function(context_obj)
	if context_obj and context_obj.Operation then
		return SectorOperations[context_obj.Operation].display_name
	else
		return T(601695937982, "None")
	end
end

function GetSectorName(sector)
	if not IsKindOf(sector, "SatelliteSector") then
		sector = ResolvePropObj(sector)
		sector = IsKindOf(sector, "SatelliteSector") and sector
	end

	if sector then
		return (sector.display_name or "").." ("..GetSectorId(sector)..")"
	end
	return ""
end

TFormat.SectorName = function(context_obj, sector)
	if type(sector) == "string" then sector = gv_Sectors and gv_Sectors[sector] end
	sector = sector or context_obj
	return GetSectorName(sector)
end

function GetSectorId(sector)
	if not sector then return false end
	if sector.GroundSector then return Untranslated(sector.GroundSector) .. T(367876597727, --[[suffix added to ground sector to get the underground sector ID. For example, the sector under H3 will become H3U]] "U") end
	return Untranslated(sector.name)
end

TFormat.SectorId = function(context_obj, sectorId)
	return GetSectorId(gv_Sectors and gv_Sectors[sectorId])
end

TFormat.SectorIdColored = function(context_obj, sectorId)
	local sector
	if context_obj and context_obj.metadata and context_obj.metadata.sector then
		sector = {}
		sector.Side = context_obj.metadata.side
		sector.GroundSector = context_obj.metadata.ground_sector
		sector.name = sectorId
	else
		sector = gv_Sectors and gv_Sectors[sectorId]
	end
	if not sector then return false end
	local _, _, _, textColor = GetSectorControlColor(sector.Side)
	local sectorId = GetSectorId(sector)
	local concat = textColor .. sectorId .. "</color>"
	return T{concat}
end

TFormat.SectorIdColored2 = function(context_obj, sectorId)
	local sector = gv_Sectors and gv_Sectors[sectorId]
	if not sector then return false end
	local _, textColor, _, _ = GetSectorControlColor(sector.Side)
	local sectorId = GetSectorId(sector)
	local concat = textColor .. sectorId .. "</color>"
	return T{concat}
end

TFormat.SectorList = function(context_obj, list, emphasize)
	list = list or context_obj
	return ConcatListWithAnd(table.map(list, function(o)
		if emphasize then
			return T{962039320355, "<em><SectorName(sector)></em>", sector = gv_Sectors[o]}
		end
		return GetSectorName(gv_Sectors[o]);
	end))
end

TFormat.SectorMilitiaCount = function(context_obj, sector)
	if not context_obj and not sector then return 0 end
	return Untranslated(GetSectorMilitiaCount((sector or context_obj).Id))
end

TFormat.UnitsCountOnly = function (context_obj)
	if not context_obj then return 0 end

	local unitCount = 0
	for i, s in ipairs(context_obj) do
		if s.units then
			local count = #s.units
				unitCount = unitCount + count
		end
	end
	
	if unitCount > 0 then
		return T{429365736153, "<unitCount>", unitCount = unitCount }
	else
		return T(720023491189, "?")
	end
end

function FormatCampaignTime(time, in_days)
	if in_days=="all" then -- XD XH XM
		local days = Max(0, time / const.Scale.day)
		local hours = Max(0, (time - days * const.Scale.day) / const.Scale.h)
		local mins = (time - (time / const.Scale.h) * const.Scale.h) / const.Scale.min
		if days == 0 then
			return T{211297072165, "<hours>H <mins>M", hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
		elseif mins == 0 then
			return T{457936384867, "<days>D <hours>H", days = days, hours = Untranslated(string.format("%02d", hours))}
		else
			return T{574423138475, "<days>D <hours>H <mins>M", days = days,hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
		end
	elseif in_days then -- XD || XH
		local days = Max(0, time / const.Scale.day)
		local hours = Max(0, (time - days * const.Scale.day) / const.Scale.h)
		if hours == 0 then
			return T{582737918674, "<days>D", days = days}
		end
		if days == 0 then
			return T{402839920108, "<hours>H", hours = hours}
		end
		
		return T{344180072111, "<days>D", days = days}
	else -- XH XM
		local hours = time / const.Scale.h
		local mins = (time - hours * const.Scale.h) / const.Scale.min
		return T{211297072165, "<hours>H <mins>M", hours = Untranslated(string.format("%02d", hours)), mins = Untranslated(string.format("%02d", mins))}
	end
end

-- Prediction magic
-- add already assigned units + merc that are newly added and are not with that profession/operation
function GetOperationTimeLeftAssign(merc, operation, context)
	if (not context or not next(context.add_units)) and not merc then
		return 0
	end	
	
	local operationPreset = SectorOperations[operation]
	local additional_units = context.add_units		
	if merc then 
		table.insert(additional_units, 1, merc)
	end
	local merc = merc or additional_units[1]
		
	local sector = context.sector or merc:GetSector()
	local sector_id = sector.Id

	if operation=="RAndR" then			
		return GetActorOperationTimeLeft(merc, "RAndR", "Restman")
	end
	
	if operation=="TrainMercs" then
		local teacher = context.list_as_prof=="Teacher" and merc
		if not teacher then
			local mercs = GetOperationProfessionalsGroupedByProfession(sector_id, "TrainMercs")
			local 	teachers = mercs["Teacher"]
			teacher = teachers[1]
		end	
		return GetActorOperationTimeLeft(teacher, "TrainMercs")
	end

	local already_assigned = GetOperationProfessionals(sector_id, operation,context.list_as_prof)
	if IsOperationHealing(operation) then
		local slowest
		if context.list_as_prof=="Patient" then
			for _, unit_data in ipairs(additional_units or empty_table) do
				slowest = Max(slowest or 0, GetPatientHealingTimeLeft(unit_data))
			end
		end
		for _, unit in ipairs(GetOperationProfessionals(sector_id, operation, "Patient")) do
			slowest = Max(slowest or 0, GetPatientHealingTimeLeft(unit))
		end
		return slowest
	end
	
	if operation == "RepairItems" then
		local queue = SectorOperationItems_GetItemsQueue(sector_id,"RepairItems")
		local min_time = SectorOperations["RepairItems"]:ResolveValue("min_time")
		if not next(queue) then 
			return min_time*const.Scale.h
		end
		
		local progress_per_tick = GetSumOperationStats(already_assigned, "Mechanical", operationPreset:ResolveValue("stat_multiplier"))					
		progress_per_tick = progress_per_tick + GetSumOperationStats(additional_units, "Mechanical", operationPreset:ResolveValue("stat_multiplier"))					
		local current_progress = operationPreset:ProgressCurrent(already_assigned[1] or merc, sector, "prediction") or 0
		local left_progress = operationPreset:ProgressCompleteThreshold(already_assigned[1] or merc, sector,"prediction") - current_progress
		local ticks_left = progress_per_tick>0 and Max(0,left_progress / progress_per_tick) or 0		
   
		return min_time*const.Scale.h + Max(ticks_left*const.Satellite.Tick, 0)
	end				
	
	--intel, militia, repairitems, craft some custom thatare not heal			
	-- get already assigned
	local progress_per_tick = 0
	for _, unit_data in ipairs(already_assigned or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data)
	end
	for _, unit_data in ipairs(additional_units or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data, "prediction")
	end
				
	if CheatEnabled("FastActivity") then
		progress_per_tick = progress_per_tick*100
	end

	local current_progress = operationPreset:ProgressCurrent(already_assigned[1] or merc, sector) or 0
	local left_progress = operationPreset:ProgressCompleteThreshold(already_assigned[1] or merc, sector) - current_progress
	local ticks_left = progress_per_tick>0 and left_progress / progress_per_tick or 0
	if left_progress > 0 then
		ticks_left = Max(ticks_left, 1)
	end
	return ticks_left*const.Satellite.Tick
end

-- merc
function GetOperationTimeLeft(merc, operation, context)
	local operationPreset = SectorOperations[operation]

	if context and context.add_units and #context.add_units > 0 then	  		
		return GetOperationTimeLeftAssign(merc, operation, context)
	end

	-- not assigning / rollvoer,timeline, progress/
	if operation == "Arriving" then
		return operationPreset:ProgressCompleteThreshold(merc, false) - merc.arriving_progress
	end
	
	if operation == "Traveling" then
		return operationPreset:ProgressCompleteThreshold(merc, false) - merc.traveling_progress
	end
	
	if operation == "Idle" then
		return SatelliteUnitRestTimeRemaining(merc) or 0
	end

	if operation=="RAndR" then
		context = context or {}
		context.merc = merc
		return GetActorOperationTimeLeft(merc,"RAndR", "Restman")
	end
	
	-- healing
	if IsOperationHealing(operation) then
		context = context or {}
		context.merc = merc
		if context.all then
			context.list_as_prof = false -- slowlest
			return TreatWoundsTimeLeft(context,operation)
		else
			return TreatWoundsTimeLeft(context,operation)
		end
	end
	
	local sector =  context and context.sector or merc and merc:GetSector()
	local sector_id = sector and sector.Id
	if operation == "TrainMercs" then
		context = context or {}
		context.merc = merc		
		
		local mercs = GetOperationProfessionalsGroupedByProfession(sector_id, "TrainMercs")
		local 	students = mercs["Student"]
		local 	teachers = mercs["Teacher"]
		if not context.prediction and (not next(students) or not next(teachers)) then
			return 0
		end
		return GetActorOperationTimeLeft(teachers[1] or context.merc, "TrainMercs")
	end
	
	if operation == "RepairItems" then	
		local left_time = merc and  GetActorOperationTimeLeft(merc, "RepairItems","prediction") or 0
		local min_time = operationPreset:ResolveValue("min_time")
		
		local time = sector.started_operations and sector.started_operations["RepairItems"]
		if not time or type(time)~= "number" then
			time = Game.CampaignTime			
		end
		return Max(0,left_time) + Max(0,min_time*const.Scale.h	 - (Game.CampaignTime - time))
	end
	
	-- other operations
	local already_assigned = GetOperationProfessionals(sector_id, operation, context and context.list_prof)
	local progress_per_tick = 0
	for _, unit_data in ipairs(already_assigned or empty_table) do
		progress_per_tick = progress_per_tick + operationPreset:ProgressPerTick(unit_data, "prediction")
	end
	if CheatEnabled("FastActivity") then
		progress_per_tick = progress_per_tick*100
	end
	local left_progress = operationPreset:ProgressCompleteThreshold(merc, sector, "prediction") - operationPreset:ProgressCurrent(merc, sector, "prediction")
	local ticks_left = progress_per_tick>0 and left_progress / progress_per_tick or 0
	return ticks_left*const.Satellite.Tick
end

function GetOperationTimerETA(merc, prediction)
	local list_as_prof
	if IsPatient(merc) and not IsDoctor(merc) then
		list_as_prof = "Patient"
	end
	if merc.OperationProfession == "Student" then
		list_as_prof = "Student"
	end	

	return merc.Operation ~= "Idle" and GetOperationTimeLeft(merc, merc.Operation, {list_as_prof = list_as_prof, prediction = prediction})
end

function GetOperationTimerInitialETA(merc)
	if merc.Operation == "Traveling" then
		local squad = merc.Squad and gv_Squads[merc.Squad]
		if squad then
			local breakdown = GetRouteInfoBreakdown(squad, squad.route)												
			local total = breakdown.total					
			return total.travelTime
		end
	end
	return GetOperationTimerETA(merc)
end

TFormat.MercContractTime = function(context_obj)
	if not IsKindOfClasses(context_obj, "UnitData", "Unit") or not context_obj.HiredUntil then return "" end
	
	local remaining_time = context_obj.HiredUntil - Game.CampaignTime
	if remaining_time <= 0 then 
		return T(659003766070, "Expired")
	else 
		return FormatCampaignTime(remaining_time, "in_days")
	end
end

TFormat.OtherPlayerName = function(context_obj)
	if not netInGame then return "" end
	if not netGamePlayers then return "" end
	
	for i, p in ipairs(netGamePlayers) do
		if p.id ~= netUniqueId then
			return Untranslated(p.name)
		end
	end
	
	return ""
end

TFormat.CampaignTime = function(context_obj, value)
	return FormatCampaignTime(value)
end

TFormat.ForgivingModeText = function(context_obj)
	if Platform.ps5 or Platform.ps4 or g_TestUIPlatform == "ps4" or g_TestUIPlatform == "ps5" then
		return T(284695860080, --[[GameRuleDef ForgivingMode Playstation description]] 'Lowers the impact of attrition and makes it easier to recover from bad situations (faster healing and repair, better income).<newline><newline><flavor>You cannot unlock the "Ironman" trophy while Forgiving mode is enabled.</flavor><newline><newline><flavor>You can change this option at any time during gameplay.</flavor>')
	end
	
	return T(823257619450, --[[GameRuleDef ForgivingMode description]] 'Lowers the impact of attrition and makes it easier to recover from bad situations (faster healing and repair, better income).<newline><newline><flavor>You cannot unlock the "Ironman" achievement while Forgiving mode is enabled.</flavor><newline><newline><flavor>You can change this option at any time during gameplay.</flavor>')
end

table.insert(BlacklistedDialogClasses, "TacticalNotification")
table.insert(BlacklistedDialogClasses, "Intro")

local function lGetTacticalNotificationState()
	local dlg = GetDialog("TacticalNotification")
	if dlg then
		if dlg.state then return dlg.state, dlg end
		dlg.state = {}
		return dlg.state, dlg
	end
	return false
end

local function lTacticalNotificationRemoveExpired(state)
	local now = RealTime()
	for i, notify in pairs(state) do
		local endPoint = notify.start + notify.duration
		if notify.duration ~= -1 and now >= endPoint then
			state[i] = nil
		end
	end
	table.compact(state)
end

local function lUpdateTacticalNotificationShown(instant_hide)
	local state, dlg = lGetTacticalNotificationState()
	if not state then return end
	lTacticalNotificationRemoveExpired(state)

	dlg:DeleteThread("updater");
	local top, topPrio = false, false -- Smallest priority integer on top
	for i, notification in ipairs(state) do
		if not topPrio or notification.priority < topPrio then
			top = notification
			topPrio = notification.priority
		end
	end

	local currentlyPlaying = dlg:GetVisible()
	if top then
		dlg:SetMode(top.style or "red")
		local txtBox = dlg:ResolveId("idText")
		txtBox:SetText(top.text)

		if top.secondaryText then
			txtBox = dlg:ResolveId("idBottomText")
			txtBox:SetText(top.secondaryText)
		end

		if top.duration ~= -1 then
			dlg:CreateThread("updater", function()
				local endPoint = top.start + top.duration
				Sleep(endPoint - RealTime())
				DelayedCall(0, lUpdateTacticalNotificationShown)
			end)
		end

		if not currentlyPlaying then
			dlg:SetVisible(true)
			if top.combatLog then 
				CombatLog(top.combatLogType,top.text)
			end
		end

		return
	end

	-- not top (no notification active)
	if currentlyPlaying then
		dlg:SetVisible(false, instant_hide)
	end
end

function GetTacticalNotificationText(groupOrId)
	local state = lGetTacticalNotificationState()
	for i, notify in ipairs(state) do
		if notify.mode == groupOrId or notify.group == groupOrId then
			return notify.text
		end
	end
end

function HideTacticalNotification(groupOrId, instant)
	local state = lGetTacticalNotificationState()
	for i, notify in ipairs(state) do
		if notify.mode == groupOrId or notify.group == groupOrId then
			notify.start = 0
			notify.duration = 0
		end
	end
	lUpdateTacticalNotificationShown(instant)
end

local function lSetTacticalNotificationMode(mode, on)
	local dlg = GetDialog("TacticalNotification")
	if not dlg then return end
	if not dlg.orderMode then
		dlg.orderMode = {}
	end
	
	dlg.orderMode[mode] = on
	
	local setpieceOn = dlg.orderMode["setpiece"]
	local pdaOn = dlg.orderMode["pda"]
	
	if setpieceOn then
		dlg:SetDrawOnTop(true)
		dlg:SetZOrder(100)
		return
	end
	
	if pdaOn then
		dlg:SetDrawOnTop(false)
		dlg:SetZOrder(0)
		return
	end
	
	dlg:SetDrawOnTop(false)
	dlg:SetZOrder(1)
end

function OnMsg.WillStartSetpiece()
	lSetTacticalNotificationMode("setpiece", true)
end

function OnMsg.SetpieceDialogClosed()
	lSetTacticalNotificationMode("setpiece", false)
	if not cameraTac.IsActive() then
		print("setpiece left camera as not tac")
		cameraTac.Activate()
	end
end

function OnMsg.OpenPDA()
	lSetTacticalNotificationMode("pda", true)
end

function OnMsg.ClosePDA()
	lSetTacticalNotificationMode("pda", false)
end

function OnMsg.DoneMap()
	local tactNot = GetDialog("TacticalNotification")
	if tactNot then
		tactNot.FadeOutTime = 0
		tactNot:Close()
	end
end

--  mode - This is the id of a listitem tactical notifiction
--  keepVisible - Whether to keep the notification visible until the hide func is called
--  text - Can override the preset's text. Currently unused
--  context - for the text.
function ShowTacticalNotification(mode, keepVisible, text, context)
	if CheatEnabled("CombatUIHidden") then return end

	local state, dlg = lGetTacticalNotificationState()
	if not dlg then
		dlg = OpenDialog("TacticalNotification")
		lSetTacticalNotificationMode("setpiece", IsSetpiecePlaying())
		lSetTacticalNotificationMode("pda", GetDialog("PDADialogSatellite"))
		state = {}
		dlg.state = state
	end

	local startTime = RealTime()

	-- Check if already exists in state.
	if table.find(state, "mode", mode) and mode ~= "customText" then
		return
	end

	-- Add to list.
	local preset = Presets.TacticalNotification.Default[mode]
	assert(preset)
	text = text or preset.text
	local secondaryText = preset.secondaryText
	if context then
		text = Untranslated(_InternalTranslate(T{text, context}))
		secondaryText = secondaryText and Untranslated(_InternalTranslate(T{secondaryText, context}))
	end
	local newEntry = {
		mode = mode,
		group = preset.removalGroup,
		text = text,
		secondaryText = secondaryText,
		start = RealTime(),
		priority = preset.SortKey,
		duration = keepVisible and -1 or preset.duration or 0,
		style = preset.style,
		combatLog = preset.combatLog,
		combatLogType = preset.combatLogType
	}
	state[#state + 1] = newEntry

	lUpdateTacticalNotificationShown()
end

function OnMsg.TurnEnded()
	HideTacticalNotification("turn")
end

function ShowTurnNotification()
	if CheatEnabled("CombatUIHidden") then return end

	local dlg = GetInGameInterfaceModeDlg()
	if not dlg then return end
	local idTurnText = dlg:ResolveId("idTurnText")
	if not idTurnText then return end
	
	if not netGamePlayers or #netGamePlayers < 2 then return end
	
	local currentTeamSide = g_Teams[g_CurrentTeam].side
	local playerName
	if currentTeamSide == "player1" then
		playerName = netGamePlayers[1].name
	elseif currentTeamSide == "player2" then
		playerName = netGamePlayers[2].name
	end
	
	idTurnText:SetText(T{845626429475, "<name>'s TURN", name = Untranslated(playerName)})
	idTurnText:SetVisible(true)
	-- Fast fingers
	idTurnText:DeleteThread("fadeOutThread")
	idTurnText:CreateThread("fadeOutThread", function(self) 
		Sleep(1000)
		self:SetVisible(false)
	end, idTurnText)
end

-- Squads and sectors

if FirstLoad then
	g_SquadsArray = false
	g_PlayerSquads = false
	g_PlayerAndMilitiaSquads = false
	g_MilitiaSquads = false
	g_EnemySquads =  false
end

function AddSquadToLists(squad)
	table.insert(g_SquadsArray, squad)
	if (squad.Side == "enemy1" or squad.Side == "enemy2") then		
		g_EnemySquads[#g_EnemySquads + 1] = squad
	elseif (squad.Side == "player1" or squad.Side == "player2" or squad.Side == "ally") then
		if not squad.militia then
			g_PlayerSquads[#g_PlayerSquads + 1] = squad
		else	
			g_MilitiaSquads[#g_MilitiaSquads + 1] = squad
		end	
		g_PlayerAndMilitiaSquads[#g_PlayerAndMilitiaSquads + 1] = squad
	end
	AddSquadToSectorList(squad,squad.CurrentSector)
end

function RemoveSquadsFromLists(squad)
	table.remove_value(g_SquadsArray, squad)
	table.remove_value(g_PlayerSquads, squad)
	table.remove_value(g_PlayerAndMilitiaSquads, squad)
	table.remove_value(g_MilitiaSquads,squad)
	table.remove_value(g_EnemySquads,squad)
	RemoveSquadFromSectorList(squad)
end

function OnMsg.PreLoadSessionData()
	g_SquadsArray = {}
	g_PlayerSquads = {}
	g_PlayerAndMilitiaSquads = {}
	g_MilitiaSquads = {}
	g_EnemySquads = {}
	for id, squad in sorted_pairs(gv_Squads) do
		AddSquadToLists(squad)
	end
end

function OnMsg.NewGame()
	g_SquadsArray = {}
	g_PlayerSquads = {}
	g_PlayerAndMilitiaSquads = {}
	g_MilitiaSquads = {}
	g_EnemySquads = {}
end

function GetPlayerMercSquads(include_militia)
	return include_militia and g_PlayerAndMilitiaSquads or g_PlayerSquads or empty_table
end

function GetHiredMercIds()
	local ids = {}
	for _, squad in ipairs(g_PlayerSquads) do
		table.iappend(ids, squad.units)
	end
	return ids
end

function AnyPlayerSquads()
	return next(g_PlayerSquads)	
end

function AnyPlayerSquadsInSector(sector_id)
	local sectorData = gv_Sectors[sector_id]
	for _, s in ipairs(g_PlayerSquads) do
		local squadSector = s.CurrentSector
		local squadSectorData = gv_Sectors[squadSector]
		local here = not sectorData or (squadSectorData and 
			(squadSector == sector_id or squadSectorData.GroundSector == sector_id or sectorData.GroundSector == squadSector))
		if here then return true, s end
	end
	return false
end

function TFormat.PlayerMercCount()
	return CountPlayerMercsInSquads()
end

function CountPlayerMercsInSquads(affiliation, includeImp)
	local count = 0
	for _, s in ipairs(g_PlayerSquads) do
		for i, u in ipairs(s.units) do
			local ud = gv_UnitData[u]
			local affiliated = (not affiliation or ud.Affiliation == affiliation)
			if not affiliated and includeImp then
				local template = UnitDataDefs[ud.class]
				affiliated = template and template.group == "IMP"
			end
			if ud and affiliated then
				count = count + 1
			end
		end
	end
	return count
end

function CountUnitsInSquads(squads)
	local count = 0
	for _, squad in ipairs(squads) do
		count = count + #squad.units
	end
	return count
end

function GetMilitiaSquads(sector)
	local squads = {}
	for _, squad in ipairs(g_MilitiaSquads) do
		if squad.CurrentSector == sector.Id then
			squads[#squads+1] = squad
		end
	end
	return squads
end

--player and allySquads
--enemySquads
--player and militia
--underground
function RemoveSquadFromSectorList(squad, prev_sector_id)
	prev_sector_id = prev_sector_id or squad.CurrentSector
	if not prev_sector_id then return end
	local prev_sector = gv_Sectors[prev_sector_id]
		
	table.remove_value(prev_sector.underground_squads, squad)
	table.remove_value(prev_sector.enemy_squads, squad)
	table.remove_value(prev_sector.ally_squads, squad)
	table.remove_value(prev_sector.militia_squads, squad)
	table.remove_value(prev_sector.ally_and_militia_squads, squad)
	table.remove_value(prev_sector.all_squads, squad)
	if prev_sector.GroundSector then
		local ground =  gv_Sectors[prev_sector.GroundSector]
		table.remove_value(ground.underground_squads, squad)
		table.remove_value(ground.all_squads, squad)
	end
end	

function AddSquadToSectorList(squad, sector_id)
	if not sector_id then return end
	local sector = gv_Sectors[sector_id]
	
	-- add to sector_lists
	sector.all_squads = sector.all_squads or {}
	assert(not table.find(sector.all_squads, squad))
	sector.all_squads[#sector.all_squads + 1] = squad
	if sector.GroundSector then
		local ground =  gv_Sectors[sector.GroundSector]
		ground.underground_squads = ground.underground_squads or {}
		ground.underground_squads[#ground.underground_squads + 1] = squad
		ground.all_squads = ground.all_squads or {}
		ground.all_squads[#ground.all_squads + 1] = squad
	end
	if (squad.Side == "player1" or squad.Side == "ally") then
		if not squad.militia then
			sector.ally_squads = sector.ally_squads  or {}
			sector.ally_squads[#sector.ally_squads + 1] = squad
		else	
			sector.militia_squads = sector.militia_squads  or {}
			sector.militia_squads[#sector.militia_squads + 1] = squad
		end	
		sector.ally_and_militia_squads =  sector.ally_and_militia_squads or {}
		sector.ally_and_militia_squads[#sector.ally_and_militia_squads + 1] = squad
	else -- Mirror behavior of GetSquadsInSector where non player squads are returned as enemy
		sector.enemy_squads = sector.enemy_squads or {}
		sector.enemy_squads[#sector.enemy_squads + 1] = squad
	end
end

function GetSquadsInSector(sector_id, excludeTravelling, includeMilitia, excludeArriving, excludeRetreating)
	local sectorData = gv_Sectors[sector_id]
	-- in allmost all of calls only sector_id is passed, so precalc that result
	if sectorData and not excludeTravelling and not includeMilitia and not excludeArriving then
		return sectorData.ally_squads or empty_table, sectorData.enemy_squads or empty_table
	end
	
	-- Passing in no sector returns all squads
	local squadList = sectorData and sectorData.all_squads or g_SquadsArray
	
	local alliedSquads = {}
	local enemySquads = {}
	for i, s in ipairs(squadList) do
		if #s.units == 0 then goto continue end -- Squad being despawned
		if s.militia and not includeMilitia then goto continue end
		if s.arrival_squad and excludeArriving then goto continue end
		if excludeTravelling and IsSquadTravelling(s) then goto continue end
		if excludeTravelling and IsTraversingShortcut(s) then goto continue end
		if excludeRetreating and s.Retreat then goto continue end
		
		local squadSector = s.CurrentSector
		if not sectorData or squadSector == sector_id then
			if s.Side == "player1" or s.Side == "ally" then
				alliedSquads[#alliedSquads + 1] = s
			else
				enemySquads[#enemySquads + 1] = s
			end
		end
		::continue::
	end
	
	return alliedSquads, enemySquads
end

function GetSquadsInSectorCombined(...)
	local newTable = {} -- We gotta copy cuz the return tables could be immutable/stateful
	local ally, enemy = GetSquadsInSector(...)
	table.iappend(newTable, ally)
	table.iappend(newTable, enemy)
	return newTable
end

function GetUngroupedSquadsInSector(sector)
	local squads = {}
	local sectorData = gv_Sectors[sector]
	for i, s in ipairs(g_SquadsArray) do
		if not s.militia then
			local squadSector = s.CurrentSector
			local squadSectorData = gv_Sectors[squadSector]
			if not sectorData or (squadSectorData and (squadSector == sector or squadSectorData.GroundSector == sector or sectorData.GroundSector == squadSector)) then
				squads[#squads + 1] = s
			end
		end
	end
	
	return squads
end

function GetPlayerMercsInSector(sector_id)
	local mercs = {}
	local squads = GetSquadsInSector(sector_id)
	for i, s in ipairs(squads) do
		table.iappend(mercs, s.units)
	end
	return mercs
end

function GetEnemiesInSector(sector, ...)
	local _, squads = GetSquadsInSector(sector, ...)
	if #squads == 0 and gv_Sectors[sector].conflict then
		return {
			DisplayName = T(496804530535, "UNKNOWN ENEMIES"),
			units = false,
			Count = T(548893794472, "UNKNOWN STRENGTH")
		}
	end
	return squads
end

function GetSquadsOnMap(references)
	local team = GetCurrentTeam()
	if not team then return {}, false end
	local squads = {}
	for i, u in ipairs(team.units) do
		local squad = u:GetSatelliteSquad()
		if squad and not table.find(squads, squad.UniqueId) and not IsSquadTravelling(squad) and squad.CurrentSector == gv_CurrentSectorId then
			squads[#squads + 1] = squad.UniqueId
		end
	end
	table.sort(squads, function (a, b)
		return a > b
	end)
	if references then
		for i, s in ipairs(squads) do
			squads[i] = gv_Squads[s]
		end
	end
	return squads, team
end

function SortSquads(squads)
	table.sort(squads, function (a, b)
		return a.UniqueId < b.UniqueId
	end)
	
	return squads
end

function GetSquadsOnMapUI()
	local team = GetCurrentTeam()
	if not team then return {}, false end
	
	local deadUnits = {}
	local squads = {}
	for i, u in ipairs(team.units) do
		-- Dead units retain a reference to which squad they were part in, but the squads dont link back to dead units.
		if u:IsDead() then
			local squadId = u.Squad;
			if not deadUnits[squadId] then deadUnits[squadId] = {} end
			table.insert(deadUnits[squadId], u)
		end
	
		-- Record all unique squads in the friendly combat team AKA all player controlled units on the map.
		local squad = IsValid(u) and u:GetSatelliteSquad()
		local squadHere = squad and squad.CurrentSector == gv_CurrentSectorId
		if squad and squadHere and not table.find(squads, squad.UniqueId) then
			squads[#squads + 1] = squad.UniqueId
		end
	end
	table.sort(squads, function (a, b)
		return a < b
	end)
	
	local squadsRefs = {}
	for i, s in ipairs(squads) do
		local squadObj = gv_Squads[s]
		local sId = squadObj.UniqueId
		local units = {}
		squadsRefs[#squadsRefs + 1] = 
		{
			Name = squadObj.Name,
			UniqueId = sId,
			units = units,
			image = squadObj.image,
			morale = MoraleLevelName[team.morale] or team.morale,
		}
		
		for i, u in ipairs(squadObj.units) do
			units[#units + 1] = g_Units[u]
		end
		for i, dUnit in ipairs(deadUnits[sId]) do
			units[#units + 1] = dUnit
		end
	end
	
	return squadsRefs
end

function GetCurrentMapUnits(enemy)
	return MapGet("map", "Unit", function(o, enemy)
		local squad = o:GetSatelliteSquad()
		local side = (o.team and o.team.side) or (squad and squad.Side) or (IsKindOf(o.spawner, "UnitMarker") and o.spawner.Side)
		if enemy == "enemy" then
			return (side == "enemy1" or side == "enemy2") and not o:IsDead() and not o:IsDefeatedVillain()
		else
			return side == "player1" and not o:IsDead()
		end
	end, enemy) or {}
end

function GetCurrentMapPlayerUnits()
	return MapGet("map", "Unit", function(o)
		local squad = o:GetSatelliteSquad()
		local side = (o.team and o.team.side) or (squad and squad.Side) or (IsKindOf(o.spawner, "UnitMarker") and o.spawner.Side)
		return (side == "enemy1" or side == "enemy2") and not o:IsDead() and not o:IsDefeatedVillain()
	end) or {}
end

function GroupEnemyMercs(squads, separateDead)
	local totalCount = 0
	local units = {}
	for i, s in ipairs(squads) do
		local shipmentPreset = false
		if (s.diamond_briefcase and gv_Sectors[s.CurrentSector].intel_discovered) or s.diamond_briefcase_dynamic then
			shipmentPreset = s.shipment_preset_id or "DiamondShipment"
			shipmentPreset = ShipmentPresets[shipmentPreset]
		end
	
		for _, u in ipairs(s.units or empty_table) do
			local data = gv_UnitData[u]
			if data then
				totalCount = totalCount + 1
				local name = _InternalTranslate(data.Name)
				if separateDead and data.HitPoints == 0 then
					name = name .. "_dead"
				end
				
				local hasShipment = false
				if shipmentPreset and data:HasItem(shipmentPreset.item) then
					hasShipment = shipmentPreset.badge_icon
				end
				
				-- Count the units with the same name.
				if units[name] then
					local c = units[name].count
					units[name].count = c + 1
					local temps = units[name].templates
					temps[#temps + 1] = data
				else
					units[name] = {
						name = name,
						villain = data.villain,
						count = 1,
						template = data,
						DisplayName = data.Name,
						templates = { data },
						Side = s.Side,
						hasShipment = hasShipment
					}
				end
			end
		end
	end
	units = table.values(units) 
	table.sort(units, function(a, b)
		-- villain
		if a.villain and not b.villain then
			return true
		end	
		if b.villain and not a.villain then
			return false
		end	
		if a.count == b.count then
			return a.name<b.name
		end	
		-- count
		return a.count < b.count
	end)
	units.totalCount = totalCount
	return units
end

function GetSquadsEnroute(sector, side)
	local squads = side=="enemy1" and g_EnemySquads or g_PlayerSquads	

	local enroute = {}
	for i, s in ipairs(squads) do
		if not s.route then goto continue end
		if s.CurrentSector == sector then goto continue end
		
		local breakOut = false
		for _, rs in ipairs(s.route) do
			for __, sec in ipairs(rs) do
				if sec == sector then
					enroute[#enroute + 1] = s
					breakOut = true
					break
				end
			end
			if breakOut then break end
		end
		::continue::
	end
	
	return enroute
end

function GetGroupedSquads(sector, includeMilitia, get_enemies, skip_retreat, exclude_travelling)
	local squads = {}
	local joiningSquads = {}
	local satSquads = {}
	local ally, enemy = GetSquadsInSector(sector, exclude_travelling, includeMilitia)
	if get_enemies then
		satSquads = enemy
	else 
		satSquads = ally
	end
	
	for i, s in ipairs(satSquads) do
		if skip_retreat and s.Retreat then goto continue end
	
		squads[#squads + 1] = s
		
		::continue::
	end
	
	-- Add joining squads to squads, or as seperate squads
	--[[for i, s in ipairs(joiningSquads) do
		if not merge_joining then
			squads[#squads + 1] = s
		else
			local targetSquadIdx = table.find(squads, "UniqueId", s.joining_squad)
			-- If a sector filter is applied the squad joining will not be here.
			if targetSquadIdx then
				local targetSquad = squads[targetSquadIdx]
				for ii, m in ipairs(s.units) do
					targetSquad.units[#targetSquad.units + 1] = m
				end
			end
		end
	end]]
	
	table.sort(squads, function (a, b)
		return a.UniqueId < b.UniqueId
	end)
	
	return #squads > 0 and squads or false
end

function GetSquadUnitCountWithJoining(squad_id)
	local squad = gv_Squads[squad_id]
	if not squad then return end
	local unitCount = #squad.units
	local unitCountWithJoining = unitCount

	for i, s in ipairs(g_SquadsArray) do	
		if s.joining_squad == squad_id then
			unitCountWithJoining = unitCountWithJoining + #s.units
		end
	end

	return unitCount, unitCountWithJoining
end

function GetMercArrayUnitData(units)
	local curList = {}	
	for i, m in ipairs(units) do
		curList[#curList + 1] = gv_UnitData[m]
	end
	return curList
end

function IsEnemySquad(squad_id)
	local side = gv_Squads[squad_id] and gv_Squads[squad_id].Side
	return side == "enemy1" or side == "enemy2"
end

function GetSquadMercsSplit(squad)
	local mercs = {}
	local curList = {}
	local units = squad.units
	for i, m in ipairs(units) do
		curList[#curList + 1] = m
		if #curList == const.Satellite.MercSquadMaxPeople then
			mercs[#mercs + 1] = curList
			curList = {}
		end
	end
	if #curList ~= 0 then
		mercs[#mercs + 1] = curList
	end
	
	return mercs
end

TFormat.ItemsGroupByTypeText = function(context_obj)
	if not context_obj then return end

	local countTable = {}
	for _, i in ipairs(context_obj) do
		if countTable[i.DisplayName] then
			countTable[i.DisplayName].count = countTable[i.DisplayName].count + 1
		else
			countTable[i.DisplayName] = { template = i, count = 1 }
		end
	end
		
	local textConstruct = T{""}
	for name, c in pairs(countTable) do
		if c.count > 1 then
			name = c.template.DisplayNamePlural
		end
		textConstruct = textConstruct .. T{800603753488, "<left><name><right><count><newline>", name = name, count = c.count}
	end
	
	return textConstruct
end

DefineClass.XZuluScroll = {
	__parents = { "XSleekScroll" },
	properties = {
		{ id = "BGColor", default = GameColors.DarkA, editor = "color" },
	},
	Image = false,
	src_rect = false,
	ThumbScale = point(350, 350)
}

function XZuluScroll:CalcSrcRect()
	if not self.src_rect then
		local w, h = UIL.MeasureImage(self.Image)
		self.src_rect = sizebox(0, 0, w, h)
	end
	return self.src_rect
end

function XZuluScroll:DrawBackground()
	local b = self.content_box
	UIL.DrawSolidRect(b, self.BGColor)
end

DefineClass.XTextLinger = {
	__parents = { "XText" },
	original = false,
	originalBox = false,
	time = false
}

function XTextLinger:Clone(originalXText)
	assert(IsKindOf(originalXText, "XText"))
	self:SetTranslate(originalXText.Translate)
	self:SetTextStyle(originalXText.TextStyle)
	self:SetText(originalXText.Text)
	self.original = originalXText
	
	self.UseClipBox = false
	self.Clip = false
	
	self:SetMargins(originalXText.Margins)
	self:SetPadding(originalXText.Padding)
	self:SetHandleMouse(false)

	self.originalBox = originalXText.content_box
	self:Invalidate()
end

function XTextLinger:LingerFor(time, fadeOut)
	self.time = time
	self:AddInterpolation{
		id = "fade",
		type = const.intAlpha,
		startValue = 255,
		endValue = 0,
		duration = fadeOut,
		visible = true,
		start = GetPreciseTicks() + time,
		on_complete = function(self, int)
			if self.window_state == "destroying" then return end
			self:delete()
		end,
	}
end

function XTextLinger:SetBox(...)
	if not self.originalBox then return end
	self.content_box = self.originalBox
	self.box = self.originalBox
end

function TableTake(table, number)
	if #table <= number then return table end
	local subTable = {}
	for i=1, number do
		subTable[i] = table[i]
	end
	return subTable
end

DefineClass.XContextImage = {
	__parents = { "XImage", "XContextWindow" }
}

DefineClass.XContextFrame = {
	__parents = { "XFrame", "XContextWindow" }
}

DefineClass.StatusEffectIcon = {
	__parents = { "XContextImage" },
	HandleMouse = true,
	UseClipBox = false,
	RolloverTemplate = "RolloverGeneric",
	RolloverText = T(304252861693, "<Description>"),
	RolloverTitle = T(733545694003, "<DisplayName>"),
	ImageScale = point(750, 750),
	IdNode = true
}

function StatusEffectIcon:Open()
	if self.context and self.context.Icon then self:SetImage(self.context.Icon) end
	XContextWindow.Open(self)
end

function AnyAttackInterrupt(unit, target, action, target_dummy)
	if action and (action.id == "CancelShot" or action.id == "CancelShotCone") or not target then return false end
	
	if action and action.ActionType == "Melee Attack" and action.AimType == "melee" and HasPerk(unit, "HardBlow") then
		return false
	end
	
	-- Pindown type interrupt
	local target_dummies = { target_dummy or unit.target_dummy or unit }
	local any = unit:CheckProvokeOpportunityAttacks("attack interrupt", target_dummies, true, "any")
	if any then
		return true
	end
	-- Overwatch type interrupt
	any = unit:CheckProvokeOpportunityAttacks("attack reaction", target_dummies, true, "any")
	if any then
		return true
	end
	return false
end

function AnyInterruptsAlongPath(unit, path, allInterrupts)
	local gotoDummies = unit:GenerateTargetDummiesFromPath(path)
	
	local mask = unit:GetItemInSlot("Head", "GasMask")
	local check_gas = (not mask or mask.Condition <= 0) and (next(g_SmokeObjs) ~= nil)
	local check_fire = next(g_Fire) ~= nil
	
	if check_gas or check_fire then
		local voxels = {}

		for i, dummy in ipairs(gotoDummies) do
			local _, headVoxel = unit:GetVisualVoxels(dummy.pos, dummy.stance, voxels)
			local smoke = g_SmokeObjs[headVoxel]
			if smoke and smoke:GetGasType() ~= "smoke" then
				if unit:GetDist(dummy.pos) < const.SlabSizeX / 2 then
					-- target dummies come in order of distance from the start, if we're already inside the gas there's no need to give off warnings
					break
				end
				return true
			end
			if 	AreVoxelsInFireRange(voxels) then
				if unit:GetDist(dummy.pos) < const.SlabSizeX / 2 then
					-- target dummies come in order of distance from the start, if we're already inside the gas there's no need to give off warnings
					break
				end
				return true
			end
		end
	end
	
	local interrupts = unit:CheckProvokeOpportunityAttacks("move", gotoDummies, true, allInterrupts and "all" or "any")
	if interrupts then
		return interrupts
	end
	return false
end

function IsMerc(o)
	local id
	if IsKindOf(o, "Unit") then
		id = o.unitdatadef_id
	elseif IsKindOf(o, "UnitData") then
		id = o.class
	elseif IsKindOf(o, "UnitDataCompositeDef") then
		return o.IsMercenary
	end
	return id and UnitDataDefs[id].IsMercenary
end

function VME_ViewPos_Game(obj, pos)
	if IsValid(obj) then
		if IsKindOf(obj, "Unit") then
			ViewAndSelectObject(obj)
		else
			ViewObject(obj)
		end
	else
		ViewPos(pos)
	end
end

function GetCurrentUITarget()
	local dlg = GetInGameInterfaceModeDlg()
	if dlg and IsKindOf(dlg, "IModeCombatAttackBase") and dlg.window_state ~= "destroying" then return dlg.target end
end

function GetZDifference(pos, d)
	if not pos:IsValidZ() and not d:IsValidZ() then return 0 end
	local start_z = pos:z() or terrain.GetHeight(pos)
	local z = d:z() or terrain.GetHeight(d)
	local z_diff = abs(start_z - z)
	return z_diff
end

function PlaceShrinkingObj(class, time, pos, scale, color, fx)
	local obj = PlaceObject(class)
	obj:SetPos(pos)
	obj:SetScale(scale or 100)
	if color then
		obj:SetColorModifier(color)
	end
	PlayFX(fx or "MoveCommand", "start", "Unit", false, pos)
	CreateGameTimeThread(function(o, time)
		local time_delta = 20
		local scale = obj:GetScale()
		local scale_delta = MulDivRound(time_delta, scale, time)
		while scale > 0 do
			Sleep(time_delta)
			scale = scale - scale_delta
			o:SetScale(scale > 0 and scale or 0)
		end
		DoneObject(o)
	end, obj, time)
end

function RunWhenXWindowIsReady(wnd, func, ...)
	if not wnd.layout_update then
		func(...)
	else
		local params = {...}
		local oldComplete = wnd.OnLayoutComplete
		wnd.OnLayoutComplete = function()
			wnd.OnLayoutComplete = oldComplete
			func(table.unpack(params))
			wnd:OnLayoutComplete()
		end
	end
end

TFormat.SquadName = function (context_obj)
	if not context_obj then return end
	if context_obj.militia then
		return T(121560205347, "MILITIA")
	end
	return T{788441578526, "<u(Name)>", context_obj}
end

TFormat.SquadNameColored = function (context_obj)
	if not context_obj then return end
	local _, colorTag = GetSectorControlColor(context_obj.Side)
	if context_obj.militia then
		return T{481087267106, "<controlColor>MILITIA</color>", controlColor = colorTag}
	end
	return T{492224151656, "<controlColor><u(Name)></color>", Name = context_obj.Name, controlColor = colorTag}
end

if Platform.developer then
function DebugDrawVoxelBBox(pos, voxel_range)
	local b = GetVoxelBBox(pos, voxel_range)
	local minx, miny = b:minxyz()
	local maxx, maxy = b:maxxyz()
	DbgAddBox(b, const.clrRed)
	DbgAddVector(point(minx, miny))
	DbgAddVector(point(minx, maxy))
	DbgAddVector(point(maxx, miny))
	DbgAddVector(point(maxx, maxy))
end
end

function GetVoxelBBox(pos, voxel_range, withZ, dontSnap)
	local x, y
	if dontSnap then
		x, y = pos:xy()
	else
		x, y = SnapToVoxel(pos:xyz())
	end
	local grow = (2 * (voxel_range or 0) + 1) * const.SlabSizeX / 2
	
	if withZ and pos:IsValidZ() then
		return box(x - grow, y - grow, pos:z() - grow, x + grow, y + grow, pos:z() + grow)
	else
		return box(x - grow, y - grow, x + grow, y + grow)
	end
end

function ConcatListWithAnd(list)
	local output = T{""}
	for i, item in ipairs(list) do
		if i == #list then
			output = output .. item
		elseif i == #list - 1 then
			if #list > 2 then
				output = output .. item .. T(289661130557, ", and ")
			else
				output = output .. item .. T(103700051305, " and ")
			end
		else
			output = output .. item .. T(642697486575, ", ")
		end
	end
	return output
end

function GetPlayerUnitsMaxDist()
	local max_dist = 0
	for i, team in ipairs(g_Teams) do
		if team.side == "player1" then
			for _, unit1 in ipairs(team.units) do
				for _, unit2 in ipairs(team.units) do
					if unit1 ~= unit2 then
						max_dist = Max(max_dist, unit1:GetDist2D(unit2))
					end
				end
			end
		end
	end
	return max_dist
end

DefineClass.XPopupSnapToWidth = {
	__parents = { "XPopup" },
	width_wnd = false
}

function XPopupSnapToWidth:SetBox(x, y, width, height)
	if self.width_wnd then
		local b = self.width_wnd.content_box
		if x < b:minx() then
			x = b:minx()
		end
		if x + width > b:maxx() then
			x = b:maxx() - width
		end
	end
	XPopup.SetBox(self, x, y, width, height)
end

function GetUnitInVoxel(pos)
	local cursorPos = pos or GetCursorPos()

	return MapGetFirst(GetVoxelBBox(cursorPos), "Unit", function (o, cursorZ)
		if not o:IsDead() then 
			if not o.visible then return end
			local x, y, z = o:GetPosXYZ()
			return (not z and not cursorZ) or z == cursorZ
		end
	end, cursorPos:z())
end

function InvokeShortcutAction(self, actionName, host, checkState)
	host = host or XShortcutsTarget
	if not host then return end
	local action = host:ActionById(actionName)
	if not action then return end
		
	if checkState then
		local state, err = action:ActionState(host)
		if state and state ~= "enabled" then return err end
	end

	host:OnAction(action, self)
end

function GetShortcutActionState(actionName, host)
	host = host or XShortcutsTarget
	if not host then return end
	local action = host:ActionById(actionName)
	if not action then return end
	
	return action:ActionState(host)
end

function GetSectorTimer(sector)
	local gp = sector.Guardpost and sector.guardpost_obj
	if gp then
		local time = gp and gp.next_spawn_time and gp.next_spawn_time - Game.CampaignTime
		return time and time > 0 and time < const.Satellite.GuardPostShowTimer and time
	
	else
		-- this counter may be used for debug purposes at some point
		--[[local _, enemy_squads = GetSquadsInSector(sector.Id, "excludeTravelling")
		for _, squad in ipairs(enemy_squads) do
			if squad.wait_in_sector then
				return Max(squad.wait_in_sector - Game.CampaignTime, 0)
			end
		end]]
	end
end

-- function TFormat.ShortcutButton(ctx, actionName, altShortcut)
-- function TFormat.ShortcutButton(ctx, keyboardShortcut, gamepadShortcut)
function TFormat.ShortcutButton(ctx, arg1, arg2)
	if not arg1 then return false end
	if arg2 and type(arg1) == "string" and type(arg2) == "string" then arg1 = { arg1, arg2 } end
	return GetShortcutButtonT(arg1) or ""
end

function TFormat.GamepadShortcutName(context_obj, shortcut)
	if not shortcut or shortcut == "" then
		return T(879415238341, "<negative>Unassigned</negative>")
	end
	local buttons = SplitShortcut(shortcut)
	for i, button in ipairs(buttons) do
		if GetAccountStorageOptionValue("GamepadSwapTriggers") then
			if button == "LeftTrigger" then
				button = "RightTrigger"
			elseif button == "RightTrigger" then
				button = "LeftTrigger"
			end
		end
	
		buttons[i] = const.TagLookupTable[button] or GetPlatformSpecificImageTag(button) or "?"
	end
	return Untranslated(table.concat(buttons))
end

local lDisplayKeyOverrides = {
	["Escape"] = T(939588806542, "ESC"),
	["Enter"] =  T(122085236350, "ENT"),
	["Insert"] = T(442527171248, "INS")
}
 
function GetShortcutButtonT(action)
	local shortcut1 = false
	local shortcutGamepad = false
	if type(action) == "string" then
		local shortcuts = GetShortcuts(action)
		if not shortcuts then return false end
		shortcut1 = shortcuts[1]
		shortcutGamepad = shortcuts[3]
	elseif IsKindOf(action, "XAction") then
		shortcut1 = action.ActionShortcut
		shortcutGamepad = action.ActionGamepad
	elseif type(action) == "table" then
		shortcut1 = action[1]
		shortcutGamepad = action[2]
	end
	
	if GetUIStyleGamepad() then
		if #(shortcutGamepad or "") == 0 then return false end
		
		local buttons = SplitShortcut(shortcutGamepad)
		for i, button in ipairs(buttons) do
			if GetAccountStorageOptionValue("GamepadSwapTriggers") then
				if button == "LeftTrigger" then
					button = "RightTrigger"
				elseif button == "RightTrigger" then
					button = "LeftTrigger"
				end
			end
			buttons[i] = button
		end
		
		for i, button in ipairs(buttons) do
			button = const.ShortenedButtonNames[button] or button
			buttons[i] = TLookupTag("<"..button..">") or "?"
		end
		
		return Untranslated(table.concat(buttons))
	else
		if #(shortcut1 or "") == 0 then return false end
		local buttons = SplitShortcut(shortcut1)
		for i, button in ipairs(buttons) do
			buttons[i] = lDisplayKeyOverrides[button] or KeyNames[VKStrNamesInverse[button]] or Untranslated(button)
		end	
		return T{116208420630, "<key>", key = table.concat(buttons, "-")}
	end
end

function TFormat.Bool(context_obj, val)
	return Untranslated(tostring(not not val))
end

if FirstLoad then
	g_ZuluMessagePopup = false
	NewGameObj = false
	NewGameObjOriginal = {difficulty = "Normal", game_rules = {}, settings = { HintsEnabled = true }, campaign_name = "", campaignId = "HotDiamonds"}
	
	MouseButtonImagesInText = {
		-- Add zulu specific images
		["MouseL"] = "UI/Icons/left_click.tga",
		["MouseR"] = "UI/Icons/right_click.tga",
		["MouseM"] = "UI/Icons/middle_click.tga",
		["MouseX1"] = "UI/Icons/button_3.tga",
		["MouseX1"] = "UI/Icons/button_4.tga",
		["MouseX2"] = "UI/Icons/button_5.tga",
		["MouseWheelFwd"] = "UI/Icons/scroll_up.tga",
		["MouseWheelBack"] = "UI/Icons/scroll_down.tga",
	}
end

function OnMsg.DataLoaded()
	ForEachPreset("GameRuleDef", function(rule)
		if rule.init_as_active then
			NewGameObjOriginal.game_rules[rule.id] = true
		end
	end)	
end

-- This modal steals mouse focus only when appropriate.
-- Project ZOrder Legend (Things that are spawned in desktop only)
-- 0: Tactical Notifications when PDA is open
-- 99: InGameMenu
-- 99: SetpieceDlg
-- 100: Tactical Notifications during setpiece
-- 100: Floor Display
-- 1000: ZuluMessageDialog
-- 1000000000: Loading Screen

DefineClass.ZuluModalDialog = {
	__parents = { "XDialog" },
	properties = {
		{ id = "GamepadVirtualCursor", editor = "bool", default = false }
	},
	
	HandleMouse = true,
}

function ZuluModalDialog:Open(...)
	LockCamera(self)
	
	if not g_ZuluMessagePopup then g_ZuluMessagePopup = {} end
	g_ZuluMessagePopup[#g_ZuluMessagePopup + 1] = self
	
	SetEnabledMouseViaGamepad(self.GamepadVirtualCursor, self)
	SetDisableMouseViaGamepad(not self.GamepadVirtualCursor, self)
	
	XDialog.Open(self, ...)
	Msg("ZuluMessagePopup", "open")
end

function ZuluModalDialog:Done(...)
	UnlockCamera(self)
	XDialog.Done(self, ...)
	
	if g_ZuluMessagePopup then
		table.remove_value(g_ZuluMessagePopup, self)
		if not next(g_ZuluMessagePopup) then g_ZuluMessagePopup = false end
	end
	Msg("ZuluMessagePopup", "close")

	SetEnabledMouseViaGamepad(false, self)
	SetDisableMouseViaGamepad(false, self)
end

function OnMsg.ZuluMessagePopup()
	ObjModified("layerButton")
	ObjModified("pda_tab")
end

function ZuluModalDialog:MouseInWindow(pt)
	return self:IsVisible() and self.window_state ~= "destroying"
end

function ZuluModalDialog:OnMousePos(...)
	XDialog.OnMousePos(self, ...)
	return "break"
end

function ZuluModalDialog:OnMouseButtonDown(pt, button)
	XDialog.OnMouseButtonDown(self, pt, button)
	if RolloverWin and button == "M" then return end -- More info
	return "break"
end

function ZuluModalDialog:OnMouseButtonUp(pt, button)
	XDialog.OnMouseButtonUp(self, pt, button)
	if RolloverWin and button == "M" then return end
	return "break"
end

function ZuluModalDialog:OnShortcut(shortcut, ...)
	if string.sub(shortcut, 1, 1) == "+" then return end 

	local result = XDialog.OnShortcut(self, shortcut, ...)
	if result == "break" then return result end
	
	local action = XShortcutsTarget:ActionByShortcut(shortcut, ...)
	if action and action.ActionId and (action.ActionId:sub(1, 3) == "DE_" or action.ActionId=="idBugReport") then
		XShortcutsTarget:OnShortcut(shortcut, ...)
	end

	-- Special exception :P
	if action and action.ActionId == "rolloverMoreInfo" then
		return
	end
	
	return "break"
end

function ZuluModalDialog:OnSetFocus()
	DelayedCall(0, RefreshPopupFocus)
end

function ZuluModalDialog:OnKillFocus()
	DelayedCall(0, RefreshPopupFocus)
end

function ZuluModalDialog:SetVisibleInstant(...)
	XDialog.SetVisibleInstant(self, ...)
	DelayedCall(0, RefreshPopupFocus)
end

function RefreshPopupFocus()
	if #(g_ZuluMessagePopup or empty_table) == 0 then return end
	
	local desktop = terminal.desktop
	local top, topZ = false, 0
	for i, popup in ipairs(g_ZuluMessagePopup) do
		if desktop and
		  popup:IsWithin(desktop) and
		  (not top or popup.ZOrder > topZ or popup.ZOrder == topZ) then
			top = popup
			topZ = popup.ZOrder
		end
	end

	local currentFocus = desktop.keyboard_focus
	if top and (not currentFocus or not currentFocus:IsWithin(top)) then
		top:SetFocus()
	end
end

function GetEnvironmentEffects(sectorId)
	if IsSectorUnderground(sectorId or gv_CurrentSectorId) then
		return { GameStateDefs.Underground }
	end
	
	if sectorId then
		local weather = GetCurrentSectorWeather(sectorId) or "ClearSky"
		local weatherPreset = GameStateDefs[weather]
		
		local tod = (Game and Game.Campaign and Game.CampaignTime) and CalculateTimeOfDay(Game.CampaignTime) or "Day"
		local todPreset = GameStateDefs[tod]
		
		return { weatherPreset, todPreset }
	end

	local effects = {}
	return ForEachPreset("GameStateDef", function(preset, group, effects)
		if #effects < 2 and GameState[preset.id] and preset.Icon and not table.find(effects, preset) then
			effects[#effects + 1] = preset
		end
	end, effects)
end

function TFormat.EnvironmentEffects()
	local effects = GetEnvironmentEffects()
	local str = false
	for i, ef in ipairs(effects) do
		local hLink = "<hyperlink " .. ef.id .. ">" .. _InternalTranslate(ef:GetDisplayName()) .. "</hyperlink>"
		if str then
			str = str .. " / " .. hLink
		else
			str = hLink
		end
	end
	return Untranslated(str)
end

function TFormat.OwnedPOI(ctx, poiName)
	local count = 0
	for i, s in pairs(gv_Sectors) do
		if s[poiName] and s.Side == "player1" then
			count = count + 1
		end
	end
	return count
end

-- temp, but possibly not
SyncCheck_NetSyncEventDispatch = return_true
SyncCheck_InGameInterfaceMode = return_true

function ShouldResetHashLogOnMapChange()
	return false
end

function TFormat.MercFlagImage(context_obj)
	if not context_obj or not context_obj.Nationality then return "" end
	local nationalityPreset = Presets.MercNationalities.Default[context_obj.Nationality]
	if nationalityPreset.Icon then
		return Untranslated("<image " .. nationalityPreset.Icon .. ">")
	end
	return ""
end

function TFormat.StatPercent(context_obj, stat, percent)
	local statAmount = ResolveValue(context_obj, stat)
	if not statAmount then statAmount = ResolveValue(context_obj, "unit", stat) end
	if not statAmount then return end
	
	local result = MulDivRound(statAmount, percent, 100)
	return result
end

-- Expected an array of arrays in which the first element is the weight and the second is the item.
function GetWeightedRandom(weights, seed)
	local totalPool = 0
	for i, weight in ipairs(weights) do
		totalPool = totalPool + weight[1]
	end

	local rand = BraidRandom(seed or AsyncRand(), totalPool) + 1
	
	for i, weight in ipairs(weights) do
		rand = rand - weight[1]
		if rand <= 0 then
			return weight[2]
		end
	end
end

DefineClass.UnitFloatingText = {
	__parents = { "XFloatingText" },
	interpolate_opacity = true,
	default_spot = "Headstatic",
	
	pushUpExtra = 20,
}

function UnitFloatingText:OffsetBox(x, y)
	if not self.context then return x, y end
	
	local extraPush = self.pushUpExtra
	local minPushUp = extraPush
	if not IsKindOf(self.context, "Unit") then
		minPushUp = 80
	end
	
	if IsSetpiecePlaying() then
		return x, y - extraPush
	end
	
	local igi = GetInGameInterfaceModeDlg()
	if igi and IsKindOf(igi, "IModeCombatAttackBase") and igi.crosshair and igi.crosshair.context and igi.crosshair.context.target == self.context then
		return x, y - igi.crosshair.box:sizey() / 2
	end
	
	local unitBadges = g_Badges[self.context]
	if not unitBadges then return x, y end
	
	-- Find the badge with the highest Y (lowest since Y axis is negative up)
	local highestY = false
	for i, b in ipairs(unitBadges) do
		if b and b.ui and b.ui.visible then
			local badgeUI = b.ui
			
			-- Wait layout
			while badgeUI.box == empty_box do
				Sleep(1)
			end
			
			local badgeMin = badgeUI.box:miny()
			if not highestY then
				highestY = badgeMin
			else
				highestY = Min(badgeMin, highestY)
			end
		end
	end
	if not highestY then highestY = 0 end

	local push = highestY - minPushUp
	return x, y + push
end

function UnitFloatingText:RecalculateBox()
	local width, height = self:Measure(self.MaxWidth, self.MaxHeight)
	local minx, miny, maxx, maxy = self:GetEffectiveMargins()
	local xLoc = -(width / 2) + minx
	local yLoc = -height + miny
	
	height = height + -yLoc
	xLoc, yLoc = self:OffsetBox(xLoc, yLoc)
	
	local x1, y1, x2, y2 = ScaleXY(self.scale, self.Padding:xyxy())
	self:SetBox(xLoc - x1, yLoc - y1, width + maxx + x1 + x2, height + maxy + y1 + y2, false)
end

DefineClass.CantAttackFloatingText = {
	__parents = { "XFloatingText" },
	TextStyle = "FloatingTextError",
	exclusive = true,
	stagger_spawn = false,
	exclusive_discard = true
}

function CheckImpossibleAttack(unit, action, args)
	if HasCombatActionInProgress(unit) and not unit.interruptable then 
		return false 
	end
	
	args = args or {}
	local state, err = action:GetUIState({unit}, args)

	local weapon = action:GetAttackWeapons(unit)
	local canAttack, reason = unit:CanAttack(
		args.target,
		weapon, action,
		args and args.aim,
		args and args.goto_pos,
		nil,
		args.free_aim
	)
	reason = reason or not canAttack and T(138935217566, "Action not possible")
	
	if state == "enabled" then
		return canAttack and "enabled" or "disabled", reason
	end
	
	return state, err
end

function CheckAndReportImpossibleAttack(unit, action, args)
	if HasCombatActionInProgress(unit) and not unit.interruptable then 
		return false 
	end
	
	args = args or empty_table
	local state, err = action:GetUIState({unit}, args)

	local weapon = action:GetAttackWeapons(unit)
	local canAttack, reason = unit:CanAttack(
		args.target,
		weapon, action,
		args and args.aim,
		args and args.goto_pos,
		nil,
		args.free_aim
	)
	reason = reason or not canAttack and T(138935217566, "Action not possible")
	if reason then ReportAttackError(IsValid(args.target) and args.target or unit, reason) end
	
	if state == "enabled" then
		return canAttack and "enabled" or "disabled"
	end
	ReportAttackError(IsValid(args.target) and args.target or unit, err or T(818027394095, "Action not available."))
	return state
end

function ReportAttackError(obj, err)
	local floatingErr = _InternalTranslate(err, {["flavor"] = "<color FloatingTextError>"})
	local front, pt = GameToScreen(IsPoint(obj) and obj or obj:GetPos())
	if not front or not terminal.desktop.box:PointInside(pt) then
		CreateCustomFloatingText(XTemplateSpawn("CantAttackFloatingText", GetDialog("FloatingTextDialog")), GetTerrainCursor(), floatingErr	)
	else
		CreateCustomFloatingText(XTemplateSpawn("CantAttackFloatingText", GetDialog("FloatingTextDialog")), obj, floatingErr	)
	end
	CombatLog("short", err)
end

function FindBandagingUnit(downedUnit)
	if not downedUnit:IsDowned() then return end
	local allies = GetAllAlliedUnits(downedUnit)
	for i, ally in ipairs(allies) do
		if ally:GetBandageTarget() == downedUnit then
			return ally
		end
	end
	return false
end

function IsPausedByGameLogic()
	return (IsPaused() and not IsActivePaused()) and not (GetDialog("PDADialogSatellite") or gv_Deployment or GetDialog("RadioBanterDialog") or GetDialog("FullscreenGameDialogs"))
end

-- Used by UI to delay certain animations and actions until after various gameplay interruptions.
function AnyPlayerControlStoppers(params)
	if GetDialog("ConversationDialog") then return true end
	if IsSetpiecePlaying() then return true end
	if IsRepositionPhase() then return true end
	if GetDialog("PopupNotification") then return true end
	
	if not params or not params.skip_pause then
		if IsPausedByGameLogic() then return true end
	end
end

function WaitPlayerControl(params)
	local anyStoppersAtAll = false
	local anyStoppers = true
	while anyStoppers do
		anyStoppers = false
		if GetDialog("ConversationDialog") then
			anyStoppers = true
			WaitMsg("CloseConversationDialog", 100)
		end
		if GetDialog("CoopMercsManagement") then
			anyStoppers = true
			Sleep(500)
		end
		if not params or not params.skip_setpiece then
			if IsSetpiecePlaying() then
				anyStoppers = true
				WaitMsg("SetpieceDialogClosed", 100)
			end
		end
		while IsRepositionPhase() do
			anyStoppers = true
			WaitMsg("RepositionEnd", 100)
		end
		if not params or not params.skip_popup then
			while GetDialog("PopupNotification") do
				anyStoppers = true
				local popupNot = GetDialog("PopupNotification")
				WaitMsg(popupNot, 100)
			end
		end
		if IsPausedByGameLogic() and (not params or not params.no_coop_pause or IsCampaignPausedByRemotePlayerOnly()) then
			anyStoppers = true
		end
		if anyStoppers then
			Sleep(1000) -- The above interruptors can spawn another interruptor.
			anyStoppersAtAll = true
		end
	end
	return anyStoppersAtAll
end

function FindTextStyle(fontName, color)
	local results = {}
	for i, t in pairs(TextStyles) do
		local nameTranslated = _InternalTranslate(t.TextFont)
		if nameTranslated == fontName and t.TextColor == color then
			results[#results + 1] = t.id
		end
	end
	return #results == 0 and "create a new one" or results
end

function FindDuplicateTextStyles()
	local duplicate = {}
	local dedupePair = {}
	for i, t in pairs(TextStyles) do
		for i2, t2 in pairs(TextStyles) do
			local nameTranslated = _InternalTranslate(t.TextFont)
			local nameTranslated2 = _InternalTranslate(t2.TextFont)
			if
				t.group ~= "Common" and t2.group ~= "Common" and
				t.group ~= "Zulu Old" and t2.group ~= "Zulu Old" and
				not string.find(nameTranslated, "droid") and not string.find(nameTranslated2, "droid") and
				i ~= i2 and
				nameTranslated == nameTranslated2 and
				t.TextColor == t2.TextColor and
				t.RolloverTextColor == t2.RolloverTextColor and
				t.ShadowType == t2.ShadowType and t.ShadowColor == t2.ShadowColor and
				t.DisabledTextColor == t2.DisabledTextColor and 
				t.DisabledRolloverTextColor == t2.DisabledRolloverTextColor then
				
				if not dedupePair[t.id] or not dedupePair[t.id][t2.id] then
					duplicate[#duplicate + 1] = t.id .. " is like " .. t2.id
				end
				
				if not dedupePair[t.id] then dedupePair[t.id] = {} end
				dedupePair[t.id][t2.id] = true
				
				if not dedupePair[t2.id] then dedupePair[t2.id] = {} end
				dedupePair[t2.id][t.id] = true
			end
		end
	end
	return duplicate, #duplicate
end

DefineClass.ZuluContextMenu = {
	__parents = { "XPopup", "XDrawCache", "XActionsHost" },
	
	RefreshInterval = 1000,
	MinWidth = 200,
	
	Background = GameColors.B,
	FocusedBackground = GameColors.B,
	BackgroundRectGlowSize = 1,
	BackgroundRectGlowColor = GameColors.A,
	
	BorderColor = GameColors.A,
	FocusedBorderColor = GameColors.A,
	BorderWidth = 2,
	ChildAnchorType = false,
	
	applied_virtual_cursor_disable = false
}

function ZuluContextMenu:Init()
	if not ZuluMouseViaGamepadDisableReasons or not table.find(ZuluMouseViaGamepadDisableReasons, "context-menu") then
		SetDisableMouseViaGamepad(true, "context-menu")
		self.applied_virtual_cursor_disable = true
	end
end

function ZuluContextMenu:Done()
	if self.applied_virtual_cursor_disable then
		SetDisableMouseViaGamepad(false, "context-menu")
	end
end

function ZuluContextMenu:Open()
	if self.RefreshInterval then
		self:CreateThread("UpdateRolloverContent", function(self)
			while true do
				Sleep(self.RefreshInterval)
				self:UpdateRolloverContent()
			end
		end, self)
	end
	XPopup.Open(self)
	local popparent = self.popup_parent 
	if IsKindOf(popparent, "XPopup") and popparent.ChildAnchorType then
		self:SetAnchorType(popparent.ChildAnchorType)
	end
	local pda = gv_SatelliteView and GetDialog("PDADialogSatellite")
	pda = pda and pda.visible
	self:SetMouseCursor(pda and "UI/Cursors/Pda_Cursor.tga" or const.DefaultMouseCursor)
end

function ZuluContextMenu:UpdateRolloverContent()
	local content = rawget(self, "idContent")
	if content then
		content:OnContextUpdate(content.context)
	end
end

function ZuluContextMenu:GetCustomAnchor(x, y, width, height, anchor)
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	-- right
	x = anchor:maxx() + margins_x1
	y = anchor:miny() - margins_y1	
	self.ChildAnchorType = "right"
	--left
	if x + 2*width + margins_x2 > safe_area_x2 then
		x = anchor:minx() - width - margins_x2 --move to left side
		self.ChildAnchorType = "left"
	end
	return x, y, width, height
end


DefineClass.AutoFitText = {
	__parents = { "XText" },
	WordWrap = false,
	properties = {
		{ id = "SafeSpace", editor = "number", default = 0 }
	}
}

function AutoFitText:UpdateMeasure(...)
	self.scale = self.parent.scale
	return XText.UpdateMeasure(self, ...)
end

function AutoFitText:Measure(max_width, max_height)
	self.scale = self.parent.scale
	self.content_measure_width = max_width
	self.content_measure_height = max_height
	
	if self.WordWrap then
		self:UpdateDrawCache(max_width, max_height, true)
	else
		self:UpdateDrawCache(9999999, max_height, true)
	end
	
	local scaleDiff = 1000
	local sizeNeeded = self.text_width + ScaleXY(self.scale, self.SafeSpace)
	local height = Clamp(self.text_height, self.font_height, max_height)
	local redoMeasure = false
	if sizeNeeded > max_width then
		scaleDiff = MulDivRound(max_width, 1000, sizeNeeded)
		redoMeasure = self.HAlign == "center" or self.HAlign == "right"
	end
	self.ScaleModifier = point(scaleDiff, scaleDiff)
	self.scale = point(ScaleXY(self.parent.scale, self.ScaleModifier:xy()))
	if redoMeasure then self:UpdateDrawCache(max_width, max_height, true) end
	return self.text_width, height
end

DefineClass.XTextWithStyleBasedOnSize = {
	__parents = { "XText" },
	properties = {
		{ editor = "text", id = "TextStyleSmall", editor = "preset_id", default = "GedDefault", invalidate = "measure", preset_class = "TextStyle", editor_preview = true }
	}
}

function XTextWithStyleBasedOnSize:Measure(max_width, max_height)
	self:SetTextStyle(self.TextStyle)
	
	local text = _InternalTranslate(self.Text, self.context)
	local break_candidate = utf8.FindNextLineBreakCandidate(text, 1)
	local largestBreakSize = false
	while break_candidate and break_candidate <= #text + 1 do
		local breakSize = UIL.MeasureText(text, self:GetFontId(), 1, break_candidate - 1)
		largestBreakSize = Max(largestBreakSize or 0, breakSize)
		break_candidate = utf8.FindNextLineBreakCandidate(text, break_candidate)
	end
	if largestBreakSize and largestBreakSize > max_width then
		self:SetTextStyle(self.TextStyleSmall)
	end
	
	return XText.Measure(self, max_width, max_height)
end

function EnemySquadsComboItems(excl_test) 
	if excl_test then
		local res = {}
		for _, squad in pairs(EnemySquadDefs) do
			if squad.group ~= "Test Encounters" then 
				table.insert(res, squad)
			end
		end
		return res
	end
	return table.keys(EnemySquadDefs, true)
end

function GetPersistentSessionIds()
	local res = {}
	for _, unitT in pairs(UnitDataDefs) do 
		if unitT.PersistentSessionId then
			table.insert(res, unitT.PersistentSessionId)
		end
	end
	return res
end

function PercentModifyByDifficulty(diff_value)
	local baseValDiffPerc = 100
	if type(diff_value) == "number" then 
		baseValDiffPerc = baseValDiffPerc + diff_value
	end
		
	return baseValDiffPerc 
end

-- Dirty fix for std popups until we get out own.
StdDialog.ZOrder = 100

function XDesktop:UpdateCursor(pt)
	pt = pt or self.last_mouse_pos
	if not pt then return end
	local target, cursor = self.modal_window:GetMouseTarget(pt)
	target = target or self.modal_window
	if self.mouse_capture and target ~= self.mouse_capture then
		cursor = self.mouse_capture:GetMouseCursor()
		target = false
	end
	local pda = gv_SatelliteView and GetDialog("PDADialogSatellite")
	pda = pda and pda.visible and pda
	local curr_cursor = pda and pda.mouse_cursor or cursor or const.DefaultMouseCursor
	if prev_cursor ~= curr_cursor then
		SetUIMouseCursor(curr_cursor)
		Msg("MouseCursor", curr_cursor)
		prev_cursor = curr_cursor
	end
	return target
end

local oldRestoreFocus = XDesktop.RestoreFocus
function XDesktop:RestoreFocus(...)
	oldRestoreFocus(self, ...)
	RefreshPopupFocus()
end

if FirstLoad then
TermsInText = false
end

function TFormat.GameTerm(context_obj, word)
	if not word then
		print("no game term specified in tag!")
		return
	end

	if not TermsInText then TermsInText = {} end
	if not TermsInText[word] then
		TermsInText[#TermsInText + 1] = word
		TermsInText[word] = word
	end
	
	local terms = Presets.GameTerm.Default
	if terms[word] then
		return T{961635936261, "<em><TermName></em>", TermName = terms[word].Name }
	end
	return Untranslated(word .. "(GameTerm preset missing)")
end

function TFormat.AdditionalTerm(context_obj, word)
	if not word then
		print("no game term specified in tag!")
		return
	end

	if not TermsInText then TermsInText = {} end
	if not TermsInText[word] then
		TermsInText[#TermsInText + 1] = word
		TermsInText[word] = word
	end
	
	local terms = Presets.GameTerm.Default
	if terms[word] then
		return ""
	end
	return Untranslated(word .. "(GameTerm preset missing)")
end


function GetGameTermsInText(text)
	if not TermsInText then TermsInText = {} end
	table.clear(TermsInText)
	_InternalTranslate(text)
	return table.copy(TermsInText)
end

DefineClass.TermClarifyingRollover = {
	__parents = { "XRolloverWindow", "XContextWindow" },
	ContextUpdateOnOpen = true,
	
	termUI = false
}

function TermClarifyingRollover:OnContextUpdate()
	local textControl = self and self.idContent and self.idContent.idText
	local terms = textControl and GetGameTermsInText(textControl.Text) or empty_table
	self:ShowTerms(terms)
	return terms
end

function TermClarifyingRollover:GetCustomAnchor(x, y, width, height, anchor)
	if self.context and self.context.control and self.context.control.bottomAnchor then
		return self:GetBottomAnchor(x, y, width, height, anchor)
	end

	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())

	local termWidth = (self.termUI and self.termUI.measure_width or 0)
	x = anchor:minx() + ((anchor:maxx() - anchor:minx()) - (width + termWidth))/2
	y = anchor:miny() - height - margins_y2
	
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	if self.termUI then
		--local dock = x < safe_area_x1 and "right" or "left" bad idea
		local dock = "right"
		if self.termUI.Dock ~= dock then
			self.termUI:SetDock(dock)
		end
		if dock == "right" then
			x = x + termWidth
		end
	end
	
	return x, y, width, height
end

function TermClarifyingRollover:GetBottomAnchor(x, y, width, height, anchor)
	local margins_x1, margins_y1, margins_x2, margins_y2 = ScaleXY(self.scale, self.Margins:xyxy())

	local termWidth = (self.termUI and self.termUI.measure_width or 0)

	x = anchor:minx() + ((anchor:maxx() - anchor:minx()) - (width + termWidth))/2
	y = anchor:maxy() + margins_y2
	
	local safe_area_x1, safe_area_y1, safe_area_x2, safe_area_y2 = self:GetSafeAreaBox()
	if self.termUI then
		local dockX = x < safe_area_x1 and "right" or "left"
		if self.termUI.Dock ~= dockX then
			self.termUI:SetDock(dockX)
		end
		if dockX == "right" then
			x = x + termWidth
		end
		
		if  y + height + margins_y2 > safe_area_y2 then
			y = anchor:miny() - height - margins_y2
			self.idContent:SetVAlign("bottom")
		else
			self.idContent:SetVAlign("top")
		end
		
	end
	
	return x, y, width, height
end

DefineClass.PDATermClarifyingRollover = {
	__parents = { "PDARolloverClass", "TermClarifyingRollover" },
}

function PDATermClarifyingRollover.Open(self)
	PDARolloverClass.Open(self)
	self:OnContextUpdate(self.context, "open")
end

function TermClarifyingRollover:ShowTerms(terms)
	local ctx = SubContext(self.context, { terms = terms })
	if not self.termUI then
		local clarification = XTemplateSpawn("RolloverTermClarification", self, ctx)
		clarification:Open()
		self.termUI = clarification
	end

	self.termUI.idContent:SetContext(ctx)
	if #terms == 0 then
		self.termUI:SetVisible(false)
	end
end

function TermClarifyingRollover:OnDelete()
	if self.termUI and self.termUI.window_state ~= "destroying" then
		self.termUI:Close()
	end
end

function numberToTimeDate(number, real_time)
	if type(number) ~= "number" and real_time then 
		number = os.time()
	end
	local osDateFormat = GetDateTimeOrder()
	local saveTimeAsTable = GetTimeAsTable(number, real_time)
	
	local saveTime = string.format("%02d", saveTimeAsTable.hour)  .. ":" .. string.format("%02d", saveTimeAsTable.min)
	local saveDate = {}
	for i, unit in ipairs(osDateFormat) do
		saveDate[i] = saveTimeAsTable[unit]
	end
	saveDate = table.concat(saveDate, "/")
	local finalTimeDate = saveTime .. " " .. saveDate
	return finalTimeDate
end

function TFormat.StatusEffectParam(context_obj, effect, param)
	local effect = g_Classes[effect]
	if not effect then return Untranslated("Couldn't find effect ".. effect) end
	local val = effect:ResolveValue(param) or 0
	return val
end

local SaveStatesT = {
	Exploration = T(995350103389, "Exploration"),
	TurnEnd = T(987479599419, "Turn <number> End"),
	Turn = T(214899348072, "Turn <number>"),
	CombatEnd = T(399785668141, "Combat End"),
	CombatStart = T(742715930390, "Combat Start"),
	NewDay = T(763044143109, "New Day"),
	SectorEnter = T(874301202187, "Sector Enter"),
	ExitGame = T(184190822120, "Exit Game"),
	Ending = T(658082619539, "Ending"),
}

function GetSaveState(state, saveStateTurnNumber)
	if SaveStatesT[state] then
		return T{SaveStatesT[state], number = saveStateTurnNumber}
	end
		
	return T(831373652255, "Satellite")
end
function TFormat.MercClass(context_obj)
	local specName = Presets.MercSpecializations.Default
	specName = context_obj and specName[context_obj.Specialization]
	specName = specName and specName.name
	return specName
end

if FirstLoad then
g_RolloverShowMoreInfo = false
g_RolloverShowMoreInfoFakeRollover = false
end

local energyEffects = {
	"WellRested"
}

RedEnergyEffects = {
	"Tired",
	"Exhausted",
	"Unconscious"
}

local noEnergyEffect = T(102280983313, "Normal")

function TFormat.EnergyStatusEffect(context_obj)
	-- Check for red
	for i, ef in ipairs(RedEnergyEffects) do
		if context_obj:HasStatusEffect(ef) then
			if g_Classes[ef]:ResolveValue("ap_loss") then
				return T{648417490486, "<error><EffectName></error> (<ApValue>AP)", EffectName = g_Classes[ef].DisplayName, ApValue = g_Classes[ef]:ResolveValue("ap_loss")}
			else
				return T{753249704554, "<error><EffectName></error>", EffectName = g_Classes[ef].DisplayName}
			end
		end
	end
	
	-- Check for effect
	for i, ef in ipairs(energyEffects) do
		if context_obj:HasStatusEffect(ef) then
			if g_Classes[ef]:ResolveValue("ap_gain") then
				return T{213633160729, "<effectName> (+<apValue>AP)", effectName = g_Classes[ef].DisplayName, apValue = g_Classes[ef]:ResolveValue("ap_gain")}
			else
				return g_Classes[ef].DisplayName
			end
		end
	end
	
	return noEnergyEffect
end

function TFormat.MercMoraleText(context_obj)
	local personalMorale = context_obj:GetPersonalMorale()
	return MoraleLevelName[personalMorale] .. ( personalMorale ~= 0 and T{450959430309, " (<apValue>AP)", apValue = personalMorale > 0 and (Untranslated("+") .. personalMorale) or personalMorale} or "")
end

function TFormat.MoreInfoDynamic()
	return T(998024303154, "[<ShortcutButton('rolloverMoreInfo')>] ") ..
		(g_RolloverShowMoreInfo and T(917639413507, "Hide Info") or T(979175068963, "More Info"))
end

function HasMoreInfo(context)
	if not context then return false end
	if g_RolloverShowMoreInfoFakeRollover then
		return true
	end
	local moreInfo
	if context.termUI and context.termUI.context.terms then
		moreInfo = #context.termUI.context.terms > 0
	else
		moreInfo = context:ResolveId("idMoreInfo")
		if not moreInfo then
			local content = context:ResolveId("idContent")
			moreInfo = content and content:ResolveId("idMoreInfo")
		end
	end
	return not not moreInfo
end

date_format_cache = {}

function GetDateFormat(to_remove)
	to_remove = to_remove or "don't remove anything"
	if date_format_cache[to_remove] then return date_format_cache[to_remove] end

	-- Prepare date formats used through the PDA.
	local systemDateFormat = GetDateTimeOrder()
	local dateFormat = {}
	for i, unit in ipairs(systemDateFormat) do
		if unit ~= to_remove then
			dateFormat[#dateFormat + 1] = "<" .. unit .. "(t)>"
		end
	end

	date_format_cache[to_remove] = table.concat(dateFormat, " ")
	return date_format_cache[to_remove]
end

function TFormat.DateFormatted(context, time)
	return T{GetDateFormat("year"), t = time}
end

function TFormat.DateFormattedIncludingYear(context, time)
	return T{GetDateFormat(), t = time}
end

local neverGuilty = { "Psycho", "StressManagement", "Optimist", "Drunk", "TheGrim" }
local superstitious = { "Spiritual", "GloryHog", "Pessimist", "Nazdarovya" }
local neverProud = { "OldDog", "TheGrim" } 
local prideful = { "Spiritual", "GloryHog", "BunsPerk", "BuildingConfidence" } 
function ApplyGuiltyOrRighteousEffect(applyEffect)
	assert(not gv_SatelliteView)
	assert(gv_CurrentSectorId)
	assert(applyEffect)
	
	local mercs = GetAllPlayerUnitsOnMap()
	for i, merc in ipairs(mercs) do
		local effectType = applyEffect == "positive" and "Conscience_Proud" or "Conscience_Guilty"
		
		for _, effect in ipairs(applyEffect == "positive" and neverProud or neverGuilty) do
			if merc:HasStatusEffect(effect) then
				effectType = false
				break
			end
		end
		
		if effectType then
			for _, effect in ipairs(applyEffect == "positive" and prideful or superstitious) do
				if merc:HasStatusEffect(effect) then
					effectType = applyEffect == "positive" and "Conscience_Righteous" or "Conscience_Sinful"
					break
				end
			end
		end
		
		if effectType then
			merc:AddStatusEffect(effectType)
		end
	end
end

function AllUnitsOfGroupAreNeutral(group)
	local anyOfGroup = false
	for i, u in ipairs(g_Units) do
		if u:IsInGroup(group) then
			anyOfGroup = true
			if IsPlayerEnemy(u) then
				return false
			end
		end
	end
	return anyOfGroup
end

-- Used for tracking one time UI animations such as
-- when an event or UI elements shows up for the first time.
-- Also for tracking UI animation start times
GameVar("UIAnimationsShown", function() return {} end)

function WasAnimationShown(id)
	return not not UIAnimationsShown[id]
end

function AnimationWasShown(id)
	UIAnimationsShown[id] = true
end

function AnimationShownReset(id)
	UIAnimationsShown[id] = false
end

function TFormat.Nick(context_obj, id)
	local merc = gv_UnitData[id]
	if IsMerc(merc) then
		return merc.Nick
	end
end

function TFormat.CombatTask(context_obj, id)
	local def = CombatTaskDefs[id]
	if def then
		return def.name
	end
end

function TFormat.Quest(context_obj, id)
	local def = Quests[id]
	if def then
		return def.DisplayName
	end
end

DefineClass.XWindowWithRolloverFX = {
	__parents = { "XContextWindow" }
}

function XWindowWithRolloverFX:OnSetRollover(rollover)
	if rollover then PlayFX("buttonRollover", "start") end
end

DefineClass.RespawningButton = {
	__parents = { "XButton", "XContentTemplate" }

}

function RespawningButton:OnShortcut(...)
	XButton.OnShortcut(self, ...)
end

ForbiddenShortcutKeys = {
	Lwin = true,
	Rwin = true,
	Menu = true,
	MouseL = true,
	MouseR = true,
	Enter = true,
}

function DifficultyToNumber(diff, wisdom)
	if type(diff) == "number" then 
		assert(false, "The difficulty should be of type string.")
		return diff 
	end
	local entry = wisdom and table.find_value(const.DifficultyPresetsWisdomMarkersNew, "id", diff) or table.find_value(const.DifficultyPresetsNew, "id", diff)
	if entry then
		return entry.value
	elseif tonumber(diff) then
		return tonumber(diff) -- Edge case in conversion to new values, some were leftover and converted to string
	else
		assert(false, "This difficulty is non-existent.")
		return 0
	end
end

function BoxIntersectsBox(boxOne, boxTwo)
	return boxTwo:minx() < boxOne:maxx() and
		boxOne:minx() < boxTwo:maxx() and
		boxTwo:miny() < boxOne:maxy() and
		boxOne:miny() < boxTwo:maxy()
end

function PointMax(po, max)
	return point(Max(po:x(), max), Max(po:y(), max))
end

function PointMin(po, min)
	return point(Min(po:x(), min), Min(po:y(), min))
end

DefineClass.ZuluFrameProgress = {
	__parents = { "XFrameProgress" },
	ProgressClip = true
}

function IsPlayerSide(side)
	return side == "player1" or side == "player2"
end

function IsEnemySide(side)
	return side == "enemy1" or side == "enemy2" or side == "enemyNeutral"
end

local commonGetShortcuts = GetShortcuts
function GetShortcuts(action_id)
	local shortcuts = commonGetShortcuts(action_id)
	if shortcuts then
		for i, sh in ipairs(shortcuts) do
			if sh == "" then
				shortcuts[i] = false
			end
		end
	end
	return shortcuts
end

function OpenStartButton()
	local startBut

	local satDiag = GetDialog("PDADialogSatellite")
	satDiag = satDiag and satDiag.idContent
	
	local pda = GetDialog("PDADialog")
	pda = pda and pda.idContent
	local browser = pda and pda.idBrowserContent
	pda = browser or pda
	
	local inventoryUI = GetDialog("FullscreenGameDialogs")

	if pda then
		startBut = pda:ResolveId("idStartButton")
	elseif inventoryUI then
		startBut = inventoryUI.idStartButton
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	elseif satDiag then
		startBut = satDiag:ResolveId("idStartButton")
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	else
		local igi = GetInGameInterfaceModeDlg()
		startBut = igi and igi:ResolveId("idStartButton")
		startBut = startBut and startBut:ResolveId("idStartButtonInner")
	end

	if not startBut or not startBut:IsVisible() then return end
	startBut:OnPress()
end

function TFormat.PercentInvert(context_obj, value)
	if not value then return 0 end
	return 100 - value
end

-- Version of this command that works with the Unit class and our voxel system
function SetpieceTeleportNear:Exec(state, Actors, DestinationActor, Radius, Face)
	if Actors == "" or DestinationActor=="" then return end
	
	local ptCenter = GetWeightPos(DestinationActor)
	local ptActors = GetWeightPos(Actors)
	local base_angle = #DestinationActor > 0 and DestinationActor[1]:GetAngle()
	
	if ptCenter:Dist(ptActors) < Radius * guim then return end
	
	local radiusBbox = GetVoxelBBox(ptCenter, Radius, "with_z")
	local dest_pos = false
	ForEachPassSlab(radiusBbox, function(x, y, z)
		if z == ptCenter:z() and not IsOccupiedExploration(nil, x, y, z) then
			local p = point(x, y, z)
			if not dest_pos or IsCloser(p, ptCenter, dest_pos) then
				dest_pos = p
			end
		end
	end)
	if not dest_pos then return end
	
	if not ptActors:IsValidZ() then
		ptActors = ptActors:SetTerrainZ()
	end

	local base_angle = #Actors > 0 and Actors[1]:GetAngle()
	for _, actor in ipairs(Actors) do
		local pos = actor:GetVisualPos()
		local offset = Rotate(pos - ptActors, actor:GetAngle() - base_angle)
		local dest = actor:GetPos() + offset		
		actor:SetAcceleration(0)
		actor:SetPos(dest_pos, 0)
		if IsKindOf(actor, "Unit") then
			actor:SetTargetDummy(false)
		end
		if Face then
			actor:Face(ptCenter)
		end
	end
end

function GoToSubMenu_OnAction(self, host, source, ...)
	if self:ActionState() == "enabled" then
		local subMenuList = host:ResolveId("idSubMenu"):ResolveId("idScrollArea")
		if subMenuList then
			subMenuList:SelectFirstValidItem()
		end
	end
end

function GoToSubMenu_ActionState(self, host)
	local dlg = GetDialog(terminal.desktop.keyboard_focus)
	local focusOnMMButton = dlg.Id == "idMainMenuButtonsContent" 
	return focusOnMMButton and "enabled" or "disabled"
end

-- Used for quests or custom stuff where the player has to pick a merc.
function UIChooseMerc(text)
	assert(CanYield())
	local dlg = OpenDialog("MercSelectionDialog", GetInGameInterface())
	dlg.idHeaderText:SetText(text)
	return dlg:Wait()
end

DefineConstInt("Default", "InteractionActionProgressBarTime", 1500, false, "The time it takes for the interaction progress bar to fill up in milliseconds")

function SpawnProgressBar(time, text)
	local bar = XTemplateSpawn("InteractionProgressBar", GetInGameInterface())
	bar.idBar:SetTimeProgress(GameTime(), GameTime() + time, true)
	bar:Open()
	bar:CreateThread("after", function()
		Sleep(time + 10)
		bar:Close()
	end)
	return bar;
end

function CloseOptionsChoiceSubmenu(ui)
	local dialog = GetDialog(ui):ResolveId("idSubSubContent")
	local choiceProp = GetDialogModeParam(dialog)
	if choiceProp then
		if choiceProp.idImgBcgrSelected then 
			choiceProp.idImgBcgrSelected:SetVisible(false)
		end
		choiceProp.isExpanded = false
	end
	dialog:SetMode("empty")
	GetDialog(ui):ResolveId("idSubMenu"):ResolveId("idScrollArea"):SetMouseScroll(true)
end

function GetCampaignNameTranslated()
	local campaign = DefaultCampaign or "HotDiamonds"											
	local dName = CampaignPresets[campaign] and CampaignPresets[campaign].DisplayName
	local campaignName = _InternalTranslate(dName)
	return campaignName
end

local function RecreateTags()
const.TagLookupTable["ButtonASmall"]   = GetPlatformSpecificImageTag("ButtonA", 650) 
const.TagLookupTable["ButtonBSmall"]   = GetPlatformSpecificImageTag("ButtonB", 650) 
const.TagLookupTable["ButtonYSmall"]   = GetPlatformSpecificImageTag("ButtonY", 650) 
const.TagLookupTable["ButtonXSmall"]   = GetPlatformSpecificImageTag("ButtonX", 650)

const.TagLookupTable["ButtonAHold"]   = T{944700099636, "<img>(Hold)",img = GetPlatformSpecificImageTag("ButtonA") }
const.TagLookupTable["ButtonASmallHold"]   = T{944700099636, "<img>(Hold)",img = GetPlatformSpecificImageTag("ButtonA", 650) }
end

function OnMsg.OnControllerTypeChanged()
	RecreateTags()
end

OnMsg.XInputInitialized = RecreateTags

RecreateTags()

-- Requirements are for these to be the same size as other gamepad buttons. (219357)
local smallerButtons = {
	["rsup"] = true,
	["rsdown"] = true,
	["rsright"] = true,
	["rsleft"] = true,
	
	["lsup"] = true,
	["lsdown"] = true,
	["lsright"] = true,
	["lsleft"] = true,
}


local commonGetPlatformSpecificImageTag = GetPlatformSpecificImageTag
function GetPlatformSpecificImageTag(btn, scale)
	if smallerButtons[btn] and not scale then
		scale = 516
	end

	return commonGetPlatformSpecificImageTag(btn, scale)
end
RecreateButtonsTagLookupTable()

function DbgFindFreePassPositions(pos, count, max_radius, seed)
	local result = {}
	local x0, y0, z0 = VoxelToWorld(WorldToVoxel(pos))
	local result = {}

	for i = 1 + (sqrt(count) - 1) / 2, max_radius do
		local r = i * const.SlabSizeX
		ForEachPassSlab(box(x0 - r, y0 - r, 0, x0 + r + 1, y0 + r + 1, 100000), function(x, y, z, result)
			local p = point_pack(x, y, z)
			if not result[p] and CanDestlock(point(x,y,z), 1) then
				table.insert(result, p)
				result[p] = true
			end
		end, result)
		if #result >= count then
			local list = {}
			for i = 1, count do
				local idx
				idx, seed = BraidRandom(seed, #result)
				idx = idx + 1
				list[i] = point(point_unpack(result[idx]))
				result[idx] = result[#result]
				result[#result] = nil
			end
			return list
		end
	end
end

local dbgStartExplorationSpamGuard = false
function DbgStartExploration(map, units)
	DbgStopCombat()
	if map and map ~= GetMapName() then
		CreateRealTimeThread(function(map, units)
			ChangeMap(map)
			DbgStartExploration(map, units)
		end, map, units)
		return
	end
	
	if not mapdata.GameLogic then
		print("This map doesn't have game logic enabled, therefore you cannot test on it.")
		return
	end
	
	if dbgStartExplorationSpamGuard and RealTime() - dbgStartExplorationSpamGuard < 50 then
		return
	end
	
	dbgStartExplorationSpamGuard = RealTime()

	-- link debug exploration to satellite sector
	if not HasGameSession() then
		NewGameSession(nil, {KeepUnitData = true})
	end
	local dbg_sector = "A1"
	gv_Sectors[dbg_sector].Map = map or GetMapName()
	gv_CurrentSectorId = dbg_sector
	g_TestExploration = true
		
	local party = units or { "Ivan", "Vicki", "Buns" }
	local p = GetTerrainCursorXY(UIL.GetScreenSize()/2)
	local pts = DbgFindFreePassPositions(p, #party, 20, xxhash(p))
	if not pts then
		print("Can't find passable point.")
		return
	end
	SetupTeamsFromMap()
	local player1_team = table.find_value(g_Teams, "side", "player1")
	for i, class in ipairs(party) do
		gv_UnitData[class] = CreateUnitData(class, class, 0)
		local unit = g_Units[class] or SpawnUnit(class, class, pts[i])
		SendUnitToTeam(unit, player1_team)
	end

	CreateNewSatelliteSquad({Side = "player1", CurrentSector = dbg_sector, Name = "GAMETEST"},party, 14, 1234567)

	if not g_Exploration then StartExploration() end
	if not g_AmbientLifeSpawn then
		AmbientLifeToggle()
	end
	gv_InitialHiringDone = true
	Msg("DbgStartExploration")
end

function OnMsg.CanSaveGameQuery(query)
	query.test_exploration = g_TestExploration or nil
end

function MakeUnitNonVillain(boss)
	local bossUnit = not gv_SatelliteView and g_Units[boss.session_id]
	if bossUnit then
		bossUnit.villain = false
		bossUnit.villain_defeated = false
		bossUnit.immortal = false
		bossUnit.DefeatBehavior = false
		bossUnit.invulnerable = false
		
		if bossUnit.command == "VillainDefeat" then
			bossUnit:SetCommand("Idle")
		end
	end
	
	local bossUD = gv_UnitData[boss.session_id]
	if bossUD then
		bossUD.villain = false
		bossUD.villain_defeated = false
		bossUD.immortal = false
		bossUD.DefeatBehavior = false
	end
	
	-- ughhh just in case
	if boss ~= bossUD and boss ~= bossUnit then
		boss.villain = false
		boss.villain_defeated = false
		boss.immortal = false
		boss.DefeatBehavior = false
	end
end

function GetParentOfKindPopupAware(win, class)
	while win and not IsKindOf(win, class) do
		if win.popup_parent then
			win = win.popup_parent
		else
			win = win.parent
		end
	end
	return win
end

-- Disable button pressing using Enter.
-- It's weird and prevents the dev console from opening.
local old = XButton.OnShortcut
function XButton:OnShortcut(shortcut, source, ...)
	if shortcut == "Enter" then
		if not Platform.developer or not GetParentOfKindPopupAware(self, "DeveloperInterface") then
			return
		end
	end
	return old(self, shortcut, source, ...)
end

DefineClass.XContextWindowVisibleReasons = {
	__parents = { "XContextWindow" },
	
	visible_reasons = false
}

function XContextWindowVisibleReasons:Init()
	self.visible_reasons = {
		["logic"] = true
	}
end

function XContextWindowVisibleReasons:SetVisible(visible, reason, instant)
	reason = reason or "logic"
	if self.visible_reasons[reason] == visible then return end
	
	self.visible_reasons[reason] = visible
	local show = true
	for reason, v in pairs(self.visible_reasons) do
		if not v then
			show = false
			break
		end
	end
	
	if show == self.visible then return end
	return XContextWindow.SetVisible(self, visible, instant)
end

table.insert(XFitContent.properties, { id = "UseMeasureCache", editor = "bool", default = true })

-- Optimized version of XFitContent's UpdateMeasure that uses
-- a cache to reduce remeasures
local one = point(1000, 1000)
function XFitContent:UpdateMeasure(max_width, max_height)
	if not self.measure_update then return end
	local fit = self.Fit
	if fit == "none"  then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	
	if self.cached_data and self.UseMeasureCache then
		-- Check if the cache is still valid
		local cached_data = self.cached_data
		local chMW = cached_data[1]
		local chMH = cached_data[2]
		local chFit = cached_data[3]
		if chMW == max_width and chMH == max_height and chFit == fit then
			local scaleX = cached_data[4]
			local scaleY = cached_data[5]
		
			self:SetScaleModifier(point(scaleX, scaleX))
			XControl.UpdateMeasure(self, max_width, max_height)
			return
		end
	end
	
	for _, child in ipairs(self) do
		child:SetOutsideScale(one)
	end
	self.scale = one
	XControl.UpdateMeasure(self, 1000000, 1000000)
	local content_width, content_height = ScaleXY(self.parent.scale, self.measure_width, self.measure_height)
	assert(content_width > 0 and content_height > 0)
	if content_width == 0 or content_height == 0 then
		XControl.UpdateMeasure(self, max_width, max_height)
		return
	end
	if fit == "smallest" or fit == "largest" then
		local space_is_wider = max_width * content_height >= max_height * content_width
		fit = space_is_wider == (fit == "largest") and "width" or "height"
	end
	local scale_x = max_width * 1000 / content_width
	local scale_y = max_height * 1000 / content_height
	if fit == "width" then
		scale_y = scale_x
	elseif fit == "height" then
		scale_x = scale_y
	end
	self:SetScaleModifier(point(scale_x, scale_y))
	XControl.UpdateMeasure(self, max_width, max_height)
	
	self.cached_data = {
		max_width,
		max_height,
		self.Fit,
		scale_x,
		scale_y
	}
end

function SetTestGamepadUIPlatform(platform)
	ChangeGamepadUIStyle({ false })
	g_PCActiveControllerType = false
	g_TestUIPlatform = platform
	RecreateButtonsTagLookupTable()
	UpdateActiveControllerType()
	ChangeGamepadUIStyle({ true })
end

DefineClass.XTextButtonZulu = {
	__parents = { "XTextButton" }
}

function XTextButtonZulu:SetSelected(selected)
	if selected then
		self:SetFocus(true)
	end

	if not selected and self.state == "pressed-out" then
		self:OnButtonUp(false, true)
	end
end

function XTextButtonZulu:IsSelectable()
	return self:GetEnabled()
end

function XTextButtonZulu:OnSetRollover(rollover)
	XTextButton.OnSetRollover(self, rollover)
	if not rollover and self.state == "pressed-out" then
		self:OnButtonUp(false, true)
	end
end

function GetInvertPDAThumbsShortcut(shortcut)
	local shrct = shortcut
	if GetAccountStorageOptionValue("InvertPDAThumbs") then
		local leftIdx = table.find(XInput.LeftThumbDirectionButtons, shrct)
		local rightIdx = table.find(XInput.RightThumbDirectionButtons, shrct)
		if leftIdx then
			shrct = XInput.RightThumbDirectionButtons[leftIdx]
		elseif rightIdx then
			shrct = XInput.LeftThumbDirectionButtons[rightIdx]
		end
	end
	return shrct
end	

local commonActionHostOnShortcut = XActionsHost.OnShortcut
function XActionsHost:OnShortcut(shortcut, source, ...)	
	if shortcut == "+TouchPadClick" then shortcut = "+Back"
	elseif shortcut == "TouchPadClick" then shortcut = "Back"
	elseif shortcut == "-TouchPadClick" then shortcut = "-Back" end

	shortcut = GetInvertPDAThumbsShortcut(shortcut)
	
	return commonActionHostOnShortcut(self, shortcut, source, ...)
end

local commonIsCtrlButtonPressed = XInput.IsCtrlButtonPressed
function XInput.IsCtrlButtonPressed(id, shortcut, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if shortcut == "LeftTrigger" then
			shortcut = "RightTrigger"
		elseif shortcut == "RightTrigger" then
			shortcut = "LeftTrigger"
		end
	end
	return commonIsCtrlButtonPressed(id, shortcut, ...)
end

local commonXInputShortcut = XInputShortcut
function XInputShortcut(button, controller_id)
	if not GetAccountStorageOptionValue("GamepadSwapTriggers") then
		return commonXInputShortcut(button, controller_id)
	end
	
	if button == "LeftTrigger" then
		button = "RightTrigger"
	elseif button == "RightTrigger" then
		button = "LeftTrigger"
	end
	return commonXInputShortcut(button, controller_id)
end

local commonGetPlatformSpecificImageName = GetPlatformSpecificImageName
function GetPlatformSpecificImageName(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImageName(button, ...)
end

local commonGetPlatformSpecificImagePath = GetPlatformSpecificImagePath
function GetPlatformSpecificImagePath(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImagePath(button, ...)
end

local commonGetPlatformSpecificImageTag = GetPlatformSpecificImageTag
function GetPlatformSpecificImageTag(button, ...)
	if GetAccountStorageOptionValue("GamepadSwapTriggers") then
		if button == "LeftTrigger" then
			button = "RightTrigger"
		elseif button == "RightTrigger" then
			button = "LeftTrigger"
		end
	end
	return commonGetPlatformSpecificImageTag(button, ...)
end

if FirstLoad then
CheckForConflictingBinding_Checked = false
end

function OnMsg.AccountStorageLoaded()
	CheckForConflictingBinding_Checked = false
end

function OnMsg.ShortcutsReloaded()
	if not CheckForConflictingBinding_Checked then
		CheckForConflictingBinding()
		CheckForConflictingBinding_Checked = true
	end
end

function CheckForConflictingBinding()
	if not Platform.desktop then return end

	local optionsObj = OptionsObj or OptionsCreateAndLoad()
	local optionEntries = optionsObj:GetProperties()
	local bindings = table.ifilter(optionEntries, function(_, o) return o.category == "Keybindings" end)

	local conflicts = {}
	for _, binding1 in ipairs(bindings) do
		local shortcutsFor1 = optionsObj[binding1.id] or empty_table
	
		for _, binding2 in ipairs(bindings) do
			if binding1 == binding2 then goto continue end
			if binding1.id == binding2.id then goto continue end
			
			-- Check if using the same shortcut.
			local shortcutsFor2 = optionsObj[binding2.id] or empty_table
			local conflictingShortcut = false
			for _, sh1 in ipairs(shortcutsFor1) do
				for _, sh2 in ipairs(shortcutsFor2) do
					conflictingShortcut = sh1 == sh2
					if conflictingShortcut then break end
				end
			end
				
			if not conflictingShortcut then goto continue end
			if not EnabledInModes(binding1.mode, binding2.mode) then goto continue end
			
			-- Collect conflicting bindings.
			-- (there are actions with duplicate ids sp we use ids)
			local binding1Id = binding1.id
			local binding2Id = binding2.id
			
			local existInReverse = conflicts[binding2Id]
			if existInReverse and table.find(existInReverse, binding1Id) then goto continue end
			
			local conflictListForMe = conflicts[binding1Id] or {}
			conflicts[binding1Id] = conflictListForMe
			if table.find(conflictListForMe, binding2Id) then goto continue end
			conflictListForMe[#conflictListForMe + 1] = binding2Id
			
			::continue::
		end
	end
	
	local unboundShortcuts = {}
	for con, conList in pairs(conflicts) do
		local data1 = table.ifilter(bindings, function(_, o) return o.id == con end)
		local defs1 = {}
		for i, d in ipairs(data1) do
			table.iappend(defs1, d.default)
		end
		local shortcutsFor1 = optionsObj[con] or empty_table
	
		for i, con2 in ipairs(conList) do
			-- Find which one of the two is the default binding (if any)
			local data2 = table.ifilter(bindings, function(_, o) return o.id == con2 end)
			local defs2 = {}
			for i, d in ipairs(data2) do
				table.iappend(defs2, d.default)
			end
			local shortcutsFor2 = optionsObj[con2] or empty_table
			
			local defaultIs1, defaultIs2 = false, false
			for _, sh1 in ipairs(shortcutsFor1) do
				for _, sh2 in ipairs(shortcutsFor2) do
					if sh1 == sh2 then
						defaultIs1 = not not table.find(defs1, sh1)
						defaultIs2 = not not table.find(defs2, sh2)
						break
					end
				end
			end
			
			if (defaultIs1 and not defaultIs2) or (defaultIs2 and not defaultIs1) then
				if defaultIs1 then
					unboundShortcuts[#unboundShortcuts + 1] = con
					optionsObj:SetProperty(con, {""})
				else
					unboundShortcuts[#unboundShortcuts + 1] = con2
					optionsObj:SetProperty(con2, {""})
				end
			end
		end
	end
	
	local unboundActionsDisplayNames = {}
	for i, sh in ipairs(unboundShortcuts) do
		local binding = table.find_value(bindings, "id", sh)
		unboundActionsDisplayNames[#unboundActionsDisplayNames + 1] = binding.name
	end
	
	if #unboundActionsDisplayNames > 0 then
		optionsObj:SaveToTables()
		ReloadShortcuts()
	
		local popupText = T{515533608396, "A game update has added new key bindings that conflict with your personalized bindings. The new key bindings have been removed.<newline>To assign buttons to these new actions go to the Keybindings section in the Options menu and look for the following: <newline><newline><actions>",
			actions = table.concat(unboundActionsDisplayNames, ", ")
		}
		CreateMessageBox(terminal.desktop, T(498221418682, "Information"), popupText)
	end
end

if FirstLoad then
ui_TimeSinceTurnStarted = false
ui_SuppressNextEndTurnAnimation = false
ui_EndTurnAnimationDuration = 500

ui_FastForwardButtonAnimationStarted = false
ui_FastForwardButtonShown = false
ui_FastForwardButtonSlideDownAfter = 3000
end

function OnMsg.TurnStart(team)
	if ui_SuppressNextEndTurnAnimation then
		ui_SuppressNextEndTurnAnimation = false
		return
	end

	local teamData = g_Teams[team]
	if teamData and teamData.player_team then
		ui_TimeSinceTurnStarted = GetPreciseTicks()
		ui_FastForwardButtonAnimationStarted = false
	elseif not ui_FastForwardButtonAnimationStarted then -- Reset animation on player turn only.
		ui_FastForwardButtonAnimationStarted = GetPreciseTicks()
	end
	ObjModified("EndTurnAnimation")
end

function OnMsg.RepositionEnd()
	ui_TimeSinceTurnStarted = GetPreciseTicks()
	ObjModified("EndTurnAnimation")
	ui_SuppressNextEndTurnAnimation = true
end

function HasEndTurnAnimationPassed() -- pepega
	if not ui_TimeSinceTurnStarted then return true end
	--if ui_FastForwardButtonAnimationStarted then return false end
	if GetPreciseTicks() - ui_TimeSinceTurnStarted > ui_EndTurnAnimationDuration then return true end
	return false
end

function ShowInGameMenuBlurRect()
	if GetDialog("PDADialog") then return false end
	if GetDialog("PDADialogSatellite") then return false end
	if GetDialog("ConversationDialog") then return false end
	if GetDialog("FullscreenGameDialogs") then return false end
	return true
end

function EndTurnAnimationOnLayoutComplete(interp, window)
	local dlg = GetDialog(window)
	local bottom = dlg.box:maxy()
	local distanceToBottomFromMe = bottom - window.box:miny()
	
	interp.targetRect = sizebox(0, distanceToBottomFromMe, 1000, 1000)
end

function Conscience_CheckExpiration(effect, target, timer)
	local duration = effect:ResolveValue("days")
	local startTime = effect:ResolveValue(timer) or 0

	local dayStarted = GetTimeAsTable(startTime)
	dayStarted = dayStarted and dayStarted.day

	local dayNow = GetTimeAsTable(Game.CampaignTime)
	dayNow = dayNow and dayNow.day

	-- Intentionally check if days have passed calendar, and not time wise.
	if dayNow - dayStarted >= duration then
		target:RemoveStatusEffect(effect.class)
	end
end

function ApplyCthModifier_Add(effect, data, value, text, meta_text)
	data.mod_add = data.mod_add + value
	if data.modifiers then
		data.modifiers[#data.modifiers + 1] = {
			id = effect.class, 
			value = value,
			name = text or effect.DisplayName, 
			metaText = meta_text,
		}
	end
end

function ConstCategoryToCombo(constList)
	local res = {}
	for k,v in pairs(constList) do
		res[#res+1] = { k, v }
	end
	table.sortby_field(res, 2)
	return table.map(res, 1)
end