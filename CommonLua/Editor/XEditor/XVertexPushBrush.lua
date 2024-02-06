DefineClass.XVertexPushBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Strength",   name = "Strength", editor = "number", default = 50, scale = "%", min = 1, max = 100, step = 1 },
		{ id = "Falloff",  default = 100, scale = "%", min = 0, max = 250, no_edit = function(self) return self:IsCursorSquare() end },
	},
	
	ToolSection = "Height",
	ToolTitle = "Vertex push",
	Description = {
		"Precisely pushes terrain up or down.",
		"(hold left button and drag)"
	},
	ActionSortKey = "13",
	ActionIcon = "CommonAssets/UI/Editor/Tools/VertexNudge.tga", 
	ActionShortcut = "Ctrl-W",
	
	mask_grid = false,
	offset = 0,
	last_mouse_pos = false,
}

function XVertexPushBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

function XVertexPushBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

function XVertexPushBrush:StartDraw(pt)
	self.mask_grid:clear()
	
	PauseTerrainCursorUpdate()	
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
end

function XVertexPushBrush:OnMouseButtonDown(pt, button)
	if button == "L" then
		self.last_mouse_pos = pt
		self.offset = 0
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XVertexPushBrush:OnMouseButtonUp(pt, button)
	if button == "L" then
		self.last_mouse_pos = false
		self.offset = 0
	end
	
	return XEditorBrushTool.OnMouseButtonUp(self, pt, button)
end

function XVertexPushBrush:OnMousePos(pt, button)
	if self.last_mouse_pos then
		self.offset = self.offset + (self.last_mouse_pos:y() - pt:y()) * (guim / const.TerrainHeightScale)
		self.last_mouse_pos = pt
	end
	XEditorBrushTool.OnMousePos(self, pt, button)
end

function XVertexPushBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, self.first_pos, self.first_pos, inner_radius, outer_radius, "max", 1.0, 1.0, self:IsCursorSquare())
	editor.AddToHeight(self.mask_grid, MulDivRound(self.offset, self:GetStrength(), const.TerrainHeightScale * 100), bbox)

	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	Msg("EditorHeightChanged", false, bbox)
end

function XVertexPushBrush:EndDraw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, bbox)
	
	ResumeTerrainCursorUpdate()
	self.cursor_default_flags = XEditorBrushTool.cursor_default_flags
	self.offset = guim
end

function XVertexPushBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end

function XVertexPushBrush:GetCursorHeight()
	return MulDivRound( self.offset, self:GetStrength(), 100)
end

function XVertexPushBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

function XVertexPushBrush:GetCursorExtraFlags()
	return const.SlabSizeZ and (self:GetSquareBrush() or self:GetClampToLevels()) and const.mfTerrainHeightFieldSnapped or 0
end

function XVertexPushBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end

----- Shortcuts 

function XVertexPushBrush:OnShortcut(shortcut, source, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, ...) then
		return "break"
	elseif shortcut == "+" or shortcut == "Numpad +" then
		self:SetStrength(self:GetStrength() + 1)
		return "break"
	elseif shortcut == "-" or shortcut == "Numpad -" then
		self:SetStrength(self:GetStrength() - 1)
		return "break"
	end
end

-----
if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	function XVertexPushBrush:GetPropertyMetadata(prop_id)
		if prop_id == "Size" and self:IsCursorSquare() then
			local sizex = const.SlabSizeX
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = 0, max = 50 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		return table.find_value(self.properties, "id", prop_id)
	end
	
	function XVertexPushBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XVertexPushBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" then
			self:SetSize(self:GetSize())
		end
	end
end
