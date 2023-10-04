DefineClass.TestTeamDef = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "mercs", name = "Mercs", editor = "string_list", default = empty_table, item_default = "", items = function() return table.keys2(UnitDataDefs, "sorted", "") end },
		{ id = "side", name = "Side", editor = "dropdownlist", default = false, items = function() return table.map(GetCurrentCampaignPreset().Sides, "Id") end },
		{ id = "ai_control", name = "AI", editor = "bool", default = false },
		{ id = "team_color", name = "Team Color", editor = "color", default = RGB(100, 100, 100) },
		{ id = "team_name", name = "Team Name", editor = "text", default = "", translate = true },
		--{ id = "spawn_marker_group", name = "Spawn Marker Group", editor = "combo", items = GridMarkerGroupsCombo(), default = "" },
		{ id = "spawn_marker_group", name = "Spawn Marker Group", editor = "text", default = "" },
	},
}

function TestTeamDef:GetEditorView()
	return Untranslated("<team_name> ( <side> ):")..Untranslated(ValueToLuaCode(self.mercs))
end

function InitTestCombat(combat, combat_params, time_of_day)
	if g_Combat ~= combat and IsValid(g_Combat) then
		DoneObject(g_Combat)
	end
	g_Combat = combat or Combat:new()

	combat_params = combat_params or {
		TestTeamDef:new{
			mercs = { "Barry", "Ivan", "Buns" },
			team_color = RGB(0, 0, 200),
			ai_control = false,
		},
		TestTeamDef:new{
			mercs = { "Grizzly", "Grunty", "Gus" },
			team_color = RGB(200, 0, 0),
			ai_control = true,
		},
	}
	
	if not HasGameSession() then
		NewGameSession()
	end
	
	-- generate units from merc defs
	g_Units = {}
	g_Teams = {}
	g_SquadsArray = {}
	--gv_UnitData = {}
	gv_Squads = {}
	gv_NextSquadUniqueId = 1
	gv_CurrentSectorId = gv_CurrentSectorId or "A1"
	gv_Sectors[gv_CurrentSectorId].Map = GetMapName()
	local seed = 0 -- tests should run consistently in order to be reproducible, so no AsyncRand here
	g_Combat.time_of_day = time_of_day or "day"
	Game.game_type = false
	if table.find(combat_params, "side", "player2") then
		Game.game_type = (not netGamePlayers or #netGamePlayers < 2) and "HotSeat" or "Competitive"
	end
	
	for i, team_def in ipairs(combat_params) do
		local combat_team = CombatTeam:new{ 
			control = team_def.ai_control and "AI" or "UI", 
			side = team_def.side or (team_def.ai_control or team_def:HasMember("enemy")) and "enemy1" or "player1", 
			team_color = team_def.team_color,
			spawn_marker_group = team_def.spawn_marker_group,
			dbgSquadIdx = i
		}
		combat_team.DisplayName = (team_def.team_name ~= "") and team_def.team_name or T{676161962248, "Team #<i>", i = i}
		local unit_ids = {}
		g_Teams[#g_Teams + 1] = combat_team
		for _, merc in ipairs(team_def.mercs) do
			local session_id = netInGame and string.format("%s_%s", merc, team_def.side) or merc
			local combat_unit = SpawnUnit(merc, session_id)
			unit_ids[#unit_ids+1] = session_id
			SendUnitToTeam(combat_unit, combat_team)
		end
		
		CreateNewSatelliteSquad({
			Name = _InternalTranslate(combat_team.DisplayName),
			UniqueId = i,
			Side = combat_team.side,
			units = unit_ids,
			CurrentSector = gv_CurrentSectorId,
		})
	end

	local combat_center = point(terrain.GetMapSize())/2
	for _, team in ipairs(g_Teams) do
		local markers, center, positions, angle, marker

		if team.spawn_marker_group ~= "" then
			markers = MapGetMarkers("Entrance", team.spawn_marker_group)
			if markers and #markers > 0 then
				marker, positions, angle = GetRandomSpawnMarkerPositions(markers, #team.units)
				assert(#positions == #team.units)
			else
				markers = MapGetMarkers("Position", team.spawn_marker_group)
				if markers and #markers > 0 then
					positions = {}
					for i = 1, #markers do
						positions[i] = markers[i]:GetPos()
						angle = angle or markers[i]:GetAngle()
					end
				end
			end
			center = #markers > 0 and AveragePoint(markers)
		end

		local team_center = center or #team.units > 0 and GetRandomTerrainVoxelPosAroundCenter(team.units[1], combat_center, 15*guim)
		markers = markers or empty_table
		positions = positions or empty_table

		for i, unit in ipairs(team.units) do
			if #positions > 0 then
				local idx = 1 + unit:Random(#positions)
				local pos = positions[idx]
				table.remove(positions, idx)
				unit:SetPos(pos)
				unit:SetAngle(angle)
			else
				local unit_pos = GetRandomTerrainVoxelPosAroundCenter(unit, team_center, 5*guim)
				unit:SetPos(unit_pos)
				unit:Face(combat_center)
			end

			local sessionId = unit.session_id
			local unitData = CreateUnitData(unit.unitdatadef_id, sessionId, seed)
			unitData.Squad = team.dbgSquadIdx
			unitData.already_spawned_on_map = true
			gv_UnitData[sessionId] = unitData
			local squad = gv_Squads[team.dbgSquadIdx]
			squad.units[#squad.units + 1] = sessionId
			unit.Squad = squad.UniqueId
			if team.side == "player1" or team.side == "player2" then
				unit.ControlledBy = team.side == "player1" and 1 or 2
				unitData.ControlledBy = team.side == "player1" and 1 or 2
			end
		end
	end
	
	MapForEach("map", "Unit", function(u)
		CreateUnitData(u.unitdatadef_id, u.session_id, 0)
	end)

	ViewPos(combat_center)
end

function DbgStartCombat(map, combat_params, time_of_day)
	local in_combat = not not g_Combat
	DbgStopCombat()
	if in_combat then
		CloseAllDialogs()
	end
	if not HasGameSession() then
		NewGameSession()
	end
	if g_Units and next(g_Units) then
		NetSyncEvent("ExplorationStartCombat")
		return
	end
	if map and (map ~= GetMapName() or in_combat) then
		CreateRealTimeThread(function(map, combat_params, time_of_day)
			ChangeMap(map)
			DbgStartCombat(map, combat_params, time_of_day)
		end, map, combat_params, time_of_day)
		return
	end
	CreateGameTimeThread(function()
		-- link dlg combat to satellite sector
		local dbg_sector = "A1"
		gv_Sectors[dbg_sector].Map = map
		gv_CurrentSectorId = dbg_sector
		gv_ActiveCombat = dbg_sector

		g_Combat = Combat:new{test_combat = true}
		InitTestCombat(g_Combat, combat_params, time_of_day)
		SetupTeamsFromMap()
		g_Combat:Start()
		ShowInGameInterface(true, false, { Mode = "IModeCombatMovement" })	
	end)
end

function DbgStopCombat()
	if g_Combat then
		g_Combat:End()
		DoneObject(g_Combat)
		g_Combat = false
	end
end

-- new test combat, simulating real game

function GetTestCombatSquadOptions()
	local squads = table.keys(EnemySquadDefs, true)
	table.insert(squads, 1, "CurrentPlayerSquad")
	return squads
end

if FirstLoad then
	g_TestCombat = false
	g_TriggerEnemySpawners = false
	g_DisableEnemySpawners = false
	g_TestExploration = false
end

function OnMsg.NewGameSessionStart()
	g_TestExploration = false
	g_TestCombat = false
	g_TriggerEnemySpawners = false
	g_DisableEnemySpawners = false
end

function TestCombatTest(def, obj, prop_id)
	return TestCombatEnterSector(def, def.map)
end

function TestCombatEnterSector(def, map)
	if not def then
		print("Invalid test combat def given", tostring(def))
		return
	end
	
	if GetMap() == "" then
		ChangeMap("__Empty")
		CloseAllDialogs()
	end
	-- we only want player squads from the old game session, all other data is initialized
	local old_unit_data = gv_UnitData
	local old_squads = gv_Squads
	local old_squads_arr = g_SquadsArray
	local old_next_id = gv_NextSquadUniqueId
	local old_playersquads = g_PlayerSquads
	local old_pandmsquads = g_PlayerAndMilitiaSquads
	local old_militiasquads = g_MilitiaSquads
	local old_enemysquads = g_EnemySquads
	local old_sectorData = gv_Sectors
	
	NewGameSession(nil, {difficulty = Game and Game.game_difficulty or "Normal"})
	local sector_id = def.sector_id
	local _, enemy = GetSquadsInSector(sector_id)
	local enemiesCopied = table.copy(enemy)
	for _, squad in ipairs(enemiesCopied) do
		RemoveSquad(squad)
	end

	gv_Sectors = next(old_sectorData) and old_sectorData or gv_Sectors
	gv_UnitData = old_unit_data or {}
	gv_Squads = old_squads or {}
	g_SquadsArray = old_squads_arr or {}
	g_PlayerSquads = old_playersquads or {}
	g_PlayerAndMilitiaSquads = old_pandmsquads or {}
	g_MilitiaSquads = old_militiasquads or {}
	g_EnemySquads = old_enemysquads or {}

	gv_NextSquadUniqueId = old_next_id or 1
	
	g_TestCombat = def
	g_TriggerEnemySpawners = def.trigger_enemy_spawners
	g_DisableEnemySpawners = def.disable_enemy_spawners

	Game.CampaignTime = CalculateTimeFromTimeOfDay(def.TimeOfDay) or 0
	Game.CampaignTimeStart = Game.CampaignTime

	if map and type(map) == "string" then
		map = map
	else
		map = def.map
	end
	if map then
		sector_id = sector_id or "A1"
		gv_Sectors[sector_id].Map = map
	end
	
	if def.reveal_intel then
		DiscoverIntelForSector(sector_id, "suppress notification")
	end
	
	for _, squad in ipairs(g_EnemySquads) do
		if squad.CurrentSector==sector_id then
			RemoveSquad(squad)
		end
	end
	
	local squad_to_spawn_markers = {}
	local game_spawn_logic = true
	local current_squad_def
	
	-- process test combat def squads
	local player_squads = GetPlayerMercSquads()
	if not next(player_squads) then
		local campaign = GetCurrentCampaignPreset()
		local id = CreateNewSatelliteSquad({Side = "player1", CurrentSector = sector_id, Name = Presets.SquadName.Player[1].Name}, GetTestCampaignSquad(), 14, 1234567)
		player_squads = {gv_Squads[id]}
	end
	
	game_spawn_logic = def.player_role
	for _, squad_def in ipairs(def.squads) do
		local tier = squad_def.tier
		local spawn_on_marker = squad_def.spawn_location == "On Marker"
		
		if squad_def.squad_type == "NPC" then
			local squad_id = GenerateEnemySquad(squad_def.npc_squad_id, sector_id, "TestCombat")
			local squad = gv_Squads[squad_id]
			TierUpSquad(squad, tier)
			if spawn_on_marker then
				squad_to_spawn_markers[squad.UniqueId] = {squad_def.spawn_marker_type or nil, squad_def.spawn_marker_group or nil}
			end
			squad.Side = squad_def.side
			local ally = SideIsAlly(squad_def.side, "player1")
			if (def.player_role == "attack" and ally) or (def.player_role == "defend" and not ally) then
				for _, session_id in ipairs(squad.units) do
					local unit = gv_UnitData[session_id]
					unit.arrival_dir = def.attacker_dir
					unit.already_spawned_on_map = false
				end
			end
		else -- player squad
			if squad_def.squad_type == "Custom" then
				for _, squad in ipairs(player_squads) do
					RemoveSquad(squad)
				end
				local id = CreateNewSatelliteSquad({Side = "player1", CurrentSector = sector_id, Name = Presets.SquadName.Player[1].Name}, squad_def.Mercs, 14, 1234567)
				local squad = gv_Squads[id]
				player_squads = { squad }
				if spawn_on_marker then
					squad_to_spawn_markers[squad.UniqueId] = {squad_def.spawn_marker_type or nil, squad_def.spawn_marker_group or nil}
				end
			end
		
			for _, squad in ipairs(player_squads) do
				TierUpSquad(squad, tier)
				squad.CurrentSector = sector_id
				if spawn_on_marker then
					squad_to_spawn_markers[squad.UniqueId] = {squad_def.spawn_marker_type or nil, squad_def.spawn_marker_group or nil}
				end
				for _, session_id in ipairs(squad.units) do
					local merc = gv_UnitData[session_id]
					merc.arrival_dir = not spawn_on_marker and def.attacker_dir
					merc.already_spawned_on_map = false
					merc.statGainingPoints = 20
				end
			end
		end
	end

	CloseDialog(GetPreGameMainMenu())
	CreateRealTimeThread( function()
		WaitMsg("PostNewMapLoaded")
		def:OnMapLoaded()
	end )
	CreateRealTimeThread( function()
		WaitMsg("CombatStart")
		def:OnCombatStart()
	end )
	EnterConflict(gv_Sectors[sector_id], nil, game_spawn_logic or "attack")
	LocalLoadSector(sector_id, game_spawn_logic, squad_to_spawn_markers)
end

function OnMsg.CanSaveGameQuery(query)
	query.test_combat = g_TestCombat or nil
end

function IgnoreSpawnEnemyConditions(obj)
	if obj:IsKindOf("UnitMarker") then
		for _, group in ipairs(g_TriggerEnemySpawners or empty_table) do
			if obj:IsInGroup(group) then
				return true
			end
		end
	end
end

function ForceDisableSpawnEnemy(obj)
	if obj:IsKindOf("UnitMarker") then
		for _, group in ipairs(g_DisableEnemySpawners or empty_table) do
			if obj:IsInGroup(group) then
				return true
			end
		end
	end
end

function TriggerEnemySpawnersCombo(combat_map)
	local groups = table.copy(GridMarkerGroupsCombo())
	local group_used = {}
	for _, group in ipairs(groups) do
		group_used[group] = true
	end
	
	local map_markers = g_DebugMarkersInfo and g_DebugMarkersInfo[combat_map]
	if map_markers then	
		for _, marker in ipairs(map_markers) do
			if marker.Groups then
				for _, group in ipairs(marker.Groups) do
					group_used[group] = true
				end
			end
		end
	end
	
	local groups_unique = table.keys2(group_used, true)
	table.insert(groups_unique, 1, "")

	return groups_unique
end

function GetCheatsTestCombatPresets()
	local items = {}
	for _, presets in ipairs(Presets.TestCombat) do
		for _, preset in ipairs(presets) do
			if preset.show_in_cheats then
				items[#items + 1] = preset
			end
		end
	end
	table.sort(items, function(a, b) return a.SortKey < b.SortKey end)
	return items
end

function PlaceBloodDecalDummy(appearance_name, weapon_name)
	local pos = GetTerrainCursor()
	local dummy_unit = PlaceObject("AppearanceObject")
	dummy_unit:ApplyAppearance(appearance_name or "Buns")
	dummy_unit:SetPos(pos)
	local unit = dummy_unit

	SetpieceSetStance.SetupActorWeapon(dummy_unit, weapon_name or "AUG")

	-- Please keep decals at a later slot...
	local dec1 = PlaceObject("DecSkBloodSplatter_01")
	unit:Attach(dec1, unit:GetSpotBeginIndex("Shoulderl"), true)
	dec1:SetAttachAxis(point(0,4096, 0))
	dec1:SetAttachAngle(60*90)
	dec1:SetAttachOffset(140, 0, 0)

	local dec2 = PlaceObject("DecSkBloodSplatter_01")
	unit:Attach(dec2, unit:GetSpotBeginIndex("Kneel"), true)
	dec2:SetAttachAxis(point(0,4096, 0))
	dec2:SetAttachAngle(60*90 + 180 * 60)
	dec2:SetAttachOffset(-40, 0, 0)

	local dec3 = PlaceObject("DecSkBloodSplatter_01")
	unit:Attach(dec3, unit:GetSpotBeginIndex("Weaponr"), true)
	dec3:SetAttachAxis(point(4096,0, 0))
	dec3:SetAttachAngle(60*90 + 90 * 90)
end

function AttachBloodDecal(unit, spot)
	local dec = PlaceObject("DecSkBloodSplatter_01")
	unit:Attach(dec, unit:GetSpotBeginIndex(spot), true)
	if spot == "Shoulderl" then
		dec:SetAttachAxis(point(0,4096, 0))
		dec:SetAttachAngle(60*90)
		dec:SetAttachOffset(140, 0, 0)
	elseif spot == "Kneel" then
		dec:SetAttachAxis(point(0,4096, 0))
		dec:SetAttachAngle(60*90 + 180 * 60)
		dec:SetAttachOffset(-40, 0, 0)
	elseif spot == "Weaponr" then
		dec:SetAttachAxis(point(4096,0, 0))
		dec:SetAttachAngle(60*90 + 90 * 90)
	end	
end

function TierUpSquad(squad, tier)
	if not squad or not squad.units then return end
	if tier == 1 then return end -- base tier no change needed
	
	for _, id in ipairs(squad.units) do
		local unit = gv_UnitData[id]
		
		-- stats
		local levelsToGain = 2 * (tier-1)
		local statsToGain = 3 * levelsToGain
		
		unit.Experience = XPTable[Min(unit:GetLevel() + levelsToGain, #XPTable)]
					
		local statProps = UnitPropertiesStats:GetProperties()
		for i = 1, statsToGain do
			local roll = InteractionRand(#statProps, "TestCombatTierUp") + 1
			local stat = statProps[roll].id
			
			local id = string.format("StatGain-%s-%s-%d", stat, unit.session_id, GetPreciseTicks())
			local mod = unit:AddModifier(id, stat, false, 1)
			--GainStat(unit, stat)
		end
		
		-- perks
		local perksToGain = levelsToGain
		
		local availablePerks = PresetArray(CharacterEffectCompositeDef)
		availablePerks = table.ifilter(availablePerks, function(i, perk)
			return perk.object_class == "Perk" and table.find({"Bronze", "Silver", "Gold"}, perk.Tier) and not HasPerk(unit, perk.id)
		end)
		
		table.sort(availablePerks, function(a, b)
			if unit[a.Stat] == unit[b.Stat] then
				if a.Tier == "Gold" and (b.Tier == "Silver" or b.Tier == "Bronze") then
					return true
				elseif a.Tier == "Silver" and b.Tier == "Bronze" then
					return true
				else
					return false
				end
			else
				return unit[a.Stat] > unit[b.Stat]
			end
		end)
		
		for _, perk in ipairs(availablePerks) do
			if perksToGain <= 0 then break end
			unit:AddStatusEffect(perk.id)
			perksToGain = perksToGain - 1
		end
		-- items
		
		local equipedItems, slots = unit:GetHandheldItems()
		for i, item in ipairs(equipedItems) do
			if IsKindOf(item, "Firearm") then
				local weaponType = InventoryItemDefs[item.class].object_class
				weaponType = g_Classes[weaponType].WeaponType
				
				local weapons = GetWeaponsByType(weaponType)
				table.sortby_field(weapons, "Cost")
				
				local weapon
				if tier == 2 and #weapons >= 2 then
					weapon = weapons[#weapons-1] 
				elseif tier >= 3 then
					weapon = weapons[#weapons]
				else
					break
				end
				
				local weaponObj = PlaceInventoryItem(weapon.id)
				unit:RemoveItem(slots[i], item)
				unit:AddItem(slots[i], weaponObj)
				
				local ammos = GetAmmosWithCaliber(weapon.Caliber)
				local ammoKey = table.find(ammos, "colorStyle" , "AmmoBasicColor")
				if not ammoKey then
					ammoKey = 1
				end
				local ammo = PlaceInventoryItem(ammos[ammoKey].id)
				ammo.Amount = ammo.MaxStacks
				unit:AddItem("Inventory", ammo)

			end
		end
	end
end

function TestCombatStartFromAltShortcut(shortcut)
	local testCombat
	for _, presets in ipairs(Presets.TestCombat) do
		local foundTestIndex = table.find(presets, "Alt_Shortcut", shortcut) or false
		if foundTestIndex then 
			testCombat = presets[foundTestIndex] 
			TestCombatEnterSector(testCombat, testCombat.map)
			return
		end
	end
	print("No test combat found at shortcut: ", shortcut)
end
