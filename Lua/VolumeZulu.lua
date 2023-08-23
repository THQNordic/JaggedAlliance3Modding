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
		local min = r.box:min()
		local max = r.box:max()
		if min:x() < border:minx() or min:y() < border:miny() or
			max:x() > border:maxx() or max:y() > border:maxy() then
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

DefineClass.BlackPlane = {
	__parents = { "Mesh" },
	flags = { gofPermanent = true },
	properties = {
		{ id = "sizex", editor = "number", default = 0 },
		{ id = "sizey", editor = "number", default = 0 },
		{ id = "depth", editor = "number", default = 0 },
		{ id = "floor", editor = "number", default = 0 },
	},
}

function BlackPlane:GameInit()
	self:Setup()
end

function BlackPlane:GetBBox2D()
	local sx = self.sizex
	local sy = self.sizey
	local ret = box(0, 0, -1, sx, sy, 0)
	local x, y, z = self:GetPosXYZ()
	return Offset(ret, point(x - sx / 2, y - sy / 2, z))
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
			if cs and cs.isVisible then--and cs.material == "Concrete" then
				return true
			end
		end
	end
	
	local function figureOutZ(x, y, f)
		local z = 0
		MapForEach(x, y, 0, halfVoxelSizeX + 1, "WallSlab", "RoomCorner", nil, const.efVisible, function(s, f)
			if s.floor == f and not rawget(s, "isPlug") then
				local sz = s:GetPos():z()
				if sz > z then
					z = sz
				end
			end
		end, f)
		return z + voxelSizeZ
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
	
	local objs = {}
	local twidth, theight = terrain.GetMapSize()
	local lastYMin = {}
	local lastYMax = {}
	local lastXMin = {}
	local lastXMax = {}
	local lastPlacedMin = {}
	local lastPlacedMax = {}
	
	for i = 0, (twidth / voxelSizeX) do
		local x = halfVoxelSizeX + i * voxelSizeX
		
		for f, t in pairs(xAxisMinY) do			
			if lastYMin[f] ~= t[x] then
				local sx = lastXMin[f]
				local y = lastYMin[f]

				lastYMin[f] = t[x]
				lastXMin[f] = x
				
				if y then
					local ex = x - voxelSizeX
					local z = figureOutZ(sx, y, f)
					local offset = guim / 10 + 1
					local offset2 = voxelSizeX - offset
					local width = ex - sx + offset2 * 2
					local height = y - offset
					local depth = figureOutDepth(lastPlacedMin[f], z)
					local pos = point(sx + width / 2 - offset2, y - height / 2 - offset, z)
					local plane = PlaceObject("BlackPlane", {sizex = width + voxelSizeX, sizey = height, depth = depth, floor = f})
					plane:SetPos(pos)
					table.set_ival(objs, f, "xAxisMinY", plane)
					lastPlacedMin[f] = plane
				end
			end
		end
		
		for f, t in pairs(xAxisMaxY) do
			--[[if f == 1 and t[x] then
				DbgAddVector(point(x, t[x], 9000))
			end]]
			if lastYMax[f] ~= t[x] then
				local sx = lastXMax[f]
				local y = lastYMax[f]

				lastYMax[f] = t[x]
				lastXMax[f] = x
				
				if y then
					local ex = x - voxelSizeX
					local z = figureOutZ(sx, y, f)
					local offset = guim / 10 + 1
					local offset2 = voxelSizeX - offset
					local width = ex - sx + offset2 * 2
					local height = (theight - y) - offset
					local depth = figureOutDepth(lastPlacedMax[f], z)
					local pos = point(sx + width / 2 - offset2, y + height / 2 + offset, z)
					local plane = PlaceObject("BlackPlane", {sizex = width + voxelSizeX, sizey = height, depth = depth, floor = f})
					plane:SetPos(pos)
					table.set_ival(objs, f, "xAxisMaxY", plane)
					lastPlacedMax[f] = plane
				end
			end
		end
	end
	lastYMin = {}
	lastYMax = {}
	lastXMin = {}
	lastXMax = {}
	lastPlacedMin = {}
	lastPlacedMax = {}
	for j = 0, (theight / voxelSizeY) - 1 do
		local y = halfVoxelSizeY + j * voxelSizeY
		
		for f, t in pairs(yAxisMinX) do
			--[[if t[y] then
				DbgAddVector(point(t[y],y, 9000))
			end]]
			if lastXMin[f] ~= t[y] then
				local sy = lastYMin[f]
				local x = lastXMin[f]

				lastXMin[f] = t[y]
				lastYMin[f] = y
				
				if x then
					local ey = y - voxelSizeY
					local z = figureOutZ(x, sy, f)
					local offset = guim / 10 + 1
					local offset2 = voxelSizeY - offset
					local width = x - offset
					local height = ey - sy + offset2 * 2
					local depth = figureOutDepth(lastPlacedMin[f], z)
					local pos = point(x - width / 2 - offset, sy + height / 2 - offset2, z)
					local plane = PlaceObject("BlackPlane", {sizex = width, sizey = height + voxelSizeY, depth = depth, floor = f})
					plane:SetPos(pos)
					table.set_ival(objs, f, "yAxisMinX", plane)
					lastPlacedMin[f] = plane
				end
			end
		end
		
		for f, t in pairs(yAxisMaxX) do
		--[[	if t[y] then
				DbgAddVector(point(t[y],y, 9000))
			end]]
			if lastXMax[f] ~= t[y] then
				local sy = lastYMax[f]
				local x = lastXMax[f]

				lastXMax[f] = t[y]
				lastYMax[f] = y
				
				if x then
					local ey = y - voxelSizeY
					local z = figureOutZ(x, sy, f)
					local offset = guim / 10 + 1
					local offset2 = voxelSizeY - offset
					local width = twidth - x - offset
					local height = ey - sy + offset2 * 2
					local depth = figureOutDepth(lastPlacedMax[f], z)
					local pos = point(x + width / 2 + offset, sy + height / 2 - offset2, z)
					local plane = PlaceObject("BlackPlane", {sizex = width, sizey = height + voxelSizeY, depth = depth, floor = f})
					plane:SetPos(pos)
					table.set_ival(objs, f, "yAxisMaxX", plane)
					lastPlacedMax[f] = plane
				end
			end
		end
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
					local plane = PlaceObject("BlackPlane", {sizex = w, sizey = h, depth = d, floor = f})
					plane:SetPos(x, y, z)
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
	return objs
end

function CleanBlackPlanes(floor)
	DoneObjects(MapGet("map", "BlackPlane", function(o) return not floor or floor == o.floor end))
end

local function HideBlackPlanesNotOnFloor(floor)
	local edit = IsEditorActive()
	if edit and LocalStorage.FilteredCategories.BlackPlane == "invisible" then
		return
	end
	local mn = GetMapName()
	if mn and mn:starts_with("H-3U") then
		--hack - always visible on this map regardless of floor
		return
	end
	
	MapForEach("map", "BlackPlane", function(o, edit, floor)
		local hide = o.floor ~= floor
		if edit then
			o:SetShadowOnlyImmediate(hide)
		else
			o:SetShadowOnly(hide)
		end
	end, edit, floor)
end

function OnMsg.GameEnterEditor()
	HideBlackPlanesNotOnFloor(LocalStorage.FilteredCategories["HideFloor"] - 1)
end

function OnMsg.FloorsHiddenAbove(floor, fnHide)
	HideBlackPlanesNotOnFloor(floor)
end

MapVar("blackPlanesLastVisibleFloor", false)
function OnMsg.WallVisibilityChanged()
	local camFloor = cameraTac.GetFloor() + 1
	if blackPlanesLastVisibleFloor ~= camFloor then
		HideBlackPlanesNotOnFloor(camFloor)
		blackPlanesLastVisibleFloor = camFloor
	end
end

function OnMsg.ChangeMapDone()
	if GetMapName() == "" then return end
	if not mapdata.GameLogic then return end
	--GameToolsRestoreObjectsVisibility now makes black planes save on maps with opacity 0,
	--cmt expects them to start with opacity 100, hence this:
	MapForEach("map", "BlackPlane", function(o)
		o:SetOpacity(100)
	end)
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
