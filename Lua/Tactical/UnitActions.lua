--List of grenades that will result in different VR played when thrown
SpecialGrenades = {
	[1] = "ConcussiveGrenade",
	[2] = "SmokeGrenade",
	[3] = "TearGasGrenade",
	[4] = "ToxicGasGrenade",
	[5] = "Molotov",
	[6] = "FlareStick"
}


function Unit:OnAttack(action, target, results, attack_args, holdXpLog)	
	if type(action) == "string" then
		action = CombatActions[action]
	end
	
	if IsKindOf(results.weapon, "FirearmBase") then
		results.weapon.num_safe_attacks = Max(0, results.weapon.num_safe_attacks - 1)
	end
	
	if IsKindOf(results.weapon, "TransmutedItemProperties") and results.weapon.RevertCondition=="attacks" then
		results.weapon.RevertConditionCounter = results.weapon.RevertConditionCounter-1
		if results.weapon.RevertConditionCounter== 0 then
			local slot_name = self:GetItemSlot(results.weapon)
			local new, prev = results.weapon:MakeTransmutation("revert")
			self:RemoveItem(slot_name, results.weapon)
			self:AddItem(slot_name, new)
			DoneObject(prev)
			self:UpdateOutfit()
		end
	end
	
	-- Add Exposed on any Melee Attack hit
	if action.ActionType == "Melee Attack" and IsKindOf(target, "Unit") and not results.miss then 
		target:AddStatusEffect("Exposed")
	end
		
	if IsValidTarget(target) then
		target.attacked_this_turn = target.attacked_this_turn or {}
		table.insert(target.attacked_this_turn, self)
	end
	
	local kill = #(results.killed_units or empty_table) > 0
	
	if kill then
		Msg("OnKill", self, results.killed_units)
	end
	
	-- singatures can't recharge themselves
	local originAction = CombatActions[attack_args.origin_action_id]
	if kill and (action.group ~= "SignatureAbilities" and (not originAction or originAction.group ~= "SignatureAbilities")) then
		self:UpdateSignatureRecharges("kill")
	end
	
	-- signature actions never recharge themselves, this has to be after UpdateSignatureRecharges
	if action.group == "SignatureAbilities" then 
		local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
		local rechargeTime = action:ResolveValue("rechargeTime") or const.Combat.SignatureAbilityRechargeTime
		if rechargeTime > 0 then
			self:AddSignatureRechargeTime(action.id, rechargeTime, recharge_on_kill > 0)
		end
	end
	
	Msg("OnAttack", self, action, target, results, attack_args)
	
	local hitUnitFromAttack = false
	for _, hit in ipairs(results.hit_objs) do
		if IsKindOf(hit.obj, "Unit") then
			if hit.damage and hit.damage > 0 then
				hitUnitFromAttack = true
				break
			end
		end
	end
	
	if results.miss then
		Msg("AttackMiss", self, target)
		if IsKindOf(target, "Unit") and not IsMerc(target) then
			target:AddStatusEffect("AITauntCounter")
			if not hitUnitFromAttack then
				local effect = target:GetStatusEffect("AITauntCounter")
				if effect and effect.stacks >= 3 then
					PlayVoiceResponse(target, "AITaunt")
				end
			end
		end
	end
	
	-- Reward xp to Mercs on kill
	if kill and IsMerc(self) then
		if not g_AccumulatedTeamXP then g_AccumulatedTeamXP = {} end
		for i, unit in ipairs(results.killed_units) do
			if self:IsOnEnemySide(unit) then
				RewardTeamExperience(unit, GetCampaignPlayerTeam())
			end
		end
		if not holdXpLog then LogAccumulatedTeamXP("debug") end
	end
	
	if next(results.killed_units) then
		local killCam = not not ActionCameraPlaying
		local waitTime = killCam and const.Combat.UnitDeathKillcamWait or const.Combat.UnitDeathWait
		Sleep(waitTime)
		if killCam then
			Msg("ActionCameraWaitSignalEnd")
		end
	end
end

function Unit:GetLastAttack()
	return self.last_attack_session_id and g_Units[self.last_attack_session_id]
end

local function ResetLastAttack(unit)
	if unit:IsAmbientUnit() then return end
	
	unit.last_attack_session_id = false
	local session_id = unit.session_id
	if session_id then
		for _, u in ipairs(g_Units) do
			if u.last_attack_session_id == session_id then
				u.last_attack_session_id = false
			end
		end
	end
end

function IsBasicAttack(action, attack_args)
	local basicAttack
	if attack_args.origin_action_id then
		basicAttack = CombatActions[attack_args.origin_action_id].basicAttack
	else
		basicAttack = action.basicAttack
	end
	return basicAttack
end

OnMsg.UnitMovementDone = ResetLastAttack
OnMsg.UnitDied = ResetLastAttack

MapVar("g_CurrentAttackActions", {}) -- stack of all started attack actions
MapVar("g_Interrupt", false)

function Unit:WaitAttack()
	self:UninterruptableGoto(self:GetVisualPos())
	self.waiting_attack = true
end

function Unit:FirearmAttack(action_id, cost_ap, args, applied_status) -- SingleShot/DualShot
	if true then	 -- net debug code
		local effects = {}
		for i, effect in ipairs(self.StatusEffects) do
			effects[i] = effect.class
		end
		effects = table.concat(effects, ",")
		local target_effects = "-"
		if IsKindOf(args.target, "Unit") then
			target_effects = {}
			for i, effect in ipairs(args.target.StatusEffects) do
				target_effects[i] = effect.class
			end
			target_effects = table.concat(target_effects, ",")
		end

		NetUpdateHash("Unit:FirearmAttack", action_id, cost_ap, self, effects, args.target, target_effects)
	end -- end net debug code
	local target = args.target
	if IsPoint(target) or IsValidTarget(target) then
		local action = CombatActions[action_id]

		if HasPerk(self, "Psycho") and (action_id == "SingleShot" or action_id == "BurstFire") then
			local chance = CharacterEffectDefs.Psycho:ResolveValue("procChance")
			local roll = InteractionRand(100, "Psycho")
			if roll < chance then
				local weapon = action:GetAttackWeapons(self)
				if action_id == "SingleShot" and table.find(weapon.AvailableAttacks, "BurstFire") then
					action = CombatActions["BurstFire"]
					PlayVoiceResponse(self, "Psycho")
				elseif action_id == "BurstFire" and table.find(weapon.AvailableAttacks, "AutoFire") then
					action = CombatActions["AutoFire"]
					PlayVoiceResponse(self, "Psycho")
				end
			end
		end
		
		if action.StealthAttack then
			args.stealth_kill_roll = 1 + self:Random(100)
		end
		args.prediction = false
		if IsKindOf(target, "Unit") and target:LightningReaction() then
			args.chance_to_hit = 0
		end
		
		local units_waiting = {}
		
		self:PushDestructor(function()
			for _, unit in ipairs(units_waiting) do
				unit.waiting_attack = false
			end
		end)
		
		if not g_Combat and IsKindOf(target, "Unit") then
			units_waiting[1] = target
			PropagateAwareness(units_waiting)
			for _, unit in ipairs(units_waiting) do
				if unit:IsInterruptable() then
					unit.waiting_attack = true
					unit:InterruptCommand("WaitAttack")
				end
			end
			repeat
				local waiting = false
				for _, unit in ipairs(units_waiting) do
					waiting = waiting or (unit.command == "WaitAttack" and not unit.waiting_attack)
				end
				if waiting then
					Sleep(10)
				end
			until not waiting
		end
		
		local results, attack_args = action:GetActionResults(self, args)
		self:ExecFirearmAttacks(action, cost_ap, attack_args, results)
		self:PopAndCallDestructor()
	else
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
	end
end

function Unit:ExecFirearmAttacks(action, cost_ap, attack_args, results)
	self:EndInterruptableMovement()

	NetUpdateHash("ExecFirearmAttacks", action, cost_ap, not not g_Combat)
	local lof_idx = table.find(attack_args.lof, "target_spot_group", attack_args.target_spot_group or "Torso")
	local lof_data = attack_args.lof[lof_idx or 1]
	local target = attack_args.target
	local target_unit = IsKindOf(target, "Unit") and IsValidTarget(target) and target
	local interrupt = attack_args.interrupt
	if interrupt then
		if ActionCameraPlaying then
			RemoveActionCamera(true)
			WaitMsg("ActionCameraRemoved", 5000)
		end
		Msg("InterruptAttackStart", self, target_unit, action) 
	end
	
	NetUpdateHash("ExecFirearmAttacks_After_Interrupt_Cam_Wait")
	
	results.attack_from_stealth = not not self:HasStatusEffect("Hidden")
	for _, attack in ipairs(results.attacks or {results}) do
		if attack.fired then
			self:AttackReveal(action, attack_args, results)
			break
		end
	end

	local can_provoke_opportunity_attacks = not action or action.id ~= "CancelShot" and action.id ~= "CancelShotCone"
	if can_provoke_opportunity_attacks then
		self:ProvokeOpportunityAttacks("attack interrupt")
	end
	self:PrepareToAttack(attack_args, results)
	if can_provoke_opportunity_attacks then
		self:ProvokeOpportunityAttacks("attack interrupt")
	end
	NetUpdateHash("ExecFirearmAttacks_Start_Action_Cam")
	-- camera effects
	if attack_args.opportunity_attack_type ~= "Retaliation" then
		local cinematicKill = false
		local dontPlayForLocalPlayer = false
		if g_Combat and IsEnemyKill(self, results) then
			g_Combat:CheckPendingEnd(results.killed_units)
			
			local isKillCinematic 
			isKillCinematic, dontPlayForLocalPlayer = IsEnemyKillCinematic(self, results, attack_args)
			if isKillCinematic then
				cameraTac.SetForceMaxZoom(false)
				SetAutoRemoveActionCamera(self, results.killed_units[1], nil, nil, nil, nil, nil, dontPlayForLocalPlayer)
				cinematicKill = true
			end
		elseif interrupt then -- the attack is from enemy pindown or overwatch
			--[[if self.team.side == "enemy" then
				SetAutoRemoveActionCamera(target_unit, self, 1000, true) -- todo: should this use the anim duration?
			else
				SetAutoRemoveActionCamera(self, target_unit, 1000, true)
			end--]]
		end
		if not cinematicKill and IsKindOf(target, "Unit") then
			local cinematicAttack, interpolation = IsCinematicAttack(self, results, attack_args, action)
			if cinematicAttack then
				local playerUnit = (IsKindOf(target, "Unit") and target:IsLocalPlayerTeam() and target) or (self:IsLocalPlayerTeam() and self)
				local enemyUnit = playerUnit and (playerUnit == target and self or target)
				if playerUnit and enemyUnit then
					SetAutoRemoveActionCamera(playerUnit, enemyUnit, false, false, false, interpolation and default_interpolation_time, nil, dontPlayForLocalPlayer)
				end
			end
		end
	end
	NetUpdateHash("ExecFirearmAttacks_After_Action_Cam")
	-- animspeed modifier & cmd destructor
	local asm = self:GetAnimSpeedModifier()
	local anim_speed_mod = attack_args.anim_speed_mod or 1000
	self:SetAnimSpeedModifier(anim_speed_mod)
	self:PushDestructor(function(self)
		self:SetAnimSpeedModifier(asm)
		if IsValid(target) and target:HasMember("session_id") then
			self.last_attack_session_id = target.session_id
		else
			self.last_attack_session_id = false
		end
		
		local cooldown = action:ResolveValue("cooldown")
		if cooldown then
			self:SetEffectExpirationTurn(action.id, "cooldown", g_Combat.current_turn + cooldown)
		end
		
		if IsValid(target) then
			ObjModified(target)
		end
		
		if interrupt then Msg("InterruptAttackEnd") end
		table.remove(g_CurrentAttackActions) -- pop the pushed attack action
	end)
	
	local ap = (cost_ap and cost_ap > 0) and cost_ap or action:GetAPCost(self, attack_args)
	table.insert(g_CurrentAttackActions, { action = action, cost_ap = ap, attack_args = attack_args, results = results })

	-- start anim, wait hit moment, apply ammo/condition results
	local 	chance_to_hit =  results.chance_to_hit
	local 	missed        =  results.miss
	local critical = results.crit
	local chance_crit = results.crit_chance
	local aim_state = self:GetStateText()
	
	local fired = false	
	if results.attacks then --- multi-weapon attacks (DualShot)
		local shots = results.attacks[1] and results.attacks[1].shots
		self:StartFireAnim(shots and shots[1], attack_args)
		for _, attack in ipairs(results.attacks) do
			attack.weapon:ApplyAmmoUse(self, attack.fired, attack.jammed, attack.condition)
			fired = fired or attack.fired
		end
	else
		self:StartFireAnim(results.shots and results.shots[1], attack_args)
		results.weapon:ApplyAmmoUse(self, results.fired, results.jammed, results.condition)
		fired = results.fired
	end
	
	if not fired then
		-- none of the weapons fired, abort
		Sleep(self:TimeToAnimEnd())
		self:PopAndCallDestructor()
		NetUpdateHash("ExecFirearmAttacks_early_out")
		return
	end

	PushUnitAlert("noise", self, results.weapon.Noise, Presets.NoiseTypes.Default.Gunshot.display_name)

	local shot_threads = {}	
	
	local attacks = results.attacks or {results}
	local attackArgs = results.attacks_args or {attack_args}
	
	if results.shots and #results.shots > 8 and g_Combat and not g_Combat:ShouldEndCombat(results.killed_units) then
		if (not results.killed_units or #results.killed_units == 1) then
			local vr = IsMerc(self) and "Autofire" or "AIAutofire"
			PlayVoiceResponse(self, vr)
		end
	end
	
	local lowChanceShot
	local base_weapon_damage = 0
	for attackIdx, attack in ipairs(attacks) do
		local attackArg = attackArgs[attackIdx]
		local fx_action = attackArg.fx_action
		if action.id == "BulletHell" then
			BulletHellOverwriteShots(attack)
		end
		local shots_per_animation = Min(3, #attack.shots)
		if action.id == "BurstFire" or action.id == "MGBurstFire" then
			shots_per_animation = #attack.shots
		end
		for i, shot in ipairs(attack.shots) do
			-- shot visuals
			attack.weapon:FireBullet(self, shot, shot_threads, results, attackArg)
			if attackArg.single_fx then
				fx_action = ""
			end
			if i < #attack.shots then -- more shots to fire
				if i % shots_per_animation == 0 then
					local shotAnimDelay = attackArg.attack_anim_delay or self:TimeToAnimEnd()
					self:StartFireAnim(attack.shots[i+1], attackArg, nil, shotAnimDelay) -- fire next shot
				else
					Sleep(self:GetAnimDuration() / shots_per_animation)
				end
			elseif attackIdx < #attacks then
				Sleep(MulDivRound(self:GetAnimDuration() / shots_per_animation, 30, 100))
			end
			if IsMerc(self) and attack.target_hit then
				if attack.chance_to_hit <= 20 then
					lowChanceShot = true
				end
			end
		end
		attack.weapon:FireSpread(attack, attackArg) -- deal the area damage, if any
		base_weapon_damage = base_weapon_damage + attack.weapon.Damage
	end

	-- additional damage (e.g. from DualShot perk)
	for _, packet in ipairs(results.extra_packets) do	
		if IsValidTarget(packet.target) then
			if packet.damage then
				packet.target:TakeDirectDamage(packet.damage, false, "short", packet.message)
			end
			if packet.effects then
				packet.target:ApplyDamageAndEffects(false, false, packet)
			end
		end
	end

	-- wait end moment and restore animation
	local time_to_fire_end = self:TimeToAnimEnd()
	if not attack_args.dont_restore_aim then
		if self:CanAimIK(results.weapon) then
			local restore_aim_delay = Min(300, time_to_fire_end)
			Sleep(restore_aim_delay)
			self:SetIK("AimIK", lof_data.lof_pos2, nil, nil, 0)
			Sleep(time_to_fire_end - restore_aim_delay)
			self:SetState(aim_state, const.eKeepComponentTargets)
		else
			Sleep(time_to_fire_end)
			self:SetState(aim_state, const.eKeepComponentTargets)
		end
	end

	-- special-case: interrupt neutral units with neutral_retaliate flag attacked by player units,
	-- so they don't look ridiculous minding their own business for several more seconds until the attack resolves
	if self.team.player_team and not g_Combat then
		if IsValid(target_unit) and target_unit.team.neutral and target_unit.neutral_retaliate and not target_unit:IsIncapacitated() then
			target_unit.neutral_retal_attacked = true
			target_unit:SetBehavior()
			target_unit:SetCommand("Idle")
		end
		
		local hits = #results > 0 and results or results.area_hits
		for _, hit in ipairs(hits) do
			local unit = IsKindOf(hit.obj, "Unit") and not hit.obj:IsIncapacitated() and hit.obj
			if IsValid(unit) and unit.team.neutral and unit.neutral_retaliate then
				unit.neutral_retal_attacked = true
				unit:SetBehavior()
				unit:SetCommand("Idle")
			end
		end
	end

	if attack_args.external_wait_shots then
		table.iappend(attack_args.external_wait_shots, shot_threads)
	else
		Firearm:WaitFiredShots(shot_threads)
	end

	-- wait target dodge anim
	while target_unit and target_unit.command == "Dodge" do
		WaitMsg("Idle")
	end
	-- play voices
	base_weapon_damage = MulDivRound(base_weapon_damage, 120, 100)
	if attacks and next(attacks)then
		--count shots fired per team for Voice Response
		self.team.tactical_situations_vr.shotsFired = self.team.tactical_situations_vr.shotsFired and self.team.tactical_situations_vr.shotsFired + 1 or 1
		self.team.tactical_situations_vr.shotsFiredBy = self.team.tactical_situations_vr.shotsFiredBy  or {}
		self.team.tactical_situations_vr.shotsFiredBy[self.session_id] = true
		PlayVoiceResponseTacticalSituation(table.find(g_Teams, self.team), "now")
		if missed then
		
			--count missed shots per team for Voice Response
			self.team.tactical_situations_vr.missedShots = self.team.tactical_situations_vr.missedShots and self.team.tactical_situations_vr.missedShots + 1 or 1
			PlayVoiceResponseTacticalSituation(table.find(g_Teams, self.team), "now")
			
			if chance_to_hit >= 70 then
				if not target_unit or not target_unit:IsCivilian() then
					PlayVoiceResponseMissHighChance(self)
				end
			elseif target_unit and chance_to_hit>=50 and base_weapon_damage>=target_unit:GetTotalHitPoints() then
				if IsMerc(target_unit) then
					target_unit:SetEffectValue("missed_by_kill_shot", true)
				end
			end
		elseif not missed then
			if results.stealth_kill and IsMerc(self) and results.killed_units and #results.killed_units > 0 then	
				
			elseif lowChanceShot and target_unit and not self:IsOnAllySide(target_unit) and not target_unit:IsCivilian() then
				PlayVoiceResponse(self, "LowChanceShot")
			end
		end
	end
	
	for i, attack in ipairs(attacks) do
		local holdXpLog = i ~= #attacks
		self:OnAttack(action, target_unit, attack, attack_args, holdXpLog)
	end
		
	LogAttack(action, attack_args, results)
	AttackReaction(action, attack_args, results, "can retaliate")
	
	if not action or (action.id ~= "CancelShot" and action.id ~= "CancelShotCone") then
		self:ProvokeOpportunityAttacks("attack reaction")
	end
	
	self:PopAndCallDestructor()
end

function Unit:MGSetup(action_id, cost_ap, args)
	self.interruptable = false
	if self.stance ~= "Prone" then
		self:DoChangeStance("Prone")
	end
	self:AddStatusEffect("StationedMachineGun")
	self:UpdateHidden()
	self:FlushCombatCache()
	self:RecalcUIActions(true)
	ObjModified(self)
	return self:MGTarget(action_id, cost_ap, args)
end

function Unit:MGTarget(action_id, cost_ap, args)
	args.permanent = true
	args.num_attacks = self:GetNumMGInterruptAttacks()
	self.interruptable = false
	return self:OverwatchAction(action_id, cost_ap, args) -- this would change the command anyway, we can't have code below it
end

function Unit:MGPack()
	self:InterruptPreparedAttack()
	self:RemoveStatusEffect("StationedMachineGun")
	self:UpdateHidden()
	self:FlushCombatCache()
	self:RecalcUIActions(true)
	if HasPerk(self, "KillingWind") then
		self:RemoveStatusEffect("FreeMove")
		self:AddStatusEffect("FreeMove")
	end
	ObjModified(self)
end

function Unit:OpportunityAttack(action_id, args, status)--target, target_spot_group, action, status)
	-- does basically nothing on its own but changes the name of the current command (relevant for overwatch/to-hit modifiers)
	g_Interrupt = true
	args.interrupt = true
	PlayFX("OpportunityAttack", "start", self)
	self:FirearmAttack(action_id, 0, args, status)
end

function Unit:PinDownAttack(target, action_id, target_spot_group, aim, status)
	-- does basically nothing on its own but changes the name of the current command (relevant for overwatch/to-hit modifiers)
	local args = { target = target, target_spot_group = target_spot_group, aim = aim, interrupt = true, opportunity_attack = true, opportunity_attack_type = "PinDown" }
	self:FirearmAttack(action_id, 0, args, status)
end

function Unit:RetaliationAttack(target, target_spot_group, action)
	-- does basically nothing on its own but changes the name of the current command
	self:AddStatusEffect("RetaliationCounter")
	PlayFX("OpportunityAttack", "start", self)
	local args = { target = target, target_spot_group = target_spot_group, interrupt = true, opportunity_attack = true, opportunity_attack_type = "Retaliation" }
	if string.match(action.id, "ThrowGrenade") then -- can't Run the action as it will change the command unfortunately
		return self:ThrowGrenade(action.id, 0, args)
	end
	return self:FirearmAttack(action.id, 0, args)
end

function Unit:OpportunityMeleeAttack(target, action)
	-- does basically nothing on its own but changes the name of the current command
	if self.team and self.team.control == "AI" then
		PlayVoiceResponse(self, "AIMeleeOpportunist")
	end	
	PlayFX("OpportunityAttack", "start", self)
	self:MeleeAttack(action.id, 0, { target = target, opportunity_attack = true, opportunity_attack_type = "Retaliation"})
end

local tf_smooth_sleep = 100
local tf_smooth_thread = false
function SetTimeFactorSmooth(tf, time)
	DeleteThread(tf_smooth_thread)
	tf_smooth_thread = CreateRealTimeThread(function()
		local curr_tf = GetTimeFactor()
		if curr_tf == tf then
			return
		end
		local delta = MulDivRound(tf - curr_tf, tf_smooth_sleep, time)
		local cmp = curr_tf < tf
		while cmp == (curr_tf + delta < tf) do
			curr_tf = curr_tf + delta
			SetTimeFactor(curr_tf)
			Sleep(tf_smooth_sleep)
		end
		SetTimeFactor(tf)
	end)
end

local smooth_tf_change_duration = 1500
function Unit:RunAndGun(action_id, cost_ap, args)
	local action = CombatActions[action_id]
	local target = args.goto_pos
	local weapon = action:GetAttackWeapons(self)
	if not weapon then 
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return 
	end
	local aim_params = action:GetAimParams(self, weapon)
	local num_shots = aim_params.num_shots
	
	if self.stance ~= "Standing" then
		self:ChangeStance(action_id, 0, "Standing")
	end
	
	-- do the attack/crit rolls
	args.attack_rolls = {}
	args.crit_rolls = {}
	args.stealth_kill_rolls = {}
	for i = 1, num_shots do
		args.attack_rolls[i] = 1 + self:Random(100)
		args.crit_rolls[i] = 1 + self:Random(100)
		if action.StealthAttack then
			args.stealth_kill_rolls[i] = 1 + self:Random(100)
		end
	end
	args.prediction = false
	NetUpdateHash("RunAndGun_0", self, args)
	local results = action:GetActionResults(self, args)
	local action_camera = false --[[ disable action camera for now ]]
	if #(results.attacks or empty_table) == 0 then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return 
	end
	
	local pathObj, path
	self:PushDestructor(function(self)
		if pathObj then
			DoneObject(pathObj)
		end
	end)
	pathObj = CombatPath:new()
	
	if action_camera then
		local tf = GetTimeFactor()
		self:PushDestructor(function()
			SetTimeFactorSmooth(tf, smooth_tf_change_duration)
		end)
	end
	local base_idle = self:GetIdleBaseAnim()
	local shot_threads
	for i, attack in ipairs(results.attacks) do
		if not self:CanUseWeapon(weapon) then -- might jam, run out of ammo, etc
			goto continue
		end
		NetUpdateHash("RunAndGun_1", self, attack.mobile_attack_pos, attack.mobile_attack_target)		
		if attack.mobile_attack_pos and (not IsValidTarget(attack.mobile_attack_target) or attack.mobile_attack_target:IsIncapacitated()) then
			local enemies = table.ifilter(action:GetTargets({self}), function(idx, u) return IsValidTarget(u) and not u:IsIncapacitated() end)
			NetUpdateHash("RunAndGun_Branch_1", self, attack.mobile_attack_pos, #enemies)
			attack.mobile_attack_target = FindTargetFromPos(action_id, self, action, enemies, point(point_unpack(attack.mobile_attack_pos)), weapon)
		end
		if attack.mobile_attack_pos and IsValidTarget(attack.mobile_attack_target) then
			if action_camera and i == 1 then
				SetTimeFactorSmooth(tf/2, smooth_tf_change_duration)
			end
			
			-- We need to build the path outside of the function so that it
			-- doesn't refund us the ap cost difference.
			local targetPos = point(point_unpack(attack.mobile_attack_pos))
			local occupiedPos = self:GetOccupiedPos()
			if self:GetDist(occupiedPos) > const.SlabSizeX / 2 and self:GetDist(targetPos) < const.SlabSizeX / 2 then
				-- already at target position because of expose/aim
				self:SetTargetDummy(nil, nil, base_idle, 0)
			else
				pathObj:RebuildPaths(self, aim_params.move_ap)
				path = pathObj:GetCombatPathFromPos(targetPos)			
				self:CombatGoto(action_id, 0, nil, path, true, i == #results.attacks and args.toDoStance)
			end

			-- recheck target, as they might have died while we were moving
			if not IsValidTarget(attack.mobile_attack_target) or attack.mobile_attack_target:IsIncapacitated() then
				local enemies = table.ifilter(action:GetTargets({self}), function(idx, u) return IsValidTarget(u) and not u:IsIncapacitated() end)
				NetUpdateHash("RunAndGun_Branch_1_1", self, attack.mobile_attack_pos, #enemies)
				attack.mobile_attack_target = FindTargetFromPos(action_id, self, action, enemies, point(point_unpack(attack.mobile_attack_pos)), weapon)
				if not IsValidTarget(attack.mobile_attack_target) then
					goto continue
				end
			end

			if action_camera then
				if i == #results.attacks then
					SetTimeFactorSmooth(tf, smooth_tf_change_duration)
				end
				SetActionCamera(self, attack.mobile_attack_target)
			end
			self:SetRandomAnim(base_idle)
			local atk_action = CombatActions[attack.mobile_attack_id] or action
			
			-- rerun simulation to account for changes happened in the meantime (broken covers, etc)
			local atk_args = {
				prediction = false,
				target = attack.mobile_attack_target,
				stance = "Standing",
				can_use_covers = i == #results.attacks,
				used_action_id = action_id, -- so that cth is calculated for the master/parent action instead of the actual attack action
			}			
			
			NetUpdateHash("RunAndGun_2", self, atk_args.target, args.goto_pos)
			local atk_results, attack_args = atk_action:GetActionResults(self, atk_args)			
			attack_args.origin_action_id = action_id
			attack_args.keep_ui_mode = true
			attack_args.unit_moved = true
			attack_args.dont_restore_aim = true
			if atk_action.id == "KnifeThrow" then
				self:ExecKnifeThrow(atk_action, cost_ap, attack_args, atk_results)
			else
				shot_threads = shot_threads or {}
				attack_args.external_wait_shots = shot_threads
				self:ExecFirearmAttacks(atk_action, cost_ap, attack_args, atk_results)
			end
		end
		::continue::
	end
	
	local cooldown = action:ResolveValue("cooldown")
	if cooldown then
		self:SetEffectExpirationTurn(action.id, "cooldown", g_Combat.current_turn + cooldown)
	end
	if action_camera then
		RemoveActionCamera()
		self:PopAndCallDestructor() -- camera
	end

	-- if not at target loc, goto there (there mustn't be a target when that happens)	
	local occupiedPos = self:GetOccupiedPos()
	if self.return_pos and self.return_pos:Dist(target) < const.SlabSizeX / 2 then
		self:ReturnToCover()
	elseif self:GetDist(occupiedPos) > const.SlabSizeX / 2 and self:GetDist(target) < const.SlabSizeX / 2 then
		self:SetTargetDummyFromPos()
	else
		pathObj:RebuildPaths(self, aim_params.move_ap)
		path = pathObj:GetCombatPathFromPos(target)
		self:CombatGoto(action_id, 0, nil, path, true)
	end
	if shot_threads then
		Firearm:WaitFiredShots(shot_threads)
	end	
	self:PopAndCallDestructor() -- pathObj 
end

function Unit:HundredKnives(action_id, cost_ap, args)
	local action = CombatActions[action_id]	
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
	
	self:RunAndGun(action_id, cost_ap, args)
end

function Unit:RecklessAssault(action_id, cost_ap, args)
	self:RunAndGun(action_id, cost_ap, args)
	self:SetTired(self.Tiredness + 1)
end

function Unit:HeavyWeaponAttack(action_id, cost_ap, args)
	local target = args.target
	if not IsPoint(target) and not IsValidTarget(target) then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	self:ProvokeOpportunityAttacks("attack interrupt")
	local action = CombatActions[action_id]
	local weapon = action:GetAttackWeapons(self)
	args.prediction = false
	local results, attack_args = action:GetActionResults(self, args)
	results.attack_from_stealth = not not self:HasStatusEffect("Hidden")
	
	if results.fired then
		self:AttackReveal(action, attack_args, results)
	end
	
	self:PrepareToAttack(attack_args, results)
	self:ProvokeOpportunityAttacks("attack interrupt")

	self:PushDestructor(function()
		local ap = (cost_ap and cost_ap > 0) and cost_ap or action:GetAPCost(self, attack_args)
		table.insert(g_CurrentAttackActions, { action = action, cost_ap = ap, attack_args = attack_args, results = results })
		local aim_pos = results and results.trajectory and results.trajectory[2] and results.trajectory[2].pos
		self:StartFireAnim(nil, attack_args, aim_pos)
		local anim_end_time = GameTime() + self:TimeToAnimEnd()

		local prev = weapon.Condition
		weapon.Condition = results.condition
		if prev ~= results.condition then
			Msg("ItemChangeCondition", weapon, prev, results.condition, self)
		end
		weapon:ApplyAmmoUse(self, results.fired, results.jammed, results.condition)
		if not results.jammed and results.trajectory then
			local ordnance = results.ordnance
			local trajectory = results.trajectory
			local action_dir = SetLen(trajectory[2].pos - trajectory[1].pos, 4096)
			local visual_obj = weapon:GetVisualObj(self)
			-- temporarily change the fx actor class of the visual obj if it doesn't match (subweapons)
			local actor_class = visual_obj.fx_actor_class
			visual_obj.fx_actor_class = weapon:GetFxClass()
			PlayFX("WeaponFire", "start", visual_obj, nil, trajectory[1].pos, action_dir)
			visual_obj.fx_actor_class = actor_class

			-- animate trajectory
			local attaches = visual_obj:GetAttaches("OrdnanceVisual")
			local projectile
			if attaches then
				projectile = attaches[1] 
				projectile:Detach()
			else
				projectile = PlaceObject("OrdnanceVisual", {fx_actor_class = ordnance.class})
			end
			if IsKindOf(weapon, "RocketLauncher") then
				weapon:UpdateRocket()
				PlayFX("RocketFire", "start", projectile)
			end
			
			local backfire_results = table.copy(results)
			for i = #backfire_results, 1, -1 do
				if not backfire_results[i].backfire then
					table.remove(backfire_results, i)
				end
			end
			for i = #results, 1, -1 do
				if results[i].backfire then
					table.remove(results, i)
				end
			end
			ApplyExplosionDamage(self, nil, backfire_results, nil, "disable burn FXes")
			
			local rpm_range = const.Combat.GrenadeMaxRPM - const.Combat.GrenadeMinRPM
			local rpm = const.Combat.GrenadeMinRPM + self:Random(rpm_range)
			local rotation_axis = RotateAxis(axis_x, axis_z, CalcOrientation(trajectory[2].pos, trajectory[1].pos))
			if weapon.trajectory_type == "line" then
				-- disable rotation and make sure the rocket is oriented towards the target point
				rpm = 0
				projectile:SetAxis(axis_z)
				projectile:SetAngle(CalcOrientation(trajectory[1].pos, trajectory[2].pos))
			end
			local throw_thread = CreateGameTimeThread(AnimateThrowTrajectory, projectile, trajectory, rotation_axis, -rpm, "GrenadeDrop")
			Sleep(self:TimeToAnimEnd())
			if IsValidThread(throw_thread) then
				local anim = self:GetAimAnim()
				self:SetState(anim, const.eKeepComponentTargets)
				while IsValidThread(throw_thread) do
					WaitMsg("GrenadeDoneThrow", 20)
				end
			end

			-- recheck results to handle possible changes in unit positions (exploration mode)
			args.explosion_pos = results.explosion_pos or projectile:GetPos()
			results, attack_args = action:GetActionResults(self, args) 

			-- do explosion/apply results
			ApplyExplosionDamage(self, projectile, results)
			LogAttack(action, attack_args, results)
			PushUnitAlert("noise", projectile, ordnance.Noise, Presets.NoiseTypes.Default.Explosion.display_name)			
			if IsValid(projectile) then
				DoneObject(projectile)
			end
			AttackReaction(action, attack_args, results)

			self:OnAttack(action_id, nil, results, attack_args)
		end

		if anim_end_time - GameTime() > 0 then
			Sleep(anim_end_time - GameTime())
		end
		
		local dlg = GetInGameInterfaceModeDlg()
		if dlg and dlg:HasMember("dont_return_camera_on_close") then
			dlg.dont_return_camera_on_close = true
		end
		
		local cooldown = action:ResolveValue("cooldown")
		if cooldown then
			self:SetEffectExpirationTurn(action.id, "cooldown", g_Combat.current_turn + cooldown)
		end
		self.last_attack_session_id = false	
		self:ProvokeOpportunityAttacks("attack reaction")
		table.remove(g_CurrentAttackActions)
	end)
	self:PopAndCallDestructor()
end

function Unit:FireFlare(action_id, cost_ap, args)
	local target = args.target
	if not IsPoint(target) and not IsValidTarget(target) then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	self:ProvokeOpportunityAttacks("attack interrupt")
	local action = CombatActions[action_id]
	local weapon = action:GetAttackWeapons(self)
	args.prediction = false
	local results, attack_args = action:GetActionResults(self, args)
	results.attack_from_stealth = not not self:HasStatusEffect("Hidden")
	
	if results.fired then
		self:AttackReveal(action, attack_args, results)
	end
	
	self:PrepareToAttack(attack_args, results)
	self:ProvokeOpportunityAttacks("attack interrupt")

	local fire_anim = self:GetAttackAnim(action_id)
	local aim_anim = self:GetAimAnim(action_id)
	
	self:SetState(fire_anim)
	local duration = self:TimeToAnimEnd()
	local hit_moment = self:TimeToMoment(1, "hit") or duration/2
	Sleep(hit_moment)
	local weapon_visual = weapon:GetVisualObj(self)
	PlayFX("FlareHandgun_Fire", "start", weapon_visual)
	
	local thread	= not results.jammed and CreateGameTimeThread(function()
		local visual = PlaceObject("GrenadeVisual", {fx_actor_class = "FlareBullet"})
		local offset = point(0, 0, 200*guic)
		offset = offset + Rotate(point(30*guic, 0, 0), self:GetAngle() + 90*60)+ Rotate(point(20*guic, 0, 0), self:GetAngle())
		local pos = self:GetPos()
		if not pos:IsValidZ() then
			pos = pos:SetTerrainZ()
		end
		pos = pos + offset
		visual:SetPos(pos)
		Sleep(100)
		visual:SetPos(pos + point(0, 0, 20*guim), 1500)
		Sleep(2000)
		local explosion_pos = results.explosion_pos +point(0, 0, 10*guic)
		local sky_pos = explosion_pos + point(0, 0, 20*guim)
		local col, pts = CollideSegmentsNearest(sky_pos, explosion_pos)
		if col then
			explosion_pos = pts[1]
		end

		visual:SetPos(sky_pos)		
		local fall_time = MulDivRound(sky_pos:Dist(explosion_pos), 1000, const.Combat.MortarFallVelocity/5)
		visual:SetPos(explosion_pos, fall_time)
		Sleep(fall_time)
		
		local flare = PlaceObject("FlareOnGround", {
			visual_obj = visual,
			remaining_time = 4*5000,
			Despawn = true,
			campaign_time = Game.CampaignTime,
		})
		flare:SetPos(explosion_pos)
		flare:UpdateVisualObj()
		PushUnitAlert("thrown", flare, self)
		Wakeup(self.command_thread)
	end)
	
	Sleep(duration - hit_moment)
	self:SetRandomAnim(self:GetIdleBaseAnim())
	
	results.weapon:ApplyAmmoUse(self, results.fired, results.jammed, results.condition)
	
	while IsValidThread(thread) do
		WaitWakeup(50)
	end
	
	self.last_attack_session_id = false	
	self:ProvokeOpportunityAttacks("attack reaction")	
end

function Unit:ThrowGrenade(action_id, cost_ap, args)
	self:EndInterruptableMovement()

	local stealth_attack = not not self:HasStatusEffect("Hidden")
	local target_pos = args.target
	if self.stance ~= "Standing" then
		self:ChangeStance(nil, nil, "Standing")
	end
	self:ProvokeOpportunityAttacks("attack interrupt")
	local action = CombatActions[action_id]
	local grenade = action:GetAttackWeapons(self)
	args.prediction = false -- mishap needs to happen now
	local results, attack_args = action:GetActionResults(self, args) -- early check for PrepareToAttack
	self:PrepareToAttack(attack_args, results)
	self:UpdateAttachedWeapons()
	self:ProvokeOpportunityAttacks("attack interrupt")

	-- camera effects
	if not attack_args.opportunity_attack_type == "Retaliation" then
		if g_Combat and IsEnemyKill(self, results) then
			g_Combat:CheckPendingEnd(results.killed_units)
			local isKillCinematic, dontPlayForLocalPlayer = IsEnemyKillCinematic(self, results, attack_args)
			if isKillCinematic then
				cameraTac.SetForceMaxZoom(false)
				SetAutoRemoveActionCamera(self, results.killed_units[1], nil, nil, nil, nil, nil, dontPlayForLocalPlayer)
			end
		end
	end

	self:RemoveStatusEffect("FirstThrow")

	-- multi-throw support
	local attacks = results.attacks or {results}
	local ap = (cost_ap and cost_ap > 0) and cost_ap or action:GetAPCost(self, attack_args)
	table.insert(g_CurrentAttackActions, { action = action, cost_ap = ap, attack_args = attack_args, results = results })

	self:PushDestructor(function(self)
		self:ForEachAttach("GrenadeVisual", DoneObject)
		table.remove(g_CurrentAttackActions)
		self.last_attack_session_id = false
		local dlg = GetInGameInterfaceModeDlg()
		if dlg and dlg:HasMember("dont_return_camera_on_close") then
			dlg.dont_return_camera_on_close = true
		end
	end)

	-- throw anim
	self:SetState("gr_Standing_Attack", const.eKeepComponentTargets)
	-- pre-create visual objs and play activate fx 
	local visual_objs = {}
	for i = 1, #attacks do
		local visual_obj = grenade:GetVisualObj(self, i > 1)
		visual_objs[i] = visual_obj
		PlayFX("GrenadeActivate", "start", visual_obj)
	end
	local time_to_hit = self:TimeToMoment(1, "hit") or 20
	self:Face(target_pos, time_to_hit/2)
	Sleep(time_to_hit)

	if results.miss or not results.killed_units or not (#results.killed_units > 1) then
		local specialNadeVr = table.find(SpecialGrenades, grenade.class) and (IsMerc(self) and "SpecialThrowGrenade" or "AIThrowGrenadeSpecial")
		local standardNadeVr = IsMerc(self) and "ThrowGrenade" or "AIThrowGrenade"
		PlayVoiceResponse(self, specialNadeVr or standardNadeVr)
	end

	local thread = CreateGameTimeThread(function()
		-- create visuals and start anim thread for each throw
		local threads = {}
		for i, attack in ipairs(attacks) do
			visual_objs[i]:Detach()
			visual_objs[i]:SetHierarchyEnumFlags(const.efVisible)
			local trajectory = attack.trajectory
			if #trajectory > 0 then
				local rpm_range = const.Combat.GrenadeMaxRPM - const.Combat.GrenadeMinRPM
				local rpm = const.Combat.GrenadeMinRPM + self:Random(rpm_range)
				local rotation_axis = RotateAxis(axis_x, axis_z, CalcOrientation(trajectory[2].pos, trajectory[1].pos))
				threads[i] = CreateGameTimeThread(AnimateThrowTrajectory, visual_objs[i], trajectory, rotation_axis, rpm, "GrenadeDrop")
			else
				-- try to find a fall down pos
				threads[i] = CreateGameTimeThread(ItemFallDown, visual_objs[i])
			end
		end
		grenade:OnThrow(self, visual_objs)
		-- wait until all threads are done
		while #threads > 0 do
			Sleep(25)
			for i = #threads, 1, -1 do
				if not IsValidThread(threads[i]) then
					table.remove(threads, i)
				end
			end
		end
		-- real check when the grenade(s) landed must use the current position(s)
		if #attacks > 1 then
			args.explosion_pos = {}
			for i, res in ipairs(attacks) do
				args.explosion_pos[i] = res.explosion_pos
			end
		else
			args.explosion_pos = results.explosion_pos
		end
		results, attack_args = action:GetActionResults(self, args) 
		local attacks = results.attacks or {results}
		
		results.attack_from_stealth = stealth_attack
		
		-- needs to be after GetActionResults
		local destroy_grenade
		if not self.infinite_ammo then
			grenade.Amount = grenade.Amount - #attacks
			destroy_grenade = grenade.Amount <= 0
			if destroy_grenade then
				local slot = self:GetItemSlot(grenade)
				self:RemoveItem(slot, grenade)
			end
			ObjModified(self)
		end
		
		self:AttackReveal(action, attack_args, results)

		self:OnAttack(action_id, nil, results, attack_args)
		LogAttack(action, attack_args, results)
		for i, attack in ipairs(attacks) do
			grenade:OnLand(self, attack, visual_objs[i])
		end
		if destroy_grenade then
			DoneObject(grenade)
		end
		AttackReaction(action, attack_args, results)
		Msg(CurrentThread())
	end)

	Sleep(self:TimeToAnimEnd())
	self:SetRandomAnim(self:GetIdleBaseAnim())
	if IsValidThread(thread) then
		WaitMsg(thread)
	end
	self:ProvokeOpportunityAttacks("attack reaction")
	self:PopAndCallDestructor()
end

function Unit:RemoteDetonate(action_id, cost_ap, args)
	local target_pos = args.target
	local action = CombatActions[action_id]
	local detonator = action:GetAttackWeapons(self)
	local traps = detonator:GetAttackResults(false, { target_pos = target_pos })
	for i, t in ipairs(traps) do
		t.obj:TriggerTrap(nil, self)
	end
end

function Unit:FaceAttackerCommand(attacker, angle)
	angle = angle or CalcOrientation(self, attacker)
	self:AnimatedRotation(angle)
	self:SetRandomAnim(self:GetIdleBaseAnim(), const.eKeepComponentTargets)
	self:SetCommand("WaitAttacker")
end

function Unit:WaitAttacker(timeout)
	Sleep(timeout or 2000)
end

function Unit:MeleeAttack(action_id, cost_ap, args)
	self:EndInterruptableMovement()

	local new_stance = self.stance ~= "Standing" and self.species == "Human" and "Standing"
	local stealth_attack = not not self:GetStatusEffect("Hidden")
	if new_stance then
		local stance = self.stance
		self:PushDestructor(function(self)
			self:GainAP(cost_ap)
			self:ChangeStance(nil, nil, stance)
		end)
		if new_stance then
			self:ChangeStance(nil, nil, "Standing")
		end
		self:PopDestructor()
	end
	local action = CombatActions[action_id]
	local weapon = action:GetAttackWeapons(self)
	local target = args.target
	if IsKindOf(target, "Unit") and not IsMeleeRangeTarget(self, nil, self.stance, target, nil, target.stance) then
		self:GainAP(cost_ap)
		ShowBadgeOfAttacker(self, false)
		return
	end

	-- do the attack/crit rolls
	args.attack_roll = 1 + self:Random(100)
	args.crit_roll = 1 + self:Random(100)
	if action.StealthAttack then
		args.stealth_attack = stealth_attack
		args.stealth_kill_roll = 1 + self:Random(100)
	end
	args.prediction = false

	self:PushDestructor(function(self)
		table.remove(g_CurrentAttackActions)
		if IsValid(target) and (target.command == "WaitAttacker" or target.command == "FaceAttackerCommand") then
			target:SetCommand("Idle")
		end
	end)

	local results, attack_args = action:GetActionResults(self, args)
	results.attack_from_stealth = stealth_attack
	local ap = (cost_ap and cost_ap > 0) and cost_ap or action:GetAPCost(self, attack_args)
	table.insert(g_CurrentAttackActions, { action = action, cost_ap = ap, attack_args = attack_args, results = results })
	self:AttackReveal(action, attack_args, results)
	self.marked_target_attack_args = nil

	if not HasPerk(self, "HardBlow") then
		self:ProvokeOpportunityAttacks("attack interrupt", nil, "melee")
	end
	
	-- camera effects 
	if not attack_args.opportunity_attack_type == "Retaliation" then
		if g_Combat and IsEnemyKill(self, results) then
			g_Combat:CheckPendingEnd(results.killed_units)
			--cameraTac.SetForceMaxZoom(false)
			--SetAutoRemoveActionCamera(self, results.killed_units[1], 1000)
		end
		if IsKindOf(target, "Unit") and IsCinematicAttack(self, results, attack_args, action) then
			SetAutoRemoveActionCamera(self, target, false, false, false, default_interpolation_time)
		end
	end

	local anim, face_angle, fx_actor
	if self.species == "Human" then
		local base_anim
		if self.infected then
			fx_actor = "fist"
			base_anim = "inf_Standing_Attack"
		else
			local BodyParts = UnitColliders[target.species].BodyParts
			local idx = table.find(BodyParts, "id", attack_args.target_spot_group)
			if not idx then
				if attack_args.target_spot_group == "Neck" then
					idx = table.find(BodyParts, "id", "Head")
				end
			end
			local spot_relative_z
			local target_spot = idx and BodyParts[idx].TargetSpots[1]
			if target_spot and target:HasSpot(target_spot) then
				local spot_pos = target:GetSpotLocPos(target:GetSpotBeginIndex(target_spot))
				local aposx, aposy, aposz = self:GetPosXYZ()
				spot_relative_z = spot_pos:z() - (aposz or terrain.GetHeight(aposx, aposy))
			end
			local attach_forward = not spot_relative_z or spot_relative_z >= 700
			if weapon.IsUnarmed then
				fx_actor = "fist"
				base_anim = attach_forward and "nw_Standing_Attack_Forward" or "nw_Standing_Attack_Down"
			else
				fx_actor = "knife"
				if IsKindOf(weapon, "MacheteWeapon") then
					fx_actor = "machete"
					base_anim = attach_forward and "mk_Standing_Machete_Attack_Forward" or "mk_Standing_Machete_Attack_Down"
				else
					base_anim = attach_forward and "mk_Standing_Attack_Forward" or "mk_Standing_Attack_Down"
				end
			end
		end
		anim = self:GetRandomAnim(base_anim)
		face_angle = CalcOrientation(self, target)
	else
		anim = "attack"
		fx_actor = "jaws"
		local can_attack
		can_attack, face_angle = IsMeleeRangeTarget(self, nil, self.stance, target, nil, target.stance)
		if self.species == "Crocodile" then
			local head_pos = SnapToVoxel(RotateRadius(const.SlabSizeX, face_angle, self))
			local adiff = AngleDiff(CalcOrientation(head_pos, target), face_angle)
			local variant = Clamp(4 + adiff/(45*60), 1, 7)
			if variant > 1 then
				anim = anim .. variant
			end
		end
	end
	if face_angle then
		if self.body_type == "Large animal" then
			self:AnimatedRotation(face_angle)
		else
			self:SetOrientationAngle(face_angle, 100)
		end
	end

	-- target face attacker
	if g_Combat
		and action_id ~= "Charge"
		and not args.opportunity_attack
		and IsKindOf(target, "Unit")
		and not target:IsDead()
		and target.stance ~= "Prone"
		and not target:IsDowned()
		and not target:HasStatusEffect("ManningEmplacement")
	then
		local target_face_angle
		if target.body_type == "Large animal" then
			if abs(target:AngleToObject(self)) > 90*60 then
				target_face_angle = target:GetAngle() + 180*60
			end
		else
			local target_angle = CalcOrientation(target, self)
			if abs(AngleDiff(target_angle, target:GetOrientationAngle())) > 45*60 then
				target_face_angle = target_angle
			end
		end
		if target_face_angle then
			if target:IsCommandThread() then
				local speed_mod = target:GetAnimSpeedModifier()
				target:SetAnimSpeedModifier(1000) -- restore the move speed modified in Unit:InterruptBegin()
				target:AnimatedRotation(target_face_angle)
				target:SetAnimSpeedModifier(speed_mod)
			else
				if target:IsInterruptable() then
					self:SetRandomAnim(self:GetIdleBaseAnim())
					target:SetCommand("FaceAttackerCommand", self, target_face_angle)
					for i = 1, 200 do
						if target.command ~= "FaceAttackerCommand" then
							break
						end
						Sleep(50)
					end
				end
			end
		end
	end
	
	if g_AIExecutionController and not ActionCameraPlaying then
		local targetPos = target:GetVisualPos()
		local cameraIsNear = DoPointsFitScreen({targetPos}, nil, const.Camera.BufferSizeNoCameraMov)
		if not cameraIsNear then
			AdjustCombatCamera("set", nil, targetPos, GetFloorOfPos(SnapToPassSlab(targetPos)), nil, "NoFitCheck")
		end
	end
	
	--handle badges as melee doesn't use prepare to attack logic
	if not g_AITurnContours[self.handle] and g_Combat and g_AIExecutionController then
		local enemy = self.team.side == "enemy1" or self.team.side == "enemy2" or self.team.side == "neutralEnemy"
		g_AITurnContours[self.handle] = SpawnUnitContour(self, enemy and "CombatEnemy" or "CombatAlly")
		ShowBadgeOfAttacker(self, true)
	end	
	ShowBadgesOfTargets({target}, "show")

	self:SetAnim(1, anim)
	local fx_target
	if IsKindOf(target, "Unit") then
		fx_target = target 
	elseif IsValid(target) then
		fx_target = GetObjMaterial(target:GetPos(), target) or target
	elseif IsPoint(target) then
		fx_target = GetObjMaterial(target) or "air"
	end
	PlayFX("MeleeAttack", "start", fx_actor, fx_target, self:GetVisualPos())

	local tth = self:TimeToMoment(1, "hit") or (self:TimeToAnimEnd() / 2)
	repeat
		Sleep(tth)
		tth = self:TimeToMoment(1, "hit", 2)
		if tth and not results.miss and IsKindOf(target, "Unit") then
			target:Pain()
		end
	until not tth

	local attack_roll= results.attack_roll
	local roll = type(attack_roll) == "number" and attack_roll or type(attack_roll) == "table" and Untranslated(table.concat(attack_roll, ", ")) or nil

	if results.miss then
		CreateFloatingText(target, T(699485992722, "Miss"), "FloatingTextMiss")
		PlayFX("MeleeAttack", "miss", fx_actor, false, self:GetVisualPos())
	else
		local resolve_steroid_punch = action_id == "SteroidPunch" and IsValidTarget(target) and IsKindOf(target, "Unit")
		for _, hit in ipairs(results) do
			local obj = hit.obj
			if IsValid(obj) and not obj:IsDead() and hit.damage > 0 then
				if IsKindOf(obj, "Unit") then
					obj:ApplyDamageAndEffects(self, hit.damage, hit, hit.armor_decay)
				else
					obj:TakeDamage(hit.damage, self, hit)
				end
			end
		end
		PlayFX("MeleeAttack", "hit", fx_actor, fx_target, IsValid(target) and target:GetVisualPos() or self:GetVisualPos())
		if resolve_steroid_punch then
			self:ResolveSteroidPunch(args, results)
		end
	end

	self:OnAttack(action_id, target, results, attack_args)

	Sleep(self:TimeToAnimEnd())

	LogAttack(action, attack_args, results)
	if not HasPerk(self, "HardBlow") then
		self:ProvokeOpportunityAttacks("attack reaction", nil, "melee")
	end	
	AttackReaction(action, attack_args, results, "can retaliate")
	ShowBadgesOfTargets({target}, "hide")

	if IsValid(target) then
		ObjModified(target)
	end

	self.last_attack_session_id = false
	self:PopAndCallDestructor()
end

function Unit:ExplodingPalm(action_id, cost_ap, args)
	return self:MeleeAttack(action_id, cost_ap, args)
end

function Unit:GetNumBrutalizeAttacks(goto_pos)
	local ap = self:GetUIActionPoints()
	if goto_pos then
		local cp = GetCombatPath(self)
		local cost = cp and cp:GetAP(goto_pos) or 0
		ap = Min(self:GetUIActionPoints(), self.ActionPoints - cost)
	end
	
	local action = self:GetDefaultAttackAction()
	local base_cost = action:GetAPCost(self)
	local num = 3
	if base_cost then
		num = ap / MulDivRound(base_cost, 66, 100)
	end
	return Max(3, num)
end

function Unit:Brutalize(action_id, cost_ap, args)
	local target = args.target
	if not IsKindOf(target, "Unit") then return end
	
	local action = CombatActions[action_id]
	local weapon = action:GetAttackWeapons(self)
	if not IsKindOf(weapon, "MeleeWeapon") then return end
	
	local bodyParts = target:GetBodyParts(weapon)
	local num_attacks = args.num_attacks or 3
	
	for i = 1, num_attacks do
		local bodyPart = table.interaction_rand(bodyParts, "Combat")
		
		args.target_spot_group = bodyPart.id
		args.target_spot_group = bodyPart.id
		self:MeleeAttack(action_id, 0, args)
		if not IsValid(self) or self:IsIncapacitated() or not IsValidTarget(target) then
			break
		end
	end
	local target = args.target
	if IsKindOf(target, "Unit") and IsValidTarget(target) then
		target:AddStatusEffect("Exposed")
	end
	self.ActionPoints = 0
	if self:IsLocalPlayerControlled() then
		GetInGameInterfaceModeDlg():NextUnit(self.team, "force")
	end
end

function Unit:MarkTarget(action_id, cost_ap, attack_args)
	--for _, unit in ipairs(g_Units) do
		--unit.marked_target_attack_args = nil
	--end
	if not g_Combat then 
		self.marked_target_attack_args = attack_args
		ShowSneakModeTutorialPopup(self)
		ShowSneakApproachTutorialPopup(self)
		local target = attack_args.target
		CreateBadgeFromPreset("MarkedBadge", target, target)
	end
end

function Unit:CancelMark()
	self.marked_target_attack_args = nil
end

function Unit:IsMarkedForStealthAttack(attacker)
	for _, unit in ipairs(g_Units) do
		if unit ~= self and unit.marked_target_attack_args and unit.marked_target_attack_args.target == self then
			if (not attacker) or (attacker == unit) then
				return true
			end
		end
	end
end

function Unit:ThrowKnife(action_id, cost_ap, args)
	local target = args.target
	if not IsPoint(target) and not IsValidTarget(target) then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end

	local action = CombatActions[action_id]

	if action.StealthAttack then
		args.stealth_kill_roll = 1 + self:Random(100)
	end
	args.prediction = false

	local results, attack_args = action:GetActionResults(self, args)

	self:ExecKnifeThrow(action, cost_ap, attack_args, results)
end

function Unit:ExecKnifeThrow(action, cost_ap, attack_args, results)
	self:EndInterruptableMovement()

	local target = attack_args.target
	local target_unit = IsKindOf(target, "Unit") and IsValidTarget(target) and target
	local target_pos = IsPoint(target) and target or target:GetPos()

	results.attack_from_stealth = not not self:HasStatusEffect("Hidden")
	self:AttackReveal(action, attack_args, results)
	self:ProvokeOpportunityAttacks("attack interrupt")
	if self.stance == "Prone" then
		self:DoChangeStance("Standing")
	end
	self:PrepareToAttack(attack_args, results)
	self:ProvokeOpportunityAttacks("attack interrupt")

	-- animation
	local weapon = action:GetAttackWeapons(self)
	self:PushDestructor(function(self)
		self:AttachActionWeapon(action)
		local visual_obj = self.custom_weapon_attach or weapon:GetVisualObj(self)

		-- camera effects
		if g_Combat and IsEnemyKill(self, results) then
			g_Combat:CheckPendingEnd(results.killed_units)
			local target
			for _, unit in ipairs(results.killed_units) do
				if unit ~= self then
					target = unit
					break
				end
			end
			local isKillCinematic, dontPlayForLocalPlayer = IsEnemyKillCinematic(self, results, attack_args)
			if target and isKillCinematic then
				cameraTac.SetForceMaxZoom(false)
				SetAutoRemoveActionCamera(self, target, nil, nil, nil, nil, nil, dontPlayForLocalPlayer)
			end
		end

		-- throw anim
		self:SetState("mk_Standing_Fire", const.eKeepComponentTargets)
		local time_to_hit = self:TimeToMoment(1, "hit") or 20
		self:Face(target_pos, time_to_hit/2)
		Sleep(time_to_hit)
		
		-- grenade trajectory
		--local weapon_pos = visual_obj:GetSpotLocPos()
		local visual_attach_spot = visual_obj:GetAttachSpot()
		local visual_attach_parent = visual_obj:GetParent()
		local start_pos, start_angle, start_axis = visual_obj:GetSpotLoc(-1)
		visual_obj:Detach()
		visual_obj:SetPos(start_pos)
		visual_obj:SetAxisAngle(start_axis, start_angle, 0)

		--visual_obj:SetPos(weapon_pos)
		PlayFX("ThrowKnife", "start", visual_obj)
		
		local trajectory = results.trajectory
		local throw_thread
		if #trajectory > 0 then
			local rotation_axis = RotateAxis(axis_y, axis_z, CalcOrientation(trajectory[2].pos, trajectory[1].pos))
			local rpm_range = const.Combat.KnifeMaxRPM - const.Combat.KnifeMinRPM
			local rpm = const.Combat.KnifeMinRPM + self:Random(rpm_range)
			throw_thread = CreateGameTimeThread(AnimateThrowTrajectory, visual_obj, trajectory, rotation_axis, -rpm)
		end
					
		while IsValidThread(throw_thread) do
			Sleep(20)
		end

		if self:IsMerc() and not self:HasStatusEffect("HundredKnives") then
			-- move the item to the proper container (unit or otherwise)
			local container = target
			if results.miss or not IsKindOf(target, "Unit") or not target:CanAddItem("Inventory", weapon) then
				local drop_pos = terrain.FindPassable(visual_obj, 0, -1, -1, const.pfmVoxelAligned)
				container = GetDropContainer(self, drop_pos)
			end
			
			local slot = self:GetItemSlot(weapon)
			local thrownKnife = weapon:SplitStack(1, "splitIfEqual")
			assert(thrownKnife)
			
			if container then
				thrownKnife.drop_chance = 100 -- make sure the weapon will be properly dropped as loot once the enemy dies
				AddItemsToInventory(container, {thrownKnife})
			end
			
			local item_class = weapon.class
			local spare
			
			self:ForEachItemInSlot("Inventory", item_class, function(item)
				if item.class == item_class then
					spare = item
					return "break"
				end
			end)
			if slot and spare then
				if weapon:MergeStack(spare) then
					self:RemoveItem("Inventory", spare)
					DoneObject(spare)
				end
			end
			
			if slot and weapon.Amount <= 0 then
				self:RemoveItem(slot, weapon)
				DoneObject(weapon)
			end
			
			self:FlushCombatCache()
			self:RecalcUIActions()
			ObjModified(self)
			ObjModified(container)
			
			if IsValid(visual_obj) then
				DoneObject(visual_obj)
			end
			self:UpdateOutfit()
		else
			if IsValid(visual_obj) and IsValid(visual_attach_parent) then
				visual_attach_parent:Attach(visual_obj, visual_attach_spot)
			else
				DoneObject(visual_obj)
				weapon:GetVisualObj(self) -- recreate
			end
		end

		if results.miss then
			CreateFloatingText(target, T(699485992722, "Miss"), "FloatingTextMiss")
		else
		
			for _, hit in ipairs(results) do
				if IsValid(hit.obj) and not hit.obj:IsDead() and hit.damage > 0 then
					if IsKindOf(hit.obj, "Unit") then
						hit.obj:ApplyDamageAndEffects(self, hit.damage, hit, hit.armor_decay)
					else
						hit.obj:TakeDamage(hit.damage, self, hit)
					end
				end
			end
			local fx_actor = "knife"
			PlayFX("MeleeAttack", "hit", fx_actor, self:GetVisualPos())
		end
				
		self:OnAttack(action.id, target, results, attack_args)
		
		LogAttack(action, attack_args, results)
		AttackReaction(action, attack_args, results, "can retaliate")

		if not attack_args.keep_ui_mode then
			SetInGameInterfaceMode("IModeCombatMovement") -- revert to movement mode first to avoid having attack modes try to do stuff with a missing weapon
		end	
		
		
		self:ProvokeOpportunityAttacks("attack reaction")

		self.last_attack_session_id = false
		table.remove(g_CurrentAttackActions)
	end)
	local ap = (cost_ap and cost_ap > 0) and cost_ap or action:GetAPCost(self, attack_args)
	table.insert(g_CurrentAttackActions, { action = action, cost_ap = ap, attack_args = attack_args, results = results })
	
	self:RemoveStatusEffect("FirstThrow")
	self:PopAndCallDestructor()	
end

function Unit:UpdateBandageConsistency()
	if self:HasStatusEffect("BeingBandaged") then
		local medic
		for _, unit in ipairs(g_Units) do
			if unit:GetBandageTarget() == self then
				return
			end
		end
		self:RemoveStatusEffect("BeingBandaged")
	end

	if self:HasStatusEffect("BandageInCombat") then
		local patient = self:GetBandageTarget()
		if not patient or not patient:HasStatusEffect("BeingBandaged") then
			self:RemoveStatusEffect("BandageInCombat")
		end
	end
end

function Unit:Bandage(action_id, cost_ap, args)
	local goto_ap = args.goto_ap or 0
	local action_cost = cost_ap - goto_ap
	local pos = args.goto_pos
	local target = args.target
	local sat_view = args.sat_view or false -- in sat_view form inventory, skip all sleeps and anims
	local target_self = target == self
	
	if g_Combat then
		if goto_ap > 0 then
			self:PushDestructor(function(self)
				self:GainAP(action_cost)
			end)
			local result = self:CombatGoto(action_id, goto_ap, args.goto_pos)
			self:PopDestructor()
			if not result then
				self:GainAP(action_cost)
				return
			end
		end
	elseif not target_self then
		self:GotoSlab(pos)
	end
	
	local myVoxel = SnapToPassSlab(self:GetPos())
	if pos and myVoxel:Dist(pos) ~= 0 then
		if self.behavior == "Bandage" then
			self:SetBehavior()
		end
		if self.combat_behavior == "Bandage" then
			self:SetCombatBehavior()
		end
		self:GainAP(action_cost)
		return
	end
	local action = CombatActions[action_id]
	local medicine = GetUnitEquippedMedicine(self)
	if not medicine then
		if self.behavior == "Bandage" then
			self:SetBehavior()
		end
		if self.combat_behavior == "Bandage" then
			self:SetCombatBehavior()
		end
		self:GainAP(action_cost)
		return
	end
	
	self:SetBehavior("Bandage", {action_id, cost_ap, args})
	self:SetCombatBehavior("Bandage", {action_id, cost_ap, args})

	if not target_self then
		self:Face(target, 200)
		Sleep(200)
	end

	if not sat_view then
		if self.stance ~= "Crouch" then
			self:ChangeStance(false, 0, "Crouch")
		end
		
		if target_self then
			self:SetState("nw_Bandaging_Self_Start")
			Sleep(self:TimeToAnimEnd() or 100)
			self:ProvokeOpportunityAttacks("attack interrupt")	
			self:SetState("nw_Bandaging_Self_Idle")
		else
			self:SetState("nw_Bandaging_Start")
			Sleep(self:TimeToAnimEnd() or 100)
			self:ProvokeOpportunityAttacks("attack interrupt")	
			self:SetState("nw_Bandaging_Idle")
		end
		
		if not g_Combat and not GetMercInventoryDlg() then
			SetInGameInterfaceMode("IModeExploration")
		end
	elseif not g_Combat then
		-- insta-heal in sat view
		while IsValid(target) and not target:IsDead() and target.HitPoints < target.MaxHitPoints and medicine.Condition > 0 do
			target:GetBandaged(medicine, self)
		end
	end

	self:SetCommand("CombatBandage", target, medicine)
end

function Unit:IsBeingBandaged()
	for _, unit in ipairs(g_Units) do
		if unit:GetBandageTarget() == self then
			return true
		end
	end
end

function Unit:GetBandageTarget()
	if self.combat_behavior == "Bandage" and not self:IsDead() then
		local args = self.combat_behavior_params[3]
		return args.target
	end
end

function Unit:GetBandageMedicine()
	if self.combat_behavior == "Bandage" and not self:IsDead() then
		return GetUnitEquippedMedicine(self)
	end
end

function Unit:CombatBandage(target, medicine)
	target:AddStatusEffect("BeingBandaged")
	ObjModified(target)
	if IsValid(target) then
		self:Face(target, 0)
	end

	if g_Combat then
		-- play anim, etc
		local heal_anim 
		if self == target then
			heal_anim = "nw_Bandaging_Self_Idle"
		else
			heal_anim = "nw_Bandaging_Idle"
			PlayVoiceResponse(self, "BandageDownedUnit")
		end
		self:SetState(heal_anim, const.eKeepComponentTargets)
		self:AddStatusEffect("BandageInCombat")
		if not GetMercInventoryDlg() then
			SetInGameInterfaceMode("IModeCombatMovement")
		end

		Halt()
	else
		self:PushDestructor(function()
			self:SetCombatBehavior()
			self:SetBehavior()
			self:RemoveStatusEffect("BandageInCombat")
			target:RemoveStatusEffect("BeingBandaged")
			ObjModified(target)
			ObjModified(self)
		end)
		self:AddStatusEffect("BandageInCombat")
		while IsValid(target) and not target:IsDead() and (target.HitPoints < target.MaxHitPoints or target:HasStatusEffect("Bleeding")) and medicine.Condition > 0 do
			Sleep(5000)
			target:GetBandaged(medicine, self)
		end
		self:SetState("nw_Bandaging_End")
		Sleep(self:TimeToAnimEnd() or 100)
		self:PopAndCallDestructor()
	end
end

function Unit:EndCombatBandage(no_ui_update, instant)
	local target = self:GetBandageTarget()
	self:RemoveStatusEffect("BandageInCombat")
	ObjModified(self)
	if IsValid(target) then
		target:RemoveStatusEffect("BeingBandaged")
		ObjModified(target)
	end
	
	local normal_anim = self:TryGetActionAnim("Idle", self.stance)
	if not instant then
		self:PlayTransitionAnims(normal_anim)
	end
	self:SetCombatBehavior()
	self:SetBehavior()
	if not no_ui_update and ((self == SelectedObj or target == SelectedObj)) and g_Combat then
		SetInGameInterfaceMode("IModeCombatMovement") -- force update to redraw the combat path areas now that movement is allowed
	end

	if self.command == "EndCombatBandage" then
		self:SetCommand("Idle")
	end
end

function OnMsg.UnitMovementStart(unit)
	for _, u in ipairs(g_Units) do
		if u:GetBandageTarget() == unit then
			u:SetCommand("EndCombatBandage", "no update")
		end
	end
end

function Unit:DownedRally(medic, medicine)	
	self:SetCombatBehavior()
	self:RemoveStatusEffect("Stabilized")
	self:RemoveStatusEffect("BleedingOut")
	self:RemoveStatusEffect("Unconscious")
	self:RemoveStatusEffect("Downed")
	self:SetTired(Min(self.Tiredness, 2))
	self.downed_check_penalty = 0
	if medic then
		if medicine then
			medicine.Condition = medicine.Condition - CombatActions.Bandage:ResolveValue("ReviveConditionLoss")
		end
		self:GetBandaged(medicine, medic)
		local slot = medic:GetItemSlot(medicine)
		if slot and medicine.Condition <= 0 then
			CombatLog("short", T{831717454393, "<merc>'s <item> has been depleted", merc = medic.Nick, item = medicine.DisplayName})
			medic:RemoveItem(slot, medicine)
			DoneObject(medicine)
		end
		medic:SetCommand("EndCombatBandage")
	else
		-- still check if another unit is tending to us
		for _, unit in ipairs(self.team.units) do
			if unit:GetBandageTarget() == self then
				unit:SetCommand("EndCombatBandage")
			end
		end
	end
	
	local stance = self.immortal and "Standing" or self.stance
	self.stance = stance
	
	local normal_anim = self:TryGetActionAnim("Idle", self.stance)
	self:PlayTransitionAnims(normal_anim)
	if g_Combat then
		self:GainAP(self:GetMaxActionPoints() - self.ActionPoints) -- rally happens at the start of turn, restore to full ap
	end
	self.TempHitPoints = 0
	ObjModified(self)
	ObjModified(self.team)
	ForceUpdateCommonUnitControlUI("recreate")
	CreateFloatingText(self, T(979333850225, "Recovered"))
	PlayFX("UnitDownedRally", "start", self)
	Msg("OnDownedRally", medic, self)
	self:SetCommand("Idle")
end

function Unit:Retaliate(attacker, attack_reason, fnGetAttackAndWeapon)
	if not IsKindOf(attacker, "Unit") or attacker.team ~= g_Teams[g_CurrentTeam] or attacker == self then
		return false
	end
	if self:IsDead() or self:IsDowned() or not self:IsAware() or self:HasPreparedAttack() then
		return false
	end
	
	local retaliated = false
	
	local num_attacks = HasPerk(self, "Killzone") and 2 or 1
	for i = 1, num_attacks do
		local action, weapon
		if fnGetAttackAndWeapon then
			action, weapon = fnGetAttackAndWeapon(self)
		else
			weapon = self:GetActiveWeapons("Firearm")
			if IsKindOf(weapon, "HeavyWeapon") then
				weapon = nil
			else				
				action = self:GetDefaultAttackAction()
			end
		end
		if not weapon or not action or not self:CanAttack(attacker, weapon, action, 0, nil, "skip_ap_check") then
			break
		end
		
		local lof_data = GetLoFData(self, { attacker }, { action_id = action.id })
		if lof_data[1].los == 0 then
			break
		end
		
		if i == 1 then			
			self:SetAttackReason(attack_reason, true)
			attacker:InterruptBegin()
		end
		if IsValidTarget(attacker) then
			retaliated = true
			self:QueueCommand("RetaliationAttack", attacker, false, action)
			while not self:IsIdleCommand() do
				WaitMsg("Idle")
			end
		end
	end
	
	ClearAITurnContours()
	g_Interrupt = true
	
	self:SetAttackReason()
	return retaliated
end

function NetSyncEvents.InvetoryAction_RealoadWeapon(session_id, ap, weapon_args, src_ammo_type)
	local combat_mode = g_Units[session_id] and InventoryIsCombatMode(g_Units[session_id] )
	local unit = (not gv_SatelliteView  or combat_mode) and g_Units[session_id] or gv_UnitData[session_id]
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("session")
	end	
	if combat_mode and ap>0 and unit:UIHasAP(ap) then
		assert(IsKindOf(unit,"Unit"), "Consume AP called for UnitData")
		unit:ConsumeAP(ap, "Reload")
	end	
	
	local weapon = g_ItemIdToItem[weapon_args.item_id]
	assert(weapon)
	unit:ReloadWeapon(weapon, src_ammo_type)
	if combat_mode and gv_SatelliteView then
		unit:SyncWithSession("map")
	end	
	if unit:CanBeControlled() then InventoryUpdate(unit) end
end

function NetSyncEvents.InvetoryAction_UnjamWeapon(session_id, ap, weapon_args)
	local combat_mode = g_Units[session_id] and InventoryIsCombatMode(g_Units[session_id] )
	local unit = (not gv_SatelliteView  or combat_mode) and g_Units[session_id] or gv_UnitData[session_id]
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("session")
	end	
	if combat_mode and ap>0 and unit:UIHasAP(ap) then
		assert(IsKindOf(unit,"Unit"), "Consume AP called for UnitData")
		unit:ConsumeAP(ap, "Unjam")
	end	
	local weapon = g_ItemIdToItem[weapon_args.item_id]
	assert(weapon)
	weapon:Unjam(unit)
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("map")
	end	
	if unit:CanBeControlled() then InventoryUpdate(unit) end
end

function NetSyncEvents.InvetoryAction_SwapWeapon(session_id, ap)
	local combat_mode = g_Units[session_id] and InventoryIsCombatMode(g_Units[session_id] )
	local unit = (not gv_SatelliteView  or combat_mode) and g_Units[session_id] or gv_UnitData[session_id]
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("session")
	end	
	if combat_mode and ap>0 and unit:UIHasAP(ap) then
		assert(IsKindOf(unit,"Unit"), "Consume AP called for UnitData")
		unit:ConsumeAP(ap, "ChangeWeapon")
	end	
	unit:SwapActiveWeapon()
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("map")
	end	
	if unit:CanBeControlled() then InventoryUpdate(unit) end
end

function NetSyncEvents.InvetoryAction_UseItem(session_id, item_id)
	local combat_mode = g_Units[session_id] and InventoryIsCombatMode(g_Units[session_id] )
	local unit = (not gv_SatelliteView  or combat_mode) and g_Units[session_id] or gv_UnitData[session_id]
	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("session")
	end	

	local item = g_ItemIdToItem[item_id]
	if combat_mode then
		unit:ConsumeAP(item.APCost * const.Scale.AP)
	end
	ExecuteEffectList(item.Effects, unit)

	if combat_mode and gv_SatelliteView then 
		unit:SyncWithSession("map")
	end	
	
	if unit:CanBeControlled() then InventoryUpdate(unit) end
end

function Unit:ReloadAction(action_id, cost_ap, args)
	if args.reload_all then
		local _, _, weapons = self:GetActiveWeapons()
		for _, weapon in ipairs(weapons) do
			local ammo = weapon.ammo and weapon.ammo.class
			self:ReloadWeapon(weapon, ammo, args.reload_all)
		end
	else
		local ammo
		if args and args.target then
			ammo = self:GetItem(args.target) 
		end	
		if not ammo then
			local bag = self.Squad and GetSquadBagInventory(self.Squad)
			if bag then
				ammo = bag:GetItem(args.target)
			end
		end
		local weapon = args and args.weapon
		-- Index
		if type(weapon) == "number" then
			local w1, w2, wl = self:GetActiveWeapons()
			weapon = wl[weapon]
		-- Template name or nothing
		else
			weapon = self:GetWeaponByDefIdOrDefault("Firearm", weapon, args and args.pos, args and args.item_id)
		end
		
		self:ReloadWeapon(weapon, ammo, args and args.delayed_fx)
	end
end

function Unit:UnjamWeapon(action_id, cost_ap, args)
	self:ProvokeOpportunityAttacks("attack interrupt")
	local weapon = false
	if args and args.pos then
		weapon = self:GetItemAtPackedPos(args.pos)
	elseif args and args.weapon then
		weapon = self:GetWeaponByDefIdOrDefault("Firearm", args and args.weapon, args and args.pos, args and args.item_id)
	end	
	if weapon then --Inventory Weapon
		weapon:Unjam(self)
	else
		local weapon1, weapon2 = self:GetActiveWeapons()
		if weapon1.jammed and not weapon1:IsCondition("Broken") then
			weapon1:Unjam(self)
		elseif weapon2.jammed and not weapon2:IsCondition("Broken") then
			weapon2:Unjam(self)
		end
	end
end

function Unit:EnterEmplacement(obj, instant)
	local visual = obj.weapon and obj.weapon:GetVisualObj()
	if not visual then return end

	local fire_spot = visual:GetSpotBeginIndex("Unit")
	local fire_pos = visual:GetSpotPos(fire_spot)
	if not instant then
		if self.stance == "Prone" then
			self:DoChangeStance("Standing")
		end
		if not IsCloser(self, fire_pos, const.SlabSizeX/2) then
			self:Goto(fire_pos, "sl")
		end
	end
	self:SetAxis(axis_z)
	self:SetAngle(obj:GetAngle(), instant and 0 or 200)
	self:SetTargetDummy(nil, nil, "hmg_Crouch_Idle", 0, "Crouch")
	self:AddStatusEffect("ManningEmplacement") -- affect weapon holster too

	if instant then
		self:SetPos(fire_pos)
		self:SetState("hmg_Crouch_Idle", 0, 0)
	else
		self:SetState("hmg_Standing_to_Crouch")
		self:SetPos(fire_pos, 500)
		Sleep(self:TimeToAnimEnd())
		self:SetState("hmg_Crouch_Idle")
	end
	if self.stance ~= "Crouch" then
		self.stance = "Crouch"
		Msg("UnitStanceChanged", self)
	end
	self:SetEffectValue("hmg_emplacement", obj.handle)
	self:SetEffectValue("hmg_sector", gv_CurrentSectorId)
	obj.manned_by = self
	obj.weapon.owner = self.session_id
end

function Unit:LeaveEmplacement(instant, exit_combat)
	if not self:HasStatusEffect("ManningEmplacement") then return end
	local handle = self:GetEffectValue("hmg_emplacement")
	local obj = HandleToObject[handle]
	if not obj then return end

	if exit_combat and obj.exploration_manned and self.team.player_enemy then
		-- enemy units manning important emplacements should stay in them
		return
	end

	obj.manned_by = nil

	local exit_pos = not IsPassSlab(self) and SnapToPassSlab(self)
	if instant then
		if exit_pos then
			self:SetPos(exit_pos)
		end
	else
		self:SetAnim(1, "hmg_Crouch_to_Standing")
		if exit_pos then
			Sleep(Max(0, self:TimeToAnimEnd() - 500))
			self:SetPos(exit_pos, 200)
		end
		Sleep(self:TimeToAnimEnd())
	end
	if self.stance ~= "Standing" then
		self.stance = "Standing"
		Msg("UnitStanceChanged", self)
	end
	self:RemoveStatusEffect("ManningEmplacement")
	self:SetEffectValue("hmg_emplacement")
	if obj.weapon then obj.weapon.owner = nil end
	self:InterruptPreparedAttack()
	self:FlushCombatCache()
	self:RecalcUIActions(true)
	self:UpdateOutfit()
	ObjModified(self)
end

function Unit:StartBombard()
	local weapon = self:GetActiveWeapons("Mortar")
	if weapon and self.prepared_bombard_zone then
		weapon:ApplyAmmoUse(self, self.prepared_bombard_zone.num_shots, false, self.prepared_bombard_zone.weapon_condition)
	end
	local fired = self.prepared_bombard_zone.num_shots and self.prepared_bombard_zone.num_shots > 0
	if not fired and self.prepared_bombard_zone then
		DoneObject(self.prepared_bombard_zone)
	end
	self.prepared_bombard_zone = nil
	
	self:SetCombatBehavior()
end

function Unit:ExplorationStartCombatAction(action_id, ap, args)
	local action = CombatActions[action_id]
	if g_Combat or not action then return end
	
	self.ActionPoints = self:GetMaxActionPoints() -- always start combat actions out of combat at max ap
	ap = action:GetAPCost(self, args)
	self:AddStatusEffect("SpentAP")
	self:SetEffectValue("spent_ap", ap)
end

function Unit:LightningReaction()
	if g_Combat and g_Teams[g_Combat.team_playing] == self.team then return end -- Don't proc in your turn
	if self.stance == "Prone" or self:HasStatusEffect("ManningEmplacement") then return end
	if self:HasStatusEffect("LightningReactionCounter") then return end
	
	local proc = HasPerk(self, "LightningReaction")
	if not proc and HasPerk(self, "LightningReactionNPC") then
		local chance = CharacterEffectDefs["LightningReactionNPC"]:ResolveValue("chance")
		local roll = InteractionRand(100, "LightningReaction")
		proc = roll < chance
	end
	
	if proc then
		self:AddStatusEffect("LightningReactionCounter")
		self:SetActionCommand("ChangeStance", nil, nil, "Prone")
		CreateFloatingText(self, T(726050447294, "Lightning Reaction"), nil, nil, true)
		return true
	end
end

-- signature abilities
function Unit:AddSignatureRechargeTime(id, duration, recharge_on_kill)
	if CheatEnabled("SignatureNoCD") then return end
	local recharges = self.signature_recharge or {}
	self.signature_recharge = recharges
	
	if string.match(id, "DoubleToss") then
		id = "DoubleToss"
	end
	
	local idx = recharges[id]
	if not idx then
		idx = #recharges + 1
		recharges[id] = idx
	end
	recharges[idx] = { id = id, expire_campaign_time = Game.CampaignTime + duration, on_kill = recharge_on_kill }
	
	self:RecalcUIActions()
	ObjModified(self)
end

function Unit:GetSignatureRecharge(id)
	if string.match(id, "DoubleToss") then
		id = "DoubleToss"
	end
	local idx = self.signature_recharge and self.signature_recharge[id]
	return idx and self.signature_recharge[idx] or false
end

function Unit:UpdateSignatureRecharges(trigger)
	local recharges = self.signature_recharge or empty_table
	
	for i = #recharges, 1, -1 do
		local recharge = recharges[i]
		if (trigger == "kill" and recharge.on_kill) or (Game.CampaignTime > recharge.expire_campaign_time) then
			local id = recharge.id
			self:RechargeSignature(id)
		end
	end
end

function Unit:RechargeSignature(id)
	local i = self.signature_recharge[id]
	table.remove(self.signature_recharge, i)
	self.signature_recharge[id] = nil
end

function Unit:HasSignatures()
	local perks = self:GetPerks()
	for _, perk in ipairs(perks) do
		if perk.Tier == "Personal" then
			return true
		end
	end
	return false
end

local function UpdateAllRecharges()
	for _, unit in ipairs(g_Units) do
		unit:UpdateSignatureRecharges()
	end
end

OnMsg.SatelliteTick = UpdateAllRecharges

function Unit:Nazdarovya(action_id, cost_ap, args)
	-- restore hp & gain status
	local action = CombatActions[action_id]
	self:ApplyTempHitPoints(action:ResolveValue("tempHp"))
	self:AddStatusEffect("Drunk")

	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
end

function Unit:DoubleToss(action_id, cost_ap, args)
	self:ThrowGrenade(action_id, cost_ap, args)
	local action = CombatActions[action_id]
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime("DoubleToss", const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
end

function Unit:OnMyTarget(action_id, cost_ap, args)
	local action = CombatActions[action_id]
	
	-- find allies who can make an attack, have them make a basic attack at the target (so long as target isn't dead)	
	local fired = {}
	for _, ally in ipairs(self.team.units) do
		if ally ~= self then 
			local attack = ally:OnMyTargetGetAllyAttack(args.target)
			if attack then
				local ap = ally.ActionPoints -- give temporary ap to avoid safeguards that would stop us from firing
				ally.ActionPoints = ally:GetMaxActionPoints()
				
				ally:SetCommand("FirearmAttack", attack.id, 0, args)
				fired[#fired + 1] = ally
				
				ally.ActionPoints = ap
			end
		end
	end
	
	while #fired > 0 do
		Sleep(100)
		for i = #fired, 1, -1 do
			if fired[i]:IsIdleCommand() then
				table.remove(fired, i)
			end
		end		
	end
	
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
	
	SetInGameInterfaceMode("IModeCombatMovement")
end

function Unit:OnMyTargetGetAllyAttack(target)
	local attack = self.command ~= "Downed" and self:GetDefaultAttackAction("ranged")
	local weapon = attack:GetAttackWeapons(self)
	if attack and attack.id ~= "UnarmedAttack" and HasVisibilityTo(self, target) and IsKindOf(weapon, "Firearm") and 
		not IsKindOf(weapon, "HeavyWeapon") and self:CanAttack(target, weapon, attack, nil, nil, "skip_ap_check") then
		return attack
	end
end

function Unit:SteroidPunch(action_id, cost_ap, args)
	self:MeleeAttack(action_id, cost_ap, args)
end

function Unit:ResolveSteroidPunch(args, results)
	local target = args.target
	if target:IsDead() then
		if target.on_die_attacker == self then
			target.on_die_hit_descr = target.on_die_hit_descr or {}
			target.on_die_hit_descr.death_blow = true
			target.on_die_hit_descr.falldown_callback = "SteroidPunchExplosion"
		end
		return
	end
	if target.stance == "Prone" or target:HasStatusEffect("Unconscious") then
		return
	end
	local angle = CalcOrientation(self, target)
	local pushSlabs = CombatActions.SteroidPunch:ResolveValue("pushSlabs")
	local fromPos = GetPassSlab(target) or target:GetPos()
	local curPos = fromPos
	local toPos = fromPos
	local free_slabs = 0
	while free_slabs < pushSlabs + 1 do
		local nextPos = GetPassSlab(RotateRadius((free_slabs + 1) * const.SlabSizeX, angle, fromPos))
		if not nextPos then
			break
		elseif not IsPassSlabStep(curPos, nextPos, const.TunnelTypeWalk) then
			break
		elseif IsOccupiedExploration(nil, nextPos:xyz()) then
			break
		end
		toPos = curPos 
		curPos = nextPos
		free_slabs = free_slabs + 1
	end
	local anim
	local toMove = Max(0, free_slabs - 1)
	angle = angle + 180*60
	if free_slabs > 0 then
		anim = self:GetRandomAnim("civ_KnockDown_B")
	else
		anim = self:GetRandomAnim("civ_KnockDown_OnSpot_B")
		if self.species == "Human" then
			angle = FindProneAngle(self, toPos, angle)
		end
	end
	target:SetCommand("Punched", self, toPos, angle, anim)
end

function SteroidPunchExplosion(attacker, target, pos)
	local mockGrenade = PlaceInventoryItem("SteroidPunchGrenade")
	local ignore_targets = { [attacker] = true, [target] = true }
	ExplosionDamage(attacker, mockGrenade, pos, nil, nil, "disableBurnFx", ignore_targets)
end

function Unit:Punched(attacker, pos, angle, anim)
	anim = anim or "civ_KnockDown_OnSpot_B"
	local hit_moment = self:GetAnimMoment(anim, "hit") or self:GetAnimMoment(anim, "end") or self:GetAnimDuration(anim) - 1
	CreateGameTimeThread(function(delay, target, pos, attacker)
		Sleep(delay)
		SteroidPunchExplosion(attacker, target, pos)
	end, hit_moment, self, pos, attacker)
	if self.species == "Human" then
		self.stance = "Prone"
	end
	self:MovePlayAnim(anim, self:GetPos(), pos, 0, nil, true, angle, nil, nil, nil, true)
end

function Unit:TakeSuppressionFire()
	self:Pain()
	if self.stance ~= "Prone" then
		self:SetActionCommand("ChangeStance", nil, nil, "Prone")
	end
end

function Unit:AlwaysReadyFindCover(enemy)
	-- calc CombatPath with a set amount of AP (70% of max)
	local ap = MulDivRound(self:GetMaxActionPoints(), const.Combat.RepositionAPPercent, 100)
	local path = CombatPath:new()
	local cost_extra = GetStanceToStanceAP("Standing", "Crouch")

	path:RebuildPaths(self, ap)
	local best_ppos, best_score, best_ap, stance, score
	-- find nearest reachable position that has cover from the attacker
	DbgClearVectors()
	for ppos, ap in pairs(path.paths_ap) do		
		local x, y, z = point_unpack(ppos)
		local pos = point(x, y, z)
		local cover, any, coverage = self:GetCoverPercentage(enemy:GetPos(), pos, "Crouch")
		DbgAddVector(point(x, y, z), guim, const.clrGray)

		if cover and cover == const.CoverLow and self.stance == "Standing" and ap < cost_extra then
			DbgAddVector(point(x, y, z), 2*guim, const.clrRed)
			cover = false
		end
		
		if cover then		
			DbgAddVector(point(x, y, z), 2*guim, const.clrYellow)
			score = cover * coverage
						
			if not best_ppos then
				best_ppos, best_score, best_ap, stance = ppos, score, ap
				if cover == const.CoverLow and self.stance == "Standing" then
					stance = "Crouch"
				else
					stance = nil
				end
			elseif score > best_score or (score > MulDivRound(best_score, 90, 100) and ap > best_ap) then
				best_ppos, best_score, best_ap, stance = ppos, score, ap
				if cover == const.CoverLow and self.stance == "Standing" then
					stance = "Crouch"
				else
					stance = nil
				end
			end
		end
	end
end

MapVar("g_AlwaysReadyThread", false)

function Unit:TryActivateAlwaysReady(enemy)
	if IsValidThread(g_AlwaysReadyThread) then
		return
	end
	local cover, any, coverage = self:GetCoverPercentage(enemy:GetPos())
	if cover then
		if cover == const.CoverLow and self.stance == "Standing" then
			-- change stance first to get in the cover
			CancelWaitingActions(-1)
			NetStartCombatAction("StanceCrouch", self, 0)
		end
		return 
	end
	
	-- override standard reposition dest picking logic
	-- calc CombatPath with a set amount of AP (70% of max)
	local ap = MulDivRound(self:GetMaxActionPoints(), const.Combat.RepositionAPPercent, 100)
	local cost_extra = GetStanceToStanceAP("Standing", "Crouch")
	local path = CombatPath:new()
	path:RebuildPaths(self, ap)
	local best_ppos, best_score, best_ap, stance
	-- find nearest reachable position that has cover from the attacker
	for ppos, ap in pairs(path.paths_ap) do		
		local pos = point(point_unpack(ppos))
		local cover, any, coverage = self:GetCoverPercentage(enemy:GetPos(), pos, "Crouch")
		if cover and cover == const.CoverLow and self.stance == "Standing" and ap < cost_extra then
			cover = false
		end
		
		if cover then
			local score = cover * coverage
						
			if not best_ppos then
				best_ppos, best_score, best_ap, stance = ppos, score, ap
				if cover == const.CoverLow and self.stance == "Standing" then
					stance = "Crouch"
				else
					stance = nil
				end
			elseif score > best_score or (score > MulDivRound(best_score, 90, 100) and ap > best_ap) then
				best_ppos, best_score, best_ap, stance = ppos, score, ap
				if cover == const.CoverLow and self.stance == "Standing" then
					stance = "Crouch"
				else
					stance = nil
				end
			end
		end
	end
	if not best_ppos then
		-- no cover available, abort
		CreateFloatingText(self, T(103063369185, "Always Ready: No covers nearby"), "FloatingTextMiss")
		return	
	end
	
	local path_to_dest = path:GetCombatPathFromPos(best_ppos)
	DoneObject(path)
	g_AlwaysReadyThread = CreateGameTimeThread(Unit.ActivateAlwaysReady, self, best_ppos, path_to_dest, stance)
end

function Unit:ActivateAlwaysReady(reposition_dest, reposition_path, stance)
	local controller = CreateAIExecutionController{ -- todo: custom notifications maybe
		label = "AlwaysReady", 
		reposition = true,
		activator = self,
	}		
	
	-- hide AP changes & store current AP to restore them at the end
	-- note: this isn't a command (the execution would override it) so make sure nothing can break in the code below 
		-- as we can't rely on command destructors to restore the state
	local start_ap = self.ActionPoints
	self.ui_override_ap = self:GetUIActionPoints()
	
	-- setup the reposition dest - the controller will not use the default logic with "AlwaysReady" label
	local x, y, z = point_unpack(reposition_dest)
	
	self.reposition_dest = stance_pos_pack(x, y, z, StancesList[stance or self.stance])
	self.reposition_path = reposition_path
	
	-- exec the reposition
	CancelWaitingActions(-1)
	controller.restore_camera_obj = SelectedObj
	g_Combat:SetRepositioned(self, false) -- we can do this more than once
	controller:Execute({self}) -- internally it is sprocall so the code below will execute even if something breaks
	DoneObject(controller)
	
	-- restore ap to their previous value
	self.ActionPoints = start_ap
	self.ui_override_ap = false
	g_AlwaysReadyThread = false
end

function Unit:ChargeAttack(action_id, cost_ap, args)
	self:PushDestructor(function()
		g_TrackingChargeAttacker = false
		self.move_attack_action_id = nil
	end)
	
	--handle badges as melee doesn't use prepare to attack logic
	if not g_AITurnContours[self.handle] and g_Combat and g_AIExecutionController then
		local enemy = self.team.side == "enemy1" or self.team.side == "enemy2" or self.team.side == "neutralEnemy"
		g_AITurnContours[self.handle] = SpawnUnitContour(self, enemy and "CombatEnemy" or "CombatAlly")
		ShowBadgeOfAttacker(self, true)
	end	
	
	--handle camera for charge attack
	ShouldTrackMeleeCharge(self, args.target)
	
	self.move_attack_action_id = action_id
	self:SetCommandParamValue(self.command, "move_anim", "Run")
	if args.goto_pos then
		args.unit_moved = true
		self:CombatGoto(action_id, args.goto_ap or 0, args.goto_pos)
	end
	self:MeleeAttack(action_id, cost_ap, args)
	self:PopAndCallDestructor()
end

function Unit:GloryHogCharge(action_id, cost_ap, args)
	local action = CombatActions[action_id]
	self:ApplyTempHitPoints(action:ResolveValue("tempHp"))
	self:ChargeAttack(action_id, cost_ap, args)
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
end

function Unit:HyenaCharge(action_id, cost_ap, args)
	if self.species ~= "Hyena" then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	
	local target = args.target
	local action = CombatActions[action_id]
	args.prediction = false
	args.unit_moved = true
	local results, attack_args = action:GetActionResults(self, args)	
	local atk_pos, atk_jmp_pos = GetHyenaChargeAttackPosition(self, target, attack_args.move_ap, attack_args.jump_dist, action_id)
	
	if not atk_pos then
		self:GainAP(cost_ap)
		CombatActionInterruped(self)
		return
	end
	
	self:PushDestructor(function()
		g_TrackingChargeAttacker = false
		table.remove(g_CurrentAttackActions)
		self.move_attack_action_id = nil
	end)
	
	--handle badges as melee doesn't use prepare to attack logic
	if not g_AITurnContours[self.handle] and g_Combat and g_AIExecutionController then
		local enemy = self.team.side == "enemy1" or self.team.side == "enemy2" or self.team.side == "neutralEnemy"
		g_AITurnContours[self.handle] = SpawnUnitContour(self, enemy and "CombatEnemy" or "CombatAlly")
		ShowBadgeOfAttacker(self, true)
	end	
	
	--handle camera for charge attack
	ShouldTrackMeleeCharge(self, target)

	self.move_attack_action_id = action_id
	table.insert(g_CurrentAttackActions, { action = action, cost_ap = cost_ap, attack_args = attack_args, results = results })	
	self:AttackReveal(action, attack_args, results)
		
	self:SetCommandParamValue(self.command, "move_anim", "Run")
	self:CombatGoto(action_id, attack_args.move_ap, atk_jmp_pos)
	self:Face(atk_pos)

	if not HasPerk(self, "HardBlow") then
		self:ProvokeOpportunityAttacks("attack interrupt", nil, "melee")
	end
	
	--handle badges as melee doesn't use prepare to attack logic
	ShowBadgesOfTargets({target}, "show")
	
	self:SetState("attack_Charge")
	local fx_actor = "jaws"
	PlayFX("MeleeAttack", "start", fx_actor, self:GetVisualPos())
			
	local tth = self:TimeToMoment(1, "hit") or (self:TimeToAnimEnd() / 2)
	self:SetPos(atk_pos, self:TimeToAnimEnd())
	Sleep(tth)
		
	if results.miss then
		CreateFloatingText(target, T(699485992722, "Miss"), "FloatingTextMiss")
	else
		for _, hit in ipairs(results) do
			if IsValid(hit.obj) and not hit.obj:IsDead() and hit.damage > 0 then
				if IsKindOf(hit.obj, "Unit") then
					hit.obj:ApplyDamageAndEffects(self, hit.damage, hit, hit.armor_decay)
				else
					hit.obj:TakeDamage(hit.damage, self, hit)
				end
			end
		end
		PlayFX("MeleeAttack", "hit", fx_actor, self:GetVisualPos())
	end

	self:OnAttack(action_id, target, results, attack_args)
	
	Sleep(self:TimeToAnimEnd())

	LogAttack(action, attack_args, results)
	AttackReaction(action, attack_args, results, "can retaliate")
	
	if IsValid(target) then
		ObjModified(target)
	end

	self.last_attack_session_id = false
	ShowBadgesOfTargets({target}, "hide")
	self:PopAndCallDestructor()	
end

function Unit:DanceForMe(action_id, cost_ap, args)
	local action = CombatActions[action_id]
	local weapon = self:GetActiveWeapons()
	local aoeParams = weapon:GetAreaAttackParams(action_id, self)
	local attackData = self:ResolveAttackParams(action_id, args.target, {})
	
	local attackerPos = attackData.step_pos
	local attackerPos3D = attackerPos
	if not attackerPos3D:IsValidZ() then
		attackerPos3D = attackerPos3D:SetTerrainZ()
	end
	local targetPos = args.target
	
	local targetAngle = CalcOrientation(attackerPos, targetPos)
	
	local distance = Clamp(attackerPos3D:Dist(targetPos), aoeParams.min_range * const.SlabSizeX, aoeParams.max_range * const.SlabSizeX)

	local enemies = GetEnemies(self)
	local maxValue, losValues = CheckLOS(enemies, attackerPos, distance, attackData.stance, aoeParams.cone_angle, targetAngle, false)
	
	if maxValue then
		for i, los in ipairs(losValues) do
			if los then
				local defaultAttack = self:GetDefaultAttackAction("ranged")
				local tempArgs = table.copy(args)
				tempArgs.target = enemies[i]
				tempArgs.target_spot_group = "Legs"
				if defaultAttack and self:CanAttack(tempArgs.target, weapon, defaultAttack, nil, nil, "skip_ap_check") then
					self:FirearmAttack(defaultAttack.id, 0, tempArgs)
				end
			end
		end
	end
	
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
	
	self:SetActionCommand("OverwatchAction", action_id, cost_ap, args)
end

-- attack each body part
function Unit:IceAttack(action_id, cost_ap, args)
	local target = args.target
	if not IsKindOf(target, "Unit") then return end
	
	local action = CombatActions[action_id]
	local weapon = self:GetActiveWeapons()
	
	local bodyParts = target:GetBodyParts(weapon)
	
	for i=#bodyParts, 1, -1 do
		if weapon.ammo.Amount < 1 then break end
		local bodyPart = bodyParts[i]
		args.target_spot_group = bodyPart.id
		args.ice_attack_num = i
		self:FirearmAttack(action_id, 0, args)
	end
	
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
end

-- bypass armor
function Unit:KalynaShot(action_id, cost_ap, args)
	self:FirearmAttack(action_id, 0, args)
	
	local action = CombatActions[action_id]
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
end

function Unit:EyesOnTheBack(action_id, cost_ap, args)
	local action = CombatActions[action_id]	
	
	local recharge_on_kill = action:ResolveValue("recharge_on_kill") or 0
	self:AddSignatureRechargeTime(action_id, const.Combat.SignatureAbilityRechargeTime, recharge_on_kill > 0)
	
	self:SetActionCommand("OverwatchAction", action_id, cost_ap, args)
end

function Unit:BulletHell(action_id, cost_ap, args)
	args.attack_anim_delay = 50
	self:SetActionCommand("FirearmAttack", action_id, cost_ap, args)
end

-- makes the actual bullets do no damage and spreads them in a repeating pattern
function BulletHellOverwriteShots(attack)
	local weapon = attack.weapon
	
	local halfAngle = DivRound(weapon.OverwatchAngle, 2)
	local newAngle = halfAngle
	local angleStep = MulDivRound(weapon.OverwatchAngle, 2, #attack.shots)

	for i, shot in ipairs(attack.shots) do
		shot.target_pos = RotateAxis(shot.target_pos, point(0, 0, 4069) , newAngle, shot.attack_pos)
		shot.stuck_pos = RotateAxis(shot.stuck_pos, point(0, 0, 4069) , newAngle, shot.attack_pos)
		if abs(newAngle) >= halfAngle then
			angleStep = -angleStep
		end
		newAngle = newAngle + angleStep
	end
end

function Unit:GrizzlyPerk(action_id, cost_ap, args)
	self:FirearmAttack(action_id, 0, args)
end