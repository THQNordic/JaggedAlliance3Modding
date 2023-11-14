const.AIDecisionThreshold = 80 -- targets/locations up to this percent of max scored target/location can be selected
const.AIPointBlankTargetMod = 50 -- targets in point-blank range get +50% score

const.AIFallbackWeight_OpenDoor = 100
const.AIFallbackWeight_ClosedDoor = 40
const.AIFallbackWeight_Window = 70

const.AIAvoidFireWeigth = -200
const.AIAvoidGasWeigth = -200
const.AIAvoidBombardEdge = 100 -- % of score retained at the border of the zone
const.AIAvoidBombardCenter = 30 -- % of score retained at the center of the zone

const.AIFriendlyFire_MaxRange = 10 * const.SlabSizeX	-- max range to ally for it to be considered in danger
const.AIFriendlyFire_LOFWidth = 100*guic 					-- max distance from an ally to the line between position and target considered in danger
const.AIFriendlyFire_LOFConeNear = 100*guic 				-- same as above for cone attacks (near side of the cone, positioned at attacker)
const.AIFriendlyFire_LOFConeFar = 300*guic 				-- same as above for cone attacks (far side of the cone, positioned at AIFriendlyFire_MaxRange)
const.AIFriendlyFire_ScoreMod = 50							-- % of damage score evaluation remanining when an ally is in danger

local function CanReload(unit, weapon)
	if not IsKindOf(weapon, "Firearm") then
		return false
	end
	if (weapon.ammo and weapon.ammo.Amount or 0) >= weapon.MagazineSize then
		return false
	end
	if not unit:HasAP(CombatActions["Reload"]:GetAPCost(unit)) then
		return false
	end
	local ammo_type
	if (weapon.ammo and weapon.ammo.Amount or 0) > 0 then
		ammo_type = weapon.ammo.class
	end
	local ammo = unit:GetAvailableAmmos(weapon, ammo_type)
	if not ammo or not ammo[1] then
		return false
	end
	return true
end

function WaitIdle(unit)
	while IsValidTarget(unit) and not unit:IsIdleCommand() do
		WaitMsg("Idle", 200)
	end
end

local remove_action_cam_actions = { Move = true, MeleeAttack = true, ThrowGrenadeA = true, ThrowGrenadeB = true , ThrowGrenadeC = true, ThrowGrenadeD = true}

function AIStartCombatAction(action_id, unit, ap, args, ...)
	if not ap then
		ap = CombatActions[action_id]:GetAPCost(unit, args, ...)
	end
	if not ap or ap < 0 or not unit:HasAP(ap, action_id) then
		return false
	end
	if ActionCameraPlaying then
		local waited
		if CurrentActionCamera.wait_signal then
			waited = true
			WaitMsg("ActionCameraWaitSignalEnd", 2000)
		end
		if remove_action_cam_actions[action_id] and g_Combat and g_Combat:IsVisibleByPoVTeam(unit) and not args.reposition then
			if not waited then
				Sleep(500)
			end
			RemoveActionCamera()
		end
	end
	if args and type(args) == "table" then
		if args.target then
			--HandleCameraTargetFixed(unit, args.target)
			ShowBadgeOfAttacker(unit, true)
		end
		if args.voiceResponse then
			PlayVoiceResponseGroup(unit, args.voiceResponse)
		elseif unit.ai_context and unit.ai_context.movement_action then
			local vr = unit.ai_context.movement_action:GetVoiceResponse()
			if vr then
				PlayVoiceResponseGroup(unit, vr)
			end
		end
	end
	local willBeTracked, visibleMovement
	if action_id == "Move" then
		willBeTracked, visibleMovement = AddToCameraTrackingBehavior(unit, args)
		args.willBeTracked = willBeTracked
		args.visibleMovement = visibleMovement
	end
	StartCombatAction(action_id, unit, ap, args, ...)
	return true
end

function AIPlayCombatAction(action_id, unit, ap, args)
	--[[if args and IsKindOf(args.target, "Unit") then
		printf("%s (%d): %s vs %s", _InternalTranslate(unit.Name or ""), unit.handle, action_id, _InternalTranslate(args.target.Name or ""))
	end--]]
	if not AIStartCombatAction(action_id, unit, ap, args) then
		return false
	end
	WaitCombatActionsPostAction(unit)
	ClearAITurnContours()
	StopCinematicCombatCamera()
	return true
end

function AIStartChangeStance(unit, stance, target_pos)
	if unit.stance == stance then
		return true
	end
	local angle
	if target_pos and target_pos:IsValid() then
		angle = CalcOrientation(unit, target_pos)
	end

	local args = { angle = angle }
	local result
	if stance == "Standing" then
		result = AIStartCombatAction("StanceStanding", unit, nil, args)
	elseif stance == "Crouch" then
		result = AIStartCombatAction("StanceCrouch", unit, nil, args)
	elseif stance == "Prone" then
		result = AIStartCombatAction("StanceProne", unit, nil, args)
	end
	return result or false
end

function AIPlayChangeStance(unit, stance, target_pos)
	if not AIStartChangeStance(unit, stance, target_pos) then
		return false
	end
	WaitCombatActionsPostAction(unit)
	return true
end

MapVar("g_AIDestIndoorsCache", {})
MapVar("g_AISignatureActionModifiers", {})

function AIUpdateContext(context, unit)
	unit = unit or context.unit

	context.unit_pos = GetPassSlab(unit) or context.unit_pos
	context.unit_stance_pos = GetPackedPosAndStance(unit) or context.unit_stance_pos
	context.unit_grid_voxel = point_pack(unit:GetGridCoords())
end

function AIGetIntendedTarget(unit, context)
	context = context or unit.ai_context or empty_table
	local dest = context.ai_destination or GetPackedPosAndStance(unit)

	return (context.dest_target or empty_table)[dest]	
end

function AILockTarget(unit, context)
	context = context or unit.ai_context

	local target = AIGetIntendedTarget(unit, context)
	if target then
		context.target_locked = target
	end	
end

function AIGetAttackTargetingOptions(unit, context, target, action, targeting)
	local body_parts
	targeting = targeting or context.archetype.BaseAttackTargeting
	if IsKindOf(target, "Unit") and targeting then
		action = action or context.default_attack
		local args = { target = target, aim = 0 }
		local parts = target:GetBodyParts(context.weapon)
		local valid, fallback
		for _, part in ipairs(parts) do
			args.target_spot_group = part.id
			local results = action:GetActionResults(unit, args)
			body_parts = body_parts or {}
			results.chance_to_hit = results.chance_to_hit or 0
			table.insert(body_parts, {id = part.id, chance = results.chance_to_hit})
			if results.chance_to_hit > 0 then
				fallback = fallback or {id = part.id, chance = results.chance_to_hit}
				if targeting[part.id] then
					valid = true
				end
			end			
		end
		if not valid then
			table.insert(body_parts, fallback)
		end
	end
	return body_parts
end

function AIPlayAttacks(unit, context, dbg_action, force_or_skip_action)
	-- filter enemies because they might have been killed by a teammate
	if g_AIExecutionController then
		g_AIExecutionController:Log("Unit %s (%d) start attack sequence", unit.unitdatadef_id, unit.handle)
	end
	local enemies = context.enemies
	for i = #enemies, 1, -1 do
		if not IsValidTarget(enemies[i]) then
			table.remove(enemies, i)
		end
	end
	
	local remaining_free_ap = unit.free_move_ap
	unit:RemoveStatusEffect("FreeMove") -- lose any remaining free movement points, we're going to use actions now
	AIUpdateContext(context, unit)

	if g_AIExecutionController then
		g_AIExecutionController:Log("  Num enemies: %d", #enemies)
		g_AIExecutionController:Log("  Action Points: %d", unit.ActionPoints)
	end
	
	local dest = not force_or_skip_action and context.ai_destination or GetPackedPosAndStance(unit)
		
	-- recalc target to make sure we're firing at a valid target, but prefer the already picked target if there's one
	--table.insert(g_AIDamageScoreLog, string.format("[%s] AIPlayAttacks (%s)", _InternalTranslate(unit.Name or ""), context.archetype.id))
	context.dest_ap[dest] = context.dest_ap[dest] or unit.ActionPoints	
	AIPrecalcDamageScore(context, {dest}, context.target_locked or (context.dest_target or empty_table)[dest])

	-- archetype signature actions
	local signature_action
	if dbg_action then
		context.action_states = context.action_states or {}
		context.action_states[dbg_action] = {}
		dbg_action:PrecalcAction(context, context.action_states[dbg_action])
		if dbg_action:IsAvailable(context, context.action_states[dbg_action]) then
			signature_action = dbg_action
		elseif force_or_skip_action then
			table.insert(failed_actions, dbg_action.BiasId or dbg_action.class)
			return
		end
	end
	if not context.reposition and not unit:HasStatusEffect("Numbness") then
		signature_action = signature_action or AIChooseSignatureAction(context)
	end
	
	local default_attack = context.default_attack
	local default_attack_vr = "AIAttack"
	if default_attack and default_attack.FiringModeMember and default_attack.FiringModeMember == "AttackShotgun" then
		default_attack_vr = "AIDoubleBarrel"
	end
	local voice_response = signature_action and (signature_action:GetVoiceResponse() or "") or default_attack_vr
	if voice_response == "" then 
		voice_response = nil
	end
	
	if signature_action then
		if g_AIExecutionController then
			g_AIExecutionController:Log("  Signature Action: %s", signature_action:GetEditorView())
		end
		signature_action:OnActivate(unit)
		--printf("[signature] %s (%d)", _InternalTranslate(unit.Name or ""), unit.handle)
		if voice_response then
			context.action_states[signature_action].args = context.action_states[signature_action].args or {}
			context.action_states[signature_action].args.voiceResponse = voice_response
		end
		local status = signature_action:Execute(context, context.action_states[signature_action])
		context.ap_after_signature = unit.ActionPoints
		if status then -- support signature actions that want to restart or stop ai turn execution
			return status
		end
		AIReloadWeapons(unit)
		context.max_attacks = context.max_attacks - 1
	else
		if g_AIExecutionController then
			g_AIExecutionController:Log("  No Signature Action chosen")
		end
	end

	local target = (context.dest_target or empty_table)[dest]
	if signature_action and (not IsValidTarget(target) or (IsKindOf(target, "Unit") and target:IsIncapacitated())) then
		--table.insert(g_AIDamageScoreLog, string.format("[%s] TargetChange (%s)", _InternalTranslate(unit.Name or ""), context.archetype.TargetChangePolicy))
		if context.archetype.TargetChangePolicy == "restart" then
			return "restart"
		end
		context.dest_ap[dest] = unit.ActionPoints
		context.target_locked = nil
		AIPrecalcDamageScore(context, {dest})
		target = context.dest_target[dest]		
	end

	if IsValidTarget(target) then
		if g_AIExecutionController then
			g_AIExecutionController:Log("  Target: %s", IsKindOf(target, "Unit") and target.unitdatadef_id or target.class)
		end
		-- revert to basic attacks
		local attacks, aim = AICalcAttacksAndAim(context, unit.ActionPoints)
		if context.default_attack.id == "Bombard" and AICheckIndoors(dest) then
			attacks = 0
		end

		local args = { target = target, voiceResponse = voice_response }
		if attacks > 1 then
			unit:SequentialActionsStart()
		end
		if g_AIExecutionController then
			g_AIExecutionController:Log("  Executing %d attacks...", attacks)
		end
		local body_parts = AIGetAttackTargetingOptions(unit, context, target)
		
		for i = 1, attacks do
			args.aim = aim[i]
			args.target_spot_group = nil
			if body_parts and #body_parts > 0 then
				local pick = table.weighted_rand(body_parts, "chance", InteractionRand(1000000, "Combat"))
				if pick then
					args.target_spot_group = pick.id
				end
			end
			Sleep(0)
			local result = AIPlayCombatAction(context.default_attack.id, unit, nil, args)
			context.max_attack = context.max_attacks - 1
			if g_AIExecutionController then
				g_AIExecutionController:Log("  Attack %d result: %s", i, tostring(result))
			end
			if IsSetpiecePlaying() then
				unit:SequentialActionsEnd()
				return
			end
			AIReloadWeapons(unit)
			if not result or i == attacks or not IsValidTarget(unit) or context.max_attacks <= 0 then
				break
			end
			while IsKindOf(target, "Unit") and target:IsGettingDowned() do
				WaitMsg("UnitDowned", 20)
			end
			if not IsValidTarget(target) or (IsKindOf(target, "Unit") and target:IsIncapacitated()) then
				--table.insert(g_AIDamageScoreLog, string.format("[%s] TargetChange (%s)", _InternalTranslate(unit.Name or ""), context.archetype.TargetChangePolicy))
				if context.archetype.TargetChangePolicy == "restart" then
					unit:SequentialActionsEnd()
					return "restart"
				end
				-- look for another target
				context.dest_ap[dest] = unit.ActionPoints
				context.target_locked = nil
				AIPrecalcDamageScore(context, {dest})
				target = context.dest_target[dest]
				if not IsValidTarget(target) then
					break
				end
			end
			Sleep(0)
		end
		unit:SequentialActionsEnd()
	elseif unit:HasStatusEffect("StationedMachineGun") and CombatActions.MGPack:GetUIState({unit}) == "enabled" then
		unit:SequentialActionsEnd()
		AIPlayCombatAction("MGPack", unit)
		return "restart"
	else
		if g_AIExecutionController then
			g_AIExecutionController:Log("  No target")
		end		
	end
	unit:SequentialActionsEnd()
	
	while not unit:IsIdleCommand() do
		WaitMsg("Idle", 50)
	end

	if unit.ActionPoints + remaining_free_ap == context.start_ap and not unit:HasStatusEffect("ManningEmplacement") then
		-- no action was taken, use a fallback one
		-- if all fails, move toward optimal loc
		if context.closest_dest then
			unit:GainAP(remaining_free_ap)
			local dest = context.closest_dest
			local x, y, z, stance_idx = stance_pos_unpack(dest)
			local move_stance_idx = context.dest_combat_path[dest]
			local cpath = context.combat_paths[move_stance_idx]
			local pt = SnapToPassSlab(x, y, z)
			local path = pt and cpath and cpath:GetCombatPathFromPos(pt)
			if path then
				local goto_stance = StancesList[move_stance_idx]
				if goto_stance ~= unit.stance then
					AIPlayChangeStance(unit, goto_stance, point(point_unpack(path[2])))
				end
				local goto_ap = unit.ActionPoints -- context.dest_ap[dest] --cpath.paths_ap[point_pack(x, y, z)] or 0
				context.ai_destination = path[1]
				AIPlayCombatAction("Move", unit, goto_ap, { goto_pos = point(point_unpack(path[1])), fallbackMove = true, goto_stance = stance_idx })
			end
		end
		if unit:GetDist(context.unit_pos) < const.SlabSizeX / 2 then
			local revert = true
			if context.archetype.FallbackAction == "overwatch" then
				-- try to place overwatch
				revert = not AIPlaceFallbackOverwatch(unit, context)
			end
			if revert then
				-- we're stuck somewhere and unable to move or act, revert back to being Unaware (only if no sight of any enemies)
				local sight = false
				for _, enemy in ipairs(context.enemies) do
					sight = sight or HasVisibilityTo(unit, enemy)
				end
				if not sight then
					table.insert(g_UnawareQueue, unit)
				end
			end
		end
	end
end

function AIPlaceFallbackOverwatch(unit, context)
	if not IsKindOf(context.weapon, "Firearm") then
		return false
	end
	if context.weapon.PreparedAttackType ~= "Overwatch" and context.weapon.PreparedAttackType ~= "Both" then
		return false
	end

	local target_pt

	local room = EnumVolumes(unit, "smallest")
	if room then
		-- indoors - overwatch against an open door/window or a closed one if none of them are opened
		local targets = {}
		room:ForEachSpawnedDoor(function(obj)
			local w = (obj.pass_through_state == "open" or obj.pass_through_state == "broken") and const.AIFallbackWeight_OpenDoor or const.AIFallbackWeight_ClosedDoor
			targets[#targets + 1] = { obj = obj, weight = w }
		end)
		room:ForEachSpawnedWindow(function(obj) 
			targets[#targets + 1] = { obj = obj, weight = const.AIFallbackWeight_Window }
		end)
		
		if #targets > 0 then
			local target = table.weighted_rand(targets, "weight", InteractionRand(1000000, "AIDecision"))
			target_pt = target.obj:GetPos()			
		end		
	elseif context.unit.last_known_enemy_pos then
		target_pt = context.unit.last_known_enemy_pos
	else
		-- check for aware teammates that we can see
		local sp = GetPackedPosAndStance(unit)
		local targets = {}
		for _, ally in ipairs(context.allies) do
			if ally ~= context.unit and context.unit:GetDist(ally) < 12 * guim and stance_pos_visibility(sp, context.ally_pack_pos_stance[ally]) then
				-- try to find a point that we can (probably) see in front of our ally
				local v = Rotate(point(guim, 0, 0), ally:GetAngle())
				for i = 6, 1, -1 do
					local tpt = SnapToPassSlab(ally:GetPos() + SetLen(v, i*guim))
					if tpt then
						local x, y, z = tpt:xyz()
						local tsp = stance_pos_pack(x, y, z, StancesList.Standing)
						if stance_pos_visibility(sp, tsp) then
							targets[#targets + 1] = tpt
							break
						end
					end
				end
			end
		end
		
		if #targets == 0 then
			-- target in direction of alive enemy
			local revealed, all = {}, {}
			for _, enemy in ipairs(context.enemies) do
				if IsValidTarget(enemy) then
					all[#all + 1] = enemy
					if not enemy:HasStatusEffect("Hidden") then
						revealed[#revealed + 1] = enemy
					end
				end
			end
			local target_units = #revealed > 0 and revealed or all
			for _, enemy in ipairs(target_units) do
				targets[#targets + 1] = enemy:GetPos() + Rotate(point(InteractionRand(4*guim), 0, 0, InteractionRand(360*60)))
			end
		end
		
		if #targets > 0 then
			target_pt = table.interaction_rand(targets, "AIDecision")
		end
	end
	
	if target_pt then		
		local args, has_ap = AIGetAttackArgs(context, CombatActions.Overwatch, nil, "None")
		if args and has_ap then
			args.target_pos = target_pt
			args.target = target_pt		
			if AIPlayCombatAction("Overwatch", context.unit, nil, args) then
				PlayVoiceResponse(context.unit, "AIOverwatch")
				return true
			end
		end
	end
	
	return false
end

function AIExecuteUnitBehavior(unit, force_or_skip_action)
	if not g_Combat or not IsValid(unit) or unit:IsDead() then
		return
	end
	
	if unit.ai_context.behavior then
		local status = unit.ai_context.behavior:Play(unit)
		if g_AIExecutionController then
			g_AIExecutionController:Log("  Behavior %s for unit %s (%d) returned '%s'", unit.ai_context.behavior:GetEditorView(), unit.unitdatadef_id, unit.handle, tostring(status))
		end

		if status then -- support behaviors that want to restart or stop the unit's ai
			return status 
		end
	end

	-- recheck unit, they could be killed or despawned during Play
	if IsValid(unit) and not unit:IsDead() then
		-- use the rest of the ap (if any) in signature actions and basic attacks
		return AIPlayAttacks(unit, unit.ai_context, unit.ai_context.forced_signature_action, force_or_skip_action) or AITakeCover(unit)
	end
end

function AITakeCover(unit, context)
	local context = unit.ai_context
	if unit:HasPreparedAttack() or not context or ((context.ap_after_signature or 0) <= 0) then
		return
	end
	local cover_high, cover_low = GetCoverTypes(unit)
	if not cover_high and not cover_low then
		return
	end
	if unit.species == "Human" and unit.stance ~= "Prone" then
		local context = unit.ai_context
		local chance = context and context.behavior and context.behavior.TakeCoverChance or 0
		if chance > 0 and (chance >= 100 or unit:Random(100) < chance) then
			local dest = GetPackedPosAndStance(unit)
			local enemy_visible = context.enemy_visible
			local enemy_pos = context.enemy_pack_pos_stance
			for _, enemy in ipairs(context.enemies) do
				if (enemy_visible[enemy] and GetCoverFrom(dest, enemy_pos[enemy]) or 0) > 0 then
					AIPlayCombatAction("TakeCover", unit, 0)
					return
				end
			end
		end
	end
	if cover_low then
		AIPlayCombatAction("StanceCrouch", unit, 0)
	end
end

function AIApplyActionModifiers(signature_action, unit)
	for _, mod in ipairs(signature_action.WeightModifications) do
		local id = mod.ActionId
		if id then
			local act_mods = g_AISignatureActionModifiers[id] or {}
			g_AISignatureActionModifiers[id] = act_mods

			local list 
			if mod.ApplyTo == "Self" then
				list = act_mods[unit] or {}
				act_mods[unit] = list
			else
				list = act_mods[unit.team] or {}
				act_mods[unit.team] = {}
			end
			list[#list + 1] = { end_turn = g_Combat.current_turn + mod.Period, value = mod.Value }
		end
	end
end

function AIGetActionWeight(action, unit, action_state)
	local w = action.Weight
	local id = action.ActionId
	if id and id ~= "" then
		local mods = g_AISignatureActionModifiers[id] or empty_table
		if mods[unit] then w = w + mods[unit].total end
		if mods[unit.team] then w = w + mods[unit.team].total end
	end
	
	local score = action_state and action_state.score or 100
	
	return MulDivRound(w, score, 100)
end

function AIGetSignatureActions(context, movement)
	local actions = {}
	-- if the behavior has any defined actions, pick from that list, otherwise revert to archetype's
	local actions_pool = context.behavior:GetSignatureActions(context)
	if not actions_pool or #actions_pool == 0 then
		actions_pool = context.archetype.SignatureActions
	end
	local unit = context.unit
	movement = movement or false
	for _, action in ipairs(actions_pool) do
		if (action.movement == movement) and action:MatchUnit(unit) then
			actions[#actions + 1] = action
		end
	end
	return actions
end

function AISelectAction(context, actions, base_weight, dbg_available_actions)
	local available = {}
	local weight = base_weight or 0
	
	context.action_states = context.action_states or {}

	for _, action in ipairs(actions) do
		context.action_states[action] = {}		
		local weight_mod, disable, priority = AIGetBias(action.BiasId, context.unit)
		disable = disable or context.disable_actions[action.BiasId or false]
		if not disable then
			action:PrecalcAction(context, context.action_states[action])
			if action:IsAvailable(context, context.action_states[action]) then
				local action_weight = MulDivRound(action.Weight, weight_mod, 100)
				priority = priority or action.Priority
				if dbg_available_actions then
					table.insert(dbg_available_actions, { action = action, weight = action_weight, priority = priority })
				end
				if priority then
					return action
				end
				available[#available + 1] = action
				available[available] = action_weight
				weight = weight + action_weight
			elseif dbg_available_actions then
				table.insert(dbg_available_actions, { action = action, weight = false })
			end
		end
	end
	if weight > 0 then
		local roll = InteractionRand(weight, "AISignatureAction", context.unit)
		for _, action in ipairs(available) do
			local w = available[action]
			if roll <= weight then
				return action
			end
			roll = roll - weight
		end
	end
	return available[#available]
end

function AIChooseSignatureAction(context)
	local weight = context.archetype.BaseAttackWeight
	context.choose_actions = { { action = false, weight = weight, priority = false } },	
	AIUpdateBiases()
	local sig_actions = AIGetSignatureActions(context)
	return AISelectAction(context, sig_actions, weight, context.choose_actions)
end

function AIChooseMovementAction(context)
	local actions = AIGetSignatureActions(context, true)
	AIUpdateBiases()
	return AISelectAction(context, actions, context.archetype.BaseMovementWeight)
end

function AIFindDestinations(unit, context)
	local pos = GetPassSlab(unit) or unit:GetPos()
	local destinations, paths, dest_ap, dest_path, voxel_to_dest, closest_free_pos = AIBuildArchetypePaths(unit, pos, context)	
	if not closest_free_pos then
		if unit.ActionPoints == 0 then
			assert(not "AI try to act with 0 action points!!!")
		else
			print("AI can't find unit free destination prints!!!")
			printf("      AP = %d", unit.ActionPoints)
			printf("      Command = %s", unit.command)
			printf("      Status effects: %s", table.concat(table.keys(unit.StatusEffects), ", "))
			printf("      Pos: %s", tostring(unit:GetPos()))
			printf("      Pass slab pos: %s", tostring(GetPassSlab(unit) or ""))
			printf("      Target dummy pos %s", unit.target_dummy and tostring(unit.target_dummy:GetPos()) or "")
			local o = GetOccupiedBy(unit:GetPos(), unit)
			if o then
				printf("Other pos %s", tostring(o:GetPos()))
				printf("Other target dummy pos %s", o.target_dummy and tostring(o.target_dummy:GetPos()) or "")
				printf("Other efResting=%d", o:GetEnumFlags(const.efResting))
				if o.reposition_dest then
					printf("Other reposition dest=%d,%d", stance_pos_unpack(o.reposition_dest))
				end
			end
			assert(not "AI can't find unit free destination")
		end
	end
	local crouch_idx = StancesList.Crouch
	local important_dests = context.important_dests or {}
	context.important_dests = important_dests
	local change_stance_costs = {}
	for stance_idx in ipairs(StancesList) do
		change_stance_costs[stance_idx] = GetStanceToStanceAP(StancesList[stance_idx], "Crouch")
	end

	-- preprocess destinations to find those where we need to change stance at the dest to take cover
	local low = const.CoverLow
	--local high = const.CoverHigh
	for i, dest in ipairs(destinations) do
		local x, y, z, stance_idx = stance_pos_unpack(dest)
		if stance_idx ~= crouch_idx then
			local cost = change_stance_costs[stance_idx]
			local ap = dest_ap[dest]
			if cost and ap and ap >= cost then
				local up, right, down, left = GetCover(x, y, z)
				if up then
					local cover_low = up == low or right == low or down == low or left == low
					--local cover_high = up == high or right == high or down == high or left == high
					if cover_low then --and not cover_high then
						table.remove_value(important_dests, dest)
						local new_dest = stance_pos_pack(x, y, z, crouch_idx)
						destinations[i] = new_dest
						voxel_to_dest[point_pack(x, y, z)]	= new_dest
						dest_ap[new_dest] = ap - cost
						dest_path[new_dest] = dest_path[dest]
						table.insert_unique(important_dests, new_dest)
					end
				end
			end
		end
	end

	context.destinations = destinations		-- available destinations
	context.dest_ap = dest_ap						-- dest -> available ap
	context.combat_paths = paths
	context.dest_combat_path = dest_path		-- dest -> index in context.combat_paths (to reach this dest)
	context.voxel_to_dest = voxel_to_dest	
	context.closest_free_pos = closest_free_pos

	context.all_destinations = AIEnumValidDests(context)
end

MapVar("g_BiasMarkers", false)

function AICreateContext(unit, context)
	local gx, gy, gz = unit:GetGridCoords()
	local weapon = unit:GetActiveWeapons()
	local default_attack = unit:GetDefaultAttackAction(nil, "ungrouped", nil, "sync")
	local enemies = table.icopy(GetEnemies(unit))
	
	for _, groupname in ipairs(unit.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for target_group, mod in pairs(group_modifiers) do
			for _, obj in ipairs(Groups[target_group]) do
				if IsKindOf(obj, "Unit") then
					table.insert_unique(enemies, obj)
				end
			end
		end
	end
	
	if not g_BiasMarkers then
		InitAIBiasMarkers()
	end
	
	-- fallback when our whole team doesn't have a visual on the enemy but we're still aware
	if #(enemies or empty_table) == 0 then
		enemies = table.ifilter(GetAllEnemyUnits(unit), function(idx, enemy) return not enemy:HasStatusEffect("Hidden") end)
	end
	
	-- special-case when having ManningEmplacement status - filter out non targetable enemies
	if unit:HasStatusEffect("ManningEmplacement") then
		enemies = table.ifilter(enemies, function(idx, enemy) return enemy:IsThreatened({unit}) end)
	end
	
	table.sortby_field(enemies, "handle")
	
	local pos = GetPassSlab(unit)
	if not pos then -- can happen if the unit is on impassable for some reason	
		--assert(false, "GetPassSlab failed for unit " .. unit.session_id)		
		local x, y, z = unit:GetPosXYZ()
		local gx, gy, gz = WorldToVoxel(x, y, z)
		if not z then
			gz = nil
		end
		pos = point(VoxelToWorld(gx, gy, (gz)))
	end
	local wx, wy, wz = pos:xyz()
	
	context = context or {}
	
	context.unit = unit
	context.unit_pos = pos
	context.start_ap = unit.ActionPoints
	context.archetype = unit:GetArchetype()
	context.unit_grid_voxel = point_pack(gx, gy, gz)
	context.unit_world_voxel = point_pack(pos)
	context.unit_stance_pos = stance_pos_pack(wx, wy, wz, StancesList[unit.stance])
	context.max_attacks = unit.MaxAttacks
	context.dest_target = {}						-- dest -> picked target (if any)
	context.dest_target_score = {}				-- dest -> estimated damage
	context.weapon = weapon
	context.default_attack = default_attack
	context.default_attack_cost = default_attack:GetAPCost(unit)
	context.EffectiveRange = IsKindOf(weapon, "Firearm") and weapon.WeaponRange / 2 or 1
	context.ExtremeRange = IsKindOf(weapon, "Firearm") and weapon.WeaponRange or 1
	context.enemies = enemies
	context.enemy_visible = {} -- [enemy] -> true/false
	context.enemy_visible_by_team = {} -- [enemy] -> true/false
	context.enemy_pos = {}
	context.enemy_grid_voxel = {}
	context.enemy_pack_pos_stance = {}
	context.enemy_dir = {}
	context.stance_pos_to_vis_enemies = {}
	context.allies = unit.team.units
	context.ally_grid_voxel = {}
	context.ally_pack_pos_stance = {}
	context.ally_pos = {}
	context.voxel_heal_target = {}
	context.voxel_heal_score = {}
	context.forced_signature_action = false
	context.apply_bias = true
	context.disable_actions = {} -- support for custom filtering for signature action selection by BiasId
	
	NetUpdateHash("AICreateContext", unit, pos, unit.stance, context.start_ap, context.archetype.id, context.max_attacks, weapon and weapon.class, weapon and weapon.id, default_attack.id)
	
	if unit:HasStatusEffect("Stimmed") then
		context.max_attacks = context.max_attacks + 1
	end
	
	for _, action in ipairs(context.archetype.SignatureActions) do
		context.can_heal = context.can_heal or IsKindOf(action, "AIActionBandage")
	end
	if not context.can_heal then
		for _, behavior in ipairs(context.archetype.Behaviors) do
			for _, action in ipairs(behavior.SignatureActions) do
				context.can_heal = context.can_heal or IsKindOf(action, "AIActionBandage")
			end
		end
	end

	for i, enemy in ipairs(enemies) do
		local x, y, z = enemy:GetGridCoords()
		context.enemy_grid_voxel[enemy] = point_pack(x, y, z)
		context.enemy_pack_pos_stance[enemy] = GetPackedPosAndStance(enemy)
		local enemy_pos = GetPassSlab(enemy) or SnapToVoxel(enemy:GetPos())
		context.enemy_pos[enemy] = enemy_pos
		if not pos:Equal2D(enemy_pos) then
			local dir = enemy_pos - pos
			dir = dir:SetInvalidZ()
			context.enemy_dir[enemy] = SetLen(dir, guim)
		else
			context.enemy_dir[enemy] = point(0, 0, guim)
		end
		context.enemy_visible[enemy] = HasVisibilityTo(unit, enemy)
		context.enemy_visible_by_team[enemy] = HasVisibilityTo(unit.team, enemy)
	end
	if context.behavior then
		context.behavior:EnumDestinations(unit, context)
	else
		AIFindDestinations(unit, context)
	end
	AIUpdateDestLosCache(unit, context)
	
	for i, ally in ipairs(context.allies) do
		local x, y, z = ally:GetGridCoords()
		context.ally_grid_voxel[ally] = point_pack(x, y, z)
		context.ally_pack_pos_stance[ally] = GetPackedPosAndStance(ally)
		context.ally_pos[ally] = ally:GetPos()
	end

	unit.ai_context = context
	return context
end

MapVar("g_AIDestEnemyLOSCache", {})

function dbgShowAIDestCache()
	DbgClearVectors()
	DbgClearTexts()
	for dest, los in pairs(g_AIDestEnemyLOSCache) do
		local x, y, z, stance_idx = stance_pos_unpack(dest)
		z = z or terrain.GetHeight(x, y)
		DbgAddVector(point(x, y, z), point(0, 0, guim), los and const.clrGreen or const.clrRed)
		DbgAddText(StancesList[stance_idx], point(x, y, z), const.clrWhite)
	end
end

function AIUpdateDestLosCache(unit, context)
	assert(CurrentThread()) -- the function will sleep internally due to the amount of calculations performed
	--local tStart = GetPreciseTicks()
	--ic("AIUpdateDestLosCache start", #units)
	local sight = unit:GetSightRadius()
	local all_destinations = context.all_destinations
	local enemies = context.enemies
	if #enemies == 0 then return end
	NetUpdateHash("AIUpdateDestLosCache_Start", GameTime(), sight, #all_destinations, hashParamTable(all_destinations), #enemies, hashParamTable(context.enemy_pack_pos_stance))

	local dests
	local los_cache = g_AIDestEnemyLOSCache
	for _, dest in ipairs(all_destinations) do
		if los_cache[dest] == nil then
			if not dests then dests = {} end
			dests[#dests + 1] = dest
			los_cache[dest] = false
		end
	end
	if dests then
		local max_los_checks = 100
		local targets = {}
		local srcs = {}
		local enemies_count = #enemies
		local next_dest_idx = 1
		local start_dest_idx = 1
		local cur_enemy = 1
		while true do
			local ppos = context.enemy_pack_pos_stance[enemies[cur_enemy]]
			local count = #targets
			local last_dest_idx = Min(#dests, next_dest_idx + max_los_checks - count - 1)
			for i = next_dest_idx, last_dest_idx do
				count = count + 1
				targets[count] = ppos
				srcs[count] = dests[i]
			end
			next_dest_idx = last_dest_idx + 1
			if next_dest_idx > #dests then
				next_dest_idx = 1
				cur_enemy = cur_enemy + 1
			end
			if count >= max_los_checks or cur_enemy > enemies_count then
				local los_any, los_data = CheckLOS(targets, srcs, sight)
				if los_any then
					local visible_dests = 0
					for i, value in ipairs(los_data) do
						if value then
							local dest = srcs[i]
							if not los_cache[dest] then
								los_cache[dest] = true
								visible_dests = visible_dests + 1
							end
						end
					end
					if visible_dests >= #dests then
						break
					end
					if cur_enemy < enemies_count or cur_enemy == enemies_count and next_dest_idx == 1 then
						-- There will be more LOS checks. Remove visible destinations from dests list to not cast more lines from there
						if #targets >= #dests then
							for i = #dests, 1, -1 do
								if los_cache[dests[i]] then
									table.remove(dests, i)
									if i < next_dest_idx then next_dest_idx = next_dest_idx - 1 end
								end
							end
						elseif start_dest_idx <= last_dest_idx then
							for i = last_dest_idx, start_dest_idx, -1 do
								if los_cache[dests[i]] then
									table.remove(dests, i)
									if i < next_dest_idx then next_dest_idx = next_dest_idx - 1 end
								end
							end
						else
							for i = #dests, start_dest_idx, -1 do
								if los_cache[dests[i]] then
									table.remove(dests, i)
									if i < next_dest_idx then next_dest_idx = next_dest_idx - 1 end
								end
							end
							for i = last_dest_idx, 1, -1 do
								if los_cache[dests[i]] then
									table.remove(dests, i)
									if i < next_dest_idx then next_dest_idx = next_dest_idx - 1 end
								end
							end
						end
						if #dests == 0 then
							assert(#dests > 0)
							break
						end
					end
				end
				if cur_enemy > enemies_count then
					break
				end
				start_dest_idx = next_dest_idx
				table.iclear(targets)
				table.iclear(srcs)
				if GetInGameInterfaceMode() ~= "IModeAIDebug" then
					Sleep(10) --yield
				end
			end
		end
	end

	NetUpdateHash("AIUpdateDestLosCache_End", GameTime())
	--printf("AIUpdateDestLosCache: %d ms for %s", GetPreciseTicks() - tStart, unit.unitdatadef_id)
end

function AIHasLOSToEnemyFromDest(dest)
	return not not g_AIDestEnemyLOSCache[dest]
end

function AICalcAttacksAndAim(context, ap)
	local aim_cost = const.Scale.AP
	if GameState.RainHeavy then
		aim_cost = MulDivRound(aim_cost, 100 + const.EnvEffects.RainAimingMultiplier, 100)
	end
	
	local 	cost = context.default_attack_cost
	local num_attacks = Min(ap / cost, context.max_attacks)
	
	if context.force_max_aim then
		num_attacks = Min(ap / (cost + aim_cost * context.weapon.MaxAimActions), context.max_attacks)
	end
	
	local remaining = ap - num_attacks * cost
	local aims = {}
	
	local attack_idx = 1
	while remaining > aim_cost do
		local aim = (aims[attack_idx] or 0) + 1
		if aim > context.weapon.MaxAimActions then 
			break 
		end
		aims[attack_idx] = aim
		attack_idx = attack_idx + 1
		if attack_idx > num_attacks then
			attack_idx = 1
		end
		remaining = remaining - aim_cost
	end
	
	return num_attacks, aims
end

function AIBuildArchetypePaths(unit, pos, context)
	local stationary = context.stationary
	local paths = {}
	local destinations, dest_path, dest_ap, voxel_to_dest = {}, {}, {}, {}
	if stationary or CombatActions.Move:GetUIState{unit} ~= "enabled" then
		local dest = GetPackedPosAndStance(unit)
		local x, y, z = stance_pos_unpack(dest)
		local voxel = point_pack(x, y, z)
		destinations[1] = dest
		dest_ap[dest] = unit.ActionPoints
		voxel_to_dest[voxel] = dest
		return destinations, paths, dest_ap, dest_path, voxel_to_dest, voxel
	end

	local archetype = unit:GetArchetype()
	local goto_stance = archetype.MoveStance
	local pref_stance = archetype.PrefStance

	local move_stance_idx = StancesList[goto_stance] or 0
	local pref_stance_idx = StancesList[pref_stance] or 0

	local ps_ap = (unit.species == "Human") and (unit.ActionPoints - GetStanceToStanceAP(unit.stance, pref_stance)) or unit.ActionPoints
	local ms_ap = (unit.species == "Human") and (unit.ActionPoints - GetStanceToStanceAP(unit.stance, goto_stance)) or unit.ActionPoints

	local move_path = CombatPath:new()
	move_path:RebuildPaths(unit, ms_ap, pos, goto_stance)

	local dest_voxels = table.keys(move_path.destinations, true)

	local pref_path
	if goto_stance == pref_stance then
		pref_path = move_path
	else
		local visited = move_path.destinations
		pref_path = CombatPath:new()
		pref_path:RebuildPaths(unit, ps_ap, pos, pref_stance)
		for voxel in sorted_pairs(pref_path.destinations) do
			if not visited[voxel] then
				dest_voxels[#dest_voxels+1] = voxel
			end
		end
	end

	local important_dests = context.important_dests or {}

	for _, voxel in ipairs(dest_voxels) do
		local x, y, z = point_unpack(voxel)
		local move_ap = move_path.paths_ap[voxel]
		local pref_ap = pref_path.paths_ap[voxel]
		local stance_idx, ap, dest
		local mn_ap = move_ap and (ms_ap - move_ap) or -1
		local pn_ap = pref_ap and (ps_ap - pref_ap) or -1

		if pn_ap > mn_ap then
			assert(pref_ap)

			dest = stance_pos_pack(x, y, z, pref_stance_idx)
			destinations[#destinations+1] = dest
			dest_path[dest] = pref_stance_idx
			dest_ap[dest] = pn_ap
		elseif move_ap then
			dest = stance_pos_pack(x, y, z, move_stance_idx)
			destinations[#destinations+1] = dest
			dest_path[dest] = move_stance_idx
			dest_ap[dest] = mn_ap
		else
			dest = stance_pos_pack(x, y, z, StancesList[unit.stance])
			assert(dest == context.unit_stance_pos)
			destinations[#destinations+1] = dest
			dest_path[dest] = move_stance_idx
			dest_ap[dest] = unit.ActionPoints
		end
		voxel_to_dest[voxel] = dest
		if not table.find(important_dests, dest) then
			if context.EffectiveRange <= 1 then
				-- make sure all potential melee positions are included in the end and not cut off by CollapsePoints
				for enemy, enemy_ppos in pairs(context.enemy_pack_pos_stance) do
					if stance_pos_dist(enemy_ppos, dest) < 2 * const.SlabSizeX then
						table.insert_unique(important_dests, dest)
						break
					end
				end
			end
			-- also do the same for allies, since we might wanna heal them
			if context.can_heal then
				for _, ally in ipairs(context.allies) do
					local ppos = GetPackedPosAndStance(ally)
					if stance_pos_dist(ppos, dest) < 2 * const.SlabSizeX then
						table.insert_unique(important_dests, dest)
						break
					end
				end
			end
		end
	end

	destinations = CollapsePoints(destinations, 1)
	context.important_dests = important_dests
	for _, dest in ipairs(important_dests) do
		local x, y, z = stance_pos_unpack(dest)
		if dest_ap[dest] and CanOccupy(unit, x, y, z) then
			table.insert_unique(destinations, dest)
		end
	end
	
	-- filter out destinations someone already called dibs for
	local occupied = {}
	for _, u in ipairs(context.allies) do
		if u ~= unit and u.ai_context then
			occupied[u.ai_context.ai_destination or false] = true
		end
	end	
	destinations = table.ifilter(destinations, function(_, dest) return not occupied[dest] end)

	paths[goto_stance] = move_path
	paths[move_stance_idx] = move_path
	paths[pref_stance] = pref_path
	paths[pref_stance_idx] = pref_path

	return destinations, paths, dest_ap, dest_path, voxel_to_dest, move_path.closest_free_pos
end

function AIScoreDest(context, policies, dest, grid_voxel, base_score, visual_voxels, score_details)
	local score = 0
	local x, y, z, stance_idx = stance_pos_unpack(dest)
	if not grid_voxel then
		local vx, vy, vz = WorldToVoxel(x, y, z)
		grid_voxel = point_pack(vx, vy, vz)
	end

	local voxels, head = context.unit:GetVisualVoxels(point_pack(x, y, z), StancesList[stance_idx], visual_voxels)
	if AreVoxelsInFireRange(voxels) then
		score = const.AIAvoidFireWeigth
		if score_details then
			score_details[#score_details + 1] = "ADJACENT FIRE"
			score_details[#score_details + 1] = const.AIAvoidFireWeigth
		end
	elseif g_SmokeObjs[head] then
		score = const.AIAvoidFireWeigth
		if score_details then
			score_details[#score_details + 1] = "GASSED AREA"
			score_details[#score_details + 1] = const.AIAvoidGasWeigth
		end
	end
	
	for _, policy in ipairs(policies) do
		local peval = policy:EvalDest(context, dest, grid_voxel)
		local pscore = MulDivRound(peval or 0, policy.Weight, 100)
		local failed = policy.Required and pscore == 0
		score = score + pscore
		if score_details then
			score_details[#score_details + 1] = (failed and "[FAILED] " or "") .. policy:GetEditorView()
			score_details[#score_details + 1] = pscore
		end
		if failed then
			return 0
		end
	end
	
	score = (base_score or 0) + score 
	
	-- bombard zone modifier
	for _, zone in ipairs(g_Bombard) do
		local dist = zone:GetDist(x, y, z)
		local radius = zone.radius * const.SlabSizeX
		if dist <= radius then
			local mod = MulDivRound(dist, const.AIAvoidBombardEdge, radius) + MulDivRound(radius - dist, const.AIAvoidBombardCenter, radius)
			local loss = MulDivRound(score, 100 - mod, 100)
			if score_details and loss > 0 then
				score_details[#score_details + 1] = "BOMBARD ZONE"
				score_details[#score_details + 1] = -loss
			end
			score = Max(0, score - loss)
		end
	end
	
	-- apply modifiers from bias markers at the end
	if context.apply_bias then
		local unit = context.unit
		for _, marker in ipairs(g_BiasMarkers) do
			local bias = marker:GetAIBias(unit, dest)
			if bias ~= 100 then
				score = MulDivRound(score, bias, 100)
				if score_details then
					score_details[#score_details + 1] = string.format("Bias Marker %s (%%): ", marker.ID)
					score_details[#score_details + 1] = bias
				end
			end
		end
	end
	
	return score
end

MapSlabsBBox_MaxZ = 100000
function AIEnumValidDests(context)
	local unit = context.unit
	local r = context.archetype.OptLocSearchRadius * const.SlabSizeX
	local ux, uy, uz = point_unpack(context.unit_grid_voxel)
	local px, py, pz = VoxelToWorld(ux, uy, uz)
	local bbox = box(px - r, py - r, 0, px + r + 1, py + r + 1, MapSlabsBBox_MaxZ)
	
	local dests, dest_added = {}, {}
	local function push_dest(x, y, z, context, dests, dest_added, ux, uy, uz)
		local gx, gy, gz = WorldToVoxel(x, y, z)
		
		if not IsCloser(gx, gy, gz, ux, uy, uz, context.archetype.OptLocSearchRadius) then
			return
		end
		if not CanOccupy(unit, x, y, z) then
			return
		end

		local world_voxel = point_pack(x, y, z)
		local dest = context.voxel_to_dest[world_voxel]
		if not dest then
			dest = stance_pos_pack(x, y, z, StancesList[context.archetype.PrefStance])
		end
		if not dest_added[dest] then
			dests[#dests + 1] = dest
			dest_added[dest] = true
		end
	end

	ForEachPassSlab(bbox, push_dest, context, dests, dest_added, ux, uy, uz)

	-- add current pos
	if not dest_added[context.unit_stance_pos] then
		local x, y, z = stance_pos_unpack(context.unit_stance_pos)
		if CanOccupy(unit, x, y, z) then
			dests[#dests + 1] = context.unit_stance_pos
			dest_added[context.unit_stance_pos] = true
		end
	end

	-- add from context.destinations
	for _, dest in ipairs(context.destinations) do
		if not dest_added[dest] then
			dests[#dests + 1] = dest
		end
	end

	dests = CollapsePoints(dests, 1)
	for _, dest in ipairs(context.important_dests) do
		table.insert_unique(dests, dest)
	end
	return dests
end

function AIFindOptimalLocation(context, dest_score_details)
	if context.best_dest then
		-- optimal location doesn't change across behaviors, no need to recalc it
		return context.best_dest
	end

	local unit = context.unit
	context.best_dests = {}

	local r = context.archetype.OptLocSearchRadius * const.SlabSizeX
	local ux, uy, uz = point_unpack(context.unit_grid_voxel)
	local px, py, pz = VoxelToWorld(ux, uy, uz)
	local bbox = box(px - r, py - r, 0, px + r + 1, py + r + 1, MapSlabsBBox_MaxZ)
	context.best_score = 0
	local unit_voxels = {}
	local dest_scores = {}
	
	local policies = table.ifilter(context.archetype.OptLocPolicies, function(idx, policy) return policy:MatchUnit(unit) end)
	
	for _, dest in ipairs(context.all_destinations) do
		local x, y, z = stance_pos_unpack(dest)
		local gx, gy, gz = WorldToVoxel(x, y, z)
		local world_voxel = point_pack(x, y, z)
		local grid_voxel = point_pack(gx, gy, gz)
		--eval_voxel(x, y, z, context, ux, uy, uz)
		
		if not context.voxel_to_dest[world_voxel] then
			context.voxel_to_dest[world_voxel] = dest
		end
		local scores
		if dest_score_details then
			scores = {}
			dest_score_details[dest] = scores
		end
		table.iclear(unit_voxels)
		local score = AIScoreDest(context, policies, dest, grid_voxel, 0, unit_voxels, scores)
		if score > 0 then
			context.best_score = Max(context.best_score, score)
			local threshold = MulDivRound(context.best_score, const.AIDecisionThreshold, 100)
			if score >= threshold then
				dest_scores[dest] = score
				context.best_dests[#context.best_dests + 1] = dest
				for i = #context.best_dests, 1, -1 do		
					local dest = context.best_dests[i]
					if dest_scores[dest] < threshold then
						table.remove(context.best_dests, i)
					end
				end
			end
		end
		if scores then
			scores.final_score = score
		end
	end
	
	-- check if a best dest candidate is on our starting voxel, default to it
	for _, dest in ipairs(context.best_dests) do
		if stance_pos_dist(context.unit_stance_pos, dest) == 0 then
			context.best_dest = dest
		end
	end
	
	if not context.best_dest and #(context.best_dests or empty_table) > 0 then
		if #(context.best_dests or empty_table) > 15 then
			context.collapsed = CollapsePoints(context.best_dests, 1)
		else
			context.collapsed = context.best_dests
		end
		local pf_dests = {}
		for i, dest in ipairs(context.collapsed) do
			local x, y, z = stance_pos_unpack(dest)
			pf_dests[i] = point(x, y, z)
		end
		
		context.best_dest_path = pf.GetPosPath(unit, pf_dests)
		if #(context.best_dest_path or empty_table) > 0 then
			local voxel = point_pack(SnapToPassSlabXYZ(context.best_dest_path[1]))
			local dest = context.voxel_to_dest[voxel]
			if not dest then
				-- try non-snapped
				voxel = point_pack(context.best_dest_path[1])
				dest = context.voxel_to_dest[voxel]
			end
			--assert(dest and (not dest_score_details or dest_score_details[dest]))
			context.best_dest = dest 
		end
	end
	
	context.dest_scores = dest_scores
	context.best_dest = context.best_dest or context.voxel_to_dest[context.unit_world_voxel] or context.unit_stance_pos
	if context.dest_combat_path[context.best_dest] then
		table.insert_unique(context.important_dests, context.best_dest)
		table.insert_unique(context.destinations, context.best_dest)
	end
	return context.best_dest
end

function AICalcPathDistances(context)
	local unit = context.unit
	local path_voxels, voxel_dist, total_dist
	if context.best_dest_path then 
		path_voxels, voxel_dist, total_dist = CalcPathVoxels(context.best_dest_path)
	end
	context.path_voxels = path_voxels
	context.path_to_target = table.copy(path_voxels or empty_table)
	context.voxel_dist = voxel_dist
	context.total_dist = total_dist
		
	-- calc distance to optimal location from each dest
	if path_voxels and voxel_dist then
		AICalcDistancesFromReachableLocations(context) -- will add path nodes to path_voxels and voxel_dist
	else
		-- no path to target, use default distances on all reachable voxels
		context.dest_dist = {}
	end
end

function AIGetWeaponCheckRange(unit, weapon, action)
	if IsKindOf(weapon, "MeleeWeapon") then
		local tiles = unit.body_type == "Large animal" and 2 or 1
		local range = (2 * tiles + 1) * const.SlabSizeX / 2
		return range, true
	elseif IsKindOf(weapon, "Firearm") then
		local max_range = weapon.WeaponRange * const.SlabSizeX
		if action.AimType ~= "cone" then
			max_range = 15 * max_range / 10
		end
		return max_range
	end
end

--MapVar("g_AIDamageScoreLog", {})

function AIAllyInDanger(allies, ally_pos, pos, target, dist_near, dist_far)
	local target_pos = target:GetPos()
	local v = target:GetPos() - pos
	local d = const.AIFriendlyFire_MaxRange
	for _, ally in ipairs(allies) do
		if ally:GetDist2D(pos) <= const.AIFriendlyFire_MaxRange then
			local ally_pos = ally_pos and ally_pos[ally] or ally:GetPos()
			local dist, x, y, z = DistSegmentToPt2D(pos, target_pos, ally_pos)
			local nearest = point(x, y, z)
			local d1 = pos:Dist2D(nearest)
			
			local dist_threshold = MulDivRound(dist_near, Clamp(0, d, d - d1), d) + MulDivRound(dist_far, Clamp(0, d, d1), d)
			
			if dist < dist_threshold then
				local v1 = nearest - pos
				if Dot2D(v, v1) > 0 then
					return true
				end
			end
		end
	end
end

function AIPrecalcDamageScore(context, destinations, preferred_target, debug_data)
	local unit = context.unit
	local weapon = context.weapon
	local action = CombatActions[context.override_attack_id or false] or context.default_attack
	local archetype = context.archetype
	local behavior = context.behavior

	if not weapon or context.reposition or unit:HasStatusEffect("Burning") then
		return
	end
	if not destinations and context.damage_score_precalced then
		return
	end

	local targets = table.icopy(action:GetTargets({unit}))	
	targets = table.ifilter(targets or empty_table, function(idx, target) return unit:IsOnEnemySide(target) end)
	if not targets or #targets == 0 then
		return
	end
	context.damage_score_precalced = true
	local target_score_mod = {}
	local tsr = archetype.TargetScoreRandomization
	for i, target in ipairs(targets) do
		target_score_mod[i] = 100 + ((tsr > 0) and unit:RandRange(-tsr, tsr) or 0)
	end
	context.target_score_mod = target_score_mod

	local base_mod = unit[weapon.base_skill]
	local cost_ap = context.override_attack_cost or context.default_attack_cost

	local max_check_range, is_melee = AIGetWeaponCheckRange(unit, weapon, action)
	local is_heavy = IsKindOf(weapon, "HeavyWeapon")

	local hit_modifiers = Presets["ChanceToHitModifier"]["Default"]
	-- stance mod
	local modCrouchBonus = 0
	local modProneBonus = 0
	--if IsKindOf(weapon, "Firearm") then
		--modCrouchBonus = hit_modifiers.AttackerStance:ResolveValue("CrouchBonus")
		--modProneBonus = hit_modifiers.AttackerStance:ResolveValue("ProneBonus")
		local value = GetComponentEffectValue(weapon, "AccuracyBonusProne", "bonus_cth")
		if value then
			modProneBonus = modProneBonus + value
		end
	--end
	-- ground difference mod
	local MinGroundDifference = hit_modifiers.GroundDifference:ResolveValue("RangeThreshold") * const.SlabSizeZ / 100
	local modHighGround = hit_modifiers.GroundDifference:ResolveValue("HighGround")
	local modLowGround = hit_modifiers.GroundDifference:ResolveValue("LowGround")
	-- cover
	local modCover = hit_modifiers.RangeAttackTargetStanceCover:ResolveValue("Cover")
	local modSameTarget = hit_modifiers.SameTarget:ResolveValue("Bonus")
	
	local target_policies = archetype.TargetingPolicies
	if behavior and #(behavior.TargetingPolicies or empty_table) > 0 then
		target_policies = behavior.TargetingPolicies
	end
	
	local dest_target = context.dest_target
	local dest_target_score = context.dest_target_score
	local dest_ap = context.dest_ap
	local aim_mod = Presets.ChanceToHitModifier.Default.Aim
	local dest_cth = {}
	context.dest_cth = dest_cth
	local lof_params
	local attacker_pos = unit:GetPos()
	
	-- script-driven modifiers (based on groups)
	local target_modifiers
	for _, groupname in ipairs(unit.Groups) do
		local group_modifiers = gv_AITargetModifiers[groupname]
		for target_group, mod in pairs(group_modifiers) do
			target_modifiers = target_modifiers or {}
			target_modifiers[target_group] = (target_modifiers[target_group] or 0) + mod
			for _, obj in ipairs(Groups[target_group]) do
				if IsKindOf(obj, "Unit") and not table.find(targets, obj) then				
					table.insert(targets, obj) -- make sure the target is considired regardless if it's an enemy or not
					table.insert(target_score_mod, 100 + ((tsr > 0) and unit:RandRange(-tsr, tsr) or 0))
				end
			end
		end
	end
	
	if unit:HasStatusEffect("StationedMachineGun") or unit:HasStatusEffect("ManningEmplacement") then
		local ow_units = {unit}
		targets = table.ifilter(targets, function(idx, target) return target:IsThreatened(ow_units, "overwatch") end)
	end
	
	if not IsValidTarget(preferred_target) or (IsKindOf(preferred_target, "Unit") and preferred_target:IsIncapacitated() or not table.find(targets, preferred_target)) then
		preferred_target = nil
	end

	if weapon and not is_melee then
		lof_params = {
			obj = unit,
			action_id = action.id,
			weapon = weapon,
			step_pos = false,
			stance = false,
			range = max_check_range,
			prediction = true,
			output_collisions = true,
		}
		if not destinations or #destinations > 1 then
			lof_params.target_spot_group = "Torso"
		end
	end
--[[	local logdata = {}
	if destinations then
		table.insert(g_AIDamageScoreLog, logdata)
	end
	logdata.preferred_target = preferred_target and (IsKindOf(preferred_target, "Unit") and _InternalTranslate(preferred_target.Name or "") or preferred_target.class) or tostring(preferred_target)--]]
	destinations = destinations or context.destinations
	NetUpdateHash("AIPrecalcDamageScore", unit, hashParamTable(destinations), hashParamTable(targets), preferred_target)
	for j, upos in ipairs(destinations) do
		local ux, uy, uz, ustance_idx = stance_pos_unpack(upos)
		local ustance = StancesList[ustance_idx]
		uz = uz or terrain.GetHeight(ux, uy)

		local ap = dest_ap[upos] or 0
		local best_target, best_cth
		local best_score = 0
		local potential_targets, target_score, target_cth = {}, {}, {}
		if weapon and ap >= cost_ap then
			local pos_mod = base_mod
			pos_mod = pos_mod + (ustance_idx == 2 and modCrouchBonus or ustance_idx == 3 and modProneBonus or 0)

			local targets_attack_data
			if not is_melee then
				attacker_pos = point(ux, uy, uz)
				lof_params.step_pos = point_pack(ux, uy, uz)
				lof_params.stance = ustance
				targets_attack_data = GetLoFData(unit, targets, lof_params)
			end
			for k, target in ipairs(targets) do
				local tpos = GetPackedPosAndStance(target)
				local dist = stance_pos_dist(upos, tpos)
				if dist <= (max_check_range or dist) and (is_melee or targets_attack_data[k] and not targets_attack_data[k].stuck) then
					local tx, ty, tz, tstance_idx = stance_pos_unpack(tpos)
					tz = tz or terrain.GetHeight(tx, ty)
					local hit_mod = pos_mod
					if not is_heavy then
						hit_mod = hit_mod + (uz > tz + MinGroundDifference and modHighGround or uz < tz - MinGroundDifference and modLowGround or 0)
						hit_mod = hit_mod + (unit:GetLastAttack() == target and modSameTarget or 0)
					end
					local target_cover = GetCoverFrom(tpos, upos)
					if target_cover == const.CoverLow or target_cover == const.CoverHigh then
						hit_mod = hit_mod + modCover
					end

					local penalty = is_heavy and 0 or (100 - weapon:GetAccuracy(dist))

					local mod = hit_mod - penalty --dist_penalty
					-- environmental modifiers when applicable
					local apply, value, target_spot_group, action, weapon1, weapon2, lof, aim, opportunity_attack
					apply, value = hit_modifiers.Darkness:CalcValue(unit, target, target_spot_group, action, weapon1, weapon2, lof, aim, opportunity_attack, attacker_pos)
					if apply then
						mod = mod + value
					end
					
					if not is_heavy and unit:IsPointBlankRange(target) then
						mod = MulDivRound(mod, 100 + const.AIPointBlankTargetMod, 100)
					end
					
					if mod > 0 then
						-- calc base score based on cth/attacks/aiming
						local base_mod = mod
						local attacks, aims = AICalcAttacksAndAim(context, ap)
						mod = 0
						for i = 1, attacks do
							local use, bonus
							if (aims[i] or 0) > 0 then
								use, bonus = aim_mod:CalcValue(unit, nil, nil, nil, nil, nil, nil, aims[i])
							end
							mod = mod + base_mod + (use and bonus or 0)
						end
						-- modify score by archetype-specific weight and (optional) targeting policies
						mod = MulDivRound(mod, archetype.TargetBaseScore, 100)
						for _, policy in ipairs(target_policies) do
							local peval = policy:EvalTarget(unit, target)
							mod = mod + MulDivRound(peval or 0, policy.Weight, 100)
						end

						if IsKindOf(target, "Unit") and (target:IsDowned() or target:IsGettingDowned()) then
							mod = MulDivRound(mod, 5, 100)
						end

						local attack_data = targets_attack_data and targets_attack_data[k]
						local ally_in_danger = attack_data and (attack_data.best_ally_hits_count or 0) > 0
												
						if action and action.AimType == "cone" then
							ally_in_danger = ally_in_danger or AIAllyInDanger(context.allies, context.ally_pos, attacker_pos, target, const.AIFriendlyFire_LOFConeNear, const.AIFriendlyFire_LOFConeFar)
						else
							ally_in_danger = ally_in_danger or AIAllyInDanger(context.allies, context.ally_pos, attacker_pos, target, const.AIFriendlyFire_LOFWidth, const.AIFriendlyFire_LOFWidth)
						end
						if ally_in_danger then
							mod = MulDivRound(mod, const.AIFriendlyFire_ScoreMod, 100)
						end
						
						mod = MulDivRound(mod, target_score_mod[k], 100)
						
						-- apply group-based modifiers
						if target_modifiers and IsKindOf(target, "Unit") then
							local group_mod = 0
							for _, groupname in ipairs(target.Groups) do
								group_mod = group_mod + (target_modifiers[groupname] or 0)
							end
							if group_mod > 0 then
								mod = MulDivRound(mod, group_mod, 100)
							end
						end
						
						--[[table.insert(logdata, {
							name = IsKindOf(target, "Unit") and _InternalTranslate(target.Name or "") or target.class,
							score = mod
						})--]]
						
						if mod > 0 and target == preferred_target then
							best_target = target
							best_score = mod
							best_cth = base_mod
							potential_targets = {}
							break
						end

						best_score = Max(best_score, mod)
						target_cth[target] = base_mod
						target_score[target] = mod
						local threshold = MulDivRound(best_score or 0, const.AIDecisionThreshold, 100)
						if mod >= threshold then
							potential_targets[#potential_targets + 1] = target
							for i = #potential_targets, 1, -1 do
								local target = potential_targets[i]
								local score = target_score[target]
								if score < threshold then
									table.remove(potential_targets, i)
								end
							end
							--best_target, best_score, best_cth = target, mod, base_mod
						end
					end
				end
			end
		end
		
		if #potential_targets > 0 then
			local total = 0
			for _, target in ipairs(potential_targets) do
				local score = target_score[target]
				total = total + score
				if debug_data then
					debug_data[target] = score
				end
			end
			local roll = InteractionRand(total, "AIDecision")
			for _, target in ipairs(potential_targets) do
				local score = target_score[target]
				if roll < score then
					best_target = target
					break
				end
				roll = roll - score
			end
			best_target = best_target or potential_targets[#potential_targets] or false
			best_score = target_score[best_target] or 0
			best_cth = target_cth[best_target] or 0
		end
		
		--[[
		if destinations and IsKindOf(best_target, "Unit") then
			if best_target == preferred_target then
				printf("%s (%d) selected target (preferred): %s (score %d)", _InternalTranslate(unit.Name or ""), unit.handle, _InternalTranslate(best_target.Name or ""), best_score)
			else
				printf("%s (%d) selected target: %s (score %d)", _InternalTranslate(unit.Name or ""), unit.handle, _InternalTranslate(best_target.Name or ""), best_score)
				printf("  potential targets:")
				for _, target in ipairs(potential_targets) do
					printf("    %s (score %d)", _InternalTranslate(target.Name or ""), target_score[target])
				end
			end
		end--]]
		
		--logdata.chosen_target = best_target and (IsKindOf(best_target, "Unit") and _InternalTranslate(best_target.Name or "") or best_target.class) or tostring(best_target)
		dest_target_score[upos] = best_score
		dest_target[upos] = best_target
		dest_cth[upos] = best_cth
	end
end

function AIScoreReachableVoxels(context, policies, opt_loc_weight, dest_score_details, cur_dest_preference)
	local unit = context.unit
	policies = table.ifilter(policies, function(idx, policy) return policy:MatchUnit(unit) end)
	unit.ai_end_turn_search = {}

	local total_dist = context.total_dist
	local dest_dist = context.dest_dist or empty_table

	local ux, uy, uz = point_unpack(context.unit_grid_voxel)
	local curr_dest = context.voxel_to_dest[context.unit_world_voxel] or context.voxel_to_dest[context.closest_free_pos] or context.unit_stance_pos
	local dist = dest_dist[curr_dest] or total_dist
	local score = -opt_loc_weight

	if (total_dist or 0) > 0 then
		score = MulDivRound(score, dist, total_dist)
	end

	local unit_voxels = {}
	local best_end_score = curr_dest and AIScoreDest(context, policies, curr_dest, context.unit_grid_voxel, score, unit_voxels)

	-- cache the best voxel on the way to optimal location to use as fallback if needed
	local best_dist_score, closest_dest
	local potential_dests, dest_scores = {curr_dest}, {best_end_score}

	for _, dest in ipairs(context.destinations) do
		total_dist = Max(total_dist or 0, dest_dist[dest] or 0)
	end

	for _, dest in ipairs(context.destinations) do
		local score = 0
		local scores

		local dist = dest_dist[dest] or 100*guim
		local dist_score = 0
		if total_dist and total_dist > 0 then
			dist_score = MulDivRound(100 - MulDivRound(100, dist, total_dist), opt_loc_weight, 100)
		end
		if dist_score > (best_dist_score or 0) then
			best_dist_score, closest_dest = dist_score, dest
		end

		score = score + dist_score
		if dest_score_details then
			scores = { "Distance to optimal location", dist_score }
			dest_score_details[dest] = scores
		end

		table.iclear(unit_voxels)
		score = AIScoreDest(context, policies, dest, nil, score, unit_voxels, scores)

		if MulDivRound(best_end_score or 0, const.AIDecisionThreshold, 100) <= score then
			best_end_score = Max(score, best_end_score or 0)
			local n = #potential_dests
			potential_dests[n+1] = dest
			dest_scores[n+1] = score
			local threshold = MulDivRound(best_end_score, const.AIDecisionThreshold, 100) -- updated threshold
			for i = n, 1, -1 do
				if dest_scores[i] < threshold then
					table.remove(dest_scores, i)
					table.remove(potential_dests, i)
				end
			end
		end
		if scores then
			scores.final_score = score
		end
	end

	-- pick best_end_dest/score from potential_dests
	assert(#potential_dests > 0)
	context.best_end_dest = false
	if cur_dest_preference == "prefer" then
		if table.find(potential_dests, curr_dest) then
			context.best_end_dest = curr_dest
		end
	elseif cur_dest_preference == "avoid" then
		if #potential_dests > 1 then
			table.remove_value(potential_dests, curr_dest)
		end
	end
	
	NetUpdateHash("AIScoreReachableVoxels", unit, unit:GetPos(), unit.ActionPoints, context.archetype.id, #(context.destinations or ""), hashParamTable(context.destinations), #(potential_dests or ""), hashParamTable(potential_dests), cur_dest_preference)	
	
	if not context.best_end_dest then
		local total = 0
		for _, score in ipairs(potential_dests) do
			total = total + score
		end
		local roll = InteractionRand(total, "AIDecision")
		for i, dest in ipairs(potential_dests) do
			local score = dest_scores[i]
			if score <= roll then
				context.best_end_dest = dest
				break
			end
			roll = roll - score
		end
		context.best_end_dest = context.best_end_dest or potential_dests[#potential_dests] or curr_dest
	end
	context.best_end_score = best_end_score

	context.closest_dest = closest_dest
	return context.best_end_dest, context.best_end_score
end

function CalcPathVoxels(path)
	local dist = 0

	if not IsPoint(path[1]) then
		local pt_path = {}
		for i, ppos in ipairs(path) do
			pt_path[i] = point(point_unpack(ppos))
		end
		path = pt_path
	end

	local processed_path = { path[1] }

	local voxel_dist = {}
	local voxels = {}
	voxel_dist[point_pack(path[1])] = 0

	local function push_path_segment(seg_start, seg_end, path_dist, tunnel)
		local seg_dist = seg_start:Dist(seg_end)
		if not tunnel and seg_dist > const.SlabSizeX/2 then
			local midpt = (seg_start + seg_end) / 2
			push_path_segment(seg_start, midpt, path_dist)
			push_path_segment(midpt, seg_end, path_dist + seg_dist / 2)
		else
			processed_path[#processed_path + 1] = seg_end
			local x, y, z = GetPassSlabXYZ(seg_end)
			local pck_end = x and point_pack(x, y, z)
			if pck_end and not voxel_dist[pck_end] then
				voxel_dist[pck_end] = path_dist + seg_dist
				voxels[#voxels + 1] = pck_end
				--[[
				local pt = point(x, y, z)
				if not pt:IsValidZ() then pt = pt:SetTerrainZ() end
				DbgAddVector(pt, point(0, 0, guim), const.clrGreen)
				DbgAddText(tostring(path_dist + seg_dist), pt + point(0, 0, guim/2), const.clrWhite)--]]
			end
		end
		return seg_dist
	end

	local dist = 0
	local marker = InvalidPos()
	local seg_start_idx, seg_end_idx
	
--DbgClearVectors()
--DbgClearTexts()
	for i = 1, #path do
		if not seg_start_idx then
			seg_start_idx = path[i] ~= marker and i
		elseif not seg_end_idx then
			seg_end_idx = path[i] ~= marker and i
		end

		if seg_start_idx and seg_end_idx then
--[[
			local pt1 = path[seg_end_idx]
			local pt2 = path[seg_start_idx]
			if not pt1:IsValidZ() or pt1:z() < terrain.GetHeight(pt1) + 50*guic then
				pt1 = pt1:SetTerrainZ(100*guic)
			end
			if not pt2:IsValidZ() or pt2:z() < terrain.GetHeight(pt2) + 50*guic then
				pt2 = pt2:SetTerrainZ(100*guic)
			end
			DbgAddVector(pt1, point(0, 0, guim), const.clrWhite)
			DbgAddVector(pt2, point(0, 0, guim), const.clrWhite)
			printf("seg %d: %s - %s", seg_start_idx, tostring(pt2), tostring(pt1))
			DbgAddVector(pt1, pt2 - pt1, seg_end_idx > seg_start_idx + 1 and const.clrYellow or const.clrWhite)
			DbgAddText(tostring(seg_start_idx), (pt1+pt2)/2, const.clrBlue)
--]]			
			dist = dist + push_path_segment(path[seg_start_idx], path[seg_end_idx], dist, seg_end_idx > seg_start_idx + 1)
			seg_start_idx = seg_end_idx
			seg_end_idx = false
		end
	end

	return voxels, voxel_dist, dist
end

function AICalcDistancesFromReachableLocations(context)
	local voxel_idx = 1
	local stance = context.archetype.MoveStance
	local tunnel_mask = stance == "Prone" and const.TunnelTypeWalk or -1
	local processed = {}
	
	local voxel_to_dest = context.voxel_to_dest
	local path_voxels = context.path_voxels
	local voxel_dist = context.voxel_dist
	
	local dest_dist = {}
	context.dest_dist = dest_dist
	
	for voxel, dist in pairs(context.voxel_dist) do
		local dest = voxel_to_dest[voxel]
		if dest then
			context.dest_dist[dest] = dist
		end
	end
	
--DbgClearVectors()
--DbgClearTexts()
	while path_voxels[voxel_idx] do
		local voxel = path_voxels[voxel_idx]
		local dest = voxel_to_dest[voxel]
		if not processed[voxel] then
			processed[voxel] = true
			local px, py, pz = point_unpack(voxel)
--[[
local pt = point(px, py, pz)
if not pt:IsValidZ() then pt = pt:SetTerrainZ() end
DbgAddVector(pt, point(0, 0, 2*guim), const.clrBlue)
DbgAddText(dest and dest_dist[dest] and tostring(dest_dist[dest]) or "n/a", pt + point(0, 0, guim), const.clrWhite)
DbgAddText(voxel_dist[voxel] and tostring(voxel_dist[voxel]) or "n/a", pt + point(0, 0, guim/2), const.clrYellow)
--]]
			ForEachPassSlabStep(px, py, pz, tunnel_mask, function(x, y, z, tunnel)
				local curr_voxel = point_pack(x, y, z)
				local curr_dest = voxel_to_dest[curr_voxel]
				if curr_dest and dest then
					assert(voxel_dist[voxel])
					local x2, y2, z2 = point_unpack(voxel)
	 				local dx, dy, dz = x - x2, y - y2, (z and z2) and z - z2 or 0
					local dist = voxel_dist[voxel] + sqrt(dx*dx + dy*dy + dz*dz) -- the tile is guaranteed to be reachable, so we can take linear distance
					if not voxel_dist[curr_voxel] or voxel_dist[curr_voxel] > dist then
						-- if the step is a tunnel, we need to check if it goes both ways to filter out shortcuts from target to current location
						if not tunnel or pf.GetTunnel(tunnel.end_point, tunnel:GetPos()) then				
							voxel_dist[curr_voxel] = dist
							dest_dist[curr_dest] = dist
						end
					end
					path_voxels[#path_voxels + 1] = curr_voxel
					if not voxel_dist[curr_voxel] then
						voxel_dist[curr_voxel] = dist
					end
					if not dest_dist[curr_dest] then
						dest_dist[curr_dest] = dist
					end
				end
			end)
		end
		voxel_idx = voxel_idx + 1
	end
end

function AIGetAttackArgs(context, action, target_spot_group, aim_type, override_target)
	local upos = GetPackedPosAndStance(context.unit)
	local target = override_target or context.dest_target[upos]
	local args = { target = target, target_spot_group = target_spot_group or "Torso" }

	local dest_ap
	if context.ai_destination then
		local u_x, u_y, u_z = stance_pos_unpack(upos)
		local dest_x, dest_y, dest_z = stance_pos_unpack(context.ai_destination)
		
		if point(u_x, u_y, u_z) ~= point(dest_x, dest_y, dest_z) then
			dest_ap = context.dest_ap[context.ai_destination]
		end
	end
		
	local unit_ap = dest_ap or context.unit:GetUIActionPoints()
	
	if action.id == "Overwatch" then
		local attacks, aim = context.unit:GetOverwatchAttacksAndAim(action, args, unit_ap)
		args.num_attacks = attacks
		args.aim_ap = aim
	elseif aim_type ~= "None" then
		args.aim = context.weapon.MaxAimActions
		if aim_type == "Remaining AP" then
			while args.aim > 0 and not context.unit:HasAP(action:GetAPCost(context.unit, args)) do
				args.aim = args.aim - 1
			end
		end
	end

	local cost = action:GetAPCost(context.unit, args)
	local has_ap = cost >= 0 and (unit_ap >= cost)
	return args, has_ap, target
end

function AICalcAOETargetPoints(context, min_range, max_range, max_radius)
	local target_pts = {}
	local unit = context.unit
	local enemies = context.enemies
	
	-- add enemy positions
	for i, enemy in ipairs(enemies) do
		if VisibilityCheckAll(unit, enemy, nil, const.uvVisible) then
			target_pts[#target_pts + 1] = context.enemy_pos[enemy]
		end
	end
	
	local num_targets = #target_pts
	-- add midpoints of enemy pairs
	for i = 1, num_targets - 1 do
		for j = i + 1, num_targets do
			local pt = (target_pts[i] + target_pts[j]) / 2
			if not max_radius or pt:Dist(target_pts[i]) <= max_radius then
				target_pts[#target_pts + 1] = pt
			end
		end
	end
	
	-- add midpoints of enemy triples
	for i = 1, num_targets - 2 do
		for j = i + 1, num_targets - 1 do
			for k = j + 1, num_targets do
				local pt = (target_pts[i] + target_pts[j] + target_pts[k]) / 3
				if not max_radius or pt:Dist(target_pts[i]) <= max_radius then
					target_pts[#target_pts + 1] = pt
				end
			end
		end
	end
	
	-- filter out target points not in range
	local attack_pos = context.unit_pos
	for i = #target_pts, 1, -1 do
		local dist = unit:GetDist(target_pts[i])
		if dist == 0 or (max_range and dist > max_range) then
			table.remove(target_pts, i)
		elseif min_range and min_range < max_range and dist < min_range then
			table.remove(target_pts, i)
		end
	end
	
	return target_pts
end

function AIPrecalcConeTargetZones(context, action_id, additional_target_pt, stance)
	if context.target_locked then return {} end
	
	local unit = context.unit
	local weapon = context.weapon
	local params = weapon:GetAreaAttackParams(action_id, unit)

	local min_range = params.min_range * const.SlabSizeX
	local max_range = params.max_range * const.SlabSizeX

	local target_pts = AICalcAOETargetPoints(context, min_range, max_range)
	if additional_target_pt then
		target_pts[#target_pts + 1] = additional_target_pt
	end

	-- calc cone areas for each remaining target point
	local zones = {}
	local cone_angle = params.cone_angle
	local targets = {}
	local attack_pos = unit:GetPos() -- make sure we're using the current position in case the unit has moved
	local units = table.copy(context.enemies)
	table.iappend(units, GetAllAlliedUnits(unit))
	local unit_sight = unit:GetSightRadius()
	
	for zi, pt in ipairs(target_pts) do
		local dir = pt - attack_pos
		if dir:Len() > 0 then
			local target_pos = (attack_pos + SetLen(dir, max_range)):SetTerrainZ()
			local zone = {
				target_pos = target_pos,
				units = {},
			}
			zones[#zones + 1] = zone
		
			local angle = CalcOrientation(attack_pos, pt)
			local los_any, los_targets = CheckLOS(units, unit, unit:GetDist(target_pos), nil, cone_angle, angle)
			if los_any then
				for i, target_unit in ipairs(units) do
					if los_targets[i] and IsValidTarget(target_unit) then
						zone.units[#zone.units + 1] = target_unit
						table.insert_unique(targets, target_unit)
					end
				end
			end
		end
	end
	
	local check_ally
	if action_id == "Overwatch" then
		local atk_action = context.default_attack
		local aim_type = atk_action.AimType
		local is_aoe = aim_type == "cone" or aim_type == "aoe" or aim_type == "parabola aoe" or aim_type == "line aoe"
		check_ally = not is_aoe
	end
	
	-- filter LOS targets
	local max_distance = Min(unit_sight, weapon:GetMaxRange())
	local los_any, los_targets = CheckLOS(targets, unit, max_distance)
	if not los_any then
		for _, zone in ipairs(zones) do
			table.iclear(zone.units)
		end
		return zones
	end
	for i = #targets, 1, -1 do
		if not los_any or not los_targets[i] then
			for _, zone in ipairs(zones) do
				table.remove_value(zone.units, targets[i])
			end
			table.remove(targets, i)
		end
	end
	-- check chance to hit
	local targets_attack_data = GetLoFData(unit, targets, {
		obj = unit,
		action_id = context.default_attack.id,
		weapon = weapon,
		stance = unit.stance,
		range = max_distance,
		target_spot_group = "Torso",
		prediction = true,
	})
	local action = CombatActions[action_id]
	local args = { target_spot_group = false }
	for i, attack_data in ipairs(targets_attack_data) do
		local target = targets[i]
		local chance_to_hit = 0
		if attack_data and not attack_data.stuck then
			for j, hit_info in ipairs(attack_data.lof) do
				if not check_ally or hit_info.ally_hits_count == 0 then
					args.target_spot_group = hit_info.target_spot_group
					chance_to_hit = unit:CalcChanceToHit(target, action, args, "chance_only")
					if chance_to_hit > 0 then
						break
					end
				end
			end
		end
		if chance_to_hit == 0 then
			for _, zone in ipairs(zones) do
				table.remove_value(zone.units, target)
			end
		end
	end
	return zones
end

local function IsUnitHit(hit)
	if not IsKindOf(hit.obj, "Unit") then return false end
	if hit.damage > 0 then return true end
	for _, effect in ipairs(hit.effects) do
		if effect and effect ~= "" then
			return true
		end
	end
end

function AIPrecalcGrenadeZones(context, action_id, min_range, max_range, blast_radius, aoeType)
	if context.target_locked then return {} end
	
	local target_pts = AICalcAOETargetPoints(context, min_range, max_range, blast_radius)

	-- calculate parabolas and affected units to each target point
	local zones = {}
	local action = CombatActions[action_id]
	local args = { target = false }
	for i, target_pt in ipairs(target_pts) do
		args.target = target_pt
		local results = action:GetActionResults(context.unit, args)
		
		local units
		local trajectory = results.trajectory or empty_table
		local pos = #trajectory > 0 and trajectory[#trajectory].pos or results.target_pos
		if pos and (aoeType == "smoke" or aoeType == "toxicgas" or aoeType == "teargas") then
			local water = terrain.IsWater(pos) and terrain.GetWaterHeight(pos)
			if not (water and (not pos:IsValidZ() or water >= pos:z())) then
				pos = SnapToPassSlab(pos) or pos
				local dx, dy = 1, 1
				for i = #trajectory - 1, 1, -1 do
					local step = trajectory[i]
					if step.pos:Dist2D(pos) > 0 then
						local px, py = step.pos:xy()
						local x, y = pos:xy()
						dx = (px == x) and 1 or ((x - px) / abs(x - px))
						dy = (py == y) and 1 or ((y - py) / abs(y - py))
						break
					end
				end
				
				local gx, gy, gz = WorldToVoxel(pos)
				local smoke, blocked = PropagateSmokeInGrid(gx, gy, gz, dx, dy)
				local smoke_voxels = {}
				for _, wpt in pairs(smoke) do
					local ppos = point_pack(WorldToVoxel(wpt))
					smoke_voxels[ppos] = true
				end
				
				for _, unit in ipairs(g_Units) do
					local _, head = unit:GetVisualVoxels()
					if smoke_voxels[head] then
						units = units or {}
						table.insert(units, unit)
					end
				end
			end
		else
			for _, hit in ipairs(results) do
				if IsUnitHit(hit) then
					units = units or {}
					table.insert(units, hit.obj)
				end
			end
		end
		if units then
			zones[#zones + 1] = { target_pos = target_pt, units = units }
		end
	end

	--print("grenade targeting precalc in", GetPreciseTicks() - tstart, "ms")
	return zones
end

function AIPrecalcLandmineZones(context)
	if context.target_locked then return {} end

	local weapon = context.weapon
	if not IsKindOf(weapon, "Firearm") then
		return {}
	end
	if not context.mine_zones then
		local unit = context.unit
		local sight = unit:GetSightRadius()
		local max_range = Min(weapon.WeaponRange * const.SlabSizeX, sight)
		local landmines = MapGet(unit, max_range, "Landmine", function(o, unit) 
			return o:SeenBy(unit)
		end, unit)
		local zones = {}
		for _, mine in ipairs(landmines) do
			local aoe_params = mine:GetAreaAttackParams(nil, unit, mine:GetPos())
			aoe_params.prediction = true
			local results = GetAreaAttackResults(aoe_params, 0)
			local units
			for _, hit in ipairs(results) do
				if IsKindOf(hit.obj, "Unit") and hit.damage > 0 then
					if not units then
						units = {}
					end
					table.insert(units, hit.obj)
				end
			end
			if units then
				zones[#zones + 1] = { target = mine, units = units }
			end
		end
		context.mine_zones = zones
	end
	return context.mine_zones
end

function AISelectHealTarget(context, dest, grid_voxel, heal_policy)
	if context.voxel_heal_score[grid_voxel] then
		return context.voxel_heal_target[grid_voxel], context.voxel_heal_score[grid_voxel]
	end
	
	local x, y, z = point_unpack(grid_voxel)
	local best_target, best_score = false, 0
	local dx, dy, dz = stance_pos_unpack(dest)
	local ppos = point_pack(dx, dy, dz)
	
	for _, ally in ipairs(context.allies) do
		local hpp = MulDivRound(ally.HitPoints, 100, ally.MaxHitPoints)
		local score
		if hpp <= heal_policy.MaxHp and not ally:IsDead() then
			local bleed = 0
			if ally:HasStatusEffect("Bleeding") then
				bleed = heal_policy.BleedingWeight
			end
			
			local gx, gy, gz = point_unpack(context.ally_grid_voxel[ally])
			if ally == context.unit or IsMeleeRangeTarget(context.unit, ppos, nil, ally) then --(abs(x - gx) <= 1 and abs(y - gy) <= 1 and abs(z - gz) <= 1) then
				score = MulDivRound(100 - hpp, heal_policy.HpWeight, 100) + bleed
			end
			
			if ally == context.unit then
				score = MulDivRound(score, heal_policy.SelfHealMod, 100)
			end
		end
		
		score = score or 0
		if not best_score or score > best_score then
			best_target, best_score = ally, score
		end
	end
	
	local ap_at_dest = context.dest_ap[dest] or 0
	if ap_at_dest >= CombatActions.Bandage.ActionPoints then
		best_score = MulDivRound(best_score, heal_policy.CanUseMod, 100)
	end
	
	context.voxel_heal_target[grid_voxel] = best_target
	context.voxel_heal_score[grid_voxel] = best_score
	
	return best_target, best_score
end

function AIEvalStimTarget(unit, target, rules)
	if target:IsDead() or target:HasStatusEffect("Stimmed") then
		return 0
	end
	
	local score = 0
	for _, rule in ipairs(rules) do
		if table.find(ally.AIKeywords or empty_table, rule.Keyword) then
			score = score + rule.Weight
		end
	end
	return score
end

local AITurnPhasePriority = {
	Early = 1,
	Normal = 2,
	Late = 3,
}

function AIGetNextPhaseUnits(units, max)
	local best_units, best_prio
	
	for _, unit in ipairs(units) do
		local behavior = unit.ai_context and unit.ai_context.behavior
		if behavior then 			
			local turn_phase = behavior:GetTurnPhase(unit)
		
			local prio = AITurnPhasePriority[turn_phase] or 999
			if not best_prio or prio < best_prio then
				best_units, best_prio = {unit}, prio
			elseif prio == best_prio then
				best_units[#best_units + 1] = unit
			end
			if max and #(best_units or empty_table) >= max then 
				break
			end
		end
	end
	return best_units
end

function IsMeleeRangeTarget(attacker, attack_pos, attack_stance, target, target_pos, target_stance, attacker_face_angle)
	if not IsValidTarget(target) then return end
	if IsSittingUnit(target) then
		target_pos = target_pos or target.last_visit:GetPos()
		target_stance = "Crouch"
	end
	return IsMeleeRangeTargetC(attacker, attack_pos, attack_stance, target, target_pos, target_stance, attacker_face_angle)
end

function GetMeleeRangePositions(attacker, target, target_pos, check_occupied)
	if IsSittingUnit(target) then
		target_pos = target.last_visit:GetPos()
	end
	return GetMeleeRangePositionsC(attacker, target, target_pos, check_occupied)
end

function GetClosestMeleeRangePos(attacker, target, target_pos, check_occupied)
	if IsSittingUnit(target) then
		target_pos = target.last_visit:GetPos()
	end
	return GetClosestMeleeRangePosC(attacker, target, target_pos, check_occupied)
end

function AIRangeCheck(context, ppt1, target, ppt2, range_type, range_min, range_max)
	if range_type == "Melee" then
		local p1 = point_pack(VoxelToWorld(point_unpack(ppt1)))
		local p2 = point_pack(VoxelToWorld(point_unpack(ppt2)))
		return IsMeleeRangeTarget(context.unit, p1, context.unit.stance, target, p2, target.stance)
	end
	if range_type ~= "Absolute" then
		-- weapon range based
		assert(range_type == "Weapon")
		local base_range = context.ExtremeRange
		range_min = range_min and MulDivRound(range_min, base_range, 100)
		range_max = range_max and MulDivRound(range_max, base_range, 100)
	end
	local x1, y1, z1 = point_unpack(ppt1)
	local x2, y2, z2 = point_unpack(ppt2)
	if (range_min or 0) > 0 and IsCloser(x1, y1, z1, x2, y2, z2, range_min) then
		return false
	end
	if (range_max or 0) > 0 and not IsCloser(x1, y1, z1, x2, y2, z2, range_max + 1) then
		return false
	end
	return true
end

function AIReloadWeapons(unit)
	local firearms = select(3, unit:GetActiveWeapons("Firearm"))
	table.iappend(firearms, select(3, unit:GetActiveWeapons("HeavyWeapon")))
	for _, firearm in ipairs(firearms) do
		if not firearm.ammo then
			local ammos = unit:GetAvailableAmmos(firearm) or empty_table
			local ammo
			if #ammos > 0 then
				ammo = ammos[1]
				ammo.Amount = Max(ammo.Amount, firearm.MagazineSize)
				unit:ReloadWeapon(firearm, ammo, "delay fx", "ai")
				CreateFloatingText(unit, T(160472488023, "Reload"))
				ObjModified(unit)
			else
				ammos = GetAmmosWithCaliber(firearm.Caliber, "sorted")
				if #ammos > 0 then
					ammo = PlaceInventoryItem(ammos[1].id)
					ammo.Amount = firearm.MagazineSize
					unit:ReloadWeapon(firearm, ammo, "delay fx", "ai")
					CreateFloatingText(unit, T(160472488023, "Reload"))
					DoneObject(ammo)
					ObjModified(unit)
				end
			end
		elseif firearm.ammo.Amount < Max(1, firearm.MagazineSize / 2) then
			local ammo = firearm.ammo
			ammo.Amount = firearm.MagazineSize
			unit:ReloadWeapon(firearm, ammo, "delay fx", "ai")
			CreateFloatingText(unit, T(160472488023, "Reload"))
			ObjModified(unit)
		end
	end
end

function AIPickScoutLocation(unit)
	local AIScoutLocationSearchRadius = 5 * guim

	-- pick a new position around alive enemy randomly, prefer non-hidden enemies
	local enemies = GetAllEnemyUnits(unit)
	
	if #enemies == 0 then
		return
	end

	local targets
	local nearest, nearby = {}, {}
	for _, enemy in ipairs(enemies) do
		local dist = unit:GetDist(enemy)
		if dist <= AIScoutLocationSearchRadius then
			nearest[#nearest + 1] = enemy
			targets = nearest
		elseif dist <= 2*AIScoutLocationSearchRadius then
			nearby[#nearby + 1] = enemy
			targets = targets or nearby
		end
	end
	targets = targets or enemies
	local enemy = table.interaction_rand(enemies, "Combat")
	
	local ux, uy, uz = enemy:GetGridCoords()
	local px, py, pz = VoxelToWorld(ux, uy, uz)
	local r = AIScoutLocationSearchRadius
	local bbox = box(px - r, py - r, 0, px + r + 1, py + r + 1, MapSlabsBBox_MaxZ)
	
	local dests, dest_added = {}, {}
	local function push_dest(x, y, z, dests, dest_added, ux, uy, uz)
		local gx, gy, gz = WorldToVoxel(x, y, z)
		
		if not IsCloser(gx, gy, gz, ux, uy, uz, AIScoutLocationSearchRadius) then
			return
		end
				
		local world_voxel = point_pack(x, y, z)
		if not dest_added[world_voxel] then
			dests[#dests + 1] = world_voxel
			dest_added[world_voxel] = true
		end		
	end
	
	ForEachPassSlab(bbox, push_dest, dests, dest_added, ux, uy, uz)
	
	if #dests > 0 then
		local voxel = table.interaction_rand(dests, "Combat")
		local x, y, z = point_unpack(voxel)
		return point(x, y, z)
	end	
end

function AIUpdateScoutLocation(unit)
	if not unit.last_known_enemy_pos then
		return
	end
	local sight = unit:GetSightRadius()
	if CheckLOS(unit.last_known_enemy_pos, unit, sight) then
		-- scouted here, next time pick a different location if still necessary
		unit.last_known_enemy_pos = nil
	end
end

MapVar("g_MGPriorityAssignment", {})

function AIAssignToEmplacements(team)
	local emplacements = MapGet("map", "MachineGunEmplacement")

	local units = table.copy(team.units)
	units = table.ifilter(units, function(idx, unit) return unit.CanManEmplacements end)

	-- update emplacements' appeal for the team
	for _, emplacement in ipairs(emplacements) do
		local targets = #units > 0 and emplacement:GetEnemyUnitsInArea(units[1]) or empty_table
		local appeal = MulDivRound(emplacement.appeal[team.side] or 0, Max(0, 100 - emplacement.appeal_decay), 100)
		for _, enemy in ipairs(targets) do
			local dist = emplacement:GetDist(enemy)
			local diff = abs(dist - emplacement.appeal_optimal_dist)
			appeal = appeal + Max(0, emplacement.appeal_per_target + MulDivRound(emplacement.appeal_per_meter, dist, guim))
		end
		emplacement.appeal[team.side] = appeal
		if not SpawnedByEnabledMarker(emplacement) or not emplacement.enabled then
			emplacement.appeal[team.side] = 0
		end
	end
	
	if emplacements then
		table.sort(emplacements, function(a, b) return a.appeal[team.side] > b.appeal[team.side] end)
	end
				
	for _, emplacement in ipairs(emplacements) do				
		local assigned_unit = g_Combat:GetEmplacementAssignment(emplacement)
		
		if (emplacement.appeal[team.side] or 0) > emplacement.appeal_use_threshold then
			if not emplacement.manned_by and not assigned_unit then
				-- free for grabs, find a unit to man the MG
				
				-- check priority assignment first
				local gunner
				for _, unit in ipairs(g_MGPriorityAssignment) do
					if IsValidTarget(unit) and unit.team == team and not unit:IsIncapacitated() then
						gunner = unit
						break
					end
				end
				
				if not gunner then
					local emplacement_pos = SnapToPassSlab(emplacement:GetPosXYZ())
					if emplacement_pos then
						table.sort(units, function(a, b) return IsCloser(emplacement_pos, a, b) end)
						local closest, closest_pf_dist
						for _, u in ipairs(units) do
							-- select unit closest to the emplacement (by pathfind)
							local emp = g_Combat:GetEmplacementAssignment(u)
							if not emp and (not closest or IsCloser(u, emplacement_pos, closest_pf_dist)) then
								local has_path, path_len, closest_pos = pf.PosPathLen(u, emplacement_pos, nil, 0, 0, u, 0, nil, 0)
								if has_path and closest_pos == emplacement_pos then
									if not closest_pf_dist or path_len < closest_pf_dist then
										closest, closest_pf_dist = u, path_len
									end
								end
							end
						end
						gunner = closest
					end
				end
				if gunner then
					g_Combat:AssignEmplacement(emplacement, gunner)
				end
			elseif assigned_unit and assigned_unit.team == team then
				if emplacement.manned_by and emplacement.manned_by ~= assigned_unit then
					-- somebody else took it, clean up assignment
					g_Combat:AssignEmplacement(emplacement, nil)
				end
			end
		elseif assigned_unit and assigned_unit.team == team then
			g_Combat:AssignEmplacement(emplacement, nil)
		end
	end
end

function AIEnemyWeaponsCombo()
	local types = table.map(GetWeaponTypes(), "id")
	table.insert_unique(types, "Pistol")
	table.insert_unique(types, "Revolver")
	table.insert_unique(types, "MeleeWeapon")
	table.insert_unique(types, "Unarmed")
	return types
end

function measure_func(func, num_invocations, ...)
	num_invocations = num_invocations or 0
	if num_invocations < 1 then 
		return 
	end
 
	local start = GetPreciseTicks()
	
	for i = 1, num_invocations do
		func(...)
	end
	local elapsed_ms = GetPreciseTicks() - start
	printf("%d invocations finished in %d ms for (%d ms average)", num_invocations, elapsed_ms, elapsed_ms / num_invocations)
end

DefineClass.AIBiasMarker = {
	__parents = { "GridMarker" },
	properties = {
		{ category = "AI Bias", id = "UnitGroups", name = "UnitGroups", editor = "string_list", default = false, items = function (self) return GetUnitGroups() end },
		{ category = "AI Bias", id = "Bias", editor = "number", min = 0, max = 1000, scale = "%", slider = true, default = 100, help = "modifier applied to AI evaluations of destinations inside the marker area"},		
	},
}

function AIBiasMarker:GetAIBias(unit, dest)
	if not unit or not self:IsMarkerEnabled() then return 100 end
	local x, y, z = stance_pos_unpack(dest)
	z = z or terrain.GetHeight(x, y)
	x, y = WorldToVoxel(x, y, z)
	if not self:IsVoxelInsideArea2D(x, y) then
		return 100
	end

	local apply_groups = g_BiasMarkers[self] or empty_table	
	for _, group in ipairs(unit.Groups) do
		if apply_groups[group] then
			return self.Bias
		end
	end
	return 100
end

function InitAIBiasMarkers()
	g_BiasMarkers = g_BiasMarkers or MapGetMarkers("GridMarker", nil, function(m) return IsKindOf(m, "AIBiasMarker") end) or false
	for _, marker in ipairs(g_BiasMarkers) do
		local apply_grous = {}
		g_BiasMarkers[marker] = apply_grous
		for _, group in ipairs(marker.UnitGroups) do
			apply_grous[group] = true
		end
	end
end

function AICheckIndoors(dest)
	if g_AIDestIndoorsCache[dest] == nil then
		local x, y, z = stance_pos_unpack(dest)
		local volume = EnumVolumes(point(x, y, z), "smallest")
		g_AIDestIndoorsCache[dest] = not not volume
	end
	return g_AIDestIndoorsCache[dest]
end