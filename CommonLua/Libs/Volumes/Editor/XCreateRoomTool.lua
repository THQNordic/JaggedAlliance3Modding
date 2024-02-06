if not const.SlabSizeX then return end

DefineClass.XCreateRoomTool = {
	__parents = { "XEditorTool" },
	properties = {
		{ id = "RoofOnly", name = "Roof only", editor = "bool", default = false, persisted_setting = true, },
	},

	ToolTitle = "Create Room",
	Description = {
		"(drag to place a room)\n" ..
		"(<style GedHighlight>hold Ctrl</style> to force placing a roof only)",
	},
	UsesCodeRenderables = true,
	
	room = false,
	room_terrain_z = 0,
	start_pos = false,
	vxs = 0,
	vys = 0,
}

function XCreateRoomTool:Done()
	if self.room then -- tool destroyed while dragging
		DoneObject(self.room)
	end
end

function XCreateRoomTool_PlaceRoom(props)
	return PlaceObject("Room", props)
end

function XCreateRoomTool:OnMouseButtonDown(pt, button)
	if button == "L" then
		local startPos = GetTerrainCursor()
		local is_roof = self:GetRoofOnly() or terminal.IsKeyPressed(const.vkControl)
		local props = { floor = 1, position = SnapVolumePos(startPos), size = point(1, 1, is_roof and 0 or defaultVolumeVoxelHeight), 
							auto_add_in_editor = false, wireframe_visible = true, being_placed = true }
		local room = XCreateRoomTool_PlaceRoom(props)
		local gz = room:LockToCurrentTerrainZ()
		room:InternalAlignObj("test")
		if room:CheckCollision() then
			room.wireframeColor = RGB(255, 0, 0)
		else
			room.wireframeColor = RGB(0, 255, 0)
		end
		room:GenerateGeometry()
		
		self.room = room
		self.start_pos = startPos
		self.vxs, self.vys = WorldToVoxel(startPos)
		self.room_terrain_z = gz
		self.desktop:SetMouseCapture(self)
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

local function MinMaxPtXY(f, p1, p2)
	return point(f(p1:x(), p2:x()), f(p1:y(), p2:y()))
end

function XCreateRoomTool:OnMousePos(pt, button)
	local room = self.room
	if room then
		local pNew = GetTerrainCursor()
		local pMin = MinMaxPtXY(Min, pNew, self.start_pos)
		local pMax = MinMaxPtXY(Max, pNew, self.start_pos)
		local change = false
		local moved = false
		pMin = pMin:SetZ(terrain.GetHeight(pMin))
		pMax = pMax:SetZ(terrain.GetHeight(pMax))
		pMin = SnapVolumePos(pMin)
		
		local vxMin, vyMin = WorldToVoxel(pMin)
		local vxMax, vyMax = WorldToVoxel(pMax)
		local pos = room.position
		
		if pos:x() ~= pMin:x() or pos:y() ~= pMin:y() then
			moved = pMin - (pos or pMin)
			moved = moved:SetZ(0)
			rawset(room, "position", pMin:SetZ(self.room_terrain_z))
			change = true
		end
		
		local xSize = Max((pMax:x() - pMin:x()) / const.SlabSizeX, 1)
		local ySize = Max((pMax:y() - pMin:y()) / const.SlabSizeY, 1)
		
		if vxMin ~= self.vxs or vxMax ~= self.vxs then
			xSize = xSize + 1
		end
		if vyMin ~= self.vys or vyMax ~= self.vys then
			ySize = ySize + 1
		end
		
		local newSize = point(xSize, ySize, room.size:z())
		local oldSize = room.size
		if room.size ~= newSize then
			rawset(room, "size", newSize)
			change = true
		end
		
		if change then
			room:InternalAlignObj("test")
			if room:CheckCollision() then
				room.wireframeColor = RGB(255, 0, 0)
			else
				room.wireframeColor = RGB(0, 255, 0)
			end
			room:GenerateGeometry()
		end	
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

function XCreateRoomTool:OnMouseButtonUp(pt, button)
	local room = self.room
	if room then
		XEditorUndo:BeginOp{ name = "Created room" }
		
		room.wireframeColor = nil
		room.wireframe_visible = false
		room:OnSetwireframe_visible()
		room.being_placed = false
		room:AddInEditor()
		if room.wall_mat ~= const.SlabNoMaterial or room.floor_mat ~= const.SlabNoMaterial then
			room:CreateAllSlabs()
		end
		room:FinishAlign()
		SetSelectedVolume(room)
		BuildBuildingsData()
		
		XEditorUndo:EndOp{ room }
		self.desktop:SetMouseCapture()
		self.room = nil
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end
