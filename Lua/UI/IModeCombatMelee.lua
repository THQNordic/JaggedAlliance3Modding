function GetMeleeAttackCombatPath(action, obj)
	local hash, path = 0
	local base_action_cost, stance_change_cost, stance = 0, 0, false
	if action then
		local x
		base_action_cost, x, stance = action:GetAPCost(obj, { goto_pos = false })
		if stance and obj.stance ~= stance then
			stance_change_cost = obj:GetStanceToStanceAP(stance)
		end
	end

	if IsValid(obj) then
		hash = xxhash(obj.handle, obj:GetUIActionPoints(), obj:GetPos(), base_action_cost)
		path = CombatPath:new()
		local withChargeAP = action.AimType == "melee-charge" and action:ResolveValue("move_ap") * const.Scale.AP + base_action_cost
		local ap = (withChargeAP or obj.ActionPoints) - base_action_cost - stance_change_cost
		path:RebuildPaths(obj, ap, nil, stance)
	end
	
	return path, hash
end

function DeleteMeleeVisualization(blackboard)
	if blackboard.adjacent_contour then
		DestroyMesh(blackboard.adjacent_contour)
		blackboard.adjacent_contour = false
	end
	
	if blackboard.fx_adjacent_action then
		PlayFX(blackboard.fx_adjacent_action, "end")
	end
	
	if blackboard.contour_target then
		DestroyMesh(blackboard.target_action_contour)
		blackboard.contour_target = false
	end
	
	if blackboard.fx_arrow then
		DoneObject(blackboard.fx_arrow)
		blackboard.fx_arrow = false
	end
end

selection_decal_scale = 130
diagonal_arrow_scale = 150

local function lGetArrowPosScale(target_pos, tile_pos)
	local arrow_pos
	if target_pos:x() == tile_pos:x() or target_pos:y() == tile_pos:y() then
		return target_pos * 4 / 7 + tile_pos * 3 / 7, selection_decal_scale
	end
	return (target_pos + tile_pos) / 2, diagonal_arrow_scale
end

function MeleeTargetingUpdateMovementAvatar(dialog, blackboard, attack_pos)
	local target = dialog.target
	local attacker = dialog.attacker
	if blackboard.movement_avatar then
		attack_pos = attack_pos or (dialog.target_pos and target ~= attacker) and dialog.target_pos
		if attack_pos then
			if attacker:GetPos() ~= attack_pos then
				blackboard.movement_avatar:SetPos(attack_pos)
			elseif attack_pos ~= blackboard.movement_avatar:GetPos() then
				blackboard.movement_avatar:SetPos(point20)
			end
		end
		if IsValid(target) and target ~= attacker then
			-- orient by target and use the "enabled" color
			blackboard.movement_avatar:SetHierarchyEnumFlags(const.efVisible)
			blackboard.movement_avatar:SetObjectMarking(5)
			local goto_pos = blackboard.movement_avatar:GetPos()
			local approach_attack_angle
			if blackboard.target_path and #blackboard.target_path >= 2 then
				approach_attack_angle = CalcOrientation(point(point_unpack(blackboard.target_path[2])), goto_pos)
			end
			local can_attack, angle = IsMeleeRangeTarget(attacker, goto_pos, attacker.stance, target, nil, target.stance, approach_attack_angle)
			if not angle then
				angle = CalcOrientation(goto_pos, target)
			end
			local orientation_angle = attacker:GetPosOrientation(goto_pos, angle)
			blackboard.movement_avatar:SetOrientation(axis_z, orientation_angle)
			MovementAvatar_PlayAnim(dialog, attacker, blackboard)
		else
			-- use the "disabled" color
			blackboard.movement_avatar:ClearHierarchyEnumFlags(const.efVisible)
		end
	end	
end

function GetMeleeTiles(attacker, target)
	if target.behavior == "Visit" and IsKindOf(target.last_visit, "AL_SitChair") then
		return {point_pack(target.last_visit:GetPos())}
	end
	return MeleeCombatActionGetValidTiles(attacker, target)
end

local melee_targeting_special_args = { no_ap_indicator = true, show_on_target = true, show_stance_arrows = false }

function Targeting_Melee(dialog, blackboard, command, pt)
	local action = dialog.action
	local attacker = dialog.attacker
	local bandaging = dialog.action.id == "Bandage"
	local brutalize = dialog.action.id == "Brutalize"
	
	if not action.IsTargetableAttack or IsKindOf(dialog, "IModeCombatFreeAim") then
		return Targeting_UnitInMelee(dialog, blackboard, command, pt)
	end
	
	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end
	
	if command ~= "delete" and not dialog.crosshair and not bandaging and not brutalize then	
		local nearest = action:GetDefaultTarget(attacker)
		if nearest then
			dialog:SetTarget(nearest)
			return
		--else
			--CreateRealTimeThread(SetInGameInterfaceMode, g_Combat and "IModeCombatMovement" or "IModeExploration")
		end
		--return
	end

	if command ~= "delete" and not blackboard.combat_path and not dialog.crosshair then
		dialog.args_gotopos = true
		dialog.disable_mouse_indicator = true
		if bandaging then
			blackboard.contour_target_action = "TargetBandage"
			blackboard.fx_adjacent_action = "Bandage"
		else
			blackboard.contour_target_action = "TargetMelee"
			blackboard.fx_adjacent_action = "Melee"
		end
	
		local meleeCombatPath, hash = GetMeleeAttackCombatPath(action, attacker)
		blackboard.combat_path = meleeCombatPath
		blackboard.combat_path_hash = hash
		
		if g_Combat then
			local borderline_attack, borderline_attack_voxels = GenerateAttackContour(action, attacker, meleeCombatPath)
			dialog.borderline_attack = borderline_attack
			dialog.borderline_attack_voxels = borderline_attack_voxels
			dialog.borderline_turns_voxels = borderline_attack_voxels
			blackboard.contour_for = { unit = attacker, pos = attacker:GetPos() }
			SelectionAddedApplyFX(Selection)
		end
		
		blackboard.visible_enemies_cache = action:GetTargets(Selection)
	end
	
	if command == "delete" then
		if blackboard.combat_path then
			blackboard.combat_path:delete()
			blackboard.combat_path = false
		end
		dialog.args_gotopos = false
		
		if g_Combat or blackboard.contour_for then
			Targeting_Movement(dialog, blackboard, "delete", pt, melee_targeting_special_args)
		end
		if dialog.crosshair then
			IModeCommonUnitControl.UpdateTarget(dialog, pt)
		end
		DeleteMeleeVisualization(blackboard)
		if blackboard.movement_avatar then
			UpdateMovementAvatar(dialog, point20, nil, "delete")
		end
		DestroyBlackboardFXPath(blackboard)
		SetAPIndicator(false, "melee-attack")
		SetAPIndicator(false, "bandage-error")
		return
	end
	
	if not g_Combat and dialog.crosshair then
		-- recheck the melee target pos out of combat in case the target moves		
		local attack_pos = dialog.crosshair.context.meleeTargetPos and point_pack(dialog.crosshair.context.meleeTargetPos)
		local tiles
		if attack_pos then
			local target = dialog.target
			if IsValid(target) and not IsKindOf(target.traverse_tunnel, "SlabTunnelLadder") then
				tiles = GetMeleeTiles(attacker, target, SnapToPassSlab(target:GetVisualPosXYZ()))
			end
		end
		if not attack_pos or not table.find(tiles, attack_pos) then
			CreateRealTimeThread(SetInGameInterfaceMode, "IModeExploration")
		end
	end
	if dialog.crosshair then
		SetAPIndicator(false, "melee-attack")
		SetAPIndicator(false, "bandage-error")
		if g_Combat then
			if not blackboard.movement_avatar then 
				UpdateMovementAvatar(dialog, point20, nil, "setup")
			end
			if not blackboard.combat_path then
				local meleeCombatPath, hash = GetMeleeAttackCombatPath(action, attacker)
				blackboard.combat_path = meleeCombatPath
			end

			local attack_pos = dialog.crosshair.context.meleeTargetPos
			if blackboard.fx_path_pos ~= attack_pos then
				DestroyBlackboardFXPath(blackboard)
				local combatPath = blackboard.combat_path
				local target_path = combatPath and combatPath:GetCombatPathFromPos(attack_pos)
				blackboard.target_path = target_path				
				CreateBlackboardFXPath(blackboard, attacker:GetPos(), target_path, true, dialog)
				blackboard.fx_path_pos = attack_pos
			end
			MeleeTargetingUpdateMovementAvatar(dialog, blackboard, dialog.crosshair.context.meleeTargetPos)
		end
		return
	end
	
	-- Check if can bandage potential_target
	local potential_target = dialog.potential_target
	local bandageError = false
	if potential_target and bandaging then
		local _, err = CanBandageUI(attacker, { target = potential_target })
		bandageError = err and Untranslated(_InternalTranslate(err, { ["flavor"] = "", ["/flavor"] = "" }))
	end
	SetAPIndicator(bandageError and 0 or false, "bandage-error", bandageError, nil, "force")
	if bandageError then
		SetAPIndicator(false, "melee-attack")
	end

	-- Find the current melee target, this could either be the moused over unit (potential_target) or a unit around us
	local attackerPos = attacker:GetPos()
	local attackerPosPacked = point_pack(attackerPos)
	local current_target = false
	local should_target = IsKindOf(potential_target, "Unit") and (potential_target ~= attacker or bandaging)
	if should_target and attacker:IsOnEnemySide(potential_target) then
		should_target = table.find(blackboard.visible_enemies_cache, potential_target)
	end
	if not bandageError and should_target then
		current_target = potential_target

		local tiles = GetMeleeTiles(attacker, potential_target)
		if bandaging and attacker == potential_target then
			table.insert(tiles, point_pack(attacker:GetPos()))
		end
		
		local attackerIsInMeleeRange = table.find(tiles, attackerPosPacked)
		if attackerIsInMeleeRange then
			dialog.target_pos = attackerPos
		else	
			-- Since we're on top of the unit, the attack pos is the closest voxel in the direction of the current cursor position
			local dirVec = pt - SnapToVoxel(potential_target:GetPos())
			local direction = dirVec:Len() ~= 0 and SetLen(dirVec, const.SlabSizeX) or point20
			local posOffset = SnapToVoxel(pt + direction)

			local closestDist, closest, closestAp
			for i, packed_pos in ipairs(tiles) do
				--[[local dist = posOffset:Dist2D(point_unpack(packed_pos))
				if not closestDist or dist < closestDist then
					closestDist = dist
					closest = packed_pos
				end--]]
				local ap = blackboard.combat_path and blackboard.combat_path:GetAP(packed_pos)
				if ap and (not closestAp or ap < closestAp) then
					closest, closestAp = packed_pos, ap
				end
			end

			dialog.target_pos = closest and point(point_unpack(closest)) or false
		end
	end
	
	local pos = dialog.target_pos
	local posPacked = pos and point_pack(pos)

	-- If there isn't a valid target under the cursor, check if the cursor is currently in a valid melee attack pos for any unit
	if not current_target and pos and SelectedObj then
		local units = blackboard.units_around_cursor_cache
		if blackboard.last_target_pos ~= pos then
			local searchBox = GetVoxelBBox(pos, 1)
			units = MapGet(searchBox, "Unit") or {}
			blackboard.last_target_pos = pos
			blackboard.units_around_cursor_cache = units
		end

		local closestDist
		for i, u in ipairs(units) do
			if not table.find(blackboard.visible_enemies_cache, u) or u == attacker then goto continue end

			-- Find possible melee attack positions, and pick the one below the cursor voxel.
			-- If a position provides multiple attack opportunities, select the target closest
			-- to the cursor
			--[[local unitPos = u:GetPos()
			local dist = u:GetDist2D(pt)			
			if not closestDist or closestDist > dist then
				local tiles = GetMeleeTiles(SelectedObj, u)
				-- (174534) if attacker is in melee range they can only select their current position
				local attackerIsInMeleeRange = table.find(tiles, attackerPosPacked)
				if table.find(tiles, posPacked) and (not attackerIsInMeleeRange or posPacked == attackerPosPacked) then
					current_target = u
					--dialog.target_pos = pos
					closestDist = dist
				end
			end--]]

			-- get melee attack positions to this unit and find the closest (by combat path)
			local tiles = GetMeleeTiles(SelectedObj, u)
			local target_tile, target_tile_ap
			for _, tile in ipairs(tiles) do
				local ap = blackboard.combat_path and blackboard.combat_path:GetAP(tile)
				if ap and (not target_tile_ap or target_tile_ap > ap) then
					target_tile, target_tile_ap = tile, ap
				end
			end
			if target_tile then
				local target_tile_steppos = SnapToPassSlab(point_unpack(target_tile))
				local target_steppos = SnapToPassSlab(pt)				
				local dist = u:GetDist(pt)
				if target_tile_steppos and target_steppos and target_tile_steppos:Dist(target_steppos) == 0 and (not closestDist or dist < closestDist) then
				-- there might be multiple enemies attackable from this tile, pick the one closest to the cursor
					current_target = u
					closestDist = dist
				end
			end

			::continue::
		end
	end

	if command == "setup" and dialog.target then
		pos = attacker:GetClosestMeleeRangePos(dialog.target)
		posPacked = point_pack(pos)
		current_target = dialog.target
		pt = pos
		dialog.target_pos = pos
		dialog:Confirm()
	end

	-- Now that the target_pos is overwritten with the attack pos, show movement from it.
	-- No need to handle the "occupied" indicator as only unit positions are skipped by the targeting above.
	if g_Combat and SelectedObj then
		Targeting_Movement(dialog, blackboard, command, pt, melee_targeting_special_args)
		if not blackboard.fx_path and (not dialog.target_pos or SelectedObj:GetDist(dialog.target_pos) > const.SlabSizeX / 2) and not bandageError then
			SetAPIndicator(not blackboard.fx_path and APIndicatorUnreachable, "unreachable")
			if not blackboard.fx_path and current_target ~= attacker then -- If no path to the target, and not targeting self - invalid target.
				current_target = false
			end
		elseif not dialog.target then
			SetAPIndicator(APIndicatorNoTarget, "unreachable")
		end
	end
	
	if not blackboard.movement_avatar then 
		UpdateMovementAvatar(dialog, point20, nil, "setup")
	end

	local targetChange = false
	if dialog.target ~= current_target then
		dialog:SetTarget(current_target, true)
		if not current_target then
			dialog.target_pos = false
			SetAPIndicator(false, "melee-attack")
		end
		blackboard.fx_pos = false
		targetChange = true
	end

	--pos = dialog.target_pos
	local target = dialog.target
	if pos == blackboard.fx_pos and not targetChange then return end
	blackboard.fx_pos = pos
	
	-- melee-specific movement avatar update
	MeleeTargetingUpdateMovementAvatar(dialog, blackboard)
	SetAPIndicator(false, "brutalize")

	if not target or not pos then
		DeleteMeleeVisualization(blackboard)
		return
	end
	
	local voxel = point_pack(pos:xyz())
	local apCost = action:GetAPCost(SelectedObj, { target = target, goto_pos = pos })
	SetAPIndicator(apCost, "melee-attack")
	if action.id == "Brutalize" then
		local num = SelectedObj:GetNumBrutalizeAttacks(voxel)
		SetAPIndicator(0, "brutalize", T{145407413631, "<num> attacks", num = num}, true)
	end
	
	local target_pos = target:GetPos()
	if blackboard.contour_target ~= target then
		if blackboard.contour_target then
			DestroyMesh(blackboard.target_action_contour)
			blackboard.target_action_contour = false
		end
		blackboard.contour_target = target
		local style = g_ActionTextStyles[blackboard.contour_target_action] or blackboard.contour_target_action
		blackboard.target_action_contour = PlaceSingleTileStaticContourMesh(style, target_pos)
	end

	DoneObject(blackboard.fx_arrow)
	blackboard.fx_arrow = PlaceObject("DecUIUnitArrow")
	
	local arrow_pos, arrow_scale = lGetArrowPosScale(target_pos, pos)
	blackboard.fx_arrow:SetPos(arrow_pos)
	blackboard.fx_arrow:SetScale(arrow_scale)
	blackboard.fx_arrow:Face(target_pos)
	
	DestroyMesh(blackboard.adjacent_contour)
	blackboard.adjacent_contour = PlaceSingleTileStaticContourMesh("BandageMeleeAdjacent", pos)
	
	PlayFX(blackboard.fx_adjacent_action, "end")
	if attacker:UIHasAP(apCost) then
		PlayFX(blackboard.fx_adjacent_action, "start", false, false, pos)
	end

	ApplyDamagePrediction(SelectedObj, action, {target = target, goto_pos = pos})
end

DefineClass.IModeCombatMelee = {
	__parents = { "IModeCombatAttackBase" },
	melee_step_pos = false,
}

function IModeCombatMelee:UpdateLinesOfFire() -- do not show lines of fire while in this mode
end

function IModeCombatMelee:SetTarget(...)
	local switchValid = IModeCombatAttackBase.SetTarget(self, ...)
	if IsValid(self.target) and switchValid then
		local pos = self.attacker:GetClosestMeleeRangePos(self.target)		
		local attacker = self.attacker
		local action = self.action
		local weapon = action:GetAttackWeapons(attacker)
		if g_Combat and not attacker:CanAttack(self.target, weapon, action, 0, pos) then
			ReportAttackError(self.target, AttackDisableReasons.CantReach)
			CreateRealTimeThread(SetInGameInterfaceMode, g_Combat and "IModeCombatMovement" or "IModeExploration")
		end
		self.target_pos = pos
		local crosshair = self:SpawnCrosshair("closeOnAttack", pos, self.target)
		local cll = XTemplateSpawn("XCameraLockLayer", crosshair)
		cll:Open()
	end
	return switchValid
end

function IModeCombatMelee:IsValidCycleTarget(target)
	if not IModeCombatAttackBase.IsValidCycleTarget(self, target) then return end
	if IsValid(target) and IsKindOf(target.traverse_tunnel, "SlabTunnelLadder") then return end
	local pos = self.attacker:GetClosestMeleeRangePos(target)
	if pos then
		if not g_Combat then return true end
		local attacker = self.attacker
		local action = self.action
		local weapon = action:GetAttackWeapons(attacker)
		if attacker:CanAttack(self.target, weapon, action, 0, pos) then
			return true
		end
	end
end

function IModeCombatMelee:Confirm(from_crosshair)
	if from_crosshair then 
		local crosshairMeleePos = self.crosshair.context.meleeTargetPos
	
		-- Melee attacks in exploration mode will close the crosshair to allow the suspicion bar to be seen.
		-- This is fine as follow up attacks are not expected.
		if not g_Combat then self:RemoveCrosshair("confirm-exploration") end

		self.move_step_position = crosshairMeleePos
		self.target_pos = crosshairMeleePos
		return IModeCombatAttackBase.Confirm(self)
	end

	if self.crosshair then
		-- Crosshair is invisible while the attack is executing.
		-- There's a small window of time in which you can close it accidentally
		-- by clicking, and upon the attack finishing you are left confused.
		--if self.crosshair.visible then self:RemoveCrosshair() end
		--return
		local unit = self:GetUnitUnderMouse()
		if IsValid(unit) and unit ~= self.target and not unit:IsDead() and self.attacker:IsOnEnemySide(unit) and HasVisibilityTo(self.attacker.team, unit) then
			if self.attacker:GetClosestMeleeRangePos(unit) then
				self:SetTarget(unit)
			else
				ReportAttackError(unit, AttackDisableReasons.CantReach)
			end
		elseif unit == self.target and self.crosshair.visible then
			self.crosshair:Attack()
		elseif not GetUIStyleGamepad() and self:GetMouseTarget(terminal.GetMousePos()) ~= self.crosshair then
			CreateRealTimeThread(RestoreDefaultMode, SelectedObj)
		end
		return "break"
	end
	
	self.target_pos = (self.attacker and self.attacker:GetPos()) or self.target_pos or self.melee_step_pos
	if not self.target or not self.target_pos then return end
	
	-- Custom errors
	if self.target == SelectedObj then self.target_pos = SnapToVoxel(SelectedObj:GetPos()) end
	if self.action.id == "Bandage" and not CheckCanBeBandagedAndReport(SelectedObj, { target = self.target, goto_pos = self.target_pos }) then 
		return 
	end
	if self.action.id == "Brutalize" and CheckAndReportImpossibleAttack(SelectedObj, self.action, {target = self.target, goto_pos = self.target_pos}) ~= "enabled" then
		return
	end
	
	if self.action.IsTargetableAttack then
		hr.CameraTacClampToTerrain = false
		local dontMoveCam = DoesTargetFitOnScreen(self, self.target)
		
		if not dontMoveCam then
			SnapCameraToObj(self.target, true)
		end
		
		local crosshair = self:SpawnCrosshair("closeOnAttack", self.target_pos, self.target, dontMoveCam)
		local cll = XTemplateSpawn("XCameraLockLayer", crosshair)
		cll:Open()
		return
	end
	
	self.move_step_position = self.target_pos
	return IModeCombatAttackBase.Confirm(self)
end

-- In melee targeting the voxel under the mouse isn't always the effects voxel.
function IModeCombatMelee:GetEffectsTargetVoxel()
	return IModeCommonUnitControl.GetEffectsTargetVoxel(self, self.targeting_blackboard.fx_pos)
end

--[[function IModeCombatMelee:UpdateCursorImage()
	if IsValid(self.target) then
		self.desktop:SetMouseCursor("UI/Cursors/Attack.tga")
	else
		self.desktop:SetMouseCursor("UI/Cursors/Attack_1.tga")	
	end
end]]

function CanBandageUI(attacker, args)
	local target = args and args.target
	local pos = args and args.goto_pos
	if not target then return false, AttackDisableReasons.NoTarget end
	if not target:IsPlayerAlly() and not target.team.neutral then return false, AttackDisableReasons.InvalidTarget end

	local action = CombatActions.Bandage
	local err = false
	
	local state, reason = action:GetUIState({attacker}, args)
	if state ~= "enabled" then
		return false, reason
	end
	
	local cost = action:GetAPCost(attacker, args)
	
	if target ~= attacker and g_Combat then		
		if not IsMeleeRangeTarget(attacker, nil, nil, target) then
			local pos = attacker:GetClosestMeleeRangePos(target)
			local cpath = GetCombatPath(attacker)
			local ap = cpath:GetAP(pos)
			if not ap then
				err = AttackDisableReasons.NoAP
			else
				cost = cost + Max(0, ap - attacker.free_move_ap)
			end
			
			--err = AttackDisableReasons.NotInBandageRange
		end
	end
	if g_Combat and cost >= 0 and not attacker:UIHasAP(cost) then
		err = g_Combat and AttackDisableReasons.NoAP or AttackDisableReasons.TooFar
	end
	
	if not err and not target:HasStatusEffect("Bleeding") and target.HitPoints >= target.MaxHitPoints and not target:HasStatusEffect("Unconscious") then
		err = AttackDisableReasons.FullHP
	end

	return not err, err
end

function CheckCanBeBandagedAndReport(attacker, args)
	local _, err = CanBandageUI(attacker, args)
	if err then
		ReportAttackError(args and args.target or attacker, err)
		return false
	end
	return true
end

function Targeting_UnitInMelee(dialog, blackboard, command, pt)
	local action = dialog.action
	local attacker = dialog.attacker
	local action_pos = attacker:GetPos()
	local bandaging = dialog.action.id == "Bandage"
	local brutalize = dialog.action.id == "Brutalize"
	local free_aim = IsKindOf(dialog, "IModeCombatFreeAim")
	
	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end

	if command == "delete" then		
		SetAPIndicator(false, "melee-attack")
		SetAPIndicator(false, "bandage-error")
		SetAPIndicator(false, "brutalize")

		for _, unit in ipairs(g_Units) do
			unit:SetHighlightReason("melee-target", false)
			unit:SetHighlightReason("bandage-target", false)
		end
		
		if IsValid(blackboard.actor_tile_mesh) then
			DoneObject(blackboard.actor_tile_mesh)
			blackboard.actor_tile_mesh = nil
		end
		if blackboard.melee_area then
			DoneObject(blackboard.melee_area)
			blackboard.melee_area = nil
		end
		if blackboard.movement_avatar then
			UpdateMovementAvatar(dialog, point20, nil, "delete")
		end
		return
	else	
		if not bandaging and g_Combat and not IsValid(blackboard.actor_tile_mesh) then
			blackboard.contour_target_action = "TargetMelee"
			local style = g_ActionTextStyles[blackboard.contour_target_action] or blackboard.contour_target_action
			blackboard.actor_tile_mesh = PlaceSingleTileStaticContourMesh(style, action_pos)
		end
		if not blackboard.melee_area and not free_aim then
			blackboard.melee_area = CombatActionCreateMeleeRangeArea(attacker)
		end
		blackboard.action_targets = blackboard.action_targets or action:GetTargets({SelectedObj})
	end

	-- Check if can bandage potential_target
	local potential_target = dialog.potential_target
	local bandageError = false
	local canAttack, attackError
	
	if free_aim and not potential_target then
		local _, target_obj = dialog:GetFreeAttackTarget(dialog.potential_target, attacker)
		if IsValid(target_obj) then
			potential_target = target_obj
		end			
	end
	
	if potential_target then
		if bandaging then
			local _, err = CanBandageUI(attacker, { target = potential_target })
			bandageError = err and Untranslated(_InternalTranslate(err, { ["flavor"] = "", ["/flavor"] = "" }))
		elseif potential_target ~= attacker then
			local weapon = action:GetAttackWeapons(attacker)
			canAttack, attackError = attacker:CanAttack(potential_target, weapon, action, 0, nil, nil, free_aim)
		end
	end

	for _, unit in ipairs(g_Units) do
		local melee_target, bandage_target = false, false
		if potential_target == unit then
			if bandaging and not bandageError then
				bandage_target = true
			elseif not bandaging and canAttack then
				melee_target = true
			end
		end
		unit:SetHighlightReason("melee-target", melee_target)
		unit:SetHighlightReason("bandage-target", bandage_target)
	end
	
	local avatar_pos
	
	if bandaging then
		if bandageError then
			SetAPIndicator(false, "melee-attack")
			SetAPIndicator(0, "bandage-error", bandageError, nil, "force")
		else
			SetAPIndicator(false, "bandage-error")
			local apCost = action:GetAPCost(SelectedObj, {target = potential_target})
			SetAPIndicator(apCost, "melee-attack")
			dialog.target = potential_target
			
			if IsValid(potential_target) and potential_target ~= attacker then
				avatar_pos = SelectedObj:GetClosestMeleeRangePos(potential_target)
			end
		end
	else
		local args = {target = potential_target, ap_cost_breakdown = {}}
		local apCost = action:GetAPCost(SelectedObj, args)
		local free_move_ap_used = Min(args.ap_cost_breakdown.move_cost or 0, SelectedObj.free_move_ap)
		apCost = apCost - Max(0, free_move_ap_used)
		-- round the cost to match before/after AP readings
		local before = SelectedObj:GetUIActionPoints() / const.Scale.AP
		local after = (SelectedObj:GetUIActionPoints() - apCost) / const.Scale.AP -- free move is already accounted for in apCost
		apCost = (before - after) * const.Scale.AP
		
		if APIndicator and #APIndicator > 1 then
			SetAPIndicator(false, "brutalize")
		end
		if action.id == "Brutalize" then
			local num = SelectedObj:GetNumBrutalizeAttacks()
			SetAPIndicator(0, "brutalize", T{145407413631, "<num> attacks", num = num}, "append", "force")
		end
		if canAttack then
			dialog.target = potential_target
			if IsValid(potential_target) then
				avatar_pos = SelectedObj:GetClosestMeleeRangePos(potential_target)
				for _, api in ipairs(APIndicator) do
					if api.reason == "attack" then
						api.ap = apCost
					end
				end
				ObjModified(APIndicator)
			end
			ApplyDamagePrediction(SelectedObj, action, {target = potential_target})
		else
			dialog.target = nil
		end
	end

	if avatar_pos then
		if not blackboard.movement_avatar then 
			UpdateMovementAvatar(dialog, point20, nil, "setup")
		end
		blackboard.movement_avatar:SetHierarchyEnumFlags(const.efVisible)
		MeleeTargetingUpdateMovementAvatar(dialog, blackboard, avatar_pos)
	elseif blackboard.movement_avatar then
		blackboard.movement_avatar:ClearHierarchyEnumFlags(const.efVisible)
	end
end