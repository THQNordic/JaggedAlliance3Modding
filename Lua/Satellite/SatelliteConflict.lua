if FirstLoad then
	g_ConflictSectors = false
end

function OnMsg.PreLoadSessionData()
	g_ConflictSectors = {}
	for id, sector in pairs(gv_Sectors) do
		if sector.conflict then
			g_ConflictSectors[#g_ConflictSectors + 1] = id
		end
	end
	table.sort(g_ConflictSectors)
end

function OnMsg.NewGame(game)
	g_ConflictSectors = {}
end

function IsConflictMode(sector_id)
	if sector_id then
		return not not table.find(g_ConflictSectors, sector_id), gv_Sectors[sector_id]
	else
		return #g_ConflictSectors > 0, gv_Sectors[g_ConflictSectors[1]]
	end
end

function AnyNonWaitingConflict()
	for i, sectorId in ipairs(g_ConflictSectors) do
		local sector = gv_Sectors[sectorId]
		if not sector.conflict.waiting then
			return sector
		end
	end
	return false
end

function GetConflictCustomDescr(sector)
	if not sector then return end

	local conflict = sector.conflict
	local preset = conflict and ConflictDescriptionDefs[conflict.descr_id or false]
	local custom = preset and preset.description
	if custom then return custom end
	
	if conflict and conflict.spawn_mode == "defend" then
		return T{129191214872, ConflictDescriptionDefs.DefaultDefend.description, sector} 
	else
		return T{292704915698, ConflictDescriptionDefs.DefaultAttack.description, sector} 
	end
end

function GetConflictCustomTitle(sector)
	if not sector then return end

	local conflict = sector.conflict
	local preset = conflict and ConflictDescriptionDefs[conflict.descr_id or false]
	local custom = preset and preset.title
	if custom then return custom end
	
	return T(829620197199, "ENEMY PRESENCE")
end

TFormat.SectorConflictCustomDescr = GetConflictCustomDescr
TFormat.GetConflictCustomTitle = GetConflictCustomTitle

function SatelliteRetreat(sector_id, sides_to_retreat)
	NetUpdateHash("SatelliteRetreat", sector_id)
	local sector = gv_Sectors[sector_id]
	if not sector.conflict then return end

	sides_to_retreat = sides_to_retreat or {"player1"}
	
	local previousSector = false
	local squadsToRetreat = {}
	for i, squad in ipairs(g_SquadsArray) do
		if squad.militia then goto continue end
		if squad.CurrentSector ~= sector_id then goto continue end
		if not IsSquadInConflict(squad) then goto continue end
		if not table.find(sides_to_retreat, squad.Side) then goto continue end
		
		squadsToRetreat[#squadsToRetreat + 1] = squad
		
		-- How?!?
		if squad.PreviousSector == sector_id then
			squad.PreviousSector = false
		end
		
		if squad.PreviousSector then
			previousSector = squad.PreviousSector
		end
		
		::continue::
	end
	
	-- Make sure all squads have a previous sector (inherit from other squads here)
	-- If none of them have one auto resolve shouldn't have been allowed in the first place.
	-- See IsAutoResolveEnabled
	if previousSector then
		for i, squad in ipairs(squadsToRetreat) do
			if not squad.PreviousSector then
				squad.PreviousSector = previousSector
			end
		end
	end
	
	for i, squad in ipairs(squadsToRetreat) do
		local prev_sector_id = (sector.conflict.player_attacking and sector.conflict.prev_sector_id) or squad.PreviousSector
		if IsWaterSector(prev_sector_id) and squad.PreviousLandSector then
			prev_sector_id = squad.PreviousLandSector
		end
		if not prev_sector_id then goto continue end
		
		if IsSectorUnderground(sector_id) or IsSectorUnderground(prev_sector_id) then
			SetSatelliteSquadCurrentSector(squad, prev_sector_id)
		else
			-- Find best retreat sector if previous sector is a bad idea.
			local badRetreat = false
			local otherSideSquads = (squad.Side == "enemy1" or squad.Side == "enemy2") and g_PlayerAndMilitiaSquads or g_EnemySquads
			-- Check if any of the other side squads on my sector are travelling towards the one I want to retreat to.
			for i, os in ipairs(otherSideSquads) do
				if os.CurrentSector == sector_id and os.route then
					local nextDest = os.route[1] and os.route[1][1]
					if nextDest == prev_sector_id then
						badRetreat = true
						break
					end
				end
			end
			
			-- Check if retreating into water.
			local prevSector = gv_Sectors[prev_sector_id]
			local illegalRetreat = prevSector.Passability == "Water" or prevSector.Passability == "Blocked"
			badRetreat = badRetreat or illegalRetreat
			
			-- Check if retreating into enemies.
			if not badRetreat then badRetreat = not not table.find(otherSideSquads, "CurrentSector", prev_sector_id) end
			-- Try to find a better retreat position, such as one without other side squads.
			if badRetreat then
				local illegalRetreatFallback, foundSector = false, false
				ForEachSectorCardinal(sector_id, function(otherSecId)
					local considerThisSector = false
					local otherSec = gv_Sectors[otherSecId]
					if SideIsAlly(otherSec.Side, squad.Side) then -- If my side, then there aren't any baddies there.
						considerThisSector = true
					elseif not table.find(otherSideSquads, "CurrentSector", otherSecId) then
						considerThisSector = true
					end

					local forbiddenRoute = IsRouteForbidden({{otherSecId}}, squad)
				
					-- If illegal retreat consider the first non-forbidden route sector, regardless of the
					-- "other-side" conditions above.
					if illegalRetreat and not illegalRetreatFallback and not forbiddenRoute then
						illegalRetreatFallback = otherSecId
					end

					if considerThisSector and not forbiddenRoute then
						foundSector = true
						prev_sector_id = otherSecId
						return "break"
					end
				end)
				
				if illegalRetreat and not foundSector and illegalRetreatFallback then
					prev_sector_id = illegalRetreatFallback
				end
			end
			
			local retreatRoute = GenerateRouteDijkstra(squad.CurrentSector, prev_sector_id, false, squad.units, "retreat", squad.CurrentSector, squad.side)
			if not retreatRoute then 
				-- Ehh, what?
				assert(false) -- Retreat route is invalid
				retreatRoute = { prev_sector_id } -- Fallback to just get out of this sector.
			end
			
			-- Try to retain the joining squad if it will retreat in the same direction it was going anyway
			local keepJoining = false
			if squad.joining_squad then
				local squadToJoin = gv_Squads[squad.joining_squad]
				keepJoining = squadToJoin and squadToJoin.CurrentSector == prev_sector_id
			end

			SetSatelliteSquadRetreatRoute(squad, { retreatRoute }, keepJoining)
		end
		
		::continue::
	end
	
	ResolveConflict(sector, "no voice", false, "retreat")
	ResumeCampaignTime("UI")
end

function NetSyncEvents.UISatelliteRetreat(sector_id, sides_to_retreat)
	SatelliteRetreat(sector_id, sides_to_retreat)
	local satCon = GetDialog("SatelliteConflict")
	if satCon then CloseDialog("SatelliteConflict") end	
end

GameVar("ForceReloadSectorMap", false)

function EnterConflict(sector, prev_sector_id, spawn_mode, disable_travel, locked, descr_id, force, from_map)
	-- Forced conflicts are resolved via quest events and such,
	sector = sector or gv_Sectors[gv_CurrentSectorId]
	local sector_id = sector and sector.Id
	if not sector then return end
	
	-- Separate enemy attack from player attack to set player_attacking
	local playerInvading = spawn_mode == "attack"
	if spawn_mode == "enemy_attack" then
		spawn_mode = "attack"
	end

	-- Already in conflict, and waiting
	if IsConflictMode(sector_id) then
		if locked ~= nil then sector.conflict.locked = locked end
		if locked ~= nil then sector.conflict.descr_id = descr_id end
		if disable_travel ~= nil then sector.conflict.disable_travel = disable_travel end
		
		--sector.conflict.spawn_mode = spawn_mode or sector.conflict.spawn_mode
		sector.conflict.prev_sector_id = prev_sector_id or sector.conflict.prev_sector_id
		if sector.conflict.waiting then
			sector.conflict.player_attacking = playerInvading
			sector.conflict.waiting = playerInvading or EnemyWantsToWait(sector_id)
			
			if sector.conflict.waiting then
				ResumeCampaignTime("SatelliteConflict")
			else
				PauseCampaignTime("SatelliteConflict")
			end
			
			if gv_SatelliteView then
				ObjModified(SelectedObj)
				ObjModified(Game)
				OpenSatelliteConflictDlg(sector)
				RequestAutosave{ autosave_id = "satelliteConflict", save_state = "CombatStart", display_name = T{285747878633, "Satellite_Conflict_<u(sector)>", sector = sector.name}, mode = "delayed" }
			end
		end
		return
	end
	
	local no_exploration_resolve = false
	if force == "force-exploration-only" then
		no_exploration_resolve = true
	elseif force then
		sector.ForceConflict = true
	end
	table.insert(g_ConflictSectors, sector_id)
	table.sort(g_ConflictSectors)
	sector.conflict = {
		prev_sector_id = prev_sector_id or nil,
		spawn_mode = spawn_mode or nil,
		player_attacking = playerInvading,
		disable_travel = disable_travel or nil,
		locked = locked,
		descr_id = descr_id or sector.CustomConflictDescr or (not playerInvading and "SectorAttacked"),
		waiting = playerInvading or EnemyWantsToWait(sector_id),
		from_map = from_map,
		no_exploration_resolve = no_exploration_resolve
	}
	if InteractionSeeds then
		local prediction, player_power, enemy_power = GetAutoResolveOutcome(sector)
		sector.conflict.predicted_autoresolve = prediction
		sector.conflict.player_power = player_power
		sector.conflict.enemy_power = enemy_power
	end
	
	-- Check if we gameovered in a conflict here then copy special properties.
	if sector.conflict_backup then
		local backupConflict = sector.conflict_backup
		local newConflict = sector.conflict
		
		newConflict.locked = backupConflict.locked
		newConflict.disable_travel = backupConflict.disable_travel
		newConflict.descr_id = backupConflict.descr_id
		newConflict.initial_sector = backupConflict.initial_sector

		sector.conflict_backup = false
	end

	Msg("ConflictStart", sector_id)

	local squads = GetSquadsInSectorCombined(sector_id, false, true)
	for i, squad in ipairs(squads) do
		SatelliteSquadWaitInSector(squad, false)
		if squad.route then squad.route.satellite_tick_passed = false end
		ObjModified(squad)
	end
	
	if gv_SatelliteView then
		OpenSatelliteConflictDlg(sector, "auto-open")
		RequestAutosave{ autosave_id = "satelliteConflict", save_state = "CombatStart", display_name = T{285747878633, "Satellite_Conflict_<u(sector)>", sector = sector.name}, mode = "delayed" }
		if spawn_mode and sector_id == gv_CurrentSectorId then -- if an enemy squad attacks the squad on the current sector, reload sector map
			ForceReloadSectorMap = true
			ObjModified("gv_SatelliteView")
		end
		ObjModified(gv_Squads)
	end

	if not sector.conflict.waiting then PauseCampaignTime("SatelliteConflict") end
	UpdateEntranceAreasVisibility()
	ObjModified(SelectedObj)
	ObjModified(Game)
	
	ExecuteSectorEvents("SE_OnConflictStarted", sector_id)
end

function EnemyWantsToWait(sector)
	local enemySquadsEnroute = GetSquadsEnroute(sector, "enemy1")
	if #enemySquadsEnroute == 0 then return false end

	local waitTime = const.Satellite.EnemySquadWaitTime
	for i, s in ipairs(enemySquadsEnroute) do
		local estimatedTravelTime = GetTotalRouteTravelTime(s.CurrentSector, s.route, s)
		if estimatedTravelTime < waitTime then
			return true
		end
	end
	return false
end

function CanGoInMap(sector)
	sector = gv_Sectors[sector]
	if not sector.Map then return false end
	if not sector.conflict then return true end
	if not sector.conflict.waiting then return true end

	if sector.conflict.waiting then
		if sector.conflict.player_attacking then
			return true
		end
		return false, "enemy waiting"
	end

	return false
end

local function lTravellingTowardsSectorCenter(sq, sector_id)
	return sq.route and sq.route[1] and #sq.route[1] > 0 and sq.route[1][1] == sector_id
end

-- return value is from player perspective
function GetConflictSide(squad, sector_id)
	local player_squad = squad.Side == "player1" or squad.Side == "player2"
	local owningSide = gv_Sectors[sector_id].Side
	local sectorOwnedByPlayer = owningSide == "player1" or owningSide == "player2" or owningSide == "ally"

	if player_squad and not sectorOwnedByPlayer then
		return "attack"
	elseif not player_squad and not sectorOwnedByPlayer then
		-- the player is attacking, but an enemy reinforcement has arrived
		return "enemy_attack" 
	end

	return "defend"
end

local function lGetSquadsForConflict(squad)
	local sector_id = squad.CurrentSector
	local sector = gv_Sectors[sector_id]
	local allySquads, enemySquads = GetSquadsInSector(sector_id, false, true, true)
	-- note: retreating squads are filtered below conditionally
	
	-- Filter out neutral squads
	local enemiesForReal = {}
	for i, s in ipairs(enemySquads) do
		if s.Side == "enemy1" or s.Side == "enemy2" then
			enemiesForReal[#enemiesForReal + 1] = s
		end
	end
	enemySquads = enemiesForReal
	
	if #allySquads > 0 and #enemySquads > 0 then
		local travellingPlayer = false
		local travellingEnemy = false
		local nonTravellingPlayer = false
		local nonTravellingEnemy = false
		
		local nonRetreatingAlly = {}
		local nonRetreatingEnemy = {}
		for i, squad in ipairs(allySquads) do
			if (not squad.Retreat or SquadReachedDest(squad)) and not IsTraversingShortcut(squad) then
				nonRetreatingAlly[#nonRetreatingAlly + 1] = squad
			end
		end
		for i, squad in ipairs(enemySquads) do
			if (not squad.Retreat or SquadReachedDest(squad)) and not IsTraversingShortcut(squad) then
				nonRetreatingEnemy[#nonRetreatingEnemy + 1] = squad
			end
		end
		
		for i, squad in ipairs(nonRetreatingAlly) do
			local travelling = not IsSquadInSectorVisually(squad, sector_id)
			if travelling then
				travellingPlayer = true
			else
				nonTravellingPlayer = true
			end
		end
	
		for i, squad in ipairs(nonRetreatingEnemy) do
			local travelling = not IsSquadInSectorVisually(squad, sector_id)
			if travelling then
				travellingEnemy = true
			else
				nonTravellingEnemy = true
			end
		end
		
		local bothSidesTraveling = travellingEnemy and travellingPlayer
		local bothSidesInCenter = nonTravellingPlayer and nonTravellingEnemy
		local conflictWillHappen = bothSidesTraveling or bothSidesInCenter
		
		-- If there is an existing conflict (a waiting conflict) retriggering it will end the wait,
		-- however we want that to happen only when a squad reaches the center.
		-- To avoid teleporting squads traveling towards that waiting conflict as soon as
		-- they pass the sector boundary we need the check below.
		--
		-- Note that squads that are past the sector boundary will all get teleported into the conflict
		-- regardless whether the conflict produced will be waiting and they are travelling towards it.
		if sector.conflict then
			conflictWillHappen = conflictWillHappen and IsSquadInSectorVisually(squad, sector_id)
		end
	
		return conflictWillHappen, nonRetreatingAlly, nonRetreatingEnemy
	end
end

function CheckAndEnterConflict(sector, squad, prev_sector_id)
	local sector_id = sector.Id
	
	local conflictSide = GetConflictSide(squad, sector_id)
	if sector.Passability ~= "Water" then
		local conflictStart, playerSquads, enemySquads = lGetSquadsForConflict(squad)
		if conflictStart then
			-- Teleport all travelling squads to the sector center
			for i = 1, #playerSquads + #enemySquads do
				local squad = i <= #playerSquads and playerSquads[i] or enemySquads[i - #playerSquads]
				if IsSquadTravelling(squad) then
					-- Reset travel status to as if plotting a route from conflict.
					squad.route.satellite_tick_passed = false
					
					local movingToConflict = lTravellingTowardsSectorCenter(squad, sector_id)
					SatelliteReachSectorCenter(squad.UniqueId, sector_id, prev_sector_id, not movingToConflict, true)
				end
			end
			EnterConflict(sector, prev_sector_id, conflictSide)
		end
	end
	
	return conflictSide
end

-- Similar code to above but used for SectorEnterConflict effect.
-- The squads returned are the same as the ones returned from PlayerPresentInSector
-- as the two effects are often used together
function ForceEnterConflictEffect(sector, ...)
	local sector_id = sector.Id
	local playerSquads, enemySquads = GetSquadsInSector(sector_id, false, false, true)
	
	-- Dont allow even a forced conflict in this case as it will break the game.
	if #playerSquads == 0 then return end
	
	-- Teleport all travelling squads to the sector center
	for i = 1, #playerSquads + #enemySquads do
		local squad = i <= #playerSquads and playerSquads[i] or enemySquads[i - #playerSquads]
		if IsSquadTravelling(squad) then
			-- Reset travel status to as if plotting a route from conflict.
			squad.route.satellite_tick_passed = false
			
			local movingToConflict = lTravellingTowardsSectorCenter(squad, sector_id)
			SatelliteReachSectorCenter(squad.UniqueId, sector_id, squad.PreviousSector, not movingToConflict, true)
		end
	end
	EnterConflict(sector, nil, ...)
end

function OnMsg.EnterSector(gameStart, gameLoaded)
	if gameLoaded then return end -- Trust the saved ForceReloadSectorMap
	ForceReloadSectorMap = false
end

GameVar("SatQueuedResolveConflict", function() return {} end)

function OnMsg.StartSatelliteGameplay()
	if not SatQueuedResolveConflict or #SatQueuedResolveConflict == 0 then return end
	
	assert(g_SatelliteUI)
	for i, sId in ipairs(SatQueuedResolveConflict) do
		local sector = gv_Sectors[sId]
		if sector.conflict then
			AutoResolveConflict(sector)
		end
	end

	table.clear(SatQueuedResolveConflict)
end

-- bNoVoice is unused
function ResolveConflict(sector, bNoVoice, isAutoResolve, isRetreat)
	gv_ActiveCombat = false
	sector = sector or gv_Sectors[gv_CurrentSectorId]
	
	-- If there is both a militia and enemy squad remaining
	-- autoresolve the conflict between them to decide the outcome.
	local mercSquads, enemySquads = GetSquadsInSector(sector.Id, "no_travel", not "include_militia", "no_arriving", "no_retreat")
	local militiaLeft = GetMilitiaSquads(sector)
	if #militiaLeft > 0 and #enemySquads > 0 then
		if isAutoResolve then
			assert(false) -- Auto resolve is causing another auto resolve, infinite loop!
			table.remove_value(g_ConflictSectors, sector.Id)
			sector.conflict = false
			
			if not AnyNonWaitingConflict() then
				ResumeCampaignTime("SatelliteConflict")	
			end
			return
		end

		if g_SatelliteUI then
			AutoResolveConflict(sector)
		elseif not table.find(SatQueuedResolveConflict, sector.Id) then
			SatQueuedResolveConflict[#SatQueuedResolveConflict + 1] = sector.Id
		end
		return
	end
	
	local playerAttacking = sector.conflict and sector.conflict.player_attacking
	local fromMap = sector.conflict and sector.conflict.from_map

	if sector then -- when going into combat without new game / proper campaign setup
		table.remove_value(g_ConflictSectors, sector.Id)
		sector.conflict = false
		if not g_Combat then
			ShowTacticalNotification("conflictResolved")
			PlayFX("NoEnemiesLeft", "start")
		end
	end
	
	if not AnyNonWaitingConflict() then
		ResumeCampaignTime("SatelliteConflict")	
	end
	UpdateEntranceAreasVisibility()
	
	-- UI update and restoring travel state from before conflict
	local squads = GetSquadsInSector(sector.Id)
	for i, squad in ipairs(squads) do
		ObjModified(squad)
	end
	ObjModified(SelectedObj)
	ObjModified("gv_SatelliteView")

	UpdateSectorControl(sector.Id)
	
	-- Check if player died in tactical view from enemies that dont have squads.
	if (sector.Side == "player1" or sector.Side == "player2") and not gv_SatelliteView and #mercSquads == 0 then
		local playerUnitsOnMap = GetCurrentMapUnits("player")
		local enemyUnitsOnMap = GetCurrentMapUnits("enemy")
		if #playerUnitsOnMap == 0 and #enemyUnitsOnMap > 0 then
			local first = enemyUnitsOnMap[1]
			SatelliteSectorSetSide(sector.Id, "enemy1")
		end
	end

	local playerWon = not isRetreat and (sector.Side == "player1" or sector.Side == "player2")
	if playerWon then
		sector.CustomConflictDescr = false
		RollForMilitiaPromotion(sector)
	end
	
	Msg("ConflictEnd", sector, bNoVoice, playerAttacking, playerWon, isAutoResolve, isRetreat, fromMap)
end

function OnMsg.SquadDespawned(squad_id, sector_id)
	-- Prevent sector takeover on arriving squad despawning on a force conflict sector as
	-- this logic will run before the "squad in sector" logic that will trigger the conflict
	if gv_Sectors[sector_id].ForceConflict then return end
	UpdateSectorControl(sector_id)
end

function UpdateSectorControl(sector_id)
	if not sector_id then
		return
	end
	
	local allySquads, enemySquads = GetSquadsInSector(sector_id, "excludeTravel", "includeMilitia", "excludeArrive", "excludeRetreat")
	local playerHere = #allySquads > 0
	local enemiesHere = false
	for _, squad in ipairs(enemySquads) do
		if squad.Side == "neutral" then goto continue end
	
		local all_dead = true
		for _, unit_id in ipairs(squad.units) do
			local unit = gv_SatelliteView and gv_UnitData[unit_id] or g_Units[unit_id]
			if unit and not unit:IsDead() then
				all_dead = false
				break
			end
		end
		enemiesHere = not all_dead and squad.Side
		
		::continue::
	end

	-- If both sides are present dont update the sector side.
	-- It should be updated by the resolution of the conflict.
	if enemiesHere and playerHere then return end
	
	if enemiesHere then
		SatelliteSectorSetSide(sector_id, enemiesHere)
	elseif playerHere then
		SatelliteSectorSetSide(sector_id, "player1")
	end
end

function NetEvents.ResolveConflict(sector, bNoVoice) -- left only for testing from the console
	ResolveConflict(gv_Sectors[sector], bNoVoice)
end

function GetSectorConflict(sector_id)
	local sector = gv_Sectors and gv_Sectors[sector_id or gv_CurrentSectorId]
	return sector and sector.conflict
end

local function lCheckMapConflictResolved()
	local sector = gv_Sectors[gv_CurrentSectorId]
	local playerUnits = GetCurrentMapUnits("player")
	local enemy_win = #playerUnits == 0
	local enemy_units = GetCurrentMapUnits("enemy")
	local player_win = true
	for _, unit in ipairs(enemy_units) do
		-- conflict can be resolved if all the remaining enemy units are both non-human and not aware
		player_win = player_win and not unit.Squad and not unit:IsAware()
	end
	if sector and sector.conflict and not sector.conflict.locked and (player_win or enemy_win) then
		sector.ForceConflict = false
		
		local isRetreat = not player_win and enemy_win
		
		-- Assert that this is correct
		if isRetreat then
			for i, u in ipairs(playerUnits) do
				assert(u.retreat_to_sector)
			end
		end
		
		ResolveConflict(sector, false, false, isRetreat)
	end
end

function CheckMapConflictResolvedForFixup()
	lCheckMapConflictResolved()
end


function OnMsg.CombatEnd(combat)
	if not combat.test_combat then
		lCheckMapConflictResolved()
	end
end

function OnMsg.UnitDied()
	if not g_Combat then
		lCheckMapConflictResolved()
	end
end

function OnMsg.VillainDefeated(unit)
	if not g_Combat then
		lCheckMapConflictResolved()
	end
end

function OnMsg.ExplorationTick()
	if g_TestCombat then return end
	
	local sector = gv_Sectors[gv_CurrentSectorId]
	if not sector then return end
	if not sector.conflict then return end
	if sector.conflict.locked then return end
	if sector.conflict.no_exploration_resolve then return end
	if sector.ForceConflict then return end
	
	lCheckMapConflictResolved()
end

local function lTacticalModeCheckEnterConflict()
	if GameState.disable_tactical_conflict then return end
	if GameState.Conflict or not gv_ActiveCombat then return end
	
	-- start conflict if there are aware units of opposing sides
	for _, unit in ipairs(g_Units) do
		if not unit:IsAware() then goto continue end
		
		local unitSquad = unit.Squad
		unitSquad = unitSquad and gv_Squads[unitSquad]
		if unitSquad and unitSquad.Retreat then goto continue end
		if unitSquad and unitSquad.CurrentSector ~= gv_CurrentSectorId then goto continue end
		
		local enemies = GetAllEnemyUnits(unit)
		for _, enemy in ipairs(enemies) do
			if not enemy:IsAware() then goto continue end

			local enemySquad = enemy.Squad
			enemySquad = enemySquad and gv_Squads[enemySquad]
			if enemySquad and enemySquad.Retreat then goto continue end
			if enemySquad and enemySquad.CurrentSector ~= gv_CurrentSectorId then goto continue end

			local unitTeam = unit.team
			local enemyTeam = enemy.team
			if unitTeam and enemyTeam then
				local unitTeamSide, enemyTeamSide = unitTeam.side, enemyTeam.side
				local playerPresent = unitTeamSide == "player1" or unitTeamSide == "player2" or enemyTeamSide == "player1" or enemyTeamSide == "player2"
				local enemyPresent = unitTeamSide == "enemy1" or unitTeamSide == "enemy2" or enemyTeamSide == "enemy1" or enemyTeamSide == "enemy2"
				if playerPresent and enemyPresent then
					EnterConflict(nil, nil, nil, nil, nil, nil, nil, "from_map")
				end
			end

			::continue::
		end

		::continue::
	end		
end

OnMsg.CombatStart = lTacticalModeCheckEnterConflict
OnMsg.UnitAwarenessChanged = lTacticalModeCheckEnterConflict

function SatelliteConflictAppliedOnSector(sector)
	return gv_CurrentSectorId == (sector and sector.Id) and CanCloseSatelliteView()
end

-- auto-resolve, autoresolve, auto resolve
GameVar("gv_AutoResolveUseOrdnance", false)

function GetPowerOfUnit(unit, noMods)
	if not unit then return 0 end

	local power
	if IsMerc(unit) then
		power = const.AutoResolve.BaseMercPower * unit:GetLevel()
	elseif unit.Squad and gv_Squads[unit.Squad].militia or unit.militia then
		power = const.AutoResolve.BaseMilitiaPower * unit:GetLevel("baseLevel")
	else -- enemy
		power = const.AutoResolve.BaseEnemyPower * unit:GetLevel("baseLevel")
	end
	
	power = MulDivRound(power, unit:GetProperty("unitPowerModifier"), 100)
	
	if noMods then
		return power
	end
	
	-- in Percents
	local modifier = 100
	-- Health and Wounds mod (power reduced by direct proportion to the units HitPoints/MaxHitPoints)
	local mod = MulDivRound(100, unit.HitPoints or unit.Health, unit:GetInitialMaxHitPoints()) - 100
	modifier = modifier + mod
	
	
	if IsMerc(unit) then
		-- Status Effects mod
		if unit:HasStatusEffect("Tired") then
			modifier = modifier + const.AutoResolve.TiredMod
		end
		
		if unit:HasStatusEffect("Exhausted") then
			modifier = modifier + const.AutoResolve.ExhaustedMod
		end
		
		if unit:HasStatusEffect("WellRested") then
			modifier = modifier + const.AutoResolve.WellRestedMod
		end
		
		-- Armor mod
		modifier = modifier + GetCombinedArmorPowerMod(unit)
		
		-- Weapon mod
		modifier = modifier + GetBestWeaponPowerMod(unit)
		
		-- Ordnance mod
		if gv_AutoResolveUseOrdnance and CanUseOrdnancePower(unit) then
			modifier = modifier + const.AutoResolve.OrdnanceMod
		end
	end
	
	power = MulDivRound(power, modifier, 100)
	return power
end

-- Max mod per Armor piece <maxMod>%. Total 3*<maxMod>%.
-- Based on Direct Proportion of its Cost and <costCap>, also on its condition
function GetCombinedArmorPowerMod(unit)
	local mod = 0
	mod = mod + GetArmorPowerMod(unit:GetItemAtPos("Head", 1, 1))
	mod = mod + GetArmorPowerMod(unit:GetItemAtPos("Torso", 1, 1))
	mod = mod + GetArmorPowerMod(unit:GetItemAtPos("Legs", 1, 1))
	return mod
end

function GetArmorPowerMod(armor)
	if not armor then return 0 end
	
	local maxMod = const.AutoResolve.MaxArmorMod -- Maximum +% mod per Armor piece
	local costCap = const.AutoResolve.MaxArmorModCost
	local mod = Min(maxMod, MulDivRound(maxMod, armor.Cost, costCap))
	mod = MulDivRound(mod, armor.Condition, 100)
	
	return mod
end

-- Max mod <maxMod>% from the best equiped Weapon.
-- Based on Direct Proportion of its Cost and <costCap>, also on its condition
function GetBestWeaponPowerMod(unit)
	local items = unit:GetHandheldItems()
	local mods = {}
	
	for _, item in ipairs(items) do
		mods[#mods+1] = GetWeaponPowerMod(unit, item)
	end
	
	table.sort(mods)
	return mods[#mods] or 0
end

function GetWeaponPowerMod(unit, weapon)
	if not weapon or not IsKindOfClasses(weapon, "Firearm", "MeleeWeapon") then return 0 end
	if IsKindOf(weapon, "MeleeWeapon") and unit.Strength + Unit.Dexterity < const.AutoResolve.MeleeRequiredStats then return 0 end
	if IsKindOf(weapon, "Firearm") and #unit:GetAvailableAmmos(weapon) < 1 then return 0 end -- doesn't have any ammo
	
	local maxMod = const.AutoResolve.MaxWeaponMod -- Maximum +% mod a Weapon can give
	local costCap = const.AutoResolve.MaxWeaponModCost
	local mod = Min(maxMod, MulDivRound(maxMod, weapon.Cost, costCap))
	mod = MulDivRound(mod, weapon.Condition, 100)
	
	return mod
end

-- if has equiped Grenades or Heavy Weapon and Ordnance
function CanUseOrdnancePower(unit)
	local items = unit:GetHandheldItems()
	
	for _, item in ipairs(items) do
		if IsKindOf(item, "Grenade") then
			return true
		elseif IsKindOf(item, "HeavyWeapon") and item.ammo and item.ammo.Amount > 0 then
			return true
		end
	end
	
	return false
end

-- 0% at 50 Leadership, 20% at 100 Leadership
function GetSideLeaderMod(units)
	local mod = 0
	local maxMod = const.AutoResolve.MaxLeaderMod
	local minLeadership = const.AutoResolve.MinLeadershipRequired
	local highestLeadership = 0
	
	for _, unit in ipairs(units) do
		if unit.Leadership > highestLeadership then
			highestLeadership = unit.Leadership
		end
	end
	
	local mod = Max(highestLeadership - minLeadership, 0)
	mod = MulDivRound(maxMod, mod, minLeadership)
	
	return mod
end

function GetSideMedicMod(units)
	local mod = 0
	local minMedical = const.AutoResolve.MinMedicalRequired
	local medics = 0
	
	for _, unit in ipairs(units) do
		if unit.Medical >= minMedical and GetUnitEquippedMedicine(unit) then
			medics = medics + 1
		end
	end
	
	if medics == 0 then
		mod = const.AutoResolve.NoMedicsMod
	elseif medics == 1 then
		mod = 0
	else
		mod = const.AutoResolve.EnoughMedicsMod
	end
	
	return mod
end

function GetSquadPower(squad)
	local power = 0
	if squad.units then
		for _, id in ipairs(squad.units) do
			local unit = gv_UnitData[id]
			power = power + GetPowerOfUnit(unit)
		end
	end
	return power
end

-- Excluding side modifiers
function GetMultipleSquadsPower(squads)
	local power = 0
	for _, squad in ipairs(squads) do
		power = power + GetSquadPower(squad)
	end
	return power
end

-- Including side modifiers
function GetSectorPowersInConflict(sector, playerSquads, enemySquads, disableRandomMod)
	-- Combined power of individual units
	if not playerSquads or not enemySquads then
		local playerSquads, enemySquads = GetSquadsInSector(sector.Id, "excludeTravelling", "includeMilitia", "excludeArriving")
	end
	local playerPower = GetMultipleSquadsPower(playerSquads)
	local enemyPower = GetMultipleSquadsPower(enemySquads)
	
	local playerUnits = GetUnitsFromSquads(playerSquads, "getUnitData")
	local enemyUnits = GetUnitsFromSquads(enemySquads, "getUnitData")
	
	local playerMod = 100 -- percent
	local enemyMod = 100

	local militiaOnlyTeam = true
	for _, unit in ipairs(playerUnits) do
		if IsMerc(unit) then
			militiaOnlyTeam = false
			break
		end
	end
	
	if not militiaOnlyTeam then
		-- Leader mod 
		playerMod = playerMod + GetSideLeaderMod(playerUnits)
		
		-- Medic mod
		playerMod = playerMod + GetSideMedicMod(playerUnits)
		
		-- Numerical Advantage mod
		if #playerUnits >= #enemyUnits * 2 then
			playerMod = playerMod + const.AutoResolve.NumericalAdvantageMod
		elseif #enemyUnits >= #playerUnits * 2 then
			playerMod = playerMod - const.AutoResolve.NumericalAdvantageMod
		end
	end
	
	-- Randomization mod: -<value>% to +<value>% (Applied to attacker)
	if sector.conflict and not disableRandomMod then
		local attackerMod = const.AutoResolve.AttackerRandomMod
		attackerMod = InteractionRandRange(-attackerMod, attackerMod, "AutoResolve")
		if sector.conflict.spawn_mode == "attack" then -- player is attacker
			playerMod = playerMod + attackerMod
		else
			enemyMod = enemyMod + attackerMod
		end
	end
	
	playerPower = MulDivRound(playerPower, playerMod, 100)
	enemyPower = MulDivRound(enemyPower, enemyMod, 100)
	
	-- Deffender bonus
	if sector.conflict then
		local bonus = sector.AutoResolveDefenderBonus
		if sector.conflict.spawn_mode == "attack" then -- player is attacker
			playerPower = playerPower + bonus
		else
			enemyPower = enemyPower + bonus
		end
	end
	
	return playerPower, enemyPower, playerMod
end

function GetAutoResolveOutcome(sector, disableRandomMod)
	local playerSquads, enemySquads = GetSquadsInSector(sector.Id, "excludeTravelling", "includeMilitia", "excludeArriving", "excludeRetreat")
	local playerPower, enemyPower, playerMod = GetSectorPowersInConflict(sector, playerSquads, enemySquads, disableRandomMod)
	
	-- Decide Outcome
	if CheatEnabled("AutoResolve") then
		return "decisive_win", playerPower, enemyPower, playerMod
	end
	
	if playerPower > 2*enemyPower then
		return "decisive_win", playerPower, enemyPower, playerMod
	elseif playerPower >= enemyPower then
		return "win", playerPower, enemyPower, playerMod
	elseif enemyPower > 2*playerPower then
		return "crushing_defeat", playerPower, enemyPower, playerMod
	else
		return "defeat", playerPower, enemyPower, playerMod
	end
end

MapVar("g_AccumulatedTeamXP", false)

function LogAccumulatedTeamXP(actor)
	if g_AccumulatedTeamXP then
		local log_msg
		for _, unit in ipairs(table.keys(g_AccumulatedTeamXP, "sorted")) do
			log_msg = log_msg or { T(280141508210, "Gained XP:") }
			log_msg[#log_msg + 1] = T{547096297080, " <unit>(<em><gain></em>)", unit = unit, gain = g_AccumulatedTeamXP[unit] }
		end
		
		if next(log_msg) then CombatLog(actor, table.concat(log_msg)) end
	end
	g_AccumulatedTeamXP = false
end

function CalculateAutoResolveUnitDamage(unit, outcome, side)
	local injuryChances = {
		decisive_win = { seriousInjury = const.AutoResolveDamage.DecisiveWinSeriousInjuryChance, injury = const.AutoResolveDamage.DecisiveWinInjuryChance }, -- 5% Serious Injury chance, 30% Injury chance
		win = { seriousInjury = const.AutoResolveDamage.WinSeriousInjuryChance, injury = const.AutoResolveDamage.WinInjuryChance }, -- 15% Serious Injury chance, 50% Injury chance
		defeat = { seriousInjury = const.AutoResolveDamage.DefeatSeriousInjuryChance, injury = const.AutoResolveDamage.DefeatInjuryChance }, -- 10% Serious Injury chance, 90% Injury chance
		crushing_defeat = { seriousInjury = const.AutoResolveDamage.CrushingDefeatSeriousInjuryChance, injury = const.AutoResolveDamage.CrushingDefeatInjuryChance}, -- 50% Serious Injury chance, 50% Injury chance
	}
	
	local militiaInjuryChanceMod = 0
	--adjust base and random dmg values and chances based on difficulty
	if side == "enemy" then
		local bonus = (GameDifficulties[Game.game_difficulty]:ResolveValue("autoResolveInjuryChanceEnemyBonus") or 0)
		injuryChances.decisive_win.injury = injuryChances.decisive_win.injury + bonus
		injuryChances.win.seriousInjury = injuryChances.win.seriousInjury + bonus
		injuryChances.win.injury = injuryChances.win.injury + bonus
		injuryChances.defeat.seriousInjury = injuryChances.defeat.seriousInjury + bonus
		injuryChances.crushing_defeat.seriousInjury = injuryChances.crushing_defeat.seriousInjury + bonus
	elseif side == "militia" then
		militiaInjuryChanceMod = const.AutoResolveDamage.MilitiaInjuryAdditiveMod
	end

	local percChangePerDiff = 100
	if side == "enemy" then
		--percChangePerDiff = PercentModifyByDifficulty(GameDifficulties[Game.game_difficulty]:ResolveValue("autoResolveEnemyDmgBonus"))
	elseif side == "player" then
		--percChangePerDiff = PercentModifyByDifficulty(GameDifficulties[Game.game_difficulty]:ResolveValue("autoResolvePlayerDmgBonus"))
	end
	
	local injuryDamage = MulDivRound(const.AutoResolveDamage.InjuryBaseDamage, percChangePerDiff, 100)
	local injuryRandomDamage = MulDivRound(const.AutoResolveDamage.InjuryRandomDamage, percChangePerDiff, 100)
	local seriousInjuryDamage = MulDivRound(const.AutoResolveDamage.SeriousInjuryBaseDamage, percChangePerDiff, 100)
	local seriousInjuryRandomDamage = MulDivRound(const.AutoResolveDamage.SeriousInjuryRandomDamage, percChangePerDiff, 100) -- applies 2 times
	
	local damage = 0
	local injury = false
	
	local injuryRoll = InteractionRand(100, "DamageOnAutoResolve") + 1
	if injuryRoll <= (injuryChances[outcome].seriousInjury + militiaInjuryChanceMod) then -- Unit got SeriouslyInjured
		damage = seriousInjuryDamage + InteractionRand(seriousInjuryRandomDamage, "DamageOnAutoResolve") + InteractionRand(seriousInjuryRandomDamage, "DamageOnAutoResolve")
		injury = "seriousInjury"
	elseif injuryRoll <= (injuryChances[outcome].injury + militiaInjuryChanceMod) then -- Unit got Injured
		damage = injuryDamage + InteractionRand(injuryRandomDamage, "DamageOnAutoResolve")
		injury = "injury"
	end
	
	return damage, injury
end

function AutoResolveUseMeds(playerSquads)
	local bestMedic = false
	local medkit = false
	
	for _, squad in ipairs(playerSquads) do
		for _, id in ipairs(squad.units) do
			local unit = gv_UnitData[id]
			local umedkit = GetUnitEquippedMedicine(unit)
			if umedkit and (not bestMedic or bestMedic.Medical < unit.Medical) then
				bestMedic = unit
				medkit = umedkit
			end
		end
	end
	
	if bestMedic then		
		for _, squad in ipairs(playerSquads) do
			for _, id in ipairs(squad.units) do
				local unit = gv_UnitData[id]				
				unit:GetBandaged(medkit, bestMedic)
			end
		end
	end
end

function AutoResolveUseAmmo(playerSquads, damageDone)
	local damageToUseAmmo = const.AutoResolveResources.DamageToAmmo
	local playerUnitsCount = CountUnitsInSquads(playerSquads)
	local baseAmmoUsagePerUnit = DivRound(damageDone, damageToUseAmmo * playerUnitsCount)
	
	local function TakeItemAmount(item, amount, container, slot)
		local used = Min(item.Amount, amount)
		item.Amount = item.Amount - used
		if item.Amount <= 0 then
			if slot then
				container:RemoveItem(slot, item, "no_update")
			elseif container then --presumably, squad bag which is an array..
				table.remove_entry(container, item)
			end
			DoneObject(item)
		end
		return used
	end
	
	for _, squad in ipairs(playerSquads) do
		for _, id in ipairs(squad.units) do
			local unit = gv_UnitData[id]
	
			local ammoRandMult = InteractionRand(50, "AutoResolveAmmo")
			local ammoToUse = MulDivRound(baseAmmoUsagePerUnit, 100 + ammoRandMult, 100)
			local handeldItems, handeldItemsSlots = unit:GetHandheldItems()
			
			if gv_AutoResolveUseOrdnance then
				local allowedOrdnance = 1 + InteractionRand(const.AutoResolveResources.MaxOrdnanceUsed, "AutoResolveAmmo")
				local ordnanceToAmmoMult = 3
				for i, item in ipairs(handeldItems) do
					if ammoToUse <= 0 or allowedOrdnance <= 0 then break end
					
					if IsKindOf(item, "Grenade") then
						local used = TakeItemAmount(item, allowedOrdnance, unit, handeldItemsSlots[i])
						allowedOrdnance = allowedOrdnance - used
						ammoToUse = ammoToUse - used * ordnanceToAmmoMult
					elseif IsKindOf(item, "HeavyWeapon") then
						local degrade = -item:GetBaseDegradePerShot()
						local ammos, containers, slots = unit:GetAvailableAmmos(item)
						for j, ammo in ipairs(ammos) do -- Use from AmmoPack and UnitInventory
							local used = TakeItemAmount(ammo, allowedOrdnance, containers[j], slots[j])
							allowedOrdnance = allowedOrdnance - used
							ammoToUse = ammoToUse - used * ordnanceToAmmoMult
							unit:ItemModifyCondition(item, degrade * used)
						end
						
						if allowedOrdnance > 0 and ammoToUse > 0 and item.ammo then -- Use from Weapon itself
							local used = TakeItemAmount(item.ammo, allowedOrdnance)
							allowedOrdnance = allowedOrdnance - used
							ammoToUse = ammoToUse - used * ordnanceToAmmoMult
							unit:ItemModifyCondition(item, degrade * used)
						end
					end
				end
			end
			
			for _, item in ipairs(handeldItems) do
				if ammoToUse <= 0 then break end
				
				if IsKindOf(item, "Firearm") then
					local degrade = -item:GetBaseDegradePerShot()
					local ammos, containers, slots = unit:GetAvailableAmmos(item)
					for j, ammo in ipairs(ammos) do -- Use from AmmoPack and UnitInventory
						local used = TakeItemAmount(ammo, ammoToUse, containers[j], slots[j])
						ammoToUse = ammoToUse - used
						unit:ItemModifyCondition(item, degrade * used)
					end
					
					if ammoToUse > 0 and item.ammo then -- Use from Weapon itself
						local used = TakeItemAmount(item.ammo, ammoToUse)
						ammoToUse = ammoToUse - used
						unit:ItemModifyCondition(item, degrade * used)
					end
				end
			end
		end
	end
end

function AutoResolveArmorDegradation(unit, injury)
	if not unit or not injury then return end
	
	local armorPieces = {}
	armorPieces[#armorPieces+1] = unit:GetItemAtPos("Head", 1, 1)
	armorPieces[#armorPieces+1] = unit:GetItemAtPos("Torso", 1, 1)
	armorPieces[#armorPieces+1] = unit:GetItemAtPos("Legs", 1, 1)
	
	local times = injury == "seriousInjury" and const.AutoResolveResources.ArmorDegradationTimesSeriousInjury or const.AutoResolveResources.ArmorDegradationTimesInjury
	
	for i = 1, times do
		if #armorPieces == 0 then return end

		local idx = InteractionRand(#armorPieces, "AutoResolveArmor") + 1
		local item = armorPieces[idx]
		
		unit:ItemModifyCondition(item, -item.Degradation)
		
		if item.Condition <= 0 then
			table.remove(armorPieces, idx)
		end
	end
end

function ApplyAutoResolveOutcome(sector, playerOutcome)
	local playerWins = IsOutcomeWin(playerOutcome)
	local enemyOutcome = GetOppositeOutcome(playerOutcome)
	local playerSquads, enemySquads = GetSquadsInSector(sector.Id, "excludeTravelling", not "includeMilitia", "excludeArriving", "excludeRetreating")
	local items = {}
	
	-- Militia outcome
	local militiaSquads = GetMilitiaSquads(sector)
	local militiaUnitsCount = CountUnitsInSquads(militiaSquads)
	local militiaKilled = 0
	for i = #militiaSquads, 1, -1 do
		local squad = militiaSquads[i]
		for j = #squad.units, 1, -1 do
			local id = squad.units[j]
			local unit = gv_UnitData[id]
			local damage = 0
			
			-- When the unit appears twice in a squad (due to another bug), this will error.
			if not unit then goto continue end
			
			if not playerWins then -- all militia die if the player loses;
				damage = unit.HitPoints
			else
				local deathRoll = InteractionRand(100, "AutoResolve")
				local deathChance = playerOutcome == "decisive_win" and const.AutoResolveDamage.NPCDeathChanceOnDecisiveWin or const.AutoResolveDamage.NPCDeathChanceOnWin
				if deathRoll < deathChance then
					damage = unit.HitPoints
				else
					damage = CalculateAutoResolveUnitDamage(unit, playerOutcome, "militia")
					local militiaDamageMultiplier = const.AutoResolveDamage.MilitiaDamageTakenMod -- percent
					damage = MulDivRound(damage, 100 + militiaDamageMultiplier, 100)
				end
			end
			
			unit.HitPoints = Max(unit.HitPoints - damage, 0)
			unit:AccumulateDamageTaken(damage)
			
			if playerWins and #playerSquads <= 0 and (militiaKilled == militiaUnitsCount - 1) then -- let the last militia survive when defending with no mercs
				unit.HitPoints = 1
			end
			
			if unit.HitPoints <= 0 then
				militiaKilled = militiaKilled + 1
				unit:Die()
				Unit.DropLoot(unit)
				if playerWins then
					unit:ForEachItem(function(item, slot_name, left, top, items)
						items[#items + 1] = item
						unit:RemoveItem(slot_name, item)
					end, items)
				end
			end
			
			::continue::
		end
	end
	
	-- Enemies outcome
	g_AccumulatedTeamXP = {}
	local totalDamageToEnemy = 0
	for i = #enemySquads, 1, -1 do
		for j = #enemySquads[i].units, 1, -1 do
			local id = enemySquads[i].units[j]
			local unit = gv_UnitData[id]
			local damage = 0
			
			if playerWins then -- all enemies die if the player wins;
				damage = unit.HitPoints
			else
				local deathRoll = InteractionRand(100, "AutoResolve")
				local deathChance = enemyOutcome == "decisive_win" and const.AutoResolveDamage.NPCDeathChanceOnDecisiveWin or const.AutoResolveDamage.NPCDeathChanceOnWin
				if deathRoll < deathChance then
					damage = unit.HitPoints
				else
					damage = CalculateAutoResolveUnitDamage(unit, enemyOutcome, "enemy")
				end
			end
			
			unit.HitPoints = Max(unit.HitPoints - damage, 0)
			--unit:AccumulateDamageTaken(damage)
			
			if unit.villain and not playerWins then -- don't kill the villain
				unit.HitPoints = 1
			end
		
			if unit.HitPoints <= 0 then
				unit:Die()
			end
			
			totalDamageToEnemy = totalDamageToEnemy + damage
			
			if playerWins then -- Generate loot
				Unit.DropLoot(unit)
				unit:ForEachItem(function(item, slot_name, left, top, items)
					items[#items + 1] = item
					unit:RemoveItem(slot_name, item)
				end, items)
			end
		end
	end
	
	-- Player outcome
	-- Consume Resources
	if #playerSquads > 0 then -- Militia only autoresolve
		AutoResolveUseAmmo(playerSquads, totalDamageToEnemy)
	end
	
	-- Damage Units
	local playerUnitsCount = CountUnitsInSquads(playerSquads)
	local mercsKilled = 0
	for i = #playerSquads, 1, -1 do
		local squad = playerSquads[i]
		for j = #squad.units, 1, -1 do
			local id = squad.units[j]
			local unit = gv_UnitData[id]
			local damage = 0
			local injury
			
			damage, injury = CalculateAutoResolveUnitDamage(unit, playerOutcome, "player")
			
			if injury then
				AutoResolveArmorDegradation(unit, injury)
			end
			
			if injury == "seriousInjury" and unit.Tiredness < 1 then
				unit:SetTired(unit.Tiredness + 1)
			end
			
			unit.HitPoints = Max(unit.HitPoints - damage, 0)
			unit:AccumulateDamageTaken(damage)
			
			if playerWins and (mercsKilled == playerUnitsCount - 1) then -- let the last Merc survive
				unit.HitPoints = 1
			end
			
			if unit.HitPoints <= 0 then
				mercsKilled = mercsKilled + 1
				unit:Die()
			end
		end
	end
	--AutoResolveUseMeds(playerSquads)
	
	if #items > 0 then
		SortItemsArray(items)
	end
	LogAccumulatedTeamXP("short")
	
	return items
end

function IsOutcomeWin(outcome)
	return outcome == "decisive_win" or outcome == "win"
end

function GetOppositeOutcome(outcome)
	if outcome == "decisive_win" then return "crushing_defeat" end
	if outcome == "win" then return "defeat" end
	if outcome == "defeat" then return "win" end
	if outcome == "crushing_defeat" then return "decisive_win" end
end

function NetEvents.CloseOtherGuysAutoResolveResultsUI()
	local dlg = GetDialog("SatelliteConflict")
	if dlg then
		dlg:Close()
	end
end

local function RecalcNames(sector, oldAllySquads)
	for _, squad in ipairs(oldAllySquads) do
		local squadUnits = table.copy(squad.units)
		for id, unitId in ipairs(squadUnits) do
			if not gv_UnitData[unitId] then
				table.remove(squad.units, table.find(squad.units, unitId))
			end
		end
	end
	local allySquads = GetGroupedSquads(sector.Id, true, false, "no_retreating")
	
	for i, s in ipairs(allySquads) do
		for i, u in ipairs(s.units) do
			local unitData = gv_UnitData[u]
			local squad = table.find_value(oldAllySquads, "UniqueId", s.UniqueId)
			if squad and not table.find(squad.units, unitData.session_id) then
				table.insert(squad.units, unitData.session_id)
			end
		end
	end
	
	return oldAllySquads
end

function lCopySquadsBeforeAutoResolve(squadList)
	local newList = {}
	for i, s in ipairs(squadList) do
		local copy = {
			units = table.copy(s.units),
			Name = s.Name,
			CurrentSector = s.CurrentSector,
			UniqueId = s.UniqueId,
			image = s.image,
			Retreat = s.Retreat,
			militia = s.militia
		}
		newList[#newList + 1] = copy
	end
	return newList
end

function AutoResolveConflict(sector)
	local player_outcome = GetAutoResolveOutcome(sector)
	local player_wins = IsOutcomeWin(player_outcome)
	
	--save the needed data for the auto-resolve screen
	--todo: maybe GetAutoResolveOutcome should return squads
	local allySquads = GetGroupedSquads(sector.Id, "includeMilitia", not "get_enemies", "no_retreating", "exclude_travelling")
	local enemySquads = GetGroupedSquads(sector.Id, not "includeMilitia", "get_enemies", "no_retreating", "exclude_travelling")
	enemySquads = enemySquads or {}
	
	-- Auto resolve will cause units to be ejected from the squads,
	-- so we need to copy the data.
	allySquads = lCopySquadsBeforeAutoResolve(allySquads)
	enemySquads = lCopySquadsBeforeAutoResolve(enemySquads)
	
	local loot = ApplyAutoResolveOutcome(sector, player_outcome)

	-- Sync to prevent ongoing combat hang if retreat->autoresolve due to militia
	if sector.Id == gv_CurrentSectorId and not ForceReloadSectorMap then
		LocalCheckUnitsMapPresence()
		SyncUnitProperties("session")
	end

	-- todo: can this reuse the information from above once it is refactored to get it from GetOutcome?
	local playerSquads = GetSquadsInSector(sector.Id, "excludeTravelling", not "includeMilitia", "excludeArriving", "excludeRetreating")
	local first_alive_merc
	for _, squad in ipairs(playerSquads) do
		for _, id in ipairs(squad.units) do
			local unit = gv_UnitData[id]
			if unit.Squad and unit.HireStatus ~= "Dead" then
				first_alive_merc = unit
				break
			end
		end
		if first_alive_merc then
			break
		end
	end
	
	local playerPower, enemyPower, playerMod = GetSectorPowersInConflict(sector, allySquads, enemySquads, "disableRandomMod")
	allySquads.power = playerPower
	allySquads.playerMod = playerMod
	enemySquads.power = enemyPower
	
	local items = table.copy(loot)
	local sectorStash = GetSectorInventory(sector.Id)
	assert(sectorStash)
	if sectorStash then
		AddItemsToInventory(sectorStash, items)
	end
	
	PauseCampaignTime("SatelliteConflictOutcome")
	
	if player_wins then
		sector.ForceConflict = false
		ResolveConflict(sector, nil, "auto-resolve", nil)
	elseif first_alive_merc then -- retreat mercs
		SatelliteRetreat(sector.Id)
	else -- no mercs left alive
		ResolveConflict(sector, "no voice", "auto-resolve", nil)
		ResumeCampaignTime("UI")
	end

	-- recalc squads to handle promoted militia
	allySquads = RecalcNames(sector, allySquads)
	
	OpenSatelliteConflictDlg(
		{
			player_outcome = player_outcome,
			allySquads = allySquads,
			enemySquads = enemySquads,
			sector = sector,
			loot = loot,
			first_alive_merc = first_alive_merc,
			autoResolve = true
		})
	ResumeCampaignTime("SatelliteConflictOutcome")
	
	ObjModified("sector_selection_changed")
	ObjModified("sector_selection_changed_actions")
	Msg("AutoResolvedConflict", sector.Id, player_outcome)
end

function NetSyncEvents.UIAutoResolveConflict(sector_id, ordenance)
	local sector = gv_Sectors[sector_id]
	if not sector.conflict then return end
	local old = gv_AutoResolveUseOrdnance
	gv_AutoResolveUseOrdnance = ordenance --quick and dirty fix for autoresolve using ui button state, this will only work if there is no sleeps/threads n such
	AutoResolveConflict(sector)
	gv_AutoResolveUseOrdnance = old
	local dlg = GetDialog("SatelliteConflict")
	if dlg then
		dlg:Close()
	end
end

function TFormat.AutoResolveOutcomeText(context_obj, status)
	if status == "decisive_win" then
		return T(907277131281, "DECISIVE WIN")
	elseif status == "win" then
		return T(561227589007, "VICTORY")
	elseif status == "defeat" then
		return T(979864159307, "DEFEAT")
	elseif status == "crushing_defeat" then
		return T(912438837574, "CRUSHING DEFEAT")
	end
end

function RollForMilitiaPromotion(sector)
	local squads = GetMilitiaSquads(sector)
	local promotedCount = 0
	
	for _, squad in ipairs(squads) do
		local unitIds = table.copy(squad.units)
		
		for _, id in ipairs(unitIds) do
			--local unit = g_Units[id]
			local unitData = gv_UnitData[id]
			
			local chance = 30
			local roll = InteractionRand(100, "MilitiaPromotion")
			
			if roll < chance then
				if unitData.class == "MilitiaRookie" then
					CreateMilitiaUnitData("MilitiaVeteran", sector, squad)
					DeleteMilitiaUnitData(unitData.session_id, squad)
					
					promotedCount = promotedCount + 1
				elseif unitData.class == "MilitiaVeteran" then
					CreateMilitiaUnitData("MilitiaElite", sector, squad)
					DeleteMilitiaUnitData(unitData.session_id, squad)
					
					promotedCount = promotedCount + 1
				end
			end
		end
	end
	
	if promotedCount > 0 then
		if promotedCount > 1 then
			CombatLog("important", T{293615811082, "<promotedCount> militia got promoted in <SectorName(sectorId)>", promotedCount = promotedCount, sectorId = sector.Id})
		else
			CombatLog("important", T{488327770041, "A militia unit got promoted in <SectorName(sectorId)>", promotedCount = promotedCount, sectorId = sector.Id})
		end
	end
end

-- remove enemy units/squads from a sector
-- value is an signed number, denoting whether and how many units to add or remove
-- valueType is a string, can either "count" which means value is a specific count or "percent"
function ModifySectorEnemySquads(sector_id, value, valueType, class)
	if value == 0 then
		return
	end
	valueType = valueType or "percent"
	
	local squads = {}
	local mercs, mercsPerSquad = {}, {}
	local enemySquads = GetSectorSquadsFromSide(sector_id, "enemy1", "enemy2")
	for i, squad in ipairs(enemySquads) do
		if not squad.villain and not squad.guardpost then
			for _, merc in ipairs(squad.units) do
				local unit = gv_UnitData[merc]
				if (not class and not unit.villain and not HasAnyShipmentItem(unit)) or unit.class == class then
					mercs[#mercs+1] = merc
					if not mercsPerSquad[squad] then mercsPerSquad[squad] = {} end
					mercsPerSquad[squad][#mercsPerSquad + 1] = merc
				end	
			end
			if EnemySquadDefs[squad.enemy_squad_def] then
				squads[#squads + 1] = squad
			end
		end
	end
	
	if value < 0 then -- Remove units
		value = abs(value)
		local removeAll = (valueType == "percent" and value == 100) or (valueType == "count" and value == #mercs)
		if removeAll then
			for _, merc in ipairs(mercs) do
				RemoveUnitFromSquad(gv_UnitData[merc], "despawn")
			end
		else
			local count = valueType == "count" and value or MulDivRound(value, #mercs, 100)
			count = Max(count, 1)
			for i = 1, Min(count, #mercs) do
				local merc, idx = table.interaction_rand(mercs, "SectorEnemySquads")
				table.remove(mercs, idx)
				RemoveUnitFromSquad(gv_UnitData[merc], "despawn")
			end
		end
	else -- Add units
		for _, squad in ipairs(squads) do
			-- Note: If the value is a percent it is relative to the current number of units of the same type in the sector.
			local count = valueType == "count" and value or MulDivRound(value, #mercsPerSquad[squad], 100)
			count = Max(count, 1)
			
			local units_to_create = {}
			if class then
				for i = 1, count do
					units_to_create[i] = class
				end
			else			
				while count > 0 do
					local unit_template_ids = GenerateRandEnemySquadUnits(squad.enemy_squad_def)
					if #unit_template_ids == 0 then
						assert(false, "We risk infinite loop here, something is wrong with the enemy squad definition. Not all enemy units will be created from this ModifySectorEnemySquads effect.")
						break
					end
					local all = #unit_template_ids
					for i = 1, all do
						local id, idx = table.interaction_rand(unit_template_ids, "SectorEnemySquads")
						units_to_create[#units_to_create + 1] = id
						table.remove(unit_template_ids, idx)
						count = count - 1
						if count == 0 then
							break
						end
					end
				end	
			end

			local new_units = GenerateUnitsFromTemplates(squad.CurrentSector, units_to_create, "ModifyEffect")
			AddUnitsToSquad(squad, new_units)
		end
	end
	
	if not gv_SatelliteView and sector_id == gv_CurrentSectorId then
		LocalCheckUnitsMapPresence()
	end
end

DefineClass.SatelliteConflictUIMercsDisplay = {
	__parents = { "XContextWindow" },
	GridWidth = 2,
	LayoutMethod = "Vlist",
	LayoutVSpacing = 10,
	MinHeight = 330,
	MaxHeight = 450,
	
	properties = {
		{ category = "MercDisplay", id = "headerText", name = "Header Name", editor = "text", default = "", translate = true },
		{ category = "MercDisplay", id = "subheaderText", name = "Subheader", editor = "text", default = "", translate = true },
		{ category = "MercDisplay", id = "showEnroute", name = "ShowEnroute", editor = "bool", default = "" },
		{ category = "MercDisplay", id = "align", name = "Align", editor = "choice", items = { "left", "right" }, default = "left" },
	}
}

function SatelliteConflictUIMercsDisplay:Open()
	self.idHeaderTitle:SetText(self.headerText)
	self.idSubHeaderText:SetText(self.subheaderText)
	XContextWindow.Open(self)
	
	if self.align == "right" then
		self.idHeader:SetHAlign("left")
		self.idHeaderTitle:SetHAlign("left")
		self.idHeaderLine:SetHAlign("left")
		self.idSubHeader:SetHAlign("left")
		
		local margins = self.idHeader.Margins
		self.idHeader:SetMargins(box(margins:maxx(), margins:miny(), margins:minx(), margins:maxy()))
	
		local paddings = self.idMercs.Padding
		self.idMercs:SetPadding(box(paddings:maxx(), paddings:miny(), paddings:minx(), paddings:maxy()))
		
		for i, s in ipairs(self.idMercs) do
			s:SetHAlign("left")
			if rawget(s, "idMercContainer") then
				s.idMercContainer:SetHAlign("left")
			end
			s:SetMargins(box(20, 0, 0, 0))
		end
	end
end

function SatelliteConflictUIMercsDisplay:GetMercUnitData(context)
	if context.UniqueId then
		return GetMercArrayUnitData(context.units) or {}
	else
		if not context.units or #context.units == 0 then
			return false
		end
		return table.imap(context.units, function(o)
			local propObj = ResolvePropObj(o) or o
			if IsKindOf(propObj, "UnitData") then return o end
			return SubContext(o.template, o)
		end)
	end
end

function SatelliteConflictUIMercsDisplay:SplitMercsIntoSquads(context)
	if not context.units then return {context} end
	
	local maxPeopleInSquad = const.Satellite.MercSquadMaxPeople
	local squadCount = #context.units > maxPeopleInSquad and MulDivRound(#context.units, 1000, maxPeopleInSquad * 1000) or 1
	local squads = {}
	for i = 0, squadCount - 1 do
		local units = {}
		local startIdx = (maxPeopleInSquad * i) + 1
		for m = startIdx, Min(startIdx + maxPeopleInSquad - 1, #context.units) do
			units[#units + 1] = context.units[m]
		end
		squads[i + 1] = {
			units = units
		}
	end
	return squads
end

GameVar("LostLoyaltyWithSectorsThisTick", false) -- Used to prevent double penalties

function OnMsg.SatelliteTick()
	LostLoyaltyWithSectorsThisTick = false
end

function GetLoyaltyCityNearby(sector, filter)
	if filter == "center_only" then
		local s = gv_Sectors[sector.Id]
		local city = s and s.City
		if city and city ~= "none" then
			return city
		else
			return
		end
	end
	
	local city = gv_Sectors[sector.Id].City
	if not filter and city and city ~= "none" then
		return city
	end
	
	city = nil
	ForEachSectorAround(sector.Id, 1, function(sector_id)
		if filter == "adjacent_only" and sector_id == sector.Id then return end
	
		-- If any of the adjacent sectors is part of a city
		local s = gv_Sectors[sector_id]
		if s and s.City and s.City ~= "none" then
			city = s.City
			return "break"
		end
	end)
	return city
end

function OnMsg.SectorSideChanged(sector_id, oldSide, newSide)
	-- Lost control of a sector that belongs to a city
	if oldSide == "player1" and newSide == "enemy1" then
		if LostLoyaltyWithSectorsThisTick and LostLoyaltyWithSectorsThisTick[sector_id] then return end
	
		local sector = gv_Sectors[sector_id]
		if sector.conflict then return end -- Conflict End will handle loyalty change
		
		local city = GetLoyaltyCityNearby(sector, "center_only")
		CityModifyLoyalty(city, const.Loyalty.CitySectorEnemyTakeOverLoyaltyLoss, T(171133072609, "City Lost"))
	end
end

function CivilianDeathPenalty()
	local penaltyAmount = const.Loyalty.CivilianDeathPenalty
	local penaltyCap = const.Loyalty.CivilianDeathPenaltyCityCap
	local currentSector = gv_Sectors[gv_CurrentSectorId]
	local cityId = currentSector and GetLoyaltyCityNearby(currentSector)
	local city = gv_Cities[cityId]
	if not city then return end
	
	if city.currentCivilianDeathPenalty + penaltyAmount > penaltyCap then penaltyAmount = penaltyCap - city.currentCivilianDeathPenalty end
	if city.Loyalty - penaltyAmount < 0 then penaltyAmount = city.Loyalty end
	local oldLoyalty = city.Loyalty
	CityModifyLoyalty(cityId, -penaltyAmount, T(938505306538, "Civilian death penalty"))
	if oldLoyalty > city.Loyalty then
		city.currentCivilianDeathPenalty = city.currentCivilianDeathPenalty + penaltyAmount
	end
end

function OnMsg.SectorSideChanged(sector_id, oldSide, newSide)
	-- reset conflictLoyaltyGained
	if oldSide == "player1" and newSide == "enemy1" then
		local sector = gv_Sectors[sector_id]
		sector.conflictLoyaltyGained = false
	end
end

function OnMsg.ConflictEnd(sector, _, playerAttacked, playerWon, autoResolve, isRetreat, startedFromMap)
	-- If you win in a conflict in a sector adjacent to a city sector that you own
	-- you get loyalty for that city.
	local allySquads = GetGroupedSquads(sector.Id, true, false, "no_retreating", "non_travelling")
	if playerWon then
		if (not playerAttacked and not startedFromMap) or not sector.conflictLoyaltyGained then
			local city = GetLoyaltyCityNearby(sector)
			
			assert(allySquads and #allySquads > 0)
			
			local nonMilitiaSquad = false
			for i, sq in ipairs(allySquads) do
				if not sq.militia then
					nonMilitiaSquad = true
				end
			end
			
			-- Militia won alone!
			if not nonMilitiaSquad then
				assert(autoResolve)
				CityModifyLoyalty(city, const.Loyalty.ConflictMilitiaOnlyWinBonus, T(469271409848, "Enemies cleared by militia"))
				sector.conflictLoyaltyGained = true
			else
				CityModifyLoyalty(city, const.Loyalty.ConflictWinBonus, T(133483288436, "Enemies cleared"))
				sector.conflictLoyaltyGained = true
			end
			--world flip that has caused disable autoresolve should be cleared
			sector.autoresolve_disabled = false
		end
		
		-- Cancel units that have retreated, now that we've won. (219850)
		for i, squad in ipairs(allySquads) do
			for i, uId in ipairs(squad.units) do
				local ud = gv_UnitData[uId]
				if ud and ud.retreat_to_sector then
					CancelUnitRetreat(ud)
				end
			end
		end
		LocalCheckUnitsMapPresence()
	-- If you retreat (this also happens when losing an auto resolve)
	elseif isRetreat then
		local city = GetLoyaltyCityNearby(sector)
		CityModifyLoyalty(city, const.Loyalty.ConflictRetreatPenalty, T(186425120178, "Retreat"))
		
		if not LostLoyaltyWithSectorsThisTick then LostLoyaltyWithSectorsThisTick = {} end
		LostLoyaltyWithSectorsThisTick[sector.Id] = true
		
	-- If you get defeated (regardless of whether militia got defeated or mercs)
	elseif not playerWon and (not allySquads or #allySquads == 0) then
		local city = GetLoyaltyCityNearby(sector, "adjacent_only")
		CityModifyLoyalty(city, const.Loyalty.ConflictDefeatedLoyaltyLoss, T(703208874704, "Defeat"))
	end
end

function OpenSatelliteConflictDlg(context, openedBy)
	CreateRealTimeThread(function()
		WaitPlayingSetpiece()
		
		local satCon = GetDialog("SatelliteConflict")
		if satCon then
			-- This shouldn't happen, but better to handle it. Reopen the dialog to ensure we have the latest.
			-- One way this can happen is when triggering a conflict from a shortcut exit
			-- since reaching the sector and the sector center will happen back to back.
			-- Another way this happens is when going out of an underground sector into an overground conflict through sat view.
			if satCon.context.Id == context.Id then
				print("double conflict", context.Id)
				satCon:Close()
			end
			WaitMsg(satCon)
		end
		
		local popupHost = GetDialog("PDADialogSatellite")
		popupHost = popupHost and popupHost:ResolveId("idDisplayPopupHost")
		OpenDialog("SatelliteConflict", popupHost or GetInGameInterface(), context)
		
		-- Play the cool sound only when the conflict is
		-- initiated by the code, and not when it is opened by UI.
		if openedBy == "auto-open" then
			PlayFX("ConflictPanelOpen")
		else
			PlayFX("ConflictPanelOpenByPlayer")
		end
	end)
end

function OnMsg.UnitDieStart(unit, attacker)
	if unit:IsCivilian() and unit.Affiliation == "Civilian" and attacker then
		local attackerSide = IsKindOf(attacker, "DynamicSpawnLandmine") and attacker.team_side or attacker.team.side
		local playerSide = NetPlayerSide()
		
		local attackerIsPlayer = attackerSide == playerSide
		local attackerIsPlayerEnemy = SideIsEnemy(playerSide, attackerSide)
		if attackerIsPlayer or attackerIsPlayerEnemy then
			CivilianDeathPenalty()
		end
	end
end

GameVar("gv_CiviliansKilled", 0)
function OnMsg.OnKill(attacker, killedUnits)
	if IsMerc(attacker) then
		for _, unit in ipairs(killedUnits) do
			if unit:IsCivilian() and not unit.immortal then
				gv_CiviliansKilled = gv_CiviliansKilled + 1
			end
		end
	end
end

function DespawnUnitData(sectorId, class, despawnUnitToo)
	local found = table.filter(gv_UnitData, function(i, o)  
		local squad = o.Squad
		squad = squad and gv_Squads[squad]
		
		local sectorFilter = squad and squad.CurrentSector == sectorId
		if not squad then
			sectorFilter = g_Units[o.session_id] and gv_CurrentSectorId == sectorId
		end
		
		return o.class == class and sectorFilter
	end)

	local firstIdx = found and next(found)
	if not firstIdx then return end
	RemoveUnitFromSquad(found[firstIdx], despawnUnitToo and "despawn")
	if despawnUnitToo then
		LocalCheckUnitsMapPresence()
	end
end

function IsAutoResolveEnabled(sector)
	if not sector.conflict then
		return false
	end

	if not sector.Map then
		return true
	end
	
	-- These are the squads that would be part of the conflict. (SatelliteConflict.lua)
	-- Auto resolve is always enabled if only militia squads will be part of the conflict.
	local alliesInConflict, enemySquads = GetSquadsInSector(sector.Id, "excludeTravelling", "includeMilitia", "excludeArriving")
	if not alliesInConflict or #alliesInConflict == 0 then
		return false
	end
	
	local onlyMilitia = true
	for i, s in ipairs(alliesInConflict) do
		if not s.militia then
			onlyMilitia = false
			break
		end
	end
	if onlyMilitia then
		return true
	end
	
	-- Losing auto resolve will retreat the squad
	-- so we allow auto resolve only when at least of the squads
	-- has a sector to retreat to (then all squads which dont have
	-- a valid retreat sector will inherit it from them in SatelliteRetreat)
	local anyHavePreviousSector = false
	for i, squad in ipairs(alliesInConflict) do
		anyHavePreviousSector = not squad.militia and squad.PreviousSector
		
		-- How?!?
		anyHavePreviousSector = anyHavePreviousSector and squad.PreviousSector ~= sector.Id
		
		if anyHavePreviousSector then break end
	end
	
	if not anyHavePreviousSector then
		return false
	end
	
	if sector.autoresolve_disabled then
		return false
	end
	
	if not enemySquads or #enemySquads == 0 then
		return false
	end
	
	return CanGoInMap(sector.Id) and not sector.ForceConflict
end

function OnMsg.ConflictEnd(sector)
	-- Check if player won
	if sector.Side ~= "player1" then return end
	
	-- Check if militia present
	local militia_squad_id = sector.militia_squad_id
	local militia_squad = gv_Squads[militia_squad_id]
	if not militia_squad or #(militia_squad.units or "") == 0 then return end	
	
	local quest = QuestGetState("05_TakeDownMajor")
	SetQuestVar(quest, "LegionBeatenByMilitia", true)
end

function GetSatelliteConflictWarnings(squads)
	local woundedCount, tiredCount = 0, 0
	for _, squad in ipairs(squads) do
		for _, id in ipairs(squad.units) do
			local unit = gv_UnitData[id]
			if unit.Tiredness >= 1 then
				tiredCount = tiredCount + 1
			end
			if unit.HitPoints < MulDivRound(unit:GetInitialMaxHitPoints(), 50, 100) then
				woundedCount = woundedCount + 1
			end
		end
	end
	return woundedCount, tiredCount
end

function OnMsg.StartSatelliteGameplay()
	if ZuluAppliedSessionDataFixups.RemoveInvalidConflicts and not
		ZuluAppliedSessionDataFixups.RemoveInvalidConflicts_2 then
		if CampaignPauseReasons.SatelliteConflict and not AnyNonWaitingConflict() then
			ResumeCampaignTime("SatelliteConflict")
		end
		ZuluAppliedSessionDataFixups.RemoveInvalidConflicts_2 = true
	end
end

function SavegameSessionDataFixups.RemoveInvalidConflicts(data)
	-- Manually get squads in the sector as the data is not filled in yet at this point.
	-- Uses same logic as AddSquadToSectorList
	local function lSquadsInSector(sector)
		local ally, enemy, militia = {}, {}, {}
		
		local squads = GetGameVarFromSession(data, "gv_Squads")
		for _, squad in sorted_pairs(squads) do
			if squad.CurrentSector == sector.Id then
				if (squad.Side == "player1" or squad.Side == "ally") then
					if not squad.militia then
						ally[#ally + 1] = squad
					else	
						militia[#militia + 1] = squad
					end
				else
					enemy[#enemy + 1] = squad
				end
			end
		end
		
		return ally, enemy, militia
	end
	
	local sectors = GetGameVarFromSession(data, "gv_Sectors")
	local anyConflict

	for id, sector in pairs(sectors) do
		if sector.conflict then
			local ally, enemy, militia = lSquadsInSector(sector)
			if not next(ally) and (not next(militia) or not next(enemy)) then
				sector.conflict = false
			else
				anyConflict = true
			end
		end
	end

	if not anyConflict then
		data.game.PersistableCampaignPauseReasons["SatelliteConflict"] = nil
	end
end
