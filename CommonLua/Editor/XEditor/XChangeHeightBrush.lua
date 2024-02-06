DefineClass.XChangeHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "ClampToLevels", name = "Clamp to levels", editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.SlabSizeZ },
		{ id = "Height",     default = 10 * guim, scale = "m", min = guic, max = 100 * guim, step = guic }, -- see GetPropertyMetadata
		{ id = "Smoothness", default = 75,        scale = "%", min = 0,    max = 100, no_edit = function(self) return self:IsCursorSquare() end },
		{ id = "DepositionMode",  name = "Deposition mode",    editor = "bool", default = true },
		{ id = "Strength",   default = 50,        scale = "%", min = 10,        max = 100, no_edit = function(self) return not self:GetDepositionMode() end },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	Description = {
		"Use deposition mode to gradually add/remove height as you drag the mouse.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)\n(<style GedHighlight>hold Ctrl</style> for inverse operation)",
	},
	
	mask_grid = false,
}

function XChangeHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
end

function XChangeHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.mask_grid:free()
end

if const.SlabSizeZ then -- modify Size/Height properties depending on SquareBrush/ClampToLevels properties
	function XChangeHeightBrush:GetPropertyMetadata(prop_id)
		local sizex, sizez = const.SlabSizeX, const.SlabSizeZ
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return { id = "Size", name = "Size (tiles)", help = help, default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		if prop_id == "Height" and self:GetClampToLevels() then
			local help = string.format("1 step = %sm", _InternalTranslate(FormatAsFloat(sizez, guim, 2)))
			return { id = "Height", name = "Height (steps)", help = help, default = sizez, scale = sizez, min = sizez, max = self.cursor_max_tiles * sizez, step = sizez, editor = "number", slider = true, persisted_setting = true, auto_select_all = true, }
		end
		return table.find_value(self.properties, "id", prop_id)
	end

	function XChangeHeightBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XChangeHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" or prop_id == "ClampToLevels" then
			self:SetSize(self:GetSize())
			self:SetHeight(self:GetHeight())
		end
	end
end

function XChangeHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
	self.mask_grid:clear()
end

function XChangeHeightBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	local op = self:GetDepositionMode() and "add" or "max"
	local strength = self:GetDepositionMode() and self:GetStrength() / 5000.0 or 1.0
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, op, strength, strength, self:IsCursorSquare())
	editor.AddToHeight(self.mask_grid, self:GetCursorHeight() / const.TerrainHeightScale, bbox)
	
	if const.SlabSizeZ and self:GetClampToLevels() then
		editor.ClampHeightToLevels(config.TerrainHeightSlabOffset, const.SlabSizeZ, bbox, self.mask_grid)
	end
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

function XChangeHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

function XChangeHeightBrush:OnShortcut(shortcut, source, controller_id, repeated, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, controller_id, repeated, ...) then
		return "break"
	end
	
	local key = string.gsub(shortcut, "^Shift%-", "")
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if key == "+" or key == "Numpad +" then
		self:SetHeight(self:GetHeight() + (self:GetClampToLevels() and const.SlabSizeZ or guim / divisor))
		return "break"
	elseif key == "-" or key == "Numpad -" then
		self:SetHeight(self:GetHeight() - (self:GetClampToLevels() and const.SlabSizeZ or guim / divisor))
		return "break"
	end
	
	if not repeated and (shortcut == "Ctrl" or shortcut == "-Ctrl") then
		editor.StoreOriginalHeightGrid(true)
		self.mask_grid:clear()
	end
end

function XChangeHeightBrush:GetCursorRadius()
	local inner_size = self:GetSize() * (100 - self:GetSmoothness()) / 100 
	return inner_size / 2, self:GetSize() / 2
end

function XChangeHeightBrush:GetCursorHeight()
	local ctrlKey = terminal.IsKeyPressed(const.vkControl)
	return ctrlKey ~= self.LowerTerrain and -self:GetHeight() or self:GetHeight()
end

function XChangeHeightBrush:IsCursorSquare()
	return const.SlabSizeZ and self:GetSquareBrush()
end

function XChangeHeightBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfTerrainHeightFieldSnapped or 0
end

function XChangeHeightBrush:GetCursorColor()
	return self:IsCursorSquare() and RGB(16, 255, 16) or RGB(255, 255, 255)
end

DefineClass.XRaiseHeightBrush = {
	__parents = { "XChangeHeightBrush" },
	LowerTerrain = false,
	ToolTitle = "Raise height",
	ActionSortKey = "09",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Raise.tga", 
	ActionShortcut = "H",
}

DefineClass.XLowerHeightBrush = {
	__parents = { "XChangeHeightBrush" },
	LowerTerrain = true,
	ToolTitle = "Lower height",
	ActionSortKey = "10",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Lower.tga", 
	ActionShortcut = "L",
}
