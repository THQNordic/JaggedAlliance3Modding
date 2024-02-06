-- dummy placement helper for the default "Select" mode
DefineClass.XPlaceObjectsHelper = {
	__parents = { "XEditorPlacementHelper" },

	InXPlaceObjectTool = true,
	AllowRotationAfterPlacement = true,
	HasSnapSetting = true,
	Title = "Place objects (N)",
	ActionIcon = "CommonAssets/UI/Editor/Tools/SelectObjects.tga",
	ActionShortcut = "N",
}

DefineClass.XPlaceObjectTool = {
	__parents = { "XEditorObjectPalette", "XEditorPlacementHelperHost" },

	ToolTitle = "Place single object",
	Description = {
		"(drag after placement to rotate object)",
	},
	ActionSortKey = "05",
	ActionIcon = "CommonAssets/UI/Editor/Tools/PlaceSingleObject.tga", 
	ActionShortcut = "N",
	
	helper_class = "XPlaceObjectsHelper",
	ui_state = "none", -- "none" - no object attached to cursor, "cursor" - dragging an object to place, "rotate" - dragging with LMB held to rotate
	cursor_object = false,
	objects = false, -- stores cursor_object in a table to pass to placement helpers and undo operations
	feedback_line = false,
}

function XPlaceObjectTool:Init()
	self:CreateCursorObject()
end

function XPlaceObjectTool:Done()
	self.desktop:SetMouseCapture() -- finalize pending operation
	self:DeleteCursorObject()
end

function XPlaceObjectTool:OnEditorSetProperty(prop_id, ...)
	if prop_id == "ObjectClass" or prop_id == "Category" then
		self:CreateCursorObject()
	end
	XEditorObjectPalette.OnEditorSetProperty(self, prop_id, ...)
end

function XEditorPlacementHelperHost:UpdatePlacementHelper()
	self:CreateCursorObject()
end

function XPlaceObjectTool:CreateCursorObject(id)
	self:DeleteCursorObject()
	id = id or table.rand(self:GetObjectClass())
	if id then
		local obj = XEditorPlaceObject(id, "cursor_object")
		if obj then
			obj:SetHierarchyEnumFlags(const.efVisible)
			obj:ClearHierarchyEnumFlags(const.efCollision + const.efWalkable + const.efApplyToGrids)
			EditorCursorObjs[obj] = true -- excludes the object from being processed in certain cases
			obj:SetCollection(Collections[editor.GetLockedCollectionIdx()])
			self.cursor_object = obj
			self.objects = { self.cursor_object }
			self.ui_state = "cursor"
			self:UpdateCursorObject()
			assert(not self.placement_helper.operation_started)
			self.placement_helper:StartOperation(terminal.GetMousePos(), self.objects)
			Msg("EditorCallback", "EditorCallbackPlaceCursor", table.copy(self.objects))
			return obj
		end
	end
end

function XPlaceObjectTool:UpdateCursorObject()
	XEditorSnapPos(self.cursor_object, editor.GetPlacementPoint(GetTerrainCursor()), point30)
end

function XPlaceObjectTool:PlaceCursorObject()
	local obj = self.cursor_object
	obj:RestoreHierarchyEnumFlags() -- will rebuild surfaces if required
	obj:SetHierarchyEnumFlags(const.efVisible)
	EditorCursorObjs[obj] = nil
	obj:SetGameFlags(const.gofPermanent)
	
	XEditorUndo:BeginOp{ name = "Placed 1 object" }
	editor.AddToSel(obj)
	
	if self.placement_helper.AllowRotationAfterPlacement then
		self.desktop:SetMouseCapture(self)
		ForceHideMouseCursor("XPlaceObjectTool")
		SuspendPassEdits("XPlaceObjectTool")
		self.ui_state = "rotate"
	else
		self:FinalizePlacement()
	end
end

function XPlaceObjectTool:FinalizePlacement()
	XEditorUndo:EndOp(self.objects)
	Msg("EditorCallback", "EditorCallbackPlace", table.copy(self.objects))
	self.cursor_object = nil
	self:CreateCursorObject()
end

function XPlaceObjectTool:DeleteCursorObject()
	if self.placement_helper.operation_started then
		self.placement_helper:EndOperation(self.objects)
	end
	local obj = self.cursor_object
	if obj then
		-- use pcall, as some objects involed in gameplay will crash when created/deleted from the editor
		local ok = pcall(obj.delete, self.cursor_object)
		if not ok and IsValid(obj) then -- a Done method failed, at least delete the C object
			CObject.delete(obj)
		end
		self.cursor_object = nil
	end
	self.objects = nil
	self.ui_state = "none"
end


----- Mouse behavior - rotate object after placement

function XPlaceObjectTool:OnMouseButtonDown(pt, button)
	if button == "L" and self.ui_state == "cursor" then
		assert(self.placement_helper.operation_started)
		self.placement_helper:EndOperation(self.objects)
		self:PlaceCursorObject()
		return "break"
	end
	return XEditorTool.OnMouseButtonDown(self, pt, button)
end

function XPlaceObjectTool:OnMousePos(pt, button)
	XEditorRemoveFocusFromToolbars()
	
	if self.ui_state == "cursor" then
		if self.helper_class == "XPlaceObjectsHelper" then
			self:UpdateCursorObject()
		else
			assert(self.placement_helper.operation_started)
			self.placement_helper:PerformOperation(pt, self.objects)
		end
		return "break"
	elseif self.ui_state == "rotate" then
		local obj = self.cursor_object
		local pt1, pt2 = obj:GetPos(), GetTerrainCursor()
		if pt1:Dist2D(pt2) > 10 * guic then
			local angle = XEditorSettings:AngleSnap(CalcOrientation(pt2, pt1))
			XEditorSetPosAxisAngle(obj, pt1, obj:GetAxis(), angle)
			self:CreateFeedbackLine(pt1, pt2)
		end
		return "break"
	end
	return XEditorTool.OnMousePos(self, pt, button)
end

function XPlaceObjectTool:OnMouseButtonUp(pt, button)
	if button == "L" and self.ui_state == "rotate" then
		self.desktop:SetMouseCapture() -- will call OnCaptureLost
		return "break"
	end
	return XEditorTool.OnMouseButtonUp(self, pt, button)
end

function XPlaceObjectTool:OnCaptureLost()
	self:DeleteFeedbackLine()
	UnforceHideMouseCursor("XPlaceObjectTool")
	ResumePassEdits("XPlaceObjectTool", "ignore_errors")
	self:FinalizePlacement()
end

function XPlaceObjectTool:CreateFeedbackLine(pt1, pt2)
	if not self.feedback_line then
		self.feedback_line = Mesh:new()
		self.feedback_line:SetShader(ProceduralMeshShaders.mesh_linelist)
		self.feedback_line:SetMeshFlags(const.mfWorldSpace)
		self.feedback_line:SetPos(point30)
	end
	local str = pstr()
	str:AppendVertex(pt1:SetTerrainZ())
	str:AppendVertex(pt2:SetTerrainZ())
	self.feedback_line:SetMesh(str)
end

function XPlaceObjectTool:DeleteFeedbackLine()
	if self.feedback_line then
		self.feedback_line:delete()
		self.feedback_line = nil
	end
end

----- Keyboard - auto-focus Filter field in the tool settings, route keystrokes to Ged if outside the game, shortcuts, etc.

function XPlaceObjectTool:OnShortcut(shortcut, source, ...)
	-- don't change tool modes, allow undo, etc. while in the process of dragging
	if terminal.desktop:GetMouseCapture() and shortcut ~= "Ctrl-F1" and shortcut ~= "Escape" then
		return "break"
	end
	
	if XEditorPlacementHelperHost.OnShortcut(self, shortcut, source, ...) == "break" then
		return "break"
	end
	
	if self.ui_state == "cursor" then
		if shortcut == "[" or shortcut == "]" then
			local dir = shortcut == "[" and -1 or 1
			local classes = self:GetObjectClass()
			SuspendPassEdits("XPlaceObjectToolCycle")
			if #classes > 1 then
				-- cycle between selected objects
				local idx = table.find(classes, self.cursor_object.class) + dir
				if idx <= 0 then
					idx = #classes
				elseif idx > #classes then
					idx = 1
				end
				self:CreateCursorObject(classes[idx])
			else
				-- cycle using the standard editor cycling logic
				local obj = CycleObjSubvariant(self.cursor_object, dir)
				self:CreateCursorObject(obj.class)
				obj:delete()
				self:SetObjectClass{obj.class}
				ObjModified(self)
			end
			ResumePassEdits("XPlaceObjectToolCycle")
			return "break"
		elseif shortcut == "Up" then
			return "break"
		elseif shortcut == "Down" then
			return "break"
		end
	end
	return XEditorSettings.OnShortcut(self, shortcut, source, ...)
end

function OnMsg.EditorCallback(id, objects)
	if id == "EditorCallbackPlace" and rawget(CObject, "GenerateFadeDistances") then
		for _, obj in ipairs(objects) do
			if IsValid(obj) then
				obj:GenerateFadeDistances()
			end
		end
	end
end
