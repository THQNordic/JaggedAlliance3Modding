local function lRespawnContours(dialog, mover, blackboard)
	local startStance = blackboard.toDoStanceAtStart
	local endStance = blackboard.playerToDoStanceAtEnd
	local combatPath = GetCombatPathKeepStanceAware(mover, blackboard.playerToDoStanceAtEnd)
	blackboard.combat_path = combatPath
	
	local action = dialog.action or mover:GetDefaultAttackAction("ranged")
	if action.id == "MGBurstFire" and not mover:HasStatusEffect("StationedMachineGun") then
		action = CombatActions.MGSetup
	end
	local borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels, attackAp =
		GenerateAttackContour(action, mover, combatPath, blackboard.custom_combat_path)
	dialog.borderline_attack = borderline_attack
	dialog.borderline_attack_voxels = borderline_attack_voxels
	dialog.borderline_turns = borderline_turns
	dialog.borderline_turns_voxels = borderline_turns_voxels
	blackboard.attackAp = attackAp
	dialog:UpdateContoursFX(true)
	SelectionAddedApplyFX(Selection)
end

local function lRemoveHighlightFromTrapsAlongPath(blackboard)
	local highlightedTraps = blackboard.highlighted_traps or empty_table
	for i, obj in ipairs(highlightedTraps) do
		if obj.trigger_radius_fx then
			obj.trigger_radius_fx:SetColorFromTextStyle("MineRange")
		end
	end
	blackboard.highlighted_traps = false
end

local function lHighlightTrapsAlongPath(blackboard, path, mover)
	if not path or not IsValid(mover) then return end
	
	lRemoveHighlightFromTrapsAlongPath(blackboard)
	if not blackboard.highlighted_traps then
		blackboard.highlighted_traps = {}
	end
	
	local interrupts = AnyInterruptsAlongPath(mover, path, "all")
	for i, t in ipairs(interrupts) do
		local typeOfInterrupt = t[1]
		local obj = t[2]
	
		if typeOfInterrupt == "trap" and IsKindOf(obj, "Trap") and obj.trigger_radius_fx then
			obj.trigger_radius_fx:SetColorFromTextStyle("MineRangeHighlight")
			
			blackboard.highlighted_traps[#blackboard.highlighted_traps + 1] = obj
		end
	end
end

local visiblityUpdated_refreshContours = false
function OnMsg.WallVisibilityChanged()
	visiblityUpdated_refreshContours = true
end

function Targeting_CombatMove(dialog, blackboard, command, pt)
	local mover = dialog.attacker

	local actualActionCamOpen = CurrentActionCamera and not IsValidThread(ActionCameraInterpolationThread) and command ~= "setup"
	if dialog:PlayerActionPending(mover) or IsSetpiecePlaying() or actualActionCamOpen then
		command = "delete-force"
	end

	if command == "delete" or command == "delete-force" then
		-- Optimization to prevent duplicate deletions while unit is moving
		if blackboard.deleted == command then return end
		blackboard.deleted = command
	
		HandleMovementTileContour()
		lRemoveHighlightFromTrapsAlongPath(blackboard)
		
		SetAPIndicator(false, "move")
		SetAPIndicator(false, "unreachable")
		UIEnemyHeadIconsPredictionMode(false)
		UpdateMovementAvatar(dialog, false, false, "delete")
		
		DestroyBlackboardFXPath(blackboard)
		if command == "delete-force" then dialog:UpdateContoursFX(false) end
		
		for _, unit in ipairs(blackboard.melee_threats) do
			if IsValid(blackboard.melee_threats[unit]) then
				DoneObject(blackboard.melee_threats[unit])
			end
		end
		for _, unit in ipairs(g_Units) do
			unit:SetHighlightReason("melee", nil)
		end
		blackboard.melee_threats = nil
		
		return
	end
	if not mover or not IsValid(mover) then return end
	
	assert(g_Combat)
	blackboard.deleted = false
	
	-- Check movement mode change
	local movementMode = dialog.movement_mode
	local movementModeLast = blackboard.movement_mode
	local movementModeChanged = movementMode ~= movementModeLast
	if movementModeChanged and movementMode then -- Enter movement mode
		UIEnemyHeadIconsPredictionMode(true)
	elseif movementModeChanged and not movementMode then -- Exit movement mode
		blackboard.last_target_pos = false
		blackboard.playerToDoStanceAtEnd = false
		UIEnemyHeadIconsPredictionMode(false)
		SetAPIndicator(false, "move")
		SetAPIndicator(false, "unreachable")
		lRemoveHighlightFromTrapsAlongPath(blackboard)
	end
	blackboard.movement_mode = movementMode
	
	-- Check for option changes
	local keepStance = GetKeepStanceOption(mover)
	local playerStanceChanged = blackboard.playerToDoStanceAtEnd ~= blackboard.last_playerToDoStanceAtEnd
	local keepStanceOptionChanged = keepStance ~= blackboard.last_keepStance
	if playerStanceChanged or keepStanceOptionChanged then
		dialog.contours_dirty = true

		if keepStance then
			blackboard.toDoStanceAtStart = false
		end

		blackboard.last_playerToDoStanceAtEnd = blackboard.playerToDoStanceAtEnd
		blackboard.last_keepStance = keepStance
	end
	
	-- Respawn contours
	if dialog.contours_dirty or visiblityUpdated_refreshContours then
		lRespawnContours(dialog, mover, blackboard)
		dialog.contours_dirty = false
		visiblityUpdated_refreshContours = false
	end
	
	-- Determine moving and selected positions
	local combatPath = blackboard.combat_path
	local show_contours = combatPath and combatPath.paths_ap and next(combatPath.paths_ap, next(combatPath.paths_ap)) and true or false -- at least 2 enties
	local target_pos = dialog.target_pos
	local notOnTarget = not dialog.potential_target

	local goto_pos = false
	if show_contours and target_pos and notOnTarget then
		local pathPositions = dialog.borderline_turns_voxels[1]
		local positionInPath = table.find(pathPositions, point_pack(target_pos))
		goto_pos = positionInPath and target_pos
	end
	
	-- If not in movement mode don't show path, unless rollover interactable
	local extraCosts = 0
	if not movementMode then
		goto_pos = false
		
		local interactable = dialog.potential_interactable
		if interactable then
			local pos = mover:GetInteractionPosWith(interactable)
			target_pos = pos
			goto_pos = pos
			
			if pos then
				local combat_action = interactable:GetInteractionCombatAction(mover)
				local interactionCost = combat_action and combat_action:GetAPCost(mover, { target = interactable, goto_pos = false })
				interactionCost = interactionCost and (interactionCost / const.Scale.AP)
				extraCosts = interactionCost or 0
			end
			
			-- If the interaction is free and the interaction pos is the current position we
			-- want to remove the goto_pos as otherwise the no movement + free extra cost will
			-- trip the "free move" display
			if extraCosts == 0 and pos == mover:GetPos() then
				goto_pos = false
			end
		end
	end
	
	-- Movement avatar
	if mover.session_id ~= blackboard.mover_avatar then -- Changing the selected obj doesn't clear the blackboard
		UpdateMovementAvatar(dialog, false, false, "delete")
		blackboard.mover_avatar = mover.session_id
	end
	if not blackboard.movement_avatar then
		UpdateMovementAvatar(dialog, point20, nil, "setup", { show_stance_arrows = true })
	end
	
	-- Update goto position visualization
	local inside_attack_area = InsideAttackArea(dialog, goto_pos)
	local posChanged = goto_pos ~= blackboard.last_pos
	local change = posChanged or playerStanceChanged or keepStanceOptionChanged
	if change then
		local stanceAtEnd = blackboard.playerToDoStanceAtEnd or mover.stance
		blackboard.fxToDoStance = stanceAtEnd
	
		-- Recalculate cost and path to new tile
		local currentStancePath = goto_pos and combatPath:GetCombatPathFromPos(goto_pos)
		local currentStancePathCost = goto_pos and combatPath:GetAP(goto_pos)
		local stanceToWalkIn = goto_pos and combatPath.destination_stances and combatPath.destination_stances[point_pack(goto_pos)]
		blackboard.toDoStanceAtStart = stanceToWalkIn
		dialog.target_path = currentStancePath
		
		CreateBlackboardFXPath(blackboard, mover:GetPos(), dialog.target_path, inside_attack_area, dialog)
		lHighlightTrapsAlongPath(blackboard, dialog.target_path, mover)
		
		-- Update fx and ap indication
		if blackboard.movement_avatar and target_pos and dialog.target_path and notOnTarget then 
			UpdateMovementAvatar(dialog, target_pos, stanceAtEnd, "update_pos")
		else 
			UpdateMovementAvatar(dialog, point20, stanceAtEnd, "update_pos")
		end
		dialog:UpdateTargetCovers("force")
		dialog.action_params = movementMode and {
			--stanceAtStart = blackboard.toDoStanceAtStart,
			stanceAtEnd = stanceAtEnd
		}
		
		SetAPIndicator(currentStancePathCost, "move", false, false, false, extraCosts)
		blackboard.last_pos = goto_pos
	end

	dialog:UpdateContoursFX(show_contours)
	
	-- Debug
	if Platform.developer and rawget(_G, "g_APCostsShown") and g_Combat then
		DbgDrawCombatNodes(combatPath)
	end
	
	-- Show occupied/unreachable prediction.
	if movementMode then
		if target_pos and not dialog.target_path and notOnTarget then
			SetAPIndicator(dialog.target_pos_occupied and APIndicatorOccupied or APIndicatorUnreachable, "unreachable")
		else
			SetAPIndicator(false, "unreachable")
		end
	end
	
	-- Position cursor
	if blackboard.last_target_pos ~= target_pos or change then
		local enemyPos = dialog.potential_target_is_enemy
		dialog:UpdateGotoFX(target_pos, goto_pos, enemyPos, inside_attack_area, not movementMode or not notOnTarget)
		blackboard.last_target_pos = target_pos
	end
end

function UpdateMovementAvatar(dialog, target_pos, stanceChange, command, special_args)
	local attacker = dialog.attacker
	local blackboard = dialog.targeting_blackboard
	local mov_avatar = blackboard.movement_avatar
	
	if not IsValid(attacker) then return end

	if command == "setup" or command == "update_weapon" then
		if command == "setup" then
			-- create obj
			if not blackboard.movement_avatar then 
				mov_avatar = PlaceObject("AppearanceObject")
				mov_avatar:ClearEnumFlags(const.efSelectable)
				mov_avatar:SetGameFlags(const.gofDontHideWithRoom)
				mov_avatar.Appearance = ""
				mov_avatar:SetPos(target_pos)
				blackboard.movement_avatar = mov_avatar
				if CheatEnabled("IWUIHidden") then mov_avatar:SetVisible(false) end
			end
			if not blackboard.movement_avatar.rollover and special_args and special_args.show_stance_arrows then
				local rollover = XTemplateSpawn("MovementAvatarRollover", dialog, blackboard.movement_avatar)
				if dialog.window_state == "open" then
					rollover:Open()
					rollover:SetVisible(false)
				end
				
				local stanceButton = dialog:ResolveId("idStanceButton")
				rollover.GetAnchor = function()
					return stanceButton.box
				end
				blackboard.movement_avatar.rollover = rollover
				
				if CheatEnabled("CombatUIHidden") then
					rollover:SetTransparency(255)
				end
			end
			
			--set appearance
			if attacker.Appearance ~= mov_avatar.Appearance then 
				mov_avatar:ApplyAppearance(attacker.Appearance)
				mov_avatar.gender = attacker.gender
				mov_avatar:ClearEnumFlags(const.efSelectable)
			end
			
			if blackboard.movement_avatar.rollover then
				--blackboard.movement_avatar.rollover:AddDynamicPosModifier({id= "attached_ui", target = blackboard.movement_avatar, spot_idx = blackboard.movement_avatar:GetSpotBeginIndex("Torsostatic")})
			end

			blackboard.melee_threats = blackboard.melee_threats or {}
			if not blackboard.melee_range_indicator and special_args and not special_args.melee_charge then
				local melee_action, melee_weapon
				if table.find(attacker.ui_actions, "UnarmedAttack") then
					melee_action = CombatActions.UnarmedAttack
				else
					melee_action = CombatActions.MeleeAttack
				end
				if melee_action:GetUIState({attacker}) == "enabled" then 	
					melee_weapon = melee_action:GetAttackWeapons(attacker)
				end
				
				if melee_weapon then
					local avatar = blackboard.movement_avatar
					blackboard.melee_range_indicator = MeleeAOEVisuals:new({}, nil, {voxels = {}, pos = avatar:GetPos(), mode =  "Ally"})
				end
			end
		end

		if command == "update_weapon" then
			mov_avatar:SetState(attacker:GetIdleBaseAnim(stanceChange))
		end

		-- set weapons (UpdateAttachedWeapon() should be called after animation set)
		mov_avatar:DestroyAttaches("WeaponVisual")
		local attaches = attacker:GetAttaches("WeaponVisual")
		if attaches then
			for i = #attaches, 1, -1 do
				local attach = attaches[i]
				local item = attach.weapon
				local o = item and item:CreateVisualObj(mov_avatar)
				if o then
					item:UpdateVisualObj(o)
					o.equip_index = attach.equip_index
					attaches[i] = o
				else
					table.remove(attaches, i)
				end
			end
			AttachVisualItems(mov_avatar, attaches, nil, nil, attacker)
		end
		mov_avatar:SetObjectMarking(5)
		mov_avatar:SetHierarchyGameFlags(const.gofObjectMarking)
		mov_avatar:ClearHierarchyEnumFlags(const.efShadow)
	elseif command == "delete" then
		if mov_avatar then
			if mov_avatar.rollover and mov_avatar.rollover.window_state ~= "destroying" then
				mov_avatar.rollover:delete()
			end
			DeleteThread(blackboard.loopAnimThread)
			DoneObject(blackboard.movement_avatar)
			blackboard.movement_avatar = false
			blackboard.fxToDoStance = false
			blackboard.playerToDoStanceAtEnd = false
			dialog.action_params = { }
			dialog.contours_dirty = true
			DoneObject(blackboard.melee_range_indicator)
			blackboard.melee_range_indicator = false
		end
		for _, unit in ipairs(blackboard.melee_threats) do
			if IsValid(blackboard.melee_threats[unit]) then
				DoneObject(blackboard.melee_threats[unit])
			end
		end
		blackboard.melee_threats = nil
		g_RolloverShowMoreInfoFakeRollover = false
		return
	elseif command == "update_pos" then
		--orientation, pos and stance
		if target_pos ~= point20 and dialog.target_path then
			local goto_pos = point(point_unpack(dialog.target_path[1]))
			local angle = CalcOrientation(point(point_unpack(dialog.target_path[2])), goto_pos)

			--set rotation and stance
			local orientation_angle = attacker:GetPosOrientation(goto_pos, angle, stanceChange, true, true)
			mov_avatar:SetState(attacker:GetIdleBaseAnim(stanceChange))
			mov_avatar:SetOrientation(axis_z, orientation_angle, blackboard.movement_avatar:GetVisible() and 150 or 0)
			if mov_avatar.rollover then mov_avatar.rollover:SetVisible(true) end
		elseif dialog.action and dialog.action.AimType == "melee-charge" then
			MovementAvatar_PlayAnim(dialog, attacker, blackboard)
		else
			if mov_avatar.rollover then mov_avatar.rollover:SetVisible(false) end
		end
	end

	if target_pos then
		if target_pos and target_pos ~= point20 then
			blackboard.movement_avatar:SetPos(target_pos, blackboard.movement_avatar:GetVisible() and 50 or 0)
			blackboard.movement_avatar:SetVisible(true)
		else
			blackboard.movement_avatar:SetVisible(false)
		end
	end

	local movement_avatar = blackboard.movement_avatar
	local melee_attack_pos = blackboard.movement_avatar:GetPos()
	
	if blackboard.melee_range_indicator then
		local voxels
		if target_pos ~= point20 then
			voxels = GetMeleeRangePositions(movement_avatar) or {}
			table.insert(voxels, point_pack(melee_attack_pos))
		else
			voxels = {point_pack(point30)}
		end
		blackboard.melee_range_indicator:RecreateAoeTiles{voxels = voxels, pos = melee_attack_pos, mode = "Ally"}
	end
	
	local melee_threats = {}
	for _, unit in ipairs(g_Units) do
		if not unit:IsDead() and attacker:IsOnEnemySide(unit) and HasVisibilityTo(attacker.team, unit) then
			local enemy_marking = blackboard.melee_range_indicator and IsMeleeRangeTarget(attacker, melee_attack_pos, attacker.stance, unit, nil, unit.stance)
			unit:SetHighlightReason("melee", target_pos ~= point20 and enemy_marking)
			if unit.stance ~= "Prone" and unit:GetActiveWeapons("MeleeWeapon") and IsMeleeRangeTarget(unit, nil, unit.stance, attacker, melee_attack_pos, attacker.stance) then
				melee_threats[#melee_threats + 1] = unit				
			end
		end		
	end
	-- remove old melee threats that are now invalid
	for i = #blackboard.melee_threats, 1, -1 do
		local unit = blackboard.melee_threats[i]
		if not table.find(melee_threats, unit) then
			if IsValid(blackboard.melee_threats[unit]) then
				DoneObject(blackboard.melee_threats[unit])
			end
			blackboard.melee_threats[unit] = nil
			table.remove(blackboard.melee_threats, i)
		end
	end
	
	-- add new melee threats
	for _, unit in ipairs(melee_threats) do
		if not IsValid(blackboard.melee_threats[unit]) then
			table.insert(blackboard.melee_threats, unit)
			local voxels = GetMeleeRangePositions(unit) or {}
			local pos = unit:GetPos()
			table.insert(voxels, point_pack(pos))
			blackboard.melee_threats[unit] = MeleeAOEVisuals:new({vstate = "Deployed", ui_melee_threat = true}, nil, {voxels = voxels, pos = pos, mode = "Enemy"})
		end
	end
	
	--if #blackboard.melee_threats > 0 then
	if target_pos ~= point20 and dialog.target_path and AnyInterruptsAlongPath(attacker, dialog.target_path) then
		movement_avatar:SetObjectMarking(3)
	else
		movement_avatar:SetObjectMarking(5)
	end
	
	blackboard.movement_avatar_cover = GetCoversAt(target_pos)
	
	ObjModified(blackboard.movement_avatar)
end

function CreateBlackboardFXPath(blackboard, mover_pos, target_path, inside_attack_area, dialog)
	local fx = UpdatePathFX(mover_pos, target_path, blackboard.fx_path, inside_attack_area, dialog)
	if CheatEnabled("IWUIHidden") and fx then
		for i, mesh in ipairs(fx.steps_objects) do
			mesh:SetVisible(false)
		end
	end
	blackboard.fx_path = fx
end

function DestroyBlackboardFXPath(blackboard)
	if blackboard.fx_path then
		DoneObject(blackboard.fx_path)
	end
	blackboard.fx_path = false
end

DefineClass.IModeCombatMovement = {
	__parents = { "IModeCombatBase" },
	movement_mode = false,
	contours_dirty = true
}

function NetSyncEvents.SyncStartIModeExploration(...)
	SetInGameInterfaceMode("IModeExploration", ...)
end

function IModeCombatMovement:Open()
	if not g_Combat then
		CreateGameTimeThread(function()
			NetSyncEvent("SyncStartIModeExploration", {suppress_camera_init = true})
		end)
	end
	IModeCombatBase.Open(self)
	
	self:CreateThread("wait-combat", function()
		if not g_Combat or not g_Combat.combat_started then
			WaitMsg("CombatStartedForReal")
		end
		while self.attacker and self.attacker.command == "AimIdle" do
			WaitMsg("Idle", 50)
		end
		self:SetMovementMode(false)
		self:SetupTargeting("combat_move")
		
		-- Updates indicators after certain combat actions end.
		UpdateAllBadges()
	end)
end

function IModeCombatMovement:Close()
	self:UpdateContoursFX(false)
	Msg("UIMovementModeChanged", false)
	IModeCombatBase.Close(self)
end

function IModeCombatMovement:HighlightNewInteractables()
	return not self.movement_mode
end

function IModeCombatMovement:SetMovementMode(movement)
	self.movement_mode = movement
	Msg("UIMovementModeChanged", movement)
end

function IModeCombatMovement:OnMouseButtonDown(pt, button, obj)
	local result = InterfaceModeDialog.OnMouseButtonDown(self, pt, button)
	if result == "break" then return "break" end
	if not g_Combat or g_Teams[g_CurrentTeam].control ~= "UI" then
		return
	end
	-- Since OnMousePos isn't called every frame we need to make sure the click will land on the right spot.
	IModeCommonUnitControl.UpdateTarget(self, GetCursorPos())

	local gamepadClick = false
	if not button and GetUIStyleGamepad() then
		gamepadClick = true
	end

	if button ~= "L" and not gamepadClick then
		if button == "R" then
			self:SetMovementMode(false)
			if self.targeting_blackboard and self.targeting_blackboard.movement_avatar then 
				UpdateMovementAvatar(self, point20, "Standing", "update_pos")
			end
		end
		return
	end

	if terminal.IsKeyPressed(const.vkControl) then
		PlayerPing()
		return "continue"
	end

	local selectedObj = IsValid(SelectedObj) and SelectedObj:CanBeControlled() and SelectedObj
	local locked_control = SelectedObj and not SelectedObj:IsIdleCommand()

	-- Attack enemy
	obj = obj or self.potential_target
	if IsKindOf(obj, "Unit") and not obj:IsDead() and obj ~= selectedObj then
		if obj:CanBeControlled() then
			SelectObj(obj)
			SnapCameraToObjFloor(obj)
			self:UpdateTarget(obj:GetPos())
			return "break"
		elseif selectedObj and obj:IsOnEnemySide(selectedObj) and not locked_control then
			local args = {target = obj}
			local action = selectedObj:GetDefaultAttackAction()
			local state = CheckAndReportImpossibleAttack(selectedObj, action, args)
			if state == "enabled" then
				action:UIBegin({selectedObj}, args)
			end
			return "break"
		end
	end
	
	-- Interact
	if selectedObj and not locked_control then
		if self.potential_interactable then
			local canInteract, reason = UICanInteractWith(selectedObj, self.potential_interactable)
			if canInteract then
				UIInteractWith(selectedObj, self.potential_interactable)
			elseif reason then
				ReportAttackError(self.potential_interactable, reason)
			end
			return "break"
		end
	end
	
	if locked_control then return end
	
	-- Move
	if self.movement_mode then
		self:MoveSelUnitToSelectedPos()
		return "break"
	end
	
	-- If nothing else happened, and the click is above a passable pos, movement mode will start.
	local combatPath = selectedObj and GetCombatPath(selectedObj)
	if combatPath and table.count(combatPath.destinations) > 1 then
		self:SetMovementMode(true)
	end
end

function IModeCombatMovement:MoveSelUnitToSelectedPos()
	if self.target_path then
		self:UpdateTarget()
		self:UpdateContoursFX(false)
	end

	if self.target_path and SelectedObj then
		local goto_voxel = self.target_path[1]
		local goto_pos = GetPassSlab(point_unpack(goto_voxel)) or point(point_unpack(goto_voxel))
		local params = self.action_params or {}
		params.goto_pos = goto_pos
		CombatActions.Move:Execute({ SelectedObj }, params)
		PlayFX("Move", "start", SelectedObj, false, goto_pos)
		PlayFX("MercMoveCommand", "start")
		PlaceShrinkingObj(self.movement_decal, self.movement_decal_shrink_time,
							goto_pos, self.movement_decal_scale, self.movement_decal_color)
		HandleMovementTileContour()
	else
		PlayFX("Unreachable", "start")
	end
end

function IModeCombatMovement:SetAttacker(attacker)
	IModeCombatAttackBase.SetAttacker(self, attacker)
	self:SetMovementMode(false)
	if not attacker or attacker:IsDisabled() then
		self:UpdateContoursFX(false)
		return
	end
	self.contours_dirty = true
end

-- This handles the combat movement contour in cases such as when a unit teleports.
function OnMsg.CombatPathReset()
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatMovement") then
		dlg.contours_dirty = true
	end
end

function OnMsg.UnitMovementDone(unit)
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatMovement") and dlg.attacker == unit then
		if dlg.movement_mode then
			dlg:SetupTargeting("combat_move")
		end
	end
end

if FirstLoad then
g_SkipNoApUnits = true
end

function IModeCombatMovement:UnitAvailableForNextUnitSelection(u, force)
	if force then
		return u:CanBeControlled()
	end

	local minAp = const["Action Point Costs"].Walk
	return u:CanBeControlled() and (not g_SkipNoApUnits or u.ActionPoints >= minAp)
end

--- Tile Contour
if FirstLoad then
	g_CursorContour = false
	g_SelectionContours = {}
end

g_ActionTextStyles = {
	CombatAttack = "BorderlineAttackActive",
	CombatMove = "BorderlineMoveActive",
	CombatMoveOccupied = "BorderlineMoveOccupied",
	Exploration = "ExplorationSelect",
	CombatOutside = "BorderlineOutside",
	CombatEnemy = "CombatDanger",
}

local ActionCursorMaterials = {
	CombatAlly = "Select_Combat_Ally_Hover",
	CombatAttack = "Select_Combat_Ally",
	CombatMove = "Select_Combat_AvatarMovement",
	CombatMoveOccupied = "Select_Combat_AvatarMovement",
	CombatOutside = "Select_Combat_Enemy",
	CombatEnemy = "Select_Combat_Enemy",
	
	ExplorationSelect = "Select_Exploration_Ally_Hover",
	Exploration = "Select_Exploration_Ally",
	Interact = "Select_Combat_AvatarMovement",
}

function HandleMovementTileContour(units, pos, action)
	if g_CursorContour then
		DestroyMesh(g_CursorContour)
		g_CursorContour = false
	end
	if IsPoint(pos) and action then
		g_CursorContour = PlaceSingleTileStaticContourMesh(RGB(255, 255,255), nil, action == "Exploration" or action == "ExplorationSelect") -- 	g_ActionTextStyles[action] or action, pos)
		g_CursorContour:SetCRMaterial(ActionCursorMaterials[action] or "Select_Combat_Ally")
		g_CursorContour:SetPos(pos)
	else
		g_CursorContour = false
	end
	for i, u in ipairs(units) do
		local contour = g_SelectionContours[u]
		local old_action = contour and contour.action
		if old_action ~= action then
			if old_action then
				DestroyMesh(contour.contour)
			end
			if action then
				if not contour then
					contour = {}
					g_SelectionContours[u] = contour
				end
				contour.contour = SpawnUnitContour(u, action)
				contour.action = action
			else
				g_SelectionContours[u] = nil
			end
		end
	end
end

function SpawnUnitContour(unit, action, old)
	if not unit then
		if IsValid(old) then
			DestroyMesh(old)
		end
		return false
	end
	local contour = old
	if not IsValid(contour) then
		contour = PlaceSingleTileStaticContourMesh(RGB(255, 255, 255), nil, action == "Exploration" or action == "ExplorationSelect")
		contour:SetCRMaterial(ActionCursorMaterials[action] or "Select_Combat_Ally")
		contour:SetHierarchyGameFlags(const.gofLockedOrientation)
	end
	unit:Attach(contour)
	return contour
end

function OnMsg.SetpieceStarted()
	HandleMovementTileContour(Selection)
end

function OnMsg.SetpieceDialogClosed()
	SelectionAddedApplyFX(Selection)
end

-- End Turn Button Flash

if FirstLoad then
EndTurnFlash = false
HudTextButtonColor = RGB(19, 23, 26)
HudTextButtonRolloverColor = RGB(209, 180, 93)
end

local function lEndTurnFlashOff() 
	EndTurnFlash = false
	ObjModified("EndTurnFlash")
end

local function lUpdateEndTurnFlash(unit)
	unit = unit or SelectedObj

	if not unit or not unit:CanBeControlled() then return end
	
	local currentIgi = GetInGameInterfaceMode()
	local teamUnits = unit.team.units
	local anyHaveAP = false
	for i, u in ipairs(teamUnits) do
		local defaultAttack = u:GetDefaultAttackAction()
		local cost = defaultAttack:GetAPCost(u)
		if not u:IsDead() and u:HasAP(cost) then
			anyHaveAP = true
			break
		end
	end
	EndTurnFlash = not anyHaveAP
	ObjModified("EndTurnFlash")
end

function OnMsg.UnitAPChanged()
	lUpdateEndTurnFlash()
end

function OnMsg.CombatStart()
	lEndTurnFlashOff()
end

function OnMsg.TurnStart()
	lEndTurnFlashOff()
end

function OnMsg.CombatActionEnd(unit, action_data)
	CreateGameTimeThread(function(unit, action_data)
		if not g_Combat or unit ~= SelectedObj then return end
		while not unit:IsIdleCommand() do
			WaitMsg("Idle")
		end
		lUpdateEndTurnFlash(unit)
	end, unit, action_data)
end

DefineClass.ButtonFlashObserver = {
	__parents = { "XContextWindow" },
}

function ButtonFlashObserver:OnScaleChanged()
	self:DeleteThread("delayed")
	self:CreateThread("delayed", function()
		self:OnContextUpdate()
	end)
end

function HudTextButtonUpdateFlash(self, flashOn)
	if self.window_state == "destroying" then return end
	if not flashOn and not self:GetThread("hudButtonFlash") and not self.idImage:FindModifier("flashColorChange") then return end

	self:DeleteThread("hudButtonFlash")
	if not flashOn then
		self.idImage:RemoveModifier("flashColorChange")
		self:SetRolloverMode(self.rollover)
		return
	end

	local function lGetGrowInterp(center, time)
		return {
			id = "flashGrow",
			type = const.intRect,
			duration = time,
			originalRect = sizebox(center, 100, 100),
			targetRect = sizebox(center, 110, 110)
		}
	end

	local function lGetColorInterp(time)
		return {
			id = "flashColorChange",
			type = const.intColor,
			duration = time,
			startValue = HudTextButtonColor,
			endValue = HudTextButtonRolloverColor
		}
	end

	self:CreateThread("hudButtonFlash", function(self)
		local b = self.box
		local growTime = 100
		local shrinkTime = 1000
		local timeBeforeNextGrow = 200
		while self.window_state ~= "destroying" do
			local center = b:Center()
			self:AddInterpolation(lGetGrowInterp(center, growTime))
			self.idImage:SetBackground(const.clrWhite)
			self.idImage:AddInterpolation(lGetColorInterp(growTime))
			Sleep(growTime + 10)
			self:SetRolloverMode(true)
			self.idImage:SetBackground(const.clrWhite)
			
			local shrink = lGetGrowInterp(center, shrinkTime)
			shrink.flags = const.intfInverse
			self:AddInterpolation(shrink)
			
			Sleep(shrinkTime + 10)
			self:SetRolloverMode(false)
			Sleep(timeBeforeNextGrow)
		end
	end, self)
end

-- Movement targeting to be attached to other targeting modes, legacy-ish

function Targeting_Movement(dialog, blackboard, command, pt, special_args)
	local movement_mode = IsKindOf(dialog, "IModeCombatMovement")
	local machine_gun_area_aim = IsKindOf(dialog, "IModeCombatAreaAim")
	if machine_gun_area_aim and special_args then
		 special_args.show_stance_arrows = false
	end
	local mover = dialog.attacker
	
	-- Check if the action cam was open from an action switch rather than an attack going out.
	local actualActionCamOpen = CurrentActionCamera and not IsValidThread(ActionCameraInterpolationThread) and command ~= "setup"
	if dialog:PlayerActionPending(mover) or IsSetpiecePlaying() or not mover:CanBeControlled() or actualActionCamOpen then
		command = "delete-force"
	end
	
	--create avatar
	if command == "setup" or command == "update" then
		if not blackboard.movement_avatar then UpdateMovementAvatar(dialog, point20, nil, "setup", special_args) end
	end

	if command == "delete" or command == "delete-force" then
		-- Optimization to prevent duplicate deletions while unit is moving
		if blackboard.deleted == command then return end
		blackboard.deleted = command

		SetAPIndicator(false, "move")
		SetAPIndicator(false, "unreachable")
		UIEnemyHeadIconsPredictionMode(false)
		
		DestroyBlackboardFXPath(blackboard)
		if not movement_mode or command == "delete-force" then dialog:UpdateContoursFX(false) end
		HandleMovementTileContour()
		lRemoveHighlightFromTrapsAlongPath(blackboard)
		dialog.target_path = false
		
		--delete movement avatar
		UpdateMovementAvatar(dialog, point20, nil, "delete")
		
		return
	end
	
	UIEnemyHeadIconsPredictionMode(true)
	assert(g_Combat)
	blackboard.deleted = false
	
	-- Generate contour data.
	local mover_pos = mover:GetPos()
	local combatPath = blackboard.combat_path or GetCombatPath(mover) -- Modes can override combat path with custom values.
	if not movement_mode or dialog.contours_dirty then
		if dialog.contours_dirty then
			local path_ap_cost
			local stanceApCost = CombatActions["Stance" .. mover.stance]:GetAPCost(mover)
			
			local attacker = dialog.attacker
			local action = dialog.action
			local weapon = action:GetAttackWeapons(attacker)
			local aim_params = action:GetAimParams(attacker, weapon)
			if aim_params.move_ap then
				path_ap_cost = aim_params.move_ap
			else
				if stanceApCost < 0 then stanceApCost = 0 end
				path_ap_cost = mover.ActionPoints - stanceApCost
			end
			combatPath = GetCombatPath(mover, nil, path_ap_cost)
			
			blackboard.combat_path = combatPath
			local action = dialog.action or mover:GetDefaultAttackAction("ranged")
			if action.id == "MGBurstFire" and not mover:HasStatusEffect("StationedMachineGun") then
				action = CombatActions.MGSetup
			end
			local borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels, attackAp = GenerateAttackContour(action, mover, combatPath, blackboard.custom_combat_path, stanceApCost)
			dialog.borderline_attack = borderline_attack
			dialog.borderline_attack_voxels = borderline_attack_voxels
			dialog.borderline_turns = borderline_turns
			dialog.borderline_turns_voxels = borderline_attack_voxels
			blackboard.attackAp = attackAp
			dialog.args_gotopos = true --in coop this gets falsified when another player shoots , idk why, but it f***s up the whole command afterward
			dialog:UpdateContoursFX(true)
			SelectionAddedApplyFX(Selection, dialog.target_pos)
			dialog.contours_dirty = false
		else
			if not blackboard.contour_for or blackboard.contour_for.unit ~= mover or blackboard.contour_for.pos ~= mover_pos then
				local borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels, attackAp = GenerateAttackContour(dialog.action, mover, combatPath, blackboard.custom_combat_path)
				dialog.borderline_attack = borderline_attack
				dialog.borderline_attack_voxels = borderline_attack_voxels
				dialog.borderline_turns_voxels = borderline_attack_voxels
				blackboard.attackAp = attackAp
		
				-- If in movestep selection and there are no valid moves, then automatically go to the next step.
				if not dialog.borderline_attack and blackboard.move_step then
					CreateRealTimeThread(function()
						if blackboard.move_step == "back" then
							dialog:GoBack()
						else
							dialog:MoveStepNext()
						end
					end)
				end

				-- We only want to show tiles we can attack from. This block is used when movement is within an attack.
				--dialog.borderline_turns = borderline_turns
				--dialog.borderline_turns_voxels = borderline_turns_voxels
				blackboard.contour_for = { unit = mover, pos = mover_pos }
				SelectionAddedApplyFX(Selection)
			end
		end
	end
	
	-- Debug
	if Platform.developer and rawget(_G, "g_APCostsShown") and g_Combat then
		DbgDrawCombatNodes(combatPath)
	end
	
	local show_contours = combatPath and combatPath.paths_ap and next(combatPath.paths_ap, next(combatPath.paths_ap)) and true or false -- at least 2 enties
	local target_pos = dialog.target_pos
	local notOnTarget = special_args and special_args.show_on_target or not dialog.potential_target
	local moveStepAttack, attacking = blackboard.move_step, not not dialog.action
	local moveStepCurrentPos = false
	if moveStepAttack and dialog.potential_target == dialog.attacker then
		notOnTarget = true
		moveStepCurrentPos = true
	end

	local goto_pos, _, min_dist_error, line_error, frontal_error = false, false, false, false, false
	local melee_charge_on_target = false
	if show_contours and target_pos and notOnTarget then
		if table.find(dialog.borderline_turns_voxels[1], point_pack(target_pos)) then
			goto_pos = target_pos
		end
	elseif special_args and special_args.melee_charge and dialog.target_pos_occupied and not IsMerc(dialog.target_pos_occupied) and
		target_pos ~= blackboard.last_pos then
		goto_pos, _, min_dist_error, line_error, frontal_error = GetChargeAttackPosition(dialog.attacker, dialog.target_pos_occupied, nil, dialog.action.id)
		melee_charge_on_target = true
	end

	local showApIndicator = (not special_args or not special_args.no_ap_indicator)
	assert(not showApIndicator)
	
	local inside_attack_area = InsideAttackArea(dialog, goto_pos)
	if target_pos ~= blackboard.last_pos then
		if dialog.target_path then
			lRemoveHighlightFromTrapsAlongPath(blackboard)
		end
		dialog.target_path = goto_pos and combatPath and not min_dist_error and not line_error and combatPath:GetCombatPathFromPos(goto_pos) or false
		CreateBlackboardFXPath(blackboard, mover_pos, dialog.target_path, inside_attack_area, dialog)
		lHighlightTrapsAlongPath(blackboard, dialog.target_path, mover)

		-- Show occupied/unreachable prediction.
		local showUnreachableApIndicator = (special_args and special_args.show_unreachable_indicator)
		local showOccupiedAPIndicator = not special_args or not special_args.melee_charge
		local errors = false
		
		if target_pos and not dialog.target_path and (line_error or min_dist_error) and combatPath:GetCombatPathFromPos(goto_pos) then
			if min_dist_error then
				SetAPIndicator(APIndicatorTooClose, "unreachable")
			elseif frontal_error then
				SetAPIndicator(APIndicatorNoFrontalAttack, "unreachable")
			else
				SetAPIndicator(APIndicatorNoLine, "unreachable")
			end
			errors = true
		elseif target_pos and not dialog.target_path and (notOnTarget or attacking) and showUnreachableApIndicator and not moveStepCurrentPos then
			SetAPIndicator(dialog.target_pos_occupied and showOccupiedAPIndicator and APIndicatorOccupied or APIndicatorUnreachable, "unreachable")
		elseif not target_pos or mover:GetDist(target_pos) > const.SlabSizeX / 2 and dialog.target_pos_occupied then
			SetAPIndicator(false, "unreachable")
		end
		
		blackboard.no_straight_line_error = errors and line_error
		blackboard.min_dist_error = errors and min_dist_error
	end

	local hide_avatar = special_args and special_args.hide_avatar
	if blackboard.last_pos ~= target_pos then--awlays else case
		dialog:UpdateGotoFX(target_pos, goto_pos, dialog.potential_target_is_enemy, inside_attack_area)
		if blackboard.movement_avatar and target_pos and dialog.target_path and notOnTarget and not hide_avatar and not min_dist_error then 
			UpdateMovementAvatar(dialog, target_pos, "Standing", "update_pos")
		else 
			UpdateMovementAvatar(dialog, point20, "Standing", "update_pos")
		end
		dialog:UpdateTargetCovers("force")
	end
	
	dialog:UpdateContoursFX(show_contours, inside_attack_area, goto_pos)
	blackboard.last_pos = target_pos
end


-- Keep stance functionality

g_MercKeepStanceOption = false

function OnMsg.CombatStart()
	g_MercKeepStanceOption = {}
end

function OnMsg.CombatEnd()
	g_MercKeepStanceOption = false
end

function GetKeepStanceOption(merc)
	if not g_MercKeepStanceOption then g_MercKeepStanceOption = {} end

	local mercId = merc.session_id
	local currentOption = g_MercKeepStanceOption[mercId]
	if currentOption == nil then
		currentOption = merc:HasStatusEffect("Hidden")
	end
	return currentOption
end

function NetSyncEvents.ToggleMercKeepStance(mercId)
	g_MercKeepStanceOption = g_MercKeepStanceOption or {}
	g_MercKeepStanceOption[mercId] = not g_MercKeepStanceOption[mercId]
	ObjModified("keep_stance_changed")
	
	local merc = g_Units[mercId]
	if merc and merc:IsLocalPlayerControlled() then
		local dialog = GetDialog("IModeCombatMovement")
		if dialog and dialog.targeting_blackboard and dialog.targeting_blackboard.movement_avatar then
			dialog.targeting_blackboard.last_pos = true
		end
	end
end

function GetStanceChangesAdditionalCost(mover, stanceChangeAtStart, stanceChangeAtEnd)
	stanceChangeAtStart = stanceChangeAtStart or mover.stance
	stanceChangeAtEnd = stanceChangeAtEnd or mover.stance

	local stanceStartAp = CombatActions["Stance" .. stanceChangeAtStart]:GetAPCost(mover)
	if stanceStartAp == -1 then stanceStartAp = 0 end
	local stanceEndAp = CombatActions["Stance" .. stanceChangeAtEnd]:GetAPCost(mover, {
		stance_override = stanceChangeAtStart
	})
	if stanceEndAp == -1 then stanceEndAp = 0 end
	
	return stanceStartAp + stanceEndAp, stanceStartAp, stanceEndAp
end

local function lMergeCombatPath(mergePath, pathToMerge, stance, extra_cost, free_move_ap)
	free_move_ap = free_move_ap or 0

	for posPacked, canReach in pairs(pathToMerge.destinations) do
		local costBase = pathToMerge.paths_ap[posPacked] + extra_cost
		local cost = Max(0, costBase - free_move_ap)
		local recordedCost = mergePath.paths_ap_discounted[posPacked]
		if not recordedCost or cost < recordedCost then
			mergePath.paths_ap[posPacked] = costBase
			mergePath.paths_ap_discounted[posPacked] = cost
			mergePath.paths_prev_pos[posPacked] = pathToMerge.paths_prev_pos[posPacked]
			mergePath.destinations[posPacked] = true
			mergePath.destination_stances[posPacked] = stance
		end
	end
end

function GetCombatPathKeepStanceAware(mover, stance_at_end, ap)
	ap = ap or mover.ActionPoints
	local mergedPath = CombatPath:new({
		destinations = {},
		destination_stances = {},
		paths_ap = {},
		paths_ap_discounted = {},
		paths_prev_pos = {},
		unit = mover,
		stance = mover.stance,
		stance_at_end = stance_at_end,
		ap = ap,
		start_pos = mover:GetPos(),
		move_modifier = mover:GetMoveModifier(mover.stance), -- for g_CombatPath caching
	})
	
	if GetKeepStanceOption(mover) then
		local extraCosts = GetStanceChangesAdditionalCost(mover, mover.stance, stance_at_end)
		local currentStancePath = CombatPath:new()
		currentStancePath:RebuildPaths(mover, ap - extraCosts, nil, mover.stance)
		lMergeCombatPath(mergedPath, currentStancePath, mover.stance, extraCosts, Max(mover.start_move_free_ap, mover.free_move_ap))
		return mergedPath
	end

	-- Standing
	local extraCostStanding = GetStanceChangesAdditionalCost(mover, "Standing", stance_at_end)
	local standingPath = CombatPath:new()
	standingPath:RebuildPaths(mover, ap - extraCostStanding, nil, "Standing")
	
	-- Crouching
	local extraCostCrouching = GetStanceChangesAdditionalCost(mover, "Crouch", stance_at_end)
	local crouchPath = CombatPath:new()
	crouchPath:RebuildPaths(mover, ap - extraCostCrouching, nil, "Crouch")
	
	-- Prone
	local extraCostProne = GetStanceChangesAdditionalCost(mover, "Prone", stance_at_end)
	local pronePath = CombatPath:new()
	pronePath:RebuildPaths(mover, ap - extraCostProne, nil, "Prone")
	
	-- Add the current stance first, so that no-stance switching is preferred even when it costs the same.
	local moverStance = mover.stance
	local paths = {
		{ standingPath, "Standing", extraCostStanding },
		{ crouchPath, "Crouch", extraCostCrouching },
		{ pronePath, "Prone", extraCostProne },
	}
	table.sort(paths, function(a, b)
		if a[2] == moverStance then
			return true
		end
		if b[2] == moverStance then
			return false
		end
		return true
	end)
	
	-- Merge paths
	for i, path in ipairs(paths) do
		lMergeCombatPath(mergedPath, path[1], path[2], path[3], Max(mover.start_move_free_ap, mover.free_move_ap))
	end

	return mergedPath
end

function MovementAvatar_PlayAnim(dialog, attacker, blackboard)
	local anim = attacker:GetAttackAnim(dialog.action.id, attacker.stance)
	blackboard.loopAnimThread = blackboard.loopAnimThread or CreateGameTimeThread(function(mov_avatar, anim) 
	  while mov_avatar do
		mov_avatar:SetState(anim)
		Sleep(mov_avatar:TimeToAnimEnd())
		mov_avatar:SetState(attacker:GetIdleBaseAnim("Standing"))
		Sleep(1500)
	 end
	end, blackboard.movement_avatar, anim)
end