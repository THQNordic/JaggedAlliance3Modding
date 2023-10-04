SectorOperationResoucesBase = {
	{
		id = "Money", name = T(517301472548, "Money"),
		icon = "UI/SectorOperations/T_Icon_Money",
		context = function(sector) return Game end,
		current = function(sector) return Game.Money end,
		-- no <money()> formatting on purpose here, a bitmap $ will be added in the UI
		current_txt = function(sector) return T{831649021785, "<money>", money = FormatNumber(Game.Money)} end,
		pay = function(sectorId, cost) AddMoney(-cost, "operation") end,
		restore = function(merc, cost) AddMoney(cost, "operation") end,
	},
}

if FirstLoad then
SectorOperationResouces = false
end

local function lAddInventoryItemAsSectorResource(name, icon, noCheat, bAdditional)
	local item = InventoryItemDefs[name]
	SectorOperationResouces[#SectorOperationResouces + 1] = {
		id = name, name = item.DisplayName,
		icon = icon or ("UI/SectorOperations/T_Icon_" .. name),
		additional = bAdditional,
		context = function(sector) return sector end,
		current = function(sector)
			if type(sector) == "string" then
				sector = gv_Sectors[sector]
			end

			return GetSectorOperationResource(sector, name)
		end,
		pay = function(sectorId, cost) 
			if not noCheat and CheatEnabled("FreeParts") then 
				cost = 0
			end
			PaySectorOperationResource(sectorId, name, cost) 
		end,
		restore = function(merc, cost) 
			if not noCheat and CheatEnabled("FreeParts") then 
				cost = 0
			end
			RestoreSectorOperationResource(merc, name, cost) 
		end,
	}
end

function OnMsg.ClassesBuilt()
	CreateRealTimeThread(function()
		WaitDataLoaded()
		SectorOperationResouces = table.copy(SectorOperationResoucesBase)
		lAddInventoryItemAsSectorResource("Meds", "UI/SectorOperations/T_Icon_Medicine", false)
		lAddInventoryItemAsSectorResource("Parts")
		lAddInventoryItemAsSectorResource("FineSteelPipe", "UI/Icons/Upgrades/parts_placeholder", false, "additional")
		lAddInventoryItemAsSectorResource("Microchip", "UI/Icons/Upgrades/parts_placeholder", false, "additional")
		lAddInventoryItemAsSectorResource("OpticalLens", "UI/Icons/Upgrades/parts_placeholder", false, "additional")
		for i, resourceData in ipairs(SectorOperationResouces) do
			SectorOperationResouces[resourceData.id] = resourceData
		end
	end)
end

---
function GetCurrentResourcesContext(operation, sector)
	local items = {}
	local resources = operation and operation.RequiredResources
	if operation and IsCraftOperation(operation.id)then
		table.insert_unique(resources,"Parts")
	end
	if resources then
		for _, res in ipairs(resources or empty_table) do
			local ts = SectorOperationResouces[res]
			if ts then
				items[#items + 1] = {resource = res, value = (ts.current_txt or ts.current)(sector), icon = ts.icon, context = ts.context(sector)}
			end
		end
	else
		for _, res in ipairs(SectorOperationResouces or empty_table) do
			if not res.additional then
				items[#items + 1] = {resource = res.id, value = (res.current_txt or res.current)(sector), icon = res.icon, context = res.context(sector)}
			end
		 end
	end	 
	return items
end
--todo: batch events
--InterruptSectorOperation + RestoreOperationCost
--can't MercRemoveOperationTreatWounds be the same func as MercSetOperation?
--most events are per merc, and are sent for each merc, rather then iterate themselves


function OperationsSync_ResumeObjModified()
	ResumeObjModified("OperationsSync")
end

local thread = false
function OperationsSync_SuspendObjModified()
	if IsValidThread(thread) then return end
	SuspendObjModified("OperationsSync")
	thread = CreateRealTimeThread(function()
		while #(SyncEventsQueue or "") > 0 do
			WaitNextFrame()
		end
		thread = false
		OperationsSync_ResumeObjModified()
	end)
end

function NetSyncEvents.LogOperationStart(operation_id, sector_id, voicelog)
	OperationsSync_SuspendObjModified()
	if operation_id == "Traveling" or operation_id == "Idle" or operation_id== "Arriving" then
		return
	end	
	local operation = SectorOperations[operation_id]
	local sector = gv_Sectors[sector_id]
	if #operation.Professions >= 2 then
		if operation_id == "TrainMercs" then
			local m_students = GetOperationProfessionals(sector_id, operation_id,"Student") 
			local m_teachers = GetOperationProfessionals(sector_id, operation_id,"Teacher")
			if #m_students >=1 and #m_teachers>=1 then
				local trainers = table.map(m_teachers, "Nick")				
				local students = table.map(m_students, "Nick")
				if voicelog then PlayVoiceResponse(table.rand(m_teachers),"ActivityStarted") end
				CombatLog("short",T{559221136920, "<em><trainers></em> started training <em><students></em> in <SectorName(sector)>",trainers = ConcatListWithAnd(trainers), students = ConcatListWithAnd(students), sector = sector})
			end	
		elseif operation_id == "TreatWounds" then
			local m_patients = GetOperationProfessionals(sector_id, operation_id,"Patient")
			local m_doctors = GetOperationProfessionals(sector_id, operation_id,"Doctor")
			if #m_doctors>=1 and #m_patients>=1 then
				local doctors  = table.map(m_doctors,  "Nick")
				local patients = table.map(m_patients, "Nick")
				if voicelog then PlayVoiceResponse(table.rand(m_doctors),"ActivityStarted") end
				CombatLog("short",T{306176602916, "<em><doctors></em> started treating the wounds of <em><patients></em> in <SectorName(sector)>",doctors = ConcatListWithAnd(doctors), patients = ConcatListWithAnd(patients), sector = sector})
			end
		end
	else
		local operationMercs = GetOperationProfessionals(sector_id, operation_id)
		local merc_names = table.map(operationMercs, function(o) return o.Nick end)
		local msg = operation.log_msg_start and operation.log_msg_start ~= "" and T{operation.log_msg_start, sector = sector, display_name = operation.display_name, mercs = ConcatListWithAnd(merc_names)} 
			or T{807960240333, "<em><mercs></em> started <em><display_name></em> in <SectorName(sector)>",mercs = ConcatListWithAnd(merc_names), display_name = operation.display_name, sector = sector}
		CombatLog("short", msg)
		local negotiatorUnits = {}
		for _, merc in ipairs(operationMercs) do
			if HasPerk(merc, "Negotiator") and InteractionRand(100, "NegotiatorVR") < 50 then
				table.insert(negotiatorUnits, merc)
			end
		end
		if voicelog then
			if next(negotiatorUnits) then
				PlayVoiceResponse(table.rand(negotiatorUnits, InteractionRand(1000000, "RandomNegotiator")), "Negotiator")
			elseif next(operationMercs) then
				PlayVoiceResponse(table.rand(operationMercs, InteractionRand(1000000, "RandomActivityStartedMerc")), "ActivityStarted")
			end
		end	
	end
end

function NetSyncEvents.SetTrainingStat(sector_id, stat)
	OperationsSync_SuspendObjModified()
	local sector = gv_Sectors[sector_id]
	sector.training_stat = stat
	ObjModified(sector)
end

function NetSyncEvents.StartOperation(sector_id, operation_id, start_time, training_stat)
	OperationsSync_SuspendObjModified()
	local sector = gv_Sectors[sector_id]
	sector.started_operations = sector.started_operations or {}
	sector.started_operations[operation_id] = start_time
	if operation_id=="TrainMercs" then
		sector.training_stat = training_stat
	end
	if sector.operations_temp_data and  sector.operations_temp_data[operation_id] and sector.operations_temp_data[operation_id].pick_item then
		sector.operations_temp_data[operation_id].pick_item = false	
	end
	local mercs = GetOperationProfessionals(sector_id, operation_id)
	for _, m in ipairs(mercs) do
		Msg("OperationTimeUpdated", m, operation_id)
	end	
	RemoveTimelineEvent("activity-temp")
	
	-- This message will no longer be needed one merc set operation is made
	-- to fire only once the operation starts.
	Msg("TempOperationStarted", operation_id)
	ObjModified(sector)
end

function NetSyncEvents.RestoreOperationCostAndSetOperation(unit_id, refund_amound, operation_id, prof_id, cost, slot, check, all_profs, partial_wounds)
	--batch of the two other evs
	OperationsSync_SuspendObjModified()
	NetSyncEvents.RestoreOperationCost(unit_id, refund_amound)
	local prev = gv_UnitData[unit_id]
	local prev_op = prev.Operation
	SectorOperations[prev_op]:OnMove(prev, true)
	NetSyncEvents.MercSetOperation(unit_id, operation_id, prof_id, cost, slot, check,  partial_wounds)
end

function NetSyncEvents.RestoreOperationCost(unit_id, cost)
	OperationsSync_SuspendObjModified()
	local merc = gv_UnitData[unit_id]
	if merc then
		for _, c in ipairs(cost or empty_table) do
			local value = c.value
			if CheatEnabled("FreeParts") and c.resource== "Parts" then 
				value = 0
			end
			local res_t = SectorOperationResouces[c.resource]
			res_t.restore(merc, c.value)
		end
	end
end

function NetSyncEvents.MercSyncOperationsData(unit_id, tiredness, rest_time, travel_time, travel_timer_start)
	OperationsSync_SuspendObjModified()
	local merc = gv_UnitData[unit_id]
	if merc then
		local sector = merc:GetSector()
		merc:SetTired(tiredness)
		merc.RestTimer = rest_time
		merc.TravelTime = travel_time
		merc.TravelTimerStart = travel_timer_start
		ObjModified(gv_Squads)
		ObjModified(sector)
	end
end

function NetSyncEvents.MercSetOperationIdle(unit_id,tiredness, rest_time, travel_time, travel_timer_start)
	OperationsSync_SuspendObjModified()
	local merc = gv_UnitData[unit_id]
	if merc then
		local sector = merc:GetSector()
		merc:SetCurrentOperation("Idle")
		merc:SetTired(tiredness)
		merc.RestTimer = rest_time
		merc.TravelTime = travel_time
		merc.TravelTimerStart = travel_timer_start
		ObjModified(gv_Squads)
		ObjModified(sector)
	end
end

function NetSyncEvents.MercSetOperation(unit_id, operation_id, prof_id, cost, slot, check, partial_wounds)
	OperationsSync_SuspendObjModified()
	local merc = gv_UnitData[unit_id]
	if merc then
		local sector = merc:GetSector()
		PayOperation(cost, merc:GetSector())
		local prev = SectorOperations[merc.Operation]
		merc:SetCurrentOperation(operation_id, slot, prof_id, partial_wounds)
		if check then
			prev:CheckCompleted(merc, sector)
			local mercs = GetOperationProfessionals(sector.Id, prev.id)
			if not next(merc) or #mercs<=0 then
				if sector.started_operations then
					sector.started_operations[prev.id] = false
				end				
			end	
		end
		
		ObjModified(gv_Squads)
		ObjModified(sector)
	end
end

function NetSyncEvents.MercRemoveOperationTreatWounds(unit_id, prof_id)
	local merc = gv_UnitData[unit_id]
	if not merc then return end
	OperationsSync_SuspendObjModified()
	local sector = merc:GetSector()
	
	if IsPatient(merc) and IsDoctor(merc) then
		if prof_id=="Doctor" then
			merc:SetCurrentOperation("Idle")	
		elseif prof_id=="Patient" then
			local count = SectorOperationCountPatients(sector.Id, unit_id)
			if count>0 then
				merc:RemoveOperationProfession("Patient")
				merc.OperationProfession = "Doctor"	
				merc:SetCurrentOperation(merc.Operation)
			else	
				merc:SetCurrentOperation("Idle")	
			end
		end
	else
		merc:SetCurrentOperation("Idle")
	end
	
	ObjModified(gv_Squads)
	ObjModified(sector)
end

function NetSyncEvents.InterruptSectorOperation(sector_id, operation, reason)
	OperationsSync_SuspendObjModified()
	local mercs = GetOperationProfessionals(sector_id, operation)
	for _, merc in ipairs(mercs) do
		local event_id =  GetOperationEventId(merc, operation)
		RemoveTimelineEvent(event_id)
		merc:SetCurrentOperation("Idle",false, false, false, reason or "interrupted")
	end
	local sector = gv_Sectors[sector_id]
	if sector.started_operations then
		sector.started_operations[operation] = false
	end

	ObjModified(sector)
end

function NetSyncEvents.ChangeSectorOperation(sector_id, operation)
	OperationsSync_SuspendObjModified()
	local mercs = GetOperationProfessionals(sector_id, operation)
	for _, merc in ipairs(mercs) do
		local event_id =  GetOperationEventId(merc, operation)
		RemoveTimelineEvent(event_id)
	end
	local sector = gv_Sectors[sector_id]
	if sector.started_operations then
		sector.started_operations[operation] = false
	end

	ObjModified(sector)
end
-- reset operation and cancel prev operation
function SectorOperation_CancelByGame(units,operation_id, already_synced)
	local to_cancel_units = {}
	for _, unit_id in ipairs(units) do
		local unit_data = type(unit_id)== "string" and gv_UnitData[unit_id] or unit_id
		if not IsMerc(unit_data) then
			return -- enemy squad is moving
		end	
		local prev_operation = unit_data.Operation
		if prev_operation~="Idle" and (not operation_id or prev_operation==operation_id) then		
			to_cancel_units[prev_operation] = to_cancel_units[prev_operation] or {}
			table.insert(to_cancel_units[prev_operation], gv_UnitData[unit_data.session_id])
		end
	end
	for operation_id, tbl in sorted_pairs(to_cancel_units) do
		local costs = GetOperationCostsProcessed(tbl, operation_id, false, "both", "refund")
		for i, unit_data in ipairs(tbl) do
			local unit_id = unit_data.session_id
			NetSyncEvent("RestoreOperationCost", unit_id, costs[i])

			local satview_unit = gv_UnitData[unit_id]
			local on_map_unit = g_Units[unit_id] 
			local map_change = not gv_SatelliteView and on_map_unit
			if map_change then	
				on_map_unit:SyncWithSession("map")
			end	
			satview_unit:SetCurrentOperation("Idle")
			SectorOperations[operation_id]:OnMove(satview_unit, already_synced)
			if map_change then	
				on_map_unit:SyncWithSession("session")
			end
		end
	end
	RepairItems_RemoveRepairedItems(units, already_synced)
end

function OnMsg.UnitDied(unit)
	if not IsMerc(unit) or unit.Operation=="Idle" then return end
	SectorOperation_CancelByGame({unit},unit.Operation, true)
end

function NetSyncEvents.ChangeSectorOperationItemsOrder(sector_id, operation_id, sector_items, sector_items_queued )
	if not IsCraftOperation(operation_id) then return end
	
	OperationsSync_SuspendObjModified()
	local sector = gv_Sectors[sector_id]
	local quid, allid = GetCraftOperationListsIds(operation_id)
	
	if allid then 
		sector[allid] = TableWithItemsFromNet(sector_items)
		ObjModified(sector[allid])
	end
	local tbl = SetCraftOperationQueueTable(sector, operation_id, TableWithItemsFromNet(sector_items_queued))
	ObjModified(sector)
	ObjModified(tbl)
end

function SectorOperation_CalcCraftResources(sector_id, operation_id)
	local sector =  gv_Sectors[sector_id]
	local craft_table = GetCraftOperationQueueTable(sector, operation_id) or {}
	-- calc queued/all resources
	local res_items = {}
	for _, q_data in pairs(craft_table) do
		local recipe = CraftOperationsRecipes[q_data.recipe]
		for _, ingrd in ipairs(recipe.Ingredients) do
			res_items[ingrd.item] = (res_items[ingrd.item] or 0)+ ingrd.amount
		end
	end
	return res_items
end

function SectorOperation_ValidateRecipeIngredientsAmount(mercs, recipe, res_items, checked_amount_cach)
	checked_amount_cach = checked_amount_cach or {}
	local res = true
	for __, ingrd in ipairs(recipe.Ingredients) do
		local amount = ingrd.amount + (res_items[ingrd.item] or 0)
		local result
		local checked = checked_amount_cach[ingrd.item]			
		if checked and checked>=amount then
			result = true
		else	
			local max 
			result, max = HasItemInSquad(mercs[1],ingrd.item, amount)			
			if result then
				checked_amount_cach[ingrd.item] = max
			end
		end
		res = res and result
	end
	return res
end

function SectorOperationValidateItemsToCraft(sector_id, operation_id, merc )	
	if not IsCraftOperationId(operation_id) then
		return
	end	
	local merc =  merc or GetOperationProfessionals(sector_id, operation_id)[1]
	if not merc then 
		return 
	end
	local mercs = gv_Squads[merc.Squad].units

	-- calc queued resources
	local res_items = SectorOperation_CalcCraftResources(sector_id, operation_id)
	
	local id =  "g_Recipes"..operation_id
	if not rawget(_G,id) then
		SectorOperationFillItemsToCraft(sector_id, operation_id, merc)
		return
	end
	
	local all_to_craft = _G[id] or {}
	local checked_amount_cach = {}-- item, amount that is checked sucsessfully, 
	for _, craft_data in pairs(all_to_craft) do
		local recipe = CraftOperationsRecipes[craft_data.recipe]
		if recipe.RequiredCrafter and merc.session_id~=recipe.RequiredCrafter then
			craft_data.hidden = true
		end
		local condition = not recipe.QuestConditions or EvalConditionList(recipe.QuestConditions)
		craft_data.hidden = craft_data.hidden or not condition
		
		local res = SectorOperation_ValidateRecipeIngredientsAmount(mercs, recipe,res_items, checked_amount_cach) 

		craft_data.enabled = not not res
	end
		
	table.sort(all_to_craft, function(a,b) 
		if not a or not b then return true end
		if a.enabled and not b.enabled then
			return true
		elseif not a.enabled and b.enabled then
			return false
		elseif a.item_id<b.item_id then return 
			true
		end
		return false	
	end)
end

function SectorOperations_CraftAdditionalResources(sector_id,operation_id)
	local res_table = {}
	for recipe_id, recipe in pairs(CraftOperationsRecipes) do
		if recipe.CraftOperationId==operation_id or recipe.group=="Ammo" and operation_id=="CraftAmmo" or recipe.group=="Explosives" and operation_id=="CraftExplosives" then
			for _, ingr in ipairs(recipe.Ingredients) do
				res_table[ingr.item] = (res_table[ingr.item] or 0) + ingr.amount
			end
		end
	end
	
	local needed_res_table = SectorOperation_CalcCraftResources(sector_id,operation_id)
	local merc
	local mercs = GetOperationProfessionals(sector_id,operation_id)
	
	if next(mercs) then
		merc = mercs[1].session_id
	else
		mercs = GetPlayerMercsInSector(sector_id)
		merc = mercs[1]
	end	
	local array = {}
	for res, val in pairs(res_table) do
		if res~="Money" and res~="Parts" then
			local result, amount_found = HasItemInSquad(merc, res, "all")
			if amount_found and amount_found>0 then
				array[#array + 1] = {res = res, value = val, queued_val = needed_res_table[res], amount_found = amount_found or 0}
			end	
		end
	end
	table.sortby(array, "res")
	return array
end

function SectorOperation_CraftItemTime(sector_id, operation_id, recipe)
	local sector = gv_Sectors[sector_id]
	local related_stat = SectorOperations[operation_id].related_stat
	local mercs = GetOperationProfessionals(sector_id,operation_id)
	if not mercs then 
		return 0
	end	
	local stat = mercs[1][related_stat]
	if IsCraftOperation(operation_id) then
		local time = CraftOperationsRecipes[recipe].CraftTime 
		return 3*time*1000/2 - stat*time*1000/100
	end
	return 0
end

function SectorOperation_CraftTotalTime(sector_id, operation_id)
	local sector = gv_Sectors[sector_id]
	local s_queued = SectorOperationItems_GetTables(sector_id, operation_id)
	local total_time = 0
	local related_stat = SectorOperations[operation_id].related_stat
	local mercs = GetOperationProfessionals(sector_id,operation_id)
	if not next(mercs) then 
		return 
	end	
	local stat = mercs[1][related_stat]
	if IsCraftOperation(operation_id) and operation_id~="RepairItems" then
		for _, q_item in ipairs(s_queued) do
			local time = CraftOperationsRecipes[q_item.recipe].CraftTime 
			local calced_time = 3*time*1000/2 - stat*time*1000/100
			total_time = total_time + calced_time
		end
		sector.custom_operations  = sector.custom_operations or {} 
		sector.custom_operations[operation_id] = sector.custom_operations[operation_id] or {}
		sector.custom_operations[operation_id].total_time = total_time
	end
end

function NetSyncEvents.SectorOperationItemsUpdateLists(sector_id,operation_id, sector_items, sector_items_queued)	
	OperationsSync_SuspendObjModified()
	local sector = gv_Sectors[sector_id]
	NetSyncEvents.ChangeSectorOperationItemsOrder(sector_id, operation_id, sector_items, sector_items_queued)
	local s_queued, s_all = SectorOperationItems_GetTables(sector_id, operation_id)
	SectorOperation_CraftTotalTime(sector_id, operation_id)
	RecalcOperationETAs(sector, operation_id, "stopped")
	ObjModified(sector)
	ObjModified(s_queued)
	if s_all then ObjModified(s_all) end
	--SectorOperation_ItemsUpdateItemLists() --not needed it seems	
end

function NetSyncEvents.RecalcOperationETAs(sector_id, operation, stopped)
	RecalcOperationETAs(gv_Sectors[sector_id], operation, stopped)
end

function CombineOperationCosts(costs)
	local combinedCosts = {}
	for _, cost_t in ipairs(costs) do
		for i, c in ipairs(cost_t) do
			local resource = c.resource
			local comb_idx = table.find(combinedCosts, "resource", c.resource)
			if comb_idx then
				combinedCosts[comb_idx].value = combinedCosts[comb_idx].value + c.value
			else
				combinedCosts[#combinedCosts + 1] = table.copy(c)
			end
		end
	end
	return combinedCosts
end

function GetOperationCostsProcessed(mercs,operation_id, prof_id, both, refund)
	local operation = type(operation_id)=="string" and SectorOperations[operation_id] or operation_id
	local costs = {}
	local min, mcost, merc = false
	for idx, m in ipairs(mercs) do
		local cost = operation:GetOperationCost(m, prof_id or m.OperationProfession, refund)		
		if both and operation.id=="TreatWounds" then
			local idx = #costs+1	
			costs[idx] = cost or {}
			if m.OperationProfessions and m.OperationProfessions["Doctor"] and m.OperationProfessions["Patient"]then
				assert(operation.id=="TreatWounds")					
				local other = m.OperationProfession=="Patient" and "Doctor" or "Patient"
				for _,cost in ipairs(operation:GetOperationCost(m, other)) do
					costs[idx] = costs[idx] or {}
					table.insert(costs[idx], cost)
				end
			end
		end
		if cost[1] and cost[1].min then
			if not min or cost[1].value<min then
				 min, mcost, merc  = cost[1].value, cost, m
			end
		elseif not (both and operation.id=="TreatWounds" ) then
			costs[#costs + 1] = cost		
		end
	end	
	if min then
		costs[#costs + 1] = mcost		
	end
	return costs	, merc
end

function GetOperationCosts(mercs, operation_id, prof_id, slot, other_free_slots)
	local operation = SectorOperations[operation_id]
	local names = {}
	local combinedCosts = {}
	local costs = {}
	local errors = {}
	--local min, cost, merc = false
	costs = GetOperationCostsProcessed(mercs,operation_id, prof_id)
	for idx, m in ipairs(mercs) do
		names[#names + 1] = m.Nick
		local err, context = operation:CanPerformOperation(m, prof_id)
		if err and err~= "OperationResourceError" then -- operation cost err is parsed in can pay operation one more time. Does not display mesage twise
			table.insert(context, m)
			errors[#errors + 1] = T{SatelliteWarnings[err].Body, context, context[1]}
		end
	end
	
	local combinedCosts = CombineOperationCosts(costs)
	local costTexts = {}
	for _, cc in ipairs(combinedCosts) do
		local resourceId, amount = cc.resource, cc.value
		if CheatEnabled("FreeParts") and resourceId=="Parts" then 
			amount = 0
		end

		local resourceData = SectorOperationResouces[resourceId]
		costTexts[#costTexts + 1] = T{Untranslated(amount) .. string.format("<image %s 1700>", resourceData.icon)}
	end
	if next(mercs) and not CanPayOperation(combinedCosts, mercs[1]:GetSector()) then
		local err, context =  "OperationResourceError", {activity = operation.display_name} 
		if err then
			local mercs_text = {}
			for i=1,#mercs do
				mercs_text[#mercs_text + 1] = mercs[i]:GetDisplayName()
			end
			errors[#errors + 1] = T{SatelliteWarnings[err].Body, context, DisplayName = table.concat(mercs_text,", ")}
		end
	end
	return combinedCosts, costTexts, names, errors
end

function MercsNetStartOperation(mercs, operation_id, prof_id, cost , slot, other_free_slots, t_wounds_being_treated)
	for i, m in ipairs(mercs) do
		local slt = i == 1 and slot or other_free_slots and other_free_slots[i-1]
		local treated_wounds = t_wounds_being_treated and t_wounds_being_treated[m]
		
		NetSyncEvent("MercSetOperation", m.session_id, operation_id, prof_id, i == 1 and cost, slt or ((slot or 1) + (i-1)), false, treated_wounds)
	end
end

function MercsOperationsFillTempDataMercs(mercs, operation_id, prof_id, cost , slot, other_free_slots, t_wounds_being_treated)
	local sector = mercs[1]:GetSector()
	sector.operations_temp_data = sector.operations_temp_data or {}
	if not sector.operations_prev_data or sector.operations_prev_data.operation_id~=operation_id then
		sector.operations_prev_data = {}
	end
	local temp_table =  sector.operations_temp_data[operation_id] or {}
	for i, m in ipairs(mercs) do
		local allProfessions = m.Operation == "TreatWounds" and operation_id == "TreatWounds" and not (m.OperationProfessions[prof_id])
		local slot = m.OperationProfession==prof_id and slot or other_free_slots and other_free_slots[i-1] or 1
		local treated_wounds = t_wounds_being_treated and t_wounds_being_treated[m]	or false	
		local tt_merc = temp_table[m.session_id] or {}
		local prev_operation = m.Operation		
		if sector.operations_prev_data[m.session_id] then
			prev_operation = sector.operations_prev_data[m.session_id].prev_Operation
		end
		local insert_data = {operation_id, prof_id or false, i == 1 and cost, slot or false, false, treated_wounds or false, 
								  RestTimer = m.RestTimer, TravelTime = m.TravelTime, TravelTimerStart = m.TravelTimerStart, Tiredness = m.Tiredness, prev_Operation = prev_operation}
		if next(tt_merc) and allProfessions then
			table.insert(tt_merc,insert_data)
		else
			tt_merc = {insert_data}
		end
		temp_table[m.session_id] = tt_merc
		sector.operations_prev_data[m.session_id] =  tt_merc
	end
	sector.operations_temp_data[operation_id] = temp_table
	sector.operations_prev_data.operation_id = operation_id
end

function GetCraftOperationListsIds(operation_id)
	if operation_id=="RepairItems" then
		return "sector_repair_items_queued", "sector_repair_items"
	end
	local queued = operation_id == "CraftAmmo" and "sector_craft_ammo_items_queued" or operation_id == "CraftExplosives" and "sector_craft_explosive_items_queued"
	if not queued and IsCraftOperationId(operation_id) then
		return "sector_"..operation_id.."_items_queued", false, "_custom"
	end
	return queued, false
end		

function 	SetCraftOperationQueueTable(sector, operation_id, queue)
	local qid, _, is_custom = GetCraftOperationListsIds(operation_id)
	if is_custom then
		sector.custom_operations = sector.custom_operations or {}
		sector.custom_operations[operation_id] = sector.custom_operations[operation_id] or {}
		sector.custom_operations[operation_id][qid] = queue
		return sector.custom_operations[operation_id][qid]
	else
		sector[qid] = queue
		return sector[qid]
	end
end	

function 	GetCraftOperationQueueTable(sector, operation_id)
	local qid, _, is_custom = GetCraftOperationListsIds(operation_id)
	if is_custom then
		sector.custom_operations[operation_id] = sector.custom_operations[operation_id] or {}
		ObjModified(sector.custom_operations[operation_id][qid])
		return sector.custom_operations[operation_id][qid]
	else
		ObjModified(sector[qid])
		return sector[qid]
	end
end	

function IsCraftOperationId(operation_id)
	return CraftOperationIds[operation_id]
end

function IsCraftOperation(operation_id)
	return operation_id=="RepairItems" or IsCraftOperationId(operation_id)
end

function MercsOperationsFillTempData(sector, operation_id)
	if not IsCraftOperation(operation_id) then
		return 
	end	
	-- RepairItems, craft
	sector.operations_temp_data = sector.operations_temp_data or {}
	local temp_table =  sector.operations_temp_data[operation_id] or {}
	temp_table.all_items = table.copy(SectorOperationItems_GetAllItems(sector.Id, operation_id) or {})
	temp_table.queued_items = table.copy(SectorOperationItems_GetItemsQueue(sector.Id, operation_id) or {})
	sector.operations_temp_data[operation_id] = temp_table
end

function TryMercsSetPartialTreatWounds(parent, mercs, operation_id, prof_id, slot, other_free_slots)
	local sector = mercs[1] and mercs[1]:GetSector()
	if prof_id ~= "Patient" or not sector then
		return
	end
	
	local cost, costTexts, names, errors = GetOperationCosts(mercs, operation_id, prof_id, slot, other_free_slots)
	if not cost or not cost[1] or not cost[1].value then
		return
	end
	
	local t_wounds_being_treated = {}
	local res_t = SectorOperationResouces["Meds"]
	local all_meds = res_t and res_t.current(sector) or 0
	local treatWoundsOperation = SectorOperations["TreatWounds"]
	local cost_per_wound = treatWoundsOperation:ResolveValue("MedicalCostPerWound")
	for i, m in ipairs(mercs) do
		local cost_p = treatWoundsOperation:GetOperationCost(m, "Patient")[1]
		if cost_p.value < all_meds then
			all_meds = all_meds - cost_p.value
			t_wounds_being_treated[m] = PatientGetWoundedStacks(m)
		else
			local partial = all_meds / cost_per_wound
			if partial > 0 then
				t_wounds_being_treated[m] = partial
			end
			break
		end
	end
	
	for i = #mercs, 1, -1 do
		if not t_wounds_being_treated[mercs[i]] then
			table.remove(mercs, i)
		end
	end
	
	if next(mercs) then
		local count = 0
		local treatWoundsOperation = SectorOperations["TreatWounds"]
		for k, v in pairs(t_wounds_being_treated) do
			count = count + v
		end
		cost[1].value = count * treatWoundsOperation:ResolveValue("MedicalCostPerWound")
		local dlg = CreateQuestionBox(
			terminal.desktop,
			T(1000599, "Warning"),
			T{887037769776, "You don't have enough Meds to fully heal all mercs. Do you want to spend <meds> Meds to heal <number> wound(s)?",
				meds = cost[1].value, number = count },
			T(689884995409, "Yes"),
			T(782927325160, "No"))
		dlg:SetModal()
		if dlg:Wait()== "ok" then
			MercsOperationsFillTempDataMercs(mercs, operation_id, prof_id, cost, slot, other_free_slots, t_wounds_being_treated)
			MercsNetStartOperation          (mercs, operation_id, prof_id, cost, slot, other_free_slots, t_wounds_being_treated)
		end
		return true
	end
end

function TryMercsSetOperation(parent, mercs, operation_id, prof_id, slot, other_free_slots)
	local operation = SectorOperations[operation_id]
	local message = ""
	local cost, costTexts, names, errors = GetOperationCosts(mercs, operation_id, prof_id, slot, other_free_slots)
	local anyErrors = #errors > 0
	if anyErrors then
		local partial = TryMercsSetPartialTreatWounds(parent, mercs, operation_id, prof_id, slot, other_free_slots)
		if not partial then
			WaitMessage(parent, T(788367459331, "Error"), table.concat(errors, T(420993559859, "<newline>")), T(325411474155, "OK"))
		end
		return partial
	end	
	
	--	move to temp data
	
	-- confirmation
	
	-- set merc operation in one place
	MercsOperationsFillTempDataMercs(mercs, operation_id, prof_id, cost , slot, other_free_slots)
	MercsNetStartOperation          (mercs, operation_id, prof_id, cost, slot, other_free_slots)	
	return true
end

function SectorOperation_UpdateOnStop(operation, mercs, sector)
	local sector = sector or (mercs and mercs[1] and mercs[1]:GetSector())
	if not sector then return end
	if sector.started_operations and #GetOperationProfessionals(sector.Id, operation.id) == 0 then
		sector.started_operations[operation.id] = false
		local event_id =  GetOperationEventId(mercs[1],  operation.id)
		RemoveTimelineEvent(event_id)
	end	
end

function OnMsg.OperationCompleted(operation, mercs, sector)
	return SectorOperation_UpdateOnStop(operation, mercs, sector)
end

function GetAvailableMercs(sector, operation, profession)
	local mercs = {}
	local operation = type(operation)=="string" and SectorOperations[operation] or operation
	for _, unit_data in ipairs(GetOperationProfessionals(sector.Id, "Idle")) do
		if operation:FilterAvailable(unit_data, profession) then
			local idx = unit_data.OperationProfessions and unit_data.OperationProfessions[profession] or (#mercs + 1)
			if mercs[idx] then
				idx = table.count(mercs) + 1
			end
			mercs[idx] = unit_data
		end
	end
	-- Special cases where a merc can take multiple professions in one operation.
	-- For now this applies to TreatWounds only
	if operation.id == "TreatWounds" then
		local check_other 
		if profession == "Patient" then
			check_other = "Doctor"
		elseif profession == "Doctor" then
			check_other = "Patient"
		end	
		for _, unit_data in ipairs(GetOperationProfessionals(sector.Id, "TreatWounds", check_other)) do
			if operation:FilterAvailable(unit_data, profession) and (not unit_data.OperationProfessions or not unit_data.OperationProfessions[profession]) then
				local idx = (#mercs + 1)
				mercs[idx] = unit_data
			end
		end
	end
	return mercs
end

function GetBusyMercsForList(sector, operation, profession)
	local mercs = {}
	for _, unit_data in ipairs(GetOperationProfessionals(sector.Id, operation.id, profession)) do
		local idx = unit_data.OperationProfessions and unit_data.OperationProfessions[profession] or (#mercs + 1)
		if mercs[idx] then
			idx = table.count(mercs) + 1
		end
		mercs[idx] = unit_data
	end
	return mercs
end


function GetOperationMercsListContext(sector, mode_param)
	local operation = SectorOperations[mode_param.operation]
	if mode_param.assign_merc then
		local mercs = GetAvailableMercs(sector, operation, mode_param.profession)
		local _, merc = next(mercs)
		if operation.related_stat or operation.related_stat_2 or merc and operation:GetRelatedStat(merc) then
			table.sort(mercs, function(a, b)
				if not a then return false end
				if not b then return true end
				local _, val_a = operation:GetRelatedStat(a)
				local _, val_b = operation:GetRelatedStat(b)
				return val_a > val_b
			end)
		end
		return {[1] = {mercs = mercs}}
	else
		local context = {}
		for _, prof in ipairs(operation.Professions) do
			local id = prof.id
			local mercs = GetBusyMercsForList(sector, operation, id)
			local sector_slots = operation:GetSectorSlots(id, sector)
			local infinite_slots = sector_slots == -1
			local all_mercs = #GetPlayerMercsInSector(sector.Id)
			if sector_slots == -1 then -- infinite
				if all_mercs>#mercs then -- there a re free mercs
					mercs[#mercs + 1] =  {class = "empty", prof = id}
				end
			else
				for i = 1, (sector_slots or 0) do
					mercs[i] = mercs[i] or {class = "empty", prof = id}
				end
			end
			if #mercs <= 0 then
				mercs[1] = {class = "empty", prof = id}
			end
			local occupied_slots = 0
			for i=1,#mercs do
				mercs[i] = mercs[i] or {class = "empty", prof = id}
				if mercs[i].class ~= "empty" then
					occupied_slots = occupied_slots + 1
				end
			end			

			local free_space = #mercs%6==0 and 0 or 6-(#mercs%6)
			for i=1,free_space do
				mercs[#mercs + 1] = {class = "free_space",}
			end
			
			context[#context + 1] = {
				mercs = mercs, 
				occupied_slots = occupied_slots,
				title = prof.display_name_plural_all_caps, 
				sector_id = sector.Id,
				list_as_prof = id, 
				operation = mode_param.operation,
				infinite_slots = infinite_slots,
				free_space = free_space,
			}
		end
		
		if operation.id == "MilitiaTraining" then
			-- add militia list
			local mercs = {}
			local militia_squad_id = sector.militia_squad_id 
			local militia_squad = militia_squad_id and gv_Squads[militia_squad_id]

			local count = {MilitiaRookie = 0,MilitiaVeteran = 0, MilitiaElite = 0} -- count already created and in the squad
			for i,unit_id in ipairs(militia_squad and militia_squad.units) do
				local class = gv_UnitData[unit_id].class				
				count[class] = count[class] + 1
			end
			if count.MilitiaRookie > 0 then
				mercs[#mercs + 1] = {class = "MilitiaRookie", def = "MilitiaRookie", prof = "Militia", in_progress = false, click =  false, count = count.MilitiaRookie}
			end
			if count.MilitiaVeteran > 0 then
				mercs[#mercs + 1] = {class = "MilitiaVeteran", def = "MilitiaVeteran", prof = "Militia",  in_progress = false, click =  false, count = count.MilitiaVeteran}
			end
			if count.MilitiaElite > 0 then
				mercs[#mercs +1 ] = {class = "MilitiaElite", def = "MilitiaElite", prof = "Militia",  in_progress = false, click =  false, count = count.MilitiaElite}
			end
			
			local trainers =  GetOperationProfessionals(sector.Id, operation.id, "Trainer")
			if #trainers>0 then
				-- add in progress				
				local added_MilitiaRookie = 0
				local added_MilitiaVeteran = 0
				for i = 1, const.Satellite.MilitiaUnitsPerTraining do
					if (added_MilitiaRookie + #(militia_squad and militia_squad.units or "")) < sector.MaxMilitia then
						added_MilitiaRookie = added_MilitiaRookie + 1
					else -- level up
						if count.MilitiaRookie<=0 then
							break
						end
						local units_def = table.find_value(mercs, "def", "MilitiaRookie")	
						if units_def then
							units_def.count = units_def.count - 1
							if units_def.count<=0 then
								table.remove_value(mercs, "def", "MilitiaRookie")
							end
						end	
						count.MilitiaRookie =  count.MilitiaRookie - 1
						count.MilitiaVeteran = count.MilitiaVeteran + 1
						added_MilitiaVeteran = added_MilitiaVeteran + 1
					end
				end
				if added_MilitiaRookie>0 then
					table.insert(mercs,1,{class = "MilitiaRookie", prof = "Militia", in_progress = true, click =  false, count = added_MilitiaRookie})						
				end
				if added_MilitiaVeteran > 0 then
					table.insert(mercs,1, {class = "MilitiaVeteran", prev = "MilitiaRookie", prof = "Militia", in_progress = true, click =  false, count = added_MilitiaVeteran})
				end		
			end
			
	--		for i=#mercs+1, sector.MaxMilitia  do
	--			mercs[i] = {class = "empty", prof =  "Militia", click =  false}
	--		end
			context[#context + 1] = {mercs = mercs, title = T(977391598484, "Militia"), click =  false,  operation = mode_param.operation}
		end
		
		return context
	end
end

function FillTempDataOnOpen(sector, operation_id)
	local context = GetOperationMercsListContext(sector, {operation = operation_id})
	local operation = SectorOperations[operation_id]
	local temp_table = {}
	for _, prof in ipairs(operation.Professions) do
		local profession = prof.id	
	
		local mercs = context[_].mercs	
		local costs = GatOperationCostsArray(sector.Id,SectorOperations[operation_id])
		
		local idx = 0
		for i, merc in ipairs(mercs) do
			if merc.class~="empty" and merc.class~="free_space" then	
				idx = idx+1				
				temp_table[merc.session_id] = temp_table[merc.session_id] or {}
				table.insert(temp_table[merc.session_id],
					{operation_id,profession or false, costs[idx+1] or false,merc.OperationProfessions and merc.OperationProfessions[profession] or idx, false, IsPatient(merc) and merc.wounds_being_treated or false,
						RestTimer = merc.RestTimer, TravelTime = merc.TravelTime, TravelTimerStart = merc.TravelTimerStart, Tiredness = merc.Tiredness, prev_Operation = operation_id})
			end
		end
	end	
	sector.operations_temp_data =  sector.operations_temp_data  or {}
	sector.operations_temp_data[operation_id] = temp_table
	MercsOperationsFillTempData(sector, operation_id)
end

function GetOperationsInSector(sector_id)
	local sector_operations = {}
	local sector = gv_Sectors[sector_id]
	if not sector then return sector_operations end
	
	if sector.Side == "player1" or sector.Side == "player2" then
		for id, operation in pairs(SectorOperations) do
			if operation:HasOperation(sector) then
				local enabled, rollover = operation:IsEnabled(sector)
				if enabled then
					local idleling = GetOperationProfessionals(sector.Id, "Idle")
					for _, prof in ipairs(operation.Professions) do
						local mercs_available = GetAvailableMercs(sector, operation, prof.id)
						local mercs_current = GetOperationProfessionals(sector.Id, operation.id)
						if #idleling==0 and #mercs_available == 0 and #mercs_current == 0 then
							enabled = false
							rollover = T{776447291880, "No <name> available", name = prof.display_name}
							break
						end
					end
				end
				if sector.started_operations and sector.started_operations[id] or 
					next(GetOperationProfessionals(sector_id, id)) 
				then
					rollover = ""
					enabled = true
				end
				sector_operations[#sector_operations + 1] = {operation = operation, enabled = enabled , rollover = rollover, sector = sector_id}
			end
		end
	end
	
	table.sort(sector_operations, function (a, b)
		local operationA = a.operation
		local operationB = b.operation
		local k1, k2 = operationA.SortKey, operationB.SortKey
		if operationA.Custom then k1 = k1 - 100 end
		if operationB.Custom then k2 = k2 - 100 end
		if k1 ~= k2 then
			return k1 < k2
		end
		
		return operationA.id < operationB.id
	end)
	
	return sector_operations
end

function GetSectorOperationResource(sector, item_id)
	local amount = {count = 0}
--[[	-- sector inventory
	local containers = sector.sector_inventory or empty_table
	for cidx, container in ipairs(containers) do
		if container[2] then -- is opened
			local items = container[3] or empty_table
			for idx, item in ipairs(items) do
				if item.class == item_id then 			
					amount.count = amount.count + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
				end	
			end
		end
	end
--]]
	-- bags
	local squads = GetSquadsInSector(sector.Id)
	for _, s in ipairs(squads or empty_table) do
		local bag = GetSquadBag(s.UniqueId) 
		for i, item in ipairs(bag or empty_table) do
			if item.class == item_id then
				amount.count = amount.count + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
			end
		end
	end
	-- all mercs
	local mercs = GetPlayerMercsInSector(sector.Id)
	for _, id in ipairs(mercs) do
		local unit = gv_UnitData[id]
		unit:ForEachItemDef(item_id, function(item, slot, amount)
			amount.count = amount.count + (IsKindOf(item, "InventoryStack") and item.Amount or 1)
		end, amount)
	end
	
	return amount.count
end

function NetSyncEvents.PaySectorOperationResource(sector_id, item_id, count)
	local left = count --TakeItemFromSectorInventory(sector_id, item_id, count)
	if left > 0 then
		TakeItemFromMercs(GetPlayerMercsInSector(sector_id), item_id, left)
	end
	InventoryUIRespawn()
	ObjModified(gv_Sectors[sector_id])
	ObjModified(sector_id)
end

function NetSyncEvents.RestoreSectorOperationResource(merc_id, item_id, count)
	local merc = gv_UnitData[merc_id]
	if not merc then return end
	if not merc.Squad then return end --merc's contract has expired, he is no longer on the map or in a squad
	
	local left = count
	--bag
	left = AddItemToSquadBag(merc.Squad, item_id, left)	
	-- merc
	local sector = merc:GetSector()
	if left>0 then
		merc:ForEachItemDef(item_id, function(item, slot)
			if item.Amount < item.MaxStacks then
				local add = Min(left, item.MaxStacks - item.Amount)
				item.Amount = item.Amount + add
				left = left - add
				if left == 0 then
					return "break"
				end
			end
		end)
	end	
	local restore_to_merc = true
	if left > 0 then
		local item = PlaceInventoryItem(item_id)
		item.Amount = left
		left = 0
		local pos, reason = merc:AddItem("Inventory", item)
		if not pos then
			--AddToSectorInventory(sector.Id, {item})
			restore_to_merc = false
		end
	end
	if restore_to_merc then
		local res = SectorOperationResouces[item_id]
		CombatLog("short", T{173792230953, " Restored <count> <resource> to <Nick>.", count = count - left, resource = res.name, merc})
	end
	InventoryUIRespawn()
	ObjModified(sector)
	ObjModified(sector.Id)
end

function PaySectorOperationResource(sector_id, item_id, count)
	local isSync = IsGameTimeThread()
	if isSync then -- PayOperation
		NetSyncEvents.PaySectorOperationResource(sector_id, item_id, count)
	else -- ModifyWeaponDlg
		NetSyncEvent("PaySectorOperationResource", sector_id, item_id, count)
	end
end

function RestoreSectorOperationResource(merc, item_id, count)
	local isSync = IsGameTimeThread()
	if isSync then -- PayOperation
		NetSyncEvents.RestoreSectorOperationResource(merc.session_id, item_id, count)
	else -- ModifyWeaponDlg
		NetSyncEvent("RestoreSectorOperationResource", merc.session_id, item_id, count)
	end
end

function CanPayOperation(cost, sector)
	for _, c in ipairs(cost or empty_table) do
		local value = c.value
		if CheatEnabled("FreeParts") and c.resource== "Parts" then 
			value = 0
		end
		local res_t = SectorOperationResouces[c.resource]
		local total = res_t and res_t.current(sector) or 0
		if value and value > total then
			return false
		end
	end
	return true
end

function PayOperation(cost, sector)
	for _, c in ipairs(cost or empty_table) do
		local res_t = SectorOperationResouces[c.resource]
		res_t.pay(sector, c.value)
	end
end

function GetCustomOperations()
	local operations = table.keys(SectorOperations, true)
	local custom = {}
	for _, ac in ipairs(operations) do
		if SectorOperations[ac].Custom then
			custom[#custom + 1] = ac
		end
	end
	return custom
end

function GetOperationProfessionals(sector_id, operation, profession, exclude_unit_id)
	local profs = {}
	local mercs = GetPlayerMercsInSector(sector_id)
	for _, id in ipairs(mercs) do
		local unit = gv_UnitData[id]
		if (not exclude_unit_id or id~=exclude_unit_id )and (not operation or operation == unit.Operation) and (not profession or unit.OperationProfessions and unit.OperationProfessions[profession] or unit.OperationProfession==profession) then
			profs[#profs + 1] = unit
		end
	end
	return profs
end

function GetOperationProfessionalsGroupedByProfession(sector_id, operation_id)
	local mercs = GetOperationProfessionals(sector_id, operation_id)
	if #mercs == 0 then return empty_table end
	
	if not operation_id then
		local grouped = {}
		for i, m in ipairs(mercs) do
			local operation = m.Operation
			local profession = m.OperationProfession or ""
			if not grouped[operation] then grouped[operation] = {} end
			if not grouped[operation][profession] then grouped[operation][profession] = {} end
			local arr = grouped[operation][profession]
			arr[#arr + 1] = m
		end
		return grouped
	end
	
	local operationPreset = SectorOperations[operation_id]
	local professions = operationPreset.Professions
	if not professions or #professions == 0 then return mercs end
	
	local grouped = {}
	for i, profs in ipairs(professions) do
		local id = profs.id
		local profsArr = {}
		
		for i, m in ipairs(mercs) do
			if m.OperationProfessions and m.OperationProfessions[id] or m.OperationProfession==id then
				profsArr[#profsArr + 1] = m
			end
		end
		
		grouped[id] = profsArr
	end
	
	return grouped
end

function GetOperationCostText(cost, img_tag, no_sign, no_name)
	local cost_t = {}
	for _, c in ipairs(cost or empty_table) do
		if c.value >= 0 then
			local t = SectorOperationResouces[c.resource]
			local display_value = c.value
			if not no_sign then
				display_value = -display_value
			end
			local texts = {Untranslated(display_value)}
			if not no_name then
				texts[#texts+1] = t.name
			end
			if img_tag and t.icon then
				texts[#texts+1] =  Untranslated(string.format("<image %s 1700 %d %d %d>", t.icon, GetRGB(GameColors.G)))
			end
			cost_t[#cost_t + 1] = table.concat(texts, "")
		end
	end
	return table.concat(cost_t, ", ")
end

function GatOperationCostsArray(sector_id, operation)
	local operations 
	if operation == "all" then	
		operations = GetOperationsInSector(sector_id)
	else	
		operations = {{operation = operation}}
	end	
	local costs = {}
	for _, operation_data in ipairs(operations) do
		local sector_operation = operation_data.operation
		local amercs = GetOperationProfessionals(sector_id, sector_operation.id)
		local ocosts = GetOperationCostsProcessed(amercs,sector_operation, false, "both", "refund")
		table.iappend(costs, ocosts)
	end
	return costs
end											

function GetActorOperationTimeLeft(merc, operation, profession)
	local sector = merc:GetSector()
	local operation = SectorOperations[operation]
	local progress_per_tick = operation:ProgressPerTick(merc, profession)
	if CheatEnabled("FastActivity") then
		progress_per_tick = progress_per_tick*100
	end
	local left_progress = operation:ProgressCompleteThreshold(merc, sector, profession) - operation:ProgressCurrent(merc, sector, profession)
	local ticks_left = progress_per_tick==0 and 0 or left_progress / progress_per_tick
	if left_progress > 0 then
		ticks_left = Max(ticks_left, 1)
	end
	return ticks_left*const.Satellite.Tick
end

-- treat wounds
function GetPatientHealingTimeLeft(merc, ativity_id)
	return GetActorOperationTimeLeft(merc, ativity_id or "TreatWounds", "Patient")
end

function TreatWoundsTimeLeft(context, operation_id)
	if context.list_as_prof == "Patient" and (context.force or IsPatient(context.merc)) then
		return GetPatientHealingTimeLeft(context.merc, operation_id)
	else
		local slowest = 0
		for _, unit in ipairs(GetOperationProfessionals(context.merc:GetSector().Id, operation_id, "Patient")) do
			slowest = Max(slowest, GetPatientHealingTimeLeft(unit, operation_id))
		end
		return slowest
	end
end

function GetHealingBonus(sector, operation_id)
	local bonus = 0
	local doctors = GetOperationProfessionals(sector.Id, operation_id, "Doctor")
	if #doctors>0 then
		bonus = 100
		local forgiving_mode = IsGameRuleActive("ForgivingMode")
		for _, unit in ipairs(doctors) do
			local stat = unit.Medical
			local min_stat_boost = GameRuleDefs.ForgivingMode:ResolveValue("MinStatBoost") or 0
			if forgiving_mode and stat<min_stat_boost then
				stat = stat + (min_stat_boost-stat)/2
			end
			bonus = bonus + stat * 2
		end
	end
	return bonus
end

function GetSumOperationStats(mercs, stat, stat_multiplier)
	-- add progress
	local forgiving_mode = IsGameRuleActive("ForgivingMode")
	local sum_stat = 0
	local min_stat_boost = GameRuleDefs.ForgivingMode:ResolveValue("MinStatBoost") or 0
	local has_perk = false
	for _, m in ipairs( mercs) do
		local stat_val = m[stat] or 0
		if forgiving_mode and stat_val<min_stat_boost then	
			stat_val = stat_val + (min_stat_boost-stat_val)/2
		end
		stat_val = MulDivRound(stat_val, stat_multiplier, 100) 
		if HasPerk(m, "JackOfAllTrades") then
			has_perk  = true
		end
		sum_stat = sum_stat + stat_val 
	end
	if has_perk then
		local mod = CharacterEffectDefs.JackOfAllTrades:ResolveValue("activityDurationMod")
		sum_stat = sum_stat + MulDivRound(sum_stat, mod, 100)
	end		
	return sum_stat	
end	

function IsDoctor(merc)
	return merc.Operation == "TreatWounds" and merc.OperationProfessions and merc.OperationProfessions["Doctor"]
end

function IsPatient(merc)
	return merc and IsOperationHealing(merc.Operation) and (merc.OperationProfessions and merc.OperationProfessions["Patient"])
end

function SectorOperationCountPatients(sector_id, except_unit_id)
	local count = 0
	for _, unit_data in ipairs(GetOperationProfessionals(sector_id, "TreatWounds")) do
		if unit_data.session_id~=except_unit_id and IsPatient(unit_data) then
			count = count + 1
		end
	end
	return count
end

function IsOperationHealing(operation_id)
	local operationPreset = SectorOperations[operation_id]
	if not operationPreset then
		assert(false, "No such operation: " .. operation_id)
		return false
	end
	return operationPreset and operationPreset.operation_type and operationPreset.operation_type.Healing
end

function UnitHealPerTick(merc, pertick_progress, heal_wound_threshold, dont_log)
	merc.wounds_being_treated = merc.wounds_being_treated>0 and merc.wounds_being_treated or PatientGetWoundedStacks(merc)
	if merc.wounds_being_treated >0 then
		local progress_per_tick = pertick_progress
		if CheatEnabled("FastActivity") then
			progress_per_tick = progress_per_tick*100
		end
		PatientAddHealWoundProgress(merc, progress_per_tick, heal_wound_threshold, dont_log)
	end
end

function PatientAddHealWoundProgress(merc, progress, max_progress, dont_log)
	if IsGameRuleActive("ForgivingMode") then 
		-- Boost resting/traveling and R&R heal speed by 25%. 
		local boost = GameRuleDefs.ForgivingMode:ResolveValue("HealingProgressBoost") or 0
		progress = MulDivRound(progress, 100 + boost, 100)
	end
	merc.heal_wound_progress = merc.heal_wound_progress + progress
	local wounds_healed = false
	while merc.heal_wound_progress > max_progress do
		merc:RemoveStatusEffect("Wounded", 1, merc.Operation)
		merc.wounds_being_treated = merc.wounds_being_treated - 1
		if merc.wounds_being_treated>0 then
			local effect = merc:GetStatusEffect("Wounded") 
			merc.wounds_being_treated = Min(merc.wounds_being_treated, effect and effect.stacks or 0)
		end
		merc.heal_wound_progress = merc.heal_wound_progress - max_progress
		wounds_healed = true
	end
	if wounds_healed and not dont_log then
		if merc.OperationProfession ~= "Doctor" then
			local context = {merc = merc}
			if merc.Operation ~= "TreatWounds" or
				(merc.Operation == "TreatWounds" and TreatWoundsTimeLeft(context,merc.operation) > 0) then
				PlayVoiceResponse(merc, "HealReceivedSatView")
			end
		end
	end
	if IsPatientReady(merc) then
		if merc.heal_wound_progress > 0 then
			merc:SetTired(Min(merc.Tiredness, const.utNormal))
		end
		merc.heal_wound_progress = 0
		merc.wounds_being_treated = 0
	elseif wounds_healed and not dont_log then
		CombatLog("short", T{394097034872, "<merc_name> was <em>cured of a wound</em>.", merc_name = merc.Nick})
	end
end

function IsPatientReady(merc)
	return not merc:HasStatusEffect("Wounded") or merc.wounds_being_treated == 0
end

function PatientGetWoundedStacks(merc)
	local idx = merc:HasStatusEffect("Wounded")
	local effect = idx and merc.StatusEffects[idx]
	return effect and effect.stacks or 0
end

function PatientGetWoundsBeingTreated(merc)
	return IsPatient(merc) and (merc.wounds_being_treated and merc.wounds_being_treated>0) and merc.wounds_being_treated or PatientGetWoundedStacks(merc)
end

function RecalcOperationETAs(sector,operation, stopped)
	local units = GetOperationProfessionals(sector.Id, operation)
	local updated
	for _, unit_data in ipairs(units) do
		local left = GetOperationTimerETA(unit_data) or 0
		NetUpdateHash("RecalcOperationETAs", unit_data.session_id, left)
		if stopped or (unit_data.OperationInitialETA or 0) < left then -- if the initial ETA was not bigger, the timer will work ok, it will just move faster
			if not stopped or IsCraftOperation(operation) then
				unit_data.OperationInitialETA = left
				updated  = true
			end
			Msg("OperationTimeUpdated", unit_data, operation)
		end
	end
	if not updated and operation=="RepairItems" and next(units) then
		Msg("OperationTimeUpdated", units[1], operation)
	end
end

function GetUnitStatsComboTranslated(except_stat)
	local items = {}
	local props = UnitPropertiesStats:GetProperties()
	for _, prop in ipairs(props) do
		if prop.category == "Stats" and except_stat~=prop.id then
			items[#items + 1] = {name = prop.name, value = prop.id}
		end
	end
	return items
end

------------------------------ UI------------------
local tile_size = 72
local tile_size_h = 72
local tile_size_rollover = 146

function SectorOperationItems_ItemsCount(tbl)
	local count= 0
	for i,itm_data in ipairs(tbl) do
		local itm = SectorOperation_FindItemDef(itm_data) 
		count = count + (itm:IsLargeItem()  and 2 or 1)
	end
	return count
end	

function SectorOperationItems_GetTables(sector_id, operation_id)
	local sector = gv_Sectors[sector_id]
	if IsCraftOperation(operation_id) then
		local quid, allid = GetCraftOperationListsIds(operation_id)
		local tbl = GetCraftOperationQueueTable(sector, operation_id)
		return tbl, operation_id~="RepairItems" and _G["g_Recipes"..operation_id] or sector[allid]
	end
end

DefineClass.XOperationItemTile = {
	__parents = {"XInventoryTile"},
	slot_image = "UI/Icons/Operations/repair_item",
	IdNode = true,
	MinWidth = tile_size_rollover,
	MaxWidth = tile_size_rollover,
	MinHeight = tile_size_rollover,
	MaxHeight = tile_size_rollover,	
}

function XOperationItemTile:Init()
	local image = XImage:new({
		MinWidth = tile_size,
		MaxWidth = tile_size,
		MinHeight = tile_size_h,
		MaxHeight = tile_size_h,
		Id = "idBackImage",
		Image = "UI/Inventory/T_Backpack_Slot_Small_Empty.tga",
		ImageColor = 0xFFc3bdac,
	},
	self)

	if self.slot_image then
		local imgslot = XImage:new({
			MinWidth = tile_size,
			MaxWidth = tile_size,
			MinHeight = tile_size_h,
			MaxHeight = tile_size_h,
			ImageScale = point(600,600),
			Dock = "box",
			Id = "idEqSlotImage",			
			ImageColor = GameColors.A,
			Transparency = 110,
		},
		self)	
		imgslot:SetImage(self.slot_image)
		image:SetImage("UI/Inventory/T_Backpack_Slot_Small.tga")
		image:SetImageColor(RGB(255,255,255))
	end
	local rollover_image = XImage:new({
		MinWidth = tile_size_rollover,
		MaxWidth = tile_size_rollover,
		MinHeight = tile_size_h,
		MaxHeight = tile_size_h,

		Id = "idRollover",
		Image = "UI/Inventory/T_Backpack_Slot_Small_Hover.tga",
		ImageColor = 0xFFc3bdac,
		Visible = false,		
		ImageFit = "width",
		},
	self)
	rollover_image:SetVisible(false)
end

function XOperationItemTile:OnSetRollover()

end

DefineClass.XActivityItem = {
	__parents = {"XInventoryItem"},
	IdNode = true,
}

function XActivityItem:Init()
	self.idItemPad:SetImageFit("none")
	local item = self:GetContext()
	local item_equipimg = XTemplateSpawn("XImage", self.idItemImg)	
	item_equipimg:SetHAlign("right")
	item_equipimg:SetVAlign("bottom")
	--item_equipimg:SetImageFit("width")
	item_equipimg:SetId("idItemEqImg")
	item_equipimg:SetUseClipBox(false)	
	item_equipimg:SetHandleMouse(false)
	--item_equipimg:SetImage(IsEquipSlot(self.slot) and "UI/Icons/Operations/equipped" or "UI/Icons/Operations/backpack")
	item_equipimg:SetScaleModifier(point(600,600))
	item_equipimg:SetMargins(box(0,0,-15,-15))
	local roll_ctrl = self.idRollover
	roll_ctrl:SetScaleModifier(point(700,700))
end

function XActivityItem:OnContextUpdate(item,...)
	XInventoryItem.OnContextUpdate(self, item,...)
	local w, h = item:GetUIWidth(), item:GetUIHeight()
	self:SetMinWidth(tile_size*w)
	self:SetMaxWidth(tile_size*w)
	self:SetMinHeight(tile_size*h)
	self:SetMaxHeight(tile_size*h)
	self:SetGridWidth(w)
	self:SetGridHeight(h)
	
	if item.SubIcon and item.SubIcon~= "" then
		self.idItemImg.idItemSubImg:SetScaleModifier(point(600,600))
	end
	local img_mod = rawget(self.idItemImg, "idItemModImg")
	if img_mod then
	--	img_mod:SetVisible(false)
		img_mod:SetScaleModifier(point(550,550))
		img_mod:SetMargins(box(-18,-18, 0 , 0))
	end
	self.idItemImg.idItemEqImg:SetVisible(IsEquipSlot(self.slot) or item and item.owner)
	self.idItemImg.idItemEqImg:SetImage(IsEquipSlot(self.slot) and "UI/Icons/Operations/equipped" or "UI/Icons/Operations/backpack")
	local itm = rawget(self, "item")
	if itm then
		self.idText:SetText(T{641971138327, "<style InventoryItemsCountMax><amount></style>", amount = itm.amount})
	end	
	--self.idText:SetVisible(false)
end

function XActivityItem:OnDropEnter(drag_win, pt, drag_source_win)
end
function XActivityItem:OnDropLeave(drag_win, pt, source)
end
-----------------------------for repair itemsactivity----
function TableWithItemsToNet(t)
	local ret = {}
	for i, inv_slot in ipairs(t or empty_table) do
		ret[i] = {}
		local rr = ret[i]
		for ii, item in ipairs(inv_slot) do
			if item then
				rr[ii] = item.id
			end
		end
		for k, v in pairs(inv_slot) do
			if not rr[k] then
				rr[k] = v
			end
		end
	end
	return ret
end

function TableWithItemsFromNet(t)
	for i, inv_slot in ipairs(t) do
		for ii, item_id in ipairs(inv_slot) do
			inv_slot[ii] = g_ItemIdToItem[item_id]
		end
	end
	return t
end

DefineClass.XDragContextWindow = {
	__parents = { "XContentTemplate", "XDragAndDropControl" },
	properties = {
		{ category = "General", id = "slot_name", name = "Slot Name", editor = "text", default = "", },
		{ category = "General", id = "disable_drag", name = "Disable Drag", editor = "bool", default = false, },
	},	
	
	ClickToDrag = true,
	ClickToDrop = true,	
}

function XDragContextWindow:OnMouseButtonClick(pos, button)
	return XDragAndDropControl.OnMouseButtonClick(self, pos, button)
end

function XDragContextWindow:OnMouseButtonDoubleClick(pos, button)
	if button == "L" then
	--if not IsMouseViaGamepadActive() then
		local ctrl = self.drag_win
		if not ctrl then return "break" end	
		if not ctrl.idItem:GetEnabled() then return "break" end
		
		local operation_id = self.context[1].operation
		local dlg = GetDialog(self)
		local dlg_context = dlg and dlg.context
		local sector = dlg_context
		local sector_id = dlg_context.Id
		local is_repair = operation_id=="RepairItems"
		local search_id =  is_repair and "id" or "item_id"
		local serch_context = is_repair and ctrl.context.id or ctrl.context.class
		
		local queue, all = SectorOperationItems_GetTables(sector_id,operation_id )
		if self.Id=="idAllItems" then
			local item, idx = table.find_value(all, search_id, serch_context)
			local itm = item and SectorOperationRepairItems_GetItemFromData(item)

			local itm_width = itm and itm:IsLargeItem() and 2 or 1
			if SectorOperationItems_ItemsCount(queue) + itm_width <= 9 then
				if is_repair then 
					table.remove(all,idx)
				end	
				table.insert(queue,item)
			end	
		else
			local item, idx = table.find_value(queue, search_id, serch_context)
			table.remove(queue,idx)
			if is_repair then 
				table.insert(all,item)
			end	
		end
		self.drag_win:delete()
		self.drag_win = false
		self:StopDrag()
		SectorOperationValidateItemsToCraft(sector_id, operation_id)
		NetSyncEvent("SectorOperationItemsUpdateLists", sector_id,operation_id, TableWithItemsToNet(all), TableWithItemsToNet(queue))
		SectorOperation_ItemsUpdateItemLists(dlg:ResolveId("node"))
		return "break"		
---end
	end
end

function XDragContextWindow:OnDragStart(pt,button) 
	if self.disable_drag then return false end
	for i, wnd in ipairs(self) do
		if wnd:MouseInWindow(pt) and not IsKindOf(wnd.idItem, "XOperationItemTile") and wnd.idItem:GetEnabled() then
			return wnd
		end	
	end
	
	return false
end
function XDragContextWindow:OnHoldDown(pt, button)end					
function XDragContextWindow:IsDropTarget(drag_win, pt, source)return not self.disable_drag end
function XDragContextWindow:OnDrop(drag_win, pt, drag_source_win)end
function XDragContextWindow:OnDropEnter(drag_win, pt, drag_source_win)end
function XDragContextWindow:OnDropLeave(drag_win, pt, source)end

function XDragContextWindow:OnDragDrop(target, drag_win, drop_res, pt)
	if not drag_win or drag_win == target then
		return 
	end
	target = target or self
	local self_slot = self.slot_name
	local target_slot = target.slot_name
	local target_wnd = target
	for i, wnd in ipairs(target) do
		if wnd:MouseInWindow(pt) then
			target_wnd =  wnd
			break
		end	
	end
	
	local operation_id = self.context[1].operation
	local is_repair = operation_id=="RepairItems"
	local dlg = GetDialog(self)or GetDialog(target_wnd)
	local dlg_context = dlg and dlg.context
	target_wnd = target_wnd or drag_win
	local context = drag_win.context
	local target_context = target_wnd:GetContext()
	local sector = dlg_context
	local sector_id = dlg_context.Id
	local self_queue, target_queue

	local a_all   = SectorOperationItems_GetAllItems(sector_id, operation_id)
	local a_queue = SectorOperationItems_GetItemsQueue(sector_id, operation_id)
	
	if self_slot=="ItemsQueue" then
		self_queue = a_queue
	elseif self_slot=="AllItems" then
		self_queue = a_all or {}
	end
	if target_slot=="ItemsQueue" then
		target_queue = a_queue
	elseif target_slot=="AllItems" then
		target_queue = a_all or {}
	end
	
	local cur_idx    = is_repair and table.find(self_queue,"id", context.id) or table.find(self_queue,"item_id", context.class)
	local target_idx = is_repair and table.find(target_queue, "id", target_context.id)	 or table.find(target_queue,"item_id", target_context.class)
	local itm        = self_queue[cur_idx]
	local item = itm and SectorOperationRepairItems_GetItemFromData(itm)
	local itm_width  = is_repair and (item and item:IsLargeItem() and 2 or 1) or 1
	
	if self_slot==target_slot then
		if cur_idx then
			if target_idx then
				target_queue[cur_idx], target_queue[target_idx] = target_queue[target_idx],target_queue[cur_idx]
			else	
				local itm = table.remove(self_queue,cur_idx)
				target_queue[#target_queue+1] = itm
			end	
		end
	elseif target_slot~="ItemsQueue" or (SectorOperationItems_ItemsCount(target_queue) + itm_width) <= 9 then 
		local itm
		if is_repair or self_slot=="ItemsQueue" then
			itm  = table.remove(self_queue,cur_idx)
		else
			itm = table.copy(self_queue[cur_idx])
		end
		if is_repair or target_slot=="ItemsQueue" then
			if not target_idx then
				target_queue[#target_queue+1] = itm
			else	
				table.insert(target_queue,target_idx,itm)
			end	
		end
	end
	local s_queue, s_all = SectorOperationItems_GetTables(sector_id, operation_id)
	local all    = target_slot=="AllItems" and target_queue  or self_slot=="AllItems" and self_queue or s_all
	local queued = target_slot=="ItemsQueue" and target_queue  or self_slot=="ItemsQueue" and self_queue or s_queue 
	
	drag_win:delete()
	SectorOperationValidateItemsToCraft(sector_id, operation_id)
	NetSyncEvent("SectorOperationItemsUpdateLists", sector_id,operation_id, TableWithItemsToNet(all), TableWithItemsToNet(queued))
	local mercs = GetOperationProfessionals(sector_id, operation_id)
	local eta = next(mercs) and GetOperationTimeLeft(mercs[1], operation_id) or 0
	local timeLeft = eta and Game.CampaignTime + eta
	AddTimelineEvent("activity-temp", timeLeft, "operation", { operationId = operation_id, sectorId = sector_id})
	
	self:RespawnContent()
	target:RespawnContent()
	local node = self:ResolveId("node")
	node:OnContextUpdate(node:GetContext())
	local node = target:ResolveId("node")
	node:OnContextUpdate(node:GetContext())
	ObjModified(target_queue)
	ObjModified(self_queue)
end

function SectorOperation_StudentStatDiff(sector_id, student, teachers)
 local teachers = teachers or GetOperationProfessionals(sector_id, "TrainMercs", "Teacher")
 local sector = gv_Sectors[sector_id]
 local avg_teachers_stat = table.avg(teachers,sector.training_stat)
 local student_stat = student[sector.training_stat]
 local diff = avg_teachers_stat-student_stat
 if diff<20 then
	return 1
 elseif diff<40 then
	return 2
 else
	return 3
 end
end

function SectorOperation_ItemsCalcRes(sector_id, operation_id)
	local queued_items = SectorOperationItems_GetItemsQueue(sector_id, operation_id)
	local operation = SectorOperations[operation_id]
	local parts = 0	
	
	if operation_id=="RepairItems" then
		local free_repair = operation:ResolveValue("free_repair")
		local restore_condition_per_Part = operation:ResolveValue("restore_condition_per_Part")
		local parts_per_step = operation:ResolveValue("parts_per_step")
		for _, item_data in ipairs(queued_items) do
			local item = SectorOperationRepairItems_GetItemFromData(item_data)
			local cur_cond = item.Condition
			local max_condition = item:GetMaxCondition()
			local to_repair = max_condition - cur_cond

			--use parts
			if to_repair > 0 then
				if to_repair <= free_repair then
				else
					local border = 0
					while border<max_condition do
						local diff = restore_condition_per_Part
						border = border + diff	
						if cur_cond<border and cur_cond+diff>=border then
							parts = parts + parts_per_step
							cur_cond  = cur_cond + diff
						end
					end
				end
			end
		end	
	end
	if IsCraftOperationId(operation_id) then
		for _, item_data in ipairs(queued_items) do
			local item = CraftOperationsRecipes[item_data.recipe]
			for __,ing in ipairs(item.Ingredients) do
				if ing.item == "Parts" then
					parts = parts + ing.amount
				end
			end
		end	
	end
	return parts
end

function SectorOperation_SquadOnMove(sector_id, newsquads)
	local mercs = GetOperationProfessionals(sector_id, "RepairItems")
	if #mercs<=0 then return end
	local queued = SectorOperationItems_GetItemsQueue(sector_id, "RepairItems")
	for i = #queued, 1, -1 do
		local item = SectorOperationRepairItems_GetItemFromData(queued[i])
		if item.owner then
			local unit =  gv_UnitData[item.owner]
			local sqId = unit and unit.Squad 
			if sqId and table.find(newsquads, sqId) then
				table.remove(queued, i)
			end
		end	
	end

	local all = SectorOperationItems_GetAllItems(sector_id, "RepairItems")
	for i = #all, 1, -1 do
		local item = SectorOperationRepairItems_GetItemFromData(all[i])
		if item.owner then
			local unit =  gv_UnitData[item.owner]
			local sqId = unit and unit.Squad 
			if sqId and table.find(newsquads, sqId) then
				table.remove(all, i)
			end
		end	
	end
	NetSyncEvent("ChangeSectorOperationItemsOrder",sector_id, "RepairItems", TableWithItemsToNet(all), TableWithItemsToNet(queued))
end

local Additionalds = {prev_start_time = true ,all_items = true,queued_items = true,training_stat = true, operation_id = true}
function SectorOperations_IsValidMercId(m_id)
	return not Additionalds[m_id]
end

function SectorOperations_DataHasDifference(prev, cur, operation_id, sector)
	-- mercs and professions
	
	for m_id, m_data in pairs(prev) do
		if SectorOperations_IsValidMercId(m_id) then
			if not cur[m_id] then
				return true
			end
			local cur = cur[m_id]
			for i, tt_merc in ipairs(m_data) do
				local cur = cur[i]
				if tt_merc.prev_Operation=="Idle" then
					return false
				end
				for id,tdata in ipairs(tt_merc)  do						
					local idx = id
					--if idx>=3 then idx = idx+1 end
					if cur[idx]==nil or cur[idx]~=tdata then
						return true
					end	
				end
			end	
		end
	end
	for m_id, m_data in pairs(cur) do
		if SectorOperations_IsValidMercId(m_id) then
			if not prev[m_id] then
				return true
			end
		end
	end
	-- repair items
	if IsCraftOperation(operation_id) then
		if prev.all_items and not sector.sector_repair_items  
			or sector.sector_repair_items and not prev.all_items 
			or prev.queued_items and sector.sector_repair_items_queued  
			or sector.sector_repair_items_queued and not prev.queued_items 
		then
			return true
		end
		if #(prev.queued_items or empty_table)~=#(sector.sector_repair_items_queued or empty_table) then
			return true
		end	
		for i, data in ipairs(prev.queued_items) do
			if not table.find(sector.sector_repair_items_queued, "id", data.id) then
				return true
			end	
		end
	end	
	-- trainig mercs stat
	if prev.training_stat~=sector.training_stat and operation_id == "TrainMercs" then
		return true
	end	
	return false
end

function SectorOperations_InterruptCurrent(sector, operation_id, reason)
	-- interrupt the last set
	local mercs = GetOperationProfessionals(sector.Id, operation_id)
	local costs = {}
	local costs = GatOperationCostsArray(sector.Id,SectorOperations[operation_id])
	RemoveTimelineEvent("activity-temp")
	--	id = "sector-activity-randr-"..ud.session_id
	for i, merc in ipairs(mercs) do
		local event_id =  GetOperationEventId(merc, operation_id)
		RemoveTimelineEvent(event_id)
		NetSyncEvent("RestoreOperationCost", merc.session_id, costs[i])
	end
	NetSyncEvent("InterruptSectorOperation", sector.Id,operation_id, reason)

	sector.operations_temp_data[operation_id] =  false
end

function SectorOperations_RestorePrev(host, sector, operation_id, prev_time)
	if not sector.operations_prev_data then return end
	
	if sector.operations_prev_data.operation_id~=operation_id then
		sector.operations_prev_data = false
		return
	end
	local prev_op = prev_time
	local temp = table.copy(sector.operations_prev_data)
	
	if prev_op and operation_id=="TrainMercs" then
		sector.training_stat = sector.operations_prev_data.training_stat
	end
		-- restore prev activity
	for m_id, merc_data in pairs(temp) do
		if SectorOperations_IsValidMercId(m_id) then
			for i,tt_merc_prof in ipairs(merc_data) do 
				table.remove(tt_merc_prof,3) -- remove cost
				local unit_data = gv_UnitData[m_id]
				if merc_data[1].prev_Operation=="Idle" then
					NetSyncEvent("MercSetOperationIdle",m_id,merc_data[1].Tiredness,merc_data[1].RestTimer, merc_data[1].TravelTime, merc_data[1].TravelTimerStart	)					
				elseif prev_op then	
					TryMercsSetOperation(host, {unit_data}, table.unpack(tt_merc_prof))				
				end
			end
		end
	end
	if prev_op and IsCraftOperation(operation_id) then
		if operation_id==temp.operation_id then
			NetSyncEvent("SectorOperationItemsUpdateLists", sector.Id, operation_id, TableWithItemsToNet(temp and temp.all_items),  TableWithItemsToNet(temp and temp.queued_items))
		end
	end	-- not sync.. maybe works cuz game is paused
	local time = temp.prev_start_time or prev_time or Game.CampaignTime
	if prev_op and sector.started_operations and sector.started_operations[operation_id] then
		sector.started_operations[operation_id]= time 
	end
		
	sector.operations_prev_data = false
	if prev_op then
		NetSyncEvent("StartOperation", sector.Id, operation_id, time,sector.training_stat)
	end
end

function SavegameSessionDataFixups.SectorActivityRenameToOperations(data, meta)
	if meta and meta.lua_revision > 330550 then return end
	for id, sector in pairs(data.gvars.gv_Sectors) do
		local started = rawget(sector,"started_activities")
		if started then
			rawset(sector,"started_activities", nil)
			sector.started_operations = started			
		end
		local custom = rawget(sector,"custom_activities")
		if custom then
			rawset(sector,"custom_activities", nil)
			sector.custom_operations = custom
		end
	end
	for _, data in ipairs(data.gvars.gv_Timeline) do
		local context = data.context
		if data.typ=="activity" and context.activityId then
			context.operationId = context.activityId
			context.activityId = nil
			data.typ = "operation"
		end
	end
	for session_id, unit_data in pairs(data.gvars.gv_UnitData) do
		if IsMerc(unit_data) then
			local unit = g_Units[session_id]
			local activity = rawget(unit_data,"Activity")
			if activity then
				unit_data.Operation = activity
				unit_data.Activity = nil
				if unit then 	
					unit.Operation = activity
					unit.Activity = nil
				end	
			end
			local eta = rawget(unit_data,"ActivityInitialETA")
			if eta then
				unit_data.OperationInitialETA = eta
				unit_data.ActivityInitialETA = nil
				if unit then 	
					unit.OperationInitialETA = eta
					unit.ActivityInitialETA = nil
				end	
			end
			local prof = rawget(unit_data,"ActivityProfession")
			if prof then
				unit_data.OperationProfession = prof
				unit_data.ActivityProfession = nil
				if unit then 	
					unit.OperationProfession = prof
					unit.ActivityProfession = nil
				end	
			end
			local profs = rawget(unit_data,"ActivityProfessions")
			if profs then
				unit_data.OperationProfessions = profs
				unit_data.ActivityProfessions  = nil
				if unit then 	
					unit.OperationProfessions = profs
					unit.ActivityProfessions  = nil
				end	
			end
		end	
	end
end
