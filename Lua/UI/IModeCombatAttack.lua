DefineClass.IModeCombatAttack = {
	__parents = { "IModeCombatAttackBase" },
	camera_floor = false
}

function IModeCombatAttack:Open(...)
	self.camera_floor = cameraTac.GetFloor()
	self.context.target = (self.context.target or (self.action.RequireTargets and self.action:GetDefaultTarget(SelectedObj)))
	IModeCombatAttackBase.Open(self, ...)
	LockCamera(self)

	local attacker = self.attacker
	if attacker and attacker:IsPlayerAlly() then
		local target = self.target
		if not target then -- Target is invalid and didn't get assigned as the target from the context.
			CreateRealTimeThread(function()
				SetInGameInterfaceMode("IModeCombatMovement")
			end)
			return
		end
	end
end

function IModeCombatAttack:Close()
	DbgClearVectors()
	UnlockCamera(self)
	if self.context.changing_action then -- Delicate reload of this interface
		IModeCommonUnitControl.Close(self)
	else
		IModeCombatAttackBase.Close(self)
	end
	if self.camera_floor and not CurrentActionCamera then
		cameraTac.SetFloor(self.camera_floor, hr.CameraTacInterpolatedMovementTime * 10, hr.CameraTacInterpolatedVerticalMovementTime * 10)
	end
	StartWallInvisibilityThreadWithChecks("IModeCombatAttack")
end

function IModeCombatAttack:OnMouseButtonDown(pt, button)
	local gamepadClick = false
	if not button and GetUIStyleGamepad() then
		if self.crosshair then
			self.crosshair:Attack()
		else
			self:Confirm()
		end
		return "break"
	end

	if button == "L" or gamepadClick then
		local obj = SelectionMouseObj()
		if IsKindOf(obj, "Unit") then
			local shootingAtEnemy = SelectedObj and SelectedObj:IsOnEnemySide(obj)
			local shootingFreeAim = self.crosshair and self.crosshair.context.free_aim
			local isValidTarget = (shootingAtEnemy or shootingFreeAim) and not obj:IsDead()
			if isValidTarget then
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
		end
		if self.crosshair and self:GetMouseTarget(pt) ~= self.crosshair then
			CreateRealTimeThread(RestoreDefaultMode, SelectedObj)
			return "break"
		end
	end
end

function IModeCombatAttack:SetTarget(target, dontMove)
	if target == self.target then return true end

	if self.context.changing_action then
		dontMove = true
		self.context.changing_action = false
	end
	local attacker = self.attacker

	if self.action and IsValid(target) and not self.context.free_aim and IsKindOf(target, "Unit") then
		local targets = self.action:GetTargets({attacker})
		if not table.find(targets, target) then
			if not HasVisibilityTo(attacker.team, target) then
				if g_Units.Livewire then
					ReportAttackError(target, AttackDisableReasons.NoTeamSightLivewire)
				else
					ReportAttackError(target, AttackDisableReasons.NoTeamSight)
				end
			else
				ReportAttackError(target, AttackDisableReasons.InvalidTarget)
			end
			return true
		end
	end

	local valid = IModeCombatAttackBase.SetTarget(self, target, "dontMove")
	if not valid then return false end

	local camMoved = true
	if not dontMove then
		self:DeleteThread("action-camera-switch")
		
		if IsValidThread(ActionCameraAutoRemoveThread) then
			DeleteThread(ActionCameraAutoRemoveThread)
			ActionCameraAutoRemoveThread = false
		end
		local actionCam
		if IsCinematicTargeting(attacker, target, self.action) and self.action.ActionCamera and HasVisibilityTo(attacker, target) then
			local attack_results, attack_args = self.action:GetActionResults(attacker, {target = target})
			if attack_args.clear_attacks ~= 0 then
				actionCam = true
			end
		end
		if actionCam then
			-- Interpolate the action camera bsed on the distance to the target.
			local interpolationTime = default_interpolation_time
			if CurrentActionCamera and IsValid(CurrentActionCamera[2]) then
				local oldTargetPos = CurrentActionCamera[2]:GetPos()
				local newTargetPos = target:GetPos()
				local dist = oldTargetPos:Dist2D(newTargetPos)
				local maxRange = guim * 10
				if dist < maxRange then
					interpolationTime = Lerp(100, interpolationTime, dist, maxRange)
				end
			end
			actionCam = SetActionCameraNoFallback(attacker, target, not IsKindOf(target, "Unit"), interpolationTime)
		end
		if not actionCam then
			if not LocalACWillStartPlaying and not CurrentActionCamera then
				--hr.CameraTacClampToTerrain = false
				local pause = false
				if DoesTargetFitOnScreen(self, target) then
					if IsVisibleFromCamera(target, true) then
						pause = true
					end
					camMoved = false
					self.dont_return_camera_on_close = true
				else
					local t, cp, lap = SnapCameraToObj(target, true)
					if cp and IsVisibleFromCamera(target, true, cp) then
						pause = true
					end
				end

				if pause then
					StopWallInvisibilityThread("IModeCombatAttack")
				else
					StartWallInvisibilityThreadWithChecks("IModeCombatAttack")
				end
			else
				self:CreateThread("action-camera-switch", function()
					while LocalACWillStartPlaying do
						WaitMsg("LocalACWillStartPlaying", 100)
					end
				
					-- If going to no action camera from one, we fake the interpolation as exiting from the target.
					-- This effectively makes it so the action camera is removed and the target is snapped to.
					if CurrentActionCamera and CameraBeforeActionCamera then
						CurrentActionCamera[1] = target
						CameraBeforeActionCamera[5] = { floor = GetFloorOfPos(target:GetPosXYZ()) }
						RemoveActionCamera(false, default_interpolation_time)
					end
				end)
			end
		end
		self.target_action_camera = actionCam
	end

	if IsKindOf(target, "CombatObject") then
		self:SpawnCrosshair(nil, nil, target, not camMoved)
	end

	-- UpdateTarget doesn't run during single target attacks, and covers are shown around the target rather than the mouse.
	-- Therefore on change target we need to manually update them.
	self:ClearTargetCovers()
	if IsKindOf(target, "Unit") then
		local def = Presets.ChanceToHitModifier.Default.RangeAttackTargetStanceCover
		local weapon = attacker:GetActiveWeapons()
		local apply, value = def:CalcValue(attacker, target, nil, nil, weapon, nil, nil, 0, false, attacker:GetPos(), target:GetPos())
		local exposed = def:ResolveValue("ExposedCover")
		self:ShowCoversShields(target:GetPos(), target.stance, attacker:GetPos(), not apply or value == exposed)
	end
	return true
end

function Targeting_AlliesAttack(dialog, blackboard, command, pt)
	local attacker = dialog.attacker
	local action = dialog.action
		
	if dialog:PlayerActionPending(attacker) then
		command = "delete"
	end

	if command == "delete" then
		if blackboard.fx_target then
			PlayFX(blackboard.fx_target_action, "end", blackboard.fx_target)
			blackboard.fx_target = false
		end
		for i, fx in ipairs(blackboard.fx_shot_lines) do
			DoneObject(fx)
		end
		blackboard.fx_shot_lines = false
		return
	end
	
	if dialog.potential_target == blackboard.last_target then return end
	blackboard.last_target = dialog.potential_target
		
	local target, allies
	if IsValid(dialog.potential_target) and dialog.potential_target_is_enemy then
		if HasVisibilityTo(attacker, dialog.potential_target) then
			target = dialog.potential_target
			allies = {}
			for _, unit in ipairs(attacker.team.units) do
				if unit ~= attacker and unit:OnMyTargetGetAllyAttack(target) then
					allies[#allies + 1] = unit
				end
			end
		end
	end

	for i, fx in ipairs(blackboard.fx_shot_lines) do
		DoneObject(fx)
	end
	blackboard.fx_shot_lines = false
	if target and #(allies or empty_table) > 0 then
		local x, y, z = target:GetPosXYZ()
		local target_pos = target:GetSpotLocPos(target:GetSpotBeginIndex("Torso"))
		blackboard.fx_shot_lines = {}
		for i, ally in ipairs(allies) do
			local color = Mesh.ColorFromTextStyle("LineOfFire")
			local posx, posy, posz = ally:GetPosXYZ()
			local attack_pos = point(posx, posy, posz or terrain.GetHeight(posx, posy) + guim)
			
			blackboard.fx_shot_lines[i] = AddShotVisual(nil, attack_pos, target_pos, color)
		end
		dialog:SetTarget(target, true)
	else
		dialog:SetTarget(false, true)
	end
end

function WaitUIEndTurn()
	-- This is just for prettiness as the camera will start moving right away.
	local modeDlg = GetInGameInterfaceModeDlg()
	if modeDlg and modeDlg.crosshair and modeDlg.crosshair.window_state ~= "destroying" then
		modeDlg.crosshair:SetVisible(false)
	end
	-- Exit attacking mode if aiming an attack while ending the turn (such as via a kbd shortcut)
	RestoreDefaultMode(SelectedObj)
end