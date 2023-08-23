DefineClass.CoverObj = {
	__parents = { "Object", "ComponentAttach" },
	entity = false,
	dbg_mesh = false,
}

function CoverObj:GameInit()
	local parent = self:GetParent()
	if not self:IsAligned() then
		self:Notify("delete")
		return
	end
end

function CoverObj:IsAligned()
end

function CoverObj:Show()
end

function CoverObj:Hide()
	if IsValid(self.dbg_mesh) then
		DoneObject(self.dbg_mesh)
		self.dbg_mesh = nil
	end
end


DefineClass.CoverWall = {
	__parents = { "CoverObj" },
}

function CoverWall:Show()
	if not IsValid(self.dbg_mesh) then
		self.dbg_mesh = PlaceObject("Mesh")		
		self.dbg_mesh:SetDepthTest(true)

		local width = 3 * const.SlabSizeX / 10
		local height = const.SlabSizeY
		local depth = const.SlabSizeZ

		width = width / 2
		height = height / 2
		--depth = -depth
		local p_pstr = pstr("")
		local function AddPoint(x,y,z) 
			p_pstr:AppendVertex(point(x*width, y*height, z*depth), RGB(120, 20, 180))
		end
		
		-- -x
		AddPoint(-1, -1, 0) AddPoint(-1,  1, 0) AddPoint(-1,  1, 1)		
		AddPoint(-1,  1, 1) AddPoint(-1, -1, 1) AddPoint(-1, -1, 0)		
		-- +x
		AddPoint( 1, -1, 0) AddPoint( 1,  1, 0) AddPoint( 1,  1, 1)		
		AddPoint( 1,  1, 1) AddPoint( 1, -1, 1) AddPoint( 1, -1, 0)
		-- -y
		AddPoint(-1, -1, 0) AddPoint( 1, -1, 0) AddPoint( 1, -1, 1)
		AddPoint( 1, -1, 1) AddPoint(-1, -1, 1) AddPoint(-1, -1, 0)		
		-- +y
		AddPoint(-1,  1, 0) AddPoint( 1,  1, 0) AddPoint( 1,  1, 1)
		AddPoint( 1,  1, 1) AddPoint(-1,  1, 1) AddPoint(-1,  1, 0)		
		-- z0
		AddPoint(-1, -1, 0) AddPoint(-1,  1, 0) AddPoint( 1,  1, 0)
		AddPoint( 1,  1, 0) AddPoint( 1, -1, 0) AddPoint(-1, -1, 0)
		-- +z
		AddPoint(-1, -1, 1) AddPoint(-1,  1, 1) AddPoint( 1,  1, 1)
		AddPoint( 1,  1, 1) AddPoint( 1, -1, 1) AddPoint(-1, -1, 1)
		
		self.dbg_mesh:SetMesh(p_pstr)
		
		self:Attach(self.dbg_mesh)
	end
end

function CoverWall:IsAligned()
	local x, y, z = self:GetPosXYZ()
	local angle = self:GetAngle()
	local tx, ty, tz = WallVoxelToWorld(WallWorldToVoxel(x, y, z, angle))
	return x == tx and y == ty and z == tz
end

-- cover shields angle!
local cover_dir_angle = {
	["up"] = 90 * 60,
	["right"] = 2 * 90 * 60,
	["down"] = 3 * 90 * 60,
	["left"] = 0,
}
function GetCoverDirAngle(dir)
	return cover_dir_angle[dir]
end

function GetCoversAt(pos_or_obj)
	local up, right, down, left = GetCover(pos_or_obj)
	if not up then
		return
	end
	return {
		[cover_dir_angle.up] = up,
		[cover_dir_angle.right] = right,
		[cover_dir_angle.down] = down,
		[cover_dir_angle.left] = left,
	}
end

local cover_offsets = {
	point(0, -const.SlabSizeY / 2, 0), -- up
	point(const.SlabSizeX / 2, 0, 0), -- "right"
	point(0, const.SlabSizeY / 2, 0), -- "down"
	point(-const.SlabSizeX / 2, 0, 0), -- "left"
}

function GetCoverOffset(angle)
	local idx = 1 + (1 + CardinalDirection(angle) / (90*60)) % 4
	return cover_offsets[idx]
end

function GetAngleCover(pos, angle)
	local idx = 1 + (1 + CardinalDirection(angle) / (90*60)) % 4
	local cover = select(idx, GetCover(pos))
	return cover
end

function GetHighestCoverUI(pos_or_obj)
	if not IsPoint(pos_or_obj) and pos_or_obj.return_pos then
		pos_or_obj = pos_or_obj.return_pos
	end
	
	return GetHighestCover(pos_or_obj)
end

function GetHighestCover(pos_or_obj)
	local up, right, down, left = GetCover(pos_or_obj)
	if not up then
		return
	end
	local high = const.CoverHigh
	return (up == high or right == high or down == high or left == high) and high or const.CoverLow
end

function GetCoverTypes(pos_or_obj)
	local up, right, down, left = GetCover(pos_or_obj)
	if not up then
		return
	end
	local low = const.CoverLow
	local high = const.CoverHigh
	local cover_low = up == low or right == low or down == low or left == low
	local cover_high = up == high or right == high or down == high or left == high
	return cover_high, cover_low
end

function GetUnitOrientationToHighCover(pos, angle)
	local up, right, down, left = GetCover(pos)
	if not up then
		return
	end
	local high = const.CoverHigh
	if up ~= high and right ~= high and down ~= high and left ~= high then
		return
	end
	local max_diff = 90*60
	local best_angle, best_diff
	-- rotations against the cover
	local a1 = cover_dir_angle.up + 180*60
	local a2 = cover_dir_angle.right + 180*60
	local a3 = cover_dir_angle.down + 180*60
	local a4 = cover_dir_angle.left + 180*60

	local diff1 = abs(AngleDiff(angle, a1))
	local diff2 = abs(AngleDiff(angle, a2))
	local diff3 = abs(AngleDiff(angle, a3))
	local diff4 = abs(AngleDiff(angle, a4))

	-- avoid facing another high cover
	-- up / down
	if right == high and diff2 < max_diff or left == high and diff4 < max_diff then
		if up ~= high   and (not best_diff or diff1 < best_diff) then best_angle, best_diff = a1, diff1 end
		if down ~= high and (not best_diff or diff3 < best_diff) then best_angle, best_diff = a3, diff3 end
	end
	-- left / right
	if up == high and diff1 < max_diff or down == high and diff3 < max_diff then
		if left ~= high and (not best_diff or diff4 < best_diff) then best_angle, best_diff = a4, diff4 end
		if right ~= high and (not best_diff or diff2 < best_diff) then best_angle, best_diff = a2, diff2 end
	end

	-- fallback (can face another high cover)
	if not best_angle then
		-- up / down
		if right == high and diff2 < max_diff or left == high and diff4 < max_diff then
			if not best_diff or diff1 < best_diff then best_angle, best_diff = a1, diff1 end
			if not best_diff or diff3 < best_diff then best_angle, best_diff = a3, diff3 end
		end
		-- left / right
		if up == high and diff1 < max_diff or down == high and diff3 < max_diff then
			if not best_diff or diff4 < best_diff then best_angle, best_diff = a4, diff4 end
			if not best_diff or diff2 < best_diff then best_angle, best_diff = a2, diff2 end
		end
	end

	return best_angle
end

DefineClass.BaseObjectWithCover = {
	__parents = { "AutoAttachObject" },
	covers = false,
}

function BaseObjectWithCover:GameInit()
	self.covers = self:GetAttaches("CoverObj")
	for _, cover in ipairs(self.covers or empty_table) do
		if self:GetParent() then
			DoneObject(cover)
		else
			local pos = cover:GetPos() + cover:GetAttachOffset()
			cover:Detach()
			cover:SetPos(pos)
		end
	end
	if self:GetParent() then
		self.covers = {}
	end
end

function BaseObjectWithCover:Done()
	for _, obj in ipairs(self.covers) do
		DoneObject(obj)
	end
	self.covers = nil
end

DefineClass.BaseCliff = {
	__parents = { "FloorAlignedObj", "Deposition" },
	flags = {efPathSlab = true},
}

DefineClass.BaseTrench = {
	__parents = { "FloorAlignedObj", "Deposition" },
	flags = {efPathSlab = true},
}

local halfVoxelSizeX = const.SlabSizeX / 2
local halfVoxelSizeY = const.SlabSizeY / 2
local VoxelSizeZ = const.SlabSizeZ
local clrInvisible = RGBA(0, 0, 0, 0)
local slabx, slaby, slabz = const.SlabSizeX, const.SlabSizeY, const.SlabSizeZ

function GetVoxelBox(padding, world_pos)
	padding = padding or 1
	world_pos = world_pos or GetCursorPos()
	
	local surface = terrain.GetHeight(world_pos)
	world_pos = (surface and surface > world_pos:z()) and world_pos:SetZ(surface) or world_pos
	local x, y, z = VoxelToWorld(WorldToVoxel(world_pos))
	local pt2d = point(x, y)
	local offset = point(padding * slabx + slabx / 2, padding * slaby + slaby / 2)
	local bbox = box(pt2d - offset, pt2d + offset)
	local minz, maxz = z, z
	MapForEach(bbox, function(obj)
		local obj_bbox = obj:GetEntityBBox()
		local obj_z = obj:GetPos():z()
		if obj_z then
			local obj_minz, obj_maxz = obj_z + obj_bbox:minz(), obj_z + obj_bbox:maxz()
			minz = (obj_minz < minz) and obj_minz or minz
			maxz = (obj_maxz > maxz) and obj_maxz or maxz
		end
	end)
	minz = minz - slabz / 2 - padding * slabz
	maxz = maxz + slabz / 2 + padding * slabz
	
	return box(bbox:min():SetZ(minz), bbox:max():SetZ(maxz))
end

function GetCoverPercentage(stand_pos, attack_pos, target_stance)
	local cover, any, coverage = PosGetCoverPercentageFrom(stand_pos, attack_pos)
	if cover == const.CoverLow and target_stance == "Standing" then
		cover, coverage = false, 0
	end
	return cover, any, coverage or 0
end
