-- not specified animations continue to "Idle"
local s_TransitionRules = {
	["%s_Standing_Idle"] = {
		{ "%s_Standing_Run", moment = "any" },
		{ "%s_Standing_Walk", moment = "any" },
		{ "%s_Standing_CombatRun", moment = "any" },
		{ "%s_Standing_CombatWalk", moment = "any" },
		{ "%s_Standing_To_Crouch", moment = "any" },
		{ "%s_Standing_To_Prone", moment = "any" },
		{ "%s_Standing_Aim", moment = "any",  },
		{ "%s_Standing_ExposeLeft_Start", moment = "any",  },
		{ "%s_Standing_ExposeRight_Start", moment = "any",  },
		{ "gr_Standing_Aim", moment = "any" },
	},
	["%s_Crouch_Idle"] = {
		{ "%s_Standing_Run", moment = "any" },
		{ "%s_Standing_Walk", moment = "any" },
		{ "%s_Standing_CombatRun", moment = "any" },
		{ "%s_Standing_CombatWalk", moment = "any" },
		{ "%s_Crouch_To_Standing", moment = "any" },
		{ "%s_Crouch_To_Prone", moment = "any" },
		{ "%s_TakeCover_Idle", moment = "any" },
		{ "gr_Standing_Aim", moment = "any" },
	},
	["%s_Prone_Idle"] = {
		{ "%s_Prone_To_Standing", moment = "any" },
		{ "%s_Prone_To_Crouch", moment = "any" },
	},
	["%s_Downed_Idle"] = {
		{ "%s_Downed_Standing", moment = "any" },
		{ "%s_Downed_Crouch", moment = "any" },
		{ "%s_Downed_Prone", moment = "any" },
	},
	["%s_Standing_Run"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_Walk"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_CombatRun"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_CombatWalk"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_Aim"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_Aim_Forward"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_Aim_Down"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["%s_Standing_Fire"] = {
		{ "%s_Standing_Idle", moment = "any" },
	},
	["gr_Standing_Aim"] = {
		{ "%s_Standing_Idle", moment = "any" },
		{ "%s_Crouch_Idle", moment = "any" },
	},
	["nw_Standing_MortarIdle"] = {
		{ "nw_Standing_MortarEnd", moment = "any" },
	},
	["nw_Standing_MortarFire"] = {
		{ "nw_Standing_MortarEnd", moment = "any" },
	},
	["nw_Standing_MortarEnd"] = {
		{ "%s_Standing_Idle" },
	},
	["%s_Standing_To_Crouch"] = { { "%s_Crouch_Idle" } },
	["%s_Standing_To_Prone"] = { { "%s_Prone_Idle" } },
	["%s_Crouch_To_Standing"] = { { "%s_Standing_Idle" } },
	["%s_Crouch_To_Prone"] = { { "%s_Prone_Idle" } },
	["%s_TakeCover_Idle"] = { { "%s_Crouch_Idle", moment = "any" }},
	["%s_Prone_To_Standing"] = { { "%s_Standing_Idle" } },
	["%s_Prone_To_Crouch"] = { { "%s_Crouch_Idle" } },
	["%s_Downed_Standing"] = { { "%s_Standing_Idle" } },
	["%s_Downed_Crouch"] = { { "%s_Crouch_Idle" } },
	["%s_Downed_Prone"] = { { "%s_Prone_Idle" } },
	["%s_Open_Door"] = {
		{ "%s_Standing_Idle", moment = "any" },
		{ "%s_Crouch_Idle", moment = "any" },
	},
	["%s_CloseDoor"] = {
		{ "%s_Standing_Idle", moment = "any" },
		{ "%s_Crouch_Idle", moment = "any" },
	},
	["%s_Standing_ExposeLeft_Start"] = {
		{ "%s_Standing_ExposeLeft_Idle" },
		locked_orientation = true,
	},
	["%s_Standing_ExposeRight_Start"] = {
		{ "%s_Standing_ExposeRight_Idle" },
		locked_orientation = true,
	},
	["%s_Standing_ExposeLeft_Idle"] = {
		{ "%s_Standing_ExposeLeft_End", moment = "any" },
		locked_orientation = true,
	},
	["%s_Standing_ExposeRight_Idle"] = {
		{ "%s_Standing_ExposeRight_End", moment = "any" },
		locked_orientation = true,
	},
	["%s_Standing_ExposeLeft_End"] = {
		{ "%s_Standing_Idle" },
		locked_orientation = true,
	},
	["%s_Standing_ExposeRight_End"] = {
		{ "%s_Standing_Idle" },
		locked_orientation = true,
	},
}

function ResolveAnimationTransitions(prefixes)
	local result = {}
	for anim_format, transitions_format in sorted_pairs(s_TransitionRules) do
		for j, prefix in ipairs(prefixes) do
			local anim = string.format(anim_format, prefix)
			local anim_transitions = result[anim]
			if not anim_transitions then
				anim_transitions = {
					prefix = string.starts_with(anim, prefix) and prefix or string.match(anim, "^(%a+_).*"),
				}
				result[anim] = anim_transitions
			end
			if transitions_format.locked_orientation then
				anim_transitions.locked_orientation = transitions_format.locked_orientation
			end
			for k, transition_format in ipairs(transitions_format) do
				assert(s_TransitionRules[transition_format[1]])
				local target_anim = string.format(transition_format[1], prefix)
				local transition = table.copy(transition_format)
				transition[1] = target_anim
				local idx = table.find(anim_transitions, 1, target_anim) or #anim_transitions + 1
				anim_transitions[idx] = transition
			end
		end
	end
	return result
end

s_AnimTransitions = ResolveAnimationTransitions({ "civ", "ar", "mk", "dw", "hg", "gr", "nw", "hw" })
local ValidStances = {
	Standing = true,
	Crouch = true,
	Prone = true,
}

function GetAnimPath(obj, start_anim, target_anim)
	if start_anim == target_anim then
		return
	end
	local queue = { start_anim, [start_anim] = 0 }
	local queue_transitions = { false }
	if not s_AnimTransitions[start_anim] then
		local prefix = string.match(start_anim, "^(%a+_)")
		local stance = prefix and obj.species == "Human" and string.match(start_anim, "^%a+_(%a+)_")
		if stance == "KnockDown" then
			stance = "Prone"
		end
		local closest = stance and string.format("%s%s_Idle", prefix, stance)
		if closest == target_anim then
			return
		end
		if not s_AnimTransitions[closest] then
			if obj.species == "Human" then
				if not stance or not ValidStances[stance] then
					stance = "Standing"
				end
				if prefix == "nw_" or prefix == "civ_" then
					prefix = string.match(target_anim, "^(%a+_)") or obj:GetWeaponAnimPrefix()
				end
				closest = string.format("%s%s_Idle", prefix, stance)
				if closest == target_anim then
					return
				end
			end
			if not s_AnimTransitions[closest] then
				return
			end
		end
		queue_transitions[2] = false
		queue[2] = closest
		queue[closest] = 1
	end

	local target_tokens = {}
	local target_token_start = 1
	while target_token_start <= #target_anim do
		local index = string.find(target_anim, "_", target_token_start)
		if not index then
			break
		end
		table.insert(target_tokens, string.sub(target_anim, 1, index))
		target_token_start = index + 1
	end
	if #target_tokens == 0 then
		return
	end
	local target_prefix = string.sub(target_tokens[1], 1, #target_tokens[1] - 1)
	local variation_index = string.match(target_anim, "()%d+$")
	if variation_index then
		table.insert(target_tokens, string.sub(target_anim, 1, variation_index - 1))
	else
		table.insert(target_tokens, target_anim)
	end

	local GetAnimDist = function(anim)
		if anim == target_anim then
			return 0
		end
		local dist = #target_tokens + 1
		for i, token in ipairs(target_tokens) do
			if not string.starts_with(anim, token) then
				break
			end
			dist = dist - 1
		end
		if anim:ends_with("Idle") then
			return dist
		end
		return dist + 1
	end

	local idx = #queue
	local best_idx = idx
	local best_dist = GetAnimDist(queue[idx])
	local best_threshold = s_AnimTransitions[target_anim] and 0 or 1

	while idx <= #queue and best_dist > best_threshold do
		local anim = queue[idx]
		local dist = GetAnimDist(anim)
		if dist - best_dist < 2 then
			local anim_data = s_AnimTransitions[anim]
			-- invalid animations can be skipped when moment == "any"
			local is_valid_anim = IsValidAnim(obj, anim)
			for i, transition in ipairs(anim_data) do
				local new_anim = transition[1]
				local new_anim_data = s_AnimTransitions[new_anim] or empty_table
				if not queue[new_anim]
					and (is_valid_anim or transition.moment == "any")
					and (anim_data.prefix == new_anim_data.prefix or new_anim_data.prefix == target_prefix)
				then
					queue[new_anim] = idx
					local dist = GetAnimDist(new_anim)
					if dist - best_dist < 2 then
						table.insert(queue, new_anim)
						table.insert(queue_transitions, transition)
						if IsValidAnim(obj, new_anim) then
							if dist < best_dist then
								best_idx, best_dist = #queue, dist
							end
							if dist == 0 then
								break
							end
						end
					end
				end
			end
		end
		idx = idx + 1
	end

	local path = {}
	idx = best_idx
	local transition
	while idx > 0 do
		local anim = queue[idx]
		if transition and transition.moment ~= "any" then
			table.insert(path, anim)
		end
		transition = queue_transitions[idx]
		idx = queue[anim]
	end
	if path[1] == obj:GetStateText() and obj:GetAnimPhase() >= GetAnimDuration(obj:GetEntity(), path[1]) - 1 then
		table.remove(path, 1)
	end
	if #path == 0 then
		return
	end
	return path
end

function PlayTransitionAnims(obj, target_anim, angle, aim_pos)
	local start_anim = obj:GetStateText()
	local path = GetAnimPath(obj, start_anim, target_anim)
	if not path and obj.species == "Human" then
		local prefix = string.match(target_anim, "^(%a+_)")
		if prefix == "inf_" then
			local nw_target_anim = "nw" .. string.sub(target_anim, #prefix)
			return PlayTransitionAnims(obj, nw_target_anim, angle, aim_pos)
		end
		if prefix and not string.starts_with(start_anim, prefix) then
			local stance = string.match(start_anim, "^%a+_(%a+)_")
			if stance then
				local closest = string.format("%s%s_Idle", prefix, stance)
				path = GetAnimPath(obj, closest, target_anim)
			end
		end
	end
	if not path then
		return false
	end
	local len = #path
	for i = len, 1, -1 do
		local anim = path[i]
		if i < len or obj:GetStateText() ~= anim then
			obj:SetState(anim, const.eKeepComponentTargets)
		end
		if angle and not (s_AnimTransitions[anim] or empty_table).locked_orientation then
			local angle_diff = AngleDiff(angle, obj:GetOrientationAngle())
			if angle_diff ~= 0 then
				local t = obj:TimeToMoment(1, "OrientationStart")
				if (t or 0) > 0 then
					Sleep(t)
				end
				t = obj:TimeToMoment(1, "OrientationEnd") or Min(300, obj:TimeToAnimEnd())
				obj:IdleRotation(angle, t)
			end
			angle = nil
		end
		if i == 1 and aim_pos and anim:ends_with("Aim_Start") then
			local t = obj:TimeToAnimEnd() - obj:GetAnimDuration() / 2 -- wait middle of the animation
			if t > 0 then
				Sleep(t)
			end
			obj:SetIK("AimIK", aim_pos)
			Sleep(obj:TimeToAnimEnd())
		end
		Sleep(obj:TimeToAnimEnd())
	end
	return true
end

local function GetDieAnimSuffix(context, fall_angle)
	local unit = context.unit

	local diff = AngleDiff(unit:GetVisualAngle(), fall_angle)
	if abs(diff) <= 45 * 60 then
		return "_F", fall_angle
	elseif abs(diff) >= 135 * 60 then
		return "_B", fall_angle + 180 * 60
	elseif diff < 0 then
		return "_R", fall_angle - 90*60
	end

	return "_L", fall_angle + 90*60
end

local function CheckNearbyPass(pos, except_dir)
	local offset = const.SlabSizeX / 2
	for y = -1, 1 do
		for x = -1, 1 do
			local p = point(x * offset, y * offset, 0)
			if not except_dir or abs(AngleDiff(CalcOrientation(p), except_dir)) >= 90*60 then
				if not terrain.IsPassable(pos + p) then
					return false
				end
			end
		end
	end
	return true
end

-- TODO: here we can incorporate transitions to another anims
local s_ConditionsGraph = {
	{
		Name = "Death_Sitting",
		Condition = function(context)
			if context.hit_descr and context.hit_descr.die_pos then
				local visit = context.unit and context.unit.last_visit
				return IsValid(visit) and IsKindOf(visit, "AL_SitChair")
			end
		end,
		Animation = function(context)
			local dir_angle = CardinalDirection(context.angle)
			local _, angle = GetDieAnimSuffix(context, dir_angle)
			return "civ_DeathChair", true, context.hit_descr.die_pos, angle
		end,
	},
	{
		Name = "Death_Wall_NextSlab",
		Condition = function(context)
			if not context.close_shot_dist or context.move_slabs ~= 0 then
				return false
			end
			if GetAngleCover(context.pos, CardinalDirection(context.angle)) ~= const.CoverHigh then
				return false -- no cover
			end
			return true
		end,
		Animation = function(context)
			local dir_angle = CardinalDirection(context.angle)
			local suffix, angle = GetDieAnimSuffix(context, dir_angle)
			local variations = CheckNearbyPass(context.pos, dir_angle)
			return "civ_DeathWall" .. suffix, variations, context.pos, angle
		end,
	},
	{
		Name = "Death_Wall_OverNextSlab",
		Condition = function(context)
			if not context.close_shot_dist or not context.move_pos1 then
				return false
			end
			local dx = context.move_pos1:x() - context.pos:x()
			local dy = context.move_pos1:y() - context.pos:y()
			if dx * dy ~= 0 then
				return false -- diagonal move
			end
			if GetAngleCover(context.move_pos1, CardinalDirection(context.angle)) ~= const.CoverHigh then
				return false -- no cover
			end
			return true
		end,
		Animation = function(context)
			local dir_angle = CardinalDirection(context.angle)
			local suffix, angle = GetDieAnimSuffix(context, dir_angle)
			local variations = CheckNearbyPass(context.pos, dir_angle)
			return "civ_DeathWall_x1" .. suffix, variations, context.move_pos1, angle
		end,
	},
	{
		Name = "Death_Fall",
		Condition = function(context)
			if not context.close_shot_dist or context.move_slabs ~= 0 then
				return false
			end
			local tunnel = GetTunnelDir(context.pos, CardinalDirection(context.angle), const.TunnelMaskDrop)
			if not tunnel then
				return false
			end
			return true
		end,
		Animation = function(context)
			local tunnel = GetTunnelDir(context.pos, CardinalDirection(context.angle), const.TunnelMaskDrop)
			if not tunnel then
				return
			end
			local suffix, angle = GetDieAnimSuffix(context, CardinalDirection(context.angle))
			local anim = string.format("civ_DeathFall_x%d%s", tunnel.tiles, suffix)
			return anim, true, tunnel:GetExit(), angle
		end,
	},
	{
		Name = "Death_Window",
		Condition = function(context)
			if not context.close_shot_dist or context.move_slabs ~= 0 then
				return false
			end
			if (context.hit_descr.impact_force or 0) < 1 then
				return false
			end
			local tunnel = GetTunnelDir(context.pos, CardinalDirection(context.angle), const.TunnelTypeWindow | const.TunnelTypeJumpOver1)
			if not tunnel then
				return false
			end
			local move_pos = tunnel:GetExit()
			local next_pos = GetPassSlab(RotateRadius(const.SlabSizeX, context.angle, move_pos))
			if not next_pos or not IsPassSlabStep(move_pos, next_pos, const.TunnelTypeWalk) then
				return false -- annimations enter the next tile
			end
			return true
		end,
		Animation = function(context)
			local tunnel = GetTunnelDir(context.pos, CardinalDirection(context.angle), const.TunnelTypeWindow | const.TunnelTypeJumpOver1)
			if not tunnel then
				return
			end
			local suffix, angle = GetDieAnimSuffix(context, CardinalDirection(context.angle))
			local anim = "civ_DeathWindow" .. suffix
			local break_obj
			if tunnel.tunnel_type & const.TunnelTypeWindow ~= 0 then
				local obj = tunnel.pass_through_obj
				if obj.pass_through_state == "intact" then
					break_obj = obj
				end
			end
			return anim, true, tunnel:GetExit(), angle, break_obj
		end,
	},
	{
		Name = "Death_Railing",
		Condition = function(context)
			if not context.close_shot_dist or context.move_slabs ~= 0 then
				return false
			end
			if (context.hit_descr.impact_force or 0) < 1 then
				return false
			end
			local tunnel_mask = const.TunnelTypeWindow | const.TunnelTypeJumpOver1 | const.TunnelTypeJumpOver2
			local tunnel = GetTunnelDir(context.pos, CardinalDirection(context.angle), tunnel_mask)
			if not tunnel then
				return false
			end
			return true
		end,
		Animation = function(context)
			local angle = CardinalDirection(context.angle)
			local tunnel_mask = const.TunnelTypeWindow | const.TunnelTypeJumpOver1 | const.TunnelTypeJumpOver2
			local tunnel = GetTunnelDir(context.pos, angle, tunnel_mask)
			if not tunnel then
				return
			end
			local suffix, angle = GetDieAnimSuffix(context, angle)
			local anim = "civ_DeathRailing" .. suffix
			return anim, true, context.pos, angle
		end,
	},
	{
		Name = "Death_Over2Slabs",
		Condition = function(context)
			if not context.close_shot_dist or not context.move_pos3 then
				return false
			end
			if (context.hit_descr.impact_force or 0) < 3 then
				return false
			end
			return true
		end,
		Animation = function(context)
			local suffix, angle = GetDieAnimSuffix(context, context.angle)
			return "civ_DeathSlide" .. suffix, true, context.move_pos3, angle
		end,
	},
	{
		Name = "Death_OverNextSlab",
		Condition = function(context)
			-- the head is in the 3th tile
			if not context.close_shot_dist or context.move_slabs < 3 then
				return false
			end
			if (context.hit_descr.impact_force or 0) < 2 then
				return false
			end
			return true
		end,
		Animation = function(context)
			local suffix, angle = GetDieAnimSuffix(context, context.angle)
			return "civ_DeathBlow" .. suffix, true, context.move_pos2, angle
		end,
	},
	{
		Name = "Death_NextSlab",
		Condition = function(context)
			-- the head is in the 2th tile
			if context.move_slabs < 2 then
				return false
			end
			if (context.hit_descr.impact_force or 0) < 1 then
				return false
			end
			return true
		end,
		Animation = function(context)
			local suffix, angle = GetDieAnimSuffix(context, context.angle)
			local anim = "civ_Death" .. suffix
			local pos = context.move_pos1
			if not GetPassSlab(pos) then
				pos = point(
					Clamp(pos:x(), context.move_pos1:x() - const.SlabSizeX / 2, context.move_pos1:x() + const.SlabSizeX / 2 - 1),
					Clamp(pos:y(), context.move_pos1:y() - const.SlabSizeY / 2, context.move_pos1:y() + const.SlabSizeY / 2 - 1),
					context.move_pos1:z())
			end
			return "civ_Death" .. suffix, true, pos, angle
		end,
	},
	{
		Name = "Death_OnPlace",
		Condition = function(context)
			return true
		end,
		Animation = function(context)
			local suffix, angle = GetDieAnimSuffix(context, context.angle)
			return  "civ_DeathOnSpot" .. suffix, true, context.pos, angle
		end,
	},
}

function GetConditionGraphAnim(context)
	if not context.hit_descr then
		context.hit_descr = empty_table
	end
	if context.hit_descr.death_blow then
		local simple = table.find_value(s_ConditionsGraph, "Name", "Death_OverNextSlab")
		local anim, variations, pos, angle, param = simple.Animation(context)
		if anim and IsValidAnim(context.unit, anim) then
			return anim, variations, pos, angle, param
		end
	end
	if context.unit.ImportantNPC then
		local simple = table.find_value(s_ConditionsGraph, "Name", "Death_OnPlace")
		local anim, variations, pos, angle, param = simple.Animation(context)
		if anim and IsValidAnim(context.unit, anim) then
			return anim, variations, pos, angle, param
		end
	end
	
	for _, node in ipairs(s_ConditionsGraph) do
		if string.match(node.Name, context.pattern) and (context.skip_condition or node.Condition(context)) then
			local anim, variations, pos, angle, param = node.Animation(context)
			if anim and IsValidAnim(context.unit, anim) then
				return anim, variations, pos, angle, param
			end
		end
	end
end

function GetDeathBaseAnim(unit, context)
	local hit_descr = context and context.hit_descr

	local variations
	if unit.species == "Hyena" and hit_descr then
		if (hit_descr.death_explosion or (hit_descr.prev_hit_points or Max(0, unit.HitPoints)) - (hit_descr.raw_damage or 0) <= -20) then
			variations = { "death2", "death3" }
		end
	end
	if variations then
		return variations[1], variations
	end

	if unit.species ~= "Human" or unit.stance == "Prone" then
		local base_anim = unit:TryGetActionAnim("Death", unit.stance)
		return base_anim, true
	end

	context = context or {}
	context.unit = context.unit or unit
	if not context.pos then
		context.pos = context.hit_descr and context.hit_descr.die_pos or FindFallDownPos(unit) or GetPassSlab(unit) or unit:GetPos()
	end
	if not context.angle then
		if context.target_pos then
			context.angle = CalcOrientation(unit, context.target_pos)
		elseif context.attacker then
			context.angle = CalcOrientation(context.attacker, unit)
		else
			context.angle = unit:GetOrientationAngle() + 180 * 60
		end
	end
	local move_slabs = 0
	local move_pos = context.pos
	while move_slabs < 4 do
		local next_pos = GetPassSlab(RotateRadius((move_slabs + 1) * const.SlabSizeX, context.angle, context.pos))
		if not next_pos or not IsPassSlabStep(move_pos, next_pos, const.TunnelTypeWalk) then
			break
		end
		move_slabs = move_slabs + 1
		move_pos = next_pos
		context["move_pos" .. move_slabs] = next_pos
	end
	context.move_slabs = move_slabs

	if context.close_shot_dist == nil and context.attacker then
		if not IsKindOf(context.hit_descr.weapon, "MeleeWeapon") then
			if IsCloser(unit, context.attacker, 5 * const.SlabSizeX) then
				context.close_shot_dist = true
			end
		end
	end
	if not context.pattern then
		context.pattern = "^Death_"
	end
	return GetConditionGraphAnim(context)
end

function GetRandomDeathAnim(unit, context)
	local base_anim, variations, pos, angle, param = GetDeathBaseAnim(unit, context)
	local anim
	if type(variations) == "table" then
		anim = variations[1 + (#variations > 1 and unit:Random(#variations) or 0)]
	elseif base_anim and variations ~= false then
		anim = unit:GetNearbyUniqueRandomAnim(base_anim)
	end
	if not anim then
		anim = base_anim or "death"
	end
	return anim, pos, angle, param
end

function TestDeathAnim(unit, pos, angle, context, variant)
	unit:SetPos(pos or context.pos or GetPassSlab(unit) or unit:GetPos())
	unit:SetAxis(axis_z)
	unit:SetAngle(angle or unit:GetAngle())
	unit:SetState(unit:GetIdleBaseAnim("Standing"), 0, 0)
	local base_anim, variations, pos, angle, param = GetDeathBaseAnim(unit, context)
	if not base_anim then
		print("No death anim")
		return
	end
	if not IsValidAnim(unit, base_anim) then
		printf("Invalid death animation: %s", base_anim)
		return
	end
	local anim
	if type(variations) == "table" then
		anim = variations[variant]
	elseif variant and variant > 1 then
		anim = base_anim .. variant
	else
		anim = base_anim
	end
	if not IsValidAnim(unit, anim) then
		printf("Invalid death animation: %s", anim)
		return
	end
	printf("Death animation: %s, angle = %d", anim, angle/60)
	unit:SetCommand("PlayDying", false, false, anim, pos, angle, param)
end
