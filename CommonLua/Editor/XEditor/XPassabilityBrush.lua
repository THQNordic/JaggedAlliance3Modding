local work_modes = {
	{ id = 1, name = "Make passable<right>(Alt-1)" },
	{ id = 2, name = "Make impassable<right>(Alt-2)" },
	{ id = 3, name = "Clear both<right>(Alt-3)" }
}

DefineClass.XPassabilityBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, auto_select_all = true,
		{ id = "WorkMode", name = "Work Mode", editor = "text_picker", default = 1, max_rows = 3, items = work_modes, },
		{ id = "SquareBrush",   name = "Square brush",    editor = "bool", default = true, no_edit = not const.PassTileSize },
	},
	
	ToolSection = "Terrain",
	ToolTitle = "Forced passability",
	Description = {
		"Force sets/clears passability."
	},
	ActionSortKey = "20",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Passability.tga", 
	ActionShortcut = "Alt-P",
	cursor_tile_size = const.PassTileSize
}

function XPassabilityBrush:Init()
	hr.TerrainDebugDraw = 1
	DbgSetTerrainOverlay("passability")
end

function XPassabilityBrush:Done()
	hr.TerrainDebugDraw = 0
end

-- Modify Size metadata depending on the SquareBrush property
if const.PassTileSize then
	function XPassabilityBrush:GetPropertyMetadata(prop_id)
		local sizex = const.PassTileSize
		if prop_id == "Size" and self:IsCursorSquare() then
			local help = string.format("1 tile = %sm", _InternalTranslate(FormatAsFloat(sizex, guim, 2)))
			return {
				id = "Size", name = "Size (tiles)", help = help, editor = "number", slider = true,
				default = sizex, scale = sizex, min = sizex, max = 100 * sizex, step = sizex,
				persisted_setting = true, auto_select_all = true,
			}
		end

		return table.find_value(self.properties, "id", prop_id)
	end

	function XPassabilityBrush:GetProperties()
		local props = {}
		for _, prop in ipairs(self.properties) do
			props[#props + 1] = self:GetPropertyMetadata(prop.id)
		end
		return props
	end
	
	function XPassabilityBrush:OnEditorSetProperty(prop_id, old_value, ged)
		if prop_id == "SquareBrush" then
			self:SetSize(self:GetSize())
		end
	end
end

function XPassabilityBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ passability = true, impassability = true, name = "Changed passability" }
end

function XPassabilityBrush:GetBrushBox()
	local radius_in_tiles = self:GetCursorRadius() / self.cursor_tile_size
	local normal_radius = (self.cursor_tile_size / 2) + self.cursor_tile_size * radius_in_tiles
	local small_radius = normal_radius - self.cursor_tile_size
	
	local cursor_pt = GetTerrainCursor()
	local center = point(
		DivRound(cursor_pt:x(), self.cursor_tile_size) * self.cursor_tile_size,
		DivRound(cursor_pt:y(), self.cursor_tile_size) * self.cursor_tile_size
	):SetTerrainZ()
	local min = center - point(normal_radius, normal_radius)
	local max = center + point(normal_radius, normal_radius)
	
	local size_in_tiles = self:GetSize() / self.cursor_tile_size
	-- For an odd-sized brush the radius is asymetrical and needs adjustment
	if size_in_tiles > 1 and size_in_tiles % 2 == 0 then
		local diff = cursor_pt - center
		if diff:x() < 0 and diff:y() < 0 then
			min = center - point(normal_radius, normal_radius)
			max = center + point(small_radius, small_radius)
		elseif diff:x() > 0 and diff:y() < 0 then
			min = center - point(small_radius, normal_radius)
			max = center + point(normal_radius, small_radius)
		elseif diff:x() < 0 and diff:y() > 0 then
			min = center - point(normal_radius, small_radius)
			max = center + point(small_radius, normal_radius)
		else
			min = center - point(small_radius, small_radius)
			max = center + point(normal_radius, normal_radius)
		end
	end
	
	return box(min, max)
end

function XPassabilityBrush:Draw(last_pos, pt)
	if self:GetSquareBrush() then
		local mode = self:GetWorkMode()
		local brush_box = self:GetBrushBox()
		
		if mode == 1 then
			editor.SetPassableBox(brush_box, true)
		elseif mode == 2 then
			editor.SetPassableBox(brush_box, false)
			editor.SetImpassableBox(brush_box, true)
		else
			editor.SetPassableBox(brush_box, false)
			editor.SetImpassableBox(brush_box, false)
		end
		return
	end
	
	local radius = self:GetSize() / 2
	local mode = self:GetWorkMode()
	if mode == 1 then
		editor.SetPassableCircle(pt, radius, true)
	elseif mode == 2 then
		editor.SetPassableCircle(pt, radius, false)
		editor.SetImpassableCircle(pt, radius, true)
	else
		editor.SetPassableCircle(pt, radius, false)
		editor.SetImpassableCircle(pt, radius, false)
	end
end

function XPassabilityBrush:EndDraw(pt1, pt2, invalid_box)
	invalid_box = GrowBox(invalid_box, const.PassTileSize * 2)
	
	XEditorUndo:EndOp(nil, invalid_box)
	terrain.RebuildPassability(invalid_box)
	Msg("EditorPassabilityChanged")
end

function XPassabilityBrush:IsCursorSquare()
	return const.PassTileSize and self:GetSquareBrush()
end

function XPassabilityBrush:GetCursorExtraFlags()
	return self:IsCursorSquare() and const.mfPassabilityFieldSnapped or 0
end

function XPassabilityBrush:OnShortcut(shortcut, ...)
	if shortcut == "Alt-1" or shortcut == "Alt-2" or shortcut == "Alt-3" then
		self:SetWorkMode(tonumber(shortcut:sub(-1)))
		ObjModified(self)
		return "break"
	else
		return XEditorBrushTool.OnShortcut(self, shortcut, ...)
	end
end

function XPassabilityBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end
