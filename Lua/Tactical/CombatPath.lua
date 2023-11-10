DefineClass.CombatPath = {
	__parents = { "InitDone" },
	unit = false,
	start_pos = false,
	stance = false,
	ap = 0,
	move_modifier = 0,
	restrict_area = false,

	destinations = empty_table, -- map: packed_pos -> true (possibly occupied points are not present here)
	paths_ap = empty_table,           -- map: packed_pos -> cost ap
	paths_prev_pos = empty_table,     -- map: pos -> previous pos (start pos -> false)
	closest_free_pos = false,         -- closest not occupied pos
	destination_stances = false,      -- for merged combat path it holds the stance to arrive at that destination
}

function CombatPath:RebuildPaths(unit, ap, pos, stance, ignore_occupied, move_through_occupied, action_id)
	stance = stance or unit and unit.stance or "Standing"
	ap = ap or unit and unit.ActionPoints or 0

	self.unit = unit
	self.stance = stance
	self.ap = ap
	self.start_pos = pos or unit and unit:GetPos()
	if ap < 0 then
		self.destinations = nil
		self.paths_ap = nil
		self.paths_prev_pos = nil
		self.closest_free_pos = nil
		return
	end
	local consts = Presets.ConstDef["Action Point Costs"]
	local side = unit and unit.team and unit.team.side
	local player_controlled = (side == "player1" or side == "player2")

	local stance_modifier = 0
	if stance == "Crouch" then
		stance_modifier = consts["CrouchModifier"].value
	elseif stance == "Prone" then
		stance_modifier = consts["ProneModifier"].value
	end

	local tunnel_mask
	if side and side ~= "neutral" and unit.body_type == "Human" then
		if stance == "Prone" then
			tunnel_mask = player_controlled and const.TunnelMaskPlayerProne or const.TunnelMaskAIProne
		else
			tunnel_mask = player_controlled and const.TunnelMaskPlayerStanding or const.TunnelMaskAIStanding
		end
	end

	self.move_modifier = unit and unit:GetMoveModifier(stance, action_id) or 0
	local move_modifier = Max(-100, self.move_modifier)
	local walk_modifier = stance_modifier + move_modifier
	local vertical_move_modifier = 0
	if HasPerk(unit, "DeathFromAbove") then
		vertical_move_modifier = CharacterEffectDefs.DeathFromAbove:ResolveValue("vertical_cost_modifier")
	end
	local tunnel_param = {
		unit = unit,
		player_controlled = player_controlled,
		move_modifier = move_modifier,
		walk_modifier = walk_modifier,
		walk_stairs_modifier = Max(-100, walk_modifier + vertical_move_modifier),
		ladder_modifier = Max(-100, move_modifier + vertical_move_modifier),
		drop_down_modifier = Max(-100, move_modifier + vertical_move_modifier),
		climb_up_modifier = Max(-100, move_modifier + vertical_move_modifier),
	}
	local walk_cost = consts["Walk"].value * (100 + walk_modifier) / 100
	local avoid_mines = unit and not player_controlled

	self.destinations, self.paths_ap, self.paths_prev_pos, self.closest_free_pos = GetCombatPathPositions(unit, self.start_pos, ap, walk_cost, tunnel_param, tunnel_mask, self.restrict_area, ignore_occupied, move_through_occupied, avoid_mines)
end

function CombatPath:GetAP(pos, endStance)
	if not pos then return end
	local pos_type = type(pos)
	local ap, stance
	if pos_type == "number" then
		ap = self.paths_ap[pos]
		stance = self.stance_at_end or (self.destination_stances and self.destination_stances[pos])
		if endStance and stance and stance ~= endStance then
			return ap + GetStanceToStanceAP(stance, endStance)
		end
		return ap
	elseif pos_type == "table" then
		local min_cost
		for i, p in ipairs(pos) do
			local c = self:GetAP(p)
			if c and (not min_cost or c < min_cost) then
				min_cost = c
			end
		end
		return min_cost
	end
	
	pos = point_pack(pos)
	ap = self.paths_ap[pos]
	stance = self.stance_at_end or (self.destination_stances and self.destination_stances[pos])
	if ap and endStance and stance and stance ~= endStance then
		return ap + GetStanceToStanceAP(stance, endStance)
	end
	return ap
end

function CombatPath:GetCombatPathFromPos(pos)
	if not pos then return end
	local p = type(pos) == "number" and pos or point_pack(pos)
	local paths_prev_pos = self.paths_prev_pos
	if not paths_prev_pos[p] then
		return
	end
	local path = {}
	while p do
		table.insert(path, p)
		p = paths_prev_pos[p]
	end
	return path
end

function CombatPath:GetReachableMeleeRangePositions(target, check_occupied, min_ap)
	local list = GetMeleeRangePositions(self.unit, target, nil, check_occupied)
	local paths_ap = self.paths_ap
	for i = list and #list or 0, 1, -1 do
		local ap = paths_ap[list[i]]
		if not ap or min_ap and ap < min_ap or not self.destinations[list[i]] then
			table.remove(list, i)
		end
	end
	return list
end

function CombatPath:GetClosestMeleeRangePos(target, target_pos, check_free, interaction)
	local list = GetMeleeRangePositions(self.unit, target, target_pos, check_free)
	local paths_ap = self.paths_ap
	local closest, min_ap
	for i, packed_pos in ipairs(list) do
		local ap = paths_ap[packed_pos]
		if ap and (not min_ap or ap < min_ap) and (not check_free or self.destinations[packed_pos]) then
			if interaction or IsMeleeRangeTarget(self.unit, packed_pos, nil, target, target_pos) then
				closest = packed_pos
				min_ap = ap
			end
		end
	end
	if closest then
		return point(point_unpack(closest))
	end
end

function GetCombatPathLen(path, obj)
	local len = 0
	if #path > 0 then
		local x1, y1, z1 = point_unpack(path[1])
		for i = 2, #path do
			local x2, y2, z2 = point_unpack(path[i])
			len = len + GetLen(x2 - x1, y2 - y1, (z1 or z2) and (z2 or terrain.GetHeight(x2, y2)) - (z1 or terrain.GetHeight(x1, y1)) or 0)
			x1, y1, z1 = x2, y2, z2
		end
		if IsValid(obj) and obj:IsValidPos() then
			len = len + obj:GetVisualDist(x1, y1, z1)
		end
	end
	return len
end
