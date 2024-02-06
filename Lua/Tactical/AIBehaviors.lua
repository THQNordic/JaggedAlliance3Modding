-- base AI behavior class
DefineClass.AIBehavior = {
	__parents = { "AIBiasObj" },
	properties = {
		{ id = "Label", editor = "text", default = "", },
		{ id = "Comment", editor = "text", default = "" },
		{ id = "Fallback", editor = "bool", default = true, help = "When enabled, this behavior will be considered the go-to fallback behavior for specific uses, like GuardArea archetype. If multiple behaviors are marked as Fallback, only the first one will be used." },
		{ id = "RequiredKeywords", editor = "string_list", default = {}, item_default = "", items = AIKeywordsCombo, arbitrary_value = true, },
		{ id = "Score", editor = "func", params = "self, unit, proto_context, debug_data", default = function(self, unit, proto_context, debug_data) return self.Weight end, },
		{ id = "turn_phase", name = "Turn Phase", editor = "choice", default = "Normal", items = function (self) return { "Early", "Normal", "Late" } end, },
		{ id = "OptLocWeight", name = "Optimal Location Weight", editor = "number", default = 100, help = "How important is moving toward optimal location", },
		{ id = "EndTurnPolicies", name = "End-of-Turn Location Policies", editor = "nested_list", default = false, base_class = "AIPositioningPolicy", class_filter = function (name, class, obj) return class.end_of_turn end, },
		{ id = "SignatureActions", name = "Signature Actions", help = "Actions specific to this behavior; if the list isn't empty the action used will be chosen from it instead of the archetype's list",
			editor = "nested_list", default = false, base_class = "AISignatureAction", class_filter = function (name, class, obj) return not class.hidden end, },
		{ id = "TargetingPolicies", name = "Targeting Policies", help = "Additoinal targeting policies that modify target score (optional)", 
			editor = "nested_list", default = false, base_class = "AITargetingPolicy", },
		{ id = "TakeCoverChance", name = "Take Cover Chance", editor = "number", min = 0, max = 100, scale = "%", default = 20, help = "chance to use Take Cover action at the end of the turn when in a cover spot" },
	},
}

function AIBehavior:MatchUnit(unit)
	for _, keyword in ipairs(self.RequiredKeywords) do
		if not table.find(unit.AIKeywords or empty_table, keyword) then
			return
		end
	end
	return true
end

function AIBehavior:GetEditorView()
	local label = self.Label ~= "" and self.Label or self.class
	local text = string.format("%s%s (%s)", self.Priority and "Priority " or "", label, self.Weight)
	
	if self.Comment ~= "" then
		text = text .. string.format(" -> %s", self.Comment)
	end
	
	return text
end

function AIBehavior:OnStart(unit)
	self:OnActivate(unit)
end

function AIBehavior:EnumDestinations(unit, context)
	AIFindDestinations(unit, context)
end

function AIBehavior:Think(unit, debug_data)
end

function AIBehavior:GetTurnPhase(unit)
	return unit:IsThreatened() and "Late" or self.turn_phase
end

function AIBehavior:BeginStep(label, debug_data)
	if not debug_data then return end	
	debug_data.thihk_steps = debug_data.thihk_steps or {}
	assert(not debug_data.thihk_steps[label])
	
	local step = { label = label, start_time = GetPreciseTicks() }
	table.insert(debug_data.thihk_steps, step)
	debug_data.thihk_steps[label] = step
end

function AIBehavior:EndStep(label, debug_data)
	if not debug_data then return end
	local step = debug_data.thihk_steps[label]
	assert(step)
	step.time = GetPreciseTicks() - step.start_time
end

function AIBehavior:TakeStance(unit)
	local context = unit.ai_context
	if not context or unit.species ~= "Human" then 
		return 
	end
	
	if context.movement_action then
		return
	end
	
	local upos = context.unit_stance_pos or stance_pos_pack(unit, unit.stance)
	local dest = context.ai_destination
	if not dest or stance_pos_dist(dest, upos) == 0 then
		-- go in pref stance if already in ai_destination
		if unit.stance ~= context.archetype.PrefStance then
			local target = context.dest_target[dest]
			local ap = Max(0, GetStanceToStanceAP(unit.stance, context.archetype.PrefStance) or 0)
			local cost = context.default_attack_cost
			local reserved = IsValidTarget(target) and cost or 0
			local uiAP = unit:GetUIActionPoints()
			if uiAP > ap + cost then
				-- check LOF for non-melee weapons first
				local max_check_range, is_melee = AIGetWeaponCheckRange(unit, context.weapon, context.default_attack)
				if not is_melee then
					local targets = context.default_attack:GetTargets({unit})
					if #targets == 0 then
						return
					end
					local targets_attack_data = GetLoFData(unit, targets, {
						obj = unit,
						action_id = context.default_attack.id,
						weapon = context.weapon,
						stance = context.archetype.PrefStance,
						range = max_check_range,
						target_spot_group = "Torso",
						prediction = true,
					})
					local any_lof = false
					for k, target in ipairs(targets) do
						local attack_data = targets_attack_data[k]
						if attack_data and not attack_data.stuck and not attack_data.best_ally_hits_count then
							any_lof = true
							break
						end
					end
					if not any_lof then return end
				end
				local target_pos = IsValidTarget(target) and target:GetPos() or nil
				AIPlayChangeStance(unit, context.archetype.PrefStance, target_pos)
			end
		end
	else
		local move_stance_idx = context.dest_combat_path[dest]
		local goto_stance = StancesList[move_stance_idx]
		if goto_stance ~= unit.stance then
			local x, y, z, stance_idx = stance_pos_unpack(dest)
			local px, py, pz = SnapToPassSlabXYZ(x, y, z)
			local cpath = context.combat_paths[move_stance_idx]
			local dest_prev_ppos = px and cpath and cpath.paths_prev_pos and cpath.paths_prev_pos[point_pack(px, py, pz)]
			if dest_prev_ppos then
				if not AIPlayChangeStance(unit, goto_stance, point(point_unpack(dest_prev_ppos))) then
					-- failed, abort movement
					assert(CanOccupy(unit, GetPassSlab(unit)))
					context.ai_destination = false
				end
			end
		end
	end
end

function AIBehavior:BeginMovement(unit, trackMove)
	local context = unit.ai_context
	local dest = context.ai_destination
	local upos = stance_pos_pack(unit, unit.stance)
	
	if not dest or (stance_pos_dist(dest, upos) == 0) then
		return "continue"
	end
	
	local x, y, z, stance_idx = stance_pos_unpack(dest)
	local move_stance_idx = context.dest_combat_path[dest]
	local cpath = context.combat_paths[move_stance_idx]
	local pt = SnapToPassSlab(x, y, z)
	local path = pt and cpath and cpath:GetCombatPathFromPos(pt)
	local goto_ap = cpath and cpath.paths_ap[point_pack(pt)] or 0

	if not context.reposition and context.movement_action then
		local retval = context.movement_action:Execute(context, context.action_states[context.movement_action])
		if retval ~= "restart" and IsKindOf(context.movement_action, "AIActionMobileShot") then
			context.max_attacks = context.max_attacks - 1
		end
		return retval
	end

	if not path then 
		return false 
	end
	local move_args = {
		goto_pos = point(point_unpack(path[1])),
		reposition = context.reposition,
		forced_run = context.forced_run,
		trackMove = trackMove,
	}
	if stance_idx ~= move_stance_idx then
		move_args.toDoStance = StancesList[stance_idx]
	end
	assert(CanOccupy(unit, move_args.goto_pos))	
	if not AIStartCombatAction("Move", unit, goto_ap, move_args) then
		return false
	end
	
	while IsValid(unit) and not unit:IsDead() and (HasCombatActionWaiting(unit) or HasCombatActionInProgress(unit)) do
		local ok, obj = WaitMsg("CombatActionStateChange", 10)
		if ok and obj == unit then
			local state = CombatActions_RunningState[unit]
			if not state or state == "PostAction" then
				break
			end
		end
	end
	local state = CombatActions_RunningState[unit]
	if (not state or state == "PostAction") and not unit:IsDead() then
		return "continue"
	end
	return false
end

function AIBehavior:EndMovement(unit)
	local context = unit.ai_context
	local dest = context.ai_destination
	if not dest or unit.species ~= "Human" or unit:IsIncapacitated() then return end
	local upos = GetPackedPosAndStance(unit)
	if stance_pos_dist(dest, upos) == 0 then
		local x, y, z, stance_idx = stance_pos_unpack(dest)
		local stance = StancesList[stance_idx]
		if unit.stance ~= stance and not unit:HasStatusEffect("StationedMachineGun") and not unit:HasStatusEffect("ManningEmplacement") then
			unit:DoChangeStance(stance)
		end
	end
end

function AIBehavior:Play(unit)
end

function AIBehavior:GetSignatureActions(context)
	return self.SignatureActions
end

----------------------------------------
-- Standard AI behavior
----------------------------------------

DefineClass.StandardAI = {
	__parents = { "AIBehavior" },
	properties = {
		{ category = "Default Attack Override", id = "override_attack_id", name = "Score Attack Id", editor = "combo", items = PresetGroupCombo("CombatAction", "WeaponAttacks"), default = "", help = "attack to use instead of the weapon's default attack to calculate damage score"},
		{ category = "Default Attack Override", id = "override_cost_id", name = "Cost Attack Id", editor = "combo", items = PresetGroupCombo("CombatAction", "WeaponAttacks"), default = "", help = "attack to use instead of the weapon's default attack to calculate attack cost"},
	},
}

function StandardAI:Think(unit, debug_data)
	self:BeginStep("think", debug_data)
		local context = unit.ai_context
	
		self:BeginStep("destinations", debug_data)
			AIFindDestinations(unit, context)
		self:EndStep("destinations", debug_data)
	
		self:BeginStep("optimal location", debug_data)
			AIFindOptimalLocation(context, debug_data and debug_data.optimal_scores)
		self:EndStep("optimal location", debug_data)
	
		self:BeginStep("end of turn location", debug_data)
			AICalcPathDistances(context)
			if self.override_attack_id ~= "" then
				context.override_attack_id = self.override_attack_id
			end
			if self.override_cost_id and CombatActions[self.override_cost_id] then
				context.override_attack_cost = CombatActions[self.override_cost_id]:GetAPCost(unit)
			end
			AIPrecalcDamageScore(context)
			context.override_attack_id = nil
			context.override_attack_cost = nil
			unit.ai_context.ai_destination = AIScoreReachableVoxels(context, self.EndTurnPolicies, self.OptLocWeight, debug_data and debug_data.reachable_scores)
		self:EndStep("end of turn location", debug_data)
		self:BeginStep("movement action", debug_data)
			context.movement_action = AIChooseMovementAction(context)
		self:EndStep("movement action", debug_data)
	self:EndStep("think", debug_data)
end

----------------------------------------
-- Retreat AI behavior
----------------------------------------

DefineClass.RetreatAI = {
	__parents = { "AIBehavior" },
	properties = {
		{ id = "DespawnAllowed", editor = "bool", default = true },
	},
}

function RetreatAI:Think(unit, debug_data)
	local context, destinations
	
	if not unit.ai_context.destinations then return end
	
	self:BeginStep("think", debug_data)
		context = unit.ai_context

		self:BeginStep("destinations", debug_data)
			AIFindDestinations(unit, context)
		self:EndStep("destinations", debug_data)
					
		context.entrance_markers = MapGetMarkers("Entrance")
		
		if not self:CanDespawn(unit) then
			self:BeginStep("optimal location", debug_data)
				AIFindOptimalLocation(context, debug_data and debug_data.optimal_scores)
			self:EndStep("optimal location", debug_data)
			
			self:BeginStep("end of turn location", debug_data)
				AICalcPathDistances(context)
				unit.ai_context.ai_destination = AIScoreReachableVoxels(context, self.EndTurnPolicies, self.OptLocWeight, debug_data and debug_data.reachable_scores)
			self:EndStep("end of turn location", debug_data)
			self:BeginStep("movement action", debug_data)
				context.movement_action = AIChooseMovementAction(context)
			self:EndStep("movement action", debug_data)
		else
			if debug_data then
				debug_data.optimal_scores[context.unit_stance_pos] = { "despawn", 100 }
			end
		end
	self:EndStep("think", debug_data)
end

function RetreatAI:CanDespawn(unit)
	if not self.DespawnAllowed then return false end	
	local context = unit.ai_context
	local pos = GetPassSlab(unit)
	local wx, wy, wz = pos:xyz()	
	local unit_stance_pos = stance_pos_pack(wx, wy, wz, StancesList[unit.stance])
	
	-- unseen?
	if not AIHasLOSToEnemyFromDest(unit_stance_pos) and unit_stance_pos == context.unit_stance_pos then
		return true
	end

	-- inside entrance marker area?
	local vx, vy = unit:GetGridCoords()
	for _, marker in ipairs(context.entrance_markers) do
		if marker:IsVoxelInsideArea(vx, vy) then
			return true
		end
	end
end

function RetreatAI:Play(unit)
	-- check for despawn conditions, despawn
	local pos = GetPassSlab(unit)
	local wx, wy, wz = pos:xyz()
	local unit_stance_pos = stance_pos_pack(wx, wy, wz, StancesList[unit.stance])
	local context = unit.ai_context
	
	if self:CanDespawn(unit) then
		AIPlayCombatAction("Despawn", unit)
	end
	return "done" -- skip attacks for this unit
end

----------------------------------------
-- Positioning AI behavior
----------------------------------------

function PositioningAIScore(self, unit, proto_context, debug_data)
	unit.ai_context = unit.ai_context or AICreateContext(unit, proto_context)
	local dest, score = AIScoreReachableVoxels(unit.ai_context, self.EndTurnPolicies, 0)
	return MulDivRound(score, self.Weight, 100)
end

DefineClass.PositioningAI = {
	__parents = { "AIBehavior" },
	properties = {
		{ id = "VoiceResponse", name = "Voice Response", editor = "text", default = "", help = "voice response to play on activation of this behavior", },
		{ id = "Score", editor = "func", params = "self, unit, proto_context, debug_data", default = PositioningAIScore, },
	},
}

function PositioningAI:Think(unit, debug_data)
	local context = unit.ai_context

	self:BeginStep("think", debug_data)	
		self:BeginStep("destinations", debug_data)
			AIFindDestinations(unit, context)
		self:EndStep("destinations", debug_data)
		self:BeginStep("positioning dest", debug_data)
			context.positioning_dest = AIScoreReachableVoxels(context, self.EndTurnPolicies, 0, debug_data and debug_data.reachable_scores)				
			context.ai_destination = context.positioning_dest
		self:EndStep("positioning dest", debug_data)
		self:BeginStep("movement action", debug_data)
			context.movement_action = AIChooseMovementAction(context)
		self:EndStep("movement action", debug_data)
	self:EndStep("think", debug_data)
end

function PositioningAI:BeginMovement(unit)
	local context = unit.ai_context
	if not context or not context.positioning_dest then
		return "restart"
	end
	if (self.VoiceResponse or "") ~= "" then
		PlayVoiceResponse(unit, self.VoiceResponse)
	end
	return AIBehavior.BeginMovement(self, unit)
end

----------------------------------------
-- HoldPosition AI behavior
----------------------------------------
DefineClass.HoldPositionAI = {
	__parents = { "AIBehavior" },
	properties = {
		{ id = "VoiceResponse", name = "Voice Response", editor = "text", default = "", help = "voice response to play on activation of this behavior", },
		{ id = "Score", editor = "func", params = "self, unit, proto_context, debug_data", default = function(self, unit) return self.Weight end, },
	},
}

function HoldPositionAI:OnStart(unit)
	AIBehavior.OnStart(self, unit)
	
	if (self.VoiceResponse or "") ~= "" then
		PlayVoiceResponse(unit, self.VoiceResponse)
	end
end

function HoldPositionAI:Think(unit, debug_data)
	local context = unit.ai_context
	self:BeginStep("think", debug_data)
		--local dest = context.voxel_to_dest[context.unit_world_voxel]		
		--local dests = dest and {dest} or nil
		local dests = { GetPackedPosAndStance(unit) }
		AIPrecalcDamageScore(context, dests)
	self:EndStep("think", debug_data)
end

----------------------------------------
-- Approach Interactable AI behavior
----------------------------------------

DefineClass.ApproachInteractableAI = {
	__parents = { "AIBehavior" },
}

function ApproachInteractableAI:Think(unit, debug_data)
	local interactable = unit.ai_context and unit.ai_context.target_interactable
	if not interactable then
		assert(false, "ApproachInteractableAI doesn't have a target_interactable set")
		return
	end
	
	self:BeginStep("think", debug_data)
		local context = unit.ai_context
	
		self:BeginStep("destinations", debug_data)
			AIFindDestinations(unit, context)
		self:EndStep("destinations", debug_data)
	
		-- skip evaluation of optimal locations, use the interactable position
		local interaction_pos = unit:GetInteractionPosWith(interactable) or interactable:GetPos()
		context.best_dest = stance_pos_pack(interaction_pos, unit.stance)
	
		self:BeginStep("end of turn location", debug_data)
			AICalcPathDistances(context)
			AIPrecalcDamageScore(context)
			unit.ai_context.ai_destination = AIScoreReachableVoxels(context, self.EndTurnPolicies, self.OptLocWeight, debug_data and debug_data.reachable_scores)
		self:EndStep("end of turn location", debug_data)
		self:BeginStep("movement action", debug_data)
			context.movement_action = AIChooseMovementAction(context)
		self:EndStep("movement action", debug_data)
	self:EndStep("think", debug_data)
end

function ApproachInteractableAI:BeginMovement(unit)
	local result = self:Play(unit)
	if result == "restart" then
		return result
	end
	return AIBehavior.BeginMovement(self, unit)
end

function ApproachInteractableAI:EndMovement()
end

function ApproachInteractableAI:Play(unit)
	local interactable = unit.ai_context and unit.ai_context.target_interactable
	
	local action = CombatActions.Interact
	local args = {target = interactable, override_ap_cost = 0 }
	
	args.goto_pos = unit:GetInteractionPosWith(interactable) or interactable:GetPos()
	args.goto_ap = args.goto_pos ~= SnapToVoxel(unit:GetPos()) and CombatActions.Move:GetAPCost(unit, { goto_pos = args.goto_pos, stance = unit.stance }) or 0
	
	local state = action:GetUIState({unit}, args)
	if state == "enabled" then
		local result = AIPlayCombatAction("Interact", unit, nil, args)
		assert(result, "AI unit wasn't able to interact")
		if result then
			return "restart"
		end
	else
		-- unassign ourselves, somebody else might have a better chance of using it		
		if g_Combat:GetEmplacementAssignment(interactable) == unit then
			g_Combat:AssignEmplacement(interactable, nil)
		end
	end	
end

----------------------------------------
-- Custom AI behavior
----------------------------------------

DefineClass.CustomAI = {
	__parents = { "AIBehavior" },
	properties = {
		{ id = "EnumDests", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "PickEndTurnPolicies", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "EvalDamageScore", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "PickOptimalLoc", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "PickEndTurnLoc", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "SelectSignatureActions", editor = "func", params = "self, unit, context, debug_data", default = empty_func },
		{ id = "Execute", editor = "func", params = "self, unit, context, debug_data", default = empty_func },		
	},
}

function CustomAI:EnumDestinations(unit, context)
	if not self:EnumDests(unit, context) then
		AIFindDestinations(unit, context)
	end
end

function CustomAI:Think(unit, debug_data)
	self:BeginStep("think", debug_data)
		local context = unit.ai_context
	
		self:BeginStep("enum dests", debug_data)
			self:EnumDestinations(unit, context)
		self:EndStep("enum dests", debug_data)
		
		self:BeginStep("optimal location", debug_data)
			if not self:PickOptimalLoc(unit, context, debug_data) then
				AIFindOptimalLocation(context, debug_data and debug_data.optimal_scores)
			end
		self:EndStep("optimal location", debug_data)
	
		self:BeginStep("end of turn location", debug_data)
			if self.override_attack_id ~= "" then
				context.override_attack_id = self.override_attack_id
			end
			if self.override_cost_id and CombatActions[self.override_cost_id] then
				context.override_attack_cost = CombatActions[self.override_cost_id]:GetAPCost(unit)
			end
			if not self:EvalDamageScore(unit, context) then
				AIPrecalcDamageScore(context)
			end
			context.override_attack_id = nil
			context.override_attack_cost = nil
			if not self:PickEndTurnLoc(unit, context, debug_data) then
				local policies = self:PickEndTurnPolicies(unit, context) or self.EndTurnPolicies
				unit.ai_context.ai_destination = AIScoreReachableVoxels(context, policies, self.OptLocWeight, debug_data and debug_data.reachable_scores)
			end
		self:EndStep("end of turn location", debug_data)
		self:BeginStep("movement action", debug_data)
			context.movement_action = AIChooseMovementAction(context)
		self:EndStep("movement action", debug_data)
	self:EndStep("think", debug_data)
end

function CustomAI:Play(unit)
	return self:Execute(unit, unit.ai_context)
end

function CustomAI:GetSignatureActions(context)
	if context then
		return self:SelectSignatureActions(context.unit, context)
	end
	return AIBehavior.GetSignatureActions(self, context)
end