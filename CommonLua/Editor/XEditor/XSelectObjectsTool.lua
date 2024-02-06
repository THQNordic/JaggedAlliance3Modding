-- dummy placement helper for the default "Select" mode
DefineClass.XSelectObjectsHelper = {
	__parents = { "XEditorPlacementHelper" },

	InXSelectObjectsTool = true,
	HasSnapSetting = true,
	Title = "Edit objects (Q)",
	ActionIcon = "CommonAssets/UI/Editor/Tools/SelectObjects.tga",
	ActionShortcut = "Escape",
	ActionShortcut2 = "Q",
}

DefineClass.XSelectObjectsTool = {
	__parents = { "XEditorTool", "XEditorPlacementHelperHost", "XEditorRotateLogic", "XSelectObjectsToolCustomFilter" },
	
	ToolTitle = "Edit objects",
	ToolSection = "Objects",
	Description = function(self)
		local descr = self and self.placement_helper:GetDescription()
		if descr then return { descr } end
		return { "(hold <style GedHighlight>Ctrl</style> to clone, <style GedHighlight>Alt</style> to rotate, <style GedHighlight>Shift</style> to scale)\n(use <style GedHighlight>[</style> and <style GedHighlight>]</style> to cycle between object variants)\n(<style GedHighlight>Alt-DblClick</style> to select/filter by class)" }
	end,
	ActionIcon = "CommonAssets/UI/Editor/Tools/SelectObjects.tga",
	ActionSortKey = "01",
	ActionShortcut = "Q",
	ToolKeepSelection = true,
	
	helper_class = "XSelectObjectsHelper",
	edit_operation = false,
	highlighted_objs = false,
	selection_box = false,
	selection_box_mesh = false,
	selection_box_enable = false,
	editing_line_mesh = false,
	init_selection = false,
	init_mouse_pos = false,
	init_move_positions = false,
	init_rotate_data = false,
	init_scales = false,
	last_mouse_pos = false,
	last_mouse_obj = false,
	last_mouse_click = false,
}

function XSelectObjectsTool:Init()
	self:CreateThread("fixup_hovered_object", self.FixupHoveredObject, self)
end

function XSelectObjectsTool:Done()
	self.desktop:SetMouseCapture() -- finalize pending operation
	self:HighlightObjects(false)
end

function XSelectObjectsTool:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "WireCurve" then
		Msg("WireCurveTypeChanged", self:GetProperty("WireCurve"), old_value)
	end
end

function XSelectObjectsTool:UpdatePlacementHelper()
	local helper = self.placement_helper
	helper.local_cs = helper.HasLocalCSSetting and GetLocalCS()
	helper.snap = helper.HasSnapSetting and XEditorSettings:GetSnapEnabled()
	XEditorUpdateToolbars()
end

function XSelectObjectsTool:CantSnapObjects()
	return not g_Classes[self:GetHelperClass()].HasSnapSetting and "This mode does not support snapping."
end

function XSelectObjectsTool:HighlightObjects(objs)
	objs = XEditorSettings:GetHighlightOnHover() and objs
	local highlighted = {}
	if objs then
		objs = editor.SelectionPropagate(objs, "for_rollover")
		for _, obj in ipairs(objs) do
			if IsValid(obj) then
				if IsKindOf(obj, "CollideLuaObject") then
					obj:SetHighlighted(true)
				else
					obj:SetHierarchyGameFlags(const.gofEditorHighlight)
				end
				highlighted[obj] = true
			end
		end
	end
	for _, obj in ipairs(self.highlighted_objs) do
		if IsValid(obj) and not highlighted[obj] then
			if IsKindOf(obj, "CollideLuaObject") then
				obj:SetHighlighted(false)
			else
				obj:ClearHierarchyGameFlags(const.gofEditorHighlight)
			end
		end
	end
	self.highlighted_objs = objs and table.copy(objs)
end

function XSelectObjectsTool:StartEditOperation(operation)
	if not self.edit_operation then
		XEditorUndo:BeginOp({
			name = operation == "PlacementHelper" and
				string.format(self.placement_helper.UndoOpName, #editor.GetSel()) or
				string.format("%sd %d object(s)", operation, #editor.GetSel()),
			objects = operation == "Clone" and empty_table or editor.GetSel(),
			edit_op = true,
		})
		SuspendPassEditsForEditOp()
		self.edit_operation = operation
	end
end

function XSelectObjectsTool:EndEditOperation()
	if self.edit_operation then
		ResumePassEditsForEditOp()
		local sel = editor.GetSel()
		editor.SetSel(editor.SelectionPropagate(sel))
		XEditorUndo:EndOp(sel)
		self.edit_operation = false
	end
end

function XSelectObjectsTool:SelectNextObjectAtCursor()
	XEditorUndo:BeginOp()
	local obj = XEditorSelectSingleObjects == 1 and
		GetNextObjectAtScreenPos(CanSelect, "topmost", selo()) or
		GetNextObjectAtScreenPos(CanSelect, "topmost", "collection", selo())
	editor.SetSel(editor.SelectionPropagate({obj}))
	XEditorUndo:EndOp()
end

function XSelectObjectsTool:OnMouseButtonDoubleClick(pt, button)
	local obj = GetObjectAtCursor()
	if button == "L" and obj then
		if terminal.IsKeyPressed(const.vkRalt) then
			self:SelectNextObjectAtCursor()
			return "break"
		elseif terminal.IsKeyPressed(const.vkAlt) then
			local sel = table.copy(editor.GetSel())
			XEditorUndo:BeginOp()
			
			-- if selection is a single object, select objects of that class on the screen; otherwise, filter current selection
			if #sel == 1 or terminal.IsKeyPressed(const.vkShift) then
				if not terminal.IsKeyPressed(const.vkShift) then
					editor.ClearSel()
				end
				local locked = Collection.GetLockedCollection()
				editor.AddToSel(XEditorGetVisibleObjects(function(o)
					return o.class == obj.class and (not locked or o:GetRootCollection() == locked)
				end))
			else
				for i = #sel, 1, -1 do
					if sel[i].class ~= obj.class then
						table.remove(sel, i)
					end
				end
				editor.ClearSel()
				editor.AddToSel(sel)
			end
			
			XEditorUndo:EndOp()
			return "break"
		end
	end
end

function XSelectObjectsTool:OnMouseButtonDown(pt, button)
	self:SetFocus()
	
	if XEditorPlacementHelperHost.OnMouseButtonDown(self, pt, button) then
		XPopupMenu.ClosePopupMenus()
		return "break"
	end
	
	if button == "L" then
		XPopupMenu.ClosePopupMenus()
		self.desktop:SetMouseCapture(self)
		
		local obj = GetObjectAtCursor()
		local terrain_pos = GetTerrainCursor()
		self.init_mouse_pos = { terrain = terrain_pos, screen = pt, time = GetPreciseTicks() }
		if obj then -- prepare data for a move operation
			local ptBase = obj:GetPos():SetTerrainZ()
			local _, ptScreenAtBase = GameToScreen(ptBase)
			self.init_mouse_pos.mouse_offset = ptScreenAtBase - pt
			self.init_mouse_pos.terrain_base = ptBase
		end
		self.last_mouse_click = terrain_pos
		
		if obj and terminal.IsKeyPressed(const.vkRalt) then
			self:SelectNextObjectAtCursor()
		elseif not (selo() and terminal.IsKeyPressed(const.vkAlt)) then
			if obj and terminal.IsKeyPressed(const.vkRshift) then
				XEditorUndo:BeginOp()
				if editor.IsSelected(obj) then
					editor.RemoveFromSel(editor.SelectionPropagate({obj}))
				else
					editor.AddToSel(editor.SelectionPropagate({obj}))
				end
				XEditorUndo:EndOp()
				return "break"
			end
			if not obj or terminal.IsKeyPressed(const.vkShift) and not editor.IsSelected(obj) then
				XEditorUndo:BeginOp()
				if not terminal.IsKeyPressed(const.vkShift) then
					editor.ClearSel()
				elseif obj then
					editor.AddToSel(editor.SelectionPropagate({obj}))
				end
				self.init_selection = table.copy(editor.GetSel())
				self.selection_box_enable = true
				return "break"
			end
			if not (obj and editor.IsSelected(obj)) then
				editor.ChangeSelWithUndoRedo(editor.SelectionPropagate({obj}))
			end
			XEditorPlacementHelperHost.OnMouseButtonDown(self, pt, button) -- try again after object is selected
		end
		return "break"
	elseif button == "R" then
		if XEditorIsContextMenuOpen() and #editor.GetSel() > 0 then
			editor.ClearSelWithUndoRedo()
		end
		XPopupMenu.ClosePopupMenus()
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

function XSelectObjectsTool:OnMousePos(pt)
	local obj = GetObjectAtCursor()
	self.last_mouse_pos = pt
	self.last_mouse_obj = obj
	XEditorRemoveFocusFromToolbars()
	
	local operation = self.edit_operation or
	  terminal.IsKeyPressed(const.vkControl) and "Clone" or
	  terminal.IsKeyPressed(const.vkAlt)     and "Rotate" or
	  terminal.IsKeyPressed(const.vkShift)   and "Scale"
	
	if self.placement_helper.operation_started then
		if operation == "Clone" then
			self.placement_helper:EndOperation()
			self:StartEditOperation("Clone")
			XEditorPlacementHelperHost.OnMousePos(self, pt)
			self:Clone()
			self.placement_helper:StartOperation(pt, editor.GetSel())
			self.edit_operation = "PlacementHelper"
		else
			self:StartEditOperation("PlacementHelper")
			XEditorPlacementHelperHost.OnMousePos(self, pt)
		end
		self:HighlightObjects(false)
		return "break"
	end
	
	if self.init_mouse_pos then
		if self.selection_box_enable then
			self:SelectWithSelectionBox()
			self:HighlightObjects(false)
		elseif selo() then
			-- call StartEditOperation only when objects are actually modified to prevent empty undo operations
			local mouse_moved = self.init_mouse_pos.screen:Dist(pt) >= 7
			if operation == "Clone" and obj and editor.IsSelected(obj) and mouse_moved then
				self:StartEditOperation("Clone")
				self:Clone()
				self:Move(pt)
				self.edit_operation = "Move"
			elseif (operation == "Move" or not operation) and GetPreciseTicks() - self.init_mouse_pos.time > 70 then
				self:StartEditOperation("Move")
				self:Move(pt)
			elseif operation == "Rotate" then
				self:StartEditOperation("Rotate")
				self:CreateEditingLine()
				if not self.init_rotate_data then
					self:InitRotation(editor.GetSel())
				else
					self:Rotate(editor.GetSel(), not terminal.IsKeyPressed(const.vkShift))
				end
			elseif operation == "Scale" then
				self:StartEditOperation("Scale")
				self:Scale(pt)
			end
			self:HighlightObjects(editor.GetSel())
		end
		return "break"
	end
	
	if not terminal.IsKeyPressed(const.vkMbutton) then -- camera orbit not active
		local op_check = self.placement_helper:CheckStartOperation(pt, not "btn_pressed")
		if op_check or obj then
			local two_pt = self.placement_helper:IsKindOf("XTwoPointAttachHelper")
			local objects = (not two_pt and (op_check or obj and editor.IsSelected(obj))) and editor.GetSel() or {obj}
			self:HighlightObjects(objects)
		else
			self:HighlightObjects(false)
		end	
		return "break"
	end
	
	self:HighlightObjects(false)
	return "break"
end

function XSelectObjectsTool:FixupHoveredObject()
	-- GetObjectAtCursor uses GetPreciseCursorObj, which needs several frames to get updated,
	-- so call OnMousePos for the next several frames after the mouse stopped moving
	while true do
		if terminal.GetMousePos() == self.last_mouse_pos then
			local obj = GetObjectAtCursor() or false
			if obj ~= self.last_mouse_obj then
				self:OnMousePos(self.last_mouse_pos)
				self.last_mouse_obj = obj
			end
		end
		WaitNextFrame()
	end
end

function XSelectObjectsTool:OnMouseButtonUp(pt, button)
	if XEditorPlacementHelperHost.OnMouseButtonUp(self, pt, button) then
		return "break"
	elseif self.init_mouse_pos then 
		self.desktop:SetMouseCapture()
		return "break"
	end
end

function XSelectObjectsTool:OnCaptureLost()
	self.init_mouse_pos = false
	self.init_move_positions = false
	self.init_scales = false
	if self.selection_box_enable then
		self.selection_box_enable = false
		if self.selection_box_mesh then
			self.selection_box_mesh:delete()
			self.selection_box_mesh = false
		end
		XEditorUndo:EndOp()
		editor.SelectionChanged()
	end
	if self.editing_line_mesh then
		self.editing_line_mesh:delete()
		self.editing_line_mesh = false
	end
	self:CleanupRotation()
	XEditorPlacementHelperHost.OnCaptureLost(self)
	self:EndEditOperation()
end

function XSelectObjectsTool:CreateSelectionBox()
	local ptOne = self.init_mouse_pos.terrain:SetInvalidZ()
	local ptThree = GetTerrainCursor():SetInvalidZ()
	local localY = camera.GetDirection()
	local localX = Normalize(Cross(axis_z, localY):SetInvalidZ())
	local diagonalNorm = Normalize(ptOne - ptThree)
	localX = Dot(diagonalNorm, localX) > 0 and localX or -localX
	local angle = diagonalNorm:Len() ~= 0 and Angle3dVectors(diagonalNorm, localX) or 0
	local sin, cos = sincos(angle)
	local diagonal = ptOne - ptThree
	local localWidth = MulDivRound(diagonal, cos, 4096):Len()
	local ptTwo = ptThree + MulDivRound(localX, localWidth, 4096)
	local ptFour = ptOne - MulDivRound(localX, localWidth, 4096)
	return {ptOne, ptTwo, ptThree, ptFour}
end

function XSelectObjectsTool:SelectWithSelectionBox()
	local selection_box = self:CreateSelectionBox()
	local selection_box_mesh = self.selection_box_mesh
	if not selection_box_mesh then
		selection_box_mesh = Mesh:new()
		selection_box_mesh:SetShader(ProceduralMeshShaders.default_polyline)
		selection_box_mesh:SetMeshFlags(const.mfWorldSpace + const.mfTerrainDistorted)
		selection_box_mesh:SetDepthTest(false)
		self.selection_box_mesh = selection_box_mesh
	end
	
	local minX, maxX = MinMax(selection_box[1]:x(), selection_box[2]:x(), selection_box[3]:x(), selection_box[4]:x())
	local minY, maxY = MinMax(selection_box[1]:y(), selection_box[2]:y(), selection_box[3]:y(), selection_box[4]:y())
	local box = box(minX, minY, maxX, maxY)
	local w, h = box:sizexyz()
	local p, tile = (w + h) / guim, const.HeightTileSize
	local step = Max(p, 50) * tile / 100
	PlaceTerrainPoly(selection_box, RGB(255, 255, 255), step, 10, selection_box_mesh)
	
	PauseInfiniteLoopDetection("SelectWithSelectionBox")
	local objects = MapGet(box, "attached", false, "CObject", function(o)
		return IsPointInsidePoly2D(o, selection_box) and CanSelect(o)
	end)
	local sel = editor.SelectionPropagate(objects)
	if terminal.IsKeyPressed(const.vkShift) then
		table.iappend(sel, self.init_selection)
	end
	editor.SetSel(sel, "dont_notify")
	ResumeInfiniteLoopDetection("SelectWithSelectionBox")
end

function XSelectObjectsTool:Clone()
	local objs = editor.GetSel("permanent")
	local clones = XEditorClone(objs)
	Msg("EditorCallback", "EditorCallbackClone", clones, objs)
	editor.SetSel(clones)
end

function XSelectObjectsTool:Move(pt)
	local objs = editor.GetSel()
	if not self.init_move_positions then
		self.init_move_positions = {}
		for i, o in ipairs(objs) do
			self.init_move_positions[i] = o:GetPos()
		end
	end
	
	local data = self.init_mouse_pos
	local vMove = (ScreenToTerrainPoint(pt + data.mouse_offset) - data.terrain_base):SetZ(0)
	local snapBySlabs = HasAlignedObjs(objs)
	for i, obj in ipairs(objs) do
		XEditorSnapPos(obj, self.init_move_positions[i], vMove, snapBySlabs)
	end
	Msg("EditorCallback", "EditorCallbackMove", objs)
end

function XSelectObjectsTool:Scale(pt)
	self:CreateEditingLine()
	
	local objs = editor.GetSel()
	if not self.init_scales then
		self.init_scales = {}
		for i, obj in ipairs(objs) do
			self.init_scales[i] = obj:GetScale()
		end
	end
	
	local screenHeight = UIL.GetScreenSize():y()
	local mouseY = 4096 * (pt:y() - screenHeight / 2) / screenHeight
	local initY = 4096 * (self.init_mouse_pos.screen:y() - screenHeight / 2) / screenHeight
	local scale
	if mouseY < initY then
		scale = 100 * (mouseY + 4096)/(initY + 4096) + 300  * (initY - mouseY)/(initY + 4096)
	else
		scale = 100 * (4096 - mouseY)/(4096 - initY) + 30  * (mouseY - initY)/(4096 - initY)
	end
	for i, obj in ipairs(objs) do
		obj:SetScaleClamped(self.init_scales[i] * scale / 100)
	end
	Msg("EditorCallback", "EditorCallbackScale", objs)
end

function XSelectObjectsTool:CreateEditingLine()
	local vpstr = pstr("")
	local pt = CenterOfMasses(editor.GetSel())
	vpstr:AppendVertex(pt, RGB(255, 255, 255))
	vpstr:AppendVertex(GetTerrainCursor():SetZ(pt:z()))
	
	if not self.editing_line_mesh then self.editing_line_mesh = PlaceObject("Polyline") end
	self.editing_line_mesh:SetMesh(vpstr)
	self.editing_line_mesh:SetPos(pt)
	self.editing_line_mesh:AddMeshFlags(const.mfWorldSpace)
end

function XSelectObjectsTool:GetRotateAngle()
	local _, pt1 = GameToScreen(self.init_rotate_center)
	local _, pt2 = GameToScreen(GetTerrainCursor())
	return CalcOrientation(pt1, pt2)
end

function XSelectObjectsTool:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" and self:GetHelperClass() == "XSelectObjectsHelper" and #editor.GetSel() > 0 then
		editor.ClearSelWithUndoRedo()
		return "break"
	end
	if XEditorPlacementHelperHost.OnShortcut(self, shortcut, source, ...) == "break" then
		return "break"
	end
	
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" then
		return "break"
	end
	
	if shortcut == "Delete" then
		CreateRealTimeThread(function()
			if self:PreDeleteConfirmation() then
				editor.DelSelWithUndoRedo()
			end
		end)
		return "break"
	elseif shortcut == "[" or shortcut == "]" then
		local dir = shortcut == "[" and -1 or 1
		-- cycle selected objects among available variants
		local sel = editor.GetSel()
		if sel and #sel > 0 and not self.edit_operation then
			local dir = shortcut == "[" and -1 or 1
			XEditorUndo:BeginOp{ objects = sel, name = string.format("Cycled %d objects", #sel) }
			SuspendPassEditsForEditOp()
			local newsel = {}
			for _, obj in ipairs(sel) do
				table.insert(newsel, CycleObjSubvariant(obj, dir)) -- produces an undo op for obj
			end
			ResumePassEditsForEditOp()
			XEditorUndo:EndOp()
			editor.SetSel(newsel) -- must be AFTER the editor op
		end
		return "break"
	elseif shortcut == "Pageup" or shortcut == "Pagedown" or shortcut == "Shift-Pageup" or shortcut == "Shift-Pagedown" then
		local sel = editor.GetSel()
		local down = shortcut:ends_with("down")
		local dir = (down and point(0, 0, -1) or point(0, 0, 1)) * (terminal.IsKeyPressed(const.vkShift) and guic or 1)
		XEditorUndo:BeginOp{ objects = sel, name = string.format("Moved %d objects %s", #sel, down and "down" or "up") }
		for _, obj in ipairs(sel) do
			obj:SetPos(obj:GetVisualPos() + dir)
		end
		XEditorUndo:EndOp(sel)
		return "break"
	end
	return XEditorSettings.OnShortcut(self, shortcut, source, ...)
end

function XSelectObjectsTool:PreDeleteConfirmation()
	return true
end

function XSelectObjectsTool:GetToolTitle()
	return XEditorShowCustomFilters and "Custom Selection Filter" or XEditorPlacementHelperHost.GetToolTitle(self)
end
