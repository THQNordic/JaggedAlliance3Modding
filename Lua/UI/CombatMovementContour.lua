local g_DbgCombatFootsteps = false

DefineClass.CombatMovementContour = {
	__parents = { "IModeCommonUnitControl" },
	fx_path = false,
	target_path = false,
	
	borderline_attack = false,
	borderline_attack_voxels = false,
	borderline_turns = false,
	borderline_turns_voxels = false,
	
	fx_borderline_attack = false,
	fx_borderline_turns = false,
	
	fx_borderline_spawned_data_attack = false,
	fx_borderline_spawned_data_turn = false,
	
	movement_mode = false,
}

function CombatMovementContour:Init()
	self.fx_borderline_turns = {}
	self.borderline_turns = {}
	self.borderline_turns_voxels = {}
end

function CombatMovementContour:GetAttackContourPreset(inside_attack_area)
	return (inside_attack_area and "BorderlineAttackActive" or "BorderlineAttackInactive"), inside_attack_area
end

function CombatMovementContour:UpdateContoursFX(show_contours, inside_attack_area, inside_playable_area)
	show_contours = show_contours and not not g_Combat
	local attack_borderlines = show_contours and self.borderline_attack
	local turn_borderlines = show_contours and self.borderline_turns

	-- If showing the contours check if their hash has changed in which
	-- case we need to recreate the mesh.
	local newBorderlineAttackHash = false
	local newTurnBorderlineHash = false
	local difference = false
	if show_contours then
		newBorderlineAttackHash = table.hash(attack_borderlines)
		newTurnBorderlineHash = table.hash(turn_borderlines)
		if self.fx_borderline_spawned_data_attack ~= newBorderlineAttackHash then
			difference = true
		end
		if self.fx_borderline_spawned_data_turn ~= newTurnBorderlineHash then
			difference = true
		end
	end

	if difference or not show_contours then
		-- Clear attack
		if self.fx_borderline_attack then
			self.fx_borderline_attack:delete()
			self.fx_borderline_attack = false
		end
		
		-- Clear turn
		local turnFx = self.fx_borderline_turns
		if turnFx and #turnFx > 0 then
			for i, t in ipairs(turnFx) do
				turnFx[i]:delete()
				turnFx[i] = nil
			end
		end
	end
	self.fx_borderline_spawned_data_attack = newBorderlineAttackHash
	self.fx_borderline_spawned_data_turn = newTurnBorderlineHash
	
	-- Not showing anything
	if not show_contours then return end

	-- create/update attack borderline
	local borderline_exclude_pts = false
	if attack_borderlines then
		local origin_voxel = self.target_path and self.target_path[#self.target_path]
		local origin_pos = origin_voxel and point(point_unpack(origin_voxel))
		if InsideAttackArea(self, origin_pos) then
			inside_attack_area = true
		end
		
		local fx = self.fx_borderline_attack
		if not fx then
			fx = RangeContourMesh:new({})
			fx:SetPolyline(self.borderline_attack)
		end
		local _, is_active = self:GetAttackContourPreset(inside_attack_area)
		fx:SetPreset("Controller_CombatRange_Inner")
		fx:SetIsInside(is_active)
		fx:SetVisible(inside_playable_area ~= false or self.targeting_mode == "mobile" or self.targeting_mode == "melee" or self.targeting_mode == "melee-charge")
		borderline_exclude_pts = fx:Recreate()
		fx:SetPos(0, 0, 0)
		self.fx_borderline_attack = fx
	end

	-- create/update turn borderlines
	if turn_borderlines then
		for i = Max(#self.fx_borderline_turns, #turn_borderlines), 1, -1 do
			local contour = turn_borderlines[i]
			local fx = self.fx_borderline_turns[i]
			if not fx then
				fx = RangeContourMesh:new({})
				fx:SetPolyline(contour, borderline_exclude_pts)
				self.fx_borderline_turns[i] = fx
			end
			fx:SetPreset("Controller_CombatRange_Outer")
			fx:SetIsInside(inside_playable_area ~= false)
			fx:SetUseExcludePolyline( inside_playable_area ~= false )
			fx:SetVisible(turn_borderlines and true)
			fx:Recreate()
			fx:SetPos(0, 0, 0)
		end
	end
end

function CombatMovementContour:UpdateGotoFX(target_pos, inside_move_area, enemy_pos, inside_attack_area, mark_units)
	local target_unit
	local cursor_action = "CombatOutside"
	if inside_attack_area then
		cursor_action = "CombatAttack"
	elseif inside_move_area then
		cursor_action = "CombatMove"
	elseif enemy_pos then
		cursor_action = "CombatEnemy"
		target_unit = true
	elseif self.potential_target and self.potential_target:CanBeControlled() then
		cursor_action = "CombatAlly"
		target_unit = true
	end
	if not mark_units and target_unit then
		cursor_action = false
	end
	if mark_units and not target_unit then
		cursor_action = false
	end
	if cursor_action and target_pos then
		if not self.target_pos_has_unit and self.target_pos_occupied then
			cursor_action = "CombatMoveOccupied"
		end
		HandleMovementTileContour(false, target_pos, cursor_action)
	else
		SelectionAddedApplyFX(Selection)
	end
end

DefineClass.FXPathSteps = {
	__parents = {"Object"},
	
	steps_class = "UIUnitFootsteps",
	
	steps_last = false,
	steps_len = 0,
	steps_size = false,
	steps_color = false,
	steps_objects = false,
	
	voxel_attack = false,
	
	steps_block = 0,		-- for debug purposes only
}

function FXPathSteps:Init()
	self.steps_size = GetEntityBBox(self.steps_class):size():Len2D()
	self.steps_interval = self.steps_size
end

function FXPathSteps:Done()
	self:ClearSteps()
end

function FXPathSteps:SetPos(pos, ...)
	Object.SetPos(self, pos, ...)
	self.steps_last = pos
end

function FXPathSteps:CreateVoxelsMap(dialog)
	local voxel_attack = {}
	for _, voxels in ipairs(dialog.borderline_attack_voxels) do
		for _, voxel in ipairs(voxels) do
			voxel_attack[voxel] = true
		end
	end
	self.voxel_attack = voxel_attack
end

function FXPathSteps:IsAttackPos(pos)
	return self.voxel_attack[point_pack(GetPassSlab(pos) or self:GetPos())]
end

function FXPathSteps:AddSteps(pos, face)
	local steps = PlaceObject(self.steps_class)
	local _, z = WalkableSlabByPoint(pos)
	steps:SetPos(z and pos:SetZ(z) or pos:SetInvalidZ())
	steps:SetColorModifier(self.steps_color)
	steps:Face(face)
	if pos:z() ~= self.steps_last:z() then
		local last_z = self.steps_last:z() or terrain.GetHeight(self.steps_last)
		local delta_z = pos:z() - last_z
		if abs(delta_z) > 2 * guic then
			local tilt_axis = Cross(self.steps_last - pos, axis_z)
			local tilt_angle = 90 * 60 - CalcAngleBetween(self.steps_last - pos, axis_z)
			local axis, angle = ComposeRotation(steps:GetAxis(), steps:GetAngle(), tilt_axis, tilt_angle)
			steps:SetAxisAngle(axis, angle)
		end
	end
	self.steps_objects = self.steps_objects or {}
	table.insert(self.steps_objects, steps)
end

function FXPathSteps:SamplePathPos(pos)
	local dir = pos - self.steps_last
	local dist_to_last = pos:Dist2D(self.steps_last)
	self.steps_len = self.steps_len + dist_to_last
	if self.steps_len >= self.steps_interval then
		self.steps_len = 0
		self:AddSteps(pos, pos - dir)
	end
	self.steps_last = pos
end

function FXPathSteps:ClearSteps()
	for _, steps in ipairs(self.steps_objects or empty_table) do
		DoneObject(steps)
	end
	self.steps_objects = false
	self.steps_len = 0
	self.steps_block = 0
	self.steps_last = false
end

function FXPathSteps:SetStepsColorModifier(color)
	for _, steps in ipairs(self.steps_objects or empty_table) do
		steps:SetColorModifier(color)
	end
end

function FXPathSteps:AppendSteps(from_left, from_right, to_left, to_right)
	local steps_start = (from_left + from_right) / 2
	local steps_end = (to_left + to_right) / 2
	local steps_dir = steps_end - steps_start
	local steps_len = steps_dir:Len2D()
	
	if g_DbgCombatFootsteps then
		DbgAddVector(steps_start, steps_end - steps_start, const.clrRed)
	end
	self:SamplePathPos(steps_start)
	if steps_len == 0 then return end
	
	for k = 0, steps_len, 15 * guic do
		local steps_pos = steps_start + MulDivTrunc(steps_dir, k, steps_len)
		local placed = #(self.steps_objects or empty_table)
		self:SamplePathPos(steps_pos)
		if g_DbgCombatFootsteps then
			DbgAddVector(steps_pos, point(0, 0, 10 * guic * self.steps_block), #(self.steps_objects or empty_table) > placed and const.clrMagenta or const.clrWhite)
		end
	end
	self:SamplePathPos(steps_end)
end

local fx_path_offset = 15 * guic
local fx_path_width = 50*guic
local fx_turn_padding = 20*guic
local fx_turn_step = 15*60
local ptz = point(0, 0, guim)

function UpdatePathFX(mover_start, path, steps_obj, inside_attack_area, dialog)
	if g_DbgCombatFootsteps then
		DbgClear()
	end
	if not path or not next(path) then
		DoneObject(steps_obj)
		return false
	end
	
	-- create/delete steps object
	if not steps_obj then
		steps_obj = PlaceObject("FXPathSteps")
		steps_obj:CreateVoxelsMap(dialog)
	else
		steps_obj:ClearSteps()
	end
	
	local obj_pos = point(point_unpack(path[#path]))
	if not obj_pos:z() then
		obj_pos = obj_pos:SetTerrainZ()
	end
	steps_obj:SetPos(obj_pos)
	
	local path_radius = fx_path_width / 2
	local goto_pos = point(point_unpack(path[1]))
	if dialog.attacker and dialog.attacker:GetProvokePos(path, true) then
		steps_obj.steps_color = const.Combat.FootstepsOverwatchColor
	else
		steps_obj.steps_color = steps_obj:IsAttackPos(goto_pos) and const.Combat.FootstepsAttackColor or const.Combat.FootstepsColor
	end

	local had_turn
	local path_len = #path
	for i = path_len, 2, -1 do
		local from = point(point_unpack(path[i]))
		local to = point(point_unpack(path[i-1]))
		if not from:z() then
			from = from:SetZ(terrain.GetHeight(from))
		end
		from = from:AddZ(fx_path_offset)
		if not to:z() then
			to = to:SetZ(terrain.GetHeight(to))
		end
		to = to:AddZ(fx_path_offset)
		if g_DbgCombatFootsteps then
			DbgAddVector(to, point(0, 0, guim), const.clrGreen)
		end
		
		--compensate for first/last voxel (draw the line to the edge, not the center)
		do
			local fwd = to - from
			local fwd_x, fwd_y = fwd:xy()
			local angle = atan(fwd_y, fwd_x)
			if angle < 0 then angle = angle + 360*60 end
			
			local compensation = 0
			if angle < 45*60 or (angle > 135*60 and angle < 225*60) or angle > 315*60 then
				local sec = MulDivRound(4096, 4096, cos(angle))
				compensation = MulDivRound(abs(sec), const.SlabSizeX/2, 4096)
			else
				local csc = MulDivRound(4096, 4096, sin(angle))
				compensation = MulDivRound(abs(csc), const.SlabSizeY/2, 4096)
			end
		end
		
		if from ~= to then
			local vforward = SetLen(to - from, guim)
			local vright = SetLen(Cross(ptz, vforward), guim)
			local vup = SetLen(Cross(vforward, vright), guim)
			if g_DbgCombatFootsteps then
				--DbgAddVector(from, vforward, const.clrRed)
				--DbgAddVector(from, vright, const.clrGreen)
				--DbgAddVector(from, vup, const.clrBlue)
			end
			
			-- adjust for turns
			if had_turn then
				from = from + MulDivRound(vforward, path_radius + fx_turn_padding, guim)
			end
			
			-- turn triangles
			local angle
			local next_from, next_to
			local next_vforward, next_vright
			local turn_angle
			if i > 2 then
				-- segment after the turn
				next_from = point(point_unpack(path[i-1]))
				next_to = point(point_unpack(path[i-2]))
				if not next_from:z() then
					next_from = next_from:SetZ(terrain.GetHeight(next_from))
				end
				next_from = next_from:AddZ(fx_path_offset)
				if not next_to:z() then
					next_to = next_to:SetZ(terrain.GetHeight(next_to))
				end
				next_to = next_to:AddZ(fx_path_offset)
				
				next_vforward = SetLen(next_to - next_from, guim)
				next_vright = SetLen(Cross(ptz, next_vforward), guim)
				
				--check if there is an actual turn
				local vforward2d, next_vforward2d =
					SetLen(vforward:SetZ(const.InvalidZ), guim),
					SetLen(next_vforward:SetZ(const.InvalidZ), guim)
				if vforward2d ~= next_vforward2d then
					local from_x, from_y = from:xy()
					local to_x, to_y = to:xy()
					local next_from_x, next_from_y = next_from:xy()
					local next_to_x, next_to_y = next_to:xy()
					
					--segment angles (world space)
					local first_angle = atan(to_y - from_y, to_x - from_x)
					if first_angle < 0 then first_angle = first_angle + 360*60 end
					local second_angle = atan(next_to_y - next_from_y, next_to_x - next_from_x)
					if second_angle < 0 then second_angle = second_angle + 360*60 end
					
					--compute signed turn angle
					turn_angle = second_angle - first_angle
					if turn_angle <= -180*60 then turn_angle = turn_angle + 360*60 end
					if turn_angle > 180*60 then turn_angle = turn_angle - 360*60 end
					
					if abs(turn_angle) <= 10 or abs(turn_angle - 180*60) <= 10 then --fix for rounding errors in atan()
						turn_angle = false
					else
						angle = first_angle
						
						--compensate for turn
						next_from = next_from + MulDivRound(next_vforward, path_radius + fx_turn_padding, guim)
					end
				end
			end
			
			--adjust for turn
			had_turn = not not turn_angle
			if turn_angle then
				to = to - MulDivRound(vforward, path_radius + fx_turn_padding, guim)
			end
			
			--append the quad
			local offset = MulDivRound(vright, path_radius, guim)
			local from_left = from - offset
			local from_right = from + offset
			local to_left = to - offset
			local to_right = to + offset
			
			steps_obj.steps_block = steps_obj.steps_block + 1
			steps_obj:AppendSteps(from_left, from_right, to_left, to_right)
			
			--append the turn quads/triangles
			if turn_angle then
				--quads
				local p1, p2 = to, next_from
				local r1, r2 = vright, next_vright
				
				local p1x, p1y = p1:xy()
				local p2x, p2y = p2:xy()
				local r1x, r1y = r1:xy()
				local r2x, r2y = r2:xy()
				
				local anchor_dist, anchor
				if r2x ~= 0 and r2x*r1y - r1x*r2y ~= 0 then
					anchor_dist = MulDivRound(
						r2y*(p1x-p2x) + r2x*(p2y-p1y),
						guim,
						r2x*r1y - r1x*r2y )
					anchor = p1 + MulDivRound(r1, anchor_dist, guim)
				elseif r1x ~= 0 then
					anchor_dist = MulDivRound(
						p2x - p1x,
						guim,
						r1x)
					anchor = p1 + MulDivRound(r1, anchor_dist, guim)
				else
					assert(false)
				end
				
				local dist1_left = anchor:Dist2D(to_left)
				local dist1_right = anchor:Dist2D(to_right)
				local dist2_left = anchor:Dist2D(next_from - MulDivRound(next_vright, path_radius, guim))
				local dist2_right = anchor:Dist2D(next_from + MulDivRound(next_vright, path_radius, guim))
				
				local steps = DivCeil(abs(turn_angle), fx_turn_step)
				local step_angle = DivCeil(abs(turn_angle), steps)
				local delta_z = next_from:z() - to:z()
				steps_obj.steps_block = steps_obj.steps_block + 1
				for step=0,steps do
					local chamfer_angle = Clamp(step*step_angle, 0, abs(turn_angle))
					local dir
					
					if turn_angle < 0 then
						chamfer_angle = -chamfer_angle
						
						local sin, cos = sincos(angle + 90*60 + chamfer_angle)
						dir = SetLen(point(cos, sin, 0), guim)
					else
						local sin, cos = sincos(angle - 90*60 + chamfer_angle)
						dir = SetLen(point(cos, sin, 0), guim)
					end
					
					local dz = MulDivRound(delta_z, step, steps)
					
					local dist_left = MulDivRound(dist2_left - dist1_left, step, steps) + dist1_left
					local dist_right = MulDivRound(dist2_right - dist1_right, step, steps) + dist1_right
					
					local chamfer_left = anchor + MulDivRound(dir, dist_left, guim):AddZ(dz)
					local chamfer_right = anchor + MulDivRound(dir, dist_right, guim):AddZ(dz)
					
					steps_obj:AppendSteps(to_left, to_right, chamfer_left, chamfer_right)
					to_left, to_right = chamfer_left, chamfer_right
				end
			end
		end
	end

	return steps_obj
end

function GenerateAttackContour(attack, attacker, combatPath, customCombatPath)
	assert(g_Combat and attack and attacker)
	combatPath = combatPath or GetCombatPath(attacker)
	
	local borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels = {}, {}, {}, {}
	local voxels = {}
	local reload = CombatActions.Reload
	local attackerAP, attackAP
	
	if not customCombatPath and CombatActions.Move:GetUIState{attacker} ~= "enabled" then
		return borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels
	end
	
	if customCombatPath then
		-- generate a single contour on all voxels from the given combatPath
		for voxel, ap in pairs(combatPath.paths_ap) do
			if ap > 0 or GetPassSlab(point_unpack(voxel)) then
				table.insert(voxels, voxel)
			end
		end
		borderline_attack = #voxels > 0 and GetRangeContour(voxels) or false
		borderline_attack_voxels[1] = voxels
	else
		-- generate attack move contours
		if attack:GetUIState({attacker}) == "enabled" and not attacker:IsWeaponJammed() then
			local actionCost, displayActionCost = attack:GetAPCost(attacker)
			if displayActionCost then actionCost = displayActionCost end

			attackAP = actionCost
			attackerAP = attacker:GetUIActionPoints() - actionCost + attacker.free_move_ap
			if attacker:OutOfAmmo() and attack.ActionType == "Ranged Attack" then
				attackerAP = attackerAP - reload:GetAPCost(attacker)
			end
		end
		if attackerAP and attackerAP > 0 then
			for voxel, ap in pairs(combatPath.paths_ap) do
				if ap <= attackerAP and (ap > 0 or GetPassSlab(point_unpack(voxel))) then
					table.insert(voxels, voxel)
				end
			end
		end
		borderline_attack_voxels[1] = voxels
		borderline_attack = false
		if #voxels > 0 then
			local contour_width = const.ContoursWidth_BorderlineAttack
			local radius2D = nil -- default
			local offset = const.ContoursOffset_BorderlineAttack
			local offsetz = const.ContoursOffsetZ_BorderlineAttack
			borderline_attack = GetRangeContour(voxels, contour_width, radius2D, offset, offsetz) or false
		end

		-- generate turn move contours
		local attack_voxels = voxels
		voxels = {}
		local max = attacker:GetUIActionPoints() + attacker.free_move_ap
		for voxel, ap in pairs(combatPath.paths_ap) do
			if ap > -1 and ap <= max and (ap > 0 or GetPassSlab(point_unpack(voxel))) then
				table.insert(voxels, voxel)
			end
		end
		if #voxels > 0 then
			borderline_turns_voxels[1] = voxels
			local contour_width = const.ContoursWidth_BorderlineTurn
			local radius2D = nil -- default
			local offset = const.ContoursOffset_BorderlineTurn
			local offsetz = const.ContoursOffsetZ_BorderlineTurn
			borderline_turns[1] = GetRangeContour(voxels, contour_width, radius2D, offset, offsetz)
		end
	end
	
	return borderline_attack, borderline_attack_voxels, borderline_turns, borderline_turns_voxels, attackAP
end

-- Check if the pos is inside the attack outlined area
function InsideAttackArea(dialog, goto_pos)
	-- In attack modes always consider as being inside the attack area.
	if dialog.action then
		return true
	end
	if not goto_pos then
		return false
	end
	local mover = dialog.attacker
	local combatPath = GetCombatPath(mover)
	local costAP = combatPath and combatPath:GetAP(goto_pos)
	if costAP and not mover:IsWeaponJammed() then
		local action = dialog.action or mover:GetDefaultAttackAction()
		local actionAp = action:GetAPCost(mover)
		local attackAP = actionAp > 0 and mover:GetUIActionPoints() + mover.free_move_ap - actionAp or 0
		if mover:OutOfAmmo() then
			attackAP = attackAP - CombatActions.Reload:GetAPCost(mover)
		end
		return costAP <= attackAP
	end
	return false
end