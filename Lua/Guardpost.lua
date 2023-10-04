DefineClass.GuardpostSessionObject = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "SectorId", editor = "text", default = "", },
		{ id = "target_sector_id", editor = "text", default = false },
		{ id = "effect_target_sector_ids", editor = "prop_table", default = false },
		{ id = "next_spawn_time", editor = "number", default = false },
		{ id = "next_spawn_time_duration", editor = "number", default = false },
		{ id = "last_squad_attacked", editor = "text", default = "" },
		{ id = "primed_squad", editor = "text", default = false },
		{ id = "custom_quest_id", editor = "text", default = false},
		{ id = "on_reach_quest", editor = "text", default = false},
		{ id = "on_reach_var", editor = "text", default = false},
		{ id = "forced_attack", editor = "text", default = false},
		
		{ id = "queued_script_attack", editor = "prop_table", default = false},
	},
}

-- specifically used for Trigger Attack effects, to check the spawned squads
GameVar("gv_CustomQuestIdToSquadId", {})

DefineClass.Guardpost = {
	__parents = { "Object" },
	session_obj = false,
}

function Guardpost:AttackWithEnemySquad(targetSectorId, promoteToStrong)
	local so = self.session_obj
	
	local sectorId = so.SectorId
	local sector = gv_Sectors[sectorId] 
	
	-- If starting an attack and the guardpost is in conflict,
	-- this means time is flowing so the conflict is a waiting conflict,
	-- in which case turn it into a non-waiting conflict.
	local conflict = GetSectorConflict(sectorId)
	if conflict then
		if conflict.waiting then
			EnterConflict(sector)
		else
			assert(not conflict)
		end
	end
	
	targetSectorId = targetSectorId or so.target_sector_id
	if not targetSectorId then return end
	
	local primedSquad = so.primed_squad
	if not primedSquad then return end
	
	local squadObj = gv_Squads[primedSquad]
	if not squadObj then
		so.primed_squad = false
		return
	end
	
	-- Promote the primed extra defenders squad to an attack squad
	local squadList
	if promoteToStrong then
		squadList = sector.StrongEnemySquadsList
	else
		squadList = sector.EnemySquadsList
	end
	if squadList and #squadList > 0 then
		local squadPresetId = table.interaction_rand(squadList, "GuardpostPromote")
		local squad_id = GenerateEnemySquad(squadPresetId, sectorId, "Guardpost")
		
		procall(RemoveSquad, squadObj)
		squadObj = gv_Squads[squad_id]
		so.primed_squad = squad_id
	end

	SendSatelliteSquadOnRoute(squadObj, targetSectorId, { enemy_guardpost = true })
	so.last_squad_attacked = primedSquad
	so.next_spawn_time = false
	so.primed_squad = false
	so.forced_attack = false
end

function Guardpost:ForceSetNextSpawnTimeAndSector(time, sector_ids, custom_quest_id, on_reach_quest, on_reach_var)
	local so = self.session_obj

	-- Allow only up to one attack a time. Queue script based attacks.
	if not self:CanSpawnNewSquad() then
		local attack = {
			time,
			sector_ids,
			custom_quest_id,
			on_reach_quest,
			on_reach_var
		}
		if not so.queued_script_attack then so.queued_script_attack = {} end
		so.queued_script_attack[#so.queued_script_attack + 1] = attack
		return
	end
	
	if gv_LastSectorTakenByPlayer then
		table.replace(sector_ids, "last captured", gv_LastSectorTakenByPlayer)
	end
	so.effect_target_sector_ids = sector_ids
	so.target_sector_id = table.interaction_rand(self:GetAvailableTargetSectors(), "ForceAttackGuardpost")
	so.next_spawn_time = Game.CampaignTime + time
	so.next_spawn_time_duration = time
	so.custom_quest_id = custom_quest_id
	so.on_reach_quest = on_reach_quest
	so.on_reach_var = on_reach_var
	so.forced_attack = true
end

function Guardpost:GetAvailableTargetSectors()
	local sectors = {}
	for _, s_id in ipairs(self.session_obj.effect_target_sector_ids or empty_table) do -- try sectors specified in trigger attack effect
		local s = gv_Sectors[s_id]
		if s.Side == "player1" or s.Side == "player2" then
			table.insert(sectors, s_id)
		end
	end
	if not next(sectors) then
		local sector = gv_Sectors[self.session_obj.SectorId]
		for _, s_id in ipairs(sector.TargetSectors or empty_table) do
			local s = gv_Sectors[s_id]
			if s.Side == "player1" or s.Side == "player2" then
				table.insert(sectors, s_id)
			end
		end
	end
	return sectors
end

function Guardpost:CanSpawnNewSquad()
	local so = self.session_obj
	
	-- Squad ready to attack
	if so.primed_squad then
		return false
	end
	
	-- Dont spawn another squad if the last attack squad is alive and enroute.
	if so.last_squad_attacked then
		local lastAttackSquad = gv_Squads[so.last_squad_attacked]
		if IsSquadTravelling(lastAttackSquad, "skip_tick_pass") then
			return
		end
	end
	
	-- Check for queued attack
	if so.queued_script_attack and #so.queued_script_attack > 0 then
		local topAttack = table.remove(so.queued_script_attack, #so.queued_script_attack)
		self:ForceSetNextSpawnTimeAndSector(table.unpack(topAttack))
		return
	end
	
	return true
end

function Guardpost:UpdateNextAttackTime(initial)
	if not self:CanSpawnNewSquad() then
		return
	end

	local so = self.session_obj
	local sector = gv_Sectors[so.SectorId]
	local time_to_add = initial and 0 or sector.PatrolRespawnTime
	so.next_spawn_time = Game.CampaignTime + time_to_add
	so.next_spawn_time_duration = time_to_add

	ObjModified(sector)
end

function Guardpost:SpawnEnemySquad()
	local so = self.session_obj
	local sector = gv_Sectors[so.SectorId]
	if sector.Side == "player1" or sector.Side == "player2" then
		return
	end
	
	assert(not self.primed_squad)
	if self.primed_squad then
		return
	end
	
	local squadToSpawn = table.interaction_rand(sector.ExtraDefenderSquads or {}, "Guardpost")
	local squad_id = GenerateEnemySquad(squadToSpawn, so.SectorId, "Guardpost")
	if not squad_id then -- Couldn't spawn?
		return
	end
	
	if so.custom_quest_id then
		gv_CustomQuestIdToSquadId[so.custom_quest_id] = squad_id
		so.custom_quest_id = false
	end

	local squad = gv_Squads[squad_id]
	squad.on_reach_quest = so.on_reach_quest or false
	squad.on_reach_var = so.on_reach_var or false
	so.primed_squad = squad_id
	Msg("GuardpostAttackPrepared", so)
end

function Guardpost:Update(initial)
	local so = self.session_obj
	local sector = gv_Sectors[so.SectorId]
	if sector.Side == "player1" or sector.Side == "player2" then return end
	
	if so.forced_attack then
		-- If no queued spawn, then try to queue one.
		if not so.next_spawn_time then self:UpdateNextAttackTime(initial) end
		if not so.next_spawn_time then return end
	
		-- If less than 24 hours to attack and no primed squad, create it.
		-- It will automatically attack in a day.
		if so.next_spawn_time - const.Scale.day <= Game.CampaignTime and not so.primed_squad then
			self:SpawnEnemySquad()
		end
	
		if so.next_spawn_time <= Game.CampaignTime then
			self:AttackWithEnemySquad()
			Msg("GuardpostAttack", self)
		end
	else
		-- Dont spawn extra defenders while attacks are halted.
		if gv_SatelliteAttacksHalted then
			so.next_spawn_time = false
			return
		end
	
		-- If no queued spawn, then try to queue one.
		if not so.next_spawn_time then self:UpdateNextAttackTime(initial) end
		if not so.next_spawn_time then return end
	
		-- If spawn time passed and there is no primed squad, spawn it.
		-- Aggro system will promote it to attack when it deems appropriate.
		if so.next_spawn_time <= Game.CampaignTime and not so.primed_squad then
			self:SpawnEnemySquad()
			so.next_spawn_time = false
		end
	end
end

function OnMsg.SatelliteTick(tick, ticks_per_day)
	for _, gp in sorted_pairs(g_Guardposts) do
		gp:Update()
	end
end

MapVar("g_Guardposts", {})

function OnMsg.LoadSessionData()
	if not gv_SatelliteView then return end
	g_Guardposts = {}
	for _, guardpost_obj in ipairs(GetGuardpostSessionObjs()) do
		-- Savegame fixup 190010
		if IsT(guardpost_obj.queued_script_attack) then
			guardpost_obj.queued_script_attack = guardpost_obj.queued_script_attack[2]
		end
	
		g_Guardposts[guardpost_obj.SectorId] = PlaceObject("Guardpost", {session_obj = guardpost_obj})
	end
end

function InitializeGuardposts() 
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.Guardpost then
			local init_session_obj = not sector.guardpost_obj
			if init_session_obj then
				sector.guardpost_obj = GuardpostSessionObject:new{ 
					SectorId = id,
				}
			end
			local gp = PlaceObject("Guardpost", {session_obj = sector.guardpost_obj})
			g_Guardposts[id] = gp
			if init_session_obj and sector.InitialSpawn then
				gp:Update("initial")
			end
		end
	end
end

OnMsg.InitSatelliteView = InitializeGuardposts

function MakeSectorGuardpost(sector_id)
	gv_Sectors[sector_id].Guardpost = true
	gv_Sectors[sector_id].ImpassableForEnemies = false
	InitializeGuardposts()
end

function SavegameSessionDataFixups.FixupGuardpostImpassable(data)
	local gvars = data.gvars
	local sectors = gvars and gvars.gv_Sectors
	
	for id, sect in pairs(sectors) do
		if sect.Guardpost then
			sect.ImpassableForEnemies = false
		end
	end
end

function OnMsg.InitSessionCampaignObjects()
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.InitialSquads then
			for i, s in ipairs(sector.InitialSquads) do
				GenerateEnemySquad(s, id, "InitialSquad" .. tostring(i))
			end
			sector.InitialSquads = false
		end
	end
end

function GenerateUnitsFromTemplates(sector_id, unit_template_ids, base_session_id, new_unit_names, new_unit_appearance)
	local units = {}
	for i, unit_id in ipairs(unit_template_ids) do
		local session_id = GenerateUniqueUnitDataId(base_session_id, sector_id, unit_id)
		local unit_data = CreateUnitData(unit_id, session_id, InteractionRand(nil, "Satellite"))
		if new_unit_names and new_unit_names[i] then
			unit_data.Name = new_unit_names[i]
		end
		if new_unit_appearance and new_unit_appearance[i] then
			local appearanceOverrideDef = new_unit_appearance[i]
			local overrideDef = UnitDataDefs[appearanceOverrideDef]
			if overrideDef then
				unit_data.Portrait = overrideDef.Portrait
				unit_data.gender = overrideDef.gender
				unit_data.BigPortrait = overrideDef.BigPortrait
				
				local firstAppearance = overrideDef.AppearancesList and overrideDef.AppearancesList[1]
				if firstAppearance then
					unit_data.ForcedAppearance = firstAppearance.Preset
				end
			end
		end
		units[#units + 1] = session_id
	end
	return units
end

function GenerateRandEnemySquadUnits(enemy_squad_id)
	local unit_template_ids = {}
	local new_names = {}
	local override_visual = {}
	local unit_gen_sources = {}
	local enemy_squad_def = enemy_squad_id and EnemySquadDefs[enemy_squad_id]
	if enemy_squad_def then
		for idx, unit in ipairs(enemy_squad_def.Units) do
			-- Remove units whose conditions dont pass
			local copied = false
			local weightList = unit.weightedList
			for i, potentialUnit in ipairs(unit.weightedList) do
				if potentialUnit.conditions then
					if not copied then
						weightList = table.copy(weightList)
						copied = true
					end
					
					local consider = true
					for _, cond in ipairs(potentialUnit.conditions) do
						if not cond:Evaluate(potentialUnit, unit) then
							consider = false
							break
						end
					end

					if not consider then
						table.remove_value(weightList, potentialUnit)
					end
				end
			end
			if #weightList ~= 0 then
				local pickedUnit = #weightList == 1 and weightList[1] or table.weighted_rand(weightList, "spawnWeight", InteractionRand(nil, "Satellite"))
				local count = InteractionRandRange(unit.UnitCountMin, unit.UnitCountMax, "Satellite")
				for i = 1, count do
					if pickedUnit.unitType ~= "empty" then
						unit_template_ids[#unit_template_ids + 1] = pickedUnit.unitType 
						new_names[#new_names + 1] = pickedUnit.nameOverride
						override_visual[#override_visual + 1] = pickedUnit.visualOverride
						unit_gen_sources[#unit_gen_sources + 1] = idx
					end
				end
			end
		end
	end
	return unit_template_ids, new_names, unit_gen_sources, override_visual
end

function GenerateEnemySquad(enemy_squad_id, sector_id, base_session_id, unit_template_ids, side, militiaTest)
	local enemy_squad_def = enemy_squad_id and EnemySquadDefs[enemy_squad_id]
	if not enemy_squad_def then
		return
	end
	
	local generated_unit_ids, generated_unit_names, generated_sources, generated_appearances = false, false, false, false
	if not unit_template_ids then
		generated_unit_ids, generated_unit_names, generated_sources, generated_appearances = GenerateRandEnemySquadUnits(enemy_squad_id)
	else
		generated_unit_ids = unit_template_ids
	end
	
	local units = GenerateUnitsFromTemplates(sector_id, generated_unit_ids, base_session_id, generated_unit_names, generated_appearances)
	local diamondBriefcase = false
	if enemy_squad_def.DiamondBriefcase and enemy_squad_def.DiamondBriefcaseCarrier then
		local carrierId = enemy_squad_def.DiamondBriefcaseCarrier
		local carrier = false
		for i, defSource in ipairs(generated_sources) do
			if defSource == carrierId then
				carrier = units[i]
				break
			end
		end
		carrier = gv_UnitData[carrier]
		if carrier then
			local dbItem = PlaceInventoryItem("DiamondBriefcase")
			dbItem.drop_chance = 100
			carrier:AddItem("Inventory", dbItem)
			diamondBriefcase = true
		else
			print("Couldn't find diamond shipment carrier for enemy squad def", enemy_squad_id)
		end
	end
	
	side = side or "enemy1"
	local squad_id = CreateNewSatelliteSquad(
		{
			militia = militiaTest,
			Side = side,
			CurrentSector = sector_id,
			Name = enemy_squad_def.displayName and _InternalTranslate(enemy_squad_def.displayName) or SquadName:GetNewSquadName(side, units),
			diamond_briefcase = diamondBriefcase or nil,
			guardpost = base_session_id == "Guardpost"
		},
		units, nil, nil, enemy_squad_id
	)
	
	return squad_id
end

function GetEnemySquadsUnitTemplates(sector_id)
	local unit_template_ids = {}
	if sector_id == "all" then
		for id, enemy_squad_def in pairs(EnemySquadDefs) do
			for _, unit in ipairs(enemy_squad_def.Units) do
				for _, u in ipairs(unit.weightedList) do
					table.insert_unique(unit_template_ids, u.unitType)
				end
			end
		end
	else
		local squads = GetSectorSquadsFromSide(sector_id,"enemy1", "enemy2")
		for i, squad in ipairs(squads) do
			if not squad.villain then
				local enemy_squad_def = squad.enemy_squad_def and EnemySquadDefs[squad.enemy_squad_def]
				if enemy_squad_def then
					for _, unit in ipairs(enemy_squad_def.Units) do
						for _, u in ipairs(unit.weightedList) do
							table.insert_unique(unit_template_ids, u.unitType)
						end
					end
				end
			end
		end
	end
	return unit_template_ids
end

function GetGuardpostSessionObjs()
	local objs = {}
	for id, sector in sorted_pairs(gv_Sectors) do
		if sector.guardpost_obj then
			objs[#objs + 1] = sector.guardpost_obj
		end
	end
	return objs
end

DefineConstInt("Satellite", "GuardpostSquadWaitTimeOnWin", 86400, false, "How much time guardpost enemies wait in a sector after winning a conflict there (randomized by +/-25%)")

function OnMsg.ConflictEnd(sector)
	if sector.Side == "enemy1" or sector.Side == "enemy2" then
		local sector_id = sector.Id
		local _, enemy_squads = GetSquadsInSector(sector_id, "excludeTravelling")
		for _, squad in ipairs(enemy_squads) do
			if squad.guardpost then
				local rand = 25 - InteractionRand(50, "wait_on_win") -- randomize +/-25%
				SatelliteSquadWaitInSector(squad, Game.CampaignTime + MulDivRound(100 + rand, const.Satellite.GuardpostSquadWaitTimeOnWin, 100))
			end
		end
	end
end

function OnMsg.SquadFinishedTraveling(squad)
	local so = squad
	if so and so.on_reach_quest and so.on_reach_var then
		local quest = QuestGetState(so.on_reach_quest)
		if quest then
			for var_name in pairs(so.on_reach_var) do
				SetQuestVar(quest, var_name, true)
			end
		end
	end
end

function GetGuardpostRollover(sector)
	if sector.Side == "player1" or sector.Side == "ally" then
		return T(559546287840, "Outposts under player control uncover fog of war in adjacent sectors")
	end
	
	local descr = table.find_value(POIDescriptions, "id", "Guardpost")
	descr = descr.descr

	local guardpost_obj = sector.guardpost_obj
	local txt_sector_id = GetSectorName(gv_Sectors[guardpost_obj.target_sector_id])
	local time = guardpost_obj.next_spawn_time
	if not time then return descr end
	
	if time > Game.CampaignTime and (time - Game.CampaignTime) < const.Satellite.GuardPostShowTimer then
		return table.concat({descr, T{246250363097, "Intending to attack sector <sector_id> in <time>",sector_id = txt_sector_id,  time = FormatCampaignTime(time - Game.CampaignTime, true)}}, "\n\n")
	elseif time <= Game.CampaignTime and gv_Squads[guardpost_obj.last_squad_attacked] then
		return table.concat({descr, T{912634965094, "Attacking sector <sector_id>", sector_id = txt_sector_id}}, "\n\n")
	end
	
	return descr
end

GameVar("gv_GuardpostObjectiveState", function() return {} end)

local function lUpdateSatelliteUIGuardpostShields(sectorId)
	if not g_SatelliteUI or not g_SatelliteUI.sector_to_wnd then return end
	local sectorWnd = g_SatelliteUI.sector_to_wnd[sectorId]
	if not sectorWnd or not IsKindOf(sectorWnd.idPointOfInterest, "SatelliteSectorIconGuardpostClass") then return end
	if sectorWnd.window_state == "open" then
		sectorWnd.idPointOfInterest.idShieldContainer:RespawnContent()
	end
end

function SavegameSessionDataFixups.NoGuardpostObjectivesState(data)
	if not data.gvars.gv_GuardpostObjectiveState then
		data.gvars.gv_GuardpostObjectiveState = {}
	end
end

function SetGuardpostObjectiveFailed(objectiveId)
	local preset = GuardpostObjectives[objectiveId]
	if not preset then return false end
	
	local presetState = gv_GuardpostObjectiveState[objectiveId]
	if not presetState then
		presetState = {}
		gv_GuardpostObjectiveState[objectiveId] = presetState
	end
	
	presetState.failed = true
	presetState.visible = true
	lUpdateSatelliteUIGuardpostShields()
end

function SetGuardpostObjectiveCompleted(objectiveId)
	local preset = GuardpostObjectives[objectiveId]
	if not preset then return false end
	
	local presetState = gv_GuardpostObjectiveState[objectiveId]
	if not presetState then
		presetState = {}
		gv_GuardpostObjectiveState[objectiveId] = presetState
	end
	
	local sectorId = preset.Sector
	local sectorConquered = gv_GuardpostObjectiveState[sectorId .. "_Conquered"]
	if sectorConquered then
		assert(false) -- Completing guardpost objective on conquered sector
		return
	end
	
	local sectorDisabled = gv_GuardpostObjectiveState[sectorId .. "_Disabled"]
	if sectorDisabled then
		assert(false) -- Completing guardpost objective on disabled sector
		return
	end
	
	presetState.regenerate = false
	presetState.done = true
	presetState.applied = false
	EvalGuardpostObjectiveCompletions()
end

function SetGuardpostObjectiveRegenerated(objectiveId)
	local preset = GuardpostObjectives[objectiveId]
	if not preset then return false end
	
	local presetState = gv_GuardpostObjectiveState[objectiveId]
	if not presetState or not presetState.done then
		return
	end
	
	presetState.regenerate = true
	presetState.done = false
	presetState.applied = false
	EvalGuardpostObjectiveCompletions()
end

function SetGuardpostObjectiveSeen(objectiveId)
	local preset = GuardpostObjectives[objectiveId]
	if not preset then return false end
	
	local presetState = gv_GuardpostObjectiveState[objectiveId]
	if not presetState then
		presetState = {}
		gv_GuardpostObjectiveState[objectiveId] = presetState
	end
	
	presetState.visible = true
	lUpdateSatelliteUIGuardpostShields(preset.Sector)
end

function GetGuardpostObjectivesDoneCount(sector_id)
	local objectives = GetGuardpostStrength(sector_id)
	if not objectives then return 0, 0 end

	local doneCount, totalCount = 0, 0
	for i, obj in ipairs(objectives) do
		if not obj.extra then
			if obj.done then
				doneCount = doneCount + 1
			else
				totalCount = totalCount + 1
			end
		end
	end
	
	return doneCount, totalCount
end

function AllGuardpostObjectivesDone(sector_id)
	local done, total = GetGuardpostObjectivesDoneCount(sector_id)
	return done >= total
end

function IsGuardpostObjectiveDone(objectiveId)
	local preset = GuardpostObjectives[objectiveId]
	if not preset then return false end
	
	local sectorId = preset.Sector
	local sectorConquered = gv_GuardpostObjectiveState[sectorId .. "_Conquered"]
	if sectorConquered then return true end
	
	local sectorDisabled = gv_GuardpostObjectiveState[sectorId .. "_Disabled"]
	if sectorDisabled then return true end

	local state = gv_GuardpostObjectiveState[objectiveId]
	if not state then return false end

	if state.failed then return true end

	return not not state.done
end

function EvalGuardpostObjectiveCompletions()
	local checkSectors = false
	ForEachPreset("GuardpostObjective", function(obj)
		local state = gv_GuardpostObjectiveState[obj.id]
		if not state or state.applied then return end
		
		-- Don't apply objectives on the current sector, this can cause units to vanish.
		local sectorId = obj.Sector
		if sectorId == gv_CurrentSectorId and not ForceReloadSectorMap then return end
		
		-- Shields are only active the first time around. (except those that regenerate)
		local sectorConquered = gv_GuardpostObjectiveState[sectorId .. "_Conquered"]
		if sectorConquered and #(obj.OnRegenerate or empty_table) == 0 then return end

		if state.done then
			ExecuteEffectList(obj.OnComplete)
		elseif state.regenerate then
			ExecuteEffectList(obj.OnRegenerate)
		end
		state.applied = true
		
		if not checkSectors then checkSectors = {} end
		if not checkSectors[sectorId] then
			checkSectors[#checkSectors + 1] = sectorId
			checkSectors[sectorId] = obj.id
		end
	end)
	
	-- Check for all objectives in a sector being completed.
	for i, sectorId in ipairs(checkSectors) do
		Msg("GuardpostStrengthChangedIn", sectorId)
	
		local presetForSector = GuardpostObjectives[sectorId]
		if not presetForSector then goto continue end
		
		local stateForSector = gv_GuardpostObjectiveState[presetForSector.id]
		if stateForSector and stateForSector.applied then goto continue end
	
		local allCompleted = true
		ForEachPreset("GuardpostObjective", function(preset)
			if preset.Sector == sectorId then
				local state = gv_GuardpostObjectiveState[preset.id]
				if not state or not state.done then
					allCompleted = false
					return "break"
				end
			end
		end)
		
		if allCompleted then
			ExecuteEffectList(presetForSector.OnComplete)
			
			if not stateForSector then
				stateForSector = {}
				gv_GuardpostObjectiveState[presetForSector.id] = stateForSector
			end
			stateForSector.applied = true
			Msg("GuardpostAllShieldsDone", sectorId)
		end
		
		::continue::
	end
end

OnMsg.GuardpostStrengthChangedIn = lUpdateSatelliteUIGuardpostShields

function OnMsg.GuardpostAttackPrepared(guardpostObj)
	if not guardpostObj then return end
	lUpdateSatelliteUIGuardpostShields(guardpostObj.SectorId)
end

function OnMsg.GuardpostAttack(guardpostObj)
	if not guardpostObj or not guardpostObj.session_obj then return end
	lUpdateSatelliteUIGuardpostShields(guardpostObj.session_obj.SectorId)
end

function OnMsg.AllSectorsRevealed()
	for id, sector in pairs(gv_Sectors) do
		lUpdateSatelliteUIGuardpostShields(id)
	end
end

OnMsg.OpenSatelliteView = EvalGuardpostObjectiveCompletions
OnMsg.AutoResolvedConflict = EvalGuardpostObjectiveCompletions

function OnMsg.IntelDiscovered(sector_id)
	local sector = gv_Sectors[sector_id]
	if not sector or not sector.Guardpost then return end
	
	local updateUI = false
	ForEachPreset("GuardpostObjective", function(preset)
		if preset.Sector == sector_id then
			SetGuardpostObjectiveSeen(preset.id)
			updateUI = true
		end
	end)
	if updateUI then lUpdateSatelliteUIGuardpostShields(sector_id) end
end

-- Once a guardpost has been conquered once
function OnMsg.SectorSideChanged(sector_id)
	local sector = gv_Sectors[sector_id]
	if not sector or not sector.Guardpost then return end
	
	gv_GuardpostObjectiveState[sector_id .. "_Conquered"] = true
	local sessionObj = sector.guardpost_obj
	if not sessionObj then return end
	
	sessionObj.next_spawn_time = false
	sessionObj.next_spawn_time_duration = false
end

function GetGuardpostStrength(sector_id)
	local sector = gv_Sectors[sector_id]
	if not sector or not sector.Guardpost or sector.Side == "player1" then return end

	local guardpostObjectives = {}
	local sectorConquered = gv_GuardpostObjectiveState[sector_id .. "_Conquered"]
	local sectorDisabled = gv_GuardpostObjectiveState[sector_id .. "_Disabled"]
	
	if not sectorConquered and not sectorDisabled then -- Guardpost objectives are active only the first time around
		ForEachPreset("GuardpostObjective", function(preset)
			if preset.Sector == sector_id then
				local state = gv_GuardpostObjectiveState[preset.id] or empty_table;
				local description = false
				if state.failed then
					description = preset.DescriptionFailed
				elseif state.done then
					description = preset.DescriptionCompleted or preset.Description
				elseif state.visible then
					description = preset.Description
				else
					description = T(281496124870, "Perform <em>Scout</em> operations or explore sectors in tactical view to gain <em>Intel</em> on how to reduce the defense of this <em>Outpost</em> ")
				end
				guardpostObjectives[#guardpostObjectives + 1] = { Description = description, done = state.done }
			end
		end)
	end

	-- Add the extra objective for no primed squad.
	local guardpostObj = sector.guardpost_obj
	local preset = GuardpostObjectives.ReadyingAttack
	local hasPrimedSquad = guardpostObj and guardpostObj.primed_squad and gv_Squads[guardpostObj.primed_squad]
	local done = not guardpostObj or not hasPrimedSquad
	guardpostObjectives[#guardpostObjectives + 1] = { Description = done and preset.DescriptionCompleted or preset.Description, done = done, extra = true }

	return guardpostObjectives
end

-- Subtracts/Adds the units defined in a squad def from a sector.
-- Only units with 100% chance and no randomness will be removed.
function ModifySectorStrengthBySquadDef(sector_id, squad_def_id, addOrRemove)
	local sector = gv_Sectors[sector_id]
	assert(sector)
	local squadDef = EnemySquadDefs[squad_def_id]
	assert(squadDef)
	assert(addOrRemove == "add" or addOrRemove == "remove")
	
	for idx, unit in ipairs(squadDef.Units) do
		local weightList = unit.weightedList
		assert(unit.UnitCountMin == unit.UnitCountMax)
		for i, potentialUnit in ipairs(unit.weightedList) do
			ModifySectorEnemySquads(sector_id, addOrRemove == "add" and unit.UnitCountMin or -unit.UnitCountMin, "count", potentialUnit.unitType)
		end
	end
end

-- Patroling enemy squads
function PatrollingSquadSetDestination(squadId)
	local squad = gv_Squads[squadId]
	local enemySquadDef = EnemySquadDefs[squad.enemy_squad_def]
	if enemySquadDef and enemySquadDef.patrolling then
		local waypoints = table.icopy(enemySquadDef.waypoints)
		if waypoints and #waypoints > 0 then
			table.remove_value(waypoints, squad.CurrentSector)
			if #waypoints > 0 then
				local nextDest = InteractionRand(#waypoints, "PatrollingSquads") + 1
				nextDest = waypoints[nextDest]
			
				local route = GenerateRouteDijkstra(squad.CurrentSector, nextDest, false, squad.units, "land_water", nil, squad.Side)
				NetSyncEvent("AssignSatelliteSquadRoute", squadId, {route})
			end
		end
	end
end

function OnMsg.SquadSpawned(id, sectorId)
	PatrollingSquadSetDestination(id)
end

function OnMsg.SquadFinishedTraveling(squad)
	PatrollingSquadSetDestination(squad.UniqueId)
end

DefineConstInt("Satellite", "AggroPerTick", 200, false, "How much aggro is generated in the satellite view per tick.")
DefineConstInt("Satellite", "MaxAggroPerTick", 300, false, "The maximum aggro that can be added in one tick.")
DefineConstInt("Satellite", "AggroPerMine", 5, false, "Additional aggro to generate per mine owned each tick.")
DefineConstInt("Satellite", "AggroPerGuardpost", 5, false, "Additional aggro to generate per guardpost owned each tick.")
DefineConstInt("Satellite", "AggroPerCity", 5, false, "Additional aggro to generate per city owned each tick.")
DefineConstInt("Satellite", "AggroTickRandomMax", 300, false, "How much aggro is generated in the satellite view per tick (upper range for the random).")
DefineConstInt("Satellite", "AggroAttackThreshold", 3000, false, "How much aggro is needed for an attack.") -- Hard
DefineConstInt("Satellite", "AggroAttackThresholdHard", 2500, false, "How much aggro is needed for an attack.") -- Very Hard
DefineConstInt("Satellite", "AggroAttackThresholdNormal", 3500, false, "How much aggro is needed for an attack.") -- Normal

function GetAggroAttackThreshold()
	local difficulty = Game.game_difficulty
	if difficulty == "VeryHard" then
		return const.Satellite.AggroAttackThresholdHard
	elseif difficulty == "Hard" then
		return const.Satellite.AggroAttackThreshold
	end
	
	-- == "Normal"
	return const.Satellite.AggroAttackThresholdNormal
end

GameVar("gv_SatelliteAggro", 0)
GameVar("gv_SatelliteAttacksHalted", false)
GameVar("gv_SatelliteAttacksHaltedFor", false)

if FirstLoad then
gv_DebugShowSatelliteAggro = false
end
	
function ModifySatelliteAggression(val, isPercent)
	gv_SatelliteAggro = gv_SatelliteAggro or 0
	if isPercent then
		local amount = MulDivRound(gv_SatelliteAggro, val, 1000)
		val = amount
	end
	gv_SatelliteAggro = gv_SatelliteAggro + val
end

function GetSatelliteAggroTarget(excludeSectors, getCount)
	local sectorWeights = {}
	for i, s in sorted_pairs(gv_Sectors) do
		if s.Side == "player1" and (not excludeSectors or not table.find(excludeSectors, s)) then
			if s.Mine then
				sectorWeights[#sectorWeights + 1] = { 40, s }
			elseif s.Guardpost then
				sectorWeights[#sectorWeights + 1] = { 35, s }
			elseif s.City ~= "none" then
				sectorWeights[#sectorWeights + 1] = { 25, s }
			end
		end
	end	
	if getCount then return #sectorWeights end
	
	if #sectorWeights == 0 then return false end
	return GetWeightedRandom(sectorWeights, InteractionRand(nil, "SatelliteAggro"))
end

function SatelliteAggroInitiateAttack(dryRun)
	local attackTypeWeights = {
		{ attacks = 1, weight = 75 }, -- Easy
		{ attacks = 2, weight = 10 }, -- Medium
		{ attacks = 3, weight = 5 }, -- Hard
		{ attacks = 1, strong_attack = true, weight = 10 }, -- Strong squad attack
	}
	
	-- Checks which kind of attacks are possible
	local guardpostsReady = {}
	for _, gp in sorted_pairs(g_Guardposts) do
		if gp and gp.session_obj then
			local sessionObj = gp.session_obj
			-- Guardposts dont clear primed squad if taken over, so we need to check if the squad exists
			if gv_Squads[sessionObj.primed_squad] and not sessionObj.forced_attack and not IsConflictMode(sessionObj.SectorId) then
				guardpostsReady[#guardpostsReady + 1] = sessionObj
			end
		end
	end

	local playerTargets = GetSatelliteAggroTarget(false, "get-count")
	local possibleAttackTypes = {}
	for i, attackType in ipairs(attackTypeWeights) do
		if #guardpostsReady >= attackType.attacks and playerTargets >= attackType.attacks then
			possibleAttackTypes[#possibleAttackTypes + 1] = { attackType.weight, attackType }
		end
	end
	
	-- If no guardposts are ready or no player targets just spawn a diamond shipment
	if #possibleAttackTypes == 0 then
		if not dryRun then SpawnDynamicDBSquad() end
		return
	end

	-- Decide attack type and targets
	local attacksAgainst = {}
	local attackTypeRandomed = GetWeightedRandom(possibleAttackTypes, InteractionRand(nil, "SatelliteAggro"))
	local attackCount = attackTypeRandomed.attacks
	for i = 1, attackCount do
		local target = GetSatelliteAggroTarget(attacksAgainst)
		attacksAgainst[#attacksAgainst + 1] = target
	end
	
	CombatLog("debug", Untranslated("Satellite aggro attack type: " .. table.find(attackTypeWeights, attackTypeRandomed)))
	
	-- Decide attackers (closest guardpost) and send them
	local strongSquads = attackTypeRandomed.strong_attack
	local guardpostsAttacked = {}
	for i, target in ipairs(attacksAgainst) do
		local closestGuardpost = false
		local closestGuardpostDist = false
		for i, gp in ipairs(guardpostsReady) do
			if table.find(guardpostsAttacked, gp) then goto continue end
		
			 local distToTarget = GetSectorDistance(target.Id, gp.SectorId)
			 if not closestGuardpost or distToTarget < closestGuardpostDist then
				closestGuardpost = gp
				closestGuardpostDist = distToTarget
			 end
			 
			 ::continue::
		end

		assert(closestGuardpost)
		if closestGuardpost and not dryRun then
			local sectorId = closestGuardpost.SectorId
			local guardpostInst = g_Guardposts[sectorId]
			guardpostInst:AttackWithEnemySquad(target.Id, strongSquads)
			Msg("GuardpostAttack", guardpostInst)
			guardpostsAttacked[#guardpostsAttacked + 1] = closestGuardpost
		end
	end
end

function OnMsg.NewDay()
	if gv_SatelliteAttacksHaltedFor and type(gv_SatelliteAttacksHaltedFor) == "number" then
		gv_SatelliteAttacksHaltedFor = gv_SatelliteAttacksHaltedFor - 1
		if gv_SatelliteAttacksHaltedFor <= 0 then
			gv_SatelliteAttacksHalted = false
			gv_SatelliteAttacksHaltedFor = false
		end
	end
end

function OnMsg.NewHour()
	if gv_SatelliteAttacksHalted then return end

	local time = Game.CampaignTime
	local hours = Game.CampaignTime / const.Scale.h
	if hours % 7 ~= 0 then return end

	gv_SatelliteAggro = gv_SatelliteAggro or 0
	
	local mines = 0
	local guardposts = 0
	local cities = gv_PlayerCityCounts and gv_PlayerCityCounts.count
	for i, s in sorted_pairs(gv_Sectors) do
		if s.Side == "player1" then
			if s.Mine then
				mines = mines + 1
			elseif s.Guardpost then
				guardposts = guardposts + 1
			end
		end
	end
	local gainFromMines = const.Satellite.AggroPerMine * mines
	local gainFromGuardposts = const.Satellite.AggroPerGuardpost * guardposts
	local gainFromCities = const.Satellite.AggroPerCity * cities
	local randomGain = InteractionRand(const.Satellite.AggroTickRandomMax - const.Satellite.AggroPerTick, "SatelliteAggro")
	CombatLog("debug", Untranslated(string.format("Aggro M/G/C/R %d %d %d %d", gainFromMines, gainFromGuardposts, gainFromCities, randomGain)))

	local gainAmount = const.Satellite.AggroPerTick
	gainAmount = gainAmount + gainFromMines
	gainAmount = gainAmount + gainFromGuardposts
	gainAmount = gainAmount + gainFromCities
	gainAmount = gainAmount + randomGain
	
	gainAmount = Min(gainAmount, const.Satellite.MaxAggroPerTick)
	
	gv_SatelliteAggro = gv_SatelliteAggro + gainAmount
	if gv_SatelliteAggro > GetAggroAttackThreshold() then
		SatelliteAggroInitiateAttack()
		gv_SatelliteAggro = 0
	end
end