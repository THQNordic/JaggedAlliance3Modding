if FirstLoad then
	owInArea = 1
	owHasLine = 2
	owNoAllyHit = 4
	owInSight = 8
end

MapVar("g_Overwatch", setmetatable({}, weak_keys_meta))
MapVar("g_Pindown", setmetatable({}, weak_keys_meta))

function OnMsg.UnitRelationsUpdated()
	local attackers = SortUnitsMap(g_Overwatch)
	for _, data in ipairs(attackers) do
		local attacker = data.unit
		if IsValid(attacker.prepared_attack_obj) then
			local mode = attacker.prepared_attack_obj.mode
			if (mode == "Ally") ~= attacker.team.player_ally then
				DoneObject(attacker.prepared_attack_obj)
				attacker.prepared_attack_obj = nil
			end
		end
		attacker:UpdateOverwatchVisual()
	end
end

function Unit:UpdateOverwatchVisual(overwatch)
	overwatch = overwatch or g_Overwatch[self]
	if not overwatch then return end
	
	if (overwatch.permanent and overwatch.num_attacks <= 0) or not self.visible then
		if IsValid(self.prepared_attack_obj) then
			DoneObject(self.prepared_attack_obj)
		end		
		self.prepared_attack_obj = nil
		return
	end
	
	local lightStepHideOW = HasPerk(SelectedObj, "LightStep") and IsValidTarget(SelectedObj) and self:IsOnEnemySide(SelectedObj) and GetInGameInterfaceMode() == "IModeCombatMovement"
	if lightStepHideOW then
		if IsValid(self.prepared_attack_obj) then
			DoneObject(self.prepared_attack_obj)
		end
		self.prepared_attack_obj = nil
	else	
		if overwatch.origin_action_id == "EyesOnTheBack" then
			local step_positions, step_objs = GetStepPositionsInArea(overwatch.pos, overwatch.dist)
			local filtered_positions = table.ifilter(step_positions, function(idx, pt) return not IsOnFadedSlab(pt) end)
			overwatch.pos = SnapToPassSlab(overwatch.pos) or overwatch.pos:SetTerrainZ()
			local visual_pos = overwatch.pos:IsValidZ() and overwatch.pos or overwatch.pos:SetTerrainZ()

			local maxvalue, los_values = CheckLOS(step_positions, overwatch.pos, -1, overwatch.stance, -1, false, false)
			if not self.prepared_attack_obj then
				local data = {
					explosion_pos = visual_pos,
					stance = overwatch.stance,
					range = overwatch.dist,
					step_positions = step_positions,
					step_objs = step_objs,
					los_values = los_values,
				}
				self.prepared_attack_obj = MortarAOEVisuals:new({
					material_prefix = "EyesOnTheBack",
					mode = (self.team.control == "UI" or self.team.player_ally) and "Ally" or "Enemy"}, nil, data)
			end
		else
			if IsValid(self.prepared_attack_obj) and not IsKindOf(self.prepared_attack_obj, "OverwatchVisuals") then				
				DoneObject(self.prepared_attack_obj)
				self.prepared_attack_obj = false
			end
			if not self.prepared_attack_obj then
				self.prepared_attack_obj = OverwatchVisuals:new({mode = (self.team.control == "UI" or self.team.player_ally) and "Ally" or "Enemy"})
			end
			self.prepared_attack_obj:UpdateFromOverwatch(overwatch)
		end
	end
end

local function CalcEarlyOverwatchEntry(unit, action_id, weapon, args, attack_data, target_pos)
	local step_pos = attack_data.step_pos
	local stance = attack_data.stance
	local attacker_pos3D = attack_data.step_pos
	if not attacker_pos3D:IsValidZ() then
		attacker_pos3D = attacker_pos3D:SetTerrainZ()
	end
	local action = CombatActions[action_id]
	if not weapon then
		weapon = action:GetAttackWeapons(unit)
	end
	local aoe_params = action and action:GetAimParams(unit, weapon) or weapon:GetAreaAttackParams(action_id, unit)
	local distance = Clamp(attacker_pos3D:Dist(target_pos), aoe_params.min_range * const.SlabSizeX, aoe_params.max_range * const.SlabSizeX)
	local cone_angle = aoe_params.cone_angle
	local target_angle = CalcOrientation(step_pos, target_pos)
	return {
		pos = step_pos,
		stance = stance,
		angle = target_angle,
		cone_angle = cone_angle,
		target_pos = target_pos,
		dist = distance,
		min_distance_2d = aoe_params.min_distance_2d,
		dir = SetLen(target_pos - step_pos, guim),
		aim = Min((args.aim_ap or 0) / const.Scale.AP, weapon.MaxAimActions),
		action_id = weapon:GetBaseAttack(unit),
		origin_action_id = action_id,
		triggered_by = args.triggered_by,
		permanent = args.permanent,
		num_attacks = args.num_attacks or 1,
		orient = CalcOrientation(step_pos, target_pos),
	}
end

function Unit:OverwatchAction(action_id, cost_ap, args)
	self:EndInterruptableMovement()

	args = table.copy(args)
	args.OverwatchAction = true
	args.num_attacks = (g_Overwatch[self] and g_Overwatch[self].num_attacks) or args.num_attacks
	if self.opportunity_attack then
		local action = CombatActions[action_id]
		local results, attack_args = action:GetActionResults(self, args)
		self:AimTarget(attack_args, results, true)
		self:SetCommand("PreparedAttackIdle")
		return
	end

	local target = args.target
	if not IsPoint(target) and not IsValid(target) then
		if g_Combat then
			self:GainAP(cost_ap)
			CombatActionInterruped(self)
		end
		return
	end
	local action = CombatActions[action_id]
	local weapon = action:GetAttackWeapons(self)
	if not weapon then 
		self:InterruptPreparedAttack()
		return
	end

	local dlg = GetInGameInterfaceModeDlg()
	if dlg and dlg:HasMember("dont_return_camera_on_close") and not g_AIExecutionController then
		dlg.dont_return_camera_on_close = true
	end

	local wasInterruptable
	if not g_Combat then
		wasInterruptable = self.interruptable
		if wasInterruptable then
			self:EndInterruptableMovement()
		end
		if not self:HasStatusEffect("ManningEmplacement") then
			self:UninterruptableGoto(self:GetVisualPos()) -- stop on the nearest free slab
		else
			local handle = self:GetEffectValue("hmg_emplacement")
			local obj = handle and HandleToObject[handle]
			if obj then -- make sure the unit is correctly positioned when loading a save
				local visual = obj.weapon and obj.weapon:GetVisualObj()
				local fire_spot = visual:GetSpotBeginIndex("Unit")
				local fire_pos = visual:GetSpotPos(fire_spot)
				self:SetPos(fire_pos)
			end
		end
		self:SetTargetDummyFromPos()
		self:UpdateAttachedWeapons()
		self:ExplorationStartCombatAction(action_id, self:GetMaxActionPoints(), args)
	end
	
	local target_pos = IsValid(target) and target:GetPos() or target
	local results, attack_args = action:GetActionResults(self, args)
	args.step_pos = attack_args.step_pos
	args.stance = attack_args.stance
	args.can_use_covers = false
	self:SetCombatBehavior("OverwatchAction", {action_id, cost_ap, args})
	if not g_Combat or args.permanent then
		self:SetBehavior("OverwatchAction", {action_id, cost_ap, args})
	end

	local overwatch = CalcEarlyOverwatchEntry(self, action_id, weapon, args, attack_args, target_pos)
	self:UpdateOverwatchVisual(overwatch)

	if not args.activated then
		self:ProvokeOpportunityAttacks("attack interrupt")
	end
	if attack_args.stance and self.stance ~= attack_args.stance then
		self:DoChangeStance(attack_args.stance)
	end
	self:PrepareToAttack(attack_args, results)

	if not args.activated then
		self:ProvokeOpportunityAttacks("attack reaction")		
		PlayFX("OverwatchActivate", "start", self)
	end

	local step_pos = attack_args.step_pos
	local stance = attack_args.stance
	local attacker_pos3D = attack_args.step_pos
	if not attacker_pos3D:IsValidZ() then
		attacker_pos3D = attacker_pos3D:SetTerrainZ()
	end
	local aoe_params = action and action:GetAimParams(self, weapon) or weapon:GetAreaAttackParams(action_id, self)
	local distance = Clamp(attacker_pos3D:Dist(target_pos), aoe_params.min_range * const.SlabSizeX, aoe_params.max_range * const.SlabSizeX)
	local cone_angle = aoe_params.cone_angle
	local target_angle = CalcOrientation(step_pos, target_pos)
	local expiration_turn = args.expiration_turn
	if not expiration_turn then
		if args.permanent then
			expiration_turn = -1
		else
			expiration_turn = (g_Combat and g_Combat.current_turn or 1) + 1
		end
	end
	
	if cone_angle >= 180*60 then -- special case for Omryn's ability
		self.return_pos = false
	end
	
	args.triggered_by = args.triggered_by or {} -- create this in args so it gets automatically saved/restored
	args.expiration_turn = expiration_turn
	g_Overwatch[self] = {
		pos = step_pos,
		stance = stance,
		angle = target_angle,
		cone_angle = cone_angle,
		target_pos = target_pos,
		dist = distance,
		min_distance_2d = aoe_params.min_distance_2d,
		dir = SetLen(target_pos - step_pos, guim),
		aim = Min((args.aim_ap or 0) / const.Scale.AP, weapon.MaxAimActions),
		action_id = self:GetDefaultAttackAction("ranged", "ungrouped", nil, true, "ignore").id,
		origin_action_id = action_id,
		triggered_by = args.triggered_by,
		permanent = args.permanent,
		expiration_turn = expiration_turn,
		num_attacks = args.num_attacks or 1,
		orient = CalcOrientation(step_pos, target_pos),
		weapon_id = weapon.id,
	}
	
	self:UpdateOverwatchVisual()

	local enemies = table.ifilter(GetAllEnemyUnits(self), function(_, enemy) return enemy:GetDist(step_pos) <= distance end)
	if #enemies > 0 then
		local maxvalue, los_values = CheckLOS(enemies, step_pos, distance, stance, cone_angle, target_angle, false)

		-- reveal & mark enemies in the area
		for i, los in ipairs(los_values) do
			if los then
				if enemies[i]:HasStatusEffect("Hidden") then
					CombatLog("short", T{353305209140, "<LogName> was revealed by enemy overwatch", enemies[i]})
					enemies[i]:RemoveStatusEffect("Hidden")
				end
				if HasPerk(self, "Spotter") then
					enemies[i]:AddStatusEffect("Marked")
				end
			end
		end
	end
		
	if action_id ~= "MGSetup" and action_id ~= "MGRotate" then
		self.ActionPoints = 0	
		Msg("UnitAPChanged", self, action_id)
	end
	Msg("OverwatchChanged",self)

	args.activated = true

	if wasInterruptable then
		self:BeginInterruptableMovement()
	end

	self:SetCommand("PreparedAttackIdle")
end

function Unit:GetOverwatchAttacksAndAim(action, args, unit_ap)
	action = action or CombatActions.Overwatch
	local weapon = action:GetAttackWeapons(self)
	local attack = self:GetDefaultAttackAction()
	unit_ap = unit_ap or (g_Combat and self:GetUIActionPoints() or self:GetMaxActionPoints())
	args = table.copy(args)
	args.action_cost_only = true
	local cost = action:GetAPCost(self, args)
	if cost < 0 then
		return 1
	end
	local ap = unit_ap - cost
	local atk_cost = attack:GetAPCost(self, args)
	
	local attacks = 1 + ap / atk_cost
	if HasPerk(self, "OverwatchExpert") then
		attacks = attacks + CharacterEffectDefs.OverwatchExpert:ResolveValue("bonusAttacks")
	end

	local aim = 0
	local extraAttackBonus = GetComponentEffectValue(weapon, "ExtraOverwatchShots", "extra_attacks")
	if extraAttackBonus then
		attacks = attacks + extraAttackBonus
	end
	
	return attacks, aim
end

function Unit:GetOverwatchTarget()
	return g_Overwatch[self] and g_Overwatch[self].target_pos
end

function Unit:InvalidatePindownLinesCache()
	if self.combat_cache then
		self.combat_cache.pindown_line_data = nil
	end
end

local function InvalidatePindownLinesCaches()
	for _, unit in ipairs(g_Units) do
		unit:InvalidatePindownLinesCache()
	end
end
OnMsg.UnitMovementDone = InvalidatePindownLinesCaches
OnMsg.DestructionPassDone = InvalidatePindownLinesCaches
OnMsg.CoversChanged = InvalidatePindownLinesCaches

function Unit:HasPindownLineCached(target, target_spot_group, step_pos)
	if not self.combat_cache or not IsValid(target) then
		return self:HasPindownLine(target, target_spot_group, step_pos)
	end
	
	self.combat_cache.pindown_line_data = self.combat_cache.pindown_line_data or {}
	local hash = xxhash(target.handle, target_spot_group, step_pos)
	local value = self.combat_cache.pindown_line_data[hash]
	if value ~= nil then
		return value
	end
	value = self:HasPindownLine(target, target_spot_group, step_pos) or false
	self.combat_cache.pindown_line_data[hash] = value
	return value
end

function Unit:HasPindownLine(target, target_spot_group, step_pos)
	if type(target) == "number" then
		target = HandleToObject[target]
	end
	if not IsKindOf(target, "Unit") or not HasVisibilityTo(self, target) then 
		return false
	end
	
	local weapon = self:GetActiveWeapons("Firearm")
	local lof_params = {
		weapon = weapon,
		step_pos = step_pos,
		target_spot_group = target_spot_group,
		can_use_covers = false,
	}
	local lof = GetLoFData(self, target, lof_params)
	if not lof or lof.los == 0 then -- check line of sight to target
		return false
	end
		
	-- check line of fire to the specified body part
	local idx = table.find(lof.lof, "target_spot_group", target_spot_group)
	return idx and not lof.lof[idx].stuck	
end

function Unit:PinDown(action_id, cost_ap, args)
	if self.opportunity_attack then
		self:SetCommand("PreparedAttackIdle")
		return
	end
	
	local target = args.target
	if not IsPoint(target) and not IsValid(target) then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	
	args = table.copy(args)
	self:SetCombatBehavior("PinDown", {action_id, cost_ap, args})
	
	local action = CombatActions[action_id]
	local results, attack_args = action:GetActionResults(self, args)
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = attack_args.lof and attack_args.lof[lof_idx or 1]
	local attack_pos = lof_data.attack_pos
	local target_pos = lof_data.target_pos

	if not self:HasPindownLine(target, attack_args.target_spot_group) then
		self:InterruptPreparedAttack()
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end

	g_Pindown[self] = {
		action_id = action_id,
		target = target,
		target_pos = target:GetPos(),
		target_stance = target.stance,
		target_spot_group = attack_args.target_spot_group,
		aim = args.aim,
		weapon_id = results.weapon.id,
	}

	if not args.activated then
		self:ProvokeOpportunityAttacks("attack interrupt")
	end
	self:PrepareToAttack(attack_args, results)
	if not args.activated then
		assert(IsValidTarget(target))
		target:AddStatusEffect("Marked")
		if HasPerk(self, "HawksEye") then
			target:AddStatusEffect("Exposed")
		end
		self:ProvokeOpportunityAttacks("attack reaction")
		PlayFX("PindownActivate", "start", self)
	end

	if IsValid(self.prepared_attack_obj) then
		DoneObject(self.prepared_attack_obj)
	end

	local meshPtr = pstr("")
	local dir = target_pos - attack_pos
	local length = dir:Len()

	CRTrail_AppendLineSegment(meshPtr, attack_pos, target_pos, false, false, false)

	self.prepared_attack_obj = PlaceObject("Mesh")
	self.prepared_attack_obj:SetMeshFlags(const.mfWorldSpace)
	local mat = CRM_VisionLinePreset:GetById(self.team.player_ally and "PreparedAttack" or "PreparedAttackEnemy"):Clone()
	mat.length = length
	self.prepared_attack_obj:SetCRMaterial(mat)
	

	self.prepared_attack_obj:SetColorFromTextStyle("PreparedAttack")
	self.prepared_attack_obj:SetMesh(meshPtr)
	self.prepared_attack_obj:SetPos(attack_pos)

	self.ActionPoints = 0
	Msg("UnitAPChanged", self, action_id)
	Msg("OverwatchChanged",self)

	args.activated = true
	self:SetCommand("PreparedAttackIdle")
end

function Unit:PrepareBombard(action_id, cost_ap, args)
	local target = args.target
	if not IsPoint(target) and not IsValid(target) then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	local action = CombatActions[action_id]
	args = table.copy(args)
	if cost_ap <= 0 then
		cost_ap = action:GetAPCost(self)
	end
	args.spent_ap = cost_ap
	args.prediction = false
	if not g_Combat then
		self:ExplorationStartCombatAction(action_id, cost_ap, args)
		self:SetBehavior("PrepareBombard", {action_id, cost_ap, args})
	end
	self:SetCombatBehavior("PrepareBombard", {action_id, cost_ap, args})
	self:PushDestructor(function(self)
		self:SetBehavior()
		self:SetCombatBehavior()
	end)
	local isPlayerTurn = self:IsMerc() and not g_AIExecutionController
	self:ProvokeOpportunityAttacks("attack interrupt")
	local results, attack_args = action:GetActionResults(self, args)
	self:PrepareToAttack(attack_args, results)

	-- weapon load
	local voxel_pos = GetPassSlab(self) or SnapToVoxel(self):SetZ(self:GetVisualPos():z())
	self:SetPos(voxel_pos)
	self:SetAxisAngle(axis_z, self:GetVisualOrientationAngle(), 0)
	PlayTransitionAnims(self, "nw_Standing_Idle")
	self:SetState("nw_Standing_MortarLoad", const.eKeepComponentTargets)
	local weapon_pos, weapon_angle = self:GetSpotLoc(self:GetSpotBeginIndex("Mortar"))
	local duration = self:TimeToAnimEnd()
	local move_pos = voxel_pos + self:GetStepVector()
	if move_pos:IsValidZ() then
		local stepz = GetVoxelStepZ(move_pos)
		if stepz then
			move_pos = move_pos:SetZ(stepz)
		end
	end
	self:SetPos(move_pos, duration)
	self:SetAngle(self:GetAngle() + self:GetStepAngle(), duration)
	local t = self:TimeToMoment(1, "hit")
	if t then 
		Sleep(t)
	end
	local weapon = self:GetActiveWeapons()
	self.bombard_weapon = weapon:GetVisualObj()
	if self.bombard_weapon then
		self.bombard_weapon:Detach()
		self.bombard_weapon:SetState("idle")
		self.bombard_weapon:SetPos(weapon_pos)
		self.bombard_weapon:SetAxisAngle(axis_z, weapon_angle, 0)
		self.bombard_weapon:SetHierarchyEnumFlags(const.efVisible)
		self.bombard_weapon:SetContourOuterOccludeRecursive(true)
	end
	Sleep(self:TimeToAnimEnd())
	self:SetState("nw_Standing_MortarIdle", const.eKeepComponentTargets)

	if IsValid(self.prepared_bombard_zone) then
		DoneObject(self.prepared_bombard_zone)
	end
	local ordnance = results.ordnance
	local bombard_radius = weapon.BombardRadius
	local bombard_shots = results.fired

	PlayFX("BombardZoneSetup", "start", self)

	local zone = PlaceObject("BombardZone")
	local target_pos = IsValid(target) and target:GetPos() or target

	-- mishap check & effect
	if IsKindOf(weapon, "MishapProperties") then
		local chance = weapon:GetMishapChance(self, target_pos)
		if not CheatEnabled("AlwaysHit") and (CheatEnabled("AlwaysMiss") or self:Random(100) < chance) then
			target_pos = target_pos
			self:ShowMishapNotification(action)
		end
	end

	local time
	if not g_Combat then
		time = 5000
	end
	
	zone.attacker = self
	zone:Setup(target_pos, bombard_radius, self.team.side, ordnance, bombard_shots, time)

	zone.action_id = action_id
	zone.weapon_id = weapon.id
	zone.weapon_condition = results.condition
	self.prepared_bombard_zone = zone

	if isPlayerTurn then
		SnapCameraToObj(zone,nil,nil,200)
		Sleep(const.Combat.BombardSetupHoldTime)
	end
	self:ProvokeOpportunityAttacks("attack reaction")

	self:PopDestructor()
	if g_Combat then
		self.ActionPoints = 0
		Msg("UnitAPChanged", self, action_id)
	else
		self:SetBehavior("PreparedBombardIdle")
	end
	self:SetCombatBehavior("PreparedBombardIdle")
	self:SetCommand("PreparedBombardIdle")
end

function Unit:PreparedAttackIdle()
	if SelectedObj == self then
		local overwatch = g_Overwatch[self]
		self:FlushCombatCache()
		self:RecalcUIActions(true)
		ObjModified(self)
	end
	self:SetTargetDummy(self:GetPos(), self:GetOrientationAngle(), self:GetStateText(), 0)
	Msg("Idle", self)
	Halt()
end

function Unit:PreparedBombardIdle()
	self:PushDestructor(function(self)
		self:SetBehavior()
		self:SetCombatBehavior()
		if IsValid(self.prepared_bombard_zone) then
			DoneObject(self.prepared_bombard_zone)
		end
		self.prepared_bombard_zone = nil
	end)
	if not IsValid(self.prepared_bombard_zone) then
		self:PopAndCallDestructor()
		return
	end
	if not self.bombard_weapon then
		local weapon = self:GetActiveWeapons()
		self.bombard_weapon = weapon and weapon:GetVisualObj()
	end
	if self.bombard_weapon then
		local start_pos = GetPassSlab(self) or SnapToVoxel(self):SetZ(self:GetVisualPos():z())
		local start_angle = self:GetAngle() - self:GetStepAngle("nw_Standing_MortarLoad")
		local mortar_spot = self:GetSpotBeginIndex("Mortar")
		local weapon_pos = start_pos + Rotate(GetEntitySpotPos(self:GetEntity(), mortar_spot), start_angle)
		local weapon_angle = start_angle + GetEntitySpotAngle(self:GetEntity(), mortar_spot)
		self.bombard_weapon:Detach()
		self.bombard_weapon:SetState("idle")
		self.bombard_weapon:SetPos(weapon_pos)
		self.bombard_weapon:SetAxisAngle(axis_z, weapon_angle, 0)
		self.bombard_weapon:SetEnumFlags(const.efVisible)
	end
	self:SetState("nw_Standing_MortarIdle", const.eKeepComponentTargets)
	self:SetTargetDummy(self:GetPos(), self:GetOrientationAngle(), self:GetStateText(), 0)
	Msg("Idle", self)

	if SelectedObj == self then
		SetInGameInterfaceMode(g_Combat and "IModeCombatMovement" or "IModeExploration")
		Sleep(1)
		if g_Combat then
			GetInGameInterfaceModeDlg():NextUnit()
		end
	end
	Halt()
end

function Unit:HolsterBombardWeapon()
	if IsValid(self.bombard_weapon) then
		local item = self.bombard_weapon.weapon
		if not item or table.find(self:GetEquippedWeapons("Handheld A"), item) or table.find(self:GetEquippedWeapons("Handheld B"), item) then
			AttachVisualItems(self, { self.bombard_weapon }, 0, true)
		else
			DoneObject(self.bombard_weapon)
		end
	end
	self.bombard_weapon = nil
end

function Unit:PreparedBombardEnd()
	self:SetState("nw_Standing_MortarEnd", const.eKeepComponentTargets)
	local duration = self:TimeToAnimEnd()
	self:SetAngle(self:GetAngle() + self:GetStepAngle(), duration)
	self:SetPos(GetPassSlab(self) or SnapToVoxel(self):SetZ(self:GetVisualPos():z()), duration)
	Sleep(self:TimeToMoment(1, "hit") or duration)
	self:HolsterBombardWeapon()
	Sleep(self:TimeToAnimEnd())
end

local PreparedAttackCommands = {
	PreparedAttackIdle = true,
	PreparedBombardIdle = true,
}

local PreparedAttackBehaviors = {
	PinDown = true,
	OverwatchAction = true,
	PrepareBombard = true,
	PrepareBombardIdle = true,
	OverwatchAction = true,
}

function Unit:HasPreparedAttack()
	return
		PreparedAttackCommands[self.command] or
		PreparedAttackBehaviors[self.behavior] or
		PreparedAttackBehaviors[self.combat_behavior]
end

function Unit:GetPinDownTarget()
	return g_Pindown[self] and g_Pindown[self].target
end

-- MeleeTraining area
function Unit:UpdateMeleeTrainingVisual()
	local contour_visible
	if g_Combat and #GetEnemies(self) > 0 and not HasCombatActionInProgress(self) then
		contour_visible = self:CanUseMeleeTraining() and (self:IsNPC() or IsCompetitiveGame() and NetPlayerSide() ~= self.team.side)
	end
	
	if contour_visible then
		local pos = self:GetPos()
		if not IsValid(self.melee_threat_contour) or self.melee_threat_contour:GetDist(pos) > 0 then
			local voxels = GetMeleeRangePositions(self)
			voxels = voxels or { }
			table.insert(voxels, point_pack(self:GetPos()))
			local is_ally = self.team.side == "player1" or self.team.side == "player2"
			if not IsValid(self.melee_threat_contour) then
				self.melee_threat_contour = MeleeAOEVisuals:new({vstate = "Deployed"}, nil, {voxels = voxels, pos = pos, mode =  is_ally and "Ally" or "Enemy"})
			else
				self.melee_threat_contour:Init({voxels = voxels, pos = pos, mode =  is_ally and "Ally" or "Enemy"})
			end
		end
	elseif not contour_visible and IsValid(self.melee_threat_contour) then
		DoneObject(self.melee_threat_contour)
		self.melee_threat_contour = nil
	end
end

function Unit:CanUseMeleeTraining()
	return not self:IsIncapacitated() and self:IsAware() and not self:IsDefeatedVillain() and
		self.stance ~= "Prone" and not self:HasStatusEffect("Protected") and self:CanActivatePerk("MeleeTraining") and 
		not not (self:GetActiveWeapons("MeleeWeapon") or not self:GetActiveWeapons()) and
		not self:HasStatusEffect("BandageInCombat") and not self:HasStatusEffect("Unconscious")
end

function OnMsg.UnitMovementStart(unit)
	-- check if the unit is pindown target
	for _, attacker in ipairs(g_Units) do
		local descr = g_Pindown[attacker] or empty_table
		if descr.target == unit then
			if IsValid(attacker.prepared_attack_obj) then
				DoneObject(attacker.prepared_attack_obj)
				attacker.prepared_attack_obj = nil
			end
		end
	end
end

local function UpdatePindowns()
	if not g_Combat then 
		if next(g_Pindown) ~= nil then
			for _, unit in ipairs(g_Units) do
				if g_Pindown[unit] then
					unit:InterruptPreparedAttack()
				end
			end
		end
		return 
	end

	for attacker, descr in sorted_handled_obj_key_pairs(g_Pindown) do
		local target = descr.target
		if type(target) == "number" then
			target = HandleToObject[target]
		end		
		if not IsValidTarget(target) then
			attacker:InterruptPreparedAttack()
		else
			local changed = not IsValid(target) or target:GetDist(descr.target_pos) > 0 or target.stance ~= descr.target_stance
			if changed then
				if not attacker:HasPindownLine(target, descr.target_spot_group) then
					attacker:InterruptPreparedAttack()
				else
					-- reset the command to reenter the pindown (face new location, recreate visual, etc)
					if attacker.command == "PreparedAttackIdle" then
						CreateGameTimeThread(attacker.SetCommand, attacker, "Idle")
					end
				end
			end
		end
	end
end

function OnMsg.UnitMovementDone(unit)
	unit:UpdateMeleeTrainingVisual()
end

function OnMsg.UnitAnyMovementStart(unit)
	unit:UpdateMeleeTrainingVisual()
end

function OnMsg.Idle(unit)
	unit:UpdateMeleeTrainingVisual()
	UpdatePindowns()
end

OnMsg.UnitDieStart = UpdatePindowns

function Unit:RemovePreparedAttackVisuals()
	if IsValid(self.melee_threat_contour) then
		DoneObject(self.melee_threat_contour)
		self.melee_threat_contour = nil
	end
	
	if IsValid(self.prepared_attack_obj) then
		DoneObject(self.prepared_attack_obj)
	end
	self.prepared_attack_obj = nil
end

function Unit:InterruptPreparedAttack(begin_turn)
	if not self.team or self.team.side == "neutral" then return end
	if not self:IsDead() and not self:IsDefeatedVillain() and not self:IsDowned() and not self:HasStatusEffect("BandageInCombat") then
		self:SetCombatBehavior()
		if self.behavior == "OverwatchAction" or self.behavior == "PrepareBombard" then
			self:SetBehavior()
		end
	end
	if IsValid(self.prepared_attack_obj) then
		DoneObject(self.prepared_attack_obj)
	end
	self.prepared_attack_obj = nil
	if g_Overwatch[self] then
		g_Overwatch[self] = nil
		self:RemoveStatusEffect("StationedMachineGun")
		Msg("OverwatchChanged")
		PlayFX("OverwatchActivate", "end", self)
	elseif g_Pindown[self] then
		g_Pindown[self] = nil
		Msg("OverwatchChanged")
		PlayFX("PindownActivate", "end", self)
	end
	if IsValid(self.prepared_bombard_zone) then
		DoneObject(self.prepared_bombard_zone)
	end
	self.prepared_bombard_zone = nil
	self:RecalcUIActions(true)
	ObjModified(self)
	if self:HasPreparedAttack() then
		CreateGameTimeThread(function()
			if IsValid(self) and not self:IsIncapacitated() then
				self:SetCommand(self.bombard_weapon and "PreparedBombardEnd" or "Idle")
			end
		end)
	else
		self:HolsterBombardWeapon()
	end
	if not g_Combat and not g_StartingCombat then
		if self:GetStatusEffect("EyesOnTheBack") and self.signature_recharge then
			self:RechargeSignature("EyesOnTheBack")
		end
		self:RemoveStatusEffect("SpentAP")
	end
end

function Unit:InterruptEnd()
	if self.interrupted then
		self.interrupted = false
		self:SetAnimSpeedModifier(1000)
		self:UpdateMoveSpeed()
		if IsValidThread(self.pain_thread) then
			Wakeup(self.pain_thread)
		end
		if CurrentThread() ~= self.command_thread then
			Wakeup(self.command_thread)
		end
	end
end

function Unit:InterruptBegin()
	if IsValid(self) and self.interruptable and not self.interrupted and not self:IsDead() then
		self.interrupted = true
		self:UpdateMoveSpeed()
		if IsValidThread(self.pain_thread) then
			Wakeup(self.pain_thread)
		end
		if CurrentThread() == self.command_thread then
			if self:GetStepLength() > 0 then
				self:SetState(self:GetIdleBaseAnim())
			end
			self:SetAnimSpeedModifier(30)
		else
			Wakeup(self.command_thread)
		end
	end
end

local OverwatchSpotTargetPreferOrder = { Torso = 1, Groin = 2, Head = 4, Arms = 5, Legs = 6 }

function Unit:OverwatchCheck(target, target_dummies, conditions, sync)
	if #target_dummies == 0 or target:HasStatusEffect("Hidden") then return end
	local overwatch = g_Overwatch[self]
	if not overwatch or overwatch.num_attacks <= 0 then --or overwatch.triggered_by[target.handle] then
		return
	end
	--local action = CombatActions[overwatch.action_id]
	local action = self:GetDefaultAttackAction("ranged", "ungrouped")
	local aim_type = action.AimType
	local is_aoe = aim_type == "cone" or aim_type == "aoe" or aim_type == "parabola aoe" or aim_type == "line aoe"
	local weapon1, weapon2 = action:GetAttackWeapons(self)
	local base_sight = self:HasStatusEffect("ManningEmplacement") and const.Combat.AwareSightRange or false
	local sight = self:GetSightRadius(target, base_sight)
	local attack_args = {
		obj = self,
		--action_id = overwatch.action_id,
		action_id = action.id,
		step_pos = overwatch.pos,
		occupied_pos = self:GetOccupiedPos(),
		stance = overwatch.stance,
		range = overwatch.dist,
		angle = overwatch.angle,
		cone_angle = overwatch.cone_angle,
		can_use_covers = false,
		group_spots = false, -- dual shot should find out which spot should be target
		require_los = true,
		prediction = true,
	}
	local wdata1, wdata2
	if weapon1 then
		attack_args.weapon = weapon1
		wdata1 = GetLoFData(self, target_dummies, attack_args) or false
	end
	if weapon2 then
		attack_args.weapon = weapon2
		wdata2 = GetLoFData(self, target_dummies, attack_args) or false
	end

	local trigger_idx, trigger_best_target_idx
	for i, target_dummy in ipairs(target_dummies) do
		local lof1 = wdata1 and wdata1[i]
		local lof2 = wdata2 and wdata2[i]

		conditions[i] = conditions[i] or 0

		local in_area = lof1 and lof1.lof or lof2 and lof2.lof
		if in_area then
			conditions[i] = bor(conditions[i], owInArea)
		end

		-- do sight check manually here instead of in LOF check to discern between "in larger cone, out of sight" and "out of cone" cases
		local dist = self:GetDist(IsValid(target_dummy) and target_dummy or target_dummy.pos or target_dummy.obj)
		
		if in_area then
			conditions[i] = bor(conditions[i], owHasLine)
		end
		
		if in_area and (dist <= sight) then
			conditions[i] = bor(conditions[i], owInSight)
			local best_idx, best_value
			if not is_aoe then
				local spot_lof1 = lof1 and lof1.lof or empty_table
				local spot_lof2 = lof2 and lof2.lof or empty_table
				for k = 1, Max(#spot_lof1, #spot_lof2) do
					local hit_data1 = spot_lof1[k] or empty_table
					local hit_data2 = spot_lof2[k] or empty_table
					if (hit_data1.ally_hits_count or 0) == 0 and (hit_data2.ally_hits_count or 0) == 0 then
						local value = OverwatchSpotTargetPreferOrder[hit_data1.target_spot_group] or 100
						if not best_idx or value < best_value or value == best_value and (not sync or self:Random(100) < 50) then
							best_idx, best_value = k, value
						end
					else
						best_idx, best_value = nil, nil
						break
					end
				end
			end
			if is_aoe or best_idx then
				conditions[i] = bor(conditions[i], owNoAllyHit)
				if not trigger_idx then
					trigger_idx = i
					trigger_best_target_idx = best_idx
				end
			end
		end
	end
	if trigger_idx then
		local lof = wdata1 and wdata1[trigger_idx] or wdata2 and wdata2[trigger_idx]
		local target_lof = trigger_best_target_idx and lof.lof[trigger_best_target_idx]
		for k, v in pairs(lof) do
			attack_args[k] = v
		end
		if target_lof then
			attack_args.best_ally_hits_count = 0
			--attack_args.lof_pos1 = target_lof.lof_pos1
			--attack_args.lof_pos2 = target_lof.lof_pos2
			--attack_args.target_pos = target_lof.target_pos
			attack_args.target_spot = target_lof.target_spot
			attack_args.target_spot_group = target_lof.target_spot_group
		end
		return trigger_idx, attack_args
	end
end

local function GetNearbyPathfindingPath(unit)
	local path = {}
	local d = const.SlabSizeX
	local x, y, z = unit:GetVisualPosXYZ()
	if not unit:IsValidZ() then
		z = nil
	end
	local p0 = point(x, y, z)
	path[1] = p0
	local vx, vy, vz = SnapToVoxel(x, y, z)
	local path_idx = unit:GetPathPointCount()
	while path_idx > 0 do
		local p1 = pf.GetPathPoint(unit, path_idx)
		if p1:IsValid() then
			local dx = p1:x() - vx
			local dy = p1:y() - vy
			if dx < -d or dx >= d or dy < -d or dy >= d then
				p1 = point(p0:x() + Clamp(dx, -d, d), p0:y() + Clamp(dy, -d, d), p1:z())
				if p1 ~= path[#path] then
					path[#path + 1] = p1
				end
				break
			end
			if p1 ~= path[#path] then
				path[#path + 1] = p1
			end
			p0 = p1
		else
			path_idx = path_idx - 1
			p0 = pf.GetPathPoint(unit, path_idx)
		end
		path_idx = path_idx - 1
	end
	return path
end

function Unit:CheckProvokeOpportunityAttacks(trigger_type, target_dummies, visible_only, return_result, trigger_attack_type)
	-- return by default the interrupts of the very first dummy
	if IsSetpiecePlaying() or not self.team or self.team.side == "neutral" then
		return
	end
	if g_StartingCombat then -- units moving to their combat positions should not provoke opportunity attacks, only their combat movement
		-- todo: check interactions with traps/mines
		return
	end
	
	if self.opportunity_attack then
		return -- already in opportunity attack (melee interrupt, pindown, overwatch, retaliate)
	end
	if #target_dummies == 0 then
		return
	end	
	
	local hardblow
	if self.move_attack_action_id and trigger_type == "move" then
		local action = CombatActions[self.move_attack_action_id]
		if action and action.ActionType == "Melee Attack" and HasPerk(self, "HardBlow") then
			hardblow = true
		end
	end

	local interrupts = {}
	target_dummies = table.icopy(target_dummies)

	local AddInterrupt = function(idx, provoke_attack, obj, attack_args, keep_dummy, interrupt_pos)
		if visible_only and not HasVisibilityTo(self.team, obj) then return end
		if return_result ~= "all" then
			if idx < #target_dummies and not keep_dummy then
				for k = 1, #target_dummies - idx do
					table.remove(target_dummies)
				end
				table.iclear(interrupts)
			end
		end
		table.insert(interrupts, {provoke_attack, obj, attack_args, target_dummies[idx], interrupt_pos})
	end

	-- pindown
--[[	if next(g_Pindown) then
		if trigger_type == "attack interrupt" or trigger_type == "move" then
			local attackers = SortUnitsMap(g_Pindown)
			for _, data in ipairs(attackers) do
				local attacker, descr = data.unit, data.data
				if descr.target == self then
					if CheckLOS(self, attacker, attacker:GetSightRadius()) then
						AddInterrupt(1, "pindown", attacker)
					else
						attacker:InterruptPreparedAttack()
					end
				end
			end
		end
	end--]]

	-- traps
	if trigger_type == "move" then
		local idx = 1
		local pos
		while idx <= #target_dummies do
			local dummy = target_dummies[idx]
			local dummy_obj = IsValid(dummy) and dummy or dummy.obj or self
			local prev_pos = pos
			pos = IsValid(dummy) and dummy:GetPos() or dummy.pos or dummy_obj:GetPos()
			if not pos:IsValid() then
				pos = nil
			end
			if pos then
				if not pos:IsValidZ() then
					pos = pos:SetTerrainZ()
				end
				local segment_dist = prev_pos and pos:Dist2D(prev_pos) or 0
				MapForEach(pos, MaxTrapTriggerRadius * const.SlabSizeX, "Landmine", function(obj)
					if obj:IsDead() then
						return
					end

					-- This isn't necessary for MaxTrapTriggerRadius above since we don't know where pos is relative to
					-- the center of a voxel, and in the worst case we'll just cut it off here.
					local radius = obj:GetTriggerDistance()
					if radius <= 0 then
						return
					end
					local dist = obj:GetDist2D(pos)
					if dist >= radius then
						if segment_dist > 0 and dist + segment_dist < radius then
							dist = DistPtToSegment2D(prev_pos, pos, obj:GetPos())
						end
						if dist >= radius + const.SlabSizeX * 3 / 4 then
							return
						end
					end
					local z = select(3, obj:GetPosXYZ()) or terrain.GetHeight(obj)
					if abs(z - pos:z()) > const.SlabSizeZ then
						return
					end
					local passed_type
					local passed_idx = table.find(self.passed_interrupts, 2, obj)
					if passed_idx then
						passed_type = self.passed_interrupts[passed_idx][1]
						if passed_type == "trap" then
							return
						end
					end
					local side = self.team and self.team.side
					local seen = obj:SeenByTeam(side)
					if visible_only and not seen then
						return
					end
					if seen and not self.combat_path and not (side == "player1" or side == "player2" or side == "ally") then
						return
					end
					-- exploration_interrupt
					if dist >= radius then
						if not self.combat_path and not self.goto_interrupted then
							local vx, vy, vz = SnapToVoxel(pos:xyz())
							local d = const.SlabSizeX
							local bbox = box(vx - d - radius, vy - d - radius, vx + d + radius, vy + d + radius)
							if bbox:Point2DInside(obj:GetPosXYZ()) then
								local nearbyPath = GetNearbyPathfindingPath(self)
								local pt_interrupt
								for k = 2, #nearbyPath do
									local dist, x, y, z = DistSegmentToPt2D(nearbyPath[k-1], nearbyPath[k]:x(), nearbyPath[k]:y(), 0, obj)
									if dist < radius then
										local interrupt_pt = GetPassSlab(point(x, y, z))
										if not interrupt_pt or IsCloser2D(obj, interrupt_pt, radius) then
											interrupt_pt = GetPassSlab(nearbyPath[k-1])
										end
										AddInterrupt(idx, "trap_approach", obj, nil, nil, interrupt_pt)
										break
									end
								end
							end
						end
						return
					end
					AddInterrupt(idx, "trap", obj)
					if return_result == "any" then
						return "break"
					end
					if not seen and not passed_type and idx > 1 then
						for i = idx - 1, 1, -1 do
							local interrupt_pos = SnapToPassSlab(target_dummies[idx - 1].pos)
							if interrupt_pos and not IsCloser(obj, interrupt_pos, radius) then
								AddInterrupt(i, "trap_interrupt", obj)
								break
							end
						end
					end
				end)
				if #interrupts > 0 and return_result == "any" then
					return interrupts, #interrupts
				end
			end
			idx = idx + 1
		end
	end

	-- melee interrupts (movement)
	if g_Combat and trigger_type == "move" and not hardblow then
		for _, attacker in ipairs(g_Units) do
			if attacker:CanUseMeleeTraining() and attacker:IsOnEnemySide(self) and not table.find(self.passed_interrupts, 2, attacker) then
				local idx_melee_atk
				for idx, dummy in ipairs(target_dummies) do
					local can_melee_attack
					if IsValid(dummy) then
						local target = IsKindOf(dummy, "TargetDummy") and dummy.obj or dummy
						can_melee_attack = IsMeleeRangeTarget(attacker, nil, attacker.stance, target, nil, dummy.stance)
					else
						can_melee_attack = IsMeleeRangeTarget(attacker, nil, attacker.stance, dummy.obj, dummy.pos, dummy.stance)
					end
					if can_melee_attack then
						idx_melee_atk = idx
					elseif idx_melee_atk == idx - 1 then
						if return_result == "any" then
							return true
						end
						AddInterrupt(idx_melee_atk, "melee", attacker)
						break
					end
				end
			end
		end
	end
		
	-- melee interrupts (ranged attacks;)
	local melee_trigger = (trigger_type == "attack interrupt" and trigger_attack_type ~= "melee") or
			(trigger_type == "attack reaction" and trigger_attack_type == "melee")
	if g_Combat and melee_trigger and not hardblow then
		for _, attacker in ipairs(g_Units) do
			if attacker:CanUseMeleeTraining() and attacker:IsOnEnemySide(self) and not table.find(self.passed_interrupts, 2, attacker) then
				for idx, dummy in ipairs(target_dummies) do
					local can_melee_attack
					if IsValid(dummy) then
						local target = IsKindOf(dummy, "TargetDummy") and dummy.obj or dummy
						can_melee_attack = IsMeleeRangeTarget(attacker, nil, attacker.stance, target, nil, dummy.stance)
					else
						can_melee_attack = IsMeleeRangeTarget(attacker, nil, attacker.stance, dummy.obj, dummy.pos, dummy.stance)
					end
					if can_melee_attack then
						if return_result == "any" then
							return true
						end
						AddInterrupt(idx, "melee", attacker)
						break
					end
				end
			end
		end
	end

	-- overwatch
	if next(g_Overwatch) and not hardblow then
		if trigger_type == "attack interrupt" or trigger_type == "move" and not HasPerk(self, "LightStep") then
			local overwatch_interrupt, fail_interrupt
			local attackers = SortUnitsMap(g_Overwatch)
			for _, data in ipairs(attackers) do
				local attacker = data.unit
				if attacker:IsOnEnemySide(self) and
					(g_Combat or (attacker.team.player_enemy and attacker:HasStatusEffect("ManningEmplacement"))) and
					(not visible_only or HasVisibilityTo(self.team, attacker)) and
					not table.find(self.passed_interrupts, 2, attacker)
				then
					local conditions = {}
					local idx, attack_args = attacker:OverwatchCheck(self, target_dummies, conditions, not visible_only)
					if idx then
						if return_result == "any" then
							return true
						end
						if fail_interrupt then
							table.remove(interrupts, fail_interrupt)
							fail_interrupt = nil
						end
						AddInterrupt(idx, "overwatch", attacker, attack_args)
						overwatch_interrupt = #interrupts
					elseif not overwatch_interrupt and not fail_interrupt then
						-- check if there's a non-zero condition (in area) and add a provisional "interrupt" to indicate a failed trigger if no real trigger happens
						local trigger_condition
						for i, cond in ipairs(conditions) do
							if cond ~= 0 then
								trigger_condition = cond
								idx = i
								break
							end
						end
						if trigger_condition then
							if return_result == "any" then
								return true
							end
							AddInterrupt(idx, "failoverwatch", attacker, trigger_condition, "keep")
							fail_interrupt = #interrupts
						end
					end
				end
			end
		end
	end

	if #interrupts > 0 then
		return interrupts, #target_dummies
	end
end

function Unit:FinishOpportunityAttack_Pindown()
	self:InterruptPreparedAttack()
	self:SetAttackReason()
end

function Unit:ProvokeOpportunityAttack_Pindown(obj, descr)
	--No need to reset them as it is assumed AIExecutionController:Done to run later on.
	self:InterruptBegin()
	LockCameraMovement("pindown")
	AdjustCombatCamera("set")
	descr = descr or g_Pindown[obj]
	obj:SetAttackReason(T(579571403585, "Pin Down"), true)

	local cmd_thread = CurrentThread() == self.command_thread
	if cmd_thread then
		self:PushDestructor(function(self)
			obj:FinishOpportunityAttack_Pindown()
		end)
	end
	
	local num_attacks = HasPerk(obj, "Killzone") and 2 or 1
	
	for i = 1, num_attacks do
		local weapon = obj:GetActiveWeapons("Firearm")
		local default_action = obj:GetDefaultAttackAction()
		if not weapon or not default_action or not obj:CanAttack(self, weapon, default_action, 0, nil, "skip_ap_check") then
			break
		end
		if IsValidTarget(self) then
			obj:SetCommand("PinDownAttack", self, descr.action_id, descr.target_spot_group, descr.aim)
			while not obj:IsIdleCommand() do
				WaitMsg("Idle", 100)
			end
		end
	end

	-- hit makes target go Pain/Die and breaks the execution of the cleanup code below
	while not obj:IsIdleCommand() do
		WaitMsg("Idle")
	end
	if cmd_thread then
		self:PopDestructor()
	end
	obj:FinishOpportunityAttack_Pindown()
end

function Unit:FinishOpportunityAttack_Overwatch()
	local overwatch = g_Overwatch[self]
	self:SetAttackReason()
	if not overwatch then
		return
	end
	
	local action = CombatActions[overwatch.action_id]
	local weapon1, weapon2 = action:GetAttackWeapons(self)
	local jammed = not weapon1 or weapon1.jammed
	local out_of_ammo = not weapon1 or self:OutOfAmmo(weapon1)
	if weapon2 then
		jammed = jammed and weapon2.jammed
		out_of_ammo = out_of_ammo and self:OutOfAmmo(weapon2)
	end
	local remaining = overwatch.num_attacks - 1
	overwatch.num_attacks = remaining
	if jammed or out_of_ammo then
		self:InterruptPreparedAttack()
	elseif remaining <= 0 then
		if overwatch.permanent then
			CreateFloatingText(self, T(559296489948, "No remaining attacks"), "FloatingTextMiss")
			self:UpdateOverwatchVisual(overwatch)
		else
			self:InterruptPreparedAttack()
		end
	end
end

function Unit:ProvokeOpportunityAttack_Overwatch(obj, attack_args, target_dummy)
	local overwatch = g_Overwatch[obj]
	if not overwatch then return end
	--local action = CombatActions[overwatch.action_id]
	overwatch.triggered_by[self.handle] = true
	CombatLog("short", T{353305209140, "<LogName> was revealed by enemy overwatch", self})
	self:RemoveStatusEffect("Hidden")
	self:InterruptBegin()

	local reason = T(484641340197, "Overwatch")
	obj:SetAttackReason(reason, true)

	local cmd_thread = CurrentThread() == self.command_thread
	if cmd_thread then
		self:PushDestructor(function(self)
			obj:FinishOpportunityAttack_Overwatch()
		end)
	end
	attack_args.aim = overwatch.aim
	attack_args.origin_action_id = overwatch.origin_action_id
	assert(attack_args.target == self)
	attack_args.target_dummy = target_dummy
	attack_args.opportunity_attack = true
	attack_args.opportunity_attack_type = "Overwatch"
	if overwatch.cone_angle > 180*60 then
		attack_args.circular_overwatch = true
	end
	local lof_data
	for _, data in ipairs(attack_args.lof) do
		if data.ally_hits_count == 0 and data.target_spot_group == attack_args.target_spot_group then
			lof_data = data
			break
		end
	end
	lof_data = lof_data or attack_args.lof[1]
	table.clear(attack_args.lof)
	lof_data.target_spot_group = "Torso" -- treat resulting hits as if they hit the target in the torso
	attack_args.lof[1] = lof_data
	attack_args.target_spot_group = "Torso"

	local status
	local num_attacks = HasPerk(obj, "Killzone") and 2 or 1

	for i = 1, num_attacks do
		local weapon = obj:GetActiveWeapons("Firearm")
		local default_action = obj:GetDefaultAttackAction("ranged", "ungrouped", nil, true, "ignore")
		if not weapon or not default_action or not obj:CanAttack(self, weapon, default_action, 0, nil, "skip_ap_check") then
			break
		end
		overwatch.action_id = default_action.id
		if IsValidTarget(self) then
			if IsKindOf(obj.prepared_attack_obj, "AOEActionVisuals") then
				obj.prepared_attack_obj:SetState("activate", self:GetPos())
			end
			obj:SetCommand("OpportunityAttack", default_action.id, attack_args, status)
			if attack_args.circular_overwatch and obj.combat_behavior == "OverwatchAction" then
				local shot_vector = self:GetPos() - obj:GetPos()
				local target_pos = (obj:GetPos() + SetLen(shot_vector, overwatch.dist)):SetZ(overwatch.target_pos:z())
				local args = obj.combat_behavior_params[3]
				if args then 
					args.target = target_pos 
				end
 			end
			while not obj:IsIdleCommand() do
				WaitMsg("Idle", 100)
			end
		end
	end

	if cmd_thread then
		self:PopDestructor()
	end
	obj:FinishOpportunityAttack_Overwatch()
end

function Unit:FinishOpportunityAttack_Melee()
	self:SetAttackReason()
	self:UpdateMeleeTrainingVisual()
end

function Unit:ProvokeOpportunityAttack_Melee(unit)
	unit:SetAttackReason(CharacterEffectDefs.MeleeTraining.DisplayName, true)

	local cmd_thread = CurrentThread() == self.command_thread
	if cmd_thread then
		self:PushDestructor(function(self)
			unit:FinishOpportunityAttack_Melee()
		end)
	end
	local action = unit:GetDefaultAttackAction()
	if not action or action.ActionType ~= "Melee Attack" then
		action = CombatActions.MeleeAttack
	end
	unit:SetCommand("OpportunityMeleeAttack", self, action)
	self:InterruptBegin()
	while not unit:IsIdleCommand() do
		WaitMsg("Idle")
	end
	if cmd_thread then
		self:PopDestructor()
	end
	unit:FinishOpportunityAttack_Melee()
end

function Unit:ProvokeOpportunityAttack_Trap(obj)
	-- Trap explosions shouldn't be interruptable due to stuff like
	-- explosion fly as that can cause the attack to be cut short.
	local wasInterruptable = self.interruptable
	if wasInterruptable then
		self:EndInterruptableMovement()
	end
	self:InterruptBegin()
	obj:TriggerTrap(self, obj.attacker)
	if wasInterruptable then
		self:BeginInterruptableMovement()
	end
end

function Unit:ProvokeOpportunityAttack_TrapInterrupt(obj)
	if obj:IsDead() then
		return
	end
	local seen = obj:SeenByTeam(self.team.side)
	if not seen then
		obj:CheckDiscovered(self)
		seen = obj:SeenByTeam(self.team.side)
	end
	if seen then
		self:Interrupt()
	end
end

function Unit:ProvokeOpportunityAttacksFromList(list)
	for i, data in ipairs(list) do
		local provoke_attack, attacker, attack_args, target_dummy = table.unpack(data)
		if IsValid(attacker) then
			if provoke_attack == "trap" then
				self:ProvokeOpportunityAttack_Trap(attacker, attack_args, target_dummy)
			elseif provoke_attack == "trap_interrupt" then
				self:ProvokeOpportunityAttack_TrapInterrupt(attacker, attack_args, target_dummy)
			elseif attacker:IsKindOf("Unit") and not attacker:IsDead() and not attacker:IsDowned() then
				if provoke_attack == "pindown" then
					self:ProvokeOpportunityAttack_Pindown(attacker)
				elseif provoke_attack == "overwatch" then
					self:ProvokeOpportunityAttack_Overwatch(attacker, attack_args, target_dummy)
				elseif provoke_attack == "failoverwatch" then
					self:InterruptBegin()
					CreateFloatingText(self, T(231879654091, "Overwatch Failed"), "FloatingTextMiss")
					local condition = attack_args
					
					if band(condition, owHasLine) == 0 then
						CombatLog("important",T{174159992548, "(<attacker>) Overwatch failed: no line of sight", attacker = attacker:GetLogName()})
					elseif band(condition, owInSight) == 0 then
						CombatLog("important",T{787029916541, "(<attacker>) Overwatch failed: out of sight range", attacker = attacker:GetLogName()})
					elseif band(condition, owNoAllyHit) == 0 then
						CombatLog("important",T{121792198447, "(<attacker>) Overwatch failed: ally in the way", attacker = attacker:GetLogName()})
					else
						CombatLog("important",T{957255271523, "(<attacker>) Overwatch failed", attacker = attacker:GetLogName()})
						CombatLog("debug", T{Untranslated("overwatch fail condition: <value>"), value = condition})
					end					
				elseif provoke_attack == "melee" then
					self:ProvokeOpportunityAttack_Melee(attacker, attack_args, target_dummy)
				end
			end
			if not self.passed_interrupts then
				self.passed_interrupts = {}
			end
			table.insert(self.passed_interrupts, data)
		end
		
		local provocationAttacksLeft = 0
		for c = i, #list do
			local attackType = list[c][1]
			if attackType == "melee" or attackType == "overwatch" or attackType == "pindown" then
				provocationAttacksLeft = provocationAttacksLeft + 1
			end
		end
		if provocationAttacksLeft == 1 then
			Msg("ActionCameraWaitSignalEnd")
		end
	end
	if self.interrupted then
		Sleep(const.Combat.ShootDelayAfterInterrupt)
		self:InterruptEnd()
		self:WaitPain()
	end
end

function Unit:ProvokeOpportunityAttacksWarning(trigger_type, interrupts)
	local warned_traps_pos = self.warned_traps_pos
	if warned_traps_pos and not self.goto_interrupted then
		self.warned_traps_pos = false
	end
	if not interrupts or not (self.team and self.team:IsPlayerControlled()) then
		return
	end
	if not self:IsInterruptable() then
		return
	end
	if trigger_type == "move" and self.team then
		 for i, data in ipairs(interrupts) do
			local provoke_attack = data[1]
			if provoke_attack == "trap" or provoke_attack == "trap_approach" then
				local obj = data[2]
				if not obj:IsDead() and obj:SeenByTeam(self.team.side) then
					local interrupt_pos = data[5]
					if self.combat_path then
						self:Interrupt(interrupt_pos)
					else
						if warned_traps_pos then
							if IsCloser2D(interrupt_pos or self, warned_traps_pos, const.SlabSizeX) then
								self.warned_traps_pos = warned_traps_pos
								return
							end
						end
						self.warned_traps_pos = interrupt_pos or self:GetVisualPos()
						self:InterruptCommand("GotoSlab", interrupt_pos, nil, nil, nil, nil, nil, "interrupted")
					end
					return
				end
			end
		end
	end
end

function Unit:ProvokeOpportunityAttacks(trigger_type, target_dummy, trigger_attack_type)
	local target_dummies = { target_dummy or self.target_dummy or self }
	local interrupts = self:CheckProvokeOpportunityAttacks(trigger_type, target_dummies, nil, nil, trigger_attack_type)
	if not interrupts then
		return
	end
	self:ProvokeOpportunityAttacksFromList(interrupts, target_dummy)
end

function Unit:IsThreatened(enemies, mode)
	if not IsValid(self) then return end

	enemies = enemies or GetEnemies(self)
	local pos = self:GetVisualPos()	

	for _, enemy in ipairs(enemies) do
		if (not mode or mode == "pindown") and g_Pindown[enemy] and g_Pindown[enemy].target == self then
			return true
		end

		local enemy_ow = g_Overwatch[enemy]
		if (not mode or mode == "overwatch") and enemy_ow then
			local angle = enemy_ow.orient or CalcOrientation(enemy:GetPos(), enemy_ow.target_pos)
			if CheckLOS(self, enemy, enemy_ow.dist, enemy.stance, enemy_ow.cone_angle, angle) and enemy:CanSee(self) then
				return true
			end
		end

		-- check melee threats
		if not mode or mode == "melee" then
			if enemy.stance ~= "Prone" and enemy:CanActivatePerk("MeleeTraining") and enemy:GetActiveWeapons("MeleeWeapon") then
				if IsMeleeRangeTarget(enemy, nil, enemy.stance, self, nil, self.stance) then
					self.is_melee_aim_last_turn = true
					return true
				end
			end
		end
	end
end

function Unit:IsUnderBombard()
	for _, bombard in ipairs(g_Bombard) do
		if IsCloser(self, bombard, (bombard.radius + g_Classes[bombard.ordnance].AreaOfEffect) * const.SlabSizeX) then
			return true
		end
	end
end

function Unit:IsUnderTimedTrap()
	for _, trap in pairs(g_Traps) do
		if trap.TriggerType == "Timed" and trap.visible and not trap.done and not trap:IsDead() then
			local trapCenter = trap:GetPos()
			local trapRadius = trap.AreaOfEffect * const.SlabSizeX
			if self:GetDist(trapCenter) <= trapRadius then
				return true
			end
		end
	end
end

function Unit:GetNumMGInterruptAttacks(skip_check)
	if not skip_check and not self:HasStatusEffect("StationedMachineGun") and not self:HasStatusEffect("ManningEmplacement") then
		return 0
	end
	local action = self:GetDefaultAttackAction()
	local ap_cost = action:GetAPCost(self)
	if ap_cost <= 0 then
		return 0
	end
	local ap = g_Combat and self:GetUIActionPoints() or self:GetMaxActionPoints()
	
	return const.Combat.MGFreeInterruptAttacks + ap / ap_cost
end

local function TimeToNextMoment(obj, moment)
	local t = obj:TimeToMoment(1, moment)
	if not t then
		return false
	end
	
	local index = 1
	while t == 0 do
		index = index + 1
		t = obj:TimeToMoment(1, moment, index)
	end
	return t
end

function OnMsg.GatherFXMoments(list)
	table.insert(list, "InterruptableStart")
	table.insert(list, "InterruptableEnd")
end

MapRealTimeRepeat("OverwatchAreaUpdate", 200, function()
	if not g_Combat then return end
	
	for unit, overwatch in pairs(g_Overwatch) do
		unit:UpdateOverwatchVisual(overwatch)
	end
end)

function OnMsg.InterruptAttackStart(unit, target, action)
	if not HasVisibilityTo(target.team, unit) 
	   and (unit.team.side == "enemy1" or unit.team.side == "enemy2") then
		ShowTacticalNotification("interruptStealth", true, false, action)
	else
		ShowTacticalNotification("interrupt", true, false, action)
	end
end

function OnMsg.InterruptAttackEnd()
	HideTacticalNotification("interrupt")
	HideTacticalNotification("interruptStealth")
end