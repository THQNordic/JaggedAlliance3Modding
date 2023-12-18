local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2

AppendClass.Room = {
	__parents = { "Object" },
	properties = {
		{ category = "General", id = "ignore_zulu_invisible_wall_logic", name = "Ignore Zulu Invisible Wall Logic", editor = "bool", default = false, },
	},
	
	visible_walls = false,
	adjacent_rooms_per_side = false,
}

local p = RoomRoof.properties
for i = 1, #p do
	local pp = p[i]
	if pp.id == "build_ceiling" then --default val for has ceilings in zulu is false
		pp.default = false
		break
	end
end

local function roomsPPHelper()
	if not IsChangingMap() then
		DelayedCall(0, RoomsPostProcess)
	end
end

local noneWallMat = const.SlabNoMaterial
function Room:HasWallOnSide(side)
	return self:GetWallMatHelperSide(side) ~= noneWallMat and (not self.visible_walls or self.visible_walls[side])
end

function WallSlab:OnVisibilityChanged(isVisible)
	--callback
	self:ForEachAttach("CoverWall", DoneObject)
	if isVisible then
		if not IsValid(self.wall_obj) and self.isVisible then
			local cw = PlaceObject("CoverWall")
			if cw then
				self:Attach(cw)
			end
		end	
	end
end

function SetDontHideToRoomsOutsideBorderArea()
	local border = GetBorderAreaLimits()
	if not border then return end
	MapForEach("map", "Room", function(r)
		if border:Intersect2D(r.box) == const.irOutside then
			r.outside_border = true
		else
			r.outside_border = false
		end
	end)
end

OnMsg.NewMapLoaded = SetDontHideToRoomsOutsideBorderArea
OnMsg.GameExitEditor = SetDontHideToRoomsOutsideBorderArea

function Slab:ColorizationPropsNoEdit(i)
	return true
end

function SlabWallObject:ColorizationPropsNoEdit(i)
	return ColorizableObject.ColorizationPropsNoEdit(self, i)
end

local defaultColors = false
function Slab:Setcolors(val)
	if val == empty_table then
		val = false
	end
	if val and (not self.colors or not rawequal(self.colors, val)) then
		val = val:Clone()
	end
	local isSelected = false
	if Platform.editor then
		isSelected = editor.IsSelected(self)
		defaultColors = defaultColors or ColorizationPropSet:new()
	end
	
	local rm = self:GetColorsRoomMember()
	local rc = self.room and self.room[rm]
	local clear = val == false
	
	if isSelected and (clear or self.colors == false and defaultColors == val) and rc then
		val = rc:Clone() --initialize color to that of the room
	end
	
	if (isSelected and not clear) or not self.room or rc ~= val then
		self.colors = val
	else
		self.colors = false
	end
	self:SetColorization(val)
	self:RefreshColors()
end

function Slab:Setinterior_attach_colors(val)
	if val == empty_table then
		val = false
	end
	if val and (not self.interior_attach_colors or not rawequal(self.interior_attach_colors, val)) then
		val = val:Clone()
	end
	local isSelected = false
	if Platform.editor then
		isSelected = editor.IsSelected(self)
		defaultColors = defaultColors or ColorizationPropSet:new()
	end
	
	if isSelected and self.interior_attach_colors == false and defaultColors == val and self.room and self.room.inner_colors then
		val = self.room.inner_colors:Clone() --initialize color to that of the room
	end
	
	if isSelected or not self.room or self.room.inner_colors ~= val then
		self.interior_attach_colors = val
	else
		self.interior_attach_colors = false
	end
	if self.variant_objects and self.variant_objects[1] then
		SetSlabColorHelper(self.variant_objects[1], val)
	end
	self:RefreshColors()
end

slab_missing_entity_white_list = {
	["WallExt_MetalScaff_CapL_01"] = true,
	["WallExt_MetalScaff_CapT_01"] = true,
	["WallExt_MetalScaff_CapX_01"] = true,
	["WallExt_MetalScaff_Corner_01"] = true,
	["WallExt_ColonialFence1_CapL_01"] = true,
	["WallExt_ColonialFence1_CapT_01"] = true,
	["WallExt_ColonialFence1_CapX_01"] = true,
	["WallExt_ColonialFence1_Corner_01"] = true,
	["WallExt_ColonialFence1_Wall_ExEx_BrokenDec_T_01"] = true,
	["WallExt_ColonialFence2_CapL_01"] = true,
	["WallExt_ColonialFence2_CapT_01"] = true,
	["WallExt_ColonialFence2_CapX_01"] = true,
	["WallExt_ColonialFence2_Corner_01"] = true,
	["WallExt_ColonialFence2_Wall_ExEx_BrokenDec_T_01"] = true,
	["WallExt_Sticks_CapL_01"] = true,
	["WallExt_Sticks_CapT_01"] = true,
	["WallExt_Sticks_CapX_01"] = true,
	["Roof_Sticks_Plane_Broken_B_01"] = true,
	["Roof_Sticks_Plane_Broken_T_01"] = true,
	["WallDec_Colonial_Column_Top_02"] = true,
	["WallDec_Colonial_Column_Top_03"] = true,
	["WallDec_Colonial_Column_Top_04"] = true,
	["WallDec_Colonial_Frieze_Corner_BrokenDec_L_01"] = true,
	["WallDec_Colonial_Frieze_Corner_BrokenDec_R_01"] = true,
}

function OnMsg.PreSaveMap()
	MapForEach("map", "Slab", function(o)
		if not o.bad_entity then
			o:LockRandomSubvariantToCurrentEntSubvariant()
		end
	end)
end

local gofPermanent = const.gofPermanent
local voxelSizeZ = const.SlabSizeZ or 0
function StairSlab:ComputeVisibility(passed)
	if self:GetEnumFlags(const.efVisible) == 0 then
		return
	end
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	local x, y, z = self:GetPosXYZ()
	if z then
		local max = self.hide_floor_slabs_above_in_range
		for i = 0, max do
			MapForEach(x, y, z, 0, "FloorSlab", nil, nil, gameFlags, function(slab, self)
				slab:SetSuppressor(self)
			end, self)
			z = z + voxelSizeZ
		end
	else
		print(string.format("Stairs with handle[%d] have an invalid Z!", stairs_slab.handle))
	end
end

DefineClass.BlackPlaneBase = {
	__parents = {"Object"},
	flags = { gofPermanent = true },
	properties = {
		{ id = "sizex", editor = "number", default = 0 },
		{ id = "sizey", editor = "number", default = 0 },
		{ id = "depth", editor = "number", default = 0 },
		{ id = "floor", editor = "number", default = 1 },
	},
}

function BlackPlaneBase:GetBBox2D()
	return self:GetBBox():SetInvalidZ()
end

function BlackPlaneBase:GetBBox()
	return self:GetObjectBBox()
end

DefineClass.BlackPlane = {
	__parents = { "BlackPlaneBase", "Mesh", "AlignedObj" },
	flags = { gofPermanent = true },
	
	--wallbox = false,
	original_pos = false, -- snap according to this
}

function BlackPlane:GameInit()
	self:Setup()
	self.original_pos = self:GetPos()
end

function BlackPlane:AlignObj(pos, angle)
	if IsChangingMap() then return end --initial allign, we should be already aligned.
	local op = self.original_pos
	local x, y, z
	
	if pos then
		x, y, z = pos:xyz() 
	else
		x, y, z = self:GetPosXYZ()
	end
	
	if op then
		local ox, oy, oz = op:xyz()
		local sox, soy, soz = VoxelToWorld(WorldToVoxel(ox, oy, oz))
		local sx, sy, sz = VoxelToWorld(WorldToVoxel(x, y, z))
		x = sx + (ox - sox)
		y = sy + (oy - soy)
		z = sz + (oz - soz)
	end
	self:SetPosAngle(x, y, z, angle or self:GetAngle())
	
	DbgClear()
	DbgAddBox(self:GetBBox())
end

function BlackPlane:GetBBox2D()
	local sx = self.sizex
	local sy = self.sizey
	local ret = box(0, 0, -1, sx, sy, 0)
	local x, y, z = self:GetPosXYZ()
	return Offset(ret, point(x - sx / 2, y - sy / 2, z))
end

function BlackPlane:GetBBox()
	local sx = self.sizex
	local sy = self.sizey
	local sz = self.depth
	local ret = box(0, 0, 0, sx, sy, sz)
	local x, y, z = self:GetPosXYZ()
	return Offset(ret, point(x - sx / 2, y - sy / 2, z - sz))
end

function BlackPlane:Setup()
	local vpstr = pstr("", 1024)
	local color = RGB(0,0,0)
	local half_size_x = self.sizex / 2
	local half_size_y = self.sizey / 2

	vpstr:AppendVertex(point(-half_size_x, -half_size_y, 0), color)
	vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color)
	vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color)

	vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color)
	vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color)
	vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color)
	
	local depth = self.depth
	if depth > 0 then
		vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color)
		vpstr:AppendVertex(point(-half_size_x, half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color)
		
		vpstr:AppendVertex(point(-half_size_x, half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color)
		
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, 0), color)
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color)
		
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color)
		
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, 0), color)
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color)
		
		vpstr:AppendVertex(point(-half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(-half_size_x, half_size_y, -depth), color)
		vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color)
		
		vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color)
		vpstr:AppendVertex(point(half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color)
		
		vpstr:AppendVertex(point(half_size_x, -half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, -depth), color)
		vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color)
	end

	self:SetMesh(vpstr)
	self:SetShader(ProceduralMeshShaders.default_mesh)
	self:SetDepthTest(true)
end

function testingMesh()
	local mesh = PlaceObject("Mesh")
	mesh:SetPos(GetTerrainCursor())
	
	local vpstr = pstr("", 1024)
	local color = RGB(0,0,0)
	local half_size_x = 1000
	local half_size_y = 1000
--[[	local low_edge = 0
	local high_edge = 0
	local glow_size = 0
	local glow_period = 0
	local glow_color = RGB(255,255,255)]]

	vpstr:AppendVertex(point(-half_size_x, -half_size_y, 0), color, 0, 0)
	vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color, 1, 0)
	vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color, 0, 1)

	vpstr:AppendVertex(point(half_size_x, -half_size_y, 0), color, 1, 0)
	vpstr:AppendVertex(point(half_size_x, half_size_y, 0), color, 1, 1)
	vpstr:AppendVertex(point(-half_size_x, half_size_y, 0), color, 0, 1)

	mesh:SetMesh(vpstr)
	--mesh:SetTexture(0, ProceduralMeshBindResource("texture", "", false, 0))
	mesh:SetShader(ProceduralMeshShaders.default_mesh)
	mesh:SetDepthTest(true)
	--mesh:SetEnumFlags(const.efSelectable)
	--mesh:SetShader(ProceduralMeshShaders.map_border)
	--mesh:SetUniforms(low_edge, high_edge, glow_size, glow_period, 255, 255, 255)
	return mesh
end

DefineClass.BlackPlaneThatCanBePlacedByHand = {
	__parents = { "BlackPlaneBase", "AlignedObj" },
	flags = { gofPermanent = true },
	entity = "CMTPlane"
}

function BlackPlaneThatCanBePlacedByHand:GameInit()
	self:SetColorModifier(RGBRM(0, 0, 0, 127, 127))
end

function BlackPlaneThatCanBePlacedByHand:AlignObj(...)
	return FloorAlignedObj.AlignObj(self, ...)
end

function BlackPlaneThatCanBePlacedByHand:Setup()
end

--table.set_ival(t, "key1", "key2", v) => table.insert(t[key1][key2], v) with checks and new t creation
function table.set_ival(t, ...)
	local c = select('#', ...)
	t = t or {}
	local ret = t
	for i = 1, c - 1 do
		local v = select(i, ...)
		t[v] = t[v] or {}
		t = t[v]
	end
	table.insert(t, select(c, ...))
	return ret
end

function AnalyseRoomsAndPlaceBlackPlanesOnEdges()
	CleanBlackPlanes()
	
	--this works for concrete mat, for other mats it will spill over and needs to be adjusted
	local xAxisMinY = {}
	local xAxisMaxY = {}
	local yAxisMinX = {}
	local yAxisMaxX = {}
	local minf, maxf
	
	local function checkCorners(v, side)
		if v.spawned_corners[side] then
			local t = v.spawned_corners[side]
			local cs = t[Max(#t - 1, 1)]
			if cs and cs.isVisible and cs.material == "Concrete" then
				return true
			end
		end
	end
	
	local function figureOutZ(x, y, f)
		local z = 0
		MapForEach(x, y, 0, halfVoxelSizeX + 1, "WallSlab", "RoomCorner", nil, const.efVisible, function(s, f)
			if s.floor == f and not rawget(s, "isPlug") and
				(not IsKindOf(s, "RoomCorner") or s.material == "Concrete") then --only fat corners bump z
				local sz = s:GetPos():z()
				if sz > z then
					z = sz
				end
			end
		end, f)
		if z ~= 0 then
			return z + voxelSizeZ
		end
	end
	
	local function findZY(x, sy, y, f)
		if x then
			for ssy = sy, y, voxelSizeY do
				local ret = figureOutZ(x, ssy, f)
				if ret then return ret end
			end
		end
		return nil
	end
	
	local function findZX(sx, x, y, f)
		if y then
			for ssx = sx, x, voxelSizeX do
				local ret = figureOutZ(ssx, y, f)
				if ret then return ret end
			end
		end
		return nil
	end
	
	local function figureOutDepth(last, z)
		if last then
			local lz = last:GetPos():z()
			if lz < z then
				return z - lz
			elseif lz > z then
				last.depth = Max(last.depth, lz - z)
			end
		end
		
		return 0
	end
	
	local function getSpecialCornerOffset(qx, qy, qz, offset)
		local c = MapGetFirst(qx, qy, qz, voxelSizeY - 1, "RoomCorner", function(o) return o.isVisible end)
		--print(c and c.material)
		if c then
			--DbgAddVector(point(qx, qy, qz))
			if c.material == "Concrete" then
				return -offset
			else
				return offset
			end
		end
		
		return 0
	end
	
	EnumVolumes(function(v)
		--west minx
		--east maxx
		--north miny
		--south maxy
		local floor = v.floor
		minf = Min(minf, floor)
		maxf = Max(maxf, floor)
		local pos = v.position
		local x, y, z = pos:xyz()
		local sx, sy, sz = v.size:xyz()
		local minx, maxx, miny, maxy
		if v:HasWallOnSide("West") then
			minx = x
		end
		if v:HasWallOnSide("East") then
			maxx = x + voxelSizeX * sx
		end
		if v:HasWallOnSide("North") then
			miny = y
		end
		if v:HasWallOnSide("South") then
			maxy = y + voxelSizeY * sy
		end
		
		local startY = y + halfVoxelSizeY
		local mint = yAxisMinX[floor] or {}
		yAxisMinX[floor] = mint
		local maxt = yAxisMaxX[floor] or {}
		yAxisMaxX[floor] = maxt
		if minx or maxx then
			for i = 0, sy - 1 do
				local yy = startY + i * voxelSizeY
				mint[yy] = Min(mint[yy], minx, maxx)
				maxt[yy] = Max(maxt[yy], minx, maxx)
			end
		end
		
		--check if corners are concrete, then we need to consider them part of the wall for this mat only since its hacked
		if v.spawned_corners then
			if miny or checkCorners(v, "North") then
				--or miny and v:GetWallMatHelperSide("North") == "Concrete" then
				local yy = startY - voxelSizeY
				mint[yy] = Min(mint[yy], x)
				maxt[yy] = Max(maxt[yy], x)
			end
			if miny or checkCorners(v, "East") then
				--or miny and v:GetWallMatHelperSide("North") == "Concrete" then
				local yy = startY - voxelSizeY
				local max = x + voxelSizeX * sx
				mint[yy] = Min(mint[yy], max)
				maxt[yy] = Max(maxt[yy], max)
			end
			if maxy or checkCorners(v, "West") then
				--or maxy and v:GetWallMatHelperSide("South") == "Concrete" then
				local yy = startY + voxelSizeY * sy
				mint[yy] = Min(mint[yy], x)
				maxt[yy] = Max(maxt[yy], x)
			end
			if maxy or checkCorners(v, "South") then
				--or maxy and v:GetWallMatHelperSide("South") == "Concrete" then
				local yy = startY + voxelSizeY * sy
				local max = x + voxelSizeX * sx
				mint[yy] = Min(mint[yy], max)
				maxt[yy] = Max(maxt[yy], max)
			end
		end
		
		local startX = x + halfVoxelSizeX
		local mint = xAxisMinY[floor] or {}
		xAxisMinY[floor] = mint
		local maxt = xAxisMaxY[floor] or {}
		xAxisMaxY[floor] = maxt
		if miny or maxy then
			for i = 0, sx - 1 do
				local xx = startX + i * voxelSizeX
				mint[xx] = Min(mint[xx], miny, maxy)
				maxt[xx] = Max(maxt[xx], miny, maxy)
			end
		end
		
		if v.spawned_corners then
			if minx or checkCorners(v, "North") then
				--or minx and v:GetWallMatHelperSide("West") == "Concrete" then
				local xx = startX - voxelSizeX
				mint[xx] = Min(mint[xx], y)
				maxt[xx] = Max(maxt[xx], y)
			end
			if minx or checkCorners(v, "West") then
				--or minx and v:GetWallMatHelperSide("West") == "Concrete" then
				local xx = startX - voxelSizeX
				local max = y + voxelSizeY * sy
				mint[xx] = Min(mint[xx], max)
				maxt[xx] = Max(maxt[xx], max)
			end
			if maxx or checkCorners(v, "East") then
				--or maxx and v:GetWallMatHelperSide("East") == "Concrete" then
				local xx = startX + voxelSizeX * sx
				mint[xx] = Min(mint[xx], y)
				maxt[xx] = Max(maxt[xx], y)
			end
			if maxx or checkCorners(v, "South") then
				--or maxx and v:GetWallMatHelperSide("East") == "Concrete" then
				local xx = startX + voxelSizeX * sx
				local max = y + voxelSizeY * sy
				mint[xx] = Min(mint[xx], max)
				maxt[xx] = Max(maxt[xx], max)
			end
			
		end
	end)
	
	local noZFightingOffset = 5
	local offset = guim / 10 + 1
	local objs = {}
	local twidth, theight = terrain.GetMapSize()
	local lastYMin = {}
	local lastYMax = {}
	local lastXMin = {}
	local lastXMax = {}
	local lastPlacedMin = {}
	local lastPlacedMax = {}
	
	local function lProcessYAxis(y, yAxisMult, container, lastX, lastY, lastPlaced)
		for f, t in pairs(container) do
			local x = lastX[f]
			local sy = lastY[f]
			local z = findZY(x, sy, y, f)
			local nextZ = x and figureOutZ(x, y, f) or z
			
			if x ~= t[y] or nextZ ~= z then
				lastX[f] = t[y]
				lastY[f] = y
				
				if x and z then
					local ey = y - voxelSizeY
					local offset2 = voxelSizeY - offset
					local width = twidth - x - offset
					if yAxisMult < 0 then
						width = x - offset
					end
					local height = ey - sy + offset2 * 2
					local lastPlane = lastPlaced[f]
					local depth = figureOutDepth(lastPlane, z)
					
					--this handles when walls are different height but one line
					if nextZ < z then
						height = height - voxelSizeY + offset + noZFightingOffset
					end
					if lastPlane and lastPlane.x == x and lastPlane.z < z then
						local offset3 = voxelSizeY - (offset + noZFightingOffset)
						sy = sy + offset3
						height = height - offset3
					end
					
					--further fine tuning.........
					--adjusts plane to be very close to the corner permutation
					if nextZ < z then
						height = height + getSpecialCornerOffset(x, sy + height - offset2*2 + voxelSizeY, z, offset)
					elseif lastPlane and lastPlane.x == x and lastPlane.z < z then
						local offset4 = getSpecialCornerOffset(x, sy - voxelSizeY, z, offset)
						height = height + offset4
						sy = sy - offset4
					end
					
					local pos = point(x + yAxisMult * width / 2 + yAxisMult * offset, sy + height / 2 - offset2, z)
					local plane = PlaceObject("BlackPlane", {
					sizex = width, 
					sizey = height + voxelSizeY, 
					depth = depth, 
					floor = f,
					x = x,
					y = y,
					z = z,
					})
					
					plane:SetPos(pos)
					local key = yAxisMult > 0 and "yAxisMaxX" or "yAxisMinX"
					table.set_ival(objs, f, key, plane)
					lastPlaced[f] = plane
					
					--[[local pbb = plane:GetBBox()
					local wallbox
					if yAxisMult < 0 then
						wallbox = box(pbb:maxx() - 600, pbb:miny(), pbb:minz(), pbb:maxx(), pbb:maxy(), pbb:maxz())
					else
						wallbox = box(pbb:minx(), pbb:miny(), pbb:minz(), pbb:minx() + 600, pbb:maxy(), pbb:maxz())
					end
					--DbgAddBox(wallbox)
					plane.wallbox = wallbox --for pp
					plane:Setup()]]
				end
			end
		end
	end
	
	local function lProcessXAxis(x, xAxisMult, container, lastX, lastY, lastPlaced)
		for f, t in pairs(container) do
			local sx = lastX[f]
			local y = lastY[f]
			local z = findZX(sx, x, y, f)
			local nextZ = y and figureOutZ(x, y, f) or z
			
			if y ~= t[x] or nextZ ~= z then
				lastX[f] = x
				lastY[f] = t[x]
				
				if y and z then
					local ex = x - voxelSizeX
					assert(offset == guim / 10 + 1)
					local offset2 = voxelSizeX - offset
					local width = ex - sx + offset2 * 2
					local height = (theight - y) - offset
					if xAxisMult < 0 then
						height = y - offset
					end
					local lastPlane = lastPlaced[f]
					local depth = figureOutDepth(lastPlane, z)
					
					--this handles when walls are different height but one line
					if nextZ < z then
						width = width - voxelSizeX + offset + noZFightingOffset
					end
					if lastPlane and lastPlane.y == y and lastPlane.z < z then
						local offset3 = voxelSizeX - (offset + noZFightingOffset)
						sx = sx + offset3
						width = width - offset3
					end
					
					--further fine tuning.........
					--adjusts plane to be very close to the corner permutation
					if nextZ < z then
						width = width + getSpecialCornerOffset(sx + width - offset2*2 + voxelSizeX, y, z, offset)
					elseif lastPlane and lastPlane.y == y and lastPlane.z < z then
						local offset4 = getSpecialCornerOffset(sx - voxelSizeX, y, z, offset)
						width = width + offset4
						sx = sx - offset4
					end
					
					local pos = point(sx + width / 2 - offset2,	y + xAxisMult * (height / 2) + xAxisMult * offset, z)
					local plane = PlaceObject("BlackPlane", {
					sizex = width + voxelSizeX, 
					sizey = height, 
					depth = depth, 
					floor = f,
					x = x,
					y = y,
					z = z
					})
					
					plane:SetPos(pos)
					local key = xAxisMult > 0 and "xAxisMaxY" or "xAxisMinY"
					table.set_ival(objs, f, key, plane)
					lastPlaced[f] = plane
					
					
					--[[local pbb = plane:GetBBox()
					local wallbox
					if xAxisMult < 0 then
						wallbox = box(pbb:minx(), pbb:maxy() - 600, pbb:minz(), pbb:maxx(), pbb:maxy(), pbb:maxz())
					else
						wallbox = box(pbb:minx(), pbb:miny(), pbb:minz(), pbb:maxx(), pbb:miny() + 600, pbb:maxz())
					end
					--DbgAddBox(wallbox)
					plane.wallbox = wallbox --for pp
					
					plane:Setup()  --for debugging, itll setup itself]]
				end
			end
		end
	end
	
	for i = 0, (twidth / voxelSizeX) do
		local x = halfVoxelSizeX + i * voxelSizeX
		
		lProcessXAxis(x, -1, xAxisMinY, lastXMin, lastYMin, lastPlacedMin)
		lProcessXAxis(x, 1, xAxisMaxY, lastXMax, lastYMax, lastPlacedMax)
	end
	
	--reset helpers
	lastYMin = {}
	lastYMax = {}
	lastXMin = {}
	lastXMax = {}
	lastPlacedMin = {}
	lastPlacedMax = {}

	for j = 0, (theight / voxelSizeY) - 1 do
		local y = halfVoxelSizeY + j * voxelSizeY
		
		lProcessYAxis(y, -1, yAxisMinX, lastXMin, lastYMin, lastPlacedMin)
		lProcessYAxis(y, 1, yAxisMaxX, lastXMax, lastYMax, lastPlacedMax)
	end
	
	local function processFirstLast(first, last, f, func)
		if first and last then
			local fb = first:GetBBox2D()
			local lb = last:GetBBox2D()
			if fb:Intersect2D(lb) ~= const.irOutside then
				if fb:Intersect(lb) == const.irOutside then
					local lbmaxz = lb:maxz()
					local lbminz = lb:minz()
					local fbmaxz = fb:maxz()
					local fbminz = fb:minz()
					
					if lbminz > fbmaxz then
						local d = lbminz - fbmaxz + 1
						lb = Offset(lb:grow(0, 0, d), point(0, 0, -d/2))
					elseif fbminz > lbmaxz then
						local d = fbminz - lbmaxz + 1
						fb = Offset(fb:grow(0, 0, d), point(0, 0, -d/2))
					end
				end
				local ib = IntersectRects(fb, lb)
				if ib and ib:IsValid() then
					local fbz = first:GetPos():z()
					local lbz = last:GetPos():z()
					local z = Max(fbz, lbz)
					local d = z - Min(fbz - first.depth, lbz - last.depth)
					local x, y, w, h = func(first, last, ib, z, d)
					local plane = PlaceObject("BlackPlane", {sizex = w, sizey = h, depth = 0, floor = f})
					plane:SetPos(x, y, z - d)
					table.set_ival(objs, f, "corners", plane)
					--DbgAddBox(Offset(plane:GetBBox2D(), 0, 0, 10000))
				end
			end
		end
	end
	
	for f = minf, maxf do
		if objs[f] then
			local t1, t2 = objs[f].xAxisMaxY, objs[f].yAxisMinX
			if t1 and t2 then
				--bot left
				local first, last = t1[1], t2[#t2]
				processFirstLast(first, last, f, function(first, last, ib, z, d)
					local w = ib:maxx()
					local h = theight - ib:miny()
					local x = w / 2
					local y = ib:miny() + h / 2
					return x, y, w, h
				end)
			end
			t1, t2 = objs[f].xAxisMinY, objs[f].yAxisMinX
			if t1 and t2 then
				local first, last = t1[1], t2[1]
				processFirstLast(first, last, f, function(first, last, ib, z, d)
					local w = ib:maxx()
					local h = ib:maxy()
					local x = w / 2
					local y = h / 2
					return x, y, w, h
				end)
			end
			t1, t2 = objs[f].yAxisMaxX, objs[f].xAxisMinY
			if t1 and t2 then
				local first, last = t1[1], t2[#t2]
				processFirstLast(first, last, f, function(first, last, ib, z, d)
					local w = twidth - ib:minx()
					local h = ib:maxy()
					local x = ib:minx() + w / 2
					local y = h / 2
					return x, y, w, h
				end)
			end
			t1, t2 = objs[f].yAxisMaxX, objs[f].xAxisMaxY
			if t1 and t2 then
				local first, last = t1[#t1], t2[#t2]
				processFirstLast(first, last, f, function(first, last, ib, z, d)
					local w = twidth - ib:minx()
					local h = theight - ib:miny()
					local x = ib:minx() + w / 2
					local y = ib:miny() + h / 2
					--DbgAddBox(Offset(ib, 0, 0, 10000))
					return x, y, w, h
				end)
			end
		end
	end
	
	local function lPPPlaneHeightsNextToWalls()
		--pp part 2, reduce box height if possible next to walls
		local bps = MapGet("map", "BlackPlane", function(o) return o.wallbox and o.wallbox:IsValid() end) or {} --skip corners
		--TODO: make less boxes
		--TODO: after corners boot up it fucks up
		local i = 1
		while i <= #bps do
			local bp1 = bps[i]
			i = i + 1
			if IsValid(bp1) and bp1.wallbox then
				local bp1bb = bp1:GetBBox()
				DbgAddBox(bp1bb)
				local dbging = 5
				for j = 1, #bps do
					local bp2 = bps[j]
					if IsValid(bp2) and bp2.wallbox and bp2.floor == bp1.floor then
						local bp2bb = bp2:GetBBox()
						if bp1bb:Intersect2D(bp2bb) ~= const.irOutside
							and (bp1.wallbox:Intersect2D(bp2bb) ~= const.irOutside or
								bp2.wallbox:Intersect2D(bp1bb) ~= const.irOutside)
							and bp1.wallbox:Intersect2D(bp2.wallbox) == const.irOutside then
							
							DbgClear()
							DbgAddBox(bp1.wallbox)
							DbgAddBox(bp2.wallbox)
							local childBoxes = SplitBoxes(bp1bb, bp2bb)
							for k = 1, #childBoxes do
								local cb = childBoxes[k]
								DbgAddBox(cb)
								local i1 = bp1.wallbox:Intersect2D(cb) ~= const.irOutside
								local i2 = bp2.wallbox:Intersect2D(cb) ~= const.irOutside
								if not i1 and not i2 then
									if bp1bb:Point2DInside(cb:Center()) then
										i1 = true
									else
										i2 = true
									end
								end
								
								if i1 and i2 then
									goto cont
								elseif i1 then
									childBoxes[k] = box(cb:minx(), cb:miny(), bp1bb:minz(),
																cb:maxx(), cb:maxy(), bp1bb:maxz())
								elseif i2 then
									childBoxes[k] = box(cb:minx(), cb:miny(), bp2bb:minz(),
																cb:maxx(), cb:maxy(), bp2bb:maxz())
								end
							end
							
							local f = bp1.floor
							local wb1 = bp1.wallbox
							local wb2 = bp2.wallbox
							DoneObject(bp1)
							DoneObject(bp2)

							for k = 1, #childBoxes do
								local cb = childBoxes[k]
								DbgAddBox(cb)
								local plane = PlaceObject("BlackPlane", {sizex = cb:sizex(), sizey = cb:sizey(), depth = cb:sizez(), floor = f})
								plane:SetPos(cb:Center():SetZ(cb:maxz()))
								if cb:Intersect2D(wb1) ~= const.irOutside then
									plane.wallbox = wb1
								elseif cb:Intersect2D(wb2) ~= const.irOutside then
									plane.wallbox = wb2
								end
								table.insert(bps, plane)
								plane:Setup()
							end
						end
					end
					::cont::
					if not IsValid(bp1) then
						break
					end
				end
			end
		end
	end
	
	--lPPPlaneHeightsNextToWalls()
	
	return objs
end

function SplitBoxes(b1, b2)
	DbgClear()
	DbgAddBox(b1)
	DbgAddBox(b2)
	local xAxis = {b1:minx(), b1:maxx(), b2:minx(), b2:maxx()}
	local yAxis = {b1:miny(), b1:maxy(), b2:miny(), b2:maxy()}
	table.sort(xAxis)
	table.sort(yAxis)
	
	
	local ret = {}
	local minx, maxx, miny, maxy
	for i, x in ipairs(xAxis) do
		maxx = minx and x
		minx = minx or x
		if minx and maxx then
			for j, y in ipairs(yAxis) do
				maxy = miny and y
				miny = miny or y
				if miny and maxy then
					local rb = box(minx, miny, maxx, maxy)
					if rb:IsValid() and (b1:Point2DInside(rb:Center()) or b2:Point2DInside(rb:Center())) then
						table.insert(ret, rb)
						--DbgAddBox(rb)
					end
					miny = maxy
					maxy = nil
				end
			end
			
			minx = maxx
			maxx = nil
		end
	end
	
	return ret
end

function dbg1()
	DbgClear()
	MapForEach("map", "BlackPlaneBase", function(o) DbgAddBox(o:GetBBox()) end)
end

function dbg2()
	MapForEach("map", "BlackPlaneBase", function(o) o:SetEnumFlags(const.efSelectable) end)
end

function dbg3()
	return MapGetFirst("map", "BlackPlaneBase")
end

function MapHasBlackPlanes()
	return MapGetFirst("map", "BlackPlaneBase")
end

function CleanBlackPlanes(floor)
	DoneObjects(MapGet("map", "BlackPlaneBase", function(o) return not floor or floor == o.floor end))
end

AppendClass.MapDataPreset = { properties = {
	{ category = "Camera", name = "Dont Hide Black Planes", id = "DontHideBlackPlanes", editor = "bool", default = false, help = "If planes were invisible when toggled, reload map to pop them up" },
}}

function HideBlackPlanesNotOnFloor(floor)
	local edit = IsEditorActive()
	if edit and LocalStorage.FilteredCategories.BlackPlane == "invisible" then
		return
	end

	if GetMapName() == "" then
		return
	end
	
	if mapdata and mapdata.DontHideBlackPlanes then
		return
	end
	
	local cmtPaused = g_CMTPaused
	MapForEach("map", "BlackPlaneBase", function(o, edit, floor, cmtPaused)
		local hide = o.floor ~= floor
		if edit or cmtPaused then
			o:SetShadowOnlyImmediate(hide)
		else
			o:SetShadowOnly(hide)
		end
	end, edit, floor, cmtPaused)
end

function OnMsg.GameEnterEditor()
	HideBlackPlanesNotOnFloor(LocalStorage.FilteredCategories["HideFloor"] - 1)
end

function OnMsg.FloorsHiddenAbove(floor, fnHide)
	HideBlackPlanesNotOnFloor(floor)
end

MapVar("blackPlanesLastVisibleFloor", false)
function OnMsg.WallVisibilityChanged()
	UpdateBlackPlaneVisibilityOnFloorChange()
end

function ResetBlackPlaneVisibility()
	blackPlanesLastVisibleFloor = false
	UpdateBlackPlaneVisibilityOnFloorChange()
end

function UpdateBlackPlaneVisibilityOnFloorChange()
	local camFloor = cameraTac.GetFloor()
	camFloor = camFloor + 1
	if not WallInvisibilityThread and mapdata then
		--basically, hide everything if WallInvisibilityThread is off except top floor planes
		camFloor = mapdata.CameraMaxFloor + 1
	end
	
	if blackPlanesLastVisibleFloor ~= camFloor then
		HideBlackPlanesNotOnFloor(camFloor)
		blackPlanesLastVisibleFloor = camFloor
	end
end

function ShowAllBlackPlanes()
	MapForEach("map", "BlackPlaneBase", function(o)
		o:SetShadowOnlyImmediate(false) --in case cmt is off
		o:SetShadowOnly(false) --in case cmt is on
	end)
	blackPlanesLastVisibleFloor = false
end

function OnMsg.ChangeMapDone()
	if GetMapName() == "" then return end
	if not mapdata.GameLogic then return end
	--GameToolsRestoreObjectsVisibility now makes black planes save on maps with opacity 0,
	--cmt expects them to start with opacity 100, hence this:
	ShowAllBlackPlanes()
end

function Slab:ApplyMaterialProps()
	local cm = self:GetMaterialType()
	self.invulnerable = false
	self:InitFromMaterialPreset(Presets.ObjMaterial.Default[cm])
end

function Volume:GetError()
	if	self:Getsize_x() > maxRoomVoxelSizeX or
		self:Getsize_y() > maxRoomVoxelSizeY or
		self:Getsize_z() > maxRoomVoxelSizeZ then
		return string.format("Volume too big - max size is %d x %d x %d. Consider splitting in two, or contact a programmer",
			maxRoomVoxelSizeX, maxRoomVoxelSizeY, maxRoomVoxelSizeZ)
	end
end

--0196197: script to go through all maps and change inner wall mat of rooms
function lvl_design_01()
	local ret = false
	EnumVolumes(function(v)
		if v.inner_wall_mat == "Concrete" and v.wall_mat == "ConcreteThin" then
			v.inner_wall_mat = noneWallMat
			v:OnSetinner_wall_mat(noneWallMat, "Concrete")
			print("Tweaked room", GetMapName())
			ret = ret or true
		end
	end)
	return ret
end

function lvl_design_01_ResaveAllMaps()
	CreateRealTimeThread(function()
		ForEachMap(nil, function()
			EditorActivate()
			if lvl_design_01() then
				SaveMap("no backup")
			end
			XShortcutsSetMode("Game")
		end)
	end)
end

----------------------------------------------------------------------
--blk plane selection
----------------------------------------------------------------------
DefineClass.XBlackPlaneSelectionTool = {
	__parents = { "XEditorTool" },
	
	ToolTitle = "Black Plane Selection Tool",
	ToolSection = "Misc",
	Description = {
		"When toggled you can select code renderable Black Planes."
	},
	ActionSortKey = "7",
	ActionIcon = "CommonAssets/UI/Editor/Tools/HideCodeRenderables.tga", 
	ActionShortcut = "Shift-X",
	ActionMode = "Editor",
	ToolKeepSelection = true,

	time_activated = false,
}

function XBlackPlaneSelectionTool:Init()
	--print("XBlackPlaneSelectionTool:Init")
	self.time_activated = now()
	editor.ClearSel()
end

function XBlackPlaneSelectionTool:CheckStartOperation(pt)
	print("XBlackPlaneSelectionTool:CheckStartOperation")
end

function XBlackPlaneSelectionTool:OnShortcut(shortcut, source, repeated)
	local released1 = string.format("-%s", self.ActionShortcut)
	local released2 = string.format("-%s", self.ActionShortcut2)
	if shortcut == self.ActionShortcut or shortcut == self.ActionShortcut2 then
		XEditorSetDefaultTool()
		return "break"
	elseif (shortcut == released1 or shortcut == released2) and (now() - self.time_activated > 300) then
		XEditorSetDefaultTool()
		return "break"
	elseif shortcut == "Delete" then
		local selection = editor.GetSel()
		editor.ClearSel()
		DoneObjects(selection)
		DbgClear()
	elseif shortcut == "W" then
		local selection = editor.GetSel()
		if #selection > 0 then
			XEditorSetDefaultTool("MoveGizmo")
		end
	end
end

function XBlackPlaneSelectionTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		--print("XBlackPlaneSelectionTool:OnMouseButtonDown")
		local selection = editor.GetSel()
		local closestPt, closestObj;
		local eye, cursor = camera.GetEye(), GetTerrainCursor()
		local vec = cursor - eye
		cursor = eye + vec * 3
		DbgAddVector(eye, cursor - eye)
		MapForEach("map", "BlackPlaneBase", function(o, eye, cursor, selection)
			if not table.find(selection, o) then
				local bb = o:GetBBox()
				if bb:sizez() == 0 then
					bb = bb:grow(0, 0, 1) --this func doesn't see zero height bbs
				end
				local rez, pt1, pt2 = IntersectSegmentBoxInt(eye, cursor, bb)
				if rez then
					local closest = IsCloser(eye, pt1, pt2) and pt1 or pt2
					if not closestPt or IsCloser(eye, closest, closestPt) then
						closestObj = o
						closestPt = closest
					end
				end
			end
		end, eye, cursor, selection)
		
		if closestObj then
			--print("great successs")
			editor.ClearSel()
			DbgClear()
			editor.AddToSel({closestObj})
			DbgAddBox(closestObj:GetBBox())
		end
	elseif button == "R" then
		editor.ClearSel()
		DbgClear()
	end
end

UndefineClass("CompositeBodyPresetColor")

function OnMsg.NewMapLoaded()
	local hasBlackPlanes = MapHasBlackPlanes()
	if MapPatchesApplied and hasBlackPlanes then
		AnalyseRoomsAndPlaceBlackPlanesOnEdges()
	end
	if hasBlackPlanes then
		PlaceBlackBoxThatHidesTheSkyOnUndergroundMaps()
	end
end

DefineClass("BlackCylinder", "Mesh") --this class gets hidden by the blackplanes filter, along with black plane base
local AppendVertex = pstr().AppendVertex
function PlaceBoxDefaultMesh(box, color)
	color = color or RGB(0, 0, 0)
	local vpstr = pstr("", 1024)
	local p1, p2, p3, p4 = box:ToPoints2D()
	local center = box:Center()
	local minz, maxz = box:minz(), box:maxz()
	p1 = p1 - center
	p2 = p2 - center
	p3 = p3 - center
	p4 = p4 - center
	minz = minz - center:z()
	maxz = maxz - center:z()
	
	for _, z in ipairs{minz, maxz} do
		for _, p in ipairs{p1, p2, p3, p3, p4, p1} do
			local x, y = p:xy()
			AppendVertex(vpstr, x, y, z, color)
		end
	end
	
	local function addPlane(p1, p2, p3)
		local p4 = p2:SetZ(p3:z())
		AppendVertex(vpstr, p1, color)
		AppendVertex(vpstr, p2, color)
		AppendVertex(vpstr, p3, color)
		AppendVertex(vpstr, p3, color)
		AppendVertex(vpstr, p2, color)
		AppendVertex(vpstr, p4, color)
	end
	
	addPlane(p1:SetZ(minz), p2:SetZ(minz), p1:SetZ(maxz))
	addPlane(p4:SetZ(minz), p1:SetZ(minz), p4:SetZ(maxz))
	addPlane(p2:SetZ(minz), p3:SetZ(minz), p2:SetZ(maxz))
	addPlane(p3:SetZ(minz), p4:SetZ(minz), p3:SetZ(maxz))
	
	local m = Mesh:new()
	m:SetMesh(vpstr)
	m:SetShader(ProceduralMeshShaders.default_mesh)
	m:SetDepthTest(true)
	m:SetPos(center)

	return m
end

function PlaceBlackBoxThatHidesTheSkyOnUndergroundMaps()
	local sizex, sizey = terrain.GetMapSize()
	local mapbb = box(0, 0, 0, sizex, sizey, 1000 * guim)
	local m = PlaceBoxDefaultMesh(mapbb)
	m:ClearGameFlags(const.gofPermanent)
	setmetatable(m, BlackCylinder)
end

function PlaceBlackCylinderThatHidesTheSkyOnUndergroundMaps()
	local b = box()
	MapForEach("map", "CObject", function(o)
		b = Extend(b, o:GetObjectBBox())
	end)

	local sizex, sizey = b:sizex()/2, b:sizey()/2
	local radius = sqrt(sizex * sizex + sizey * sizey) --+ 10 * guim
	local wall = CreateCylinderMesh(point(0, 0, 0), point(0, 0, 1000 * guim), radius, point(0, 0, 4096), 0, black)
	wall:SetShader(ProceduralMeshShaders.default_mesh)
	wall:SetDepthTest(true)
	wall:SetPos(b:Center():SetTerrainZ())
	wall:ClearGameFlags(const.gofPermanent)
	setmetatable(wall, BlackCylinder) --so it hides with the same editor filter as other blackplanes
	return wall
end
