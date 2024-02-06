const.PassModifierStairs = 0

StancesList = { [0] = "", "Standing", "Crouch", "Prone" }
for idx, stance in ipairs(StancesList) do StancesList[stance] = idx end

local mask_all = 0
local mask_any = 2^32 - 1
local flags_enum = const.efVisible + const.efCollision
local flags_game_ignore = const.gofSolidShadow
local flags_collision_mask = const.cmDefaultObject
local flags_walkable = const.efPathSlab + const.efApplyToGrids

DefineClass.CursorPosIgnoreObject = {
	__parents = { "PropertyObject" }
}

CursorPosFilter = function(o)
	return not IsKindOf(o, "CursorPosIgnoreObject")
end

MapVar("LastCursorPos", false)
MapVar("LastCursorObj", false)
MapVar("CursorPosFrameNo", false)
MapVar("LastWalkableCursorPos", false)
MapVar("LastWalkableCursorObj", false)
MapVar("WalkableCursorPosFrameNo", false)

function GetCursorPos(walkable)
	UpdateLastCursor(walkable)
	if walkable then
		return LastWalkableCursorPos
	end
	return LastCursorPos
end

function GetCursorObj()
	UpdateLastCursor()
	return LastCursorObj
end

function UpdateLastCursor(walkable)
	local n = GetRenderFrame()
	if walkable then
		if n == WalkableCursorPosFrameNo then
			return
		end
	else
		if n == CursorPosFrameNo then
			return
		end
	end
	local src = camera.GetEye()
	local dest = (GetUIStyleGamepad() or not g_MouseConnected) and GetTerrainGamepadCursor() or GetTerrainCursor()
	local closest_obj, closest_pos
	if src and dest then
		closest_obj, closest_pos = GetClosestRayObj(src, dest, walkable and flags_walkable or flags_enum, flags_game_ignore, CursorPosFilter, mask_all, flags_collision_mask)
	end
	local pos = (closest_pos and not IsKindOf(closest_obj, "TerrainCollision")) and closest_pos or dest
	if walkable then
		LastWalkableCursorPos = pos or false
		LastWalkableCursorObj = closest_obj or false
		WalkableCursorPosFrameNo = n
	else
		LastCursorPos = pos or false
		LastCursorObj = closest_obj or false
		CursorPosFrameNo = n
	end
end

function GetCursorPassSlab()
	return GetPassSlab(GetCursorPos())
end

function GetPackedPosAndStance(unit, stance)
	if IsValid(unit) then
		stance = stance or unit.stance
		local stance_idx = StancesList[stance]
		if IsSittingUnit(unit) then
			local x, y, z = GetPassSlabXYZ(unit.last_visit)
			if x then
				return stance_pos_pack(x, y, z, stance_idx)
			end
		end
		local x, y, z = GetPassSlabXYZ(unit.target_dummy or unit)
		if x then
			return stance_pos_pack(x, y, z, stance_idx)
		end
		return stance_pos_pack(unit, stance_idx)
	end
end

-- Slab spots can be 3 tiles aside from the object Origin
const.FloorSlabMaxRadius = 1 + sqrt(
	(3 * const.SlabSizeX + const.SlabSizeX / 2 + const.PassTileSize / 2) ^ 2 +
	(0 * const.SlabSizeX + const.SlabSizeX / 2 + const.PassTileSize / 2) ^ 2)

function SnapToVoxelZ(x, y, z)
	return select(3, SnapToVoxel(x, y, (z or terrain.GetHeight(x, y)) + const.SlabSizeZ / 2))
end

function FindFallDownPos(obj_or_pos)
	local x, y, z
	if IsValid(obj_or_pos) then
		if obj_or_pos:GetEnumFlags(const.efApplyToGrids) ~= 0 then
			return -- these object will change the passability grid and would hang
		end
		x, y, z = obj_or_pos:GetPosXYZ()
	else
		x, y, z = obj_or_pos:xyz()
	end
	local pass_x, pass_y, pass_z = GetPassSlabXYZ(x, y, z)
	if x == pass_x and y == pass_y and z == pass_z then
		return
	end
	if pass_x then
		if z == pass_z then
			return pass_x, pass_y, pass_z
		end
		local stepz
		if x == pass_x and y == pass_y then
			stepz = pass_z or terrain.GetHeight(pass_x, pass_y)
		else
			stepz = GetVoxelStepZ(x, y)
		end
		local posz = z or terrain.GetHeight(x, y)
		if abs(posz - stepz) < 50*guic then
			return pass_x, pass_y, pass_z
		end
	end
	local slab, step_z = WalkableSlabByPoint(x, y, z, "downward only")
	pass_x, pass_y, pass_z = GetPassSlabXYZ(x, y, step_z)
	if not pass_x then
		pass_x, pass_y, pass_z = GetPassSlabXYZ(terrain.FindPassable(x, y, step_z, 0,  -1, -1, const.pfmVoxelAligned, true)) -- adjust Z
	end
	return pass_x, pass_y, pass_z
end

function FallDownCheck(unit)
	if unit.command == "FallDown" then return end
	local x, y, z = FindFallDownPos(unit)
	if not x or unit:IsEqualPos(x, y, z) then
		return
	end
	local ux, uy, uz = unit:GetPosXYZ()
	local _, fall_z = WalkableSlabByPoint(x, y, z, "downward only")
	local _, unit_z = WalkableSlabByPoint(ux, uy, uz, "downward only")
	local current_z = uz or unit_z
	if fall_z ~= current_z then
		if current_z and (not fall_z or current_z - fall_z >= 35 * guic) then
			unit:SetCommand("FallDown", point(x, y, z), unit.command == "Cower")
		end
	end
end

function UnitsFallDown(clip)
	WaitAllOtherThreads()
	for _, unit in ipairs(g_Units) do
		if IsValid(unit)
			and (not clip or clip:Point2DInside(unit))
			and unit.command ~= "FallDown"
			and not unit.perpetual_marker
			and not unit:GetParent()		-- e.g. Hanging Luc
		then
			unit:Interrupt(FallDownCheck)
		end
	end
	MapGet(clip or "map", "ItemDropContainer", function(obj)
		local x, y, z = FindFallDownPos(obj)
		if not x then return end
		CreateGameTimeThread(GravityFall, obj, point(x, y, z))
	end)
end

function RebuildArea(clip)
	if not mapdata.GameLogic then return end
	clip = IsBox(clip) and clip or nil
	--local t0 = GetPreciseTicks(1000)
	RebuildSlabTunnels(clip)
	RebuildCovers(clip)

	if IsEditorActive() then
		return
	end

	RebuildAreaInteractables(clip)
	CreateGameTimeThread(UnitsFallDown, clip)

	MapGet(clip or "map", "Unit", function(obj)
		if obj:GetStatusEffect("Protected") then
			if not obj:CanTakeCover() then
				obj:RemoveStatusEffect("Protected")
			end
		end
	end)
	UpdateTakeCoverAction()

	local pass_grid_hash = terrain.HashPassability()
	local tunnel_hash = terrain.HashPassabilityTunnels()
	NetUpdateHash("PassabilityChanged", pass_grid_hash, tunnel_hash)

	--local t = GetPreciseTicks() - t0
	--printf("Rebuild voxel pass: %dms", t)
end

OnMsg.OnPassabilityChanged = RebuildArea
function OnMsg.GameExitEditor()
	RebuildArea()
end

local formations =
{	-- looking up
	[1] = {
		{0, 0, 0},
		{0, 1, 0},
		{0, 0, 0}},
	[2] = {
		{0, 0, 0},
		{1, 0, 1},
		{0, 0, 0}},
	[3] = {
		{0, 0, 0},
		{1, 0, 1},
		{0, 1, 0}},
	[4] = {
		{0, 0, 0},
		{1, 0, 1},
		{1, 0, 1}},
	[5] = {
		{1, 0, 1},
		{0, 1, 0},
		{1, 0, 1}},
	[6] = {
		{1, 0, 1},
		{1, 0, 1},
		{1, 0, 1}},
}

local KeepFormOrientaionDist = 2

local function GetFormPositions(count, goto_pos, angle)
	local result = {}
	local form = formations[Clamp(count, 1, #formations)]
	local fcenter_x = 2
	local fcenter_y = 2
	local a = (AngleDiff(angle or 0, -90*60) + 45*60) / (90*60) * (90*60)
	local sina = sin(a) / 4096
	local cosa = cos(a) / 4096
	local x0, y0 = goto_pos:xyz()
	local tilesize = const.SlabSizeX
	for fy, row in ipairs(form) do
		for fx, value in ipairs(row) do
			if value ~= 0 then
				local x = x0 + ((fx - fcenter_x) * cosa - (fy - fcenter_y) * sina) * tilesize
				local y = y0 + ((fx - fcenter_x) * sina + (fy - fcenter_y) * cosa) * tilesize
				table.insert(result, point_pack(x, y))
			end
		end
	end
	return result
end

local function GetValidGotoDest(units, goto_pos)
	-- find reachable positions from goto_pos
	local pts = {}
	local function add(x, y, z, tunnel, pts, prev_idx)
		local pt = point_pack(SnapToVoxel(x, y, z))
		if pts[pt] then
			return
		end
		if (prev_idx or 0) > 1 then
			local x0, y0 = point_unpack(pts[1])
			if Max(abs(x - x0), abs(y - y0)) > 2 * const.SlabSizeX then
				return
			end
			local prev_x, prev_y = point_unpack(pts[prev_idx])
			if (x - prev_x) * (prev_x - x0) < 0 or (y - prev_y) * (prev_y - y0) < 0 then
				return
			end
		end
		pts[#pts + 1] = pt
		pts[pt] = pt
		if z then
			pts[point_pack(SnapToVoxel(x, y))] = pt
		end
	end
	local x, y, z = GetPassSlabXYZ(goto_pos)
	if x then
		add(x, y, z, nil, pts)
	end
	local i = 0
	while i < #pts do
		i = i + 1
		x, y, z = GetPassSlabXYZ(point_unpack(pts[i]))
		ForEachPassSlabStep(x, y, z, const.TunnelMaskWalk, add, pts, i)
	end

	-- remove other units destlocked positions
	local own_destlocks = {}
	for i, unit in ipairs(units) do
		if unit:GetEnumFlags(const.efResting) ~= 0 and unit:IsValidPos() then
			own_destlocks[point_pack(SnapToVoxel(unit:GetPosXYZ()))] = true
		end
		local o = unit:GetDestlock()
		if o and o:IsValidPos() then
			own_destlocks[point_pack(SnapToVoxel(o:GetPosXYZ()))] = true
		end
	end
	local r = const.SlabSizeX / 2
	local fCheckDestlock = function(obj, z)
		local oz = select(3, obj:GetPosXYZ()) or terrain.GetHeight(obj)
		if abs(oz - z) < guim then
			return true
		end
	end
	for i = #pts, 1, -1 do
		local id = pts[i]
		if not own_destlocks[id] then
			local pt = GetPassSlab(point_unpack(id))
			local z = pt:z() or terrain.GetHeight(pt)
			local o =
				MapGetFirst(pt, pt, r, nil, const.efResting, fCheckDestlock, z) or
				MapGetFirst(pt, pt, r, "Destlock", fCheckDestlock, z)
			if o then
				table.remove(pts, i)
				pts[id] = nil
			end
		end
	end
	return pts
end

local function AssignUnitsToFormPos(units, pts)
	local t = table.icopy(units)
	while #pts > 0 do
		local farthest_pt, farthest_dist, closest_unit
		for k, p in ipairs(pts) do
			local bestu, besti, bestx, besty
			local px, py = point_unpack(p)
			for i, u in ipairs(t) do
				local ux, uy = u:GetPosXYZ()
				if not besti or IsCloser2D(px, py, ux, uy, bestx, besty) then
					bestu, besti, bestx, besty = u, i, ux, uy
				end
			end
			local closest_dist = point(bestx, besty):Dist2D(px, py)
			if not farthest_dist or farthest_dist < closest_dist then
				farthest_pt = k
				farthest_dist = closest_dist
				closest_unit = besti
			end
		end
		local unit = t[closest_unit]
		local p = pts[farthest_pt]
		t[unit] = p
		table.remove(t, closest_unit)
		table.remove(pts, farthest_pt)
	end
	for i, u in ipairs(units) do
		pts[i] = t[u] or false
	end
	return pts
end

function GetUnitsDestinations(units, goto_pos)
	goto_pos = SnapToVoxel(goto_pos)
	local angle = 0
	if #units > 1 then
		local count, x, y = 0, 0, 0
		for i, u in ipairs(units) do
			if u:IsValidPos() then
				local posx, posy = u:GetPosXYZ()
				local vx, vy = WorldToVoxel(posx, posy, 0)
				x = x + vx
				y = y + vy
				count = count + 1
			end
		end
		local center = count > 0 and point(VoxelToWorld((x + count/2) / count, (y + count/2) / count)) or goto_pos
		if not IsCloser2D(center, goto_pos, KeepFormOrientaionDist * const.SlabSizeX + 1) then
			angle = CalcOrientation(center, goto_pos)
		else
			-- guess angle
			local best_dist, best_angle
			for i = 1, 4 do
				local a = (i-1)*90*60
				local form_pts = GetFormPositions(#units, center, a)
				local assigned_pts = AssignUnitsToFormPos(units, form_pts)
				local d = 0
				for i, unit in ipairs(units) do
					if unit:IsValidPos() and assigned_pts[i] then
						d = d + unit:GetDist2D(point_unpack(assigned_pts[i]))
					end
				end
				if not best_dist or d < best_dist then
					best_dist = d
					best_angle = a
				end
			end
			angle = AngleNormalize(best_angle)
		end
	end

	local form_pts = GetFormPositions(#units, goto_pos, angle)
	local valid_pos = GetValidGotoDest(units, goto_pos)
	local destinations = {}

	for i = #form_pts, 1, -1 do
		local p = form_pts[i]
		local pos = valid_pos[p]
		if pos then
			table.insert(destinations, pos)
			valid_pos[p] = nil
			table.remove_value(valid_pos, pos)
			table.remove(form_pts, i)
		end
	end
	-- find alternative positions 
	while #valid_pos > 0 and #destinations < #units do
		local form_x, form_y
		if #form_pts > 0 then
			form_x, form_y = point_unpack(form_pts[#form_pts])
		else
			form_x, form_y = goto_pos:xy()
		end
		local d = const.SlabSizeX / 2
		local spotx = form_x + Clamp(goto_pos:x() - form_x, -d, d)
		local spoty = form_y + Clamp(goto_pos:y() - form_y, -d, d)
		local besti = 1
		local bestx, besty = point_unpack(valid_pos[besti])
		for i = 2, #valid_pos do
			local ix, iy = point_unpack(valid_pos[i])
			if IsCloser2D(spotx, spoty, ix, iy, bestx, besty) then
				besti, bestx, besty = i, ix, iy
			end
		end
		local p = valid_pos[besti]
		table.insert(destinations, p)
		valid_pos[p] = nil
		table.remove(valid_pos, besti)
		table.remove(form_pts, #form_pts)
	end
	local assigned_dest = AssignUnitsToFormPos(units, destinations)
	return assigned_dest, angle
end

-- IsOccupied depends on target dummies, which are not present outside combat.
function IsOccupiedExploration(unit, x, y, z)
	if g_Combat then
		return IsOccupied(x, y, z)
	elseif unit then
		return not CanDestlock(unit, x, y, z)
	end
	return not CanDestlock(x, y, z or const.InvalidZ, Unit.radius)
end

function CheckForDetailObjsAffectingPassability()
	local dummy_collections = {}
	local offending_objs = {}
	
	local function process(o)
		--acknowledge dummies
		if IsKindOf(o, "FloatingDummy") then
			dummy_collections[o:GetCollectionIndex()] = o
		end
		
		--any parent that is non essential can hide/show this obj
		local parent = o:GetParent()
		local dc = o:GetDetailClass()
		while dc == "Essential" and parent do
			dc = parent:GetDetailClass()
			parent = parent:GetParent()
		end
		
		if dc ~= "Essential" then
			if not o:ObjEssentialCheck() then
				table.insert(offending_objs, o)
			end
		end
	end
	MapForEach("map", "CObject", process)
	
	for i = #offending_objs, 1, -1 do
		local o = offending_objs[i]
		local topParent = GetTopmostParent(o)
		if dummy_collections[topParent:GetCollectionIndex() or 0] then
			table.remove(offending_objs, i) --managed by floating dummy presumably
		end
	end
	
	for i, o in ipairs(offending_objs) do
		StoreErrorSource(o, "Object will provoke pass grid rebuild on object details change!")
	end
end

function OnMsg.PreSaveMap()
	CheckForDetailObjsAffectingPassability()
end

