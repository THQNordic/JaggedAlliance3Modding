DefineClass.XLevelHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "LevelMode", name = "Mode", editor = "dropdownlist", default = "Lower & Raise", items = {"Lower & Raise", "Raise Only", "Lower Only"} },
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Height",   default = 10 * guim, scale = "m", min = guic, max = const.MaxTerrainHeight, step = guic },
		{ id = "Falloff",  default = 100, scale = "%", min = 0,  max = 250, no_edit = function(self) return self:IsCursorSquare() end },
		{ id = "Strength", default = 100, scale = "%", min = 10, max = 100 },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Level height",
	Description = {
		"Levels the terrain at the height of the starting point, creating a flat area.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)\n(<style GedHighlight>hold Ctrl</style> to use the value in Height)\n(<style GedHighlight>Alt-click</style> to get the height at the cursor)",
	},
	ActionSortKey = "11",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Level.tga", 
	ActionShortcut = "P",
	
	mask_grid = false,
}

function XLevelHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

function XLevelHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	function XLevelHeightBrush:GetPropertyMetadata(prop_id)
		local sizex, sizez = const.SlabSizeX, const.SlabSizeZ
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		if prop_id == "Height" and self:GetClampToLevels() then
			local help = string.format("1 step = %sm", _InternalTranslate(FormatAsFloat(sizez, guim, 2)))
			return { id = "Height", name = "Height (steps)", help = help, default = sizez, scale = sizez, min = sizez, max = self.cursor_max_tiles * sizez, step = sizez, editor = "number", slider = true, persisted_setting = true, auto_select_all = true }
		end
		return table.find_value(self.properties, "id", prop_id)
	end

	function XLevelHeightBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XLevelHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" or prop_id == "ClampToLevels" then
			self:SetSize(self:GetSize())
			self:SetHeight(self:GetHeight())
		end
	end
end

function XLevelHeightBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		self:SetHeight(GetTerrainCursor():z())
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XLevelHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	self.mask_grid:clear()
	if not terminal.IsKeyPressed(const.vkControl) then
		self:SetHeight(terrain.GetHeight(pt))
		ObjModified(self)
	end
end

function XLevelHeightBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local op = self:GetStrength() ~= 100 and "add" or "max"
	local strength = self:GetStrength() ~= 100 and self:GetStrength() / 5000.0 or 1.0
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, op, strength, strength, self:IsCursorSquare())
	editor.SetHeightWithMask(self:GetHeight() / const.TerrainHeightScale, self.mask_grid, bbox, self:GetLevelMode())
	
	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

function XLevelHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

function XLevelHeightBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end

function XLevelHeightBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

function XLevelHeightBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfTerrainHeightFieldSnapped or 0
end

function XLevelHeightBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end
