if FirstLoad then
	TargetingModeLookup = false
end

function EmptyTargetingFunction(dialog, blackboard, command, pt)

end

function OnMsg.ClassesBuilt()
	TargetingModeLookup = {
		["combat_move"] = Targeting_CombatMove,
		["cone"] = Targeting_AOE_Cone,
		["parabola aoe"] = Targeting_AOE_ParabolaAoE,
		["line"] = EmptyTargetingFunction,
		["none"] = EmptyTargetingFunction,
		["mobile"] = Targeting_Mobile,
		["melee"] = Targeting_Melee,
		["melee-charge"] = Targeting_MeleeCharge,
		["allies-attack"] = Targeting_AlliesAttack,
	}
end

-- All attack modes inherit this. Mostly legacy.
DefineClass.IModeCombatAttackBase = {
	__parents = { "IModeCombatBase" }
}

-- All attack modes and CombatMovement inherit this. It provides boilerplate for the various targeting functionality.
DefineClass.IModeCombatBase = {
	__parents = { "CombatMovementContour" },
	
	attacker = false,
	action = false,
	disable_mouse_indicator = false,
	action_params = false,
	target = false,
	target_action_camera = false,
	target_as_pos = false, -- Used for actions who target ground positions rather than objects
	last_target_attempt = false, -- Target that last failed being set. Assuming that nothing can make it valid while targeting, skipping subsequent checks.
	
	targeting_mode = false,
	targeting_func = false,
	targeting_blackboard = false, -- Contains members and data relating to the current targeting mode.
	force_targeting_func_loop = false,
	attack_confirmed = false,
	
	crosshair = false, -- Crosshair UI, spawned by some targeting modes.
	args_gotopos = false,
	
	move_step_marker = false,
	move_step_position = false,
	
	dont_return_camera_on_close = false,
}

local function IsAttackWeapon(weapon, attack_weapon)
	if weapon == attack_weapon then 
		return true 
	end
	if IsKindOf(weapon, "FirearmBase") then
		for slot, sub in pairs(weapon.subweapons) do
			if sub == attack_weapon then
				return true
			end
		end
	end
end

function IModeCombatBase:Open()
	local attacker = self.context and self.context.attacker or SelectedObj
	local action = self.context and self.context.action
	self.attacker = attacker
	self.action = action
	self.action_params = action and self.context.action_params or {}
	IModeCommonUnitControl.Open(self)
	local target = self.context and self.context.target

	self:SetTarget(target)
	self:ResetTargeting()
	PrecalcLOFUI(attacker, action)
end

function IModeCombatBase:Close()
	local attacker = self.context and self.context.attacker or SelectedObj
	
	if CurrentActionCamera then
		RemoveActionCamera(false, default_interpolation_time)
	elseif attacker and self.action and not self.dont_return_camera_on_close then
		SnapCameraToObj(attacker)
	end
	if not CurrentActionCamera then
		hr.CameraTacClampToTerrain = true
	end
	if attacker and self.action then self:AttackerAimAnimation() end
	ClearDamagePrediction()
	self:SetupTargeting(false)
	
	if self.move_step_marker then
		DoneObject(self.move_step_marker)
		self.move_step_marker = false
	end

	-- Check if contours were cleared
	assert(not self.fx_borderline_attack)
	if self.fx_borderline_attack then
		self:UpdateContoursFX(false)
	end
	IModeCommonUnitControl.Close(self)
	
	-- Make sure this doesn't leak since the move and attack thread will be destroyed.
	if attacker and attacker.move_attack_in_progress then
		NetSyncEvent("MoveAndAttack_End", attacker)
	end
end

function IModeCombatBase:MoveBeforeTargetEnabled()
	local moveBeforeTarget = not not g_Combat and (dbgForceMoveStep or self.action and self.action.MoveStep)
	local singleStep = self.action and self.action.AimType == "melee" and "melee"
	return moveBeforeTarget, singleStep
end

function IModeCombatBase:ResetTargeting()
	local action = self.action
	if not action then return end
	
	local moveBeforeTarget, singleStep = self:MoveBeforeTargetEnabled()
	if moveBeforeTarget and not self.target then
		self:SetupTargeting(singleStep or "move")
		self.targeting_blackboard.move_step = true
	else
		self:SetupTargeting(action.AimType)
	end
end

function IModeCombatBase:SetupTargeting(mode)
	self:DeleteThread("update_targeting")
	if self.targeting_func then
		self.targeting_func(self, self.targeting_blackboard, "delete")
		self.targeting_func = false
		self.targeting_blackboard = false
	end
	if not mode then return end

	self.targeting_mode = mode
	self.targeting_func = TargetingModeLookup[mode]
	assert(self.targeting_func)

	self.targeting_blackboard = {}
	self:CreateThread("update_targeting", function(self)
		local first = true
		while self.window_state ~= "destroying" do
			if not GetDialog("FullscreenGameDialogs") then
				local pt = GetCursorPos(self.movement_mode and "walkable")
				
				local withinBadge = false
				if self.desktop.last_mouse_target and GetDialog("BadgeHolderDialog") then
					local badgeDlg = GetDialog("BadgeHolderDialog")
					withinBadge = self.desktop.last_mouse_target:IsWithin(badgeDlg)
				end
				local withinMyUI = GetUIStyleGamepad() or self:IsWithin(self.desktop.last_mouse_target)				
				local withinUI = (withinBadge or withinMyUI or first or self.force_targeting_func_loop)
				if (not self.crosshair and withinUI) or (self.crosshair and self.crosshair.update_targets) then
					self:UpdateTarget(pt)
				end
				if (withinUI or self.contours_dirty) and (not SelectedObj or not SelectedObj:IsDisabled()) then
					self.targeting_func(self, self.targeting_blackboard, first and "setup" or "update", pt)
					first = false
					self.force_targeting_func_loop = false
				end
			end
			WaitFramesOrSleepAtLeast(1, 50)
		end
	end, self)
end

-- Prevents multiple attacks from clicking too fast.
function IModeCombatBase:PlayerActionPending(unit)
	if self.window_state == "destroying" then
		return true
	end
	return PlayerActionPending(unit)
end

function PlayerActionPending(unit)
	if unit == nil then
		unit = SelectedObj
	end
	if not unit then
		return true
	end
	
	if g_UnitAwarenessPending then
		return true
	end

	-- is performing an action?
	if g_Combat then
		if not unit:IsIdleCommand() then
			return true 
		end
	else
		if not unit:IsIdleCommand() and not unit:IsInterruptable() then
			return true 
		end
	end

	--checking actions_nettravel is not sync, i.e. this func may return different vals on different clients
	if HasCombatActionWaiting(unit) or unit.actions_nettravel > 0 then
		return true
	end

	if not unit:CanBeControlled() then
		return true
	end

	-- Is anyone else in the team performing an action
	if unit.team and unit.team.control == "UI" then
		local team = unit.team
		for i, u in ipairs(team.units) do
			if not u:IsIdleCommand() and not u:IsInterruptable() and u:IsLocalPlayerControlled() then
				return true
			end
		end
	end
	
	return false
end

function IModeCombatBase:OnMouseButtonDown(pt, button)
	if self:PlayerActionPending() and (button == "L" or button == "R") then 
		return "break" 
	end

	local result = IModeCommonUnitControl.OnMouseButtonDown(self, pt, button)
	if result == "break" then return "break" end

	local gamepadClick = false
	if not button and GetUIStyleGamepad() then
		gamepadClick = true
	end

	if button == "L" or gamepadClick then
		return self:Confirm()
	elseif button == "R" then
		return self:GoBack()
	end
end

function IModeCombatBase:GetAttackTarget()
	return self.target or self.target_as_pos and self.target_pos
end
MapVar("MoveAndAttackSyncState", 0) --seems game cannot be saved during this action
function NetSyncEvents.MoveAndAttack_Start(attacker, target, action_id)
	attacker.move_attack_in_progress = true
	attacker.move_attack_target = target
	attacker.move_attack_action_id = action_id
	MoveAndAttackSyncState = 1
end

function NetSyncEvents.MoveAndAttack_End(attacker)
	attacker.move_attack_in_progress = nil
	attacker.move_attack_action_id = nil
	MoveAndAttackSyncState = 0
end

function IModeCombatBase:StartMoveAndAttack(attacker, action, target, step_pos, args)
	if attacker.move_attack_in_progress then return end
	if self.real_time_theads and IsValidThread(self.real_time_theads.move_and_attack) then return end
	
	self.move_step_position = step_pos or self.move_step_position	
		
	-- check the position in case the action was a melee action without a targeting step
	if self.targeting_mode == "melee" and attacker ~= target and not IsMeleeRangeTarget(attacker, self.move_step_position, nil, target) then
		self.move_step_position = attacker:GetClosestMeleeRangePos(target)
	end
	
	local pos = self.move_step_position and GetPassSlab(self.move_step_position) or self.move_step_position
	self:CreateThread("move_and_attack", function()
		if self.move_step_marker then
			DoneObject(self.move_step_marker)
			self.move_step_marker = false
		end
	
		local attackerPos = attacker:GetPos()
		local started_in_combat = not not g_Combat
		if IsKindOf(target, "Unit") then
			NetSyncEvent("MoveAndAttack_Start", attacker, target, action.id)
		end
		local attackerArray = {attacker}
		if pos and attacker:GetDist(pos) > const.SlabSizeX / 2 then
			-- special-case for melee attacks: give follow target instead of goto pos
			if not g_Combat and action.id == "MeleeAttack" and IsValid(target) then
				CombatActions.Move:Execute(attackerArray, { follow_target = target })
			else
				CombatActions.Move:Execute(attackerArray, { goto_pos = pos })
			end
			
			-- Wait for move to start.
			while attacker:IsIdleCommand() do
				local _, unit = WaitMsg("UnitAnyMovementStart", 20)
				if unit == attacker then
					break
				end
			end
		end
		
		-- Wait for move to finish.
		while not attacker:IsIdleCommand() do
			WaitMsg("Idle", 20)
		end
		
		-- Wait for other units to finish (like co-op for instance)
		local team = attacker.team
		while team do
			local anyNonIdle = false
			for i, u in ipairs(team.units) do
				if not u:IsIdleCommand() then
					WaitMsg("Idle", 20)
					anyNonIdle = true
				end
			end
			if not anyNonIdle then
				break
			end
		end

		self.move_step_position = false
					
		-- Check if the attacker made it, and can still use the action.
		local state, err = action:GetUIState(attackerArray, args)
		if not IsValid(attacker) or state ~= "enabled" then
			CombatLog("debug", "Attack couldn't be used post-movement. Reason:" .. _InternalTranslate(err or ""))				
		else
			args.unit_moved = attacker:GetDist(attackerPos) > const.SlabSizeX / 2
			action:Execute(attackerArray, args)
		end
		NetSyncEvent("MoveAndAttack_End", attacker)
		if not started_in_combat then
			if g_Combat or g_StartingCombat then
				SetInGameInterfaceMode("IModeCombatMovement")
			else
				SetInGameInterfaceMode("IModeExploration")
			end
		end
	end)	
end

function IModeCombatBase:Confirm()
	local moveBeforeTarget, singleStep = self:MoveBeforeTargetEnabled()
	if moveBeforeTarget and not singleStep and self.targeting_mode == "move" then
		self:MoveStepNext()
		return "break"
	end
	
	-- Prepare attack args
	local action = self.action
	local args = self.action_params or {}
	args.free_aim = self.context and self.context.free_aim
	
	args.target = self:GetAttackTarget()
	if IsPoint(self.args_gotopos) then
		args.goto_pos = self.args_gotopos
	elseif self.args_gotopos then
		args.goto_pos = self.target_pos
	end
	if args.action_override then
		action = args.action_override
		args.action_override = false
	end
	
	-- Clear in world ui while attack is going on.
	self:ClearLinesOfFire()
	self:ClearTargetCovers()
	
	local attacker = self.attacker
	local target = args.target
	local attackerArray = { self.attacker }
	if target and self.move_step_position then
		self.attack_confirmed = true
		ClearAPIndicator()
		self:StartMoveAndAttack(attacker, action, target, nil, args)
		return "break"
	end

	if target then
		if CheckAndReportImpossibleAttack(attacker, action, args) == "enabled" then
			self.attack_confirmed = true
			ClearAPIndicator()
			action:Execute(attackerArray, args)
		else
			return "fail"
		end
	end
	return "break"
end

function IModeCombatBase:GoBack()
	if self.crosshair then return end

	local moveBeforeTarget, singleStep = self:MoveBeforeTargetEnabled()
	if moveBeforeTarget and not singleStep and self.targeting_mode ~= "move" then
		self:MoveStepBack()
		return "break"
	end

	InvokeShortcutAction(self, "ExitAttackMode", self)
	return "break"
end

function IModeCombatBase:SetAttacker(attacker)
	self.attacker = attacker
	if self.action then -- Changing attackers in a targeting mode brings you back to movement
		SetInGameInterfaceMode("IModeCombatMovement")
	end
end

function OnMsg.SelectedObjChange()
	local combatUI = GetInGameInterfaceModeDlg()
	if not g_Combat or not IsKindOf(combatUI, "IModeCombatBase") or not IsKindOf(SelectedObj, "Unit") then return end
	combatUI:SetAttacker(SelectedObj)
end

function OnMsg.UnitAwarenessChanged(unit)
	local dlg = GetInGameInterfaceModeDlg()
	if IsKindOf(dlg, "IModeCombatAttackBase") and dlg.target == unit and unit:IsAware() then SetInGameInterfaceMode("IModeCombatMovement") end
end

function IModeCombatBase:SetTarget(target, dontMove, args)
	if self.last_target_attempt ~= target then self.last_target_attempt = false end
	if target == self.target then return true end
	if self.last_target_attempt and self.last_target_attempt == target then return false end
	self.last_target_attempt = false
	
	if target and not self.move_step_position and (not self.action or self.action.AimType ~= "mobile") then
		args = args or { target = target, free_aim = self.context.free_aim }
		local attackable = CheckAndReportImpossibleAttack(self.attacker, self.action, args)
		if attackable ~= "enabled" then
			if not dontMove then SnapCameraToObj(target) end
			self.last_target_attempt = target
			return false
		end
	end

	ClearDamagePrediction()
	self:RemoveCrosshair("target-change")
	if not dontMove then SnapCameraToObj(target) end
	
	local oldTarget = self.target
	self.target = target
	ObjModified(oldTarget)
	ObjModified("combat_bar_enemies")
	ObjModified("combat_bar_traps")
	
	if IsKindOf(target, "Unit") then SetActiveBadgeExclusive(target) end
	if not target then
		SetActiveBadgeExclusive(false)
		return
	end
	
	-- Used to prevent targets swapping while the camera is moving
	-- between targets in IModeCombatMovingAttack when using gamepad
	if not dontMove then
		self.last_set_target_time = RealTime()
	end

	return true
end

function IModeCombatBase:IsValidCycleTarget(target)
	return SelectedObj:IsOnEnemySide(target) and HasVisibilityTo(SelectedObj.team, target)
end

function IModeCombatBase:GetNextTarget(delta)
	if not SelectedObj then return self.target end
	
	local targets = GetTargetsToShowAboveActionBarSorted(SelectedObj, self)
	local curTargetIdx = table.find(targets, self.target) or 0
	for i = 1, #targets do
		curTargetIdx = curTargetIdx + delta
		if curTargetIdx > #targets then
			curTargetIdx = 1
		elseif curTargetIdx < 1 then
			curTargetIdx = #targets
		end
		-- cycling should only cycle enemies
		if self:IsValidCycleTarget(targets[curTargetIdx]) then
			return targets[curTargetIdx]
		end
	end	
	return self.target
end

function IModeCombatBase:NextTarget()
	if not SelectedObj or not SelectedObj:CanBeControlled() or self:PlayerActionPending() then return end
	local target = self:GetNextTarget(1)
	if target == self.target then return end
	self:SetTarget(target)
end

function IModeCombatBase:PrevTarget()
	if not SelectedObj or not SelectedObj:CanBeControlled() or self:PlayerActionPending() then return end
	local target = self:GetNextTarget(-1)
	if target == self.target then return end
	self:SetTarget(target)
end

------ Crosshair ------

function IModeCombatBase:SpawnCrosshair(...)
	self:RemoveCrosshair()
	self.crosshair = SpawnCrosshair(self, self.action, ...)
	self:OnMousePos(terminal.GetMousePos()) -- Refresh ui
	return self.crosshair
end

function IModeCombatBase:RemoveCrosshair(reason)
	local removed = false
	if self.crosshair and self.crosshair.window_state ~= "destroying" then
		self.crosshair:delete(reason)
		removed = true
	end
	self.crosshair = false
	return removed
end

function IModeCombatBase:HighlightNewInteractables()
	return false
end

-- Move Step

if FirstLoad then
	dbgForceMoveStep = false
end

function IModeCombatBase:MoveStepNext()
	if not self.target_path then
		self:SetupTargeting(self.action.AimType)
		return
	end
	
	local goto_voxel = self.target_path[1]
	local goto_pos = point(point_unpack(goto_voxel))
	self.move_step_position = goto_pos
	
	local entity = self.attacker.gender == "Male" and "Male" or self.attacker.gender == "Female" and "Female" or "Male"
	local markerMesh = PlaceObject(entity)
	
	-- Attach weapons
	local weapon1, weapon2 = self.attacker:GetActiveWeapons()
	local attack_weapon = self.action and self.action:GetAttackWeapons(attacker)
	if attack_weapon and not IsAttackWeapon(weapon1, attack_weapon) and not IsAttackWeapon(weapon2, attack_weapon) then
		weapon1 = attack_weapon
	end
	if IsKindOf(weapon1, "Firearm") then
		markerMesh:Attach(weapon1:CreateVisualObj(markerMesh), markerMesh:GetSpotBeginIndex("Weaponr"))
	end
	if IsKindOf(weapon2, "Firearm") then
		markerMesh:Attach(weapon2:CreateVisualObj(markerMesh), markerMesh:GetSpotBeginIndex("Weaponl"))
	end

	-- Mark as green hologram
	markerMesh:SetObjectMarking(2)
	markerMesh:SetHierarchyGameFlags(const.gofObjectMarking)

	-- Set attack animation
	local anim = self.attacker:GetAimAnim(self.action.id, self.attacker.stance)
	markerMesh:SetState(anim)

	-- Set pos
	markerMesh:SetPos(goto_pos)

	self.move_step_marker = markerMesh
	self:SetupTargeting(self.action.AimType)
end

function IModeCombatBase:MoveStepBack()
	self:SetupTargeting("move")
	if self.move_step_marker then
		DoneObject(self.move_step_marker)
		self.move_step_marker = false
	end
	self.move_step_position = false
	self.targeting_blackboard.move_step = "back"
end

function IModeCombatBase:AttackerAimAnimation(pt_or_target)
	if pt_or_target and self.move_step_marker then
		self.move_step_marker:Face(pt_or_target)
	elseif pt_or_target and self.action then
		NetSyncEvent("Aim", self.attacker, self.action.id, pt_or_target)
	else
		NetSyncEvent("Aim", self.attacker)
	end
end

function RestoreDefaultMode(unit, next_unit)
	if g_Combat then
		if next_unit == nil then
			while g_AIExecutionController do
				WaitMsg("ExecutionControllerDeactivate", 50)
			end
			next_unit = IsValid(unit) and (not unit:CanBeControlled() or unit:IsIncapacitated() or (unit.ActionPoints < const["Action Point Costs"].Walk))
		end
		if g_Combat:ShouldEndCombat() then
			g_Combat:EndCombatCheck(true)
		else
			CreateRealTimeThread(function()
				if next_unit then
					-- While attack modes do handle removing the action camera properly by themselves when closing,
					-- the closing requested by NextUnit does not reach in time for the camera pan to the next target to work,
					-- as the camera will still be locked by the action camera.
					if IsKindOf(GetInGameInterfaceModeDlg(), "IModeCombatAttackBase") and CurrentActionCamera then
						RemoveActionCamera()
						WaitMsg("ActionCameraRemoved", 1000)
					end
					SetInGameInterfaceMode("IModeCombatMovement")
					Sleep(1)
					GetInGameInterfaceModeDlg():NextUnit()
				else
					SetInGameInterfaceMode("IModeCombatMovement")
				end
			end)
		end
	elseif gv_Deployment then
		if not GetInGameInterfaceModeDlg("IModeDeployment") then
			SetInGameInterfaceMode("IModeDeployment")
		end
		return
	elseif not GetInGameInterfaceModeDlg("IModeExploration") then
		SetInGameInterfaceMode("IModeExploration", {suppress_camera_init = true})
	end
end

function RestoreDefaultModeSimple()
	if g_Combat then
		if not GetInGameInterfaceModeDlg("IModeCombatMovement") then
			SetInGameInterfaceMode("IModeCombatMovement")
		end
	elseif gv_Deployment then
		if not GetInGameInterfaceModeDlg("IModeDeployment") then
			SetInGameInterfaceMode("IModeDeployment")
		end
	else
		if not GetInGameInterfaceModeDlg("IModeExploration") then
			SetInGameInterfaceMode("IModeExploration", {suppress_camera_init = true})
		end
	end
end

MapVar("g_CombatActionEndThread", false)

function OnMsg.RunCombatAction(actionId, unit)
	if not unit or not unit.team or unit.team.control ~= "UI" then
		return
	end
	if unit:IsLocalPlayerControlled() then
		if unit:HasQueuedAction() then
			CreateRealTimeThread(RestoreDefaultMode, SelectedObj)
		end
		return
	end
	local mode_dlg = GetInGameInterfaceModeDlg()
	if mode_dlg and mode_dlg.crosshair then
		local crosshair = mode_dlg.crosshair
		local target = crosshair.context and crosshair.context.target
		if not IsValid(target) or target:IsDead() then
			CreateRealTimeThread(RestoreDefaultMode, SelectedObj)
			return
		end
	
		crosshair:UpdateAim()
	end
end

function OnMsg.CombatActionEnd(unit)
	if IsValidThread(g_CombatActionEndThread) then return end
	local currentIgi = GetInGameInterfaceMode()
	g_CombatActionEndThread = CreateGameTimeThread(function(unit)
		local isLocalPlayerAttacking = unit:IsLocalPlayerControlled()
		if not isLocalPlayerAttacking then --handle crosshair on dead target in MP
			local igi = GetInGameInterfaceModeDlg()
			local crosshair = igi and igi.crosshair
			local crosshairTarget = crosshair and crosshair.context.target
			local crosshairAttacker = crosshair and crosshair.context.attacker
			local crosshairAction = crosshair and crosshair.context.action
			local interrupt = g_Interrupt and (not crosshairAttacker or not crosshairAttacker.move_attack_in_progress)
			if crosshair and (crosshairTarget:IsDead() or (IsKindOf(crosshairTarget, "Unit") and crosshairTarget:IsDefeatedVillain()) or not table.find(crosshairAction:GetTargets{crosshairAttacker}, crosshairTarget) or interrupt) then
				g_Interrupt = false
				SetInGameInterfaceMode("IModeCombatMovement")
				return
			end
		end
		if unit ~= SelectedObj then return end
		while not unit:IsIdleCommand() and g_Combat do
			WaitMsg("Idle")
		end
		if unit ~= SelectedObj or IsSetpiecePlaying() then return end
		
		local mode_dlg = GetInGameInterfaceModeDlg()
		
		-- The dialog was closed already.
		if mode_dlg.window_state == "destroying" then return end
		local attackMode = IsKindOf(mode_dlg, "IModeCombatAttackBase")
		
		-- exploration exit targeting
		if not g_Combat then
--[[		local action = mode_dlg.action 
			if action and action.group == "SignatureAbilities" and unit:GetSignatureRecharge(action.id) then
				return RestoreDefaultMode(unit)
			end]]
			return RestoreDefaultMode(unit)
		end
		
		-- The move portion of a move-step attack just finished.
		if attackMode and mode_dlg.move_step_position then return end
		
		-- The attacks are always "close on attack"
		if IsKindOfClasses(mode_dlg, "IModeCombatAreaAim", "IModeCombatFreeAim", "IModeCombatMovingAttack", "IModeCombatCharge") then
			return RestoreDefaultMode(unit)
		end
		
		Sleep(500)
		if currentIgi ~= mode_dlg.class or IsSetpiecePlaying() then return end -- If the dialog mode changed in the delay, then user input overrode us.
		
		-- Retreated
		if not IsValid(unit) then
			local ud = gv_UnitData[unit.session_id]
			local retreat = ud and ud.retreat_to_sector
			if retreat then
				return
			end
		end
		
		-- The attacker died (pindown/overwatch)
		if not unit:CanBeControlled() or unit:IsIncapacitated() then			
			return RestoreDefaultMode(unit, "next")
		end

		--if unit.ActionPoints < const["Action Point Costs"].Walk then
			--return RestoreDefaultMode(unit, "next")
		--end
		
		-- Check if the target died.
		local target = mode_dlg:HasMember("target") and mode_dlg.target
		local action = mode_dlg:HasMember("action") and mode_dlg.action
		local attacker = mode_dlg:HasMember("attacker") and mode_dlg.attacker

		if IsValid(target) and action then
			if target:IsDead() or (IsKindOf(target, "Unit") and target:IsDefeatedVillain()) or not table.find(action:GetTargets{unit}, target) or g_Interrupt then
				g_Interrupt = false
				SetInGameInterfaceMode("IModeCombatMovement")
				return
			end
		end
		
		-- Check if another attack can afforded, by using the crosshair's parameters.
		if attackMode and mode_dlg.crosshair then
			local crosshair = mode_dlg.crosshair
			if crosshair.window_state == "destroying" then return end -- Crosshair is handling closing of attack mode.
			local crosshairContext = crosshair.context
			
			-- check if still can attack, if not exit attack mode
			local attacker = crosshairContext.attacker
			if attacker ~= unit then return end
			
			local chAction = crosshairContext.action
			local weapon = chAction:GetAttackWeapons(attacker)
			local target = crosshairContext.target
			local can_attack = unit:CanAttack(target, weapon, chAction)
			
			-- Check if another firing mode can still be afforded.
			if not can_attack then
				local firingModes = crosshairContext.firingModes
				if firingModes then
					for i, f in ipairs(firingModes) do
						if f ~= chAction and unit:CanAttack(target, weapon, f) then
							chAction = f
							can_attack = true
							crosshair:ChangeAction(f)
							break
						end
					end
				end
			end
			
			if not can_attack then
				SetInGameInterfaceMode("IModeCombatMovement")
				return
			end

			-- New attack should have the same aim, or lower.
			local minAimPossibleNow, maxAimPossibleNow = attacker:GetAimLevelRange(chAction, target)			
			crosshair.maxAimPossible = maxAimPossibleNow
			crosshair.minAimPossible = minAimPossibleNow
			if crosshair.aim then
				crosshair.aim = Clamp(crosshair.aim, minAimPossibleNow, maxAimPossibleNow)
			end
			crosshair:UpdateAim()
			ApplyDamagePrediction(attacker, chAction, {target = target})
			crosshair:SetVisible(true)
		elseif action then
			-- Check if another attack can be afforded
			local cost_ap = action:GetAPCost(unit) or -1
			local cantShootAgain = cost_ap < 0 or not unit:UIHasAP(cost_ap)
			local attacker = mode_dlg:HasMember("attacker") and mode_dlg.attacker
			if unit == attacker and cantShootAgain then
				SetInGameInterfaceMode("IModeCombatMovement")
				return
			end
		end
		if attackMode and not HasCombatActionInProgress(attacker) then
			mode_dlg.attack_confirmed = false -- targeting is enabled again
		end
	end, unit)
end
