DefineClass.XStickToObjsBase = {
	__parents = { "XObjectPlacementHelper" },
	
	InXPlaceObjectTool = true,
	InXSelectObjectsTool = true,
	AllowRotationAfterPlacement = true,
	HasSnapSetting = true,
	
	pivot_obj_id = false,
	intersection_class = "WallSlab",
	set_angle = true,
}

function XStickToObjsBase:StartMoveObjects(mouse_pos, objects)
	local cur_pos = GetTerrainCursor()
	local bestIp = false
	local bestId = -1
	local eye = camera.GetEye()
	local cursor = ScreenToGame(mouse_pos)
	local sp = eye
	local ep = (cursor - eye) * 1000 + cursor
	self.init_move_positions = {}
	self.init_orientations = {}
	for i, o in ipairs(objects) do
		local hisPos = o:GetPos()
		if not hisPos:IsValid() then
			o:SetPos(cur_pos)
			hisPos = cur_pos
		end
		self.init_move_positions[i] = hisPos
		self.init_orientations[i] = { o:GetOrientation() }
		
		local ip1, ip2 = ClipSegmentWithBox3D(sp, ep, o)
		if ip1 and (bestId == -1 or IsCloser(sp, ip1, bestIp)) then
			bestIp = ip1
			bestId = i
		end
	end
	
	if bestId == -1 then
		bestId = 1 --that sux, no obj crossed the ray from camera
	end
	
	self.pivot_obj_id = bestId
	self.init_drag_position = objects[bestId]:GetPos():SetTerrainZ()
end

function XStickToObjsBase:MoveObjects(mouse_pos, objects)
	local vMove = (GetTerrainCursor() - self.init_drag_position):SetZ(0)
	for i, obj in ipairs(objects) do
		local offset = self.init_move_positions[i] - self.init_move_positions[self.pivot_obj_id]
		if not offset:z() then
			offset = offset:SetZ(0)
		end
		local eye = camera.GetEye()
		local cursor = ScreenToGame(mouse_pos)
		local sp = eye + offset
		local ep = (cursor - eye) * 1000 + cursor + offset
		local objs = IntersectObjectsOnSegment(sp, ep, 0, self.intersection_class, function(o)
			if not o.isVisible then
				return rawget(o, "wall_obj") == obj
			end
			return true
		end)
		--[[DbgClear()
		print(eye)
		DbgAddVector(eye, cursor - eye, RGB(255, 0, 0))
		DbgAddVector(sp, ep - sp)
		if objs and objs[1] then
			DbgAddBox(objs[1]:GetObjectBBox())
		end]]
		
		if objs and #objs > 0 then
			local closest = objs[1]
			local p1, p2 = ClipSegmentWithBox3D(sp, ep, closest)
			local ip = closest:GetPos()
			if p1 then
				ip = p1 == sp and p2 or p1
			end
			local angle = closest:GetAngle()
			local x, y, z
			if XEditorSettings:GetSnapEnabled() then
				x, y, z, angle = WallWorldToVoxel(ip:x(), ip:y(), ip:z(), angle)
				x, y, z = WallVoxelToWorld(x, y, z, angle)
			else
				x, y, z = ip:xyz()
			end
			if IsKindOf(obj, "AlignedObj") then
				obj:AlignObj(point(x, y, z), self.set_angle and angle or nil)
			else
				if self.set_angle then
					obj:SetPosAngle(x, y, z, angle)
				else
					obj:SetPos(x, y, z)
				end
			end
			
		else
			local pos = (self.init_move_positions[i] + vMove):SetTerrainZ()
			if IsKindOf(obj, "AlignedObj") then
				obj:AlignObj(pos)
			else
				obj:SetPos(pos)
			end
		end
		
	end
	Msg("EditorCallback", "EditorCallbackMove", objects)
end

DefineClass.XStickToWallsHelper = {
	__parents = { "XStickToObjsBase" },
	
	Title = "Stick to walls (Y)",
	Description = false,
	ActionSortKey = "6",
	ActionIcon = "CommonAssets/UI/Editor/Tools/StickToWall.tga",
	ActionShortcut = "Y",
	UndoOpName = "Stuck %d object(s) to wall",
	
	intersection_class = "WallSlab",
	set_angle = true,
}

DefineClass.XStickToFloorsHelper = {
	__parents = { "XStickToObjsBase" },
	
	Title = "Stick to floors (U)",
	Description = false,
	ActionSortKey = "7",
	ActionIcon = "CommonAssets/UI/Editor/Tools/StickToFloor.tga",
	ActionShortcut = "U",
	UndoOpName = "Stuck %d object(s) to floor",
	
	intersection_class = "FloorSlab",
	set_angle = false,
}
