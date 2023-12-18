if FirstLoad then
	g_ShowGrenadeVolume = false
end

MishapChanceToText = {
	None = T(601695937982, --[[MishapChance: None]] "None"),
	VeryLow = T(881231004201, --[[MishapChance: Very Low]] "Very Low"),
	Low = T(645131164243, --[[MishapChance: Low]] "Low"),
	Moderate = T(304728934972, --[[MishapChance: Moderate]] "Moderate"),
	High = T(119692148931, --[[MishapChance: High]] "High"),
	VeryHigh = T(211764664344, --[[MishapChance: Very High]] "Very High"),
}

function TFormat.MishapToText(chance)
	local chanceT
	if chance <= 0 then
		chanceT = MishapChanceToText.None
	elseif chance <= 5 then
		chanceT = MishapChanceToText.VeryLow
	elseif chance <= 15 then
		chanceT = MishapChanceToText.Low
	elseif chance <= 30 then
		chanceT = MishapChanceToText.Moderate
	elseif chance <= 50 then
		chanceT = MishapChanceToText.High
	elseif chance > 50 then
		chanceT = MishapChanceToText.VeryHigh
	end
	
	return T{138326583335, "Mishap Chance: <chanceText>", chanceText = chanceT}
end

DefineClass.IModeCombatAreaAim = {
	__parents = { "IModeCombatAttackBase" }
}

function IModeCombatAreaAim:UpdateTarget(...)
	local canTarget = self.action.IsTargetableAttack
	if self.action.id == "Overwatch" then
		local apCost = self.action:GetAPCost(SelectedObj)
		SetAPIndicator(apCost > 0 and apCost or false, "attack")
	end
	
	if not canTarget then
		return
	end
	
	IModeCombatAttackBase.UpdateTarget(self, ...)
end

function IModeCombatAreaAim:GetAttackTarget()
	if not self.target and IsPoint(self.target_as_pos) then
		return self.target_as_pos
	end
	return IModeCombatAttackBase.GetAttackTarget(self)
end

function IModeCombatAreaAim:SetTarget(target, dontMove, args)
	local validTarget = IModeCombatAttackBase.SetTarget(self, target, "dontMove", args)
	if target ~= nil and self.context then -- Not intentionally removed, just not provided.
		local canTarget = self.action.IsTargetableAttack
		self.context.free_aim = not canTarget or not target or not validTarget
	end
	if validTarget then
		self.force_targeting_func_loop = true
	end
	return validTarget
end

function IModeCombatAreaAim:OnMouseButtonDown(pt, button)
	if button == "L" then
		local obj = SelectionMouseObj()
		if IsKindOf(obj, "Unit") and SelectedObj:IsOnEnemySide(obj) and not obj:IsDead() and (not self.action or self.action.TargetableAttack) then
			if obj == self.target then
				if self.crosshair then
					self.crosshair:Attack()
				else
					self:Confirm()
				end
			else
				self:SetTarget(obj)
			end
			return "break"
		end
		if self.crosshair and self:GetMouseTarget(pt) ~= self.crosshair then
			CreateRealTimeThread(RestoreDefaultMode, SelectedObj)
			return "break"
		end
	end
	return IModeCombatAttackBase.OnMouseButtonDown(self, pt, button)
end

function IModeCombatAreaAim:Confirm(from_crosshair)
	local canTarget = self.action.IsTargetableAttack
	local freeAim = self.context.free_aim
	
	if from_crosshair then
		return IModeCombatAttackBase.Confirm(self)
	end
	
	if GetUIStyleGamepad() then
		return IModeCombatAttackBase.Confirm(self)
	end
	
	-- In targeted mode switch the target if clicked on an enemy or switch to free_aim if clicked outside crosshair.
	if canTarget and self.potential_target then
		local new_target = self.potential_target
		local free_aim = not self.potential_target_is_enemy
		local args = { target = new_target, free_aim = free_aim }
		local attackable = CheckAndReportImpossibleAttack(self.attacker, self.action, args)
		-- Swap the target only if it is attackable, otherwise our crosshair will get deleted and we have to respawn it.
		if attackable == "enabled" then
			self:SetTarget(self.potential_target, nil, args)
		end
	elseif canTarget and not self.potential_target and self.target then
		self:SetTarget(false, true)
		if self.attacker then SnapCameraToObj(self.attacker) end
	else
		if self.action.group == "FiringModeMetaAction" then
			local args = self.action_params or {}
			args.action_override = GetUnitDefaultFiringModeActionFromMetaAction(self.attacker, self.action)
			self.action_params = args 
		end
		return IModeCombatAttackBase.Confirm(self)
	end
end

function IModeCombatAreaAim:UpdateLinesOfFire() -- do not show lines of fire while in this mode
end

function IModeCombatAreaAim:ShowCoversShields(world_pos, cover)
	IModeCommonUnitControl.ShowCoversShields(self, world_pos, cover)
end

local function lAoEGetAimPoint(obj, pt, start_pos)
	if not pt:IsValidZ() then
		pt = pt:SetTerrainZ()
	end
	if not start_pos:IsValidZ() then
		start_pos = start_pos:SetTerrainZ()
	end
	local min_range = const.SlabSizeX / 2
	if IsCloser2D(start_pos, pt, min_range) then
		pt = RotateRadius(min_range, obj:GetAngle(), start_pos)
	end
	return pt
end

local AreaTargetMoveAvatarVisibilityDelay = 300

local function VisUpdateThread(blackboard)
	while IsValid(blackboard.movement_avatar) do
		local dt = blackboard.move_avatar_time - RealTime()
		if blackboard.move_avatar_visible ~= blackboard.movement_avatar.visible then
			if dt <= 0 then
				blackboard.movement_avatar:SetVisible(blackboard.move_avatar_visible)
				blackboard.move_avatar_time = RealTime() + AreaTargetMoveAvatarVisibilityDelay
				WaitWakeup()
			else
				WaitWakeup(dt)
			end
		else
			WaitWakeup()
		end
	end
end

local function SetAreaMovementAvatarVisibile(dialog, blackboard, visible, time)
	if not IsValidThread(dialog.real_time_threads.MovementAvatarVisibilityUpdate) then
		dialog:CreateThread("MovementAvatarVisibilityUpdate", VisUpdateThread, blackboard)		
	end
	if visible == blackboard.move_avatar_visible then return end
	blackboard.move_avatar_visible = visible
	Wakeup(dialog.real_time_threads.MovementAvatarVisibilityUpdate)
end

function Targeting_AOE_Cone(dialog, blackboard, command, pt)
	pt = GetCursorPos("walkableFlag")
	local attacker = dialog.attacker
	local action = dialog.action
	if not blackboard.firing_mode_action then
		if action.group == "FiringModeMetaAction" then
			action = GetUnitDefaultFiringModeActionFromMetaAction(attacker, action)
		end
		blackboard.firing_mode_action = action
	end
	action = action.group == "FiringModeMetaAction" and blackboard.firing_mode_action or action
	
	if action.IsTargetableAttack and not dialog.context.free_aim then
		blackboard.gamepad_aim = false
		return Targeting_AOE_Cone_TargetRequired(dialog, blackboard, command, pt)
	end

	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end

	if command == "delete" then
		if blackboard.mesh then
			if IsActivePaused() and dialog.action and dialog.action.ActivePauseBehavior == "queue" and attacker.queued_action_id == dialog.action.id then
				attacker.queued_action_visual = blackboard.mesh
			else
				DoneObject(blackboard.mesh)
			end
			blackboard.mesh = false
		end
		if blackboard.movement_avatar then
			UpdateMovementAvatar(dialog, point20, nil, "delete")
		end
		UnlockCamera("AOE-Gamepad")
		SetAPIndicator(false, "free-aim")
		ClearDamagePrediction()
		return
	end
	
	local shouldGamepadAim = GetUIStyleGamepad()
	local wasGamepadAim = blackboard.gamepad_aim

	if shouldGamepadAim ~= wasGamepadAim then
		if shouldGamepadAim then
			LockCamera("AOE-Gamepad")
			if not CurrentActionCamera then SnapCameraToObj(attacker, "force") end
		else
			UnlockCamera("AOE-Gamepad")
		end
		blackboard.gamepad_aim = shouldGamepadAim
	end

	-- Get attack data
	local weapon = action:GetAttackWeapons(attacker)
	local aoe_params = action:GetAimParams(attacker, weapon) or (weapon and weapon:GetAreaAttackParams(action.id, attacker))
	if not aoe_params then
		return
	end
	local min_aim_range = aoe_params.min_range * const.SlabSizeX
	local max_aim_range = aoe_params.max_range * const.SlabSizeX
	local lof_params = { --todo: building lof_params should be a function of the combat action
		weapon = weapon,
		step_pos = dialog.move_step_position or attacker:GetOccupiedPos(),
		prediction = true,
	}
	local attack_data = attacker:ResolveAttackParams(action.id, pt, lof_params)
	local attacker_pos3D = attack_data.step_pos
	if not attacker_pos3D:IsValidZ() then attacker_pos3D = attacker_pos3D:SetTerrainZ() end

	if not blackboard.movement_avatar then 
		UpdateMovementAvatar(dialog, point20, nil, "setup")
		UpdateMovementAvatar(dialog, point20, nil, "update_weapon")
		blackboard.movement_avatar:SetVisible(false)
		blackboard.move_avatar_visible = false
		blackboard.move_avatar_time = RealTime()
		--blackboard.movement_avatar:SetOpacity(0)
		--blackboard.movement_avatar_opacity = 0
	end	

	if not IsCloser(attacker, attack_data.step_pos, const.SlabSizeX / 2 + 1) then
		UpdateMovementAvatar(dialog, attack_data.step_pos, false, "update_pos")
		local aim_anim = attacker:GetAimAnim(attack_data.action_id, attack_data.stance)
		blackboard.movement_avatar:SetState(aim_anim, 0, 0)
		blackboard.movement_avatar:Face(pt)
		--blackboard.movement_avatar:SetVisible(true)
		SetAreaMovementAvatarVisibile(dialog, blackboard, true, AreaTargetMoveAvatarVisibilityDelay)
		--[[if blackboard.movement_avatar_opacity == 0 then
			local o = blackboard.movement_avatar:GetOpacity()
			local t = MulDivRound(AreaTargetMoveAvatarVisibilityDelay, 100 - o, 100)
			blackboard.movement_avatar:SetOpacity(100, t)
			blackboard.movement_avatar_opacity = 100
		end--]]
	elseif blackboard.movement_avatar then
		--blackboard.movement_avatar:SetVisible(false)
		SetAreaMovementAvatarVisibile(dialog, blackboard, false, AreaTargetMoveAvatarVisibilityDelay)
		--[[if blackboard.movement_avatar_opacity ~= 0 then
			local o = blackboard.movement_avatar:GetOpacity()
			local t = MulDivRound(AreaTargetMoveAvatarVisibilityDelay, o, 100)
			blackboard.movement_avatar:SetOpacity(0, t)
			blackboard.movement_avatar_opacity = 0
		end--]]
	end

	if blackboard.gamepad_aim then
		local currentLength = blackboard.gamepad_aim_length
		if not currentLength then
			currentLength = max_aim_range
		end
		
		local gamepadState = GetActiveGamepadState()
		
		local ptRight = gamepadState and gamepadState.RightThumb or point20
		if ptRight ~= point20 then
			local up = ptRight:y() < -1
			currentLength = currentLength + 500 * (up and -1 or 1)
			currentLength = Clamp(currentLength, min_aim_range, max_aim_range)
			blackboard.gamepad_aim_length = currentLength
		end
		
		local ptLeft = gamepadState and gamepadState.LeftThumb or point20
		if ptLeft == point20 then
			if blackboard.gamepad_aim_last_pos then
				ptLeft = blackboard.gamepad_aim_last_pos 
			else
				local p1 = attacker:GetPos()
				local p2 = p1 + Rotate(point(5*guim, 0), attacker:GetAngle())
				local s1 = select(2, GameToScreen(p1))
				local s2 = select(2, GameToScreen(p2))
				local angle = CalcOrientation(s1, s2)
				ptLeft = Rotate(point(guim, 0), -angle) -- screen Y is reversed
			end
		end
		blackboard.gamepad_aim_last_pos = ptLeft
		
		ptLeft = ptLeft:SetY(-ptLeft:y())
		ptLeft = Normalize(ptLeft)
		
		local cameraDirection = point(camera.GetDirection():xy())
		local directionAngle = atan(cameraDirection:y(), cameraDirection:x())
		directionAngle = directionAngle + 90 * 60
		ptLeft = RotateAxis(ptLeft, axis_z, directionAngle)
		
		pt = attacker:GetPos() + SetLen(ptLeft, currentLength)

		local zoom = Lerp(800, hr.CameraTacMaxZoom * 10, currentLength, max_aim_range)
		cameraTac.SetZoom(zoom, 50)
	end

	-- Update targeting if unit not moving and the prediction pos is different or if too far from the last prediction pos
	local moved = dialog.target_as_pos ~= pt or blackboard.attacker_pos ~= attack_data.step_pos
	moved = moved or (dialog.target_as_pos and dialog.target_as_pos:Dist(pt) > 8 * guim)
	if not moved then
		return
	end
	local attacker_pos = attack_data.step_pos
	blackboard.attacker_pos = attacker_pos

	-- Show damage in hp bars, and highlit hit areas
	local aim_pt = lAoEGetAimPoint(attacker, pt, attacker_pos3D)
	dialog.target_as_pos = aim_pt
	local attack_distance = Clamp(attacker_pos3D:Dist(aim_pt), min_aim_range, max_aim_range)
	local args = {
		target = aim_pt,
		distance = attack_distance,
		step_pos = dialog.move_step_position,
	}
	ApplyDamagePrediction(attacker, action, args)
	dialog:AttackerAimAnimation(pt)

	-- Show targeting cone
	local cone2d = action.id == "Overwatch" or action.id == "DanceForMe" or action.id == "MGSetup"
	local cone_target = cone2d and CalcOrientation(attacker_pos, aim_pt) or aim_pt
	local stance = action.id == "MGSetup" and "Prone" or attacker.stance
	local step_positions, step_objs, los_values
	if action.id == "EyesOnTheBack" then
		step_positions, step_objs, los_values = GetAOETiles(attacker_pos, stance, attack_distance)
		blackboard.mesh = CreateAOETilesCircle(step_positions, step_objs, blackboard.mesh, attacker_pos3D, attack_distance, los_values)
	else 
		step_positions, step_objs, los_values = GetAOETiles(attacker_pos, stance, attack_distance, aoe_params.cone_angle, cone_target, "force2d")
		blackboard.mesh = CreateAOETilesSector(step_positions, step_objs, los_values, blackboard.mesh, attacker_pos3D, aim_pt, guim, attack_distance, aoe_params.cone_angle, false, aoe_params.falloff_start)
	end
	blackboard.mesh:SetColorFromTextStyle("WeaponAOE")
end

function Targeting_AOE_Cone_TargetRequired(dialog, blackboard, command, pt)
	local attacker = dialog.attacker
	local action = dialog.action
	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end

	if command == "setup" and not dialog.target then
		local defaultTarget = action:GetDefaultTarget(attacker)
		if not defaultTarget then
			dialog.context.free_aim = true
			return
		end
		dialog:SetTarget(defaultTarget)
	end

	if command == "delete" then
		if blackboard.mesh then
			DoneObject(blackboard.mesh)
			blackboard.mesh = false
		end

		SetAPIndicator(false, "free-aim")
		ClearDamagePrediction()
		return
	end

	-- Snapping cone to target
	local snapTarget = dialog.target or (dialog.potential_target_is_enemy and dialog.potential_target)
	if not snapTarget then
		local interactable = dialog:GetInteractableUnderCursor()
		if IsKindOf(interactable, "Trap") then
			snapTarget = interactable
		end
	end

	if not snapTarget then
		if dialog.window_state == "open" then
			CreateRealTimeThread(function()
				SetInGameInterfaceMode("IModeCombatMovement")
			end)
		end
		return
	end

	pt = snapTarget:GetPos()
	dialog.target_as_pos = pt

	-- Get attack data
	local weapon = action:GetAttackWeapons(attacker)
	local aoe_params = action:GetAimParams(attacker, weapon) or weapon:GetAreaAttackParams(action.id, attacker)
	local min_aim_range = aoe_params.min_range * const.SlabSizeX
	local max_aim_range = aoe_params.max_range * const.SlabSizeX
	local lof_params = {
		weapon = weapon,
		step_pos = dialog.move_step_position or attacker:GetOccupiedPos(),
		prediction = true,
	}
	local attack_data = attacker:ResolveAttackParams(action.id, snapTarget or pt, lof_params)
	local attacker_pos3D = attack_data.step_pos
	if not attacker_pos3D:IsValidZ() then attacker_pos3D = attacker_pos3D:SetTerrainZ() end
	local attacker_pos = attack_data.step_pos

	if not dialog.crosshair then
		local weaponRange = 0
		if IsKindOf(weapon, "Firearm") then
			assert(aoe_params.max_range)
			weaponRange = aoe_params.max_range * const.SlabSizeX
		end
		
		hr.CameraTacClampToTerrain = false
		
		local dontMoveCam = DoesTargetFitOnScreen(dialog, snapTarget)
		if not dontMoveCam then
			SnapCameraToObj(snapTarget, true)
		end

		local crosshair = dialog:SpawnCrosshair("closeOnAttack", not "meleePos", snapTarget, dontMoveCam)
		local cll = XTemplateSpawn("XCameraLockLayer", crosshair)
		cll:Open()
		crosshair.update_targets = true
	end

	-- Show damage in hp bars, and highlit hit areas
	local aim_pt = lAoEGetAimPoint(attacker, pt, attacker_pos3D)
	local attack_distance = Clamp(attacker_pos3D:Dist(aim_pt), min_aim_range, max_aim_range)
	if not dialog.crosshair then
		local args = {
			target = snapTarget or aim_pt,
			distance = attack_distance,
			step_pos = dialog.move_step_position,
		}
		ApplyDamagePrediction(attacker, action, args)
		dialog:AttackerAimAnimation(pt)
	end

	-- Show targeting cone
	local cone2d = action.id == "Overwatch"
	local cone_target = cone2d and CalcOrientation(attacker_pos, aim_pt) or aim_pt
	local step_positions, step_objs, los_values = GetAOETiles(attacker_pos, attacker.stance, attack_distance, aoe_params.cone_angle, cone_target)
	blackboard.mesh = CreateAOETilesSector(step_positions, step_objs, los_values, blackboard.mesh, attacker_pos3D, aim_pt, guim, attack_distance, aoe_params.cone_angle, false, aoe_params.falloff_start)
	blackboard.mesh:SetColorFromTextStyle("WeaponAOE")
end

function Targeting_AOE_ParabolaAoE(dialog, blackboard, command, pt)
	local attacker = dialog.attacker

	local attacker = dialog.attacker
	local action = dialog.action
	if dialog:PlayerActionPending(attacker) or dialog.attack_confirmed then
		command = "delete-except-grenade"
	end
	
	if command == "setup" then
		local weapon = action:GetAttackWeapons(attacker)
		if IsKindOf(weapon, "Grenade") then
			blackboard.grenade_actor = attacker
		end
	elseif command == "delete" or command == "delete-except-grenade" then		
		for _, mesh in ipairs(blackboard.meshes) do
			DoneObject(mesh)
		end
		blackboard.meshes = false
		for _, mesh in ipairs(blackboard.arc_meshes) do
			DoneObject(mesh)
		end
		blackboard.arc_meshes = false
		
		if command ~= "delete-except-grenade" then
			if blackboard.grenade_actor then
				local grenade = action:GetAttackWeapons(attacker)
				if grenade then
					blackboard.grenade_actor:DetachGrenade(grenade)
				end
			end
		end

		SetAPIndicator(false, "free-aim")
		SetAPIndicator(false, "mishap-chance")
		SetAPIndicator(false, "instakill-chance")
		SetAPIndicator(false, "danger-close")
		ClearDamagePrediction()
		return
	end

	-- Snapping cone to target
	local target = dialog.target or (dialog.potential_target_is_enemy and dialog.potential_target)

	-- Get attack data
	local weapon = action:GetAttackWeapons(attacker)
	local min_aim_range = action:GetMinAimRange(attacker, weapon)
	min_aim_range = min_aim_range and min_aim_range * const.SlabSizeX
	local max_aim_range = action:GetMaxAimRange(attacker, weapon)
	max_aim_range = max_aim_range and max_aim_range * const.SlabSizeX
	local gas = weapon and (weapon.aoeType == "smoke" or weapon.aoeType == "teargas" or weapon.aoeType == "toxicgas")
	local lof_params = {
		weapon = weapon,
		step_pos = dialog.move_step_position or attacker:GetOccupiedPos(),
		stance = "Standing",
		prediction = true,
	}
	local attack_data = attacker:ResolveAttackParams(action.id, pt, lof_params)
	local attacker_pos3D = attack_data.step_pos
	if not attacker_pos3D:IsValidZ() then attacker_pos3D = attacker_pos3D:SetTerrainZ() end
	local attacker_pos = attack_data.step_pos
	local aim_pt = lAoEGetAimPoint(attacker, pt, attacker_pos3D)
	if not IsCloser(attacker_pos3D, aim_pt, max_aim_range + 1) then
		aim_pt = attacker_pos3D + SetLen(aim_pt - attacker_pos3D, max_aim_range)
	end

	aim_pt = weapon:ValidatePos(aim_pt)

	-- Update prediction only when hasn't moved for a while or passed some time
	if not gas and blackboard.prediction_args and (RealTime() - blackboard.prediction_time > 0 or 
		not blackboard.last_prediction or RealTime() - blackboard.last_prediction > 1000)
	then
		ApplyDamagePrediction(attacker, action, blackboard.prediction_args)
		blackboard.prediction_args = false
		blackboard.last_prediction = RealTime()

		local dialog_target = IsKindOf(dialog.target, "Unit") and dialog.target or pt
		dialog:AttackerAimAnimation(dialog_target)
	end

	-- Update targeting if unit not moving and the prediction pos is different or if too far from the last prediction pos
	local moved = dialog.target_as_pos ~= aim_pt or blackboard.attacker_pos ~= attack_data.step_pos
	if not moved then
		return
	end

	-- Show damage in hp bars
	dialog.target_as_pos = aim_pt
	dialog.args_gotopos = attacker_pos
	blackboard.attacker_pos = attack_data.step_pos
	
	-- If no aim pt clear meshes.
	if not aim_pt then
		blackboard.prediction_args = false
		blackboard.last_prediction = false
		ClearDamagePrediction()
		
		for i, m in ipairs(blackboard.meshes) do
			DoneObject(m)
		end
		blackboard.meshes = false
		
		for i, m in ipairs(blackboard.arc_meshes) do
			DoneObject(m)
		end
		blackboard.arc_meshes = false
		
		SetAPIndicator(1000, "mishap-chance", AttackDisableReasons.InvalidTarget, "append")
		return
	end
	
	if IsKindOf(weapon, "MishapProperties") then
		local chance = weapon:GetMishapChance(attacker, aim_pt, "async")
		if CthVisible() then
			SetAPIndicator(1, "mishap-chance", T{426191353094, "<percent(num)> Mishap Chance", num = chance}, "append", "force update") -- force update because chance may change
		else
			SetAPIndicator(1, "mishap-chance", TFormat.MishapToText(chance), "append", "force update") -- force update because chance may change
		end
	end
	
	if IsKindOfClasses(weapon, "HeavyWeapon", "Grenade") and HasPerk(attacker, "DangerClose") then
		local targetRange = attacker:GetDist(pt)
		local dangerClose = CharacterEffectDefs.DangerClose
		local rangeThreshold = dangerClose:ResolveValue("rangeThreshold") * const.SlabSizeX
		if targetRange <= rangeThreshold then
			SetAPIndicator(1, "danger-close", T{190936138167, "<perkName> - in range", perkName = dangerClose.DisplayName}, "append")
		else
			SetAPIndicator(false, "danger-close")
		end
	end
	
	local results, attack_args = action:GetActionResults(attacker, {target = aim_pt, step_pos = attacker_pos, prediction = true})
	
	-- Queue damage prediction
	blackboard.prediction_args = { target = aim_pt, distance = attacker_pos3D:Dist(aim_pt) }
	blackboard.prediction_time = RealTime() + 50

	local attacks = results.attacks or {results}
	blackboard.meshes = blackboard.meshes or {}
	blackboard.arc_meshes = blackboard.arc_meshes or {}
	
	local attack_params = weapon:GetAreaAttackParams(action.id, attacker, aim_pt)
	local range = attack_params.max_range * const.SlabSizeX
	local stance = attack_params.stance or IsValid(attacker) and attacker.stance or 1
	
	for i, attack in ipairs(attacks) do
		-- Build mesh
		local attack_args = attack.attack_args or attack_args
		local trajectory = attack.trajectory or empty_table
		local atk_pos = attack_args.target
		local explosion_pos = attack.explosion_pos or ((#trajectory > 0) and trajectory[#trajectory].pos)
		
		if explosion_pos then	
			if weapon.coneShaped then
				local cone_length = attack_params.cone_length
				local cone_angle = attack_params.cone_angle
				if terrain.GetHeight(explosion_pos) > explosion_pos:z() - guim then
					explosion_pos = explosion_pos:SetTerrainZ(guim)
				end
				local target = RotateRadius(cone_length, CalcOrientation(attack_args.step_pos, explosion_pos), explosion_pos)
				local step_positions, step_objs, los_values = GetAOETiles(explosion_pos, stance, cone_length, cone_angle, target, "force2d")
				blackboard.meshes[i] = CreateAOETilesSector(step_positions, step_objs, los_values, blackboard.meshes[i], explosion_pos, target, 0, cone_length, cone_angle, "GrenadeConeShapedTilesCast")
			else
				local step_positions, step_objs, los_values = GetAOETiles(explosion_pos, stance, range)
				if gas then
					step_objs, los_values = empty_table, empty_table
				end
				local data = {
					explosion_pos = explosion_pos,
					stance = stance,
					range = range,
					step_positions = step_positions,
					step_objs = step_objs,
					los_values = los_values
				}
				if not blackboard.meshes[i] or not IsValid(blackboard.meshes[i]) then
					local is_mortar = IsKindOfClasses(weapon, "MortarInventoryItem", "TrapDetonator")
					local class = is_mortar and MortarAOEVisuals or GrenadeAOEVisuals
					blackboard.meshes[i] = class:new({mode = "Ally", state = "blueprint"}, nil, data)
				end
				blackboard.meshes[i]:RecreateAoeTiles(data)
				blackboard.meshes[i]:SetPos(explosion_pos)
			end
			
			-- Build trajectory mesh
			local arc_mesh = blackboard.arc_meshes[i]
			if not arc_mesh then
				arc_mesh = Mesh:new()
				arc_mesh:SetMeshFlags(const.mfWorldSpace)
				arc_mesh:SetShader(ProceduralMeshShaders.path_contour)
				blackboard.arc_meshes[i] = arc_mesh
			end
			
			local mesh = pstr("", 1024)
			
			local attackVector = attacker_pos - atk_pos
			if attackVector:Len() == 0 then
				attackVector = false
			end

			local prev
			local prevDir
			local distance = 0
			for _, step in ipairs(trajectory) do
				local pos = step.pos
				if prev then
					distance, prevDir = CRTrail_AppendLineSegment(mesh, prev, pos, distance, prevDir, attackVector)
				end
				prev = pos
			end
			
			arc_mesh:SetPos(attacker_pos)
			arc_mesh:SetMesh(mesh)
			local mat = CRM_VisionLinePreset:GetById("CastTrajectoryArc"):Clone()
			mat.length = distance
			arc_mesh:SetCRMaterial(mat) -- "CastTrajectoryArc")
		else
			if blackboard.meshes[i] then
				DoneObject(blackboard.meshes[i])
				blackboard.meshes[i] = false
			end
			if blackboard.arc_meshes[i] then
				DoneObject(blackboard.arc_meshes[i])
				blackboard.arc_meshes[i] = false
			end
			local reason = (#trajectory > 0) and AttackDisableReasons.InvalidTarget or AttackDisableReasons.NoFireArc
			SetAPIndicator(1000, "mishap-chance", reason, "append")
		end
	end

	if g_ShowGrenadeVolume then	
		DbgClearVectors()
		for _, voxel in ipairs(volume or empty_table) do
			local pos = point(point_unpack(voxel))
			DbgAddVoxel(pos, const.clrWhite)
		end
	end
end

local function NormalizeConeFragmentLen(len, whole_len)
	return MulDivRound(len, 1000, whole_len)
end

local function GetPointsFromCurve(center, pt1x, pt1y, pt1z, pt2x, pt2y, pt2z, pts_count)
	local pts = {point(pt1x, pt1y, pt1z)}
	local rad_v = point(pt1x - center:x(), pt1y - center:y(), pt1z - center:z())
	local v2 = point(pt2x - center:x(), pt2y - center:y(), pt2z - center:z())
	local axis, angle = GetAxisAngle(rad_v, v2)
	local angle = MulDivRound(angle, 1, pts_count-1)
	for i = 1, pts_count - 2 do
		pts[#pts+1] = center + RotateAxis(rad_v, axis, angle * i)
	end
	pts[#pts+1] = point(pt2x, pt2y, pt2z)
	return pts
end

function ConstructConeAreaShapes(origin, aim_pt, cone_angle, num_curve_pts, z)
	local minz = terrain.GetHeight(origin) + const.SlabSizeZ / 2
	if not origin:IsValidZ() or origin:z() < minz then
		origin = origin:SetZ(minz)
	end
	
	local dir = (aim_pt - origin):SetZ(0)
	local ptA = origin + Rotate(dir, -cone_angle / 2)
	local ptB = origin + Rotate(dir,  cone_angle / 2)
	
	local base_shape = { origin, ptA }
	local ax, ay, az = ptA:xyz()
	local bx, by, bz = ptB:xyz()
	local added = { 
		[point_pack(origin:xy())] = true, 
		[point_pack(ptA:xy())] = true, 
	}
	local curve_pts = GetPointsFromCurve(origin,  ax,  ay,  az, bx, by, bz, num_curve_pts or 7)
	for i, pt in ipairs(curve_pts) do
		local packed = point_pack(pt:xy())
		if not added[packed] then
			base_shape[#base_shape + 1] = pt
			added[packed] = true
		end
	end
		
	local vertices = {
		point(-const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2, -const.SlabSizeY / 2),
		point( const.SlabSizeX / 2,  const.SlabSizeY / 2),
		point(-const.SlabSizeX / 2,  const.SlabSizeY / 2),
	}
	local ms_points = {}
	for _, pt in ipairs(base_shape) do
		for _, vert in ipairs(vertices) do
			ms_points[#ms_points + 1] = pt + vert
		end
	end
	
	local ms_shape = ConvexHull2D(ms_points)
	
	if z then
		for i, pt in ipairs(base_shape) do
			base_shape[i] = pt:SetZ(z)
		end
		for i, pt in ipairs(ms_shape) do
			ms_shape[i] = pt:SetZ(z)
		end
	end
	
	return base_shape, ms_shape
end

function CreateAOETiles(voxels, step_objs, values)
	local color = const.clrWhite
	local z_offset = 10*guic
	local mesh = pstr("", 1024)
	local xAvg, yAvg = AppendVerticesAOETilesMesh(mesh, voxels, step_objs, values, color, z_offset)
	return mesh, xAvg, yAvg 
end

function CreateAOETilesCircle(voxels, step_objs, obj, center, r, values, material_override)
	assert(center:z())
	local mesh, avgx, avgy = CreateAOETiles(voxels, step_objs, values)

	if not obj then
		obj = Mesh:new()
		obj:SetMeshFlags(const.mfWorldSpace)
	end

	obj:SetMesh(mesh)

	local mat = obj.CRMaterial
	if not mat then
		if type(material_override) == "string" then
			mat = CRM_AOETilesMaterial:GetById(material_override):Clone()
		elseif not material_override then
			mat = CRM_AOETilesMaterial:GetById("EyesOnTheBack1_Blueprint"):Clone()
		else
			mat = material_override
		end
		mat.GridPosX = center:x()
		mat.GridPosY = center:y()
	end
	mat.center = center
	mat.radius = r
	-- mat.Transparency0_Distance = r2 * (falloff_percent or 100) / 100
	-- mat.Transparency1_Distance = mat.Transparency0_Distance + (r2 - mat.Transparency0_Distance) * 33 / 100
	-- mat.Transparency2_Distance = mat.Transparency0_Distance + (r2 - mat.Transparency0_Distance) * 66 / 100
	-- mat.Transparency3_Distance = r2
	mat.dirty = true
	obj:SetCRMaterial(mat)


	if avgx then
		obj:SetPos(avgx, avgy, terrain.GetHeight(avgx, avgy))
	end
	return obj
end

function CreateAOETilesCylinder(voxels, step_objs, obj, center, r, values)
	local mesh, avgx, avgy = CreateAOETiles(voxels, step_objs, values)

	if not obj then
		obj = Mesh:new()
		obj:SetMeshFlags(const.mfWorldSpace)
	end

	obj:SetMesh(mesh)
	obj:SetUniforms(center:x(), center:y(), center:z(), r)
	obj:SetShaderName("aoe_tiles_cylinder")
	if avgx then
		obj:SetPos(avgx, avgy, terrain.GetHeight(avgx, avgy))
	end
	return obj
end

function CreateAOETilesSector(voxels, step_objs, values, obj, center, target, r1, r2, cone_angle, material, falloff_percent)
	local dir_angle = CalcOrientation(center, target)
	local ray1 = RotateRadius(4096, dir_angle - cone_angle / 2 + 90*60) -- + point(4096, 4096, 0)
	local ray2 = RotateRadius(4096, dir_angle + cone_angle / 2 - 90*60) -- + point(4096, 4096, 0)
	local main_ray = RotateRadius(4096, dir_angle)

	local mesh, avgx, avgy = CreateAOETiles(voxels, step_objs, values)

	if not obj then
		obj = Mesh:new()
		obj:SetMeshFlags(const.mfWorldSpace)
	end
	
	obj:SetMesh(mesh)
	
	local mat = obj.CRMaterial
	if not mat then
		mat = CRM_AOETilesMaterial:GetById(material or "Overwatch_Default"):Clone()
		mat.GridPosX = center:x()
		mat.GridPosY = center:y()
	end
	mat.center = center:IsValidZ() and center or center:SetTerrainZ()
	mat.radius1 = r1
	mat.radius2 = r2
	mat.ray1 = ray1
	mat.ray2 = ray2
	mat.main_ray = main_ray
	mat.vertical_angle = MulDivRound(cone_angle, 3141, 180 * 60)
	mat.horizontal_angle = mat.vertical_angle
	mat.Transparency0_Distance = r2 * (falloff_percent or 100) / 100
	mat.Transparency1_Distance = mat.Transparency0_Distance + (r2 - mat.Transparency0_Distance) * 33 / 100
	mat.Transparency2_Distance = mat.Transparency0_Distance + (r2 - mat.Transparency0_Distance) * 66 / 100
	mat.Transparency3_Distance = r2
	mat.dirty = true
	obj:SetCRMaterial(mat)

	--obj:SetShader(ProceduralMeshShaders.debug_mesh)
	if avgx then
		obj:SetPos(avgx, avgy, terrain.GetHeight(avgx, avgy))
	end

	
	return obj, avgx and terrain.GetHeight(avgx, avgy)
end