function AIKeywordsCombo()
	return {
		"Control",
		"Explosives",
		"Sniper",
		"Soldier",
		"Ordnance",
		"Smoke",
		"Flank",
		"MobileShot",
		"RunAndGun",
		"Stim",
		"Nova",
		"Heal",

	}
end

function AIEnvStateCombo()
	local items = {}
	
	ForEachPresetInGroup("GameStateDef", "weather", function(item) table.insert(items, item.id) end)
	ForEachPresetInGroup("GameStateDef", "time of day", function(item) table.insert(items, item.id) end)
	return items
end

-- Base class
DefineClass.AISignatureAction = {
	__parents = { "AIBiasObj", },

	properties = {
		{ id = "NotificationText", name = "Notification Text", editor = "text", translate = true, default = ""  },
		{ id = "RequiredKeywords", editor = "string_list", default = {}, item_default = "", items = AIKeywordsCombo, arbitrary_value = true, },
		{ id = "AvailableInState", name = "Available In", editor = "set", default = set(), items = AIEnvStateCombo },
		{ id = "ForbiddenInState", name = "Forbidden In", editor = "set", default = set(), items = AIEnvStateCombo },
	},

	hidden = false,
	movement = false,
	voice_response = false, -- if a non-empty string, play that responce; if empty string play nothing, if false play default response
}

function AISignatureAction:GetEditorView()
	return self.class
end

function AISignatureAction:MatchUnit(unit)
	for state, _ in pairs(self.AvailableInState) do
		if not GameStates[state] then
			return
		end
	end
	for state, _ in pairs(self.ForbiddenInState) do
		if GameStates[state] then
			return
		end
	end
	
	for _, keyword in ipairs(self.RequiredKeywords) do
		if not table.find(unit.AIKeywords or empty_table, keyword) then
			return
		end
	end
	return true
end

function AISignatureAction:PrecalcAction(context, action_state)	
end

function AISignatureAction:IsAvailable(context, action_state)
	return false
end

function AISignatureAction:Execute(context, action_state)	
end

function AISignatureAction:GetVoiceResponse()
	return self.voice_response
end

function AISignatureAction:OnActivate(unit)
	if (self.NotificationText or "") ~= "" then
		ShowTacticalNotification("enemyAttack", false, self.NotificationText)
	end
	return AIBiasObj.OnActivate(self, unit)
end

---------------------------------------
DefineClass.AIActionBasicAttack = {
	__parents = { "AISignatureAction", },
}

function AIActionBasicAttack:PrecalcAction(context, action_state)
	local unit = context.unit
	local dest = context.ai_destination or GetPackedPosAndStance(unit)
	local target = (context.dest_target or empty_table)[dest]

	if not IsValidTarget(target) then
		return
	end
	
	local 	cost = context.default_attack_cost
	if cost >= 0 and unit:HasAP(cost) then
		action_state.args = {target = target}
		action_state.has_ap = true
	end
end

function AIActionBasicAttack:IsAvailable(context, action_state)
	return action_state.has_ap
end

function AIActionBasicAttack:Execute(context, action_state)
	assert(action_state.has_ap)
	
	AIPlayCombatAction(context.default_attack.id, context.unit, nil, action_state.args)
end

-- area attack base classes
DefineClass.AIActionBaseZoneAttack = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "enemy_score", name = "Enemy Hit Score", editor = "number", default = 100, },
		{ id = "team_score", name = "Teammate Hit Score", editor = "number", default = -1000, },
		{ id = "self_score_mod", name = "Self Score Modifier", editor = "number", scale = "percent", default = -100, help = "Score will be modified with this value if the targeted zone includes the unit performing the attack" },
		{ id = "min_score", name = "Score Threshold", editor = "number", default = 200, help = "Action will not be taken if best score is lower than this", },
	},
	action_id = false,
	hidden = true,
}

function AIEvalZones(context, zones, min_score, enemy_score, team_score, self_score_mod)
	local best_target, best_score = nil, (min_score or 0) - 1
	
	for _, zone in ipairs(zones) do
		local score
		local selfmod = 0
		for _, unit in ipairs(zone.units) do		
			local uscore = 0
			if not unit:IsDead() and not unit:IsDowned() then
				if unit:IsOnEnemySide(context.unit) then
					uscore = enemy_score or 0
				elseif unit.team == context.unit.team then
					uscore = team_score or 0
					if unit == context.unit then
						selfmod = self_score_mod or 0
					end
				end
			end
			score = (score or 0) + uscore
		end
		score = score and MulDivRound(score, zone.score_mod or 100, 100)
		score = score and MulDivRound(score, 100 + selfmod, 100)		
		if score and score > best_score then
			best_target, best_score = zone, score
		end
		zone.score = score
	end
	
	return best_target, best_score
end

function AIActionBaseZoneAttack:EvalZones(context, zones)
	return AIEvalZones(context, zones, self.min_score, self.enemy_score, self.team_score, self.self_score_mod)
end

DefineClass.AIActionBaseConeAttack = {
	__parents = { "AIActionBaseZoneAttack", },
	properties = {
		{ id = "self_score_mod", editor = "number", default = 0, no_edit = true },
	},
}

MapVar("g_LastSelectedZone", false)

function DbgShowLastSelectedZone()
	if not g_LastSelectedZone then return end
	
	DbgClearVectors()
	local start = g_LastSelectedZone.poly[#g_LastSelectedZone.poly]
	for _, pt in ipairs(g_LastSelectedZone.poly) do
		DbgAddVector(start:SetTerrainZ(guim), (pt - start):SetZ(0), const.clrWhite)
		start = pt
	end
end

function AIActionBaseConeAttack:PrecalcAction(context, action_state)
	if not IsKindOf(context.weapon, "Firearm") then
		return
	end
	
	local caction = CombatActions[self.action_id]
	if not caction or caction:GetUIState({context.unit}) ~= "enabled" then return end
	
	local args, has_ap = AIGetAttackArgs(context, caction, nil, "None")
	action_state.has_ap = has_ap
	if not has_ap then return end
	
	local zones = AIPrecalcConeTargetZones(context, self.action_id, nil, action_state.stance)
	local zone, best_score = self:EvalZones(context, zones)
	action_state.score = best_score
	args.target_pos = zone and zone.target_pos
	args.target = zone and zone.target_pos
	action_state.args = args
	
	g_LastSelectedZone = zone
end

function AIActionBaseConeAttack:IsAvailable(context, action_state)
	return action_state.has_ap and action_state.args.target_pos
end

function AIActionBaseConeAttack:Execute(context, action_state)
	assert(action_state.has_ap)
	AIPlayCombatAction(self.action_id, context.unit, nil, action_state.args)
end

-- actions
---------------------------------------
DefineClass.AIActionThrowGrenade = {
	__parents = { "AIActionBaseZoneAttack", },
	properties = {
		{ id = "MinDist", editor = "number", scale = "m", default = 2*guim, min = 0 },
		{ id = "MaxDist", editor = "number", scale = "m", default = 100*guim, min = 0 },
		{ id = "AllowedAoeTypes", editor = "set", items = {"none", "fire", "smoke", "teargas", "toxicgas"}, default = set("none") },
		{ id = "TargetLastAttackPos", editor = "bool", default = false },
 	},
	hidden = false,
	voice_response = "AIThrowGrenade",

}

function AIActionThrowGrenade:PrecalcAction(context, action_state)
	local action_id, grenade
	local actions = { "ThrowGrenadeA", "ThrowGrenadeB", "ThrowGrenadeC", "ThrowGrenadeD" }
	for _, id in ipairs(actions) do
		local caction = CombatActions[id]
		local cost = caction and caction:GetAPCost(context.unit) or -1
		if cost > 0 and context.unit:HasAP(cost) then
			action_id = id
			local weapon = caction:GetAttackWeapons(context.unit)
			local aoetype = weapon.aoeType or "none"
			if IsKindOf(weapon, "Grenade") and self.AllowedAoeTypes[aoetype] then
				grenade = weapon			
				break
			end
		end
	end
	
	if not action_id or not grenade then
		return
	end
	
	local max_range = Min(self.MaxDist, grenade:GetMaxAimRange(context.unit) * const.SlabSizeX)
	local blast_radius = grenade.AreaOfEffect * const.SlabSizeX
	local target_pts
	if self.TargetLastAttackPos then 
		-- collect enemy last attack positions and pass them as target_pos array to AIPrecalcGrenadeZones
		for _, enemy in ipairs(context.enemies) do
			if enemy.last_attack_pos then
				target_pts = target_pts or {}
				target_pts[#target_pts + 1] = enemy.last_attack_pos
			end
		end
	end
	local zones = AIPrecalcGrenadeZones(context, action_id, self.MinDist, max_range, blast_radius, grenade.aoeType, target_pts)
	local zone, score = self:EvalZones(context, zones)
	if zone then
		action_state.action_id = action_id
		action_state.target_pos = zone.target_pos
		action_state.score = score
	end
end

function AIActionThrowGrenade:IsAvailable(context, action_state)
	return not not action_state.action_id
end

function AIActionThrowGrenade:Execute(context, action_state)
	assert(action_state.action_id and action_state.target_pos)
	AIPlayCombatAction(action_state.action_id, context.unit, nil, {target = action_state.target_pos})
end
---------------------------------------
DefineClass.AIConeAttack = {
	__parents = { "AIActionBaseConeAttack", },
	properties = {
		{ id = "action_id", editor = "dropdownlist", items = {"Buckshot", "DoubleBarrel", "Overwatch"}, default = "Buckshot" },
	},
	hidden = false,
}

function AIConeAttack:GetEditorView()
	return string.format("Cone Attack (%s)", self.action_id)
end

function AIConeAttack:Execute(context, action_state)
	AIActionBaseConeAttack.Execute(self, context, action_state)
	if self.action_id == "Overwatch" then
		return "done"
	end
end

function AIConeAttack:GetVoiceResponse()
	if self.action_id == "Overwatch" then
		return "AIOverwatch"
	end
	return self.voice_response
end
---------------------------------------
DefineClass.AIActionBandage = {
	__parents = { "AISignatureAction", "AIBaseHealPolicy", },
	voice_response = "",
}

function AIActionBandage:IsAvailable(context, action_state)
	return action_state.has_ap
end

function AIActionBandage:Execute(context, action_state)
	assert(action_state.has_ap)
	if action_state.args.target then
		if not IsMeleeRangeTarget(context.unit, nil, nil, action_state.args.target) then
			return
		end
		context.unit:Face(action_state.args.target)
	end
	AIPlayCombatAction("Bandage", context.unit, nil, action_state.args)
	return "stop"
end

function AIActionBandage:PrecalcAction(context, action_state)
	local unit = context.unit
	local x, y, z = unit:GetGridCoords()
	local grid_voxel = point_pack(x, y, z)
	local dest = GetPackedPosAndStance(unit)
	local target = AISelectHealTarget(context, dest, grid_voxel, self)
	
	if target then
		action_state.args = { 
			target = target,
			goto_pos = SnapToVoxel(unit:GetPos()),
		}
		local cost = CombatActions.Bandage:GetAPCost(unit, action_state.args)
		action_state.has_ap = (cost >= 0) and unit:HasAP(cost)
	end
end
---------------------------------------
DefineClass.AIStimRule = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Keyword", editor = "dropdownlist", default = "", items = AIKeywordsCombo },
		{ id = "Weight", editor = "number", default = 0 },
	},
}
DefineClass.AIActionStim = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "TargetRules", editor = "nested_list", default = false, base_class = "AIStimRule", inclusive = true },
		{ id = "CanTargetSelf", editor = "bool", default = false },
	},
	voice_response = "",
}

function AIActionStim:IsAvailable(context, action_state)
	return action_state.has_ap and IsValid(action_state.target)
end

function AIActionStim:Execute(context, action_state)
	assert(action_state.has_ap and IsValid(action_state.target))
	
	-- just fake it
	context.unit:ConsumeAP(CombatStim.APCost * const.Scale.AP)
	for _, effect in ipairs(CombatStim.Effects) do
		effect:__exec(action_state.target)
	end
end

function AIActionStim:PrecalcAction(context, action_state)
	local cost = CombatStim.APCost * const.Scale.AP
	local unit = context.unit
	action_state.has_ap = unit:HasAP(cost)	
	if not action_state.has_ap then return end
	
	local best_score, best_target = 0, false
	if self.CanTargetSelf then
		best_score = AIEvalStimTarget(unit, unit, self.TargetRules)
		best_target = (best_score > 0) and unit
	end
	
	for _, ally in ipairs(context.allies) do
		if IsMeleeRangeTarget(unit, nil, nil, ally) then
			local score = AIEvalStimTarget(unit, ally, self.TargetRules)
			if score > best_score then
				best_score, best_target = score, ally
			elseif score == best_score and IsValid(best_target) then
				if unit:GetDist(ally) < unit:GetDist(best_target) then
					best_target = ally
				end
			end
		end
	end
	action_state.target = best_target
end
---------------------------------------
DefineClass.AIActionCharge = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "DestPreference", editor = "dropdownlist", items = {"score", "nearest"}, default = "score", help = "Specifies the way a charge destination and target are selected when the destination picked by the general AI logic isn't a valid Charge destination.\n'score' picks the destination with highest evaluation, while 'nearest' opts for the destination nearest to the general destination already picked" },
	},
	movement = true,
	action_id = "Charge",
}

function AIActionCharge:IsAvailable(context, action_state)
	return not not action_state.args
end

function AIActionCharge:GetActionId(unit)
	return HasPerk(unit, "GloryHog") and "GloryHog" or "Charge"
end

function AIActionCharge:Execute(context, action_state)
	assert(action_state.has_ap)
	if #CombatActions_Waiting > 0 or (next(CombatActions_RunningState) ~= nil) then
		-- do not queue together with other move actions to avoid shooting actions going back and forth between units
		return "restart"
	end
	local action_id = self:GetActionId(context.unit)
	AIPlayCombatAction(action_id, context.unit, nil, action_state.args)	
end

function AIActionCharge:PrecalcAction(context, action_state)
	local unit = context.unit
	local action_id = self:GetActionId(unit)
	local action = CombatActions[action_id]
		
	-- check action state
	local units = {unit}
	local state = action:GetUIState(units)
	local cost = action:GetAPCost(unit)
	if state ~= "enabled" or (cost > 0 and not unit:HasAP(cost)) then return end
	
	-- check if we have valid targets and the resulting positions
	local targets = action:GetTargets(units)
	local move_ap = action:ResolveValue("move_ap") * const.Scale.AP
	local args, score, dist
	local pref = context.ai_destination and self.DestPreference or "score"
	
	for _, target in ipairs(targets) do
		local atk_pos = GetChargeAttackPosition(unit, target, move_ap, action_id)
		local atk_dest = stance_pos_pack(atk_pos, StancesList.Standing)
		local atk_dist = context.ai_destination and stance_pos_dist(context.ai_destination, atk_dest)
		-- prefer selected dest if possible, select the dest with highest overall score otherwise?
		if atk_dist and atk_dist == 0 then
			args = { target = target, goto_pos = atk_pos }
			break
		end
		if pref == "score" then
			local dest_score = context.dest_scores[atk_dest] or 0
			if not args or (dest_score > score) then
				args = {target = target, goto_pos = atk_pos}
				score = dest_score
			end
		elseif pref == "nearest" then
			if not args or atk_dist < dist then
				args = {target = target, goto_pos = atk_pos}
				dist = atk_dist
			end
		else
			assert(false, string.format("unknown dest preference for AI Charge (%s), aborting", tostring(pref)))
			break
		end
	end
	
	if not args then return end
	
	args.goto_ap = CombatActions.Move:GetAPCost(unit, {goto_pos = args.goto_pos})
	action_state.args = args
end
---------------------------------------
DefineClass.AIActionHyenaCharge = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "DestPreference", editor = "dropdownlist", items = {"score", "nearest"}, default = "score", help = "Specifies the way a charge destination and target are selected when the destination picked by the general AI logic isn't a valid Charge destination.\n'score' picks the destination with highest evaluation, while 'nearest' opts for the destination nearest to the general destination already picked" }
	},
	movement = true,
	action_id = "HyenaCharge",
}

function AIActionHyenaCharge:IsAvailable(context, action_state)
	return not not action_state.args
end

function AIActionHyenaCharge:Execute(context, action_state)
	assert(action_state.args)
	if #CombatActions_Waiting > 0 or (next(CombatActions_RunningState) ~= nil) then
		-- do not queue together with other move actions to avoid shooting actions going back and forth between units
		return "restart"
	end
	AIPlayCombatAction(self.action_id, context.unit, nil, action_state.args)	
end

function AIActionHyenaCharge:PrecalcAction(context, action_state)
	local unit = context.unit
	local action = CombatActions[self.action_id]
		
	-- check action state
	local units = {unit}
	local state = action:GetUIState(units)
	local cost = action:GetAPCost(unit)
	if state ~= "enabled" or (cost > 0 and not unit:HasAP(cost)) then return end
	
	-- check if we have valid targets and the resulting positions
	local targets = action:GetTargets(units)
	local move_ap = action:ResolveValue("move_ap") * const.Scale.AP
	local args, score, dist
	local pref = context.ai_destination and self.DestPreference or "score"
	
	for _, target in ipairs(targets) do
		local atk_pos = GetHyenaChargeAttackPosition(unit, target, move_ap, false, self.action_id)
		local atk_dest = stance_pos_pack(atk_pos, 0)
		local atk_dist = context.ai_destination and stance_pos_dist(context.ai_destination, atk_dest)
		-- prefer selected dest if possible, select the dest with highest overall score otherwise?
		if atk_dist and atk_dist == 0 then
			args = { target = target }
			break
		end
		if pref == "score" then
			local dest_score = context.dest_scores[atk_dest] or 0
			if not args or (dest_score > score) then
				args = {target = target }
				score = dest_score
			end
		elseif pref == "nearest" then
			if not args or atk_dist < dist then
				args = {target = target }
				dist = atk_dist
			end
		else
			assert(false, string.format("unknown dest preference for AI Charge (%s), aborting", tostring(pref)))
			break
		end
	end
	
	action_state.args = args
end
---------------------------------------
DefineClass.AIActionMobileShot = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "action_id", name = "Action", editor = "dropdownlist", items = {"MobileShot", "RunAndGun"}, default = "MobileShot" },
	},
	movement = true,
	default_notification_texts = {
		MobileShot = T(222119395990, "Mobile Shot"),
		RunAndGun = T(439839298337, "Run and Gun"),
	},
	voice_response = "AIMobile", -- both attacks use the same VR
}

function AIActionMobileShot:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "NotificationText" then		
		return self.default_notification_texts[self.action_id] or prop_meta.default
	end
	return AISignatureAction.GetDefaultPropertyValue(self, prop, prop_meta)
end

function AIActionMobileShot:SetProperty(property, value)
	if property == "action_id" then		
		local meta = self:GetPropertyMetadata("NotificationText")
		local cur_default_text = self.default_notification_texts[self.action_id] or meta.default
		local new_default_text = self.default_notification_texts[value] or meta.default
		if self.NotificationText == cur_default_text then
			self:SetProperty("NotificationText", new_default_text)
		end
	end
	return AISignatureAction.SetProperty(self, property, value)
end

function AIActionMobileShot:GetEditorView()
	return string.format("Mobile Attack (%s)", self.action_id)
end

function AIActionMobileShot:IsAvailable(context, action_state)
	return action_state.has_ap
end

function AIActionMobileShot:Execute(context, action_state)
	assert(action_state.has_ap)
	if #CombatActions_Waiting > 0 or (next(CombatActions_RunningState) ~= nil) then
		-- do not queue together with other move actions to avoid shooting actions going back and forth between units
		return "restart"
	end
	AIPlayCombatAction(self.action_id, context.unit, nil, action_state.args)	
end

function AIActionMobileShot:PrecalcAction(context, action_state)
	local unit = context.unit
	local action = CombatActions[self.action_id]
	
	-- only available to reach the already chosen dest
	if not context.ai_destination then return end
	
	-- check action state
	local state = action:GetUIState({unit})
	if state ~= "enabled" then return end
	
	-- check if the action would do something
	local x, y, z = stance_pos_unpack(context.ai_destination)
	local target_pos = point(x, y, z)
	local shot_voxels, shot_targets, shot_ch, canceling_reason = CalcMobileShotAttacks(unit, action, target_pos)
	shot_voxels = shot_voxels or empty_table
	shot_targets = shot_targets or empty_table

	if shot_voxels[1] and not canceling_reason[1] and IsValidTarget(shot_targets[1]) then
		action_state.args = { 
			goto_pos = target_pos,
		}
		local cost = action:GetAPCost(unit, action_state.args)
		action_state.has_ap = (cost >= 0) and unit:HasAP(cost)
	end
end
---------------------------------------
DefineClass.AIActionPinDown = {
	__parents = { "AISignatureAction", },
	voice_response = "AIPinDown",
}

function AIActionPinDown:PrecalcAction(context, action_state)
	if IsKindOf(context.weapon, "Firearm") then
		local args, has_ap = AIGetAttackArgs(context, CombatActions.PinDown, nil, "None")
		action_state.args = args
		action_state.has_ap = has_ap
	end
end

function AIActionPinDown:IsAvailable(context, action_state)
	if not action_state.has_ap then
		return false
	end
	
	local target = action_state.args.target
	
	-- filter targets that are already pinned down
	for attacker, descr in pairs(g_Pindown) do
		if descr.target == target then
			return false
		end
	end
	
	return IsValidTarget(target) and context.unit:HasPindownLine(target, action_state.args.target_spot_group or "Torso")
end

function AIActionPinDown:Execute(context, action_state)
	assert(action_state.has_ap)
	local target = action_state.args.target
	AIPlayCombatAction("PinDown", context.unit, nil, action_state.args)
	return "done"
end
---------------------------------------
DefineClass.AIActionShootLandmine = {
	__parents = { "AIActionBaseZoneAttack", },
	hidden = false,
}

function AIActionShootLandmine:PrecalcAction(context, action_state)
	local zones = AIPrecalcLandmineZones(context)
	local zone, score = self:EvalZones(context, zones)
	if zone then
		local args, has_ap = AIGetAttackArgs(context, context.default_attack, nil, "None", zone.target)
		if has_ap then
			action_state.score = score
			action_state.args = args
			action_state.has_ap = has_ap
		end
	end
end

function AIActionShootLandmine:IsAvailable(context, action_state)
	return action_state.has_ap
end

function AIActionShootLandmine:Execute(context, action_state)
	assert(action_state.has_ap)
	AIPlayCombatAction(context.default_attack.id, context.unit, nil, action_state.args)
end
---------------------------------------
DefineClass.AIActionSingleTargetShot = {
	__parents = { "AISignatureAction", },
	properties = {
		{ id = "action_id", editor = "dropdownlist", items = {"SingleShot", "BurstFire", "AutoFire", "Buckshot", "DoubleBarrel", "KnifeThrow"}, default = "SingleShot" },
		{ id = "Aiming", 
			editor = "choice", default = "None", items = function (self) return { "None", "Remaining AP", "Maximum"} end, },
		{ id = "AttackTargeting", help = "if any parts are set the unit will pick one of them randomly for each of its basic attacks; otherwise it will always use the default (torso) attacks", 
			editor = "set", default = false, items = function (self) return table.keys2(Presets.TargetBodyPart.Default) end, },
	},
	
	default_notification_texts = {
		AutoFire = T(730263043731, "Full Auto"),
		DoubleBarrel = T(937676786920, "Double Barrel Shot"),
	},
}

function AIActionSingleTargetShot:GetDefaultPropertyValue(prop, prop_meta)
	if prop == "NotificationText" then		
		return self.default_notification_texts[self.action_id] or prop_meta.default
	end
	return AISignatureAction.GetDefaultPropertyValue(self, prop, prop_meta)
end

function AIActionSingleTargetShot:SetProperty(property, value)
	if property == "action_id" then		
		local meta = self:GetPropertyMetadata("NotificationText")
		local cur_default_text = self.default_notification_texts[self.action_id] or meta.default
		local new_default_text = self.default_notification_texts[value] or meta.default
		if self.NotificationText == cur_default_text then
			self:SetProperty("NotificationText", new_default_text)
		end
	end
	return AISignatureAction.SetProperty(self, property, value)
end

function AIActionSingleTargetShot:GetEditorView()
	return string.format("Single Target Attack (%s)", self.action_id)
end

function AIActionSingleTargetShot:PrecalcAction(context, action_state)
	if IsKindOf(context.weapon, "Firearm") and not IsKindOf(context.weapon, "HeavyWeapon") then
		local action = CombatActions[self.action_id]
		
		local unit = context.unit
		local upos = GetPackedPosAndStance(unit)
		local target = context.dest_target[upos]
		
		local body_parts = AIGetAttackTargetingOptions(unit, context, target, action, self.AttackTargeting)
		local targeting
		if body_parts and #body_parts > 0 then
			local pick = table.weighted_rand(body_parts, "chance", InteractionRand(1000000, "Combat"))
			targeting = pick and pick.id or nil
		end

		assert(action)
		local args, has_ap = AIGetAttackArgs(context, action, targeting or "Torso", self.Aiming)
		action_state.args = args
		action_state.has_ap = has_ap
		if has_ap and IsValidTarget(args.target) then
			local results = action:GetActionResults(context.unit, args)
			action_state.has_ammo = not not results.fired
			action_state.can_hit = results.chance_to_hit > 0
		end
	end
end

function AIActionSingleTargetShot:IsAvailable(context, action_state)
	if not action_state.has_ap or not action_state.has_ammo or not action_state.can_hit then
		return false
	end
	
	return IsValidTarget(action_state.args.target)
end

function AIActionSingleTargetShot:Execute(context, action_state)
	assert(action_state.has_ap)
	
	AIPlayCombatAction(self.action_id, context.unit, nil, action_state.args)
end

function AIActionSingleTargetShot:GetVoiceResponse()
	local action_id = self.action_id
	if action_id and (action_id == "DoubleBarrel" or action_id == "Buckshot" or  action_id == "BuckshotBurst") then
		return "AIDoubleBarrel"
	end
	return self.voice_response
end
---------------------------------------
DefineClass.AIAttackSingleTarget = {
	__parents = { "AIActionSingleTargetShot", },
}
---------------------------------------
DefineClass.AIActionCancelShot = {
	__parents = { "AIActionSingleTargetShot", },
	properties = { 
		{ id = "action_id", editor = "dropdownlist", items = {"CancelShot"}, default = "CancelShot", no_edit = true },
	},
}

function AIActionCancelShot:IsAvailable(context, action_state)
	if not action_state.has_ap then
		return false
	end
	
	local target = action_state.args.target
	return IsValidTarget(target) and (target:HasPreparedAttack() or target:CanActivatePerk("MeleeTraining"))
end
---------------------------------------
DefineClass.AIActionMGSetup = {
	__parents = { "AIActionBaseConeAttack", },
	properties = {
		{ id = "cur_zone_mod", name = "Current Zone Modifier", editor = "number", scale = "%", default = 100, help = "Modifier applied when scoring the already set zone" },
	},
	action_id = "MGSetup",
	hidden = false,
}

function AIActionMGSetup:PrecalcAction(context, action_state)
	if not context.unit:HasStatusEffect("StationedMachineGun") then
		-- setup
		action_state.stance = "Prone" -- MGSetup will change the stance so we need to check LOS in that stance
		AIActionBaseConeAttack.PrecalcAction(self, context, action_state)
	else
		local curr_target_pt = g_Overwatch[context.unit] and g_Overwatch[context.unit].target_pos
		local zones = AIPrecalcConeTargetZones(context, self.action_id, curr_target_pt)
		local cur_zone = zones[#zones]
		if not cur_zone then
			return
		end
		cur_zone.score_mod = self.cur_zone_mod
		local zone, best_score = self:EvalZones(context, zones)
	
		-- check best zone:
		if not zone then -- no suitable zone, pack up
			action_state.action_id = "MGPack"
		elseif zone ~= cur_zone then -- another best zone, rotate
			action_state.action_id = "MGRotate"
			action_state.target_pos = zone.target_pos
		end

		if action_state.action_id then
			action_state.score = best_score
			action_state.target_pos = zone and zone.target_pos
			
			local caction = CombatActions[action_state.action_id]
			if not caction then return end
			
			local args, has_ap = AIGetAttackArgs(context, caction, nil, "None")
			action_state.has_ap = has_ap
			if has_ap then 
				g_LastSelectedZone = zone
			end
		end
	end
end

function AIActionMGSetup:IsAvailable(context, action_state)
	return action_state.has_ap and (action_state.args and action_state.args.target_pos or action_state.action_id == "MGPack")
end

function AIActionMGSetup:Execute(context, action_state)
	assert(action_state.has_ap)
	local args = {}
	if action_state.action_id ~= "MGPack" then
		assert(action_state.args)
		args.target = action_state.args.target_pos
	end
	AIPlayCombatAction(action_state.action_id or self.action_id, context.unit, nil, args)
	if action_state.action_id == "MGPack" then
		return "restart"
	end
end
---------------------------------------
DefineClass.AIActionMGBurstFire = {
	__parents = { "AIActionSingleTargetShot", },
	properties = { 
		{ id = "action_id", editor = "dropdownlist", items = { "MGBurstFire" }, default = "MGBurstFire", no_edit = true },
	},
	--action_id = "MGBurstFire",
}
function AIActionMGBurstFire:PrecalcAction(context, action_state)
	if context.unit:HasStatusEffect("StationedMachineGun") then
		return AIActionSingleTargetShot.PrecalcAction(self, context, action_state)
	end
end
---------------------------------------
DefineClass.AIActionHeavyWeaponAttack = {
	__parents = { "AIActionBaseZoneAttack", },
	properties = { 
		{ id = "MinDist", editor = "number", scale = "m", default = 2*guim, min = 0 },
		{ id = "MaxDist", editor = "number", scale = "m", default = 100*guim, min = 0 },
		{ id = "SmokeGrenade", editor = "bool", default = false, },
		{ id = "action_id", editor = "dropdownlist", items = { "GrenadeLauncherFire", "RocketLauncherFire", "Bombard" }, default = "GrenadeLauncherFire" },
		{ id = "LimitRange", editor = "bool", default = false },
		{ id = "MaxTargetRange", editor = "number", min = 1, max = 100, default = 20, slider = true, no_edit = function(self) return not self.LimitRange end, },
	},
	hidden = false,
	--voice_response = "AIThrowGrenade",
}

function AIActionHeavyWeaponAttack:GetEditorView()
	return string.format("Heavy Attack (%s)", self.action_id)
end

function AIActionHeavyWeaponAttack:PrecalcAction(context, action_state)
	local caction = CombatActions[self.action_id]
	local cost = caction and caction:GetAPCost(context.unit) or -1
	local weapon = caction and caction:GetAttackWeapons(context.unit)
	
	if not weapon or cost < 0 or not context.unit:HasAP(cost) or not weapon.ammo or weapon.ammo.Amount < 1 then
		return
	end
	if self.SmokeGrenade ~= (weapon.ammo.aoeType == "smoke") then
		return
	end
	if self.action_id == "Bombard" and context.unit.indoors then
		return
	end
	
	local max_range = Min(self.MaxDist, caction:GetMaxAimRange(context.unit, weapon) * const.SlabSizeX)
	local blast_radius = weapon.ammo.AreaOfEffect * const.SlabSizeX
	local zones = AIPrecalcGrenadeZones(context, self.action_id, self.MinDist, max_range, blast_radius, weapon.ammo.aoeType)
	
	if self.LimitRange then
		local attacker = context.unit
		local range = self.MaxTargetRange * const.SlabSizeX
		zones = table.ifilter(zones, function(idx, zone) return attacker:GetDist(zone.target_pos) <= range end)
	end
	
	local zone, score = self:EvalZones(context, zones)
	if zone then
		action_state.action_id = self.action_id
		action_state.target_pos = zone.target_pos
		action_state.score = score
	end
end

function AIActionHeavyWeaponAttack:IsAvailable(context, action_state)
	return not not action_state.action_id
end

function AIActionHeavyWeaponAttack:Execute(context, action_state)
	assert(action_state.action_id and action_state.target_pos)
	AIPlayCombatAction(action_state.action_id, context.unit, nil, {target = action_state.target_pos})
end
---------------------------------------