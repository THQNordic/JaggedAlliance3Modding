DefineClass.IModeCombatFreeAim = {
	__parents = { "IModeCombatAttackBase" },
	lock_camera = false,
	attack_pos = false,
	tile_free_attack = false,
	fx_free_attack = false,
	disable_mouse_indicator = true,
	mouse_world_pos = false,
	
	firing_modes = false,
	current_firing_mode = false, -- separate just in case
	meta_action = false,
}

function IModeCombatFreeAim:Open()
	IModeCombatAttackBase.Open(self)

	local action = self.action
	local attacker = self.attacker
	if action.group == "FiringModeMetaAction" then
		local defaultMode, firingModes = GetUnitDefaultFiringModeActionFromMetaAction(attacker, action)
		
		local possibleOnes = {}
		for i, fm in ipairs(firingModes) do
			local actionEnabled = attacker.ui_actions[fm.id]
			actionEnabled = actionEnabled == "enabled"
			if actionEnabled then
				possibleOnes[#possibleOnes + 1] = fm
			end
		end
		if #possibleOnes > 1 then
			self.current_firing_mode = defaultMode
			self.firing_modes = possibleOnes
			self.meta_action = self.action
			self.action = self.current_firing_mode
		end
	end
end

function IModeCombatFreeAim:CycleFiringMode()
	local firing_modes = self.firing_modes
	if not firing_modes then return end

	local id = self.current_firing_mode.id
	local curTargetIdx = table.find(firing_modes, "id", id) or 0
	curTargetIdx = curTargetIdx + 1
	if curTargetIdx > #firing_modes then
		curTargetIdx = 1
	end
	local action = firing_modes[curTargetIdx]
	self.current_firing_mode = action
	self.action = self.current_firing_mode
	self.attacker.lastFiringMode = action.id
	
	self:UpdateTarget()
end

function IModeCombatFreeAim:Done()
	if self.fx_free_attack then
		SetInteractionHighlightRecursive(self.fx_free_attack, false, true)
		self.fx_free_attack = false
	end
	self.tile_free_attack = false
	ClearDamagePrediction()
	SetAPIndicator(false, "free-aim")
	UpdateAllBadges()
end


function IModeCombatFreeAim:UpdateTarget(...)
	if not SelectedObj or not SelectedObj:IsIdleCommand() then return end

	IModeCombatAttackBase.UpdateTarget(self, ...)
	
	local tile, fx_target = self:GetFreeAttackTarget(self.potential_target, self.attacker)
	if self.fx_free_attack ~= fx_target then
		self.tile_free_attack = tile
		if self.fx_free_attack then
			SetInteractionHighlightRecursive(self.fx_free_attack, false, true)
			self.fx_free_attack = false
		end

		if fx_target then
			self.fx_free_attack = fx_target
			SetInteractionHighlightRecursive(fx_target, true, true)
		end

		local attacker = SelectedObj or Selection[1]
		local action = self.action
		--ApplyDamagePrediction(attacker, action, {target = tile})

		if action.id and tile then
			NetSyncEvent("Aim", attacker, action.id, tile)
		end
	end
end

function IModeCombatFreeAim:SetTarget()
	return false
end

function IModeCombatFreeAim:UpdateLinesOfFire() -- do not show lines of fire while in this mode
end

function IModeCombatFreeAim:ShowCoversShields(world_pos, cover)
	IModeCommonUnitControl.ShowCoversShields(self, world_pos, cover)
end

function IModeCombatFreeAim:OnMouseButtonDown(pt, button)	
	if not IsValid(SelectedObj) or not SelectedObj:CanBeControlled() then
		return
	end
	
	local gamepadClick = false
	if not button and GetUIStyleGamepad() then
		gamepadClick = true
	end

	if button == "L" or gamepadClick then
		if IsValidThread(self.real_time_threads and self.real_time_threads.move_and_attack) then
			return
		end
		-- special-case MG burst attack free aim to be restricted in the attack cone
		local target, target_obj = self:GetFreeAttackTarget(self.potential_target, self.attacker)
		if GetUIStyleGamepad() and self.action.AimType == "cone" and self.target_as_pos then
			target = self.target_as_pos
		end
		if self.action.id == "MGBurstFire" then
			local overwatch = g_Overwatch[SelectedObj]
			if overwatch and overwatch.permanent then
				if SelectedObj:HasStatusEffect("ManningEmplacement") then
					if IsCloser2D(SelectedObj, target, guim) then
						ReportAttackError(target or SelectedObj, AttackDisableReasons.OutOfRange)
						return
					end
				end
				local angle = overwatch.orient or CalcOrientation(SelectedObj:GetPos(), overwatch.target_pos)
				if not CheckLOS(target, SelectedObj, overwatch.dist, SelectedObj.stance, overwatch.cone_angle, angle) then
					ReportAttackError(target or SelectedObj, AttackDisableReasons.OutOfRange)
					return
				end
			end
		elseif self.action.ActionType == "Melee Attack" then
			if IsValid(target_obj) then
				local step_pos = self.attacker:GetClosestMeleeRangePos(target_obj)
				if step_pos then
					local args = {target = target_obj, goto_pos = step_pos, free_aim = true}
					if CheckAndReportImpossibleAttack(self.attacker, self.action, args) == "enabled" then
						if self.action.IsTargetableAttack and IsKindOf(target_obj, "Unit") then	
							self.action:UIBegin({self.attacker}, args)
						else
							self:StartMoveAndAttack(self.attacker, self.action, target_obj, step_pos, args)
						end
					end
					return "break"
				elseif g_Combat then
					ReportAttackError(GetCursorPos(), AttackDisableReasons.TooFar)
					return
				end
			else
				ReportAttackError(GetCursorPos(), AttackDisableReasons.NoTarget)
				return
			end
		end
		if self.attacker ~= target then 
			FreeAttack(SelectedObj, target, self.action, self.context.free_aim, self.target_as_pos, self.meta_action)
		else 
			ReportAttackError(target or SelectedObj, AttackDisableReasons.InvalidSelfTarget)
		end
		return
	end
	return IModeCombatAttackBase.OnMouseButtonDown(self, pt, button)
end


--target can be only unit or point
function IModeCombatFreeAim:GetFreeAttackTarget(target, attacker_or_pos)
	local spawnFXObject
	local objForFX
	-- check target
	if IsValid(target) then
		objForFX = target
		return target, objForFX
	else
		target = self:GetUnitUnderMouse()
		if not target then
			local solid, transparent = GetPreciseCursorObj()
			local obj = transparent or solid
			obj = not IsKindOf(obj, "Slab") and SelectionPropagate(obj) or obj
			if IsKindOf(obj, "Object") and not obj:IsInvulnerable() and (IsKindOf(obj, "CombatObject") and not obj.is_destroyed or ShouldDestroyObject(obj)) then
				target = obj
			end
		end
		
		--target could be combatObject/vulnerable object or false
		
		-- edge case for machine guns emplacements, currently they should not be targeted
		if IsKindOf(target, "MachineGunEmplacement") then
			target = false
		end
		
		-- edge case for dynamicspawnlandmine
		if IsKindOf(target, "DynamicSpawnLandmine") then
			spawnFXObject = target
			target = target:GetAttach(1)
		elseif self.action.ActionType == "Melee Attack" then
			spawnFXObject = target
		end
		
		if target then
			objForFX = target
			local hitSpotIdx = target:GetSpotBeginIndex("Hit")
			if hitSpotIdx ~= -1 then
				hitSpotIdx = target:GetNearestSpot("Hit", attacker_or_pos)
			end
			
			--if hitspot exists -> set pos to it
			if hitSpotIdx > 0 then
				target = target:GetSpotPos(hitSpotIdx) 
			else
			--if no hitspot -> set pos to the middle of the bboxf
				local bbox = GetEntityBBox(target:GetEntity())
				target = target:GetVisualPos() + bbox:Center()
			end
		else
		--if there is no target -> set pos to the cursor 
			target = GetCursorPos()
		end 
	end
	
	return spawnFXObject or target, objForFX
end

function FreeAttack(unit, target, action, isFreeAim, target_as_pos, meta_action_crosshair)
	if not target then return end

	unit = unit or SelectedObj	
	if not IsValid(unit) or unit:IsDead() then
		return
	end	
	if not CanYield() then
		return CreateRealTimeThread(FreeAttack, unit, target, action, isFreeAim, target_as_pos, meta_action_crosshair)
	end
	
	if IsKindOf(target, "Unit") then 
		-- revert to normal attack mode to this unit
		action = meta_action_crosshair or action
		local args = {target = target, free_aim = isFreeAim}
		local state, reason = action:GetUIState({unit}, args)--add free_aim
		if state == "enabled" or (state == "disabled" and reason == AttackDisableReasons.InvalidTarget) then
			action:UIBegin({unit}, args)
		else
			CheckAndReportImpossibleAttack(unit, action, args)
		end
		return
	end
	
	SelectObj(unit)

	local cursor_pos = terminal.GetMousePos()
	if GetUIStyleGamepad() then
		local front
		front, cursor_pos = GameToScreen(GetCursorPos())
	end

	RequestPixelWorldPos(cursor_pos)
	WaitNextFrame(6)
	local preciseAttackPt = ReturnPixelWorldPos()
	if action.AimType == "cone" and target_as_pos then
		preciseAttackPt = target_as_pos
	end
	
	local camera_pos = camera.GetEye()
	-- the target point may be outside the target object collision surfaces, so we extend the line a bit
	local segment_end_pos = camera_pos + SetLen(preciseAttackPt - camera_pos, camera_pos:Dist(preciseAttackPt) + guim)
	local rayObj, pt, normal = GetClosestRayObj(camera_pos, segment_end_pos, const.efVisible, 0, function(o)
		if o:GetOpacity() == 0 then
			return false
		end
		return true
	end, 0, const.cmDefaultObject)
	local args = { target = pt or target }

	if action.group == "FiringModeMetaAction" then
		action = GetUnitDefaultFiringModeActionFromMetaAction(unit, action)
	end
	local state, reason = action:GetUIState({unit}, args) 
	if state == "enabled" or (state == "disabled" and reason == AttackDisableReasons.InvalidTarget) then
		action:Execute({unit}, args)
	else
		CheckAndReportImpossibleAttack(unit, action, args)
	end
end