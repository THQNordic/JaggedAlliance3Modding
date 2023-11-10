local mobile_targeting_special_args = {no_ap_indicator = true, show_unreachable_indicator = true, show_stance_arrows = false, hide_avatar = true}
function Targeting_Mobile(dialog, blackboard, command, pt)
	local attacker = dialog.attacker
	local action = dialog.action
		
	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end
	
	if command == "setup" then
		dialog.args_gotopos = true
		dialog.disable_mouse_indicator = true
		local weapon = action:GetAttackWeapons(attacker)
		local aim_params = action:GetAimParams(attacker, weapon)
		if aim_params.move_ap then
			blackboard.combat_path = CombatPath:new()
			blackboard.combat_path:RebuildPaths(attacker, aim_params.move_ap, nil, "Standing", nil, nil, action.id)
			blackboard.custom_combat_path = true
		end
	end

	Targeting_Movement(dialog, blackboard, command, pt, mobile_targeting_special_args)

	local clickWillSelect = dialog.potential_target and dialog.potential_target:CanBeControlled()
	if clickWillSelect then
		SetAPIndicator(false, "unreachable")
	end

	if command == "delete" then
		if blackboard.fx_target then
			PlayFX(blackboard.fx_target_action, "end", blackboard.fx_target)
			blackboard.fx_target = false
		end
		if blackboard.combat_path then
			DoneObject(blackboard.combat_path)
			blackboard.combat_path = nil
		end
		for i, fx in ipairs(blackboard.fx_shot_lines) do
			DoneObject(fx)
		end
		blackboard.fx_shot_lines = false
		dialog.args_gotopos = false
		SetAPIndicator(false, "moving-attack")

		if IsValid(blackboard.melee_range_indicator) then
			DoneObject(blackboard.melee_range_indicator)
			blackboard.melee_range_indicator = false
		end

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
	
	local goto_pos = dialog.target_pos
	if goto_pos == blackboard.last_goto and not blackboard.stanceChanged then return end
	blackboard.last_goto = goto_pos
	
	-- Prevent updates while the camera is moving between targets.
	-- This allows the gamepad to cycle between targets.
	if GetUIStyleGamepad() then
		local timeSinceLastSetTarget = dialog.last_set_target_time or 0
		if RealTime() - timeSinceLastSetTarget < SnapCameraToObjInterpolationTimeDefault then
			return
		end
	end

	local shot_positions, shot_targets, shot_cth, valid_shots = {}, {}, {}, 0
	local results = dialog.action:GetActionResults(dialog.attacker, {goto_pos = goto_pos, prediction = true})
	for i, attack in ipairs(results.attacks or empty_table) do
		shot_positions[i] = attack.mobile_attack_pos or false
		shot_targets[i] = attack.mobile_attack_target
		shot_cth[i] = attack.chance_to_hit
		if IsValidTarget(attack.mobile_attack_target) then
			valid_shots = valid_shots + 1
		end
	end
	
	local movement_mode = IsKindOf(dialog, "IModeCombatMovement")
	if valid_shots > 0 then
		UpdateMovementAvatar(dialog, goto_pos, movement_mode and blackboard.fxToDoStance or "Standing", "update_pos")
	else
		UpdateMovementAvatar(dialog, point20,  movement_mode and blackboard.fxToDoStance or "Standing", "update_pos")
		SetAPIndicator(APIndicatorNoTarget, results.shot_canceling_reason or "unreachable")
	end
	dialog.movement_mode = true
	dialog:UpdateTargetCovers("force")
	
	for i, fx in ipairs(blackboard.fx_shot_lines) do
		DoneObject(fx)
	end
	blackboard.fx_shot_lines = false
	blackboard.shot_targets = shot_targets
	blackboard.shot_positions = shot_positions
	blackboard.shot_cth = shot_cth
	ClearDamagePrediction()
	
	if valid_shots > 0 then
		local fx_shot_lines = {}
		blackboard.fx_shot_lines = fx_shot_lines

		for i, pos in ipairs(shot_positions or empty_table) do
			local target = shot_targets[i]
			local cth = shot_cth[i]
			if pos and target then
				local color = Mesh.ColorFromTextStyle("LineOfFire")
							
				local x, y, z = target:GetPosXYZ()
				local posx, posy, posz = point_unpack(pos)
												
				local attack_pos = point(posx, posy, posz or terrain.GetHeight(posx, posy) + dialog.fx_lof_offset)
				local target_pos = point(x, y, z or terrain.GetHeight(x, y) + dialog.fx_lof_offset)
				
				fx_shot_lines[i] = AddShotVisual(nil, attack_pos, target_pos, color)
				local args = { target = target, step_pos = attack_pos, goto_pos = goto_pos }
				if valid_shots == 1 then
					dialog:SetTarget(target, true, args)
				end
				ApplyDamagePrediction(attacker, action, args, results)
			else
				fx_shot_lines[i] = false
			end			
		end

		local apCost = action:GetAPCost(attacker, { goto_pos = goto_pos })
		local extraAP = false
		if blackboard.fxToDoStance and blackboard.fxToDoStance ~= attacker.stance then
			extraAP = CombatActions["Stance"..blackboard.fxToDoStance]:GetAPCost(attacker)
			apCost = apCost + extraAP
		end
		SetAPIndicator(apCost, "moving-attack")
		ObjModified(APIndicator) -- Manually notify because the cost could be the same
	else
		SetAPIndicator(false, "moving-attack")
	end
	
	-- When using gamepad show the target under the cursor.
	-- This allows cycling between targets with LB/RB
	if GetUIStyleGamepad() and dialog.potential_target then
		dialog:SetTarget(dialog.potential_target, true)
		return
	end
	
	-- If more than one shot (or zero shots), it isn't clear which one we're inspecting.
	if valid_shots ~= 1 then
		dialog:SetTarget(false, true)
	end
end

DefineClass.IModeCombatMovingAttack = {
	__parents = { "IModeCombatAttackBase" },
	target_as_pos = true
}

function IModeCombatMovingAttack:GetAttackContourPreset(inside_attack_area)
	local active = false
	local preset_id = "BorderlineTurn"
	local action = self.context.action
	local cost = action and action:GetAPCost(SelectedObj) or -1
	local baseAttack = SelectedObj:GetDefaultAttackAction(true)
	cost = cost + (baseAttack and baseAttack:GetAPCost(SelectedObj) or 0)
	if cost >= 0 and SelectedObj:HasAP(cost) then
		preset_id = "BorderlineAttackActive"
		active = true
	end
	
	return preset_id, active
end

function IModeCombatMovingAttack:Confirm()
	local blackboard = self.targeting_blackboard
	if not blackboard then return end

	if self.potential_target and self.potential_target:CanBeControlled() then
		SelectObj(self.potential_target)
		return
	end

	-- Custom errors
	local anyValidShotPos = false
	for i, sh in ipairs(blackboard.shot_positions or empty_table) do
		if sh then
			anyValidShotPos = true
			break
		end
	end
	if not self.target_path or not anyValidShotPos then
		if not self.target_path then
			if not self.target_pos then
				ReportAttackError(GetCursorPos(), AttackDisableReasons.Impassable)
			elseif IsOccupied(self.target_pos) then
				ReportAttackError(GetCursorPos(), AttackDisableReasons.Occupied)
			else
				ReportAttackError(GetCursorPos(), AttackDisableReasons.OutOfRange)
			end
		else
			ReportAttackError(GetCursorPos(), AttackDisableReasons.NoTarget)
		end
		return
	end
	
	return IModeCombatAttackBase.Confirm(self)
end

local function EvalEnemiesFromList(action_id, attacker, args, action, enemies, atk_pos, weapon, default, max_range)
	local best_enemy, best_chance_to_hit, canceling_reason
	for i, enemy in ipairs(enemies) do
		if IsValidTarget(enemy) then
			args.target = enemy
			args.step_pos = atk_pos
			local attack_args = attacker:PrepareAttackArgs(action_id, args)
			if not attack_args.stuck then -- otherwise there's no LOF
				local dist = enemy:GetDist(atk_pos)
				attack_args.range = dist + guim -- we only care about whether or not we can hit the intended target here, no need to check trajectory all the way to Africa
				local results = weapon:GetAttackResults(default, attack_args)						
				if results.target_hit and (not max_range or max_range >= dist) then
					if not results.allyHit then
						return enemy, results.chance_to_hit
					end
					if not best_enemy then
						best_enemy, best_chance_to_hit, canceling_reason = enemy, results.chance_to_hit, "ally_hit"
					end
				end
			end
		end
	end
	if best_enemy then
		return best_enemy, best_chance_to_hit, canceling_reason
	end
	return nil, 0
end

function FindTargetFromPos(action_id, attacker, action, enemies, atk_pos, weapon, can_use_covers)
	local nearest, nearest_dist, cth
	local nearest_down, nearest_down_dist, down_cth
	local args = {
		obj = attacker,
		weapon = weapon,
		step_pos = atk_pos,
		stance = "Standing",
		attack_roll = 0,
		can_use_covers = can_use_covers or false,
		prediction = true,
	}
	local default = attacker:GetDefaultAttackAction("ranged", nil, weapon)
	local max_range = action:GetMaxAimRange(attacker, weapon)
	if IsKindOf(weapon, "Firearm") then
		max_range = max_range or weapon.WeaponRange
		max_range = MulDivRound(max_range, 150 * const.SlabSizeX, 100)
	else
		max_range = max_range and (max_range * const.SlabSizeX)
	end
	-- find nearest shootable enemy from atk_pos
	-- sort by distance, then select only non-downed units if there are any
	table.sort(enemies, function(a, b)
		local distA = a:GetDist(atk_pos)
		local distB = b:GetDist(atk_pos)
		if distA == distB then
			return a.handle < b.handle
		end
		return distA < distB
	end)

	local primary, secondary = {}, {}
	for _, enemy in ipairs(enemies) do
		if IsKindOf(enemy, "Unit") then
			local tbl = enemy:IsDowned() and secondary or primary
			tbl[#tbl + 1] = enemy
		end
	end
	
	local best_enemy, best_chance_to_hit, canceling_reason = EvalEnemiesFromList(action_id, attacker, args, action, primary, atk_pos, weapon, default, max_range)
	if best_enemy and not canceling_reason then
		return best_enemy, best_chance_to_hit
	end
	local sec_enemy, sec_cth, sec_reason = EvalEnemiesFromList(action_id, attacker, args, action, secondary, atk_pos, weapon, default, max_range)
	if sec_enemy and not sec_reason then
		return sec_enemy, sec_cth
	end
	if best_enemy then
		return best_enemy, best_chance_to_hit, canceling_reason
	end
	return sec_enemy, sec_cth, sec_reason 
end

function CalcMobileShotAttacks(attacker, action, attack_pos, enemies, weapon)
	enemies = enemies or action:GetTargets({attacker})
	weapon = weapon or action:GetAttackWeapons(attacker)
	local aim_type = action.AimType
	if aim_type ~= "mobile" then return end
	local aim_params = action:GetAimParams(attacker, weapon)
	
	local combat_path = CombatPath:new()
	combat_path:RebuildPaths(attacker, aim_params.move_ap, nil, "Standing", nil, nil, action.id)
	local voxel_path = combat_path:GetCombatPathFromPos(attack_pos)	
	if not voxel_path then 
		DoneObject(combat_path)
		return 
	end
	
	local shot_voxel_candidates = {}
	
	local path = {}
	for i, voxel in ipairs(voxel_path) do
		path[i] = point(point_unpack(voxel))
	end
	local path_voxels, voxel_dist, total_dist = CalcPathVoxels(path)
	local atk_voxel = point_pack(attack_pos)
	if path_voxels[1] ~= atk_voxel then
		table.insert(path_voxels, 1, atk_voxel)
	end
		
	shot_voxel_candidates[1] = { atk_voxel }
	local num_shots = aim_params.num_shots
	local step = #path_voxels / Max(1, num_shots)
	for i = 2, num_shots do
		local idx = 1 + step * (i-1)
		table.insert(shot_voxel_candidates, 1, { path_voxels[idx], path_voxels[idx-1], path_voxels[idx+1] })
	end
	
	-- process candidates
	local shot_voxels, targets, shot_cth, shot_canceling_reason = {}, {}, {}, {}
	
	for i, candidates in ipairs(shot_voxel_candidates) do
		shot_voxels[i] = false
		targets[i] = false
		for _, voxel in ipairs(candidates) do
			if not table.find_value(shot_voxels, voxel) then
				local pos = point(point_unpack(voxel))
				local target, cth, canceling_reason = FindTargetFromPos(action.id, attacker, action, enemies, pos, weapon, i == #shot_voxel_candidates)
				if target then
					shot_voxels[i] = voxel
					targets[i] = target
					shot_cth[i] = cth
					shot_canceling_reason[i] = canceling_reason
					break
				end
			end
		end
	end
	
	DoneObject(combat_path)
	
	return shot_voxels, targets, shot_cth, shot_canceling_reason
end

function AddShotVisual(fx, attack_pos, target_pos, color)	
	local meshPtr = pstr("")
	
	local dir = target_pos - attack_pos
	local length = dir:Len()


	CRTrail_AppendLineSegment(meshPtr, attack_pos, target_pos, false, false, false)

	if not fx then
		fx = PlaceObject("Mesh")
		fx:SetMeshFlags(const.mfWorldSpace)
	end
	local mat = CRM_VisionLinePreset:GetById("DefaultVision"):Clone()
	mat.length = length
	fx:SetCRMaterial(mat)
	
	fx:SetMesh(meshPtr)
	fx:SetPos(attack_pos)
	return fx
end

function GetMobileShotResults(action, unit, args)
	local weapon = action:GetAttackWeapons(unit)

	args = table.copy(args)
	args.step_pos = args.goto_pos -- needed in PrepareAttackArgs
	local shot_positions, shot_targets, shot_ch, shot_canceling_reason = CalcMobileShotAttacks(unit, action, args.goto_pos)
	local attacks = {}
	local attack_args

	-- resolve attack action
	local attack_id, atk_action	
	if args.attack_id and args.attack_id ~= action.id then
		attack_id = args.attack_id
		atk_action = CombatActions[attack_id] or CombatActions.SingleShot
	else
		attack_id = "SingleShot"
		atk_action = CombatActions.SingleShot
	end
	local canceling_reason

	for i, pos in ipairs(shot_positions) do
		local target = shot_targets[i]
		local results, attack_args
		if pos and IsValidTarget(target) and not shot_canceling_reason[i] then
			--[[ 
				In prediction mode we need to presim the attacks (and merge the results later) for UI / damage prediction.
				When simulating the actual attack this extra work isn't needed as Unit:RunAndGun needs to recalculate it anyway after movement.
				Thus, we only pack the relevant data - the position and target. The target can also change, but we have it anyway and we prefer
				to stick to it so the gameplay effects better reflect what we show the user in prediction.
			--]]
			if args.prediction then
				args.target = target
				args.step_pos = point(point_unpack(pos))
				args.attack_roll = args.attack_rolls and args.attack_rolls[i]
				args.crit_roll = args.crit_rolls and args.crit_rolls[i]
				args.stealth_kill_roll = args.stealth_kill_rolls and args.stealth_kill_rolls[i]
				args.used_action_id = action.id -- so that cth is calculated for the master/parent action instead of the actual attack action
				args.stance = "Standing"
				args.can_use_covers = false
				local results, attack_args = atk_action:GetActionResults(unit, args)
				attacks[i] = results
				attacks[i].mobile_attack_id = attack_id
				attacks[i].mobile_attack_pos = pos
				attacks[i].mobile_attack_target = target
				attacks[i].attack_args = attack_args
			else
				attacks[i] = {
					mobile_attack_id = attack_id,
					mobile_attack_pos = pos,
					mobile_attack_target = target,
				}
			end
		else
			attacks[i] = {}
		end
	end

	local results
	if args.prediction then
		results = MergeAttacks(attacks)
		results.shot_canceling_reason = shot_canceling_reason and shot_canceling_reason[#shot_canceling_reason]
	else
		results = { attacks = attacks }
	end
	return results, attack_args
end