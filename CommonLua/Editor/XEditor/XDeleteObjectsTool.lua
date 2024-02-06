DefineClass.XDeleteObjectsTool = {
	__parents = { "XEditorBrushTool", "XEditorObjectPalette" },
	properties = {
		{ id = "buttons", editor = "buttons", default = false, buttons = {{name = "Clear selected objects", func = "ClearSelection"}} },
	},
	
	ToolTitle = "Delete objects",
	Description = {
		"(<style GedHighlight>hold Ctrl</style> to delete objects on a select terrain)",
	},
	ActionSortKey = "07",
	ActionIcon = "CommonAssets/UI/Editor/Tools/DeleteObjects.tga", 
	ActionShortcut = "D",
	
	deleted_objects = false,
	start_terrain = false,
}

function XDeleteObjectsTool:StartDraw(pt)
	SuspendPassEdits("XEditorDeleteObjects")
	self.deleted_objects = {}
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
end

function XDeleteObjectsTool:Draw(pt1, pt2)
	local classes = self:GetObjectClass()
	local radius = self:GetCursorRadius()
	local callback = function(o) 
		if not self.deleted_objects[o] and XEditorFilters:IsVisible(o) and o:GetGameFlags(const.gofPermanent) ~= 0 then
			if not self.start_terrain or terrain.GetTerrainType(o:GetPos()) == self.start_terrain then
				self.deleted_objects[o] = true
				o:ClearEnumFlags(const.efVisible)
			end
		end 
	end
	if #classes > 0 then
		for _, class in ipairs(classes) do
			MapForEach(pt1, pt2, radius, class, callback)
		end
	else
		MapForEach(pt1, pt2, radius, callback)
	end
end

function XDeleteObjectsTool:EndDraw(pt)
	if next(self.deleted_objects) then
		local objs = table.validate(table.keys(self.deleted_objects))
		for _, obj in ipairs(objs) do obj:SetEnumFlags(const.efVisible) end
		XEditorUndo:BeginOp({ objects = objs, name = string.format("Deleted %d objects", #objs) })
		Msg("EditorCallback", "EditorCallbackDelete", objs)
		for _, obj in ipairs(objs) do obj:delete() end
		XEditorUndo:EndOp()
	end
	ResumePassEdits("XEditorDeleteObjects")
	self.deleted_objects = false
end

function XDeleteObjectsTool:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

function XDeleteObjectsTool:ClearSelection()
	self:SetObjectClass({})
	ObjModified(self)
end
