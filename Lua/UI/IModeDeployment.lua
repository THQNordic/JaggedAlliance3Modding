DefineClass.IModeDeployment = {
	__parents = { "GamepadUnitControl" },
	cursor_voxel = false,
	badges = false,
	
	units_deployed = false
}

local function lWillThereBeDeployment()
	if gv_Deployment then
		local currentSector = gv_Sectors[gv_CurrentSectorId]
		if currentSector.enabled_auto_deploy and currentSector.conflict then
			return true, true
		else
			return true, false
		end
	else
		return false
	end
end

function GetFirstControlledUnit()
	if not g_CurrentTeam and not g_Teams then
		return
	end
	if not g_CurrentTeam and g_Teams then
		g_CurrentTeam = table.find(g_Teams, "side", "player1")
	end
	local team = g_Teams[g_CurrentTeam]
	if team.units and #team.units > 0 then
		for _, u in ipairs(team.units) do
			if u:IsLocalPlayerControlled() then
				return u
			end
		end
	end
end

function SetupDeploymentCam()
	local u = GetFirstControlledUnit()
	if u then
		CameraPositionFromUnitOrientation(u)
		SelectionSet()
		SelectionAdd(u)
	end
	
	local deploy_markers = GetAvailableDeploymentMarkers()
	
	local firstMarker = deploy_markers and deploy_markers[1]
	if firstMarker then SnapCameraToObjFloor(firstMarker) end
	
	return deploy_markers
end

function OnMsg.SetpieceEnded(setpiece)
	--this code tries to move cam to deployment zone before setpiece fade in, seems to work
	local dep, autoStart = lWillThereBeDeployment()
	if dep and autoStart then
		SetupDeploymentCam()
		
		local team = GetPoVTeam()
		if not team then return end
		local units = team.units
		for _, u in ipairs(units) do
			u:SetVisible(false, "force")
		end
	end
end

function IModeDeployment:Open()
	PauseCampaignTime("Deployment")
	GamepadUnitControl.Open(self)
	
	--Call this function as during deployment the QuestTCEEvaluation() is not executed, but it is needed to display tutorial
	TutorialHintVisibilityEvaluate()
	
	local deploy_markers = SetupDeploymentCam()
	self.badges = {}
	for i, zone in ipairs(deploy_markers) do
		self.badges[#self.badges + 1] = CreateBadgeFromPreset("DeploymentAreaBadge", zone)
	end
	
	-- add open inventory action
	local shortcuts = GetShortcuts("idInventory")
	XAction:new({
		ActionShortcut = shortcuts[1],
		ActionShortcut2 = shortcuts[2],
		ActionGamepad = shortcuts[3],
		OnAction = function()
			OpenInventory(SelectedObj)
		end,
	}, self)
	
	self.units_deployed = {}
end

function IModeDeployment:Close()
	ResumeCampaignTime("Deployment")
	GamepadUnitControl.Close(self)
	
	for i, b in ipairs(self.badges or empty_table) do
		b:Done()
	end
	
	for i, u in ipairs(g_Units) do
		u:SetHighlightReason("deploy_predict", false)
	end
	
	TutorialHintsState.DeploymentSet = true
	RedeploymentCheck()
end


function IModeDeployment:OnMousePos(pt, button)
	self:UpdateTarget()
	GamepadUnitControl.OnMousePos(self, pt)
end

function IModeDeployment:UpdateTarget()
	local cursorPos = GetCursorPos()
	if cursorPos then
		local vx, vy, vz = WorldToVoxel(cursorPos)
		local voxel = point_pack(vx, vy, vz)
		if voxel == self.cursor_voxel then
			return
		end
		self.cursor_voxel = voxel
		UpdateMarkerAreaEffects()
	end
	
	-- Deployment prediction
	local units = GetCurrentDeploymentSquadUnits("local_player_controlled_only")
	local allUnitsInSquadDeployed = true
	for i, u in ipairs(units) do
		if not IsUnitDeployed(u) then
			allUnitsInSquadDeployed = false
			break
		end
	end
	
	-- Handling super obscure co-op case where the host changes merc control while deploying.
	if Selection and Selection[1] and IsUnitDeployed(Selection[1]) then
		allUnitsInSquadDeployed = true
	end
	
	local markers = GetAvailableDeploymentMarkers()
	local noPredict = false
	local cursor_pos = GetCursorPassSlab()
	local unitInVoxel = GetUnitInVoxel(cursor_pos)
	local noUnitHere = (not unitInVoxel or not IsUnitDeployed(unitInVoxel))
	local unitUnderMouse = self:GetUnitUnderMouse()
	local noUnitUnderMouse = (not unitUnderMouse or not IsUnitDeployed(unitUnderMouse))
	local marker, positions = false, false
	if not allUnitsInSquadDeployed and cursor_pos and noUnitHere and noUnitUnderMouse then
		for _, m in ipairs(markers) do
			if m:IsInsideArea(cursor_pos) then
				marker, positions = GetRandomSpawnMarkerPositions({m}, #units, "around_center", cursor_pos)
				break
			end
		end
	end
	
	local function shouldSendEvent()
		for i, u in ipairs(units) do
			if IsUnitDeployed(u) then
				if u.highlight_reasons and u.highlight_reasons["deploy_predict"] then
					return true
				end
			elseif marker then
				local p = positions[i]
				if p then
					if u:GetPos():SetInvalidZ() ~= p then
						return true
					end
				end
			else
				if u:GetVisible() then
					return true
				end
			end
		end
		return false
	end
	
	if shouldSendEvent() then
		NetSyncEvent("DeploymentPredictionMoveUnits", marker, units, positions)
	end
end

function NetSyncEvents.DeploymentPredictionMoveUnits(marker, units, positions)
	for i, u in ipairs(units) do
		if IsUnitDeployed(u) then
			u:SetHighlightReason("deploy_predict", false)
		elseif marker then
			local p = positions[i]
			if p then
				u:SetPos(p)
				u:SetAngle(marker:GetAngle())
				u:SetVisible(true)
				u:SetHighlightReason("deploy_predict", true)
			end
		else
			u:SetVisible(false)
		end
	end
end

function IModeDeployment:OnMouseButtonDown(pt, button, time)
	local result = GamepadUnitControl.OnMouseButtonUp(self, button, pt, time)
	if result and result ~= "continue" then
		return result
	end

	-- Gamepad click
	if not button and GetUIStyleGamepad() then
		button = "L"
	elseif button ~= "L" and button ~= "R" then
		return "continue"
	end

	local cursor_pos = GetCursorPassSlab()
	if not cursor_pos then return end

	local markers = GetAvailableDeploymentMarkers()
	
	-- In world unit selection
	if button == "L" then
		local sel_unit = self:GetUnitUnderMouse()
		if sel_unit and self:CanSelectObj(sel_unit) then
			SelectObj(sel_unit)
			return "break"
		end
	end
	
	local marker = false
	for _, m in ipairs(markers) do
		if m:IsInsideArea(cursor_pos) then
			marker = m
			break
		end
	end
	
	local unitHere = GetUnitInVoxel(cursor_pos)
	if marker and (not unitHere or not IsUnitDeployed(unitHere)) then
		-- If the currently selected unit isn't deployed, the click will deploy their whole squad.
		local selUnit = Selection[1]
		if not selUnit or not IsUnitDeployed(selUnit) then
			local units = GetCurrentDeploymentSquadUnits("local_player_controlled_only")
			units = table.ifilter(units, function(_, o) return not IsUnitDeployed(o) end)
			NetSyncEvent("DeployUnitsOnMarker", units, marker, "show", cursor_pos)
		elseif selUnit then
			NetSyncEvent("DeployUnit", selUnit.session_id, cursor_pos, marker)
		end
	end

	return "break"
end

function IModeDeployment:NextUnit()
	local team = g_Teams and g_Teams[g_CurrentTeam]
	if not team or team.control ~= "UI" then return end
	team = GetFilteredCurrentTeam(team)
	
	local units = team.units
	if not units or not next(units) then return end
	
	local idx = table.find(units, SelectedObj) or 0
	local n = #units
	for i = 1, n do
		local j = i + idx
		if j > n then j = j - n end
		local unit = units[j]
		if unit:CanBeControlled() then
			SelectObj(unit)
			if not IsFirstSquadDeployment(unit.Squad) then
				SnapCameraToObj(unit)
			end
			break
		end
	end
end

function LocalDeployUnitsOnMarker(units, marker, show, slab_pos)
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "IModeDeployment") or not igi.units_deployed then
		igi = false
	end

	if not marker then
		local pr_entr
		local some_unit = units and units[1]
		if some_unit and gv_Deployment == "attack" then
			pr_entr = MapGetMarkers("Entrance", some_unit.arrival_dir)[1]
		end
		marker = marker or pr_entr or table.interaction_rand(GetAvailableDeploymentMarkers(some_unit))
	end
	if not marker then return end
	
	for _, unit in ipairs(units) do
		unit:SetPos(InvalidPos())
	end
	marker:RecalcAreaPositions()
	local _, positions, marker_angle = GetRandomSpawnMarkerPositions({marker}, #units, "around_center", slab_pos)
	for i, unit in ipairs(units) do
		local snap_pos, snap_angle = unit:GetVoxelSnapPos(positions[i], marker_angle)
		unit:SetPos(snap_pos or positions[i])
		unit:SetAngle(snap_angle or marker_angle)
		unit:SetTargetDummy(false)
		unit:InterruptPreparedAttack()
		unit.entrance_marker = marker
		
		local voxels, head = unit:GetVisualVoxels(nil, nil)
		EnvEffectDarknessTick(unit, voxels)
		
		if igi then
			igi.units_deployed[unit] = true
			igi.cursor_voxel = false -- Force recalc
			ObjModified(unit)
		end
		
		if show then
			unit:SetVisible(true)
		end
	end
	marker:RecalcAreaPositions()
	
	if show then
		UpdateMarkerAreaEffects()
		ObjModified("DeployUpdated")
		ObjModified("UpdateTacticalNotification")
	end
end

function NetSyncEvents.DeployUnitsOnMarker(units, marker, show, slab_pos)
	LocalDeployUnitsOnMarker(units, marker, show, slab_pos)
end

function NetSyncEvents.DeployUnit(session_id, pos, marker)
	local angle = marker:GetAngle()
	local unit = g_Units[session_id]
	local snap_pos, snap_angle = unit:GetVoxelSnapPos(pos, angle)
	unit:SetPos(snap_pos or pos)
	unit:SetAngle(snap_angle or angle)
	unit:SetTargetDummy(false)
	unit.entrance_marker = marker
	
	local voxels, head = unit:GetVisualVoxels(nil, nil)
	EnvEffectDarknessTick(unit, voxels)
	
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "IModeDeployment") or not igi.units_deployed then
		igi = false
	end
	if igi then
		igi.units_deployed[unit] = true
		igi.cursor_voxel = false -- Force recalc
	end
	marker:RecalcAreaPositions()
	
	ObjModified("DeployUpdated")
	ObjModified("UpdateTacticalNotification")
	ObjModified(unit)
end

function IModeDeployment:StartExploration()
	local quick_deploy = IsFirstSquadDeployment()
	local ready = IsDeploymentReady()
	if not quick_deploy and not ready then
		CreateMessageBox(GetDialog("IModeDeployment"),
			T(824112417429, "Warning"), 
			T(286144111238, "You have to deploy all merc squads to continue! You can cycle between squads using the control at the top left of the screen."),
			T(325411474155, "OK")
		)
		return
	end
	NetSyncEvent("DeploymentToExploration", quick_deploy, netUniqueId)
end

function IModeDeployment:GetUnitUnderMouse()
	local obj = SelectionMouseObj()
	if IsKindOf(obj, "Unit") then return obj end
	return GetUnitInVoxel()
end

function IModeDeployment:CanSelectObj(obj)
	return IsKindOf(obj, "Unit") and obj:CanBeControlled() and IsUnitDeployed(obj)
end

function NetSyncEvents.DeploymentToExploration(quick_deploy, person_who_clicked)
	if quick_deploy then
		if netUniqueId == person_who_clicked then
			HideDeployButton()
		end
		ShowUnitsOnDeployment(true, netUniqueId == person_who_clicked)
	end
	
	if not IsDeploymentReady() or not gv_DeploymentStarted then
		return
	end

	if gv_Deployment == "defend" then
		local delay = 10000 -- Wait a bit before sending the enemies on their way
		local markers_per_group = {}
		local defender_markers = MapGetMarkers("Defender", false, function(m) return m:IsMarkerEnabled() end)
		if next(defender_markers) then
			local _, enemy_squads = GetSectorSquadsToSpawnInTactical(gv_CurrentSectorId)
			for _, squad in ipairs(enemy_squads) do
				local squad_marker = table.interaction_rand(defender_markers) -- move unit to this marker if it was not grouped with other units in SpawnSquads
				for _, session_id in ipairs(squad.units or empty_table) do
					local marker = false
					local unit = g_Units[session_id]
					for idx, group in ipairs(g_GroupedSquadUnits) do
						if table.find(group, unit.session_id) then
							if not markers_per_group[idx] then
								markers_per_group[idx] = table.interaction_rand(defender_markers)
							end
							marker = markers_per_group[idx]
							break
						end
					end
					marker = marker or squad_marker
					unit:SetBehavior("AdvanceTo", {marker:GetHandle(), delay})
					unit:SetCommandParams("AdvanceTo", {move_anim = "Walk"})
					unit:SetCommand("AdvanceTo", marker:GetHandle(), delay)
				end
			end
		end
	end
	
	gv_DeploymentStarted = false
	SetDeploymentMode(false)
	local firstSelected = Selection and Selection[1]
	if firstSelected and not IsOnScreen(firstSelected) then
		DelayedCall(0, SnapCameraToObj, firstSelected, "player-input")
	end
	SyncStartExploration()
end

function OnMsg.CombatStart()
	if gv_Deployment then
		gv_DeploymentStarted = false
		SetDeploymentMode(false)
	end
end

function SetupDeployOrExploreUI(load_game)
	if gv_ActiveCombat ~= gv_CurrentSectorId and gv_CurrentSectorId then -- Loading a save in combat
		local dep, autoStart = lWillThereBeDeployment()
		if dep then
			if autoStart then
				ReapplyUnitVisibility("force")
				StartDeployment("auto_deploy")
				return
			elseif gv_Deployment then -- test condition
				-- If not automatically entering deployment mode (but will have deploy)
				-- then we expect a script to trigger it. In which case stop deployment mode.
				-- This is potentially legacy functionality for working around setpieces at sector enter
				-- and is probably unused.
				SetDeploymentMode(false)
			end
		elseif not g_Exploration then
			-- ^ It's possible to already be in exploration, such as when deployment
			-- is started through an effect on EnterMap events
			assert(not gv_DeploymentStarted)
			gv_DeploymentStarted = false -- Peculiar save had this broken in this way, no idea how
			SyncStartExploration()
		end
	end
	
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "IModeExploration") then return end
	
	-- Position the camera on the playable units, and turn it towards the first unit's orientation.
	if not g_CurrentTeam and g_Teams then
		g_CurrentTeam = table.find(g_Teams, "side", "player1")
	end
	local team = g_Teams[g_CurrentTeam]
	local skip_snap
	if not igi.suppress_camera_init and team.units and #team.units > 0 then
		local unit = team.units[1]
		skip_snap = unit.entrance_marker
		CameraPositionFromUnitOrientation(unit, gv_DeploymentStarted and 500)
	end
	
	if not SelectedObj and #GetCurrentMapUnits("player") > 0 then 
		igi:NextUnit(nil, nil, skip_snap)
		ForceUpdateCommonUnitControlUI(false, igi)
	end
end

function NetSyncEvents.StartRedeployDeployment()
	SetDeploymentMode("explore")
	StartDeployment(false, true)
end

function NetSyncEvents.StartDeployment(auto_deploy)
	StartDeployment(auto_deploy, true)
end

function StartDeployment(auto_deploy, sync_call)
	local currentSector = gv_Sectors[gv_CurrentSectorId]
	if not gv_Deployment and currentSector.conflict then
		SetDeploymentMode(currentSector.conflict.spawn_mode or false)
	end

	currentSector.enabled_auto_deploy = true
	gv_DeploymentStarted = true
	ShowDeployButton()
	
	if netInGame and not sync_call then
		if NetIsHost() then
			NetSyncEvent("StartDeployment", auto_deploy)
		end
		return
	end
	
	-- Clear exploration if deployment was started during it
	-- such as via an effect.
	if g_Exploration then
		DoneObject(g_Exploration)
		g_Exploration = false
	end
	assert(not g_Combat)
	
	EnsureCurrentSquad()
	local squadsOnMap = GetSquadsOnMap("references")
	for i, s in ipairs(squadsOnMap) do
		local units = {}
		for i, uId in ipairs(s.units) do
			local unit = g_Units[uId]
			if unit then
				units[#units + 1] = unit
			end
		end
		if #units > 0 then
			LocalDeployUnitsOnMarker(units)
		end
	end

	ShowInGameInterface(true, false, { Mode = "IModeDeployment" })
	Msg("DeploymentStarted")
	UpdateAvailableDeploymentMarkers()
	ShowUnitsOnDeployment(false)
	
	CreateRealTimeThread(function(auto_deploy)
		WaitLoadingScreenClose()
		if not gv_Deployment then return end
		-- Ivko: Set overview mode to false first to make sure cameraTac.SetForceOverview(true) does not early out
		-- and will force the proper overview camera angle to apply after the SetupDeploymentCam call (which breaks it)
		cameraTac.SetForceOverview(false)
		cameraTac.SetForceOverview(true)
		ShowTacticalNotification("deployMode", true)
		if not auto_deploy then
			RequestAutosave{ autosave_id = "sectorEnter", save_state = "SectorEnter", display_name = T{841930548612, "<u(Id)>_SectorEnter", gv_Sectors[gv_CurrentSectorId]}, mode = "delayed" }
		end
	end, auto_deploy)
end

function OnMsg.ChangeMap()
	cameraTac.SetForceOverview(false)
	cameraTac.SetFixedLookat(false)
end

function ForceUpdateDeploymentControlUI(recreate)
	local mode = GetInGameInterfaceModeDlg()
	local context_window = mode and mode:IsKindOf("IModeDeployment") and mode.idContainer
	if context_window then
		context_window:OnContextUpdate(nil, recreate)
	end
	ObjModified("DeployUpdated")
end

function OnMsg.SelectionChange()
	ForceUpdateDeploymentControlUI(true)
	UpdateAvailableDeploymentMarkers()
	PlayFX("activityButtonPress_SelectMercIngame", "start")
end

function OnMsg.SelectionAdded(obj)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if not IsKindOf(mode_dlg, "IModeDeployment") then return end
	HandleMovementTileContour({obj}, false, "Exploration")
end

function OnMsg.SelectionRemoved(obj)
	local mode_dlg = GetInGameInterfaceModeDlg()
	if not IsKindOf(mode_dlg, "IModeDeployment") then return end
	HandleMovementTileContour({obj})
end

function OnMsg.CurrentSquadChanged()
	if not gv_Deployment then return end
	local playerUnits = GetAllPlayerUnitsOnMap()
--[[	for i, u in ipairs(playerUnits) do
		if not IsUnitDeployed(u) then
			u:SetVisible(false)
		end
	end]]

	if not g_CurrentSquad then return end
	local selUnit = Selection[1]
	if not selUnit then return end

	local selUnitSquad = selUnit.Squad
	if selUnitSquad == g_CurrentSquad then return end
	
	local units = GetCurrentDeploymentSquadUnits("local_player_controlled_only")
	for i, u in ipairs(units) do
		SelectObj(u)
		break
	end
end

function IsUnitDeployed(unit)
	local igi = GetInGameInterfaceModeDlg()
	if not IsKindOf(igi, "IModeDeployment") or not igi.units_deployed then return true end
	
	local deploymentUnits = GetCurrentTeam()
	deploymentUnits = deploymentUnits and deploymentUnits.units
	if deploymentUnits and not table.find(deploymentUnits, unit) then return true end
	
	return igi.units_deployed[unit]
end