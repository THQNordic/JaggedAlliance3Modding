local function FindHighestRoof(obj)
	local pos = obj:GetVisualPos()
	local highest_room, highest_z, highest_pt_dir = false, 0, 0
	MapForEach(pos, roomQueryRadius, "Room", function(room, pos)
		if not IsPointInVolume2D(room, pos) then return end
		
		local z, dir = room:GetRoofZAndDir(pos)
		if not IsKindOf(obj, "Decal") then
			local thickness = room:GetRoofThickness()
			z = z + thickness
		end
		
		if z < highest_z then return end
		
		highest_z = z 
		highest_room = room
		highest_pt_dir = dir
	end, pos)
	
	return highest_room, highest_z, highest_pt_dir
end

function editor.ToggleDontHideWithRoom()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end
	
	XEditorUndo:BeginOp{ objects = sel, "Set hide with room" }
	local set = 0
	local cleared = 0
	for i = 1, #sel do
		local obj = sel[i]
		if obj:GetGameFlags(const.gofDontHideWithRoom) == 0 then
			obj:SetDontHideWithRoom(true)
			set = set + 1
		else
			obj:SetDontHideWithRoom(false)
			cleared = cleared + 1
		end
	end
	
	print("Set flag to " .. tostring(set) .. " objects.")
	print("Cleared flag from " .. tostring(cleared) .. " objects.")
	XEditorUndo:EndOp(sel)
end

function editor.ClearRoofFlags()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Set roof OFF" }
	
	for i = 1, #sel do
		local obj = sel[i]
		
		obj:ClearHierarchyGameFlags(const.gofOnRoof)
	end
	print("CLEARED objects' roof flags")
	XEditorUndo:EndOp(sel)
end

function editor.SnapToRoof()
	local sel = editor:GetSel()
	if #sel < 1 then
		return
	end

	XEditorUndo:BeginOp{ objects = sel, name = "Set roof ON" }
	local counter = 0
	
	for i = 1, #sel do
		local obj = sel[i]
		
		if obj:GetGameFlags(const.gofOnRoof) == 0 then
			counter = counter + 1
			obj:SetHierarchyGameFlags(const.gofOnRoof)
		end
	end
	
	if counter > 0 then
		print(tostring(counter) .. " objects MARKED as OnRoof objects out of " .. tostring(#sel))
		XEditorUndo:EndOp(sel)
		return
	end
	
	SuspendPassEditsForEditOp()
	local new_position = { }
	local new_up = { }
	
	for i = 1, #sel do
		local obj = sel[i]
		
		local highest_roof = FindHighestRoof(obj)
		if highest_roof then
			local target_pos, target_up = highest_roof:SnapObject(obj)
			new_position[obj] = target_pos
			new_up[obj] = target_up
			counter = counter + 1
		end
	end
	print(tostring(counter) .. " objects SNAPPED to roof out of " .. tostring(#sel))
	--editor callbacks
	local objects = {}
	local cfEditorCallback = const.cfEditorCallback
	for i = 1, #sel do
		if sel[i]:GetClassFlags(cfEditorCallback) ~= 0 then
			objects[#objects + 1] = sel[i]
		end
	end
	if #objects > 0 then
		Msg("EditorCallback", "EditorCallbackMove", objects)
	end
	
	XEditorUndo:EndOp(sel)
	ResumePassEditsForEditOp()
	
	for i = 1, #sel do
		local obj = sel[i]
		
		local pos = obj:GetPos()
		local wrong_pos = new_position[obj] and new_position[obj] ~= pos
		
		local wrong_angle
		local up = RotateAxis(point(0, 0, 4096), obj:GetAxis(), obj:GetAngle())
		if new_up[obj] then
			local axis, angle = GetAxisAngle(new_up[obj], up)
			wrong_angle = (angle > 0)
		end
		
		local obj_name = IsKindOf(obj, "CObject") and obj:GetEntity() or obj.class
		local aligned_obj = IsKindOf(obj, "AlignedObj")
		
		if wrong_pos then
			local err = "not snapped to the roof Z"
			if aligned_obj then
				err = err .. " (AlignedObj)"
			end
			print(obj_name, err)
		end
		
		if wrong_angle then
			local err = "not aligned with the roof slope"
			print(obj_name, err)
		end
	end
end
