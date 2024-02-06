NSEW_pairs = sorted_pairs -- todo: make an iterator that explicitly visits them in a predefined order
-- EnumVolumes([class, ] { box, | obj, | point, | x, y | x, y, z, }) - returns an array of the volumes interesecting the box/point
-- EnumVolumes(..., "smallest") - returns the smallest volume (by surface) interesecting the box/point
-- EnumVolumes(..., filter, ...) - returns an array with all volumes interesecting the box/point for which filter(volume, ...) returned true
local gofPermanent = const.gofPermanent

if FirstLoad then
	GedRoomEditor = false
	GedRoomEditorObjList = false
	g_RoomCornerTaskList = {}
	SelectedVolume = false
	VolumeCollisonEnabled = false
	HideFloorsAboveThisOne = false
	--moves wall slabs on load to their expected pos
	--it seems that lvl designers commonly misplace wall slabs which causes weird glitches, this should fix that
	RepositionWallSlabsOnLoad = Platform.developer or false
end

function VolumeStructuresList()
	local list = {""}
	EnumVolumes(function (volume, list, find)
		if not find(list, volume.structure) then
			list[#list + 1] = volume.structure
		end
	end, list, table.find)
	table.sort(list)
	return list
end

-- the map is considered in bottom-right quadrant, which means that (0, 0) is north, west
local noneWallMat = const.SlabNoMaterial
local defaultWallMat = "default"

DefineClass.Volume = {
	__parents = { "RoomRoof", "StripObjectProperties", "AlignedObj", "ComponentAttach", "EditorVisibleObject" },
	flags = { gofPermanent = true, cofComponentVolume = true, efVisible = true },
	
	properties = {
		{ category = "Not Room Specific", id = "volumeCollisionEnabled",  name = "Toggle Global Volume Collision", default = true, editor = "bool", dont_save = true },
		{ category = "Not Room Specific", id = "buttons3", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Recreate All Walls", func = "RecreateAllWallsOnMap"},
				{name = "Recreate All Roofs", func = "RecreateAllRoofsOnMap"},
				{name = "Recreate All Floors", func = "RecreateAllFloorsOnMap"},
			},
		},
		{ category = "General", id = "buttons2", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Recreate Walls", func = "RecreateWalls"},
				{name = "Recreate Floor", func = "RecreateFloor"},
				{name = "Recreate Roof", func = "RecreateRoofBtn"},
				{name = "Re Randomize", func = "ReRandomize"},
				{name = "Copy Above", func = "CopyAbove"},
				{name = "Copy Below", func = "CopyBelow"},
			},
		},
		{ category = "General", id = "buttons2row2", name = "Buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			buttons = {
				{name = "Lock Subvariants", func = "LockAllSlabsToCurrentSubvariants"},
				{name = "Unlock Subvariants", func = "UnlockAllSlabs"},
				{name = "Make Slabs Vulnerable", func = "MakeOwnedSlabsVulnerable"},
				{name = "Make Slabs Invulnerable", func = "MakeOwnedSlabsInvulnerable"},
			},
		},
		
		{ category = "General", id = "box", name = "Box", editor = "box", default = false, no_edit = true },
		{ category = "General", id = "locked_slabs_count", name = "Locked Slabs Count", editor = "text", default = "", read_only = true, dont_save = true},
		{ category = "General", id = "wireframe_visible", name = "Wireframe Visible", editor = "bool", default = false,},
		{ category = "General", id = "wall_text_markers_visible", name = "Wall Text ID Visible", editor = "bool", default = false, dont_save = true},
		{ category = "General", id = "dont_use_interior_lighting", name = "No Interior Lighting", editor = "bool", default = false, },
		{ category = "General", id = "seed", name = "Random Seed", editor = "number", default = false},
		{ category = "General", id = "floor", name = "Floor", editor = "number", default = 1, min = -9, max = 99 },
		--bottom left corner of room in world coords
		{ category = "General", id = "position", name = "Position", editor = "point", default = false, no_edit = true, },
		{ category = "General", id = "size", name = "Size", editor = "point", default = point30, no_edit = true, },
		
		{ category = "General", id = "override_terrain_z", editor = "number", default = false, no_edit = true },
		{ category = "General", id = "structure", name = "Structure", editor = "combo", default = "", items = VolumeStructuresList },
		
		{ category = "Roof", id = "room_is_roof", name = "Room is Roof", editor = "bool", default = false, help = "Mark room as roof, roofs are hidden entirely (all walls, floors, etc.) when their floor is touched. Rooms that have zero height are considered roofs by default."},
	},
	
	wireframeColor = RGB(100, 100, 100),
	lines = false,
	
	adjacent_rooms = false, --{ ? }
	
	text_markers = false,
	
	last_wall_recreate_seed = false,
	building = false, --{ [floor] = {room, room, room} }
	
	being_placed = false,
	enable_collision = true, --with other rooms
	
	EditorView = Untranslated("<opt(u(structure),'',' - ')><u(name)>"),
	
	light_vol_obj = false,
	entity = "InvisibleObject",
	editor_force_excluded = true, -- exclude from Map editor palette (causes crash)
}

local voxelSizeX = const.SlabSizeX or 0
local voxelSizeY = const.SlabSizeY or 0
local voxelSizeZ = const.SlabSizeZ or 0
local halfVoxelSizeX = voxelSizeX / 2
local halfVoxelSizeY = voxelSizeY / 2
local halfVoxelSizeZ = voxelSizeZ / 2
local InvalidZ = const.InvalidZ
maxRoomVoxelSizeX = const.MaxRoomVoxelSizeX or 40
maxRoomVoxelSizeY = const.MaxRoomVoxelSizeY or 40
maxRoomVoxelSizeZ = const.MaxRoomVoxelSizeZ or 40
roomQueryRadius = Max((maxRoomVoxelSizeX + 1) * voxelSizeX, (maxRoomVoxelSizeY + 1) * voxelSizeY, (maxRoomVoxelSizeZ + 1) * voxelSizeZ)
defaultVolumeVoxelHeight = 4

local halfVoxelPtZeroZ = point(halfVoxelSizeX, halfVoxelSizeY, 0)
local halfVoxelPt = point(halfVoxelSizeX, halfVoxelSizeY, halfVoxelSizeZ)
function SnapVolumePos(pos)
	return SnapToVoxel(pos) - halfVoxelPtZeroZ
end

function snapZRound(z)
	z = (z + halfVoxelSizeZ) / voxelSizeZ
	return z * voxelSizeZ
end

function snapZCeil(z)
	z = DivCeil(z, voxelSizeZ)
	return z * voxelSizeZ
end

function snapZ(z)
	z = z / voxelSizeZ
	return z * voxelSizeZ
end

function Volume:Getlocked_slabs_count()
	return "N/A"
end

function Volume:GetvolumeCollisionEnabled()
	return VolumeCollisonEnabled
end

function Volume:Setroom_is_roof(val)
	if self.room_is_roof == val then return end
	self.room_is_roof = val
	ComputeSlabVisibilityInBox(self.box)
end

function Volume:IsRoofOnly()
	return self.room_is_roof or self.size:z() == 0
end

function Volume:SetvolumeCollisionEnabled(v)
	VolumeCollisonEnabled = v
end

function Volume:Init()
	--todo: if platform.somethingorother,
	self.text_markers = {
		North = PlaceObject("Text"),
		South = PlaceObject("Text"),
		West = PlaceObject("Text"),
		East = PlaceObject("Text"),
	}
	
	for k, v in pairs(self.text_markers) do
		v.hide_in_editor = false
		v:SetText(k)
		v:SetColor(RGB(255, 0, 0))
		v:SetGameFlags(const.gofDetailClass1)
		v:ClearGameFlags(const.gofDetailClass0)
	end
	
	self:SetPosMarkersVisible(self.wall_text_markers_visible)
	self:CopyBoxToCCD()
	self:InitEntity()
end

function Volume:InitEntity()
	if IsEditorActive() then
		self:ChangeEntity("RoomHelper")
	end
end

function Volume:EditorEnter()
	--dont mess with visibility flags
	self:ChangeEntity("RoomHelper")
end

function Volume:EditorExit()
	--dont mess with visibility flags
	self:ChangeEntity("InvisibleObject")
end

function Volume:Setdont_use_interior_lighting(val)
	self.dont_use_interior_lighting = val
	self:UpdateInteriorLighting()
end

function Volume:CopyBoxToCCD()
	local box = self.box
	if not box then return end
	SetVolumeBox(self, box)
	self:UpdateInteriorLighting()
end

function Volume:UpdateInteriorLighting()
	local box = self.box
	if not box then
		return
	end
	
	if self.dont_use_interior_lighting then
		DoneObject(self.light_vol_obj)
		self.light_vol_obj = nil
		return
	end
	
	local lo = self.light_vol_obj
	if not IsValid(lo) then
		lo = PlaceObject("ComponentLight")
		lo:SetLightType(const.eLightTypeClusterVolume)
		self.light_vol_obj = lo
	end
	
	if not self.dont_use_interior_lighting and self.floor_mat == noneWallMat and self.floor == 1 then
		lo:SetClusterVolumeBox(box:minx(), box:miny(), box:minz() - 100, box:maxx(), box:maxy(), box:maxz()) --this is here so vfx can properly catch ground below rooms
	else
		lo:SetClusterVolumeBox(box:minx(), box:miny(), box:minz(), box:maxx(), box:maxy(), box:maxz())
	end
	lo:SetVolumeId(self.handle)
	lo:SetPos(self:GetPos())
end

function Volume:CalcZ()
	local posZ = self.position:z()
	
	if self.being_placed then
		local z = self.override_terrain_z or terrain.GetHeight(self.position)
		posZ = snapZ(z + voxelSizeZ / 2)
		self.position = self.position:SetZ(posZ)
	end
	
	if posZ == nil then
		--save compat
		local z = self.override_terrain_z or terrain.GetHeight(self.position)
		z = snapZ(z + voxelSizeZ / 2)
		posZ = (rawget(self, "z_offset") or 0) * voxelSizeZ + z + (self.floor - 1) * self.size:z() * voxelSizeZ
		self.position = self.position:SetZ(posZ)
	end

	return posZ
end

function Volume:LockToCurrentTerrainZ()
	self.override_terrain_z = terrain.GetHeight(self.position)
	return self.override_terrain_z
end

function Volume:CalcSnappedZ()
	local z = self:CalcZ()
	z = z / voxelSizeZ
	z = z * voxelSizeZ
	return z
end

function FloorFromZ(z, roomHeight, ground_level)
	return (z - ground_level) / (roomHeight * voxelSizeZ) + 1
end

function ZFromFloor(f, roomHeight, ground_level) --essentialy calcz but makes assumptions about floor size
	return ground_level + (f - 1) * (roomHeight * voxelSizeZ)
end

function Volume:Move(pos)
	--bottom left corner of the voxel at pos will be the new positon
	self.position = SnapVolumePos(pos)
	self:AlignObj()
end

function Volume:ChangeFloor(newFloor)
	if self.floor == newFloor then
		return
	end
	
	self.floor = newFloor
	self:AlignObj()
end

function Volume:SetSize(newSize)
	if self.size == newSize then
		return
	end
	
	self.size = newSize
	self:AlignObj()
end

function Volume:AlignObj(pos, angle)
	if pos then
		local v = pos - self:GetPos()
		self.position = SnapVolumePos(self.position + v)
	end
	self:InternalAlignObj()
end

function Volume:InternalAlignObj(test)
	local w, h, d = self.size:x() * voxelSizeX, self.size:y() * voxelSizeY, self.size:z() * voxelSizeZ
	local cx, cy = w / 2, h / 2
	local z = self:CalcZ()
	local pos = point(self.position:x() + cx, self.position:y() + cy, z)
	local p = self.position
	local newBox = box(p:x(), p:y(), z, p:x() + w, p:y() + h, z + d)
	if not test and self:GetPos() == pos and self.box == newBox then return p end --nothing to align
	self:SetPos(pos)
	self:SetAngle(0)
	self.box = newBox
	if not test then
		self:FinishAlign()
	end
	return p
end

function GetOppositeSide(side)
	if side == "North" then return "South"
	elseif side == "South" then return "North"
	elseif side == "West" then return "East"
	elseif side == "East" then return "West" 
	end
end

local function GetOppositeCorner(c)
	if c == "NW" then return "SE"
	elseif c == "NE" then return "SW"
	elseif c == "SW" then return "NE"
	elseif c == "SE" then return "NW"
	end
end

local function SetAdjacentRoom(adjacent_rooms, room, data)
	if not adjacent_rooms then
		return
	end
	if data then
		if not adjacent_rooms[room] then
			adjacent_rooms[#adjacent_rooms + 1] = room
		end
		adjacent_rooms[room] = data
		return data
	end
	data = adjacent_rooms[room]
	if data then
		adjacent_rooms[room] = nil
		table.remove_value(adjacent_rooms, room)
		return data
	end
end

function Volume:ClearAdjacencyData()
	local adjacent_rooms = self.adjacent_rooms
	self.adjacent_rooms = nil
	
	for _, room in ipairs(adjacent_rooms or empty_table) do
		local hisData = SetAdjacentRoom(room.adjacent_rooms, self, false)
		if hisData then
			local hisAW = hisData[2]
			for i = 1, #(hisAW or empty_table) do
				room:OnAdjacencyChanged(hisAW[i])
			end
		end
	end
end


local AdjacencyEvents = {}
function Volume:RebuildAdjacencyData()
	-- must be called inside an undo op, otherwise delayed updating may cause changes not captured by undo
	assert(XEditorUndo:AssertOpCapture())
	
	local adjacent_rooms = self.adjacent_rooms
	local new_adjacent_rooms = {}
	local mb = self.box
	local events = {}
	--DbgAddBox(mb)
	local is_permanent = self:GetGameFlags(gofPermanent) ~= 0
	local gameFlags = is_permanent and gofPermanent or nil
	MapForEach(self, roomQueryRadius, self.class, nil, nil, gameFlags, function(o, mb, is_permanent)
		if o == self or not is_permanent and o:GetGameFlags(gofPermanent) ~= 0 then
			return
		end
		
		--TODO: use +roof box for sides, -roof box for ceiling/floor
		local hb = o.box
		--DbgAddBox(hb, RGB(0, 255, 0))
		local ib = IntersectRects(hb, mb)
		--DbgAddBox(ib, RGB(255, 0, 0))
		if not ib:IsValid() then
			return
		end
		local myData = adjacent_rooms and adjacent_rooms[o]
		local oldIb = myData and myData[1]
		
		local myNewData = {}
		local hisData = o.adjacent_rooms and o.adjacent_rooms[self]
		local hisNewData = {}
		
		--restore previously affected walls
		local myaw = myData and myData[2]
		local hisaw = hisData and hisData[2]
		for i = 1, #(myaw or empty_table) do
			table.insert(events, {self, myaw[i]})
		end
		for i = 1, #(hisaw or empty_table) do
			table.insert(events, {o, hisaw[i]})
		end
		
		hisNewData[1] = ib
		myNewData[1] = ib
		hisNewData[2] = {}
		myNewData[2] = {}
		
		if ib:sizez() > 0 then
			if ib:minx() == ib:maxx() and ib:miny() == ib:maxy() then
				--corner adj, rebuild corner
				local p = ib:min()
				if p:x() == mb:minx() then --west
					if p:y() == mb:miny() then --north
						table.insert(events, {self, "NW"})
						table.insert(hisNewData[2], "SE")
						table.insert(myNewData[2], "NW")
					else
						table.insert(events, {self, "SW"})
						table.insert(hisNewData[2], "NE")
						table.insert(myNewData[2], "SW")
					end
				else --east
					if p:y() == mb:miny() then
						table.insert(events, {self, "NE"})
						table.insert(hisNewData[2], "SW")
						table.insert(myNewData[2], "NE")
					else
						table.insert(events, {self, "SE"})
						table.insert(hisNewData[2], "NW")
						table.insert(myNewData[2], "SE")
					end
				end
			elseif ib:minx() == ib:maxx()
					and ib:miny() ~= ib:maxy() then
				--east/west adjacency
				if mb:maxx() == ib:maxx() then
					--my east, his west
					table.insert(events, {self, "East"})
					table.insert(events, {o, "West"})
					table.insert(hisNewData[2], "West")
					table.insert(myNewData[2], "East")
				else
					--my west, his east
					table.insert(events, {self, "West"})
					table.insert(events, {o, "East"})
					table.insert(hisNewData[2], "East")
					table.insert(myNewData[2], "West")
				end
			elseif ib:minx() ~= ib:maxx()
					and ib:miny() == ib:maxy() then
				--nort/south adjacency
				if mb:maxy() == ib:maxy() then
					--my north, his south
					table.insert(events, {self, "South"})
					table.insert(events, {o, "North"})
					table.insert(hisNewData[2], "North")
					table.insert(myNewData[2], "South")
				else
					--my south, his north
					table.insert(events, {self, "North"})
					table.insert(events, {o, "South"})
					table.insert(hisNewData[2], "South")
					table.insert(myNewData[2], "North")
				end
			else
				--rooms intersect
				if (ib:maxx() == mb:maxx() or ib:minx() == mb:maxx())
						and mb:maxx() == hb:maxx() then
					--east
					table.insert(events, {self, "East"})
					table.insert(myNewData[2], "East")
					table.insert(hisNewData[2], "East")
				end
				
				if (ib:minx() == mb:minx() or ib:maxx() == mb:minx())
					and mb:minx() == hb:minx() then
					--west
					table.insert(events, {self, "West"})
					table.insert(myNewData[2], "West")
					table.insert(hisNewData[2], "West")
				end
				
				if (ib:maxy() == mb:maxy() or ib:miny() == mb:maxy())
					and mb:maxy() == hb:maxy() then
					--south
					table.insert(events, {self, "South"})
					table.insert(myNewData[2], "South")
					table.insert(hisNewData[2], "South")
				end
				
				if ib:maxy() == mb:miny() or ib:miny() == mb:miny() 
					and mb:miny() == hb:miny() then
					--north
					table.insert(events, {self, "North"})
					table.insert(myNewData[2], "North")
					table.insert(hisNewData[2], "North")
				end
			end
		end
		
		
		if ib:sizex() > 0 and ib:sizey() > 0 then
			if (mb:minz() >= ib:minz() and  mb:minz() <= ib:maxz()) or
				(hb:maxz() >= ib:minz() and hb:maxz() <= ib:maxz()) then
				--floor
				table.insert(events, {self, "Floor"})
				table.insert(myNewData[2], "Floor")
				table.insert(hisNewData[2], "Roof")
			end
			
			if (mb:maxz() <= ib:maxz() and mb:maxz() >= ib:minz()) or
				(hb:minz() <= ib:maxz() and hb:minz() >= ib:minz()) then
				--roof
				table.insert(events, {self, "Roof"})
				table.insert(myNewData[2], "Roof")
				table.insert(hisNewData[2], "Floor")
			end
		end
		
		SetAdjacentRoom(o.adjacent_rooms, self, #hisNewData[2] > 0 and hisNewData)
		SetAdjacentRoom(new_adjacent_rooms, o, #myNewData[2] > 0 and myNewData)
	end, mb, is_permanent)
	
	for _, room in ipairs(adjacent_rooms or empty_table) do
		if not new_adjacent_rooms[room] then
			--adjacency removed
			local data = adjacent_rooms[room]
			local myaw = data[2]
			local hisData = SetAdjacentRoom(room.adjacent_rooms, self, false)
			local hisaw = hisData and hisData[2]
			for i = 1, #(myaw or empty_table) do
				table.insert(events, {self, myaw[i]})
			end
			for i = 1, #(hisaw or empty_table) do
				table.insert(events, {room, hisaw[i]})
			end
		end
	end
	
	self.adjacent_rooms = new_adjacent_rooms
	
	if IsChangingMap() or XEditorUndo.undoredo_in_progress then
		return
	end
	
	if #(events or empty_table) > 0 then
		table.insert(AdjacencyEvents, events)
		Wakeup(PeriodicRepeatThreads["AdjacencyEvents"])
	end
end

function ProcessVolumeAdjacencyEvents()
	local passed = {}
	for i = 1, #AdjacencyEvents do
		local events = AdjacencyEvents[i]
		for i = 1, #(events or empty_table) do
			local ev = events[i]
			local o = ev[1]
			local s = ev[2]
			if IsValid(o) and (not passed[o] or (passed[o] and not passed[o][s])) then
				passed[o] = passed[o] or {}
				passed[o][s] = true
				--print(o.name, s)
				o:OnAdjacencyChanged(s)
			end
		end
	end
	table.clear(AdjacencyEvents)
end

-- make sure all changes to rooms are completed before we finish capturing undo data
OnMsg.EditorObjectOperationEnding = ProcessVolumeAdjacencyEvents

MapGameTimeRepeat("AdjacencyEvents", -1, function(sleep)
	PauseInfiniteLoopDetection("AdjacencyEvents")
	ProcessVolumeAdjacencyEvents()
	ResumeInfiniteLoopDetection("AdjacencyEvents")
	WaitWakeup()
end)

local dirToWallMatMember = {
	North = "north_wall_mat",
	South = "south_wall_mat",
	West = "west_wall_mat",
	East = "east_wall_mat",
	Floor = "floor_mat",
}

local sideToFuncName = {
	NW = "RecreateNWCornerBeam",
	NE = "RecreateNECornerBeam",
	SW = "RecreateSWCornerBeam",
	SE = "RecreateSECornerBeam",
}

function Volume:CheckWallSizes()
	if not Platform.developer then return end
	local t = self.spawned_walls
	assert(#t.West == #t.East)
	assert(#t.North == #t.South)
end

function Volume:OnAdjacencyChanged(side)
	if #side == 2 then
		self[sideToFuncName[side]](self)
	elseif side == "Floor" then
		self:CreateFloor(self.floor_mat)
	elseif side == "Roof" then
		if not self.being_placed then
			self:UpdateRoofSlabVisibility()
		end
	else
		self:CreateWalls(side, self[dirToWallMatMember[side]])
		self:CheckWallSizes()
	end
	
	self:DelayedRecalcRoof()
end

if FirstLoad then
	SelectedRooms = false
	RoomSelectionMode = false
end

function SetRoomSelectionMode(bVal)
	RoomSelectionMode = bVal
	print(string.format("RoomSelectionMode is %s", RoomSelectionMode and "ON" or "OFF"))
end

function ToggleRoomSelectionMode()
	SetRoomSelectionMode(not RoomSelectionMode)
end

if FirstLoad then
	roomsToDeselect = false
end

local function selectRoomHelper(r, t)
	t = t or SelectedRooms
	t = t or {}
	r:SetPosMarkersVisible(true)
	table.insert(t, r)
	if roomsToDeselect then
		table.remove_entry(roomsToDeselect, r)
	end
end

local function deselectRoomHelper(r)
	if IsValid(r) then
		r:SetPosMarkersVisible(false)
		r:ClearSelectedWall()
	end
end

local function deselectRooms()
	for i = 1, #(roomsToDeselect or "") do
		deselectRoomHelper(roomsToDeselect[i])
	end
	roomsToDeselect = false
end

function OnMsg.EditorSelectionChanged(objects)
	--room selection
	if RoomSelectionMode then
		--if 1 slab is selected?
		local o = #objects == 1 and objects[1]
		if o and IsKindOf(o, "Slab") and IsValid(o.room) then
			editor.ClearSel()
			editor.AddToSel({o.room})
			return --don't do further analysis this pass
		end
	end
	--selected rooms
	local newSelectedRooms = {}
	
	for i = 1, #objects do
		local o = objects[i]
		if IsKindOf(o, "Slab") then
			local r = o.room
			if IsValid(r) then
				selectRoomHelper(r, newSelectedRooms)
			end
		elseif IsKindOf(o, "Room") then
			selectRoomHelper(o, newSelectedRooms)
		end
	end
	
	for i = 1, #(SelectedRooms or "") do
		local r = SelectedRooms[i]
		if not table.find(newSelectedRooms, r) then
			--deselect
			roomsToDeselect = roomsToDeselect or {}
			table.insert(roomsToDeselect, r)
			DelayedCall(0, deselectRooms)
		end
	end
	
	SelectedRooms = #newSelectedRooms > 0 and newSelectedRooms or false
end

function Volume:TogglePosMarkersVisible()
	local el = self.text_markers.North
	self:SetPosMarkersVisible(el:GetEnumFlags(const.efVisible) == 0)
end

function Volume:SetPosMarkersVisible(val)
	for k, v in pairs(self.text_markers) do
		if not val then
			v:ClearEnumFlags(const.efVisible)
		else
			v:SetEnumFlags(const.efVisible)
		end
	end
end

function Volume:PositionWallTextMarkers()
	local t = self.text_markers
	local gz = self:CalcZ() + self.size:z() * voxelSizeZ / 2
	local p = self.position + point(self.size:x() * voxelSizeX / 2, 0)
	p = p:SetZ(gz)
	t.North:SetPos(p)
	p = self.position + point(self.size:x() * voxelSizeX / 2, self.size:y() * voxelSizeY)
	p = p:SetZ(gz)
	t.South:SetPos(p)
	p = self.position + point(0, self.size:y() * voxelSizeY / 2)
	p = p:SetZ(gz)
	t.West:SetPos(p)
	p = self.position + point(self.size:x() * voxelSizeX, self.size:y() * voxelSizeY / 2)
	p = p:SetZ(gz)
	t.East:SetPos(p)
end

function Volume:FinishAlign()
	if not self.seed then
		self.seed = EncodeVoxelPos(self)
	end
	
	self:CopyBoxToCCD()
	self:RebuildAdjacencyData()
	if self.wireframe_visible then
		self:GenerateGeometry()
	else
		self:DoneLines()
	end
	self:PositionWallTextMarkers()
	self.box_at_last_roof_edit = self.box
	
	if not IsChangingMap() then
		self:RefreshFloorCombatStatus()
	end
	
	Msg("RoomAligned", self)
end

function Volume:RefreshFloorCombatStatus()
end

function Volume:Setfloor(v)
	self.floor = v
	self:RefreshFloorCombatStatus()
end

function Volume:VolumeDestructor()
	self:DoneLines()
	DoneObject(self.light_vol_obj)
	DoneObjects(self.light_vol_objs)
	self.light_vol_obj = nil
	self.light_vol_objs = nil
	for k, v in pairs(self.text_markers) do
		DoneObject(v)
	end
	self["VolumeDestructor"] = empty_func
end

function Volume:Done()
	self:VolumeDestructor()
end

function Volume.ToggleVolumeCollision(_, self)
	VolumeCollisonEnabled = not VolumeCollisonEnabled
end

function Volume:CheckCollision(cls, box)
	if not VolumeCollisonEnabled then return false end
	if not self.enable_collision then return false end
	cls = cls or self.class
	local ret = false
	box = box or self.box
	MapForEach(self:GetPos(), roomQueryRadius, cls, function(o)
		if o ~= self and o.enable_collision then
			if box:Intersect(o.box) ~= 0 then
				ret = true
				return "break"
			end
		end
	end, box)
	
	return ret
end

local dontCopyTheeseProps = {
	name = true,
	floor = true,
	adjacent_rooms = true,
	box = true,
	position = true,
	roof_objs = true,
	spawned_doors = true,
	spawned_windows = true,
	spawned_decals = true,
	spawned_walls = true,
	spawned_corners = true,
	spawned_floors = true,
	text_markers = true,
}

function Volume:RecreateAllWallsOnMap()
	MapForEach("map", "Volume", Volume.RecreateWalls)
end

function Volume:RecreateAllRoofsOnMap()
	local all_volumes = MapGet("map", "Volume")
	table.sortby_field(all_volumes, "floor")
	for i,volume in ipairs(all_volumes) do
		volume:RecreateRoof()
	end
end

function Volume:RecreateAllFloorsOnMap()
	MapForEach("map", "Volume", Volume.RecreateFloor)
end

function Volume:RecreateWalls()
	SuspendPassEdits("Volume:RecreateWalls")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:CreateAllWalls()
	self:CreateAllCorners()
	self:OnSetouter_colors(self.outer_colors)
	self:OnSetinner_colors(self.inner_colors)
	ResumePassEdits("Volume:RecreateWalls")
end

function Volume:RecreateFloor()
	SuspendPassEdits("Volume:RecreateFloor")
	self:DeleteAllFloors()
	self:CreateFloor()
	self:OnSetfloor_colors(self.floor_colors)
	ResumePassEdits("Volume:RecreateFloor")
end

function Volume:RecreateRoofBtn()
	self:RecreateRoof()
end

function Volume:ReRandomize()
	self.last_wall_recreate_seed = self.seed
	self.seed = BraidRandom(self.seed)
	self:CreateAllWalls()
	self.last_wall_recreate_seed = self.seed
	ObjModified(self)
end

function Volume:CopyAbove()
	XEditorUndo:BeginOp()
	local nv = self:Copy(1)
	SetSelectedVolume(nv)
	XEditorUndo:EndOp{ nv }
end

function Volume:CopyBelow()
	XEditorUndo:BeginOp()
	local nv = self:Copy(-1)
	SetSelectedVolume(nv)
	XEditorUndo:EndOp{ nv }
end

function Volume:CollisionCheckNextFloor(floorOffset)
	if not VolumeCollisonEnabled then return false end
	if not self.enable_collision then return false end
	local b = self.box
	local offset = point(0, 0, voxelSizeZ * self.size:z() * floorOffset)
	b = Offset(b, offset)
	local collision = false	
	MapForEach(self:GetPos(), roomQueryRadius, self.class, function(o)
		if o ~= self and o.enable_collision then
			if b:Intersect(o.box) ~= 0 then
				collision = true
				return "break"
			end
		end
	end)
	return collision
end

function Volume:Copy(floorOffset, inputObj, skipCollisionTest)
	local offset = point(0, 0, voxelSizeZ * self.size:z() * floorOffset)
	local collision = false
	if not skipCollisionTest then
		collision = self:CollisionCheckNextFloor(floorOffset)
	end
	
	if skipCollisionTest or not collision then
		inputObj = inputObj or {}
		inputObj.floor = inputObj.floor or self.floor + floorOffset
		inputObj.position = inputObj.position or self.position + offset
		inputObj.size = inputObj.size or self.size
		inputObj.name = inputObj.name or self.name .. " Copy"
		local doNotCopyTheseEither = table.copy(inputObj)
		
		local cpy = PlaceObject(self.class, inputObj)
		local prps = self:GetProperties()
		for i = 1, #prps do
			local prop = prps[i]
			if not dontCopyTheeseProps[prop.id] and not doNotCopyTheseEither[prop.id] then
				cpy:SetProperty(prop.id, self:GetProperty(prop.id))
			end
		end
		cpy:OnCopied(self, offset)
		DelayedCall(500, BuildBuildingsData)
		return cpy
	end
end

function Volume:OnCopied(from)
	self:AlignObj()
end

function Volume:ToggleGeometryVisible()
	if self.lines == false then
		self:GenerateGeometry()
		return
	end
	if self.lines and self.lines[1] then
		local visible = self.lines[1]:GetEnumFlags(const.efVisible) == 0
		for i = 1, #(self.lines or empty_table) do
			if visible then
				self.lines[i]:SetEnumFlags(const.efVisible)
			else
				self.lines[i]:ClearEnumFlags(const.efVisible)
			end
		end
	end
end

function Volume:DoneLines()
	DoneObjects(self.lines)
	self.lines = false
end

function Volume:GetWallBox(side, roomBox)
	local ret = false
	local b = roomBox or self.box
	if side == "North" then
		ret = box(b:minx(), b:miny(), b:minz(), b:maxx(), b:miny() + 1, b:maxz())
	elseif side == "South" then
		ret = box(b:minx(), b:maxy() - 1, b:minz(), b:maxx(), b:maxy(), b:maxz())
	elseif side == "East" then
		ret = box(b:maxx() - 1, b:miny(), b:minz(), b:maxx(), b:maxy(), b:maxz())
	elseif side == "West" then
		ret = box(b:minx(), b:miny(), b:minz(), b:minx() + 1, b:maxy(), b:maxz())
	end
	
	return ret
end

local function SetLineMesh(line, line_pstr)
	if not line_pstr or line_pstr:size() == 0 then return end
	line:SetMesh(line_pstr)
	return line
end

local offsetFromVoxelEdge = 20
function Volume:GenerateGeometry()
	self:DoneLines()
	
	local lines = {}
	local xPoints = {}
	local xPointsRoof = {}
	local yPoints = {}
	local yPointsRoof = {}
	
	local zOrigin = self:CalcSnappedZ()
	local p = self.position
	local x, y = p:xyz()
	local sx = abs(self.size:x())
	local sy = abs(self.size:y())
	local sz = abs(self.size:z())
	
	for inX = 0, sx - 1 do
		for inY = 0, sy - 1 do
			xPoints[inY] = xPoints[inY] or pstr("")
			yPoints[inX] = yPoints[inX] or pstr("")
			
			xPointsRoof[inY] = xPointsRoof[inY] or pstr("")
			yPointsRoof[inX] = yPointsRoof[inX] or pstr("")
			
			local xx, yy, zz, ox, oy, oz
			
			xx = x + inX * voxelSizeX + halfVoxelSizeX
			if inX == 0 then
				ox = xx - halfVoxelSizeX + offsetFromVoxelEdge
			elseif inX == sx - 1 then
				ox = xx + halfVoxelSizeX - offsetFromVoxelEdge
			else
				ox = xx
			end
			
			yy = y + inY * voxelSizeY + halfVoxelSizeY
			if inY == 0 then
				oy = yy - halfVoxelSizeY + offsetFromVoxelEdge
			elseif inY == sy - 1 then
				oy = yy + halfVoxelSizeY - offsetFromVoxelEdge
			else
				oy = yy
			end
			
			zz = zOrigin + offsetFromVoxelEdge
			oz = zz + sz * voxelSizeZ - offsetFromVoxelEdge*2
			
			if inX == 0 then
				--wall
				xPoints[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			end
			xPoints[inY]:AppendVertex(ox, yy, zz, self.wireframeColor)
			if sx == 1 then
				xPointsRoof[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
				ox = xx + halfVoxelSizeX - offsetFromVoxelEdge
				xPoints[inY]:AppendVertex(ox, yy, zz, self.wireframeColor)
			end
			if inX == sx - 1 then
				--wall
				xPoints[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			end
			
			if inY == 0 then
				--wall
				yPoints[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
			end
			yPoints[inX]:AppendVertex(xx, oy, zz, self.wireframeColor)
			if sy == 1 then
				yPointsRoof[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
				oy = yy + halfVoxelSizeY - offsetFromVoxelEdge
				yPoints[inX]:AppendVertex(xx, oy, zz, self.wireframeColor)
			end
			if inY == sy - 1 then
				--wall
				yPoints[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
			end
			
			xPointsRoof[inY]:AppendVertex(ox, yy, oz, self.wireframeColor)
			yPointsRoof[inX]:AppendVertex(xx, oy, oz, self.wireframeColor)
		end
	end
	
	local visible = self.wireframe_visible
	local function SetVisibilityHelper(line)
		if not visible then
			line:ClearEnumFlags(const.efVisible)
		end
	end
	
	for inX = 0, sx - 1 do
		local line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, yPoints[inX])
		table.insert(lines, line)
		self:Attach(line)
		line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, yPointsRoof[inX])
		table.insert(lines, line)
		self:Attach(line)
	end
	
	for inY = 0, sy - 1 do
		local line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, xPoints[inY])
		table.insert(lines, line)
		self:Attach(line)
		line = PlaceObject("Polyline")
		SetVisibilityHelper(line)
		line:SetPos(p)
		SetLineMesh(line, xPointsRoof[inY])
		table.insert(lines, line)
		self:Attach(line)
	end
	
	self.lines = lines
end

function Volume:GetBiggestEncompassingRoom(func, ...)
	--this presumes no wall crossing
	local biggestRoom = self
	if self.box then
		local sizex, sizey = self.box:sizexyz()
		local biggestRoomSize = sizex + sizey
		EnumVolumes(self.box, function(o, ...)
			local szx, szy = o.box:sizexyz()
			local size = szx + szy
			if size > biggestRoomSize then
				if not func or func(o, ...) then
					biggestRoom = o
					biggestRoomSize = size
				end
			end
		end, ...)
	end
	return biggestRoom
end

local function MakeSlabInvulnerable(o, val)
	o.forceInvulnerableBecauseOfGameRules = val
	o.invulnerable = val
	SetupObjInvulnerabilityColorMarkingOnValueChanged(o)
end

function Volume:MakeOwnedSlabsInvulnerable()
	self:ForEachSpawnedObj(function(o)
		MakeSlabInvulnerable(o, true)
		if IsKindOf(o, "SlabWallObject") then
			local os = o.owned_slabs
			if os then
				for _, oo in ipairs(os) do
					MakeSlabInvulnerable(oo, true)
				end
			end
		end
	end)
end

function Volume:MakeOwnedSlabsVulnerable()
	local floorsInvul = self.floor == 1
	self:ForEachSpawnedObj(function(o)
		if not floorsInvul or not IsKindOf(o, "FloorSlab") then
			MakeSlabInvulnerable(o, false)
			if IsKindOf(o, "SlabWallObject") then
				local os = o.owned_slabs
				if os then
					for _, oo in ipairs(os) do
						MakeSlabInvulnerable(oo, false)
					end
				end
			end
		end
	end)
end

function Volume:Destroy()
	--so shift + d in f3 doesn't kill these
end

function ShowVolumes(bShow, volume_class, max_floor, fn)
	MapClearEnumFlags(const.efVisible, "map", "Volume")
	if not bShow or not volume_class then return end
	MapSetEnumFlags(const.efVisible, "map", volume_class, function(volume, max_floor, fn)
		if volume.floor <= max_floor then
			fn(volume)
			return true
		end
	end, max_floor or max_int, fn or empty_func)
end

function SelectVolume(pt) -- in screen coordinates, terminal.GetMousePos()
	-- enumerate all visible volumes on the map and select the one under the mouse point pt
	local start = ScreenToGame(pt)
	local pos = cameraRTS.GetPos()
	local dir = start - pos
	dir = dir * 1000
	local dir2 = start + dir
	local camFloor = cameraTac.GetFloor() + 1

	--DbgAddCircle(start, 100)
	--DbgAddVector(start, pos - start)  
	--DbgAddVector(start, dir*1000, RGB(0, 255, 0))

	return MapFindMin("map", "Volume", nil, nil, nil, nil, nil, nil, function(volume, dir2, camFloor)
		if HideFloorsAboveThisOne then
			if volume.floor > HideFloorsAboveThisOne then
				return false
			end
		end
		--return distance to intersection between the camera ray and volume box
		local p1, p2 = ClipSegmentWithBox3D(start, dir2, volume.box)
		if p1 then
			--DbgAddCircle(p1, 100)
			--DbgAddCircle(p2, 100, RGB(0, 0, 255))
			return p1:Dist2(start)
		end
		
		return false
	end, start, dir2, camFloor) or false, start, dir2
end

local lastSelectedVolume = false
local function SetSelectedVolumeAndFireEvents(vol)
	if vol ~= SelectedVolume then
		local oldVolume = SelectedVolume
		SelectedVolume = vol
		if oldVolume then
			lastSelectedVolume = oldVolume
			if IsValid(oldVolume) then
				oldVolume.wall_text_markers_visible = false
				oldVolume:SetPosMarkersVisible(false)
			end
			Msg("VolumeDeselected", oldVolume)
		end
		if SelectedVolume then
			if SelectedVolume ~= lastSelectedVolume then --only deselect wall if another vol is selected
				SelectedVolume.selected_wall = false
				ObjModified(SelectedVolume)
			end
			
			SelectedVolume.wall_text_markers_visible = true
			SelectedVolume:SetPosMarkersVisible(true)
			editor.ClearSel()
		end
		Msg("VolumeSelected", SelectedVolume)
	end
end

function SetSelectedVolume(vol)
	SetSelectedVolumeAndFireEvents(vol)
	if GedRoomEditor then
		GedRoomEditorObjList = GedRoomEditor:ResolveObj("root")
		CreateRealTimeThread(function()
			GedRoomEditor:SetSelection("root", table.find(GedRoomEditorObjList, SelectedVolume))
		end)
	end
end

local doorId = "Door"
local windowId = "Window"
local doorTemplate = "%s_%s"
local Doors_WidthNames = { "Single", "Double" }
local Windows_WidthNames = { "Single", "Double", "Triple" }

function DoorsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		
		for j = 1, #Doors_WidthNames do
			local name = string.format(doorTemplate, doorId, Doors_WidthNames[j])
			local data = {mat = false, width = j, height = 3}
			table.insert(ret, {name = name, id = data})
		end
		
		return ret
	end
end

function WindowsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		
		for j = 1, #Windows_WidthNames do
			local name = string.format(doorTemplate, windowId, Windows_WidthNames[j])
			local data = {mat = false, width = j, height = 2}
			table.insert(ret, {name = name, id = data})
		end
		
		return ret
	end
end

function GetDecalPresetData()
	return Presets.RoomDecalData.Default
end

function DecalsDropdown()
	return function()
		local ret = { {name = "", id = ""} }
		local presetData = GetDecalPresetData()
		for _, entry in ipairs(presetData) do
			local data = { entity = entry.id, }
			table.insert(ret, {name = entry.id, id = data})
		end
		return ret
	end
end

local function GetAllWindowEntitiesForMaterial(obj)
	local material = type(obj) == "string" and obj or obj.linked_obj and obj.linked_obj.material or obj.material
	local ret = { false }
	for w = 0, 3 do
		for h = 1, 3 do
			for v = 1, 10 do
				local e = SlabWallObjectName(material, h, w, v, false)
				if IsValidEntity(e) then
					ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
				end
			end
		end
	end
	
	return ret
end

local function GetAllDoorEntitiesForMaterial(obj)
	local material = type(obj) == "string" and obj or obj.linked_obj and obj.linked_obj.material or obj.material
	local ret = { false }
	for w = 1, 3 do
		for h = 3, 4 do
			for v = 1, 10 do
				local e = SlabWallObjectName(material, h, w, v, true)
				if IsValidEntity(e) then
					ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
				end
				
				if v == 1 then
					e = SlabWallObjectName(material, h, w, nil, true)
					if IsValidEntity(e) then
						ret[#ret + 1] = { name = e, value = {entity = e, height = h, width = w, subvariant = v, material = material} }
					end
				end
			end
		end
	end
	
	return ret
end

local function SelectedWallNoEdit(self)
	return self.selected_wall == false
end

slabDirToAngle = {
	North = 270 * 60,
	South = 90 * 60,
	West = 180 * 60,
	East = 0,
}

slabAngleToDir = {
	[270 * 60] = "North",
	[90 * 60] = "South",
	[180 * 60] = "West",
	[0] = "East",
}

slabCornerAngleToDir = {
	[270 * 60] = "East",
	[90 * 60] = "West",
	[180 * 60] = "North",
	[0] = "South",
}

function _RoomVisibilityCategoryNoEdit()
	return RoomVisibilityCategoryNoEdit()
end

function RoomVisibilityCategoryNoEdit()
	return true
end

local VisibilityStateItems = {
	"Closed",
	"Hidden",
	"Open"
}

function SlabMaterialComboItemsWithNone()
	return PresetGroupCombo("SlabPreset", "SlabMaterials", nil, noneWallMat)
end

function SlabMaterialComboItemsOnly()
	return function()
		local f1 = SlabMaterialComboItemsWithNone()
		local ret = f1()
		table.remove(ret, 1)
		return ret
	end
end

function SlabMaterialComboItemsWithDefault()
	return function() 
		local f1 = SlabMaterialComboItemsWithNone()
		local ret = f1()
		table.insert(ret, 2, defaultWallMat)
		return ret
	end
end

DefineClass.Room = {
	__parents = { "Volume", "EditorSubVariantObject" },
	flags = { gofWarped = true },
	
	properties = {
		{ category = "General", name = "Doors And Windows Are Blocked", id = "doors_windows_blocked", editor = "bool", default = false, },
		{ category = "General", id = "name", name = "Name", editor = "text", default = false, help = "Default 'Room <handle>', renameable." },
		
		{ category = "General", id = "size_z", name = "Height (z)", editor = "number", default = defaultVolumeVoxelHeight, min = 0, max = maxRoomVoxelSizeZ, dont_save = true},
		{ category = "General", id = "size_x", name = "Width (x)", editor = "number", default = 1, min = 1, max = maxRoomVoxelSizeX, dont_save = true},
		{ category = "General", id = "size_y", name = "Depth (y)", editor = "number", default = 1, min = 1, max = maxRoomVoxelSizeY, dont_save = true},
		{ category = "General", id = "move_x", name = "Move EW (x)", editor = "number", default = 0, dont_save = true},
		{ category = "General", id = "move_y", name = "Move NS (y)", editor = "number", default = 0, dont_save = true},
		{ category = "General", id = "move_z", name = "Move UD (z)", editor = "number", default = 0, dont_save = true},
		--materials
		{ category = "Materials", id = "wall_mat", name = "Wall Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "SlabMaterials", extra_item = noneWallMat, default = "Planks",
			buttons = {
				{name = "Reset", func = "ResetWallMaterials"}, 
			},
		},
		{ category = "Materials", id = "outer_colors", name = "Outer Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "inner_wall_mat", name = "Inner Wall Material", editor = "preset_id", preset_class = "SlabIndoorMaterials", extra_item = noneWallMat, default = "Planks", },
		
		{ category = "Materials", id = "inner_colors", name = "Inner Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "north_wall_mat", name = "North Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat,
			buttons = { 
				{name = "Select", func = "ViewNorthWallFromOutside"},
			}
		},		
		{ category = "Materials", id = "south_wall_mat", name = "South Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat, 
			buttons = { 
				{name =  "Select", func = "ViewSouthWallFromOutside"},
			} 
		},
		{ category = "Materials", id = "east_wall_mat", name = "East Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat, 
			buttons = { 
				{name =  "Select", func = "ViewEastWallFromOutside"},
			}
		},
		{ category = "Materials", id = "west_wall_mat", name = "West Wall Material", editor = "dropdownlist", items = SlabMaterialComboItemsWithDefault, default = defaultWallMat,
			buttons = { 
				{name =  "Select", func = "ViewWestWallFromOutside"},
			}
		},
		{ category = "Materials", id = "floor_mat", name = "Floor Material", editor = "preset_id", preset_class = "SlabPreset", preset_group = "FloorSlabMaterials", extra_item = noneWallMat, default = "Planks", },
		{ category = "Materials", id = "floor_colors", name = "Floor Color Modifier", editor = "nested_obj", base_class = "ColorizationPropSet", inclusive = true, default = false, },
		{ category = "Materials", id = "Warped", name = "Warped", editor = "bool", default = true },
		
		{ category = "Materials", id = "selected_wall_buttons", name = "selected wall buttons", editor = "buttons", default = false, dont_save = true, read_only = true,
			no_edit = SelectedWallNoEdit,
			buttons = {
				{name = "Clear Wall Selection", func = "ClearSelectedWall"},
				{name = "Delete Doors", func = "UIDeleteDoors"},
				{name = "Delete Windows", func = "UIDeleteWindows"},
			},
		},
		
		{ category = "Materials", id = "place_decal", name = "Place Decal", editor = "choice", items = DecalsDropdown, default = "", no_edit = SelectedWallNoEdit,},
		
		{ category = "General", id = "spawned_doors", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_windows", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_decals", editor = "objects", no_edit = true,}, --todo: kill
		
		{ category = "General", id = "spawned_floors", editor = "objects", no_edit = true},
		{ category = "General", id = "spawned_walls", editor = "objects", no_edit = true,},
		{ category = "General", id = "spawned_corners", editor = "objects", no_edit = true,},
		
		{ category = "Not Room Specific", id = "hide_floors_editor", editor = "number", default = 100, name = "Hide Floors Above", dont_save = true},
		
		--bacon specific?
		{ category = "Visibility", name = "Visibility State", id = "visibility_state", editor = "choice", items = VisibilityStateItems, dont_save = true, no_edit = _RoomVisibilityCategoryNoEdit },
		{ category = "Visibility", name = "Focused", id = "is_focused", editor = "bool", default = false, dont_save = true, no_edit = _RoomVisibilityCategoryNoEdit },
		
		{ category = "Ignore None Material", name = "Wall", id = "none_wall_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "By default, setting a wall material to none will hide overlapping walls, tick this for it to stop happening. Affects all walls of a room." },
		{ category = "Ignore None Material", name = "Roof Wall", id = "none_roof_wall_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "Same as walls (see above), but for walls that are part of the roof - roof walls." },
		{ category = "Ignore None Material", name = "Floor", id = "none_floor_mat_does_not_affect_nbrs", editor = "bool", default = false, help = "By default, setting a floor material to none will hide overlapping floors, tick this for it to stop happening. Affects all floors of a room." },
	},
	
	auto_add_in_editor = true, -- for Room editor
	
	spawned_walls = false, -- {["North"] = {}, etc.}
	spawned_corners = false,
	spawned_floors = false,
	spawned_doors = false,
	spawned_windows = false,
	spawned_decals = false,
	
	selected_wall = false, -- false, "North", "South", etc.
	
	next_visibility_state = false,
	visibility_state = false, -- when defined purely as a prop, something strips it.
	open_state_collapsed_walls = false,
	outside_border = false,
	nametag = false,
}

local function moveHelper(self, key, old_v, x, y, z, ignore_collision)
	if IsChangingMap() then return end
	self:InternalAlignObj(true) -- this moves box
	if not ignore_collision and self:CheckCollision() then
		self[key] = old_v
		self:InternalAlignObj(true)
		print("Could not move room due to collision with other room!")
		return false
	else
		self:MoveAllSpawnedObjs(x, y, z)
		Volume.FinishAlign(self)
		Msg("RoomMoved", self, x, y, z) -- x, y, z - move delta in voxels
		return true
	end
end

function sign(v)
	return v ~= 0 and abs(v) / v or 0
end

function moveHelperHelper(r, delta)
	local old = r.position
	delta = delta + halfVoxelPt
	r.position = SnapVolumePos(old + delta)
	return moveHelper(r, "position", old, delta:x() / voxelSizeX, delta:y() / voxelSizeY, delta:z() / voxelSizeZ)
end

function Room:EditorExit()
	if IsValid(self.nametag) then
		self.nametag:ClearEnumFlags(const.efVisible)
	end
end

function Room:EditorEnter()
	if IsValid(self.nametag) and self:GetEnumFlags(const.efVisible) ~= 0 then
		self.nametag:SetEnumFlags(const.efVisible)
	end
end

function Room:Setname(n)
	self.name = n
	if not IsValid(self.nametag) then
		self.nametag = PlaceObject("TextEditor")
		self:Attach(self.nametag)
		self.nametag:SetAttachOffset((axis_z * 3 * voxelSizeZ) / 4096)
		
		if not IsEditorActive() or self:GetEnumFlags(const.efVisible) == 0 then
			self.nametag:ClearEnumFlags(const.efVisible)
		end
	end
	self.nametag:SetText(self.name)
end

local movedRooms = false
function Room_RecalcRoofsOfMovedRooms()
	if not movedRooms then return end
	for i = 1, #movedRooms do
		local room = movedRooms[i]
		if IsValid(room) then
			room:RecalcRoof()
			room:UpdateRoofVfxControllers()
		end
	end
	movedRooms = false
end

function Room:DelayedRecalcRoof()
	movedRooms = table.create_add_unique(movedRooms, self)
	if LocalStorage.FilteredCategories["Roofs"] and not XEditorUndo.undoredo_in_progress then
		DelayedCall(200, Room_RecalcRoofsOfMovedRooms)
	end
end

-- make sure all changes to roofs are completed before we finish capturing undo data
OnMsg.EditorObjectOperationEnding = Room_RecalcRoofsOfMovedRooms

function Room:AlignObj(pos, angle)
	if pos then
		assert(IsEditorActive())
		local offset = pos - self:GetPos()
		local box = self.box
		local didMove = false
		if abs(offset:x()) / voxelSizeX > 0 or abs(offset:y()) / voxelSizeY > 0 or abs(offset:z()) / voxelSizeZ > 0 then
			didMove = moveHelperHelper(self, offset)
		end
		if didMove then
			ObjModified(self)
			assert(self:GetGameFlags(const.gofPermanent) ~= 0)
			box = AddRects(box, self.box)
			ComputeSlabVisibilityInBox(box)
			DelayedCall(500, BuildBuildingsData)
			self:DelayedRecalcRoof()
		end
	else
		self:InternalAlignObj()
	end
end

function Room:GetEditorLabel()
	return self.name or self.class
end

function InsertMaterialProperties(name, count)
	assert(count >= 1 and count <= 4)
	for i = 1, count do
		table.insert(Room.properties, {
			id = name .. "color" .. count,
			editor = "color",
			alpha = false,
		})
		table.insert(Room.properties, {
			id = name .. "metallic" .. count,
			editor = "number",
		})
	end
end


local room_NSWE_lists = {
	"spawned_walls",
	"spawned_corners",
	"spawned_doors",
	"spawned_windows",
	"spawned_decals",
}

local room_NSWE_lists_no_DoorsWindows = {
	"spawned_walls",
	"spawned_corners",
}

local room_regular_lists = {
	"spawned_floors",
	"roof_objs",
}

local room_regular_list_sides = {
	"Floor",
	false -- see RoomRoof:GetPivots
}

function ForEachInTable(t, f, ...)
	for i = 1, #(t or "") do
		local o = t[i]
		if IsValid(o) then
			f(o, ...)
		end
	end
end

function Room:UnlockAllSlabs()
	self:UnlockFloor()
	self:UnlockAllWalls()
	self:UnlockRoof()
end

function Room:UnlockFloor()
	ForEachInTable(self.spawned_floors, Slab.UnlockSubvariant)
end

function Room:UnlockAllWalls()
	for side, t in pairs(self.spawned_walls or empty_table) do
		ForEachInTable(t, Slab.UnlockSubvariant)
	end
	for side, t in pairs(self.spawned_corners or empty_table) do
		ForEachInTable(t, Slab.UnlockSubvariant)
	end
	ForEachInTable(self.roof_objs, function(o)
		if not IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end)
end

function Room:UnlockRoof()
	ForEachInTable(self.roof_objs, function(o)
		if IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end)
end

sideToCornerSides = {
	East = { "East", "South" },
	South = { "West", "South" },
	West = { "West", "North" },
	North = { "East", "North" },
}

function Room:UnlockWallSide(side) --both walls and corners + roof walls n corners in one
	ForEachInTable(self.spawned_walls and self.spawned_walls[side], Slab.UnlockSubvariant)
	local css = sideToCornerSides[side]
	for _, cs in ipairs(css) do
		ForEachInTable(self.spawned_corners and self.spawned_corners[cs], Slab.UnlockSubvariant)
	end
	
	ForEachInTable(self.roof_objs, function(o, side)
		if o.side == side and not IsKindOf(o, "RoofSlab") then
			o:UnlockSubvariant()
		end
	end ,side)
end

function Room:ForEachSpawnedObjNoDoorsWindows(func, ...)
	return self:_ForEachSpawnedObj(room_NSWE_lists_no_DoorsWindows, room_regular_lists, func, ...)
end

function Room:ForEachSpawnedObj(func, ...)
	return self:_ForEachSpawnedObj(room_NSWE_lists, room_regular_lists, func, ...)
end

function Room:_ForEachSpawnedObj(NSWE_lists, regular_lists, func, ...)
	for i = 1, #NSWE_lists do
		for side, objs in NSEW_pairs(self[NSWE_lists[i]] or empty_table) do
			for j = 1, #objs do
				if IsValid(objs[j]) then func(objs[j], ...) end
			end
		end
	end
	
	for i = 1, #regular_lists do
		local lst = self[regular_lists[i]] or ""
		for j = 1, #lst do
			if IsValid(lst[j]) then func(lst[j], ...) end
		end
	end
end

function Room:GetEditorRelatedObjects()
	local ret = {}
	for i = 1, #room_NSWE_lists do
		for side, objs in NSEW_pairs(self[room_NSWE_lists[i]] or empty_table) do
			for _, obj in ipairs(objs) do
				if obj then
					ret[#ret + 1] = obj
					if obj:HasMember("owned_objs") and obj.owned_objs then
						table.iappend(ret, obj.owned_objs)
					end
					if obj:HasMember("owned_slabs") and obj.owned_slabs then
						table.iappend(ret, obj.owned_slabs)
					end
				end
			end
		end
	end
	for i = 1, #room_regular_lists do
		table.iappend(ret, self[room_regular_lists[i]] or empty_table)
	end
	Msg("GatherRoomRelatedObjects", self, ret)
	return ret
end

function Room:SetWarped(warped, force)
	CObject.SetWarped(self, warped)
	if force or not IsChangingMap() then
		self:ForEachSpawnedObj(function(obj)
			obj:SetWarped(warped)
		end)
	end
end

local function copyWallObjs(t, offset, room)
	local ret = {}
	for side, objs in NSEW_pairs(t or empty_table) do
		ret[side] = {}
		for i = 1, #objs do
			local o = objs[i]
			local no = PlaceObject(o.class)
			no.floor = room.floor
			no.width = o.width
			no.height = o.height
			no.material = o.material
			no:SetPos(o:GetPos() + offset)
			no:SetAngle(o:GetAngle())
			table.insert(ret[side], no)
			no:UpdateEntity()
		end
	end
	
	return ret
end

local function copyDecals(t, offset, room)
	local ret = {}
	for side, objs in NSEW_pairs(t or empty_table) do
		ret[side] = {}
		for i = 1, #objs do
			local o = objs[i]
			local no = PlaceObject(o.class)
			no.floor = room.floor
			no:SetPos(o:GetPos() + offset)
			no:SetAngle(o:GetAngle())
			no.restriction_box = Offset(o.restriction_box, offset)
			table.insert(ret[side], no)
		end
	end
	
	return ret
end

function Room:OnSetdoors_windows_blocked()
	self:ForEachSpawnedWallObj(function(o, val)
		o:SetlockpickState(val and "blocked" or "closed")
	end, self.doors_windows_blocked)
end

function Room:OnSetnone_roof_wall_mat_does_not_affect_nbrs()
	self:ComputeRoomVisibility()
end

function Room:OnSetnone_wall_mat_does_not_affect_nbrs()
	self:ComputeRoomVisibility()
end

function Room:OnCopied(from, offset)
	Volume.OnCopied(self, from, offset)
	self:CreateAllSlabs()
	
	self.spawned_doors = copyWallObjs(from.spawned_doors, offset, self)
	self.spawned_windows = copyWallObjs(from.spawned_windows, offset, self)
	self.spawned_decals = copyDecals(from.spawned_decals, offset, self)
end

function Room:OnAfterEditorNew(parent, ged, is_paste)
	--undo deletion from ged
	self.adjacent_rooms = nil
	self:AlignObj()
	self:CreateAllSlabs()
end

function Room:OnEditorSetProperty(prop_id, old_value, ged)
	if not IsValid(self) then return end --undo on deleted obj
	local f = rawget(Room, string.format("OnSet%s", prop_id))
	if f then
		f(self, self[prop_id], old_value)
		DelayedCall(500, BuildBuildingsData)
	end
end

function Room:OnSethide_floors_editor()
	assert(IsEditorActive())
	HideFloorsAboveThisOne = rawget(self, "hide_floors_editor")
	HideFloorsAbove(HideFloorsAboveThisOne)
end

function Room:Gethide_floors_editor()
	return HideFloorsAboveThisOne
end

function Room:OnSetwireframe_visible()
	self:ToggleGeometryVisible()
end

function Room:OnSetwall_text_markers_visible()
	self:TogglePosMarkersVisible()
end

function Room:OnSetinner_wall_mat(val, oldVal)
	if val == "" then
		val = noneWallMat
		self.inner_wall_mat = val
	end
	if (val == noneWallMat or oldVal == noneWallMat) and val ~= oldVal then
		self:UnlockAllWalls()
	end
	self:SetInnerMaterialToSlabs("North")
	self:SetInnerMaterialToSlabs("South")
	self:SetInnerMaterialToSlabs("West")
	self:SetInnerMaterialToSlabs("East")
	self:SetInnerMaterialToRoofObjs()
end

function Room:OnSetinner_colors(val, oldVal)
	self:SetInnerMaterialToSlabs("North")
	self:SetInnerMaterialToSlabs("South")
	self:SetInnerMaterialToSlabs("West")
	self:SetInnerMaterialToSlabs("East")
	self:SetInnerMaterialToRoofObjs()
end

function Room:OnSetouter_colors(val, oldVal)
	local function iterateNSEWTableAndSetColor(t)
		if not t then return end
		for side, list in NSEW_pairs(t) do
			for i = 1, #list do
				local o = list[i]
				if IsValid(o) then --wall piece might be deleted by lvl designer
					o:Setcolors(val)
				end
			end
		end
	end
	iterateNSEWTableAndSetColor(self.spawned_walls)
	
	for side, list in NSEW_pairs(self.spawned_corners) do
		for i = 1, #list do
			local o = list[i]
			if IsValid(o) then
				o:SetColorFromRoom()
			end
		end
	end
	
	for side, list in NSEW_pairs(self.spawned_windows or empty_table) do
		for i = 1, #list do
			list[i]:UpdateManagedSlabs()
			list[i]:RefreshColors()
		end
	end
	
	for side, list in NSEW_pairs(self.spawned_doors or empty_table) do
		for i = 1, #list do
			list[i]:RefreshColors()
		end
	end
	
	if self.roof_objs then
		for i=1,#self.roof_objs do
			local o = self.roof_objs[i]
			if IsValid(o) and not IsKindOf(o, "RoofSlab") then
				o:Setcolors(val)
			end
		end
	end
end

function Room:OnSetfloor_colors(val, oldVal)
	for i = 1, #(self.spawned_floors or "") do
		local o = self.spawned_floors[i]
		if IsValid(o) then
			o:Setcolors(val)
		end
	end
end

function Room:OnSetfloor_mat(val)
	self:UnlockFloor()
	self:CreateFloor()
end

function Room:ResetWallMaterials()
	local wm = defaultWallMat
	local change = self.north_wall_mat ~= wm
	self.north_wall_mat = wm
	change = change or self.south_wall_mat ~= wm
	self.south_wall_mat = wm
	change = change or self.west_wall_mat ~= wm
	self.west_wall_mat = wm
	change = change or self.east_wall_mat ~= wm
	self.east_wall_mat = wm
	--todo: wall added/removed msgs
	if change then
		ObjModified(self)
		self:UnlockAllWalls()
		self:CreateAllWalls()
		self:RecreateRoof()
	end
end

local function FireWallChangedEventsHelper(self, side, val, oldVal)
	local wasWall = oldVal ~= noneWallMat and (oldVal ~= defaultWallMat or self.wall_mat ~= noneWallMat)
	local isWall = val ~= noneWallMat and (val ~= defaultWallMat or self.wall_mat ~= noneWallMat)
	if not wasWall and isWall then
		Msg("RoomAddedWall", self, side)
	elseif wasWall and not isWall then
		Msg("RoomRemovedWall", self, side)
	end
end

function Room:OnSetnorth_wall_mat(val, oldVal)
	self:UnlockWallSide("North")
	self:CreateWalls("North", val)
	self:RecreateNECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "North", val, oldVal)
	self:CheckWallSizes()
end

function Room:OnSetsouth_wall_mat(val, oldVal)
	self:UnlockWallSide("South")
	self:CreateWalls("South", val)
	self:RecreateSECornerBeam()
	self:RecreateSWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "South", val, oldVal)
	self:CheckWallSizes()
end

function Room:OnSetwest_wall_mat(val, oldVal)
	self:UnlockWallSide("West")
	self:CreateWalls("West", val)
	self:RecreateSWCornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "West", val, oldVal)
	self:CheckWallSizes()
end

function Room:OnSeteast_wall_mat(val, oldVal)
	self:UnlockWallSide("East")
	self:CreateWalls("East", val)
	self:RecreateSECornerBeam()
	self:RecreateNECornerBeam()
	self:RecreateRoof()
	FireWallChangedEventsHelper(self, "East", val, oldVal)
	self:CheckWallSizes()
end

function Room:SetWallMaterial(val)
	local ov = self.wall_mat
	self.wall_mat = val
	if IsChangingMap() then return end
	self:OnSetwall_mat(val, ov)
end

function Room:OnSetwall_mat(val, oldVal)
	if val == "" then
		val = noneWallMat
		self.wall_mat = val
	end
	self:UnlockAllWalls()
	self:CreateAllWalls()
	self:RecreateRoof()
	
	local wasWall = oldVal ~= noneWallMat
	local isWall = val ~= noneWallMat
	local ev = false
	if wasWall and not isWall then
		ev = "RoomRemovedWall"
	elseif not wasWall and isWall then
		ev = "RoomAddedWall"
	end
	
	if ev then
		if self.south_wall_mat == defaultWallMat then
			Msg(ev, self, "South")
		end
		if self.north_wall_mat == defaultWallMat then
			Msg(ev, self, "North")
		end
		if self.west_wall_mat == defaultWallMat then
			Msg(ev, self, "West")
		end
		if self.east_wall_mat == defaultWallMat then
			Msg(ev, self, "East")
		end
	end
end

function SizeSetterHelper(self, old_v)
	if IsChangingMap() then return end
	local oldBox = self.box
	self:InternalAlignObj(true)
	if self:CheckCollision() then
		self.size = old_v
		self:InternalAlignObj(true)
		return false
	else
		self:Resize(old_v, self.size, oldBox)
		Volume.FinishAlign(self)
		Msg("RoomResized", self, old_v) --old_v == old self.size
		return true
	end
end

function Room:OnSetsize_x(val)
	local old_v = self.size
	self.size = point(val, self.size:y(), self.size:z())
	SizeSetterHelper(self, old_v)
end

function Room:OnSetsize_y(val)
	local old_v = self.size
	self.size = point(self.size:x(), val, self.size:z())
	SizeSetterHelper(self, old_v)
end

function Room:OnSetsize_z(val)
	local old_v = self.size
	self.size = point(self.size:x(), self.size:y(), val)
	SizeSetterHelper(self, old_v)
	if val == 0 then
		self:DeleteAllWallObjs()
		self:DeleteAllFloors()
		self:DeleteAllCornerObjs()
	end
end

function Room:Getsize_x()
	return self.size:x()
end

function Room:Getsize_y()
	return self.size:y()
end

function Room:Getsize_z()
	return self.size:z()
end

function Room:Getmove_x()
	local x = WorldToVoxel(self.position)
	return x
end

function Room:Getmove_y()
	local _, y = WorldToVoxel(self.position)
	return y
end

function Room:Getmove_z()
	local x, y, z = WorldToVoxel(self.position)
	return z
end

function Room:OnSetz_offset(val, old_v)
	moveHelper(self, "z_offset", old_v, 0, 0, val - old_v)
end

function Room:OnSetmove_x(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(val, y, z, true))
	moveHelper(self, "position", old_v, val - x, 0, 0)
end

function Room:OnSetmove_y(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(x, val, z, true))
	moveHelper(self, "position", old_v, 0, val - y, 0)
end

function Room:OnSetmove_z(val)
	local old_v = self.position
	local x, y, z = WorldToVoxel(self.position)
	self.position = SnapVolumePos(VoxelToWorld(x, y, val, true))
	moveHelper(self, "position", old_v, 0, 0, val - z)
end

--left to right sort on selected wall
local dirToComparitor = {
	South = function(o1, o2)
		local x1, _, _ = o1:GetPosXYZ()
		local x2, _, _ = o2:GetPosXYZ()
		return x1 < x2
	end,
	
	North = function(o1, o2)
		local x1, _, _ = o1:GetPosXYZ()
		local x2, _, _ = o2:GetPosXYZ()
		return x2 < x1
	end,
	
	West = function(o1, o2)
		local _, y1, _ = o1:GetPosXYZ()
		local _, y2, _ = o2:GetPosXYZ()
		return y1 < y2
	end,
	
	East = function(o1, o2)
		local _, y1, _ = o1:GetPosXYZ()
		local _, y2, _ = o2:GetPosXYZ()
		return y2 < y1
	end,
}

function Room:SortWallObjs(objs, dir)
	table.sort(objs, dirToComparitor[dir])
end

--for doors/windows
function Room:CalculateRestrictionBox(dir, wallPos, wallSize, height, width)
	local xofs, nxofs = 0, 0
	local yofs, nyofs = 0, 0
	width = Max(width, 1)
	
	if dir == "North" or dir == "South" then
		xofs = (wallSize / 2 - width * voxelSizeX / 2)
		nxofs = xofs
		if width % 2 == 0 then
			local m = (dir == "South" and -1 or 1)
			xofs = xofs + m * voxelSizeX / 2
			nxofs = nxofs - m * voxelSizeX / 2
		end
	else
		yofs = (wallSize / 2 - width * voxelSizeY / 2)
		nyofs = yofs
		if width % 2 == 0 then
			local m = (dir == "West" and -1 or 1)
			yofs = yofs + m * voxelSizeX / 2
			nyofs = nyofs - m * voxelSizeX / 2
		end
	end
	
	local maxZ = wallPos:z() + (self.size:z() * voxelSizeZ - height * voxelSizeZ)
	return box(wallPos:x() - nxofs, wallPos:y() - nyofs, wallPos:z(), wallPos:x() + xofs, wallPos:y() + yofs, maxZ)
end

function Room:FindSlabObjPos(dir, width, height)
	local sizeX, sizeY = self.size:x(), self.size:y()
	if dir == "North" or dir == "South" then
		if width > sizeX then
			print("Obj is too big")
			return false
		end
	else
		if width > sizeY then
			print("Obj is too big")
			return false
		end
	end
	
	local z = self:CalcZ() + (3 - height) * voxelSizeZ
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	local offsx = 0
	local offsy = 0
	local max = 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
		max = sizeX
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
		max = sizeY
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
		max = sizeX
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
		max = sizeY
	end
	
	local iStart = width == 3 and 1 or 0
	
	for i = iStart, max - 1 do
		local x = sx + offsx * i
		local y = sy + offsy * i
		
		local newPos = point(x, y, z)
		local canPlace = not IntersectWallObjs(nil, newPos, width, height, angle)
		
		if canPlace then
			return newPos
		end
	end
	
	return false
end

function Room:NewSlabWallObj(obj, class)
	class = class or SlabWallObject
	return class:new(obj)
end

function Room:ForEachSpawnedWindow(func, ...)
	for _, t in sorted_pairs(self.spawned_windows or empty_table) do
		for i = #t, 1, -1 do
			func(t[i], ...)
		end
	end
end

function Room:ForEachSpawnedDoor(func, ...)
	for _, t in sorted_pairs(self.spawned_doors or empty_table) do
		for i = #t, 1, -1 do --functor may del
			func(t[i], ...)
		end
	end
end

function Room:ForEachSpawnedWallObj(func, ...) --doors and windows
	self:ForEachSpawnedDoor(func, ...)
	self:ForEachSpawnedWindow(func, ...)
end

function Room:PlaceWallObj(val, side, class)
	local dir = side or self.selected_wall
	assert(dir)
	if not dir then return end
	--check for collision, pick pos
	local freePos = self:FindSlabObjPos(dir, val.width, val.height)
	
	if not freePos then
		print("No free pos found!")
		return
	end
	local wallPos, wallSize, center = self:GetWallPos(dir)
	local obj = self:NewSlabWallObj({
			entity = false, room = self, material = val.mat or "Planks",
			building_class = val.building_class or nil, building_template = val.building_template or nil,
			side = dir
		},
		class.class)
	local a = slabDirToAngle[dir]
	local zPosOffset = (3 - val.height) * voxelSizeZ
	local vx, vy, vz, va = WallWorldToVoxel(freePos:x(), freePos:y(), wallPos:z() + zPosOffset, a)
	local pos = point(WallVoxelToWorld(vx, vy, vz, va))
	obj.room = self
	obj.floor = self.floor
	obj.subvariant = 1
	obj:SetPos(pos)
	obj:SetAngle(a)
	obj:SetProperty("width", val.width)
	obj:SetProperty("height", val.height)
	obj:AlignObj()
	obj:UpdateEntity()
	
	local container, nestedList
	if val.is_door or obj:IsDoor() then --door
		self.spawned_doors = self.spawned_doors or {}
		self.spawned_doors[dir] = self.spawned_doors[dir] or {}
		container = self.spawned_doors
	else --window
		self.spawned_windows = self.spawned_windows or {}
		self.spawned_windows[dir] = self.spawned_windows[dir] or {}
		container = self.spawned_windows
	end
	
	if container then
		table.insert(container[dir], obj)
	end
	
	if Platform.editor and IsEditorActive() then
		editor.ClearSel()
		editor.AddToSel({obj})
	end
	
	return obj
end


function Room:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
	local xofs, nxofs = 0, 0
	local yofs, nyofs = 0, 0
	if dir == "North" or dir == "South" then
		xofs = wallSize / 2
		nxofs = xofs
		
		wallPos = wallPos:SetY(wallPos:y() + 100 * (dir == "North" and -1 or 1))
	else
		yofs = wallSize / 2
		nyofs = yofs
		
		wallPos = wallPos:SetX(wallPos:x() + 100 * (dir == "West" and -1 or 1))
	end
	local maxZ = wallPos:z() + (self.size:z() * voxelSizeZ) + 1
	return box(wallPos:x() - nxofs, wallPos:y() - nyofs, wallPos:z(), wallPos:x() + xofs, wallPos:y() + yofs, maxZ)
end

DefineClass.RoomDecal = {
	__parents = { "AlignedObj", "Decal", "Shapeshifter", "Restrictor", "HideOnFloorChange" },
	properties = {
		{ category = "General", id = "entity", editor = "text", default = false, no_edit = true },
	},
	flags = { cfAlignObj = true, cfDecal = true, efCollision = false, gofPermanent = true, },
}

function RoomDecal:AlignObj(pos, angle, axis)
	pos = pos or self:GetPos()
	local x, y, z = self:RestrictXYZ(pos:xyz())
	
	self:SetPos(x, y, z)
	self:SetAxisAngle(axis or self:GetAxis(), angle or self:GetAngle())
end

function RoomDecal:ChangeEntity(val)
	Shapeshifter.ChangeEntity(self, val)
	self.entity = val
end

function RoomDecal:GameInit()
	if IsChangingMap() and self.entity then
		Shapeshifter.ChangeEntity(self, self.entity)
	end
end

function RoomDecal:Done()
	local safe = rawget(self, "safe_deletion")
	if not safe then
		--decals dont have ref to the room they belong to, so the check is all weird
		local box = self.restriction_box
		if box then
			local passed = {}
			MapForEach(box:grow(100, 100, 0), "WallSlab", function(s)
				local side = s.side
				local room = s.room
				if room then
					local id = xxhash(room.handle, side)
					if not passed[id] then
						passed[id] = true
						local t = room.spawned_decals[side]
						local t_idx = table.find(t, self)
						if t_idx then
							table.remove(t, t_idx)
							ObjModified(room)
							return "break"
						end
					end
				end
			end)
		else
			local b = self:GetObjectBBox()
			local success = false
			b = b:grow(guim, guim, guim)
			EnumVolumes(b, function(r)
				local t = r.spawned_decals
				for side, tt in pairs(t or empty_table) do
					local t_idx = table.find(tt, self)
					if t_idx then
						table.remove(tt, t_idx)
						ObjModified(r)
						success = true
						return "break"
					end
				end
			end)
			
			if not success then
				assert(false, "RoomDecal not safely deleted, ref in room remains!")
			end
		end
	end
end

function Room:Setplace_decal(val)
	local dir = self.selected_wall
	if not dir then return end
	
	local wallPos, wallSize, center = self:GetWallPos(dir)
	local a = slabDirToAngle[dir]
	
	local obj = RoomDecal:new()
	obj.floor = self.floor
	obj:ChangeEntity(val.entity)
	obj:SetAngle(a)
	local xOffs = 0
	local yOffs = 0
	if dir == "East" then
		obj:SetAxis(axis_y)
		obj:SetAngle(90 * 60)
		xOffs = 100
	elseif dir == "West" then
		obj:SetAxis(axis_y)
		obj:SetAngle(-90 * 60)
		xOffs = -100
	elseif dir == "North" then
		obj:SetAxis(axis_x)
		obj:SetAngle(90 * 60)
		yOffs = -100
	elseif dir == "South" then
		obj:SetAxis(axis_x)
		obj:SetAngle(-90 * 60)
		yOffs = 100
	end
	obj:SetPos(wallPos + point(xOffs, yOffs, voxelSizeZ * self.size:z() / 2))
	obj.restriction_box = self:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
	--DbgAddBox(obj.restriction_box, RGB(255, 0, 0))
	
	self.spawned_decals = self.spawned_decals or {}
	self.spawned_decals[dir] = self.spawned_decals[dir] or {}
	table.insert(self.spawned_decals[dir], obj)
	
	editor.ClearSel()
	editor.AddToSel({obj})
	
	self.place_decal = "temp"
	ObjModified(self)
	self.place_decal = ""
	ObjModified(self)
end

function Room:DeleteWallObjHelper(d)
	d:RestoreAffectedSlabs()
	DoneObject(d)
	ObjModified(self)
end

function Room:DeleteWallObjs(container, dir)
	if not dir then
		self:DeleteWallObjs("North", container)
		self:DeleteWallObjs("South", container)
		self:DeleteWallObjs("East", container)
		self:DeleteWallObjs("West", container)
		self:DeleteAllFloors()
		self:DeleteAllCornerObjs()
	else
		local t = container and container[dir]
		for i = #(t or empty_table), 1, -1 do
			if IsValid(t[i]) then --can be killed from editor
				self:DeleteWallObjHelper(t[i])
			end
			t[i] = nil
		end
		ObjModified(self)
	end
end

function Room:RebuildAllSlabs()
	self:DeleteAllSlabs()
	self:CreateAllSlabs()
	self:RecreateRoof("force")
end

function Room:DoneObjectsInNWESTable(t)
	for k, v in NSEW_pairs(t or empty_table) do
		--windows and doors are so clever that they remove themselves from these lists when deleted, which causes DoneObjects to sometimes fail
		while #v > 0 do
			local idx = #v
			DoneObject(v[idx])
			v[idx] = nil
		end
	end
end

function Room:DeleteAllSlabs()
	SuspendPassEdits("Room:DeleteAllSpawnedObjs")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:DeleteAllFloors()
	self:DeleteRoofObjs()
	ResumePassEdits("Room:DeleteAllSpawnedObjs")
end

function Room:DeleteAllSpawnedObjs()
	SuspendPassEdits("Room:DeleteAllSpawnedObjs")
	self:DeleteAllWallObjs()
	self:DeleteAllCornerObjs()
	self:DeleteAllFloors()
	self:DeleteRoofObjs()
	self:DoneObjectsInNWESTable(self.spawned_doors)
	self:DoneObjectsInNWESTable(self.spawned_windows)
	self:DoneObjectsInNWESTable(self.spawned_decals)
	ResumePassEdits("Room:DeleteAllSpawnedObjs")
end

function Room:DeleteAllFloors()
	SuspendPassEdits("Room:DeleteAllFloors")
	DoneObjects(self.spawned_floors, "clear")
	ResumePassEdits("Room:DeleteAllFloors")
	Msg("RoomDestroyedFloor", self)
end

function Room:DeleteAllCornerObjs()
	for k, v in NSEW_pairs(self.spawned_corners or empty_table) do
		DoneObjects(v, "clear")
	end
end

function Room:DeleteAllWallObjs()
	SuspendPassEdits("Room:DeleteAllWallObjs")
	for k, v in NSEW_pairs(self.spawned_walls or empty_table) do
		DoneObjects(v, "clear")
	end
	ResumePassEdits("Room:DeleteAllWallObjs")
end

function Room:HasWall(mat)
	return mat ~= noneWallMat and (mat ~= defaultWallMat or self.wall_mat ~= noneWallMat)
end

function Room:HasWallOnSide(side)
	return self:GetWallMatHelperSide(side) ~= noneWallMat
end

function Room:HasAllWalls()
	for _, side in ipairs(CardinalDirectionNames) do
		if not self:HasWallOnSide(side) then
			return false
		end
	end
	
	return true
end

function Room:RecreateNWCornerBeam()
	local mat = self.north_wall_mat
	if mat == noneWallMat then
		mat = self.west_wall_mat
	end
	self:CreateCornerBeam("North", mat) --nw
end

function Room:RecreateSWCornerBeam()
	local mat = self.west_wall_mat
	if mat == noneWallMat then
		mat = self.south_wall_mat
	end
	self:CreateCornerBeam("West", mat) --sw
end

function Room:RecreateNECornerBeam()
	local mat = self.east_wall_mat
	if mat == noneWallMat then
		mat = self.north_wall_mat
	end
	self:CreateCornerBeam("East", mat) --ne
end

function Room:RecreateSECornerBeam()
	local mat = self.south_wall_mat
	if mat == noneWallMat then
		mat = self.east_wall_mat
	end
	self:CreateCornerBeam("South", mat) --se
end

function Room:CreateAllWalls()
	SuspendPassEdits("Room:CreateAllWalls")
	self:CreateWalls("North", self.north_wall_mat)
	self:CreateWalls("South", self.south_wall_mat)
	self:CreateWalls("West", self.west_wall_mat)
	self:CreateWalls("East", self.east_wall_mat)
	self:CheckWallSizes()
	ResumePassEdits("Room:CreateAllWalls")
end

function Room:CreateAllSlabs()
	SuspendPassEdits("Room:CreateAllSlabs")
	self:CreateAllWalls()
	self:CreateFloor()
	self:CreateAllCorners()
	if not self.being_placed then
		self:RecreateRoof()
	end
	self:SetWarped(self:GetWarped(), true)
	ResumePassEdits("Room:CreateAllSlabs")
end

function Room:RefreshFloorCombatStatus()
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	if not floorsAreCO then return end
	
	local flr = self.floor
	local val = not self:IsRoofOnly() and flr == 1
	for i = 1, #(self.spawned_floors or "") do
		local f = self.spawned_floors[i]
		if IsValid(f) then
			f.impenetrable = val
			f.invulnerable = val
			f.forceInvulnerableBecauseOfGameRules = val
		end
	end
end

function Room:CreateFloor(mat, startI, startJ)
	mat = mat or self.floor_mat
	self.spawned_floors = self.spawned_floors or {}
	local objs = self.spawned_floors
	
	local gz = self:CalcZ()
	local sx, sy = self.position:x(), self.position:y()
	local sizeX, sizeY, sizeZ = self.size:xyz()
	
	if sizeZ <= 0 then
		self:DeleteAllFloors()
		print("<color 0 255 38>Removed floor because it is a zero height room. </color>")
		return
	end
	
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	startI = startI or 0
	startJ = startJ or 0
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		local floorBBox = box(sx, sy, gz, sx + voxelSizeX * (sizeX - 1), sy + voxelSizeY * (sizeY - 1), gz + 1)
		ComputeSlabVisibilityInBox(floorBBox)
	end
	
	SuspendPassEdits("Room:CreateFloor")
	local insertElements = startJ ~= 0 and #objs < sizeX * sizeY
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	local floorsAreInvulnerable = floorsAreCO and not self:IsRoofOnly() and self.floor == 1
	for xOffset = startI, sizeX - 1 do
		for yOffset = xOffset == startI and startJ or 0, sizeY - 1 do
			local x = sx + xOffset * voxelSizeX
			local y = sy + yOffset * voxelSizeY
			local idx = xOffset * sizeY + yOffset + 1
			
			if insertElements then
				if #objs < idx then
					objs[idx] = false
				else
					table.insert(objs, idx, false)
				end
				
				insertElements = insertElements and #objs < sizeX * sizeY
			end
			
			local floor = objs[idx]
			if not IsValid(floor) then
				floor = FloorSlab:new{floor = self.floor, material = mat, side = "Floor", room = self}
				floor:SetPos(x, y, gz)
				floor:AlignObj()
				floor:UpdateEntity()
				floor:Setcolors(self.floor_colors)
				objs[idx] = floor
			else
				floor:SetPos(x, y, gz)
				if floor.material ~= mat then
					floor.material = mat
					floor:UpdateEntity()
				else
					floor:UpdateSimMaterialId()
				end
				
			end
			
			floor.floor = self.floor
			if floorsAreCO then --zulu specific
				floor.impenetrable = floorsAreInvulnerable
				floor.invulnerable = floorsAreInvulnerable
				floor.forceInvulnerableBecauseOfGameRules = floorsAreInvulnerable
			end
		end
	end
	ResumePassEdits("Room:CreateFloor")
	Msg("RoomCreatedFloor", self, mat)
end

function Room:CreateCornerBeam(dir, mat) --corner is next clockwise corner from dir
	self.spawned_corners = self.spawned_corners or {North = {}, South = {}, West = {}, East = {}}	
	local objs = self.spawned_corners[dir]
	
	if mat == defaultWallMat then
		mat = self.wall_mat
	end
	
	local gz = self:CalcSnappedZ()
	local sx, sy = self.position:x(), self.position:y()
	local sizeX, sizeY = self.size:x(), self.size:y()
	if dir == "South" or dir == "West" then
		sy = sy + sizeY * voxelSizeY
	end
	
	if dir == "South" or dir == "East" then
		sx = sx + sizeX * voxelSizeX
	end
	
	local count = self.size:z() + 1
	if count < #objs then
		for i = #objs, count + 1, -1 do
			DoneObject(objs[i])
			objs[i] = nil
		end
	end
	
	local isPermanent = self:GetGameFlags(const.gofPermanent) ~= 0
	local sz = self.size:z()

	if sz > 0 then
		for j = 0, sz do
			local z = gz + voxelSizeZ * Min(j, self.size:z() - 1)
			local pt = point(sx, sy, z)

			local obj = objs[j + 1]
			if not IsValid(obj) then
				obj = PlaceObject("RoomCorner", {room = self, side = dir, floor = self.floor, material = mat})
				objs[j + 1] = obj
			end
			obj.isPlug = j == self.size:z()
			obj:SetPos(pt)
			obj.material = mat
			obj.invulnerable = false
			obj.forceInvulnerableBecauseOfGameRules = false
			if not isPermanent then
				obj:UpdateEntity() --corners rely on ComputeSlabVisibilityInBox to update their ents
			end
		end
	end
	
	if isPermanent then
		local box = box(sx, sy, gz, sx, sy, gz + voxelSizeZ * (self.size:z() - 1))
		ComputeSlabVisibilityInBox(box)
	end
end

function Room:GetWallMatHelperSide(side)
	local m = dirToWallMatMember[side]
	return m and self:GetWallMatHelper(self[m]) or nil
end

function Room:GetWallMatHelper(mat)
	return mat == defaultWallMat and self.wall_mat or mat
end

function Room:RecalcAllRestrictionBoxes(dir, containers)
	local wallPos, wallSize, center = self:GetWallPos(dir)
	for j = 1, #(containers or empty_table) do
		local container = containers[j]
		local t = container and container[dir]
		
		--save fixup, idk how, sometimes decal lists have false entries
		for i = #(t or ""), 1, -1 do
			if type(t[i]) == "boolean" then
				table.remove(t, i)
				print("once", "Found badly saved decals/windows/doors!")
			end
		end
		
		if t and IsKindOf(t[1], "RoomDecal") then
			for i = 1, #(t or empty_table) do
				local o = t[i]
				if o then
					o.restriction_box = self:CalculateDecalRestrictionBox(dir, wallPos, wallSize)
					o:AlignObj()
				end
			end
		end
	end
end

function Room:Resize(oldSize, newSize, oldBox)
	if oldSize == newSize then
		return
	end
	
	SuspendPassEdits("Room:Resize")
	local delta = newSize - oldSize
	
	local offsetY = delta:y() * voxelSizeY
	local offsetX = delta:x() * voxelSizeX
	local offsetZ = delta:z() * voxelSizeZ
	local sx, sy = self.position:x(), self.position:y()
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	local sizeX, sizeY = newSize:x(), newSize:y()
	
	local function moveObjs(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				local x, y, z = o:GetPosXYZ()
				o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
			end
		end
	end
	
	local function moveObjX(o)
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y, z)
		if IsKindOf(o, "SlabWallObject") then
			o:UpdateManagedObj()
		end
	end
	
	local function moveObjsX(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				moveObjX(o)
			end
		end
	end
	
	local function moveObjY(o)
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x, y + offsetY, z)
		if IsKindOf(o, "SlabWallObject") then
			o:UpdateManagedObj()
		end
	end
	
	local function moveObjsY(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				moveObjY(o)
			end
		end
	end
	
	local function moveObjsZ(objs)
		if not objs then return end
		for i = 1, #objs do
			local o = objs[i]
			if IsValid(o) then
				local x, y, z = o:GetPosXYZ()
				o:SetPos(x, y, z + offsetZ)
			end
		end
	end
	
	if delta:y() ~= 0 then
		--south wall moves
		moveObjsY(self.spawned_walls and self.spawned_walls.South)
		moveObjsY(self.spawned_doors and self.spawned_doors.South)
		moveObjsY(self.spawned_windows and self.spawned_windows.South)
		if self.spawned_corners then
			moveObjsY(self.spawned_corners.South)
			moveObjsY(self.spawned_corners.West)
		end
		local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
		self:RecalcAllRestrictionBoxes("East", containers)
		self:RecalcAllRestrictionBoxes("West", containers)
		self:RecalcAllRestrictionBoxes("South", containers)
	end
	if delta:x() ~= 0 then
		--east wall moves
		moveObjsX(self.spawned_walls and self.spawned_walls.East)
		moveObjsX(self.spawned_doors and self.spawned_doors.East)
		moveObjsX(self.spawned_windows and self.spawned_windows.East)
		if self.spawned_corners then
			moveObjsX(self.spawned_corners.South)
			moveObjsX(self.spawned_corners.East)
		end
		local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
		self:RecalcAllRestrictionBoxes("North", containers)
		self:RecalcAllRestrictionBoxes("East", containers)
		self:RecalcAllRestrictionBoxes("South", containers)
	end
	
	if delta:z() ~= 0 then
		if delta:z() > 0 then
			local move = delta:x() ~= 0 or delta:y() ~= 0 --needs to reorder slabs so let it go through the entire wall
			self:CreateWalls("South", self.south_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("North", self.north_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("East", self.east_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
			self:CreateWalls("West", self.west_wall_mat, nil, not move and oldSize:z(), nil, nil, move)
		else
			self:DestroyWalls("East", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("West", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("North", nil, oldSize, nil, newSize:z())
			self:DestroyWalls("South", nil, oldSize, nil, newSize:z())
		end
	end
	
	if delta:y() ~= 0 then
		if delta:y() < 0 then
			local count = abs(delta:y())
			self:DestroyWalls("East", count, oldSize:SetZ(newSize:z()))
			self:DestroyWalls("West", count, oldSize:SetZ(newSize:z()))
			
			
			local floors = self.spawned_floors
			for i = oldSize:x() - 1, 0, -1 do
				for j = oldSize:y() - 1, newSize:y(), -1 do
					local idx = (i * oldSize:y()) + j + 1
					local o = floors[idx]
					if o then
						DoneObject(o)
						table.remove(floors, idx)
					end
				end
			end			
		else
			if self.spawned_walls then
				local ew = self.spawned_walls.East
				local ww = self.spawned_walls.West
				if ew then
					self:CreateWalls("East", self.east_wall_mat, newSize:y() - delta:y())
				end
				if ww then
					self:CreateWalls("West", self.west_wall_mat, newSize:y() - delta:y())
				end
			end
			
			self:CreateFloor(self.floor_mat, 0, oldSize:y())
		end
	end
	
	if delta:x() ~= 0 then
		if delta:x() < 0 then
			local count = abs(delta:x())
			self:DestroyWalls("South", count, oldSize:SetZ(newSize:z()))
			self:DestroyWalls("North", count, oldSize:SetZ(newSize:z()))
						
			local floors = self.spawned_floors
			local nc = newSize:x() * newSize:y()
			local lc = #floors - nc
			for i = 1, lc do
				local idx = #floors
				local f = floors[idx]
				DoneObject(f)
				floors[idx] = nil
			end
		else
			if self.spawned_walls then
				local sw = self.spawned_walls.South
				local nw = self.spawned_walls.North
				if sw then
					self:CreateWalls("South", self.south_wall_mat, newSize:x() - delta:x())
				end
				if nw then
					self:CreateWalls("North", self.north_wall_mat, newSize:x() - delta:x())
				end
			end
			
			self:CreateFloor(self.floor_mat, oldSize:x())
		end
	end
	
	if oldSize:z() > 0 and newSize:z() <= 0 then
		self:DeleteAllFloors()
		self:DestroyCorners()
	elseif oldSize:z() <= 0 and newSize:z() > 0 then
		self:CreateFloor(self.floor_mat)
	end
	
	self:RecreateNECornerBeam()
	self:RecreateSECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateSWCornerBeam()
	
	if not self.being_placed then
		self:RecreateRoof()
	end
	
	ResumePassEdits("Room:Resize")
	self:CheckWallSizes()
end

function Room:DestroyCorners()
	for side, t in NSEW_pairs(self.spawned_corners or empty_table) do
		DoneObjects(t)
		self.spawned_corners[side] = {}
	end
end

function Room:MoveAllSpawnedObjs(dvx, dvy, dvz)
	local offsetX = dvx * voxelSizeX
	local offsetY = dvy * voxelSizeY
	local offsetZ = dvz * voxelSizeZ

	if offsetX == 0 and offsetY == 0 and offsetZ == 0 then
		return
	end
	
	SuspendPassEdits("Room:MoveAllSpawnedObjs")
	local function move(o)
		if not IsValid(o) then return end
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
		--align should not be required, omitted for performance
	end
	
	local function move_window(o)
		if not IsValid(o) then return end
		local x, y, z = o:GetPosXYZ()
		o:SetPos(x + offsetX, y + offsetY, z + offsetZ)
		o:AlignObj() --specifically so small windows realign managed slabs, t.t
	end
	
	local function iterateNSWETable(t, m)
		m = m or move
		for _, st in NSEW_pairs(t or empty_table) do
			for i = 1, #st do
				local o = st[i]
				m(o)
			end
		end
	end
	
	for i = 1, #(self.spawned_floors or empty_table) do
		move(self.spawned_floors[i])
	end
	
	iterateNSWETable(self.spawned_walls)
	iterateNSWETable(self.spawned_corners)
	for i = 1, #(self.roof_objs or empty_table) do
		move(self.roof_objs[i])
	end
	-- move doors & windows after roof_objs, otherwise doors & windows won't find their "main_wall"
	iterateNSWETable(self.spawned_doors)
	iterateNSWETable(self.spawned_windows, move_window)
	iterateNSWETable(self.spawned_decals)
	
	local containers = {self.spawned_doors, self.spawned_windows, self.spawned_decals}
	self:RecalcAllRestrictionBoxes("East", containers)
	self:RecalcAllRestrictionBoxes("West", containers)
	self:RecalcAllRestrictionBoxes("South", containers)
	self:RecalcAllRestrictionBoxes("North", containers)

	ResumePassEdits("Room:MoveAllSpawnedObjs")
end

function Room:DestroyWalls(dir, count, size, startJ, endJ)
	local objs = self.spawned_walls and self.spawned_walls[dir]
	local wnd = self.spawned_windows and self.spawned_windows[dir]
	local doors = self.spawned_doors and self.spawned_doors[dir]
	local len = 0
	local offsX = 0
	local flatOffsX = 0
	local offsY = 0
	local flatOffsY = 0
	local sx, sy = self.position:x(), self.position:y()
	local mat
	sx = sx + halfVoxelSizeX
	sy = sy + halfVoxelSizeY
	size = size or self.size
	
	if dir == "North" then
		len = size:x()
		mat = self:GetWallMatHelper(self.north_wall_mat)
		offsX = voxelSizeX
		flatOffsY = -voxelSizeY / 2
	elseif dir == "East" then
		len = size:y()
		mat = self:GetWallMatHelper(self.east_wall_mat)
		flatOffsX = voxelSizeX / 2
		offsY = voxelSizeY
		sx = sx + (size:x() - 1) * voxelSizeX
	elseif dir == "South" then
		len = size:x()
		mat = self:GetWallMatHelper(self.south_wall_mat)
		offsX = voxelSizeX
		flatOffsY = voxelSizeY / 2
		sy = sy + (size:y() - 1) * voxelSizeY
	elseif dir == "West" then
		len = size:y()
		mat = self:GetWallMatHelper(self.west_wall_mat)
		flatOffsX = -voxelSizeX / 2
		offsY = voxelSizeY
	end
	startJ = startJ or size:z()
	endJ = endJ or 0
	count = count or len
	local gz = self:CalcZ()
	
	SuspendPassEdits("Room:DestroyWalls")
	
	self:SortWallObjs(doors or empty_table, dir)
	self:SortWallObjs(wnd or empty_table, dir)
	
	for i = len - 1, len - count, -1 do
		for j = startJ - 1, endJ, -1 do
			if endJ == 0 then
				--clear wind/door
				local px = sx + i * offsX + flatOffsX
				local py = sy + i * offsY + flatOffsY
				local pz = gz + j * voxelSizeZ
				local p = point(px, py, pz)
			end
			
			if objs and #objs > 0 then
				local idx = i * size:z() + j + 1
				local o = objs[idx]
				DoneObject(o)
				if #objs >= idx then
					table.remove(objs, idx)
				end
			end
		end
	end
	
	local containers = {self.spawned_decals}
	self:RecalcAllRestrictionBoxes(dir, containers)
	self:TouchWallsAndWindows(dir)
	ResumePassEdits("Room:DestroyWalls")
	Msg("RoomDestroyedWall", self, dir)
end

function Room:GetWallSlabPos(dir, idx)
	local x, y, z = self.position:xyz()
	local sizeX, sizeY, sizeZ = self.size:xyz()
	
	assert(voxelSizeX == voxelSizeY)
	local offs = ((idx - 1) / sizeZ) * voxelSizeX + halfVoxelSizeX
	z = z + ((idx - 1) % sizeZ) * voxelSizeZ
	
	if dir == "North" then
		x = x + offs
	elseif dir == "South" then
		x = x + offs
		y = y + sizeY * voxelSizeY
	elseif dir == "West" then
		y = y + offs
	else --dir == "East"
		y = y + offs
		x = x + sizeX * voxelSizeX
	end
	
	return x, y, z
end

function Room:TestAllWallPositions()
	self:TestWallPositions("North")
	self:TestWallPositions("South")
	self:TestWallPositions("West")
	self:TestWallPositions("East")
end

function Room:TestWallPositions(dir)
	self.spawned_walls = self.spawned_walls or {North = {}, South = {}, East = {}, West = {}}
	dir = dir or "North"
	local objs = self.spawned_walls[dir]
	
	local gz = self:CalcZ()
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	--local size = oldSize or self.size
	local size = self.size
	local sizeX, sizeY, sizeZ = size:x(), size:y(), size:z()
	local offsx = 0
	local offsy = 0
	
	local endI = (dir == "North" or dir == "South") and sizeX or sizeY
	local endJ = sizeZ
	local startI = 0
	local startJ = 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
	end
	
	local insertElements = startJ ~= 0 and #objs < ((dir == "North" or dir == "South") and sizeX or sizeY) * sizeZ
	
	for i = startI, endI - 1 do
		for j = startJ, endJ - 1 do
			local px = sx + i * offsx
			local py = sy + i * offsy
			local z = gz + j * voxelSizeZ
			local idx = i * sizeZ + j + 1
			
			local s = objs[idx]
			if not s or s:GetPos() ~= point(px, py, z) then
				print(dir, idx)
			end
		end
	end
end

function Room:CreateWalls(dir, mat, startI, startJ, endI, endJ, move)
	self.spawned_walls = self.spawned_walls or {North = {}, South = {}, East = {}, West = {}}
	mat = mat or "Planks"
	dir = dir or "North"
	local objs = self.spawned_walls[dir]
	
	if mat == defaultWallMat then
		mat = self.wall_mat
	end
	
	local oppositeDir = nil
	local gz = self:CalcZ()
	local angle = 0
	local sx, sy = self.position:x(), self.position:y()
	local size = self.size
	local sizeX, sizeY, sizeZ = size:x(), size:y(), size:z()
	local offsx = 0
	local offsy = 0
	
	endI = endI or (dir == "North" or dir == "South") and sizeX or sizeY
	endJ = endJ or sizeZ
	startI = startI or 0
	startJ = startJ or 0
	
	if dir == "North" then
		angle = 270 * 60
		offsx = voxelSizeX
		sx = sx + halfVoxelSizeX
		oppositeDir = "South"
	elseif dir == "East" then
		angle = 0
		offsy = voxelSizeY
		sx = sx + sizeX * voxelSizeX
		sy = sy + halfVoxelSizeY
		oppositeDir = "West"
	elseif dir == "South" then
		angle = 90 * 60
		offsx = voxelSizeX
		sy = sy + sizeY * voxelSizeY
		sx = sx + halfVoxelSizeX
		oppositeDir = "North"
	elseif dir == "West" then
		angle = 180 * 60
		offsy = voxelSizeY
		sy = sy + halfVoxelSizeY
		oppositeDir = "East"
	end
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		local wallBBox = self:GetWallBox(dir)
		ComputeSlabVisibilityInBox(wallBBox)
	end
	
	SuspendPassEdits("Room:CreateWalls")
	local insertElements = startJ ~= 0 and #objs < ((dir == "North" or dir == "South") and sizeX or sizeY) * sizeZ
	local forceUpdate = self.last_wall_recreate_seed ~= self.seed
	local isLoadingMap = IsChangingMap()
	local affectedRooms = {}
	
	for i = startI, endI - 1 do
		for j = startJ, endJ - 1 do
			local px = sx + i * offsx
			local py = sy + i * offsy
			local z = gz + j * voxelSizeZ
			local idx = i * sizeZ + j + 1
			local m = mat
			
			if insertElements then
				if idx > #objs then
					objs[idx] = false --Happens when resizing in (x or y) ~= 0 and z ~= 0 in the same time. Fill it in, second pass will fill in the missing ones without breaking integrity, probably..
				else
					table.insert(objs, idx, false)
				end
			end
			
			local wall = objs[idx]
			if not IsValid(wall) then
				wall = WallSlab:new{floor = self.floor, material = m, room = self, side = dir, 
										variant = self.inner_wall_mat ~= noneWallMat and "OutdoorIndoor" or "Outdoor", indoor_material_1 = self.inner_wall_mat}
				wall:SetAngle(angle)
				wall:SetPos(px, py, z)
				wall:AlignObj()
				wall:UpdateEntity()
				wall:UpdateVariantEntities()
				
				wall:Setcolors(self.outer_colors)
				wall:Setinterior_attach_colors(self.inner_colors)
				wall.invulnerable = false
				wall.forceInvulnerableBecauseOfGameRules = false
				objs[idx] = wall
			else
				if move then
					--sometimes if we change both z and x or y sizing at the same time we end up with the same number of slabs per wall but they need to be re-arranged.
					wall:SetAngle(angle)
					local op = wall:GetPos()
					wall:SetPos(px, py, z)
					if op ~= wall:GetPos() and wall.wall_obj then
						local o = wall.wall_obj
						o:RestoreAffectedSlabs()
					end
					wall:AlignObj()
				end
				wall:UpdateSimMaterialId()
			end
			
			if not isLoadingMap then
				if forceUpdate or wall.material ~= m or wall.indoor_material_1 ~= self.inner_wall_mat then
					wall.material = m
					wall.indoor_material_1 = self.inner_wall_mat
					wall:UpdateEntity()
					wall:UpdateVariantEntities()
				end
			end
		end
	end
	
	affectedRooms[self] = nil
	for room, isMySide in pairs(affectedRooms) do
		if IsValid(room) then
			local d = isMySide and dir or oppositeDir
			room:TouchWallsAndWindows(d)
			room:TouchCorners(d)
		end
	end
	
	self:TouchWallsAndWindows(dir)
	self:TouchCorners(dir)
	ResumePassEdits("Room:CreateWalls")
	Msg("RoomCreatedWall", self, dir, mat)
end

local postComputeBatch = false
function Room:SetInnerMaterialToRoofObjs()
	local objs = self.roof_objs
	if not objs or #objs <= 0 then return end
	
	local passedSWO = {}
	local col = self.inner_colors
	for i = 1, #objs do
		local o = objs[i]
		if IsValid(o) and IsKindOf(o, "WallSlab") then
			if o.indoor_material_1 ~= self.inner_wall_mat then
				o.indoor_material_1 = self.inner_wall_mat
				o:UpdateVariantEntities()
			end
			o:Setinterior_attach_colors(col)
			
			local swo = o.wall_obj
			if swo and not passedSWO[swo] then
				passedSWO[swo] = true
			end
		end
	end
	
	if next(passedSWO) then
		--in some cases slabs need to recalibrate in computeslabvisibility, we need to pass after that
		postComputeBatch = postComputeBatch or {}
		postComputeBatch[#postComputeBatch + 1] = passedSWO
	end
	
	ComputeSlabVisibilityInBox(self.roof_box)
end

function Room:SetInnerMaterialToSlabs(dir)
	local objs = self.spawned_walls and self.spawned_walls[dir]
	local gz = self:CalcZ()
	local sizeX, sizeY = self.size:x(), self.size:y()
	local endI = (dir == "North" or dir == "South") and sizeX or sizeY
	local passedSWO = {}
	local wallBBox = box()
	local col = self.inner_colors
	if objs then
		for i = 0, endI - 1 do
			for j = 0, self.size:z() - 1 do
				local idx = i * self.size:z() + j + 1
				local o = objs[idx]
				if IsValid(o) then
					wallBBox = Extend(wallBBox, o:GetPos())
					if o.indoor_material_1 ~= self.inner_wall_mat then
						o.indoor_material_1 = self.inner_wall_mat
						o:UpdateVariantEntities()
					end
					o:Setinterior_attach_colors(col)
					
					local swo = o.wall_obj
					if swo and not passedSWO[swo] then
						passedSWO[swo] = true
					end
				end
			end
		end
	end
	
	objs = self.spawned_corners[dir]
	for i = 1, #(objs or "") do
		if IsValid(objs[i]) then --can be gone
			objs[i]:SetColorFromRoom()
		end
	end
	
	if next(passedSWO) then
		--in some cases slabs need to recalibrate in computeslabvisibility, we need to pass after that
		postComputeBatch = postComputeBatch or {}
		postComputeBatch[#postComputeBatch + 1] = passedSWO
	end
	
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		ComputeSlabVisibilityInBox(wallBBox)
	end
	self:CreateAllCorners()
end

function OnMsg.SlabVisibilityComputeDone()
	if not postComputeBatch then return end
	
	local allPassed = {}
	for i, batch in ipairs(postComputeBatch) do
		for swo, _ in pairs(batch) do
			if not allPassed[swo] then
				allPassed[swo] = true
				swo:UpdateManagedSlabs()
				swo:UpdateManagedObj()
				swo:RefreshColors()
			end
		end
	end
	postComputeBatch = false
end

function TouchWallsAndWindowsHelper(objs)
	if not objs then return end
	table.validate(objs)
	for i = #(objs or empty_table), 1, -1 do
		local o = objs[i]
		o:AlignObj()
		if o.room == false then
			DoneObject(o)
		else
			o:UpdateSimMaterialId()
		end
	end
end

function Room:TouchWallsAndWindows(side)
	TouchWallsAndWindowsHelper(self.spawned_doors and self.spawned_doors[side])
	TouchWallsAndWindowsHelper(self.spawned_windows and self.spawned_windows[side])
end

function Room:TouchCorners(side)
	if side == "North" then
		self:RecreateNECornerBeam()
		self:RecreateNWCornerBeam()
	elseif side == "South" then
		self:RecreateSECornerBeam()
		self:RecreateSWCornerBeam()
	elseif side == "East" then
		self:RecreateSECornerBeam()
		self:RecreateNECornerBeam()
	elseif side == "West" then
		self:RecreateSWCornerBeam()
		self:RecreateNWCornerBeam()
	end
end

function GedOpViewRoom(socket, obj)
	if IsValid(obj) then
		Room.CenterCameraOnMe(nil, obj)
	else
		print("No room selected.")
	end
end

function GedOpNewVolume(socket, obj)
	print("Use f3 -> map -> new room or ctrl+shift+n instead. This method is no longer supported.")
end

function Room:SelectWall(side)
	self:ClearBoldedMarker()
	self.selected_wall = side
	local m = self.text_markers[side]
	m:SetTextStyle("EditorTextBold")
	m:SetColor(RGB(0, 255, 0))
	ObjModified(self)
end

function Room:ViewNorthWallFromOutside()
	self:SelectWall("North")
	self:ViewWall("North")
	ObjModified(self)
end

function Room:ViewSouthWallFromOutside()
	self:SelectWall("South")
	self:ViewWall("South")
	ObjModified(self)
end

function Room:ViewWestWallFromOutside()
	self:SelectWall("West")
	self:ViewWall("West")
	ObjModified(self)
end

function Room:ViewEastWallFromOutside()
	self:SelectWall("East")
	self:ViewWall("East")
	ObjModified(self)
end

function Room:ClearBoldedMarker()
	if self.selected_wall then
		local m = self.text_markers[self.selected_wall]
		m:SetTextStyle("EditorText")
		m:SetColor(RGB(255, 0, 0))
	end
end

function Room:ClearSelectedWall()
	self:ClearBoldedMarker()
	self.selected_wall = false
	ObjModified(self)
end

function GetSelectedRoom()
	--find a selected room..
	return SelectedRooms and SelectedRooms[1] or SelectedVolume
end

function SelectedRoomClearSelectedWall()
	local r = GetSelectedRoom()
	if IsValid(r) then
		r:ClearSelectedWall()
		print("Cleared selected wall")
	else
		print("No selected room found!")
	end
end

function SelectedRoomSelectWall(side)
	local r = GetSelectedRoom()
	if IsValid(r) then
		r:SelectWall(side)
		print(string.format("Selected wall %s of room %s", side, r.name))
	else
		print("No selected room found!")
	end
end

function SelectedRoomResetWallMaterials()
	local r = GetSelectedRoom()
	if IsValid(r) then
		if r.selected_wall then
			local side = r.selected_wall
			local matMember = string.format("%s_wall_mat", string.lower(side))
			local curMat = r[matMember]
			if curMat ~= defaultWallMat then
				r[matMember] = defaultWallMat
				local matPostSetter = string.format("OnSet%s", matMember)
				r[matPostSetter](r, defaultWallMat, curMat)
			end
		else
			r:ResetWallMaterials()
			print(string.format("Reset wall materials."))
		end
	else
		print("No selected room found!")
	end
end

function Room:CycleWallMaterial(delta, side)
	local mats
	local matMember = "wall_mat"
	if side then
		mats = SlabMaterialComboItemsWithDefault()()
		matMember = string.format("%s_wall_mat", string.lower(side))
	else
		mats = SlabMaterialComboItemsWithNone()()
	end
	local matPostSetter = string.format("OnSet%s", matMember)
	local curMat = self[matMember]
	local idx = table.find(mats, curMat) or 1
	local newIdx = idx + delta
	if newIdx > #mats then
		newIdx = 1
	elseif newIdx <= 0 then
		newIdx = #mats
	end
	local newMat = mats[newIdx]
	self[matMember] = newMat
	self[matPostSetter](self, newMat, curMat)
	print(string.format("Changed wall material of room %s side %s new material %s", self.name, side or "all", newMat))
end

function Room:CycleEntity(delta)
	local sw = self.selected_wall
	if not sw then
		self:CycleWallMaterial(delta)
		return
	end
	self:CycleWallMaterial(delta, sw)
end

function Room:UIDeleteDoors()
	self:DeleteWallObjs(self.spawned_doors, self.selected_wall)
end

function Room:UIDeleteWindows()
	self:DeleteWallObjs(self.spawned_windows, self.selected_wall)
end

local decalIdPrefix = "decal_lst_"
function Room:UIDeleteDecal(gedRoot, prop_id)
	local sh = string.gsub(prop_id, decalIdPrefix, "")
	local h = tonumber(sh)
	
	local t = self.spawned_decals[self.selected_wall]
	local idx = table.find(t, "handle", h)
	if idx then
		local d = t[idx]
		table.remove(t, idx)
		rawset(d, "safe_deletion", true)
		DoneObject(d)
		ObjModified(self)
	end
end

function Room:UISelectDecal(gedRoot, prop_id)
	local sh = string.gsub(prop_id, decalIdPrefix, "")
	local h = tonumber(sh)
	
	local t = self.spawned_decals[self.selected_wall]
	local idx = table.find(t, "handle", h)
	if idx then
		local d = t[idx]
		if d then
			editor.ClearSel()
			editor.AddToSel({d})
		end
	end
end

function Room:GetWallPos(dir, zOffset)
	local wallSize, wallPos
	local wsx = self.size:x() * voxelSizeX
	local wsy = self.size:y() * voxelSizeY
	local pos = self:GetPos()
	if zOffset then
		pos = pos:SetZ(pos:z() + zOffset)
	end
	
	if dir == "North" then
		wallPos = point(pos:x(), pos:y() - wsy / 2, pos:z())
		wallSize = wsx
	elseif dir == "South" then
		wallPos = point(pos:x(), pos:y() + wsy / 2, pos:z())
		wallSize = wsx
	elseif dir == "West" then
		wallPos = point(pos:x() - wsx / 2, pos:y(), pos:z())
		wallSize = wsy
	elseif dir == "East" then
		wallPos = point(pos:x() + wsx / 2, pos:y(), pos:z())
		wallSize = wsy
	end
	
	return wallPos, wallSize, pos
end

function Room:ViewWall(dir, inside)
	dir = dir or "North"
	local wallPos, wallSize, pos = self:GetWallPos(dir, self.size:z() * voxelSizeZ / 2)
	
	--fit wall to screen
	local fovX = camera.GetFovX()
	local a = (180 * 60 - fovX) / 2
	local wallWidth = wallSize
	local s = MulDivRound(wallWidth, sin(a), sin(fovX))
	local x = wallWidth / 2
	local dist = sqrt(s * s - x * x)
	
	local fovY = camera.GetFovY()
	a = (180 * 60 - fovY) / 2
	local wallHeight = self.size:z() * voxelSizeZ
	s = MulDivRound(wallHeight, sin(a), sin(fovY))
	x = wallHeight / 2
	dist = Max(sqrt(s * s - x * x), dist)
	
	local offset
	if inside then
		offset = pos - wallPos
	else
		offset = wallPos - pos
	end
	
	dist = dist + 3 * guim --some x margin so wall edge is not stuck to the screen edge
	offset = SetLen(offset, dist)
	offset = offset:SetZ(offset:z() + self.size:z() * voxelSizeZ * 3) --move eye up a little bit
	
	local cPos, cLookAt, cType = GetCamera()
	local cam = _G[string.format("camera%s", cType)]
	cam.SetCamera(wallPos + offset, wallPos, 1000, "Cubic out")
	
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
end

function Room.CenterCameraOnMe(_, self)
	local cPos, cLookAt, cType = GetCamera()
	local cOffs = cPos - cLookAt
	local mPos = self:GetPos()
	local cam = _G[string.format("camera%s", cType)]
	if cType == "Max" then
		local len = 20*guim * ((Max(self.size:x(), self.size:y()) / 10) + 1)
		cOffs = SetLen(cOffs, len)
	end
	cam.SetCamera(mPos + cOffs, mPos, 1000, "Cubic out")
	
	if rawget(terminal, "BringToTop") then
		return terminal.BringToTop()
	end
end

local defaultDecalProp = { category = "Materials", id = decalIdPrefix, name = "Decal ", editor = "text", default = "", read_only = true,
										buttons = {
											{name = "Delete", func = "UIDeleteDecal"},
											{name = "Select", func = "UISelectDecal"},
										},}

local function AddDecalPropsFromContainerHelper(self, props, container, idx, defaultProp)
	for i = 1, #container do
		local np = table.copy(defaultProp)
		local obj = container[i]
		np.id = string.format("%s%s", np.id, obj.handle)
		np.name = string.format("%s%s", np.name, obj:GetEntity())
		
		table.insert(props, idx + i, np)
	end
end

function Room:GetProperties()
	local decals = self.spawned_decals and self.spawned_decals[self.selected_wall]
	
	if #(decals or empty_table) > 0 then
		local p = table.copy(self.properties)
		
		if decals then
			local idx = table.find(p, "id", "place_decal")
			AddDecalPropsFromContainerHelper(self, p, decals, idx, defaultDecalProp)
		end
		
		return p
	else
		return self.properties
	end
end

function Room:GenerateName()
	return string.format("Room %d%s", self.handle, self:IsRoofOnly() and " - Roof only" or "")
end

function Room:Init()
	self.name = self.name or self:GenerateName()
	
	if self.auto_add_in_editor then
		self:AddInEditor()
	end
end

function ComputeVisibilityOfNearbyShelters()
	--stub
end

function Room:ClearRoomAdjacencyData()
	self:ClearAdjacencyData()
end

function Room:RoomDestructor()
	Msg("RoomDone", self)
	local wasPermanent = self:GetGameFlags(const.gofPermanent) ~= 0
	self:ClearGameFlags(const.gofPermanent) --this is to dodge this assert -> assert(false, "Passability rebuild provoked from destructor! Obj class: " .. (obj.class or "N/A"))
	self:DeleteAllSpawnedObjs()
	self:ClearRoomAdjacencyData()
	
	if GedRoomEditor then
		table.remove_entry(GedRoomEditorObjList, self)
		ObjModified(GedRoomEditorObjList)
		if SelectedVolume == self then
			SetSelectedVolumeAndFireEvents(false)
			--todo: this does not work to clear the props pane
			GedRoomEditor:UnbindObjs("SelectedObject")
			ObjModified(GedRoomEditorObjList)
		end
	end
	
	if wasPermanent then
		ComputeSlabVisibilityInBox(self.box) --since we are no longer gofPermanent, call directly
		ComputeVisibilityOfNearbyShelters(self.box)
	end
	self["RoomDestructor"] = empty_func
end

function Room:ComputeRoomVisibility()
	if self:GetGameFlags(const.gofPermanent) ~= 0 then
		ComputeSlabVisibilityInBox(self.box)
	end
end

function Room:OnEditorDelete()
	self:VolumeDestructor()
	self:RoomDestructor()
end

function Room:Done()
	self:RoomDestructor()
	self.spawned_walls = nil
	self.spawned_corners = nil
	self.spawned_floors = nil
	self.spawned_doors = nil
	self.spawned_windows = nil
	self.spawned_decals = nil
end

function Room:AddInEditor()
	if GedRoomEditor then
		table.insert_unique(GedRoomEditorObjList, self)
		ObjModified(GedRoomEditorObjList)
	end
end

function WallObjToNestedListEntry(d, cls)
	cls = cls or "DoorNestedListEntry"
	local entry = PlaceObject(cls)
	entry.linked_obj = d
	entry.width = d.width
	entry.material = d.material
	entry.subvariant = d.subvariant or 1
	return entry
end

function Room:TestCorners()
	for k, v in NSEW_pairs(self.spawned_corners or empty_table) do
		for i = 1, #v do
			if not IsValid(v[i]) then
				print(k, v[i])
			end
		end
	end
end

function Room:AssignPropValuesToMySlabs()
	-- assign prop values that are convenient to have per slab but are not saved per slab
	local reposition = RepositionWallSlabsOnLoad
	for i = 1, #room_NSWE_lists do
		for side, objs in NSEW_pairs(self[room_NSWE_lists[i]] or empty_table) do
			local isDecals = "spawned_decals" == room_NSWE_lists[i]
			local isCorners = "spawned_corners" == room_NSWE_lists[i]
			local isWalls = "spawned_walls" == room_NSWE_lists[i]
			local isFloors = "spawned_floors" == room_NSWE_lists[i]
			local isWindows = "spawned_windows" == room_NSWE_lists[i]
			local isDoors = "spawned_doors" == room_NSWE_lists[i]
			for j = 1, #objs do
				local obj = objs[j]
				if obj then
					obj.room = self
					obj.side = side
					obj.floor = self.floor
					
					if not isDecals then -- could be a decal from spawned_decals
						obj.invulnerable = obj.forceInvulnerableBecauseOfGameRules
					end
					
					if isCorners and j == #objs then
						obj.isPlug = true -- last one is always a plug
					end
					if isWalls or isCorners then
						obj:DelayedUpdateEntity() -- call this after room is set for the correct seed
					end
					if isWalls then
						obj:DelayedUpdateVariantEntities() -- default colors are not available 'till .room gets assigned, this will reapply them to attaches
					end
					
					if reposition and isWalls then
						obj:SetPos(self:GetWallSlabPos(side, j))
					end
				end
			end
		end
	end
	
	local floorsAreCO = g_Classes.CombatObject and IsKindOf(FloorSlab, "CombatObject")
	for i = 1, #room_regular_lists do
		local isFloors = room_regular_lists[i] == "spawned_floors"
		local t = self[room_regular_lists[i]] or empty_table
		local side = room_regular_list_sides[i]
		for j = #t, 1, -1 do
			local o = t[j]
			if o then
				o.room = self
				o.side = side
				o.floor = self.floor
				o.invulnerable = o.forceInvulnerableBecauseOfGameRules
				
				if isFloors then
					o:DelayedUpdateEntity() -- these now have random ents as well, so rerandomize after seed is setup
				end
			end
		end
	end
end

function Room:CreateAllCorners()
	self:RecreateNECornerBeam()
	self:RecreateNWCornerBeam()
	self:RecreateSWCornerBeam()
	self:RecreateSECornerBeam()
end

-- used manually when resaving maps from old schema to new shcema
function RecreateAllCornersAndColors()
	MapForEach("map", "RoomCorner", DoneObject)
	MapForEach("map", "Room", function(room)
		room:RecreateWalls()
		room:RecreateFloor()
		room:RecreateRoof()
		room:OnSetouter_colors(room.outer_colors)
		room:OnSetinner_colors(room.inner_colors)
	end)
end

function RefreshAllRoomColors()
	MapForEach("map", "Room", function(room)
		room:OnSetouter_colors(room.outer_colors)
		room:OnSetinner_colors(room.inner_colors)
	end)
end

function Room:SaveFixups()
	local hasCeiling = type(self.roof_objs) == "table" and IsKindOf(self.roof_objs[#self.roof_objs], "CeilingSlab") or false
	if not self.build_ceiling and hasCeiling then
		-- tweaked this default value, so now there are blds with disabled ceiling who have ceilings
		-- because we avoid touching roofs during load they remain
		while IsKindOf(self.roof_objs[#self.roof_objs], "CeilingSlab") do
			local o = self.roof_objs[#self.roof_objs]
			self.roof_objs[#self.roof_objs] = nil
			DoneObject(o)
		end
	end
end

function Room:Getlocked_slabs_count()
	local total, locked = 0, 0
	
	local function iterateAndCount(t)
		for i = 1, #(t or "") do
			local slab = t[i]
			if IsValid(slab) and slab.isVisible then
				total = total + 1
				locked = locked + (slab.subvariant ~= -1 and 1 or 0)
			end
		end
	end
	
	local function iterateAndCountNSEW(objs)
		for side, t in NSEW_pairs(objs or empty_table) do
			iterateAndCount(t)
		end
	end
	
	iterateAndCountNSEW(self.spawned_walls)
	local ws = string.format("%d/%d walls", locked, total)
	locked, total = 0, 0
	iterateAndCountNSEW(self.spawned_corners)
	local cs = string.format("%d/%d corners", locked, total)
	locked, total = 0, 0
	iterateAndCount(self.spawned_floors)
	local fs = string.format("%d/%d floors", locked, total)
	locked, total = 0, 0
	iterateAndCount(self.roof_objs)
	local rs = string.format("%d/%d roof objs", locked, total)
	
	return string.format("%s; %s; %s; %s;", ws, cs, fs, rs)
end

function Room:LockAllSlabsToCurrentSubvariants()
	-- goes through all slabs and switches -1 subvariant val to their current subvariant.
	-- this will lock those variants in case of random generator changes
	
	local function iterateAndSet(t)
		for i = 1, #(t or "") do
			local slab = t[i]
			if IsValid(slab) and slab.isVisible then
				slab:LockSubvariantToCurrentEntSubvariant()
			end
		end
	end
	
	local function iterateAndSetNSEW(objs)
		for side, t in NSEW_pairs(objs or empty_table) do
			iterateAndSet(t)
		end
	end
	
	iterateAndSetNSEW(self.spawned_walls)
	iterateAndSetNSEW(self.spawned_corners)
	iterateAndSet(self.spawned_floors)
	iterateAndSet(self.roof_objs)
	ObjModified(self)
end

local function extractCpyId(str)
	local r = string.gmatch(str, "copy%d+")()
	return r and tonumber(string.gmatch(r, "%d+")()) or 0
end

function Room:GenerateNameWithCpyTag()
	local n = self.name
	local pid = extractCpyId(n)
	local topId = pid
	EnumVolumes(function(v, n, find, sub)
		local hn = v.name
		local mn = n
		if #hn < #mn then
			mn = string.sub(mn, 1, #hn)
		elseif #hn > #mn then
			hn = string.sub(hn, 1, #mn)
		end
		
		if hn == mn then
			local hpid = extractCpyId(v.name)
			if hpid > topId then
				topId = hpid
			end
		end
	end, string.gsub(n, " copy%d+", ""), string.find, string.sub)
	
	local tag = string.format("copy%d", tonumber(topId) + 1)
	if pid == 0 then
		return string.format("%s %s", self.name, tag)
	else
		return string.gsub(self.name, "copy%d+", tag)
	end
end

function Room:PostLoad(reason)
	if reason == "paste" then
		self:Setname(self:GenerateNameWithCpyTag())
	end
	
	SuspendPassEdits("Room:PostLoad")
	
	self:SaveFixups()
	self:InternalAlignObj()
	self:SetWarped(self:GetWarped(), true)
	self:AssignPropValuesToMySlabs() -- sets slab properties that are not saved - .room, .side, etc.
	
	self:RecalcRoof()
	self:ComputeRoomVisibility()
	
	ResumePassEdits("Room:PostLoad")
end

function Room:OnWallObjDeletedOutsideOfGedRoomEditor(obj)
	local dir = slabAngleToDir[obj:GetAngle()]
	local t = self[obj:IsDoor() and string.format("placed_doors_nl_%s", string.lower(dir)) or string.format("placed_windows_nl_%s", string.lower(dir))]
	local container = obj:IsDoor() and self.spawned_doors or self.spawned_windows
	if container then
		for i = 1, #(t or empty_table) do
			if t[i].linked_obj == obj then
				DoneObject(t[i])
				table.remove(t, i)
				table.remove_entry(container[dir], obj)
				return
			end
		end
	elseif Platform.developer then
		local cs = obj:IsDoor() and "spawned_doors" or "spawned_windows"
		local dirFound
		local r = MapGetFirst("map", "Room", function(o, cs, obj, et)
			for side, t in sorted_pairs(o[cs] or et) do
				if table.find(t or et, obj) then
					dirFound = side
					return true
				end
			end
		end, cs, obj, empty_table)
		
		if r then
			print(string.format("Wall obj was found in room %s, side %s container", r.name, dirFound))
		else
			print("Wall obj was not found in any room container")
		end
		
		assert(false, string.format("Room %s had no contaier initialized for wall obj with entity %s, deduced side %s, member side %s", self.name, obj.entity, dir, obj.side))
	end
end

local dirs = { "North", "East", "South", "West" }
function rotate_direction(direction, angle)
	local idx = table.find(dirs, direction)
	if not idx then return direction end
	idx = idx + angle / (90 * 60)
	if idx > 4 then idx = idx - 4 end
	return dirs[idx]
end

function Room:EditorRotate(center, axis, angle, last_angle)
	angle = angle - last_angle
	if axis:z() < 0 then angle = -angle end
	angle = (angle + 360 * 60 + 45 * 60 ) / (90 * 60) * (90 * 60)
	while angle >= 360 * 60 do angle = angle - 360 * 60 end
	if axis:z() == 0 or angle == 0 then return end

	-- rotate room properties
	local a = center + Rotate(self.box:min() - center, angle)
	local b = center + Rotate(self.box:max() - center, angle)
	self.box = boxdiag(a, b)
	self.position = self.box:min()
	local x, y, z = self.box:size():xyz()
	self.size = point(x / voxelSizeX, y / voxelSizeY, z / voxelSizeZ)
	
	-- rotate roof properties
	if self:GetRoofType() == "Gable" then
		if angle == 90 * 60 or angle == 270 * 60 then
			self.roof_direction = self.roof_direction == GableRoofDirections[1] and GableRoofDirections[2] or GableRoofDirections[1]
		end
	elseif self:GetRoofType() == "Shed" then
		self.roof_direction = rotate_direction(self.roof_direction, angle)
	end
	
	-- rotate slabs
	self:ForEachSpawnedObj(function(obj, center, angle)
		local new_angle = 0
		if not IsKindOf(obj, "FloorAlignedObj") then
			new_angle = obj:GetAngle() + angle
		end
		obj:SetPosAngle(center + Rotate(obj:GetPos() - center, angle), new_angle)
		obj.side = rotate_direction(obj.side, angle)
		if obj:IsKindOf("SlabWallObject") then obj:UpdateManagedObj() end
	end, center, angle)
	
	-- assign slabs to the proper lists after rotation
	local d = table.copy(dirs)
	while angle >= 90 * 60 do
		d[1], d[2], d[3], d[4] = d[2], d[3], d[4], d[1]
		angle = angle - 90 * 60
	end
	for i = 1, #room_NSWE_lists do
		local lists = self[room_NSWE_lists[i]]
		if lists then
			lists[d[1]], lists[d[2]], lists[d[3]], lists[d[4]] = lists.North, lists.East, lists.South, lists.West
		end
	end
	self:InternalAlignObj()
	self:RecreateRoof()
end

function OnMsg.GedClosing(ged_id)
	if GedRoomEditor and GedRoomEditor.ged_id == ged_id then
		GedRoomEditor = false
		GedRoomEditorObjList = false
	end
end

function OnMsg.GedOnEditorSelect(obj, selected, editor)
	if editor == GedRoomEditor then
		SetSelectedVolumeAndFireEvents(selected and obj or false)
	end
end

function OpenGedRoomEditor()
	CreateRealTimeThread(function()
		if not IsValid(GedRoomEditor) then
			GedRoomEditorObjList = MapGet("map", "Room") or {}
			table.sortby_field(GedRoomEditorObjList, "name")
			table.sortby_field(GedRoomEditorObjList, "structure")
			GedRoomEditor = OpenGedApp("GedRoomEditor", GedRoomEditorObjList) or false
		end
	end)
end

function OnMsg.ChangeMap()
	if GedRoomEditor then
		GedRoomEditor:Send("rfnClose")
		GedRoomEditor = false
	end
end
--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
DefineClass.SlabPreset = {
	__parents = { "Preset", },
	properties = {
		{ id = "Group", no_edit = false, },
	},
	HasSortKey = false,
	PresetClass = "SlabPreset",
	NoInstances = true,
	EditorMenubarName = "Slab Presets",
	EditorMenubar = "Editors.Art",
}

DefineClass.SlabMaterialSubvariant = {
	__parents = {"PropertyObject"},
	properties = {
		{ id = "suffix", name = "Suffix", editor = "text", default = "01" },
		{ id = "chance", name = "Chance", editor = "number", default = 100 },
	},
}

--------------------------------------------------------------------------
--------------------------------------------------------------------------
--------------------------------------------------------------------------
function TouchAllRoomCorners()
	MapForEach("map", "Room", function(o)
		o:TouchCorners("North")
		o:TouchCorners("South")
		o:TouchCorners("West")
		o:TouchCorners("East")
	end)
end

DefineClass.HideOnFloorChange = {
	__parents = { "Object" },
	properties = {
		{ id = "floor", name = "Floor", editor = "number", min = -10, max = 100, default = 1, dont_save = function (obj) return obj.room end },
	},
	room = false,
	invisible_reasons = false,
}

function HideOnFloorChange:Getfloor()
	local room = self.room
	return room and room.floor or self.floor
end

HideSlab = false -- used only if defined

function HideFloorsAbove(floor, fnHide)
	SuspendPassEdits("HideFloorsAbove")
	HideFloorsAboveC(floor, fnHide or HideSlab or nil)
	Msg("FloorsHiddenAbove", floor, fnHide)
	ResumePassEdits("HideFloorsAbove")
end

function CountRoomSlabs()
	local t = 0
	MapForEach("map", "Room", function(o)
		t = t + (o.size:x() + o.size:y()) * 2 * o.size:z()
	end)
	
	return t
end

function CountMirroredSlabs()
	local t, tm = 0, 0
	
	MapForEach("map", "WallSlab", function(o)
		if o:CanMirror() and o:GetEnumFlags(const.efVisible) ~= 0 then
			if o:GetGameFlags(const.gofMirrored) ~= 0 then
				tm = tm + 1
			else
				t = t + 1
			end
		end
	end)
	
	return t, tm
end

function BuildBuildingsData()
end

function DbgWindowDoorOwnership()
	MapForEach("map", "SlabWallObject", function(o)
		if o.room then
			DbgAddVector(o:GetPos(), o.room:GetPos() - o:GetPos())
		else
			DbgAddVector(o:GetPos())
		end
	end)
end
