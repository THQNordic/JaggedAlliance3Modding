local MaxSlabMoveTiles = const.MaxSlabMoveTiles
local MaxSlabMoveTilesZ = const.MaxSlabMoveTilesZ
local tilex = const.SlabSizeX
local tiley = const.SlabSizeY
local tilez = const.SlabSizeZ
local sqrt2_10000 = sqrt(2 * 10000 * 10000)
local IsPassable = terrain.IsPassable
local GetTerrainHeight = terrain.GetHeight

TunnelExplorationAdditionalCosts = {
	SlabTunnelDrop1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelDrop2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelDrop3 = "ExplorationActionMovesModifierStrong",
	SlabTunnelDrop4 = "ExplorationActionMovesModifierStrong",
	SlabTunnelClimb1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelClimb2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelClimb3 = "ExplorationActionMovesModifierStrong",
	SlabTunnelClimb4 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpOver1 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpOver2 = "ExplorationActionMovesModifierStrong",
	SlabTunnelJumpAcross1 = "ExplorationActionMovesModifierWeak",
	SlabTunnelJumpAcross2 = "ExplorationActionMovesModifierWeak",
	SlabTunnelWindow = "ExplorationActionMovesModifierStrong",
}

function GetTunnelCost(tunnel, context)
	return tunnel:GetCost(context)
end

function ModifyAPCost(value, id)
	local consts = Presets.ConstDef["Action Point Costs"]
	local data = consts[id]
	if data.scale == "%" then
		value = value + MulDivTrunc(value, data.value, 100)
	else
		value = value + data.value * 1000
	end
	return value
end

function GetTunnelDir(pos, angle, mask)
	local tunnel
	pf.ForEachTunnel(pos, function(obj)
		if obj.tunnel_type & mask == 0 then
			return
		end
		if CalcOrientation(obj:GetEntrance(), obj:GetExit()) ~= angle then
			return
		end
		tunnel = obj
		return true
	end)
	return tunnel
end

DefineClass.TunnelObject = {
	__parents = { "CObject" },
}

function TunnelObject:PlaceTunnels()
end

function TunnelObject:GetWidthForTunnels()
	local width = self:HasMember("width") and self.width or nil
	if not width then
		local bb = self:GetEntityBBox("idle")
		width = (bb:sizey() + const.SlabSizeY / 2) / const.SlabSizeY
	end
	return Max(width, 1)
end

DefineClass.TunnelBlocker = {
	__parents = { "Object" },
	flags = { efVisible = false, efPathExecObstacle = true, cofComponentPath = true, efResting = true },
	owner = false,
	tunnel_end_point = false,
}

function TunnelBlocker:GetTunnel()
	return pf.GetTunnel(self:GetPos(), self.tunnel_end_point)
end

DefineClass.SlabTunnel = {
	__parents = { "PFTunnel" },
	flags = { efVisible = false },
	end_point = false,
	tunnel_type = 0,
	can_sprint_through = false,
	base_cost = false,
	modifier = 0,
	traverse_params = false,
}

function SlabTunnel:AddPFTunnel()
	local pos1 = self:GetEntrance()
	local pos2 = self:GetExit()
	local exploration_additional_cost = GetSpecialMoveAPCost(TunnelExplorationAdditionalCosts[self.class]) or 0
	if exploration_additional_cost > 0 then
		exploration_additional_cost = exploration_additional_cost * (GetSpecialMoveAPCost("Walk") or 0)
	end
	local exploration_cost = self.base_cost * (100 + self.modifier) / 100 + exploration_additional_cost
	pf.AddTunnel(self, pos1, pos2, exploration_cost, self.tunnel_type, -1)
end

function SlabTunnel:RemovePFTunnel()
	pf.RemoveTunnel(self, self:GetPos(), self.end_point)
end

function SlabTunnel:GetEntrance()
	return self:GetPos()
end

function SlabTunnel:GetExit()
	return self.end_point
end

function SlabTunnel:CanSprintThrough(unit, pos1, pos2)
	return self.can_sprint_through
end

function SlabTunnel:InteractTunnel(unit, quick_play)
	return true, quick_play
end

function SlabTunnel:TraverseTunnel(unit, pos1, pos2, quick_play)
	self:SetPos(pos2)
end

function SlabTunnel:GetTraverseParam(obj)
	if not obj then return end
	for i, params in ipairs(self.traverse_params) do
		if obj:IsKindOf(params[1]) then
			return params[2]
		end
	end
end

function CanUseTunnel(tunnel_entrance, tunnel_exit, unit)
	local o = MapGetFirst(tunnel_entrance, 0, "TunnelBlocker", function(o, end_pos, ignore_blockers)
		if o.tunnel_end_point ~= tunnel_exit then
			return false
		end
		if ignore_blockers and table.find(ignore_blockers, o) then
			return false
		end
		return true
	end, tunnel_exit, unit and unit.tunnel_blockers)
	if o then
		return false
	end
	return true
end

function SlabTunnel:IsBlocked()
	return false
end

function SlabTunnel:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.move_modifier or 0)) / 100
end

function GetSpecialMoveAPCost(id)
	return id and Presets.ConstDef["Action Point Costs"][id].value
end

function PlaceSlabTunnel(classname, costAP, x1, y1, z1, x2, y2, z2)
	if not costAP then
		return
	end
	local pt1 = point(x1, y1, z1 or nil)
	local pt2 = point(x2, y2, z2 or nil)
	local tunnel = pf.GetTunnel(pt1, pt2)
	if tunnel then
		if tunnel.base_cost < costAP then
			return
		end
		tunnel:RemovePFTunnel()
		DoneObject(tunnel)
	end
	local obj = PlaceObject(classname, { end_point = pt2, base_cost = costAP })
	obj:SetPos(x1, y1, z1 or nil)
	obj:AddPFTunnel()
	return obj
end

DefineClass.SlabTunnelHelper = {
	__parents = {"Object"},
	entity = "SpotHelper",
	tunnel = false
}

function OnMsg.GameExitEditor()
	MapForEach("map", "SlabTunnelHelper", function(helper)
		DoneObject(helper)
	end)
end

function SlabTunnelHelper:EditorExit()
end
-- terrain to slab link
DefineClass.SlabTunnelWalk = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeWalk,
	can_sprint_through = true,
}

function SlabTunnelWalk:Init()
	assert(self.base_cost)
end

function SlabTunnelWalk:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.walk_modifier or 0)) / 100
end

function TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
	local anim = unit:GetMoveAnim()
	local angle = CalcOrientation(pos1, pos2)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetOrientationAngle(angle)
		return
	end
	-- can't use goto, because it clears unit destlock
	if unit:GetState() ~= anim then
		unit:SetState(anim)
	end
	if not pos1:IsValidZ() and pos2:IsValidZ() then
		unit:SetPos(pos1:SetTerrainZ())
	end
	local dest = not pos2:IsValidZ() and pos1:IsValidZ() and pos2:SetTerrainZ() or pos2
	while true do
		local dist = unit:GetVisualDist2D(pos2)
		if dist == 0 then
			break
		end
		local anim_speed = unit:GetMoveSpeed()
		unit:SetAnimSpeed(1, anim_speed)
		local time = dist * 1000 / Max(1, unit:GetSpeed())
		local rotate_time = Min(time, MulDivRound(300, 1000, Max(1, anim_speed)))
		unit:SetPos(dest, time)
		if unit.ground_orient then
			local angle_diff = AngleDiff(unit:GetVisualOrientationAngle(), angle)
			local steps = Max(1, rotate_time / 50)
			local speed_change
			for i = 1, steps do
				local t = rotate_time * i / steps - rotate_time * (i - 1) / steps
				local a = angle - angle_diff * (steps - i) / steps
				unit:SetGroundOrientation(a, t)
				speed_change = WaitWakeup(t) or unit:GetMoveSpeed() ~= anim_speed
				if speed_change then
					break
				end
			end
			if not speed_change then
				local move_time = time - rotate_time
				if move_time > 0 then
					local steps = 1 + unit:GetDist2D(unit:GetVisualPosXYZ()) / (const.SlabSizeX / 2)
					for i = 1, steps do
						local t = move_time * i / steps - move_time * (i - 1) / steps
						unit:SetGroundOrientation(angle, t)
						WaitWakeup(t)
					end
				end
			end
		else
			unit:SetAngle(angle, rotate_time)
			if use_stop_anim and unit.move_stop_anim_len > 0 then
				local wait_time = dist > unit.move_stop_anim_len and pf.GetMoveTime(unit, dist - unit.move_stop_anim_len) or 0
				local speed_change
				if wait_time > 0 then
					speed_change = WaitWakeup(wait_time) or unit:GetMoveSpeed() ~= anim_speed
				end
				if not speed_change then
					unit:ChangePathFlags(const.pfDirty)
					unit:GotoStop(pos2)
				end
			else
				WaitWakeup(time)
			end
		end
	end
	unit:SetPos(pos2)
end

function SlabTunnelWalk:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

-- Move Stairs
DefineClass.SlabTunnelStairs = {
	__parents = { "SlabTunnel" },
	tunnel_type = const.TunnelTypeStairs,
	can_sprint_through = true,
	dbg_tunnel_color = const.clrBlue,
	dbg_tunnel_zoffset = 20 * guic,
}

function SlabTunnelStairs:Init()
	assert(self.base_cost)
end

function SlabTunnelStairs:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

function SlabTunnelStairs:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.walk_stairs_modifier or 0)) / 100
end

function SlabTunnelStairs:CombineMove(move, unit)
	return false
end

-- Drop
DefineClass.SlabTunnelDrop = {
	__parents = { "SlabTunnel" },
	traverse_params = {
		{ "RoofSlab", 15*guic },
	},
}
DefineClass.SlabTunnelDrop1 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop1,
	tiles = 1,
}
DefineClass.SlabTunnelDrop2 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop2,
	tiles = 2,
}
DefineClass.SlabTunnelDrop3 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop3,
	tiles = 3,
}
DefineClass.SlabTunnelDrop4 = {
	__parents = { "SlabTunnelDrop" },
	tunnel_type = const.TunnelTypeDrop4,
	tiles = 4,
}

function SlabTunnelDrop:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.drop_down_modifier or 0)) / 100
end

function SlabTunnelDrop:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim("Drop", false, self.tiles)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveDrop", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveDrop", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	local stepz, step_obj = GetVoxelStepZ(pos1)
	local offset_2d = self:GetTraverseParam(step_obj) or 0
	if pos1:x() ~= pos2:x() and pos1:y() ~= pos2:y() then
		offset_2d = offset_2d + 20*guic
	end
	local angle = CalcOrientation(pos1, pos2)
	local stepz1_1 = GetVoxelStepZ(pos1 + Rotate(point(const.SlabSizeX / 4, 30*guic, 0), angle))
	local stepz1_2 = GetVoxelStepZ(pos1 + Rotate(point(const.SlabSizeX / 4, -30*guic, 0), angle))
	local dz1 = 2 * (Max(stepz1_1, stepz1_2) - stepz)
	local start_offset = Rotate(point(offset_2d, 0, dz1), angle)

	unit:MovePlayAnim(anim, pos1, pos2, nil, nil, nil, angle, start_offset, point30)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

-- Climb
DefineClass.SlabTunnelClimb = {
	__parents = { "SlabTunnel" },
	traverse_params = {
		{ "RoofSlab", -15*guic },
	},
}
DefineClass.SlabTunnelClimb1 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb1,
	tiles = 1,
}
DefineClass.SlabTunnelClimb2 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb2,
	tiles = 2,
}
DefineClass.SlabTunnelClimb3 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb3,
	tiles = 3,
}
DefineClass.SlabTunnelClimb4 = {
	__parents = { "SlabTunnelClimb" },
	tunnel_type = const.TunnelTypeClimb4,
	tiles = 4,
}

function SlabTunnelClimb:GetCost(context)
	return self.base_cost * (100 + self.modifier + (context and context.climb_up_modifier or 0)) / 100
end

function SlabTunnelClimb:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim("Climb", false, self.tiles)
	--local hidden_weapon
	--if climb_tiles > 1 and unit:HideActiveMeleeWeapon() then
	--	hidden_weapon = true
	--	unit:PushDestructor(unit.ShowActiveMeleeWeapon)
	--end

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveClimb", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveClimb", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	local stepz2, step_obj2 = GetVoxelStepZ(pos2)
	local offset_2d = self:GetTraverseParam(step_obj2) or 0
	if pos1:x() ~= pos2:x() and pos1:y() ~= pos2:y() then
		offset_2d = offset_2d - 20*guic
	end
	local angle = CalcOrientation(pos1, pos2)
	local stepz2_1 = GetVoxelStepZ(pos2 - Rotate(point(const.SlabSizeX / 4, 30*guic, 0), angle))
	local stepz2_2 = GetVoxelStepZ(pos2 - Rotate(point(const.SlabSizeX / 4, -30*guic, 0), angle))
	local dz2 = 2 * (Max(stepz2_1, stepz2_2) - stepz2)
	local end_offset = Rotate(point(offset_2d, 0, dz2), angle)

	unit:MovePlayAnim(anim, pos1, pos2, nil, nil, nil, nil, point30, end_offset)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()

	--if hidden_weapon then
	--	unit:PopAndCallDestructor()
	--end
end

-- Jump
DefineClass.SlabTunnelJump = {
	__parents = { "SlabTunnel" },
	action = false,
	can_sprint_through = true,
}

function SlabTunnelJump:TraverseTunnel(unit, pos1, pos2, quick_play)
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim(self.action, false)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveJump", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveJump", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	unit:MovePlayAnim(anim, pos1, pos2)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

DefineClass.SlabTunnelJumpOver1 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpOver1,
	action = "JumpOverShort",
}
DefineClass.SlabTunnelJumpOver2 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpOver2,
	action = "JumpOverLong",
}
DefineClass.SlabTunnelJumpAcross1 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpAcross1,
	action = "JumpAcross1",
}
DefineClass.SlabTunnelJumpAcross2 = {
	__parents = { "SlabTunnelJump" },
	tunnel_type = const.TunnelTypeJumpAcross2,
	action = "JumpAcross2",
}

local drop_ids = { "Drop1", "Drop2", "Drop3", "Drop4" }
local climb_ids = { "Climb1", "Climb2", "Climb3", "Climb4" }
local query_flags = const.cqfSingleResult  + const.cqfResultIfStartInside + const.cqfFrontAndBack

local function CapsuleCollides(center, half_extent, radius, mask_any, filter)
	mask_any = mask_any or (const.cmObstruction + const.cmTerrain + const.cmPassability)
	
	local collides
	collision.Collide(center, half_extent, radius, point30, query_flags, 0, mask_any, function(obj)
		if not filter or filter(obj) then
			collides = true
			return true
		end
	end)
	
	return collides
end

-- return voxelz, passz, stepz, voxel custom data
local function FindPassVoxelZ(x, y, z1, z2, voxel_pass)
	local terrain_z, terrain_voxel_z
	for voxelz = z1, z2, z1 <= z2 and tilez or -tilez do
		if voxel_pass then
			local vinfo = GetSlabPassDataFromC(point(x, y, voxelz))
			if vinfo then
				local stepz = vinfo.z or voxelz
				return voxelz, stepz, stepz, vinfo
			end
		end
		if IsPassable(x, y, voxelz, 0) then
			local stepz = GetVoxelStepZ(x, y, voxelz)
			return voxelz, stepz, stepz
		end
		if not terrain_z then
			terrain_z = GetTerrainHeight(x, y)
			terrain_voxel_z = SnapToVoxelZ(x, y, terrain_z)
		end
		if voxelz == terrain_voxel_z and IsPassable(x, y) then
			return voxelz, nil, terrain_z
		end
	end
end

local function AddTunnelPoints(points, x1, y1, x2, y2, voxelz, minz, vinfo)
	local voxelz1, z1, stepz1 = FindPassVoxelZ(x1, y1, voxelz, minz, vinfo)
	local voxelz2, z2, stepz2 = FindPassVoxelZ(x2, y2, voxelz, minz, vinfo)
	if voxelz1 and voxelz2 then
		local ztiles = (abs(stepz1 - stepz2) + tilez/2) / tilez
		local insert = table.insert
		if voxelz - voxelz1 <= tilez and (ztiles < 2 or CheckHeroPassLine(x2, y2, stepz1, x2, y2, stepz2 + tilez)) then
			insert(points, x1)
			insert(points, y1)
			insert(points, z1 or false)
			insert(points, x2)
			insert(points, y2)
			insert(points, z2 or false)
		end
		if voxelz - voxelz2 <= tilez and (ztiles < 2 or CheckHeroPassLine(x1, y1, stepz2, x1, y1, stepz1 + tilez)) then
			insert(points, x2)
			insert(points, y2)
			insert(points, z2 or false)
			insert(points, x1)
			insert(points, y1)
			insert(points, z1 or false)
		end
	end
end

local function GetMovePassThroughObjSpots(obj, vinfo, max_drop_tiles)
	max_drop_tiles = max_drop_tiles or 0
	local voxelz = select(3, SnapToVoxel(0, 0, select(3, obj:GetVisualPosXYZ()) + tilez / 2))
	local minz = voxelz - tilez - max_drop_tiles * tilez
	local points = {}

	-- spots replace the default placement
	if obj:HasSpot("Tunnel") then
		local dx, dy = RotateAxis(point(tilex / 2, 0, 0), obj:GetAxis(), obj:GetAngle()):xy()
		local first_spot, last_spot = obj:GetSpotRange("Tunnel")
		for spot = first_spot, last_spot do
			local x, y, z = obj:GetSpotPosXYZ(spot)
			local x1, y1, z1 = SnapToVoxel(x + dx, y + dy, z)
			local x2, y2, z2 = SnapToVoxel(x - dx, y - dy, z)
			if x1 == x2 and abs(y1 - y2) == tiley or y1 == y2 and abs(x1 - x2) == tilex then
				AddTunnelPoints(points, x1, y1, x2, y2, voxelz, minz, vinfo)
			end
		end
		return points
	end

	local width = Max(1, obj:GetWidthForTunnels())

	--account for art being offset for some objs and not others.
	local _center_x, _center_y = obj:GetEntityBBox("idle"):Center():xy()
	local _x1 = _center_x - tilex / 2
	local _y1 = _center_y - tiley * (width - 1) / 2
	local x1, y1, z1 = SnapToVoxel(obj:GetRelativePointXYZ(_x1, _y1, 0))
	local x2, y2, z2 = SnapToVoxel(obj:GetRelativePointXYZ(_x1 + tilex, _y1, 0))
	if not (x1 == x2 and abs(y1 - y2) == tiley or y1 == y2 and abs(x1 - x2) == tilex) then
		return
	end

	local stepx, stepy = 0, 0
	if width > 1 then
		local posx, posy, posz = obj:GetPosXYZ()
		local rx, ry = obj:GetRelativePointXYZ(0, tiley, 0)
		if abs(rx - posx) >= abs(ry - posy) then
			stepx = rx > posx and tilex or -tilex
		else
			stepy = ry > posy and tiley or -tiley
		end
	end
	for w = 0, width - 1 do
		AddTunnelPoints(points, x1 + w * stepx, y1 + w * stepy, x2 + w * stepx, y2 + w * stepy, voxelz, minz, vinfo)
	end
	return points
end

DefineClass.Door = {
	__parents = { "CombatObject", "Interactable", "Lockpickable", "BoobyTrappable",
		"AutoAttachObject", "TunnelObject", "AttachLightPropertyObject"
	},
	entity = "Door_Planks_Single_01", 
	properties = {
		{ id = "HitPoints", name = "Hit Points", editor = "number", default = 30, no_edit = true, min = -1, max = 100 },
		{ category = "Interactable", id = "BadgePosition", name = "Badge Position", editor = "choice", items = { "self", "average" }, default = "self" },
		{ id = "impassable", name = "Impassable", editor = "bool", default = false, help = "If true, will not place passability tunnels and not allow for interact." },
	},
	flags = { efCollision = true, efApplyToGrids = true, },
	tunnel_class = "SlabTunnelDoor",
	pass_through_state = "closed", -- "open", "locked", "blocked"
	thread = false,
	interacting_unit = false,
	highlight_collection = false,
	interact_positions = false,
	decorations = false,
}

function DrawDecorationsContours()
	MapForEach("map", "Door", "WindowTunnelObject", function(obj)  
		local objFloor = obj.floor or (obj.room and obj.room.floor)
		local isOnSameFloor = objFloor == cameraTac.GetFloor() + 1
		if obj.impassable and isOnSameFloor then
			local decorations = {}
			local objFloor = obj.floor
			local allDecorations = MapGet(GrowBox(obj:GetObjectBBox(), const.SlabSizeX / 100))
			for _, decoration in ipairs(allDecorations) do
				local collections = ExtractCollectionsFromObjs({decoration})
				for col, _ in pairs(collections) do
					local data = GetRoomDataForCollection(col)
					local isLinked = not not data
					if isLinked then
						for room, sides in pairs(data or empty_table) do
							if room.floor == objFloor then
								decorations[#decorations + 1] = decoration
								decoration.floor = decoration.floor or obj.floor
								break
							end
						end
					end
				end
			end
			obj.decorations = decorations
		end
	end)
end

function OnMsg.NewMapLoaded()
	DrawDecorationsContours()
end

function Door:GameInit()
	local state = self.pass_through_state
	if self:GetStateText() == "open" then		
		state = "open"	-- level designer saved state overrides the class default state
	end
	self.pass_through_state = false
	self:SetDoorState(state)
	if self.impassable then
		self.lockpickState = "blocked"
		self.lockpickDifficulty = "Impossible"
	end
	
	-- Dont run interactable discovery for open doors
	if state == "open" then
		self.discovered = true
	end
end
Door.ShouldAttach = return_true

local maxColliders = const.maxCollidersPerObject or 4
local cmPassability = const.cmPassability

local function HasCollider(obj)
	for i = 0, maxColliders - 1 do
		if (collision.GetCollisionMask(obj, i) & cmPassability) ~= 0 then
			return true
		end
	end
	
	return false
end

local function lGetInteractionSpotsFromTunnelPoints(objAngle, points)
	local count = points and #points or 0
	local interact_positions = {}
	for i = 1, count, 6 do
		local x, y, z = table.unpack(points, i, i + 2)
		table.insert(interact_positions, point(x, y, z or nil))
	end
	local angle = objAngle + 90*60
	for i = 1, #interact_positions do
		local p = interact_positions[i]
		local p1 = GetPassSlab(RotateRadius(tilex, angle, p))
		local p2 = GetPassSlab(RotateRadius(-tilex, angle, p))
		if p1 and not table.find(interact_positions, p1) and IsPassSlabStep(p, p1, const.TunnelMaskWalk) then
			table.insert(interact_positions, p1)
		end
		if p2 and not table.find(interact_positions, p2) and IsPassSlabStep(p, p2, const.TunnelMaskWalk) then
			table.insert(interact_positions, p2)
		end
	end
	return interact_positions
end

function Door:PlaceTunnels(slab_pass)
	self.interact_positions = false
	if self.impassable then return end
	if not self:HasState("open") or self:GetEntity() == "InvisibleObject" then
		-- this door can never be openned, so presumably it doesn't need tunnels
		return
	end
	local points = GetMovePassThroughObjSpots(self, slab_pass)
	local count = points and #points or 0
	if count == 0 then
		return -- there is no passability
	end

	-- add interaction spots
	local t = lGetInteractionSpotsFromTunnelPoints(self:GetAngle(), points)
	if t and #t > 0 then
		self.interact_positions = t
	end

	-- opened doors do not place tunnels
	local isOpen = self.pass_through_state == "open"
	-- Dont path through locked doors that we know are locked
	local isBlocked = IsBlockingLockpickState(self.pass_through_state)
	local isKnownLocked = isBlocked and self.discovered_lock
	
	if not isOpen and not isKnownLocked then
		local tunnel_class = self.tunnel_class
		if isBlocked then
			tunnel_class = "SlabTunnelDoorBlocked"
		end
		for i = 1, count, 6 do
			local cost, interact_cost, move_cost = self:GetTunnelCost(table.unpack(points, i, i + 5))
			if cost then
				local tunnel = PlaceSlabTunnel(tunnel_class, cost, table.unpack(points, i, i + 5))
				if tunnel then
					assert(IsKindOf(tunnel, "SlabTunnelPassThroughObj"))
					tunnel.pass_through_obj = self
					tunnel.base_interact_cost = interact_cost
					tunnel.base_move_cost = move_cost
				end
			end
		end
	end
end

function Door:GetPassPos()
	return self:GetPos()
end

function Door:InteractDoor(unit, door_state)
	assert(not self.impassable)
	local stance = unit.stance == "Prone" and "Standing" or unit.stance
	local base_anim = unit:GetActionBaseAnim("Open_Door")
	local anim = unit:GetStateText()
	if IsAnimVariant(anim, base_anim) and (unit:GetAnimPhase(1) == 0 or unit:TimeToMoment(1, "hit")) then
		-- already in a open door animation
	else
		anim = unit:GetNearbyUniqueRandomAnim(base_anim)
		if anim and unit:HasState(anim) then
			if unit.stance ~= stance then
				unit:PlayTransitionAnims(unit:GetIdleBaseAnim(stance))
			end
			unit:SetState(anim)
		else
			anim = false
		end
	end
	if anim then
		repeat
			unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
			local time_to_hit = unit:TimeToMoment(1, "hit") or 0
			local t = Min(MulDivRound(200, 1000, Max(1, unit:GetMoveSpeed())), time_to_hit)
		until not WaitWakeup(t)
	else
		StoreErrorSource(unit, "Unit does not have an open door animation ", anim)
		unit:SetState(unit:GetIdleBaseAnim(stance))
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
		unit:SetAnimPhase(1, Max(0, GetAnimDuration(unit:GetEntity(), unit:GetStateText()) - 1000))
		unit:Face(self)
	end

	local self_pos = self:GetVisualPos()
	local fx_target, _, _, fx_target_secondary = GetObjMaterial(self_pos, self)
	local fx_action
	if door_state == "open" then
		fx_action = "OpenDoor"
	elseif door_state == "closed" then
		fx_action = "CloseDoor"
	end
	local cant_open = self:CannotOpen()
	if fx_action and not cant_open then
		PlayFX(fx_action, "start", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	self:TriggerTrap(unit)
	if not IsValid(self) then
		return -- a trap may have destroyed the door
	end
	if cant_open then
		self:PlayCannotOpenFX(unit)
		unit:ClearPath()
		DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
		Sleep(unit:TimeToAnimEnd() + 1)
		return "failed"
	end
	self:SetDoorState(door_state, true)
	if fx_action then
		PlayFX(fx_action, "hit", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	repeat
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
	until not WaitWakeup(unit:TimeToAnimEnd())
	if fx_action then
		PlayFX(fx_action, "end", unit, fx_target, self_pos)
		if fx_target_secondary then
			PlayFX(fx_action, "start", unit, fx_target_secondary, self_pos)
		end
	end
	if IsValid(self) and self.thread then
		WaitMsg(self, self:TimeToAnimEnd() + 1) -- wait the door to set the proper state (passability update, VisibilityUpdate)
	end
end

function Door:SetDoorState(state, animated)
	if self.pass_through_state == state then return end
	if self:CannotOpen() then
		if state == "open" then return end -- Dont allow setting open state.
	else
		self.lockpickState = state
	end

	self.pass_through_state = state
	local isOpening = state == "open"
	DeleteThread(self.thread)
	self.thread = nil
	self:PlayLockpickableFX(isOpening and "open" or "close")

	if animated then
		self:SetState(isOpening and "opening" or "closing")
		self.thread = CreateGameTimeThread(function(self, isOpening)
			if IsValid(self) then
				Sleep(self:TimeToAnimEnd())
			end
			self.thread = nil
			if IsValid(self) then
				self:SetState(isOpening and "open" or "idle")
				Msg("CoversChanged", self:GetObjectBBox())
			end
			Msg(self)
		end, self, isOpening)
	elseif state == "cut" then
		self:SetState("cut")
		Msg("CoversChanged", self:GetObjectBBox())
	else
		local newState = isOpening and "open" or "idle"
		if self:HasState(newState) then
			self:SetState(newState)
		end
		Msg("CoversChanged", self:GetObjectBBox())
	end
end

-- Map lockpickable state to pass_through_state
function Door:LockpickStateChanged(status)
	if self:CannotOpen() then -- Treat all cannot-open states as "locked"
		self:SetDoorState("closed", false)
		self.pass_through_state = "locked"
	elseif status == "cut" then -- Cut means the door is open and cannot be closed
		self:SetDoorState(status, false)
		self.pass_through_state = "open"
	else -- open and close map directly
		self:SetDoorState(status, false)
		self.pass_through_state = status
	end
	if not IsChangingMap() then
		self:InvalidateSurfaces()
	end
end

function Door:SetLockpickState(val)
	local oldState = self.lockpickState
	Lockpickable.SetLockpickState(self, val)
	if IsBlockingLockpickState(oldState) ~= IsBlockingLockpickState(val) then
		DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
	end
end

function Door:GetOpenAPCost()
	if self.pass_through_state == "open" then
		return 0
	end
	local combat_action = self:GetInteractionCombatAction()
	return combat_action and combat_action:GetAPCost() or 0
end

-- tunnel general cost
function Door:GetTunnelCost()
	local interactAP = self:GetOpenAPCost()
	local moveAP = GetSpecialMoveAPCost("Walk")
	return interactAP + moveAP, interactAP, moveAP
end

function Door:InteractionEnabled()
	if self.lockpickState == "cut" or self.impassable then return false end
	return IsValid(self) and (self.HitPoints > 0) and self:IsAnimated()
end

function DoorOnSameLevel(unit, door)
	local unitPos = unit:GetPos()
	local unitPosZ = unitPos:z()
	if not unitPosZ then unitPosZ = SnapToVoxelZ(unitPos:xy()) or terrain.GetHeight(unitPos) end
	
	local doorPos = door:GetPos()
	local doorPosZ = doorPos:z()
	if not doorPosZ then doorPosZ = SnapToVoxelZ(doorPos:xy()) or terrain.GetHeight(doorPos) end

	return abs(unitPosZ - doorPosZ) <= const.SlabSizeZ
end

-- Returns the default interaction for the object.
-- These actions should handle the animations and visuals (banters etc)
-- for when attempting to interact with the object when its locked/blocked etc
function GetOpenAction(obj)
	if IsKindOf(obj, "Door") then
		return "Interact_DoorOpen"
	elseif IsKindOf(obj, "SlabWallWindow") then
		return "Interact_WindowBreak"
	end
end

function Door:IsDead()
	return CombatObject.IsDead(self)
end

function Door:GetInteractionCombatAction(unit)
	if not self:InteractionEnabled() then
		return
	end
	
	local trapAction = BoobyTrappable.GetInteractionCombatAction(self, unit)
	if trapAction then
		return trapAction
	end
	
	if self:CannotOpen() then
		local baseAction = Lockpickable.GetInteractionCombatAction(self, unit)
		if baseAction then return baseAction end 
	end
	
	if self.pass_through_state ~= "open" then
		return Presets.CombatAction.Interactions.Interact_DoorOpen
	else
		return Presets.CombatAction.Interactions.Interact_DoorClose
	end
end

function Door:GetInteractionPos()
	return self.interact_positions
end

function Door:RegisterInteractingUnit(unit)
	self.interacting_unit = unit
end

function Door:UnregisterInteractingUnit(unit)
	self.interacting_unit = false
end

function Door:IsInteracting()
	return not not self.interacting_unit
end

function Door:IsBlocked()
	return self:CannotOpen()
end

Door.GetSide = WallSlab.GetSide

function SlabWallObject:IsBlockedDueToRoom()
	return self.room and self.room.doors_windows_blocked
end

UndefineClass("SlabWallDoor")
DefineClass.SlabWallDoor = {
	__parents = { "SlabWallDoorDecor", "Door" },
	properties = {
		{ id = "HitPoints", name = "Hit Points", editor = "number", default = 30, no_edit = true, min = -1, max = 100 },
	},
	entity = "Door_Planks_Single_01", 
	IsBlockedDueToRoom = SlabWallObject.IsBlockedDueToRoom,
}

function SlabWallDoor:GetlockpickDifficulty()
	return self:IsBlockedDueToRoom() and -1 or Lockpickable.GetlockpickDifficulty(self)
end

function SlabWallDoor:IsBlocked()
	return Door.IsBlocked(self) or self:IsBlockedDueToRoom()
end

function SlabWallDoor:RefreshEntityState()
	self.pass_through_state = nil
	self:SetLockpickState(self.lockpickState)
end

SlabWallDoor.GetSide = WallSlab.GetSide

function SlabWallDoor:OnDie(...)
	CombatObject.OnDie(self, ...)
	self:TriggerTrap(false)
end

DefineClass.SlabWallUnopenableDoor = {
	__parents = { "SlabWallObject" },
}

function SlabWallUnopenableDoor:IsDoor()
	return true
end

DefineClass.SlabTunnelPassThroughObj = {
	__parents = { "SlabTunnel" },
	pass_through_obj = false,
}

DefineClass.SlabTunnelDoorBlocked = {
	__parents = { "SlabTunnelDoor" },
	tunnel_type = const.TunnelTypeDoorBlocked,
}

function SlabTunnelDoorBlocked:IsBlocked(u)
	return true
end

DefineClass.SlabTunnelDoor = {
	__parents = { "SlabTunnelPassThroughObj" },
	tunnel_type = const.TunnelTypeDoor,
}

function SlabTunnelDoor:CanSprintThrough(unit, pos1, pos2)
	return self.pass_through_obj.pass_through_state == "open"
end

function SlabTunnelDoor:IsBlocked(u)
	local passThroughObj = self.pass_through_obj
	local passThroughObjBlocked = passThroughObj and passThroughObj:IsBlocked()
	local passThroughState = passThroughObj and passThroughObj.pass_through_state
	return passThroughObjBlocked or SlabTunnelPassThroughObj.IsBlocked(self, u) or (passThroughState and passThroughState ~= "closed" and passThroughState ~= "open")
end

function SlabTunnelDoor:InteractTunnel(unit, quick_play)
	local obj = self.pass_through_obj
	if obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken" then
		if obj:InteractionEnabled() then
			obj:InteractDoor(unit, "open")
		end
		if (obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken") or unit:IsDead() then
			return false, quick_play
		end
		if quick_play then
			Sleep(0) -- wait visibility update
			quick_play = unit:CanQuickPlayInCombat() -- the unit may have been detected when opened the door
		end
	end
	return true, quick_play
end

function SlabTunnelDoor:TraverseTunnel(unit, pos1, pos2, quick_play, use_stop_anim)
	TunnelGoto(unit, pos1, pos2, quick_play, use_stop_anim)
end

function SlabTunnelDoor:GetCost(context)
	if not (context and context.player_controlled) and self.pass_through_obj:CannotOpen() then
		return -1 -- AI players can't use locked doors
	end
	
	local interact_cost = self.base_interact_cost
	local move_cost = self.base_move_cost * (100 + (context and context.walk_modifier or 0)) / 100
	
	return self.base_cost + interact_cost + move_cost
end

local function lWindowSpecialImpassable(window)
	return window.invulnerable and window.room and window.room.ignore_zulu_invisible_wall_logic
end

DefineClass.WindowTunnelObject = {
	__parents = {"AutoAttachObject", "TunnelObject", "AttachLightPropertyObject"},
	properties = {
		{ id = "impassable",
			name = "Impassable",
			editor = "bool",
			default = false,
			help = "If true, will not place passability tunnels.",
			no_edit = lWindowSpecialImpassable
		},
		{ id = "impassable_room", -- This property is to visualize lWindowSpecialImpassable state for level designers
			name = "Impassable",
			editor = "bool",
			default = true,
			help = "This window is impassable due to being invulnerable and in an 'Ignore Zulu Visibility Logic' room.",
			read_only = true,
			dont_save = true,
			no_edit = function(self) return not lWindowSpecialImpassable(self) end
		},
	},
	tunnel_class = "SlabTunnelWindow",
	base_interact_cost = 0,
	base_move_cost = 0,
	base_drop_cost = 0,
	decorations = false,
}

WindowTunnelObject.ShouldAttach = return_true

function WindowTunnelObject:IsBlocked()
	return self:IsBlockedDueToRoom()
end

function WindowTunnelObject:PlaceTunnels(slab_pass)
	if self.impassable or self.height < 2 or self:GetEntity() == "InvisibleObject" then
		return
	end
	if IsKindOf(self, "SlabWallWindow") and not self:HasBrokenOrOpenState() then
		--windows with no such states are presumed always open and use generic jump over/pass tunnels and don't need to place any
		return
	end
	if self:IsBlockedDueToRoom() then
		--rooms can specify that their windows are not breakable
		return
	end
	if lWindowSpecialImpassable(self) then
		-- another dirty hack for rooms with "Ignore Zulu.." check for which "Make Slabs Invulnerable" button was pressed 
		return	
	end
	local grounded = self:IsKindOf("SlabWallWindowGrounded")
	if grounded and self.pass_through_state ~= "intact" then
		return
	end
	local points = GetMovePassThroughObjSpots(self, slab_pass, MaxSlabMoveTilesZ)
	local count = points and #points or 0
	for i = 1, count, 6 do
		local x1, y1, z1, x2, y2, z2 = table.unpack(points, i, i + 5)
		local centerX = (x1 + x2) / 2
		local centerY = (y1 + y2) / 2
		local centerZ = Max(z1 or terrain.GetHeight(x1, y1), z2 or terrain.GetHeight(x2, y2)) + tilez + tilez / 2
		local halfExtentX = (x2 - x1) / 2
		local halfExtentY = (y2 - y1) / 2
		local halfExtentZ = 0
		local radius = tilez / 4
		if CheckPassCapsule(centerX, centerY, centerZ, halfExtentX, halfExtentY, halfExtentZ, radius, self) then
			local cost, interact_cost, move_cost, drop_cost = self:GetTunnelCost(table.unpack(points, i, i + 5))
			if cost then
				local tunnel = PlaceSlabTunnel(self.tunnel_class, cost, table.unpack(points, i, i + 5))
				if tunnel then
					assert(IsKindOf(tunnel, "SlabTunnelPassThroughObj"))
					tunnel.pass_through_obj = self
					tunnel.base_interact_cost = interact_cost
					tunnel.base_move_cost = move_cost
					tunnel.base_drop_cost = drop_cost
				end
			end
		end
	end
	return points
end

function WindowTunnelObject:GetTunnelCost(x1, y1, z1, x2, y2, z2)
	local interactAP = 0
	local moveAP = GetSpecialMoveAPCost("Walk")
	local dropAP = 0
	if z1 ~= z2 then
		local stepz1 = z1 or terrain.GetHeight(x1, y1)
		local stepz2 = z2 or terrain.GetHeight(x2, y2)
		local ztiles = (abs(stepz1 - stepz2) + tilez/2) / tilez
		if ztiles > 0 then
			if stepz1 < stepz2 then
				return
			end
			local drop_mod = drop_ids[Clamp(ztiles, 1, #drop_ids)]
			dropAP = GetSpecialMoveAPCost(drop_mod) or 0
		end
	end
	return interactAP + moveAP + dropAP, interactAP, moveAP, dropAP
end

UndefineClass("SlabWallWindowBroken")
DefineClass.SlabWallWindowBroken = {
	__parents = {"SlabWallObject", "WindowTunnelObject"},
	entity = "WindowBig_Colonial_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "broken"
}

function SlabWallWindowBroken:IsBreakable()
	return false
end

UndefineClass("SlabWallWindowGrounded")
DefineClass.SlabWallWindowGrounded = {
	__parents = {"SlabWallWindow"},
	entity = "TallWindow_City_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "intact",
}

UndefineClass("ImpassableWindowTunnelObject")
DefineClass.ImpassableWindowTunnelObject = {
	__parents = {"SlabWallWindow"},
	properties = {
		{ id = "impassable", name = "Impassable", editor = "bool", default = true, help = "If true, will not place passability tunnels." },
	},
	entity = "TallWindow_City_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
}

UndefineClass("SlabWallWindowOpen")
DefineClass.SlabWallWindowOpen = {
	__parents = {"SlabWallWindow"},
	pass_through_state = "open",
}

UndefineClass("SlabWallWindow")
DefineClass.SlabWallWindow = {
	__parents = {"SlabWallObject", "WindowTunnelObject"},
	entity = "WindowBig_Colonial_Single_01",
	flags = { efCollision = true, efApplyToGrids = true, },
	pass_through_state = "intact",		-- intact, broken
	IsBlockedDueToRoom = SlabWallObject.IsBlockedDueToRoom
}

local slab_z_offset = point(0, 0, tilez)

function SlabWallWindow:SetDynamicData(data)
	self:SetWindowState(data.pass_through_state or "intact", "no_fx")
end

function SlabWallWindow:GetDynamicData(data)
	if self:IsBroken() then
		data.pass_through_state = self.pass_through_state
	end
end

function SlabWallWindow:HasBrokenOrOpenState()
	return self:HasState("broken") or self:HasState("open")
end


function SlabWallWindow:GetPassPos()
	return self:GetPos() - slab_z_offset
end

function SlabWallWindow:IsBreakable()
	return self:HasState("broken")
end

function SlabWallWindow:IsBroken()
	return self.pass_through_state == "broken"
end

function SlabWallWindow:IsDead()
	return CombatObject.IsDead(self)
end

function SlabWallWindow:GetOpenAPCost()
	local combat_action = Presets.CombatAction.Interactions.Interact_WindowBreak
	return combat_action and combat_action:GetAPCost() or 0
end

function SlabWallWindow:GetTunnelCost(...)
	local openAP = self:GetOpenAPCost() or 0
	local moveAP = WindowTunnelObject.GetTunnelCost(self, ...) or 0
	return openAP + moveAP
end

function SlabWallWindow:SetWindowState(window_state, no_fx)
	if self.pass_through_state == "intact" and window_state == "broken" then
		if not (self.is_destroyed and self:GetEntity() == "InvisibleObject") then
			if self:HasState("broken") then
				self:SetState("broken")
			else
				StoreErrorSource(self, string.format("Window with entity '%s' does not have 'broken' state on map '%s'", self:GetEntity(), GetMapName()))
			end
		end
		if not no_fx then
			PlayFX("WindowBreak", "start", self)
		end
		if IsKindOf(self, "SlabWallWindowGrounded") then
			DelayedCall(0, RebuildSlabTunnels, self:GetObjectBBox())
			if rawget(_G, "debug_pass_vectors") then
				DelayedCall(0, DbgDrawTunnels, "show")
			end
		end
	end
	self.pass_through_state = window_state
end

function SlabWallWindow:InteractWindow(unit)
	if not self:HasBrokenOrOpenState() then
		return
	end
	if self.pass_through_state ~= "intact" then
		return
	end
	if unit:GetPfClass() == CalcPFClass("neutral") then
		StoreErrorSource(unit, "Non-military unit tries to break a window")
		StoreErrorSource(self, "Windows tried to be broken by non-military unit")
	end
	local anim = unit:GetActionRandomAnim("BreakWindow")
	local stance = unit.stance == "Prone" and "Standing" or unit.stance
	if anim and unit:HasState(anim) then
		if unit.stance ~= stance then
			unit:PlayTransitionAnims(unit:GetIdleBaseAnim(stance))
		end
		unit:SetState(anim)
		repeat
			unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
			local time_to_hit = unit:TimeToMoment(1, "hit") or 0
			local t = Min(MulDivRound(200, 1000, Max(1, unit:GetMoveSpeed())), time_to_hit)
		until not WaitWakeup(t)
	else
		StoreErrorSource(unit, "Unit does not have break window animation ", anim)
		unit:SetState(unit:GetIdleBaseAnim(stance))
		unit:SetAnimPhase(1, Max(0, GetAnimDuration(unit:GetEntity(), unit:GetStateText()) - 1000))
		unit:Face(self)
	end
	if not IsValid(self) then
		return -- a trap may have destroyed the window
	end
	self:SetWindowState("broken")
	repeat
		unit:SetAnimSpeed(1, unit:CalcMoveSpeedModifier())
	until not WaitWakeup(unit:TimeToAnimEnd())
	Msg("WindowInteraction")
end

DefineClass.SlabTunnelWindow = {
	__parents = { "SlabTunnelPassThroughObj" },
	tunnel_type = const.TunnelTypeWindow,
	dbg_tunnel_color = const.clrMagenta,
	dbg_tunnel_zoffset = 30 * guic,
	action = "JumpOverShort",
	base_interact_cost = 0,
	base_move_cost = 0,
	base_drop_cost = 0,
}

function SlabTunnelWindow:CanSprintThrough(unit, pos1, pos2)
	return self.pass_through_obj.pass_through_state == "open"
end

function SlabTunnelWindow:InteractTunnel(unit, quick_play)
	local obj = self.pass_through_obj
	local pass_through_state = IsKindOf(obj, "SlabWallWindowOpen") and "open" or obj.pass_through_state
	if not (pass_through_state == "open" or pass_through_state == "broken") then
		obj:InteractWindow(unit)
		-- check for blocked window or a trap may have killed the unit
		if (obj.pass_through_state ~= "open" and obj.pass_through_state ~= "broken") or unit:IsDead() then
			unit:Interrupt()
			return false, quick_play
		end
		if quick_play then
			Sleep(0) -- wait possible visibility update
			quick_play = unit:CanQuickPlayInCombat() -- the unit may have been detected while interacting the window
		end
	end
	return true, quick_play
end

function SlabTunnelWindow:TraverseTunnel(unit, pos1, pos2, quick_play)
	assert(not self.invulnerable, "Why invulnerable windows are traversed?!?")
	if quick_play then
		unit:SetPos(pos2)
		unit:SetAxis(axis_z)
		unit:SetAngle(pos1:Equal2D(pos2) and self:GetVisualAngle() or CalcOrientation(pos1, pos2))
		return
	end
	local anim = unit:GetActionRandomAnim(self.action, false)

	local surface_fx_type, surface_pos = GetObjMaterial(pos1)
	PlayFX("MoveJumpWindow", "start", unit, surface_fx_type, surface_pos)

	local hit_thread = CreateGameTimeThread(function(unit, anim, pos)
		local delay = unit:GetAnimMoment(anim, "hit") or unit:GetAnimMoment(anim, "end") or unit:TimeToAnimEnd()
		WaitWakeup(delay)
		local surface_fx_type, surface_pos = GetObjMaterial(pos)
		PlayFX("MoveJumpWindow", "end", unit, surface_fx_type, surface_pos)
	end, unit, anim, pos2)
	unit:PushDestructor(function()
		DeleteThread(hit_thread)
	end)

	-- Todo: window jump through break cinematic moment
	local duration = GetAnimDuration(unit:GetEntity(), anim)
	if g_Combat and unit:IsLocalPlayerTeam() then
		SetAutoRemoveActionCamera(unit, unit, duration, nil, nil, nil, "no_wait")
	end

	unit:MovePlayAnim(anim, pos1, pos2)

	if IsValidThread(hit_thread) then
		Wakeup(hit_thread)
		Sleep(0)
	end
	unit:PopAndCallDestructor()
end

function SlabTunnelWindow:IsBlocked(u)
	return self.pass_through_obj:IsBlocked()
end

function SlabTunnelWindow:GetCost(context)
	if context and not context.player_controlled and self.pass_through_obj:IsBlocked(context.unit) then
		return -1 -- AI players can not use blocked windows
	end
	
	local interact_cost = self.base_interact_cost
	local move_cost = self.base_move_cost * (100 + (context and context.walk_modifier or 0)) / 100
	local drop_cost = self.base_drop_cost * (100 + (context and context.drop_down_modifier or 0)) / 100
	
	return self.base_cost + interact_cost + move_cost + drop_cost
end

function OnMsg.GatherFXActions(list)
	table.insert(list, "OpenDoor")
	table.insert(list, "CloseDoor")
end

function OnMsg.GatherFXTargets(list)
	table.insert(list, "SlabWallDoor")
	table.insert(list, "Door")
end

-- C Interop

function GetTunnelBuildQueueLength()
	return 16000
end

function PlaceSlabTunnelFromC(classname, pt1, pt2, base_cost, modifier)
	local obj = PlaceObject(classname, {
		end_point = pt2,
		base_cost = base_cost,
		modifier = modifier,
	})
	obj:SetPos(pt1)
	obj:AddPFTunnel()
end

function AddTunnelObjectPassability(extendedClip)
	MapForEach(extendedClip, "TunnelObject", function(obj)
		if IsObjectDestroyed(obj) then
			return
		end
		obj:PlaceTunnels("FromC")
	end)
end

function GetSlabPassDataFromC(point)
	local z, obj = GetSlabPassC(point)
	if not z then return false end
	return { z = z, floor_obj = obj, floor_type = "stairs" }
end

function DBG_CheckTunnelsOnAllMaps()
	CreateRealTimeThread(function()
		ForEachMap(ListMaps(), function()
			print(CurrentMap)
		end)
	end)
end
