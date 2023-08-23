DefineClass.ExitZoneInteractable = {
	__parents = { "EditorVisibleObject", "Interactable", "Object", "GridMarker" },
	properties = {
		{ category = "Enabled Logic", editor = "bool", id = "HideVisualWhenDisabled", default = false },
		{ category = "Travel", editor = "combo", id = "SectorOverride", items = function() return GetCampaignSectorsCombo() end, default = false },
		{ category = "Travel", editor = "bool", id = "IsUnderground", default = false },
		{ category = "Travel", editor = "bool", id = "RetreatInConflictOnlyIfCameFromHere", default = false },
		{ category = "Travel", editor = "choice", name = "Entity", id = "entity", items = function() return table.get(Presets, "EntityVariation", "Default", "TravelObject", "Entities") or { "UITravelObject_01" } end, default = "UITravelObject_01" },
	},

	-- Change in GridMarkerType editor
	AreaWidth = 5,
	AreaHeight = 5,
	
	BadgePosition = "average",
	Type = "ExitZoneInteractable",
	
	fake_visual_obj = false, -- Object to be used when one isn't explicitly placed
	discovered = true
}

function ExitZoneInteractable:InitFakeVO()
	if not self.fake_visual_obj then
		local obj = PlaceObject(self.entity)
		obj:SetColorizationPalette(g_DefaultColorsPalette)
		obj:SetEnumFlags(const.efSelectable)
		obj:ClearGameFlags(const.gofPermanent)
		obj:SetCollision(false)
		obj.spawner = self
		self.fake_visual_obj = obj
		if self.visuals_cache then
			self.visuals_cache[#self.visuals_cache + 1] = self.fake_visual_obj
		end
	end
end

function ExitZoneInteractable:GameInit()
	self:InitFakeVO()
	self:EvaluateNeedForFakeVisual()
end

function ExitZoneInteractable:Done()
	if self.fake_visual_obj then
		DoneObject(self.fake_visual_obj)
		self.fake_visual_obj = false
	end
end

function ExitZoneInteractable:Setentity(value)
	self:ChangeEntity(value)
	if IsValid(self.fake_visual_obj) then
		self.fake_visual_obj:ChangeEntity(value)
		self.fake_visual_obj:SetColorizationPalette(g_DefaultColorsPalette)
	end
	self:SetColorizationPalette(g_DefaultColorsPalette)
	self.entity = value
end

function ExitZoneInteractable:PopulateVisualCache()
	Interactable.PopulateVisualCache(self)
	table.remove_value(self.visuals_cache, self) -- ExitZoneInteractable is never its own visual.
	
	local visuals = self.visuals_cache
	for i, obj in ipairs(visuals) do
		if IsKindOf(obj, "Interactable") then
			obj.visual_of_interactable = self
		end
	end
	
	if self.fake_visual_obj then self.visuals_cache[#self.visuals_cache + 1] = self.fake_visual_obj end
end

local function lUpdateVisualsOfExitZoneInteractables()
	FireNetSyncEventOnHost("UpdateVisualsOfExitZoneInteractables")
end

function NetSyncEvents.UpdateVisualsOfExitZoneInteractables()
	MapForEach("map", "ExitZoneInteractable", ExitZoneInteractable.EvaluateNeedForFakeVisual)
end

OnMsg.ExplorationStart = lUpdateVisualsOfExitZoneInteractables
OnMsg.DeploymentStarted = lUpdateVisualsOfExitZoneInteractables

function ExitZoneInteractable:EvaluateNeedForFakeVisual()
	self:InitFakeVO()

	local visualObjects = ResolveInteractableVisualObjects(self)
	local shouldHave
	if #visualObjects == 0 then
		shouldHave = true
	elseif #visualObjects <= 2 then
		local o1, o2 = visualObjects[1], visualObjects[2]
		if (not o1 or o1 == self or o1 == self.fake_visual_obj) and
			(not o2 or o2 == self or o2 == self.fake_visual_obj) then
			shouldHave = true
		end
	end

	if shouldHave and self.HideVisualWhenDisabled and not self:IsMarkerEnabled() then
		shouldHave = false
	end
	
	local nextSector = self:GetNextSector()
	if not nextSector then
		shouldHave = false
	end
	
	shouldHave = shouldHave or IsEditorActive()
	if shouldHave then	
		self.fake_visual_obj:SetEnumFlags(const.efVisible)
		self.fake_visual_obj:SetCollision(true)
	else
		self.fake_visual_obj:ClearEnumFlags(const.efVisible)
		self.fake_visual_obj:SetCollision(false)
	end
	
	local dirs = {
		point(const.SlabSizeX, 0, 0),
		point(const.SlabSizeX, 0, 0),
		point(0, const.SlabSizeY, 0),
		point(0, -const.SlabSizeY, 0)
	}
	
	local spotForFakeInteractable = false
	for i, d in ipairs(dirs) do
		local voxel = self:GetPos() + d
		local bbox = GetVoxelBBox(voxel)
		local any = MapGetFirst(bbox, "GridMarker")	-- NOTE: enumerating in the voxel may be faster than all GridMarkers
		if not any then
			spotForFakeInteractable = voxel
			break
		end
	end
	
	self.fake_visual_obj:SetPos(spotForFakeInteractable)
	self.fake_visual_obj:SetAngle(self:GetAngle())
end

function ExitZoneInteractable:EditorEnter()
	EditorVisibleObject.EditorEnter(self)
	self:EvaluateNeedForFakeVisual()
end

function ExitZoneInteractable:EditorExit()
	EditorVisibleObject.EditorExit(self)
	Interactable.EditorExit(self)
	self:EvaluateNeedForFakeVisual()
end

function ExitZoneInteractable:EditorCallbackMove()
	self:EvaluateNeedForFakeVisual()
end

function ExitZoneInteractable:EditorCallbackRotate()
	self:EvaluateNeedForFakeVisual()
end

function ExitZoneInteractable:EditorCallbackPlace()

end

function ExitZoneInteractable:GetNextSector()
	if not gv_CurrentSectorId then return false end

	local sectorId, underground = false, false
	if self:IsUndergroundExit() then
		sectorId = gv_Sectors[gv_CurrentSectorId].GroundSector or (gv_CurrentSectorId .. "_Underground")
		underground = self.Groups[1]
	else
		for _, dir in ipairs(const.WorldDirections) do
			if self:IsInGroup(dir) then
				local neighSectorId = GetNeighborSector(gv_CurrentSectorId, dir)
				if neighSectorId and
					not IsTravelBlocked(gv_CurrentSectorId, neighSectorId) and
					not GetDirectionProperty(neighSectorId, gv_CurrentSectorId, "BlockTravelRiver") and
					gv_Sectors[neighSectorId].Map then
					
					sectorId = neighSectorId
					break
				end
			end
		end
	end
	
	if self.SectorOverride then
		sectorId = self.SectorOverride
	end

	return gv_Sectors[sectorId], underground
end

function ExitZoneInteractable:IsUndergroundExit()
	return self:IsInGroup("Underground") or self.IsUnderground
end

function ExitZoneInteractable:BadgeTextUpdate()
	local withCursor = table.find(self.highlight_reasons, "cursor")
	local badgeInstance = self.interactable_badge
	if not badgeInstance or badgeInstance.ui.window_state == "destroying" then return end
	
	if IsUnitPartOfAnyActiveBanter(self) then
		badgeInstance.ui.idText:SetVisible(false)
		return
	end
	
	local unit = UIFindInteractWith(self)
	if unit then	
		local currentSect = gv_Sectors[gv_CurrentSectorId]
		if not currentSect then return end

		local nextSect, underground = self:GetNextSector()
		local nextMapName = nextSect and GetSectorText(nextSect)
		local action = self:GetInteractionCombatAction(unit)
		badgeInstance.ui.idText:SetContext(unit)
		
		local text = action:GetActionDisplayName({unit, self})
		if gv_CurrentSectorId == "A1" then
			text = Untranslated("Cant Travel in Exploration Test")
		elseif underground then
			if IsSectorUnderground(gv_CurrentSectorId) then
				text = T(705526346094, "Exit")
			else
				text = T(749506366915, "Go Underground")
			end
		elseif currentSect.conflict then
			text = T(482029101969, "Retreat To <Map>")
		else
			text = T(500843659226, "Exit To <Map>")
		end

		badgeInstance.ui.idText:SetText(T{text, Map = nextMapName})
	end
	badgeInstance.ui.idText:SetVisible(withCursor)
end

function ExitZoneInteractable:GetInteractionCombatAction(unit)
	if not self:IsMarkerEnabled() then return false end
	if gv_DeploymentStarted then return false end
	
	if self.RetreatInConflictOnlyIfCameFromHere then
		local group = self.Groups
		group = group and group[1]
		
		local sector = gv_Sectors[gv_CurrentSectorId]
		if sector and sector.conflict and unit and unit.arrival_dir ~= group then
			return false
		end
	end

	local sector = gv_Sectors[gv_CurrentSectorId]
	if sector and sector.conflict and sector.conflict.disable_travel then return false end
	
	local nextSector = self:GetNextSector()
	if not nextSector then
		return false
	end

	if unit and (unit:IsDowned() or unit:IsDead()) then
		return false
	end

	return CombatActions.Interact_Exit
end

MapVar("g_RetreatThread", false)

function ExitZoneInteractable:UnitLeaveSector(unit)
	if IsValidThread(g_RetreatThread) then return end
	g_RetreatThread = CreateRealTimeThread(ExitZoneInteractable.UnitLeaveSectorInternal, self, unit)
end

function ExitZoneInteractable:IsUnitInside(u)
	local entranceMarker = MapGetMarkers("Entrance", self.Groups and self.Groups[1])
	entranceMarker = entranceMarker and entranceMarker[1] or self
	return self:IsInsideArea(u) or entranceMarker:IsInsideArea(u)
end

-- Original Spec: http://mantis.haemimontgames.com/view.php?id=147486
-- Cases
-- 1. Conflict All Units
--	2. Conflict Partial Units
--	3. No Conflict All Units
--	4. No Conflict Partial Units
-- Subcases, apply these to to each of the above cases.
--	1. Going towards a sector with travel time 0 (cities/roads)
--	2. Going towards a sector with travel time above 0
--	3. To Underground
--	4. To Overground
function ExitZoneInteractable:UnitLeaveSectorInternal(unit)
	if not unit:CanBeControlled() then return end

	local sector, underground = self:GetNextSector()
	if not sector then return end
	local sector_id = sector.Id
	
	local playerSquads = GetSquadsOnMap()
	local leavingSquads = {}
	for i, squadId in ipairs(playerSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
	
		-- Find which units can leave
		local thisSquadHasLeavingUnit = false
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u and u:IsLocalPlayerControlled() and self:IsUnitInside(u) and self:IsMarkerEnabled() then
				thisSquadHasLeavingUnit = true
				break
			end
		end
		if thisSquadHasLeavingUnit then
			leavingSquads[#leavingSquads + 1] = squadId
		end
	
		::continue::
	end
	
	local leavingUnits = {}
	for i, squadId in ipairs(leavingSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
		
		-- Check if the squad has any tired units
		local exhausted = GetSquadTiredUnits(squad, "Exhausted")
		if exhausted then
			local exhausted_ids = ShowExhaustedUnitsQuestion(squad, exhausted)
			if exhausted_ids then
				-- This needs to be sync so that the split happens completely before we proceed with the exit.
				-- This function it self isn't sync due to various UI popups etc.
				SyncSplitSquad(squad.UniqueId, exhausted_ids)
				ObjModified("hud_squads")
			else
				goto continue
			end
		end
	
		-- Find which units can leave
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u and u:CanBeControlled() and self:IsUnitInside(u) and self:IsMarkerEnabled() then
				table.insert(leavingUnits, u.session_id)
			end
		end
		
		::continue::
	end
	
	local spawned_units = 0
	for i, squadId in ipairs(playerSquads) do
		local squad = gv_Squads[squadId]
		if not squad then goto continue end
		
		for _, id in ipairs(squad.units or empty_table) do
			local u = g_Units[id]
			if u then
				spawned_units = spawned_units + 1
			end
		end
		
		::continue::
	end
	
	-- All were filtered out.
	if #leavingUnits == 0 then return end

	if gv_Sectors[gv_CurrentSectorId].conflict then
		LeaveSectorConflict(sector_id, leavingUnits, underground, spawned_units, unit)
	else
		LeaveSectorExploration(sector_id, leavingUnits, underground, nil, unit:IsLocalPlayerControlled())
	end
end

function GetExitZoneInteractableFromMarker(marker)
	if not marker then return end
	local exitInteractable = MapGetMarkers("ExitZoneInteractable", marker.Groups and marker.Groups[1])
	return exitInteractable and exitInteractable[1]
end

function LeaveSectorConflict(sectorId, units, underground, totalPlayerUnits, initiatingUnit)
	local names = {}
	for _, u in ipairs(units) do
		local unitData = gv_UnitData[u]
		names[#names + 1] = _InternalTranslate(unitData.Nick)
	end
	names = table.concat(names, ", ")
	
	local initiatedByLocalPlayer = initiatingUnit:IsLocalPlayerControlled()
	local state_func = nil
	if not initiatedByLocalPlayer then
		state_func = function() return "disabled" end
	end
	local three_choices = #units > 1
	local res = WaitPopupChoice(GetInGameInterfaceModeDlg(), {
		translate = true,
		text = T{867511434762, "Do you want to retreat the following mercs - <u(names)>?", names = names},
		choice1 = three_choices and T(288455844681, "Retreat All") or T(1138, "Yes"),
		choice1_state_func = state_func,
		choice1_gamepad_shortcut = "ButtonX",
		choice2 = three_choices and T{162642612318, "Retreat <merc>", merc = initiatingUnit.Nick} or T(967444875712, "Cancel"),
		choice2_state_func = three_choices and state_func or nil,
		choice2_gamepad_shortcut = three_choices and "ButtonY" or "ButtonB",
		choice3 = three_choices and T(1000246, "Cancel") or nil,
		choice3_gamepad_shortcut = "ButtonB",
		sync_close = initiatedByLocalPlayer,
	})
	
	if res == 1 then

	elseif res == 2 and three_choices then
		units = {initiatingUnit.session_id}
	else
		return
	end
	
	if #units < totalPlayerUnits then
		NetSyncEvent("RetreatUnits", units, sectorId, underground, totalPlayerUnits - #units)
	else
		LeaveSectorExploration(sectorId, units, underground, true)
	end
end

function WaitQuestion_ZuluSync(parent, caption, text, ok_text, cancel_text, obj, localPlayer)
	--creates a question box that has it's ok enabled only for localPlayer == true
	--cancel is enabled for all clients to evade failure states
	--cancel/ok on localPlayer == true closes box on all clients
	assert(type(parent) == "table" and parent.IsKindOf and parent:IsKindOf("XWindow"), "The first argument must be a parent window. Don't just create 'global' messages, attach them to the correct parent so they'd share their lifetimes.", 1)
	local dialog
	if IsKindOf(caption, "XDialog") then
		dialog = caption
	else
		local func = nil
		if not localPlayer then
			func = function() return "disabled" end
		end
		dialog = CreateQuestionBox(parent, caption, text, ok_text, cancel_text, obj, func, nil, nil, localPlayer)
	end
	local result, dataset, xInputStateAtClose = dialog:Wait() 
	return result, dataset, xInputStateAtClose
end

function LeaveSectorExploration(sectorId, units, underground, skipNotify, localPlayer)
	if not skipNotify then
		local popupText
		if underground then
			if IsSectorUnderground(gv_CurrentSectorId) then
				popupText = T(528652976882, "Are you sure you want to exit?")
			else
				popupText = T(261972368205, "Are you sure you want to go underground?")
			end
		else
			popupText = T{397573113952, "Are you sure you want to leave sector <SectorName(current_sector)> and enter sector <SectorName(next_sector)>?", 
				current_sector = gv_Sectors[gv_CurrentSectorId],
				next_sector = gv_Sectors[sectorId],
			}
		end
		
		if WaitQuestion_ZuluSync(GetInGameInterfaceModeDlg(), T(814633909510, "Confirm"), popupText, T(689884995409, "Yes"), T(782927325160, "No"), nil, localPlayer) ~= "ok" then
			return
		end
	end
			
	local special_entrance = underground
	local squads = {}
	for i, u in ipairs(units) do
		local unit = g_Units[u] or gv_UnitData[u]
		local squadId = unit.Squad
		table.insert_unique(squads, squadId)
	end
	
	-- Check for busy squads
	local squadsToMove = {}
	for i, sqId in ipairs(squads) do
		local squad = gv_Squads[sqId]
		local squadToMove = CheckSquadBusy(sqId)
		if squadToMove then 
			squadsToMove[#squadsToMove + 1] = squadToMove
		end
	end
	if #squadsToMove == 0 then return end

	NetSyncEvent("LeaveSectorMap", sectorId, false, special_entrance, squadsToMove)
end

-- Map retreat from non-adjacent sectors is possible when
-- an exit zone interactable has its destination overriden.
-- In these cases travel instantly.
function AreAdjacentSectors(s1Id, s2Id)
	return GetSectorDistance(s1Id, s2Id) <= 1
end

function RetreatMoveWholeSquad(squad_id, to_sector_id, from_sector_id)
	local squad = gv_Squads[squad_id]
	local route = {{to_sector_id}}
	local time = AreAdjacentSectors(from_sector_id, to_sector_id) and GetSectorTravelTime(from_sector_id, to_sector_id, route, squad.units) or 0
	local instant = not time or time <= 0
	
	local from_sector = gv_Sectors[from_sector_id]
	local to_sector = gv_Sectors[to_sector_id]
	if to_sector.GroundSector or from_sector.GroundSector then
		instant = true
	end
	
	if not instant then
		-- Tick needs to be considered passed in order for the squad to be considered travelling.
		route.satellite_tick_passed = true
		SetSatelliteSquadRetreatRoute(squad, route, "keepJoiningSquads", "from_map")
	else
		squad.Retreat = false
		if not gv_SatelliteView then SyncUnitProperties("map") end
		SetSatelliteSquadCurrentSector(squad, to_sector_id, "update_pos", "teleported")
		-- For player units we need to sync back to the unit as they will sync back to the unit data in the despawn function
		if not gv_SatelliteView then SyncUnitProperties("session") end
	end
	return instant
end

local function lMoveWholeSquadTacticalView(squad_id, sector_id)
	return RetreatMoveWholeSquad(squad_id, sector_id, gv_CurrentSectorId)
end

function RetreatUnit(unit, sector_id)
	Msg("UnitRetreat", unit)
	local team = unit.team
	unit:Despawn()
	gv_UnitData[unit.session_id].retreat_to_sector = sector_id
	if g_Combat then
		if g_Teams[g_CurrentTeam] == team then
			g_Combat:NextUnit(team, "force")
		end
		g_Combat:CheckEndTurn()
	end
	ObjModified(Game)
	ObjModified(Selection)
	ObjModified("hud_squads")
end

function CancelUnitRetreat(ud)
	-- Try to get the units in the direction they retreated to
	if IsSectorUnderground(ud.retreat_to_sector) then
		ud.arrival_dir = "Underground"
	else
		local dirToRetreatSector = GetSectorDirection(gv_CurrentSectorId, ud.retreat_to_sector)
		ud.arrival_dir = dirToRetreatSector
	end

	ud.retreat_to_sector = false
	ud.already_spawned_on_map = false
end

-- Used for resuming retreat if the last units on the map die
GameVar("gv_LastRetreatedUnit", false)
GameVar("gv_LastRetreatedEntrance", false)

function NetSyncEvents.RetreatUnits(session_ids, sector_id, underground, remaining)
	local units = {}
	for _, id in ipairs(session_ids) do
		local unit = g_Units[id]
		if not unit then
			assert(false, "Trying to retreat non existent unit")
			return
		end
		units[#units + 1] = unit
	end

	-- When retreating in conflict force cancel operations of units. (219850)
	SectorOperation_CancelByGame(units)

	-- Record in case the rest of the units die.
	-- We need to call LeaveSectorExploration then.
	gv_LastRetreatedUnit = #session_ids > 0 and session_ids[1]
	gv_LastRetreatedEntrance = { sector_id, underground }

	local check_squads = {}
	for _, unit in ipairs(units) do
		RetreatUnit(unit, sector_id)
		table.insert_unique(check_squads, unit.Squad)
	end
	
	-- check if there are new squads with all mercs retreated
	for _, id in ipairs(check_squads) do
		local retreat_whole_squad = true
		local squad = gv_Squads[id]
		for _, unit in ipairs(squad.units or empty_table) do
			if not gv_UnitData[unit].retreat_to_sector then
				retreat_whole_squad = false
				break
			end
		end
		if retreat_whole_squad then
			lMoveWholeSquadTacticalView(squad.UniqueId, sector_id)
		end
	end
	EnsureCurrentSquad()
	ShowTacticalNotification("allyRetreat", nil, T(312444150797, "Retreated successfully"), { number = remaining })
end

function SyncSplitSquad(squad_id, available)
	assert(CanYield())
	NetSyncEvent("SplitSquad", squad_id, available)
	local err, newSquad, oldSquad
	while oldSquad ~= squad_id do
		err, newSquad, oldSquad = WaitMsg("SyncSplitSquad", 1000)
		if err then
			break
		end
	end
	return newSquad
end

function CheckSquadBusy(squad_id)
	local busy, available = GetSquadBusyAvailable(squad_id)
	if next(busy) then
		local res = GetSplitMoveChoice(busy, available)
		if res == "split" then
			return SyncSplitSquad(squad_id, available)
		elseif res == "cancel" then
			return false
		end
	end
	return squad_id
end

function NetSyncEvents.LeaveSectorMap(dest_sector_id, spawn_mode, special_entrance, squad_ids)
	if g_Combat and not g_Combat.combat_started then return end
	if IsSetpiecePlaying() then return end

	SectorOperation_SquadOnMove(gv_CurrentSectorId, squad_ids)

	local squads = GetSquadsWithIds(squad_ids)
	local curSector = gv_Sectors[gv_CurrentSectorId]

	-- Apply unaware to non-player units when leaving the map.
	-- This will be synced to the unit data inside MoveWholeSquad
	for _, unit in ipairs(g_Units) do
		if unit.team and not unit.team.player_team then
			unit:AddStatusEffect("Unaware")
		else
			if unit:HasStatusEffect("ManningEmplacement") then
				unit:LeaveEmplacement("instant")
			elseif unit:HasStatusEffect("StationedMachineGun") then
				unit:MGPack()
			end
		end
	end

	-- travel or teleport to other sector instantly
	local satellite = false
	for i, squad in ipairs(squads) do
		-- stop operations
		if dest_sector_id ~= squad.CurrentSector then
			local units = squad.units
			SectorOperation_CancelByGame(units, false, true)
		end

		-- move
		local instant = lMoveWholeSquadTacticalView(squad.UniqueId, dest_sector_id)
		satellite = satellite or not instant
		
		for _, id in ipairs(squad.units) do
			local unit = g_Units[id]
			if unit then
				RetreatUnit(unit, dest_sector_id)
			end
		end
		
		-- Clear retreat flag from units
		for _, u in ipairs(squad.units) do
			local ud = gv_UnitData[u]
			ud.retreat_to_sector = false
		end
		
		-- Overwrite arrival direction with special entrance if any.
		-- This will affect the deployment on the new sector.
		if special_entrance then
			for _, u in ipairs(squad.units) do
				local ud = gv_UnitData[u]
				ud.arrival_dir = special_entrance
			end
		end
	end
	
	local conflict = curSector.conflict
	local bRetreat = false
	for i, squad in ipairs(squads) do
		if conflict then
			if satellite then squad.Retreat = true end
			bRetreat = true
		end
	end
	
	if conflict then
		ResolveConflict(curSector, bRetreat and "no_voice", false, bRetreat)
	end
	
	-- Retreat triggered while in satellite mode, such as by a merc release.
	-- In this case don't force an explore as it can be jarring.
	if gv_SatelliteView then return end
	
	if satellite then
		ForceReloadSectorMap = true
		LocalCheckUnitsMapPresence()
		CreateRealTimeThread(function()
			OpenSatelliteView()
			SetCampaignSpeed(Game.CampaignTimeFactor, "UI")
		end)
	else
		if not spawn_mode then
			local destSector = gv_Sectors[dest_sector_id]
			spawn_mode = destSector and destSector.conflict and "attack" or "explore"
		end
		CreateGameTimeThread(function()
			LoadSector(dest_sector_id, spawn_mode) --pause wants to yield, but it can't
		end)
	end
end

-- Promote half-way retreating squads into full retreating squads should all their units have been released.
function OnMsg.MercReleased(_, squadId)
	local squad = gv_Squads[squadId]
	if not squad then return end
	
	local squadUnitsLeft = squad.units
	local allRetreating, retreatingTo = true, false
	for i, u in ipairs(squadUnitsLeft) do
		local ud = gv_UnitData[u]
		if not ud.retreat_to_sector then
			allRetreating = false
		elseif not retreatingTo then
			retreatingTo = ud.retreat_to_sector
		end
	end
	if allRetreating then
		local currentSector = squad.CurrentSector
		local underground = currentSector .. "_Underground" == retreatingTo or retreatingTo .. "_Underground" == currentSector
		LeaveSectorExploration(retreatingTo, squadUnitsLeft, underground, true)
	end
end

MapVar("gv_RetreatOrTravelOption", false)

function CheckRetreatButtonVisibility()
	local selectedUnit = Selection and Selection[1]
	if not selectedUnit or not selectedUnit:CanBeControlled() then
		gv_RetreatOrTravelOption = false
		ObjModified("gv_RetreatOrTravelOption")
		return
	end

	local markers = MapGetMarkers("Entrance")
	for i, m in ipairs(markers) do
		if m:IsMarkerEnabled() and m:IsInsideArea(selectedUnit) then
			local exitInteractable = MapGetMarkers("ExitZoneInteractable", m.Groups and m.Groups[1])
			exitInteractable = exitInteractable and exitInteractable[1]
			
			if exitInteractable and exitInteractable:GetInteractionCombatAction(selectedUnit) then
				gv_RetreatOrTravelOption = exitInteractable
				ObjModified("gv_RetreatOrTravelOption")
				return
			end
		end
	end
	
	gv_RetreatOrTravelOption = false
	ObjModified("gv_RetreatOrTravelOption")
end

OnMsg.ExplorationTick = CheckRetreatButtonVisibility
OnMsg.CombatGotoStep = CheckRetreatButtonVisibility
OnMsg.SelectedObjChange = CheckRetreatButtonVisibility
OnMsg.SelectionChange = CheckRetreatButtonVisibility
OnMsg.TurnStart = CheckRetreatButtonVisibility
OnMsg.RepositionEnd = CheckRetreatButtonVisibility

function GetClosestExitZoneInteractable(pos_or_obj)
	local closestExitZone = false
	MapForEach("map", "ExitZoneInteractable", function(o)
		if not closestExitZone then
			closestExitZone = o
			return
		end
		closestExitZone = closestExitZone and IsCloser(pos_or_obj, o, closestExitZone) and o or closestExitZone
	end)
	
	return closestExitZone
end

if Platform.developer then
local function lCheckMapEntrances(campaign_preset, sector, errors)
	errors = errors or {}

	local sectors = campaign_preset.Sectors or empty_table
	local directions = { }
	for _, dir in ipairs(const.WorldDirections) do
		local neighSectorId = GetNeighborSector(sector.Id, dir, campaign_preset)
		if neighSectorId then
			local sector = table.find_value(sectors, "Id", neighSectorId)
			if sector and sector.Passability ~= "Blocked" then
				directions[#directions + 1] = dir
			end
		end
	end
	
	local blockedTravel = sector.BlockTravel or empty_table
	for i, dir in ipairs(directions) do
		if not blockedTravel[dir] and not next(MapGetMarkers("ExitZoneInteractable", dir)) then
			errors[#errors + 1] = string.format("No ExitZoneInteractable on map '%s' for direction '%s'", GetMapName(), dir)
		end
	end
	
	return errors
end

function OnMsg.SaveMap()
	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local campaign_preset = campaign_presets[campaign]

	local sectors = campaign_preset and campaign_preset.Sectors or empty_table
	
	local sector = false
	for i, s in ipairs(sectors) do
		if s.Map == CurrentMap then
			sector = s
			break
		end
	end
	if not sector or sector.GroundSector then return end
	
	local errors = lCheckMapEntrances(campaign_preset, sector)
	for i, err in ipairs(errors) do
		StoreErrorSource(i, err)
	end
end

function CheckEntrancesOfAllMaps()
	if not CanYield() then
		CreateRealTimeThread(CheckEntrancesOfAllMaps)
		return
	end

	local campaign = Game and Game.Campaign or rawget(_G, "DefaultCampaign") or "HotDiamonds"
	local campaign_presets = rawget(_G, "CampaignPresets") or empty_table
	local campaign_preset = campaign_presets[campaign]

	local sectors = campaign_preset and campaign_preset.Sectors or empty_table
	local maps = {}
	local mapToSector = {}
	for i, s in ipairs(sectors) do
		if s.Map and not s.GroundSector then
			maps[#maps + 1] = s.Map
			mapToSector[s.Map] = s
		end
	end
	
	local errors = {}
	ForEachMap(maps, function()
		local sector = mapToSector[CurrentMap]
		errors = lCheckMapEntrances(campaign_preset, sector, errors)
	end)

	while IsChangingMap() do Sleep(100) end

	for i, err in ipairs(errors) do
		StoreErrorSource(false, err)
	end
	Inspect(errors)
end
end