GameVar("gv_Deployment", false)
GameVar("gv_DeploymentStarted", false)
GameVar("gv_DeploymentDir", false)
MapVar("gv_Redeployment", false)
MapVar("RedeploymentThread", false)

DefineClass.DeploymentMarker = {
	__parents = {"GridMarker"},
	
	properties = {
		{ category = "Grid Marker", id = "Type", name = "Type", editor = "dropdownlist", items = {"DeployArea"}, default = "DeployArea", no_edit = true },
		{ category = "Marker", id = "Reachable", name = "Reachable only", editor = "bool", default = false, help = "Area of marker includes only tiles reachable from marker position, not the entire rectangle"},
		{ category = "Marker", id = "GroundVisuals", name = "Ground Visuals", editor = "bool", default = true, help = "Show ground mesh on the marker area"},
		{ category = "Trigger Logic", id = "Trigger", name = "Trigger", editor = "dropdownlist", items = { "always", }, default = "always", no_edit = true},
		{ category = "Trigger Logic", id = "TriggerEffects", name = "Effects", editor = "nested_list", base_class = "Effect", default = false, no_edit = true},
		{ category = "Deployment", id = "AlternateEntrance", name = "Alternate Entrance", editor = "bool", default = false},
	},
}

function DeploymentMarker:Init()
	self:UpdateVisuals(self.Type, true)
end 

function DeploymentMarker:TriggerThreadProc()
end

function DeploymentMarker:IsAreaVisible()
	return IsEditorActive() or gv_DeploymentStarted and self:IsMarkerEnabled()
end

local deploy_types = {"Entrance", "Defender", "DefenderPriority", "DeployArea"}
function IsDeployMarker(marker)
	return not not table.find(deploy_types, marker.Type)
end

function GetAvailableEntranceMarkers(arrival_dir)
	-- Entrance markers are always enabled as mercs can enter from there.
	-- There are quest cases in which we might want to disable them though, which is denoted by gv_Deployment
	local markers 
	if gv_Deployment ~= "custom" then
		markers = MapGetMarkers("Entrance", g_GoingAboveground and "Underground" or arrival_dir, function(marker)
			return marker:IsMarkerEnabled()
		end)
	else
		markers = {}
	end
	if not g_GoingAboveground then
		-- Add alt entrance deployment markers.
		local additionalEntrances = MapGetMarkers("DeployArea", arrival_dir, function(marker)
			return marker:IsMarkerEnabled()
		end)
		table.iappend(markers, additionalEntrances)

		MapForEach("map", "DeploymentMarker", function (marker, markers)
			if not marker.AlternateEntrance and marker:IsMarkerEnabled() then
				markers[#markers + 1] = marker
			end
		end, markers)
	end
	
	return markers
end

function GetAvailableDeploymentMarkers(some_unit)
	local markers = {}
	some_unit = some_unit or SelectedObj
	if gv_Deployment == "defend" then
		markers = MapGetMarkers("Defender", false, function(m) return m:IsMarkerEnabled() end)
		local player_side = NetPlayerSide()
		local non_blocked_markers = {}
		for _, marker in ipairs(markers) do
			local area = marker:GetAreaBox()
			local blocked = false
			for _, unit in ipairs(g_Units) do
				if SideIsEnemy(player_side, unit.team.side) and not unit:IsDead() and area:Point2DInside(unit) then
					blocked = true
					break
				end
			end
			if not blocked then
				table.insert(non_blocked_markers, marker)
			end
		end
		
		return #non_blocked_markers > 0 and non_blocked_markers or {markers[1]}
	elseif some_unit then
		markers = GetAvailableEntranceMarkers(some_unit.arrival_dir)
	end
	return markers
end

function GetEnemyDeploymentMarkers()
	local markers = {}
	local _, enemy_squads = GetSquadsInSector(gv_CurrentSectorId)
	for _, squad in ipairs(enemy_squads) do
		local dir = squad.units and squad.units[1] and gv_UnitData[squad.units[1]] and gv_UnitData[squad.units[1]].arrival_dir
		if dir then
			local available = GetAvailableEntranceMarkers(dir)
			for _, marker in ipairs(available) do
				table.insert_unique(markers, marker)
			end
		end
	end
	return markers
end

function UpdateAvailableDeploymentMarkers()
	if gv_DeploymentStarted then
		local enemy_markers = GetEnemyDeploymentMarkers()
		local available = GetAvailableDeploymentMarkers()
		MapForEachMarker("GridMarker", nil, function(marker)
			if IsDeployMarker(marker) then
				if not table.find_value(available, marker) then
					marker:HideArea()
					DeleteBadgesFromTargetOfPreset("DeploymentAreaBadge", marker)
				else
					if not TargetHasBadgeOfPreset("DeploymentAreaBadge", marker) then
						CreateBadgeFromPreset("DeploymentAreaBadge", marker)
					end
					if not marker:IsAreaShown() then
						marker:ShowArea()
					end
				end
				if gv_Deployment == "defend" then
					if not table.find_value(enemy_markers, marker) then
						DeleteBadgesFromTargetOfPreset("EnemyDeploymentAreaBadge", marker)
					else
						if not TargetHasBadgeOfPreset("EnemyDeploymentAreaBadge", marker) then
							CreateBadgeFromPreset("EnemyDeploymentAreaBadge", marker)
						end
					end
				end
			end
		end)
	else
		UpdateEntranceAreasVisibility()
		MapForEachMarker("GridMarker", nil, function(marker)
			if marker.Type == "DeployArea" then
				marker:HideArea()
			end
			DeleteBadgesFromTargetOfPreset("DeploymentAreaBadge", marker)
			DeleteBadgesFromTargetOfPreset("EnemyDeploymentAreaBadge", marker)
		end)
	end
end

function IsFirstSquadDeployment(squad_id) -- check all squads if not squad_id is provided
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units) do
			if (not squad_id or u.Squad == squad_id) and u:IsLocalPlayerControlled() and IsUnitDeployed(u) then
				return false
			end
		end
	end
	return true
end

function IsDeploymentReady()
	local team = GetCurrentTeam()
	if team then
		for i, u in ipairs(team.units) do
			if not IsUnitDeployed(u) then
				return false
			end
		end
	end
	return true
end

function GetCurrentDeploymentSquadUnits(local_player_controlled_only)
	local units = {}
	local currentSquad = gv_Squads[g_CurrentSquad]
	for i, session_id in ipairs(currentSquad.units) do
		local u = g_Units[session_id]
		if not local_player_controlled_only or u:IsLocalPlayerControlled() then
			units[#units + 1] = u
		end
	end
	return units
end

if FirstLoad then
	DeployButtonVisible = true
end

function HideDeployButton()
	DeployButtonVisible = false
end

function ShowDeployButton()
	DeployButtonVisible = true
end

function ShouldHideDeployButton()
	return not DeployButtonVisible
end

function ShowUnitsOnDeployment(bShow, bLclPlayer)
	if bShow then
		local igi = GetInGameInterfaceModeDlg()
		if not IsKindOf(igi, "IModeDeployment") or not igi.units_deployed then
			igi = false
		end
	
		for _, t in ipairs(g_Teams) do
			if t.side == "player1" or t.side == "player2" then -- show only player units, enemies will be handled in exploration VisibilityThread
				for i, unit in ipairs(t.units) do
					if bLclPlayer == unit:IsLocalPlayerControlled() then
						unit:SetVisible(true)
						
						-- Mark unit as deployed. It should be in a valid deploy position due to LocalDeployUnitsOnMarker in StartDeployment
						if igi then
							igi.units_deployed[unit] = true
							igi.cursor_voxel = false -- Force recalc
						end
					end
				end
			end
		end
	else
		for _, t in ipairs(g_Teams) do
			if t.side == "player1" or t.side == "player2" or t.side == "enemy1" or t.side == "enemy2" then
				for i, unit in ipairs(t.units) do
					unit:SetVisible(false)
				end
			end
		end
	end
	ObjModified("DeployUpdated")
	ObjModified("UpdateTacticalNotification")
end

function SkipDeployment(mode)
	if gv_Deployment then
		return false
	elseif not mode then
		return true
	end
	if g_TestCombat and g_TestCombat.skip_deployment then
		return true
	end	
	-- temp comment out, check SetupDeployOrExploreUI
	--[[if mode == "attack" or mode == "defend" then
		return false
	end]]

	local currentSector = gv_Sectors[gv_CurrentSectorId]
	local conflict = IsConflictMode(gv_CurrentSectorId)

	if not currentSector.enabled_auto_deploy or not conflict then
		return true
	end

	if g_GoingAboveground then
		return true
	end

	return false
end

function SetDeploymentMode(deploy)
	local defend_mode = deploy == "defend" or not deploy and gv_Deployment == "defend"
	gv_Deployment = deploy
	deploy = not not deploy
	local update_visuals = {}
	if defend_mode then
		if deploy then
			MapForEachMarker("GridMarker", nil, function(marker)
				if (marker.Type == "Defender" or marker.Type == "DefenderPriority") and marker:IsMarkerEnabled() then
					table.insert_unique(g_InteractableAreaMarkers, marker)
					update_visuals[#update_visuals + 1] = marker
				end
			end)
		else
			MapForEachMarker("GridMarker", nil, function(marker)
				if (marker.Type == "Defender" or marker.Type == "DefenderPriority") and marker:IsMarkerEnabled() then
					marker:RemoveFloatTxt()
					table.remove_value(g_InteractableAreaMarkers, marker)
					update_visuals[#update_visuals + 1] = marker
				end
			end)
		end
		
	else
		update_visuals = MapGetMarkers("Entrance", g_GoingAboveground and "Underground" or nil)
		table.iappend(update_visuals, MapGetMarkers("DeployArea"))
		if deploy then
			if not g_GoingAboveground then
				MapForEachMarker("GridMarker", nil, function(marker)
					if marker:IsKindOf("DeploymentMarker") then
						table.insert_unique(g_InteractableAreaMarkers, marker)
					end
				end)
			end
		else
			if not g_GoingAboveground then
				MapForEachMarker("GridMarker", nil, function(marker)
					if marker:IsKindOf("DeploymentMarker") then
						marker:RemoveFloatTxt()
						table.remove_value(g_InteractableAreaMarkers, marker)
					end
				end)
			end
		end
	end
	for _, marker in ipairs(update_visuals) do
		marker.Reachable = true--not deploy
		if marker.area_ground_mesh then
			marker.area_ground_mesh:UpdateState()
		end
		marker:UpdateVisuals(deploy and "DeployArea" or marker.Type, "force")
		marker:RecalcAreaPositions()
		if not marker:IsAreaVisible() then
			marker:HideArea()
		end
	end
	if not deploy then
		UpdateAvailableDeploymentMarkers()
		HideTacticalNotification("deployMode")
		Msg("DeploymentModeDone")
	end
	Msg("DeploymentModeSet", deploy)
end

function TFormat.DeployModeNotif(context_obj)
	local non_deployed = 0
	local non_deployed_lcl_player = 0
	local deployed = 0
	local team = GetCurrentTeam()
	local totalUnits = 0
	if team then
		for i, u in ipairs(team.units) do
			if not IsUnitDeployed(u) then
				non_deployed = non_deployed + 1
				if u:IsLocalPlayerControlled() then
					non_deployed_lcl_player = non_deployed_lcl_player + 1
				end
			else
				deployed = deployed + 1
			end
		end
		totalUnits = #team.units
	end
	local sector = gv_Sectors[gv_CurrentSectorId]
	if non_deployed_lcl_player <= 0 and non_deployed > 0 then
		local other_player_info = GetOtherNetPlayerInfo()
		return T{616675804493, "<other_player> Deploying", other_player = Untranslated(other_player_info and other_player_info.name or "N/A")}
	else
		return T{673244787391, "Deploy Merc(s) (<deployed>/<total>)", deployed = deployed, total = totalUnits}
	end
end

function TFormat.IntelForSector(context_obj)
	local sector = gv_Sectors[gv_CurrentSectorId]
	if sector and sector.Intel and not sector.intel_discovered then
		return T(244800584080, "No Intel for this sector")
	end
	return false
end

function GetDeploymentAreaRollover(marker)
	if marker.DeployRolloverText ~= "" then
		return marker.DeployRolloverText
	end

	if marker.Type == "Entrance" then
		if marker:IsInGroup("North") then
			return T(147747736813, "North Deployment Zone")
		elseif marker:IsInGroup("South") then
			return T(565574703512, "South Deployment Zone")
		elseif marker:IsInGroup("East") then
			return T(189571269539, "East Deployment Zone")
		elseif marker:IsInGroup("West") then
			return T(998300938139, "West Deployment Zone")
		end
	end
	return T(419061570457, "Deployment Area")
end

OnMsg.CustomInteractableEffectsDone = UpdateAvailableDeploymentMarkers

function IsUnitSeenByAnyDeploymentMarker(unit, markers)
	markers = markers or GetAvailableDeploymentMarkers()
	-- If the unit can see the marker, we consider it seeing back.
	-- This will cause weather effects and such to apply.
	-- The code below is a circle x rectangle collision.
	local unitSightRadius = unit:GetSightRadius()
	local ux, uy = unit:GetPosXYZ()
	local half_slabsize = const.SlabSizeX / 2
	for i, m in ipairs(markers) do
		local mx, my = m:GetPosXYZ()
		local distX = abs(ux - mx)
		local markerWidth = m.AreaWidth * half_slabsize
		local dx = distX - markerWidth
		if dx <= unitSightRadius then
			local distY = abs(uy - my)
			local markerHeight = m.AreaHeight * half_slabsize
			local dy = distY - markerHeight
			if dy <= unitSightRadius then
				if distX <= markerWidth / 2 or distY <= markerHeight / 2 then
					return true
				end
				-- Pythagoras
				if dx * dx + dy * dy <= unitSightRadius * unitSightRadius then
					return true
				end
			end
		end
	end
	return false
end

function IsStuckedMercPos(unit, pos, pfclass, destinations)
	if not pfclass then
		pfclass = CalcPFClass("player1")
	end
	if not destinations then
		destinations = {}
		local markers = GetAvailableEntranceMarkers(unit.arrival_dir)
		for i, marker in ipairs(markers) do
			local pos = GetPassSlab(marker)
			if pos then
				table.insert(destinations, pos)
			end
		end
	end
	if #destinations == 0 then
		return false
	end
	local has_path, closest_pos = pf.HasPosPath(pos, destinations, pfclass)
	if has_path and table.find(destinations, closest_pos) then
		return false
	end
	return true
end

function HasStuckedMercs()
	local destinations, dummy
	local pfclass = CalcPFClass("player1")
	for _, t in ipairs(g_Teams) do
		if t.side == "player1" or t.side == "player2" then
			for i, unit in ipairs(t.units) do
				if unit:IsLocalPlayerControlled() and unit:IsValidPos() and not unit:IsDead() then
					if not destinations then
						local markers = GetAvailableEntranceMarkers(unit.arrival_dir)
						if not markers then
							return
						end
						destinations = {}
						for i, marker in ipairs(markers) do
							local pos = GetPassSlab(marker)
							if pos then
								table.insert(destinations, pos)
							end
						end
					end
					if #destinations == 0 then
						return
					end
					-- invalidate the path
					local start_pos = unit.traverse_tunnel and unit.traverse_tunnel:GetExit() or GetPassSlab(unit) or unit:GetPos()
					local pfflags = const.pfmImpassableSource
					local has_path, closest_pos = pf.HasPosPath(start_pos, destinations, pfclass, 0, 0, nil, 0, nil, pfflags)
					if not has_path or not table.find(destinations, closest_pos) then
						return true
					end
				end
			end
		end
	end
	DoneObject(dummy)
	return false
end

function RedeploymentCheck()
	local redeploy = false
	if mapdata.GameLogic and Game and not g_Combat then
		if HasStuckedMercs() then
			redeploy = true
		end
	end
	gv_Redeployment = redeploy
	ObjModified("gv_Redeployment")
end

function RedeploymentCheckDelayed()
	if not mapdata.GameLogic or not Game then
		return
	elseif g_Combat then
		return
	elseif IsValidThread(RedeploymentThread) then
		return
	elseif GameState.disable_redeploy_check then
		return
	end
	RedeploymentThread = CreateGameTimeThread(function()
		Sleep(2000)
		RedeploymentCheck()
	end)
end

OnMsg.OnPassabilityChanged = RedeploymentCheckDelayed
OnMsg.CombatEnd = RedeploymentCheckDelayed
