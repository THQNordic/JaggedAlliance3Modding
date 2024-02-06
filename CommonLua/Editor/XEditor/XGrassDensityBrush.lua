DefineClass.XGrassDensityBrush =
{
	__parents = { "XEditorBrushTool" },
	properties =
	{
		persisted_setting = true, auto_select_all = true, slider = true,
		{ id = "LevelMode", name = "Mode", editor = "dropdownlist", default = "Lower & Raise", items = { "Lower & Raise", "Raise Only", "Lower Only", "Draw on Empty" } },
		{ id = "MinDensity", name = "Min grass density", editor = "number", min = 0, max = 100, default = 0},
		{ id = "MaxDensity", name = "Max grass density", editor = "number", min = 0, max = 100, default = 100},
		{ id = "GridVisible", name = "Toggle grid visibilty", editor = "bool", default = true},
		{ id = "TerrainDebugAlphaPerc", name = "Grid opacity", editor = "number",
		  default = 80, min = 0, max = 100, slider = true, no_edit = function(self) return not self:GetGridVisible() end },
	},
	
	ToolSection = "Terrain",
	ToolTitle = "Terrain grass density",
	Description = {
		"Defines the grass density of the terrain.",
		"(<style GedHighlight>hold Ctrl</style> to draw on a select terrain)\n(<style GedHighlight>Alt-click</style> to see grass density at the cursor)"
	},
	ActionSortKey = "21",
	ActionIcon = "CommonAssets/UI/Editor/Tools/GrassDensity.tga", 
	ActionShortcut = "Alt-N",
	
	prev_alpha = false,
	start_terrain = false,
}

function XGrassDensityBrush:Init()
	if self:GetProperty("GridVisible") then
		self:ShowGrid()
	end
end

function XGrassDensityBrush:Done()
	self:HideGrid()
end

function XGrassDensityBrush:ShowGrid()
	hr.TerrainDebugDraw = 1
	self.prev_alpha = hr.TerrainDebugAlphaPerc
	hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	DbgSetTerrainOverlay("grass")
end

function XGrassDensityBrush:HideGrid()
	hr.TerrainDebugDraw = 0
	hr.TerrainDebugAlphaPerc = self.prev_alpha
end

function XGrassDensityBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local grid = editor.GetGridRef("grass_density")
		local value = grid:get(GetTerrainCursor() / const.GrassTileSize)
		print("Grass density at cursor:", value)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XGrassDensityBrush:StartDraw(pt)
	XEditorUndo:BeginOp{grass_density = true, name = "Changed grass density"}
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
end

function XGrassDensityBrush:Draw(pt1, pt2)
	editor.SetGrassDensityInSegment(pt1, pt2, self:GetSize() / 2, self:GetMinDensity(), self:GetMaxDensity(), self:GetLevelMode(), self.start_terrain or -1)
end

function XGrassDensityBrush:EndDraw(pt1, pt2, invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
end

function XGrassDensityBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

function XGrassDensityBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "GridVisible" then
		if self:GetProperty("GridVisible") then
			self:ShowGrid()
		else
			self:HideGrid()
		end
	elseif prop_id == "MinDensity" or prop_id == "MaxDensity" then
		local min = self:GetProperty("MinDensity")
		local max = self:GetProperty("MaxDensity")
		if prop_id == "MinDensity" then
			if min > max then
				self:SetProperty("MaxDensity", min)
			end
		else
			if max < min then
				self:SetProperty("MinDensity", max)
			end
		end
	elseif prop_id == "TerrainDebugAlphaPerc" then
		hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	end
end
