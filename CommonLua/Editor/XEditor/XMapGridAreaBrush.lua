-- Override this class to create editor brushes for grids defined with DefineMapGrid

DefineClass.XMapGridAreaBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		auto_select_all = true,
		{	id = "TerrainDebugAlphaPerc", name = "Opacity", editor = "number",
			default = 50, min = 0, max = 100, slider = true,
		},
		{	id = "WriteValue", name = "Value", editor = "texture_picker", default = "Blank",
			thumb_width = 101, thumb_height = 35, small_font = true, items = function(self) return self:GetGridPaletteItems() end,
		},
		{	id = "mask_help", editor = "help", help = "<center><style GedHighlight>You can only draw outside the grey mask.</style>\n",
			no_edit = function(self) return not self.selection_available end,
		},
		{	id = "mask_buttons", editor = "buttons", default = false,
			buttons = {
				{ name = "Clear (Esc)", func = "ClearSelection" },
				{ name = "Invert (I)", func = "InvertSelection" },
				{ name = "Fill area (F)", func = "FillSelection" },
			},
			no_edit = function(self) return not self.selection_available end,
		},
	},
	
	-- settings
	GridName = false, -- grid name, as defined with DefineMapGrid
	GridTileSize = false,
	Grid = false,
	
	-- state
	saved_alpha = false,
	add_connected_area = false,
	add_every_tile = false,
	selection_grid = false,
	selection_available = false,
	
	-- overrides
	CreateBrushGrid = empty_func,
	GetGridPaletteItems = empty_func,
	GetPalette = empty_func,
}

function XMapGridAreaBrush:Init()
	self:Initialize()
end

function XMapGridAreaBrush:Initialize()
	if (not self.GridName or not _G[self.GridName]) and not self.Grid and not self:CreateBrushGrid() then
		assert(false, "Grid area brush has no configured grid or configured grid was not found")
		return
	end
		
	local items = self:GetGridPaletteItems()
	if not table.find(items, "value", self:GetWriteValue()) then
		self:SetWriteValue(items[1].value)
	end
	
	local grid = self.Grid or _G[self.GridName]
	local w, h = grid:size()
	self.selection_grid = NewHierarchicalGrid(w, h, 64, 1)
	self:SelectionOp("clear")
	
	self:UpdateItems()
	self.saved_alpha = hr.TerrainDebugAlphaPerc
	hr.TerrainDebugDraw = 1
	hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
end

function XMapGridAreaBrush:Done()
	if (not self.GridName and not self.Grid) or not self.selection_grid then return	end
	
	hr.TerrainDebugDraw = 0
	hr.TerrainDebugAlphaPerc = self.saved_alpha
	DbgSetTerrainOverlay("") -- prevent further access to self.selection_grid (which is getting freed) from C++
	self.selection_grid:free()
end

function XMapGridAreaBrush:UpdateItems()
	-- Upload new palette to the debug overlay
	DbgSetTerrainOverlay("grid", self:GetPalette(), self.Grid or _G[self.GridName], self.selection_grid)
	-- Update UI
	ObjModified(self)
end

function XMapGridAreaBrush:HideDebugOverlay()
	DbgSetTerrainOverlay("")
end

function XMapGridAreaBrush:StartDraw(pt)
	XEditorUndo:BeginOp{[self.GridName] = true, name = string.format("Edited grid - %s", self.GridName)}
end
 
function XMapGridAreaBrush:Draw(pt1, pt2)
	local tile_size = MapGridTileSize(self.GridName) or self.GridTileSize
	local bbox = editor.SetGridSegment(self.Grid or _G[self.GridName], tile_size, pt1, pt2, self:GetSize() / 2, self:GetWriteValue(), self.selection_grid)
	Msg("OnMapGridChanged", self.GridName, bbox)
end

function XMapGridAreaBrush:EndDraw(pt1, pt2, invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
	self.start_pt = false
	ObjModified(self) -- update palette items
end

function XMapGridAreaBrush:SelectionOp(op, param)
	local tile_size = MapGridTileSize(self.GridName) or self.GridTileSize
	local bbox = editor.GridSelectionOp(self.Grid or _G[self.GridName], self.selection_grid, tile_size, op, param)
	if bbox and not bbox:IsEmpty() then
		Msg("OnMapGridChanged", self.GridName, bbox)
	end
end

function XMapGridAreaBrush:ClearSelection()
	self:SelectionOp("clear")
	self.selection_available = false
	ObjModified(self)
end

function XMapGridAreaBrush:InvertSelection()
	self:SelectionOp("invert")
end

function XMapGridAreaBrush:FillSelection()
	XEditorUndo:BeginOp{[self.GridName] = true, name = string.format("Edited grid - %s", self.GridName)}
	
	if not self.selection_available then
		self:SelectionOp("invert") -- select entire map
	end
	self:SelectionOp("fill", self:GetWriteValue())
	self:SelectionOp("clear")
	self.selection_available = false
	ObjModified(self)
	
	XEditorUndo:EndOp()
end

function XMapGridAreaBrush:OnMouseButtonDown(pt, button)
	if button == "L" then
		local selecting = self.add_connected_area or self.add_every_tile
		if selecting then
			local world_pt = self:GetWorldMousePos()
			if self.add_every_tile then
				self:SelectionOp("add every tile", world_pt)
			elseif self.add_connected_area then
				self:SelectionOp("add connected area", world_pt)
			end
			self.selection_available = true
			ObjModified(self)
			return "break"
		elseif terminal.IsKeyPressed(const.vkAlt) then
			local tile_size = MapGridTileSize(self.GridName)
			local value = self.Grid or _G[self.GridName]:get(GetTerrainCursor() / tile_size)
			self:SetWriteValue(value)
			ObjModified(self)
			return "break"
		end
	elseif button == "R" then
		if self.selection_available then
			self:ClearSelection()
			return "break"
		end
	end
	
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XMapGridAreaBrush:OnKbdKeyDown(vkey)
	local result
	if vkey == const.vkControl then
		self.add_connected_area = true
		result = "break"
	elseif vkey == const.vkShift then
		self.add_every_tile = true
		result = "break"
	end
	return result or XEditorBrushTool.OnKbdKeyDown(self, vkey)
end

function XMapGridAreaBrush:OnKbdKeyUp(vkey)
	local result
	if vkey == const.vkControl then
		self.add_connected_area = false
		result = "break"
	elseif vkey == const.vkShift then
		self.add_every_tile = false
		result = "break"
	end
	return result or XEditorBrushTool.OnKbdKeyDown(self, vkey)
end

function XMapGridAreaBrush:OnShortcut(shortcut, source, ...)
	if shortcut == "Escape" and self.selection_available then
		self:ClearSelection()
		return "break"
	elseif shortcut == "I" then
		self:InvertSelection()
		return "break"
	elseif shortcut == "F" then
		self:FillSelection()
		return "break"
	end
	return XEditorBrushTool.OnShortcut(self, shortcut, source, ...)
end

function XMapGridAreaBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

function XMapGridAreaBrush:OnEditorSetProperty(prop_id)
	if prop_id == "TerrainDebugAlphaPerc" then
		hr.TerrainDebugAlphaPerc = self:GetTerrainDebugAlphaPerc()
	end
end
