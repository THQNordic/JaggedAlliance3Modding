
DefineClass.XSmoothHeightBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "Strength", default = 50,        scale = "%", min = 10,       max = 100,        step = 10 },
		{ id = "RegardWalkables", name = "Limit to walkables", editor = "bool", default = false },
	},
	
	ToolSection = "Height",
	ToolTitle = "Smooth height",
	Description = {
		"Removes jagged edges and softens terrain features."
	},
	ActionSortKey = "12",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Smooth.tga", 
	ActionShortcut = "S",
	
	blurred_grid = false,
	mask_grid = false,
}

function XSmoothHeightBrush:Init()
	local w, h = terrain.HeightMapSize()
	self.blurred_grid = NewComputeGrid(w, h, "F")
	self.mask_grid = NewComputeGrid(w, h, "F")
	self:InitBlurredGrid()
end

function XSmoothHeightBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.blurred_grid:free()
	self.mask_grid:free()
end

function XSmoothHeightBrush:InitBlurredGrid()
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	editor.CopyFromOriginalHeight(self.blurred_grid)

	local blur_size = MulDivRound(self:GetStrength(), self:GetSize(), guim * const.HeightTileSize * 3)
	AsyncBlurGrid(self.blurred_grid, Max(blur_size, 1))
end

-- called via Msg when height is changed via this brush, or via undo
function XSmoothHeightBrush:UpdateBlurredGrid(bbox)
	bbox = terrain.ClampBox(GrowBox(bbox, 512 * guim)) -- TODO: make updating the blurred grid in the changed area only not produce sharp changes at the edges

	local grid_box = bbox / const.HeightTileSize
	
	-- copy the changed area back into blurred grid, and blur only that area to update it
	local height_part = editor.GetGrid("height", bbox)
	self.blurred_grid:copyrect(height_part, grid_box - grid_box:min(), grid_box:min())
	height_part:free()
	
	local blur_size = MulDivRound(self:GetStrength(), self:GetSize(), guim * const.HeightTileSize * 3)
	AsyncBlurGrid(self.blurred_grid, grid_box, Max(blur_size, 1)) -- update the blurred version of the terrain grid in the edited box
end

function OnMsg.EditorHeightChangedFinal(bbox)
	local brush = XEditorGetCurrentTool()
	if IsKindOf(brush, "XSmoothHeightBrush") then
		brush:UpdateBlurredGrid(bbox)
	end
end

function XSmoothHeightBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Strength" or prop_id == "Size" then
		self:InitBlurredGrid()
	end
end

function XSmoothHeightBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true , name = "Changed height" }
	editor.StoreOriginalHeightGrid(false) -- false = don't use for GetTerrainCursor
	self.mask_grid:clear()
end

function XSmoothHeightBrush:Draw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, self:GetSize() / 4, self:GetSize(), "max", self:GetStrength() * 1.0 / 100.0)
	editor.SetHeightWithMask(self.blurred_grid, self.mask_grid, bbox)
	
	if self:GetRegardWalkables() then
		editor.ClampHeightToWalkables(bbox)
	end
	Msg("EditorHeightChanged", false, bbox)
end

function XSmoothHeightBrush:EndDraw(pt1, pt2, invalid_box)
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, self:GetSize(), self:IsCursorSquare())
	Msg("EditorHeightChanged", true, bbox)
	XEditorUndo:EndOp(nil, invalid_box)
end

function XSmoothHeightBrush:OnShortcut(shortcut, source, ...)
	if XEditorBrushTool.OnShortcut(self, shortcut, source, ...) then
		return "break"
	end
	
	local key = string.gsub(shortcut, "^Shift%-", "") -- ignore Shift, use it to decrease step size
	local divisor = terminal.IsKeyPressed(const.vkShift) and 10 or 1
	if key == "+" or key == "Numpad +" then
		self:SetStrength(self:GetStrength() + 10)
		return "break"
	elseif key == "-" or key == "Numpad -" then
		self:SetStrength(self:GetStrength() - 10)
		return "break"
	end
end

function XSmoothHeightBrush:GetCursorHeight()
	return self:GetStrength() / 3 * guim
end

function XSmoothHeightBrush:GetCursorRadius()
	return self:GetSize() / 2, self:GetSize() / 2
end

function XSmoothHeightBrush:GetAffectedRadius()
	return self:GetSize()
end
