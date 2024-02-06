DefineClass.XRampBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		editor = "number", slider = true, persisted_setting = true, auto_select_all = true,
		{ id = "Falloff", default = 100, scale = "%", min = 0, max = 250 },
	},
	
	ToolSection = "Height",
	ToolTitle = "Ramp",
	Description = {
		"Creates an inclined plane between two points.",
		"(<style GedHighlight>hold Shift</style> to align to world directions)",
	},
	ActionSortKey = "14",
	ActionIcon = "CommonAssets/UI/Editor/Tools/slope.tga", 
	ActionShortcut = "/",
	
	old_bbox = false,
	ramp_grid = false,
	mask_grid = false,
}

function XRampBrush:Init() 
	local w, h = terrain.HeightMapSize()
	self.ramp_grid = NewComputeGrid(w, h, "F")
	self.mask_grid = NewComputeGrid(w, h, "F")
end

function XRampBrush:Done()
	editor.ClearOriginalHeightGrid()
	self.ramp_grid:free()
	self.mask_grid:free()
end

function XRampBrush:StartDraw(pt)
	XEditorUndo:BeginOp{ height = true, name = "Changed height" }
	editor.StoreOriginalHeightGrid(true) -- true = use for GetTerrainCursor
end

function XRampBrush:Draw(pt1, pt2)
	pt1 = self.first_pos
	if pt1 == pt2 then return end
	self.mask_grid:clear()
	self.ramp_grid:clear()
	
	local h1 = editor.GetOriginalHeight(pt1) / const.TerrainHeightScale
	local h2 = editor.GetOriginalHeight(pt2) / const.TerrainHeightScale
	local inner_radius, outer_radius = self:GetCursorRadius()
	local bbox = editor.DrawMaskSegment(self.mask_grid, pt1, pt2, inner_radius, outer_radius, "max")
	editor.DrawMaskSegment(self.ramp_grid, pt1, pt2, outer_radius, outer_radius, "set", h1, h2)
	
	local extended_box = AddRects(self.old_bbox or bbox, bbox)
	editor.SetHeightWithMask(self.ramp_grid, self.mask_grid, extended_box)
	Msg("EditorHeightChanged", false, extended_box)
	self.old_bbox = bbox
end

function XRampBrush:EndDraw(pt1, pt2)
	local _, outer_radius = self:GetCursorRadius()
	local bbox = editor.GetSegmentBoundingBox(pt1, pt2, outer_radius, self:IsCursorSquare())
	local extended_box = AddRects(self.old_bbox or bbox, bbox)
	self.old_bbox = nil
	Msg("EditorHeightChanged", true, extended_box)
	XEditorUndo:EndOp(nil, extended_box)
end

function XRampBrush:GetCursorRadius()
	local inner_size = self:GetSize() * 100 / (100 + 2 * self:GetFalloff())
	return inner_size / 2, self:GetSize() / 2
end
