DefineClass.TerrainColor = {
	__parents = { "Preset" },
	properties = {
		{ id = "value", editor = "number", default = 0, },
	},
	GedEditor = false,
}

function TerrainColor:PostLoad()
	if self.value == 0 then
		local r, g, b = self.id:match("^<color (%d+) (%d+) (%d+)")
		r, g, b = tonumber(r), tonumber(g), tonumber(b)
		self.value = r and g and b and RGB(r, g, b) or nil
	end
end

if const.ColorizeTileSize then -- ColorizeGrid support

local function get_colors() 
	local items = {}
	local encountered = {}
	ForEachPreset("TerrainColor", function(preset, group, ids)
		if preset.id ~= "" and not encountered[preset.id] then
			ids[#ids + 1] = preset.id
			encountered[preset.id] = true
		end
	end, items)
	table.sort(items, function(a, b) return a:strip_tags():lower() < b:strip_tags():lower() end)
	return items
end

DefineClass.XColorizeTerrainBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, auto_select_all = true, slider = true,
		{ id = "Blending", editor = "number", min = 1, max = 100, default = 100 },
		{ id = "Smoothness", editor = "number", min = 0, max = 100, default = 100 },
		{ id = "Roughness", editor = "number", min = -127, max = 127, default = 0, no_edit = const.ColorizeType ~= 8888 },
		{ id = "Color", editor = "color", default = RGB(200, 200, 200), alpha = false },
		{ id = "Buttons", editor = "buttons", default = false,
			buttons = {
				{ name = "Add to palette", func = "AddColorToPalette" },
				{ name = "Remove", func = "RemoveColorFromPalette" },
				{ name = "Rename", func = "RenamePaletteColor" },
			},
		},
		{ id = "ColorPalette", name = "Color Palette", editor = "text_picker", default = false, 
		  items = function (self) return get_colors end },
		{ id = "Pattern", editor = "texture_picker", default = "CommonAssets/UI/Editor/TerrainBrushesThumbs/default.tga",
		  thumb_size = 75, small_font = true, max_rows = 2, base_color_map = true,
		  items = function()
			local files = io.listfiles("CommonAssets/UI/Editor/TerrainBrushesThumbs", "*")
			local items = {}
			local default
			for _, file in ipairs(files) do
				local name = file:match("/(%w+)[ .A-Za-z0-1]*$")
				if name then
					if name == "default" then
						default = file
					else
						items[#items + 1] = { text = name, image = file, value = file, }
					end
				end	
			end
			table.sortby_field(items, "text")
			if default then
				table.insert(items, 1, { text = "default", image = default, value = default, })
			end
			return items
		  end
		},
		{	id = "PatternScale", name = "Pattern scale",
			editor = "number", default = 100, min = 10, max = 1000, step = 10, scale = 100, slider = true, exponent = 2,
			no_edit = function(self) return self:GetPattern() == self:GetDefaultPropertyValue("Pattern") end,
		},
	},
	
	ToolSection = "Colorization",
	ToolTitle = "Terrain colorization",
	Description = {
		"Tints the color of the terrain.",
		"(<style GedHighlight>hold Ctrl</style> to draw over select terrain)\n" ..
		"(use default color to clear colorization)\n" ..
		"(<style GedHighlight>Alt-click</style> to get the color at a point)"
	},
	ActionSortKey = "27",
	ActionIcon = "CommonAssets/UI/Editor/Tools/TerrainColorization.tga",
	ActionShortcut = "Alt-Q",
	
	mask_grid = false,
	init_grid = false,
	pattern_grid = false,
	start_pt = false,
	init_terrain_type = false,
	only_on_type = false,
}

function XColorizeTerrainBrush:Init()
	local w, h = terrain.ColorizeMapSize()
	self.mask_grid = NewComputeGrid(w, h, "F")
	self:GatherPattern()
end

function XColorizeTerrainBrush:Done()
	self.mask_grid:free()
	if self.pattern_grid then
		self.pattern_grid:free()
	end
end

function XColorizeTerrainBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local grid = editor.GetGridRef("colorize")
		local value = grid:get(GetTerrainCursor() / const.ColorizeTileSize)
		local r, g, b, a = GetRGBA(value)
		self:SetColor(RGB(r, g, b))
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XColorizeTerrainBrush:StartDraw(pt)
	XEditorUndo:BeginOp{colorize = true, name = "Changed terrain colorization"}
	self.mask_grid:clear()
	self.init_grid = terrain.GetColorizeGrid()
	self.start_pt = pt
	self.init_terrain_type = terrain.GetTerrainType(pt)
	if terminal.IsKeyPressed(const.vkControl) then self.only_on_type = true end
end

function XColorizeTerrainBrush:Draw(pt1, pt2)
	local inner_radius, outer_radius = self:GetCursorRadius()
	editor.SetColorizationInSegment(self.mask_grid, self.init_grid, self.start_pt, pt1, pt2, self:GetBlending(), inner_radius, outer_radius,
		self:GetColor(), self:GetRoughness(), self.init_terrain_type, self.only_on_type,
		self.pattern_grid or nil, self:GetPatternScale())
end

function XColorizeTerrainBrush:EndDraw(pt1, pt2, invalid_box)
	self.init_grid:free()
	self.start_pt = false
	self.init_terrain_type = false
	self.only_on_type = false
	XEditorUndo:EndOp(nil, GrowBox(invalid_box, const.ColorizeTileSize / 2)) -- the box is extended internally in editor.SetColorizationInSegment
end

function XColorizeTerrainBrush:GatherPattern()
	if self.pattern_grid then
		self.pattern_grid:free()
		self.pattern_grid = false
	end
	self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	if not self.pattern_grid then
		self:SetPattern(self:GetDefaultPropertyValue("Pattern"))
		self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	end
end

function XColorizeTerrainBrush:GetCursorRadius()
	local inner_size = self:GetSize() * (100 - self:GetSmoothness()) / 100 
	return inner_size / 2, self:GetSize() / 2
end

function XColorizeTerrainBrush:OnEditorSetProperty(prop_id)
	if prop_id == "ColorPalette" then
		local preset = Presets.TerrainColor.Default[self:GetColorPalette()]
		local color = preset and preset.value
		if color then
			self:SetColor(color)
		end
	elseif prop_id == "Pattern" then
		self:GatherPattern()
	elseif prop_id == "Color" then
		self:SetColorPalette(false) -- clear the selected color
	end
end

function XColorizeTerrainBrush:AddColorToPalette()
	local name = WaitInputText(nil, "Name Your Color:")
	local r, g, b = GetRGB(self:GetColor())
	name = name and string.format("<color %s %s %s>%s</color>", r, g, b, name)
	if self:GetColor() and name and not table.find(Presets.TerrainColor.Default, "id", name) then
		local color = TerrainColor:new()
		color:SetGroup("Default")
		color:SetId(name)
		color.value = self:GetColor()
		TerrainColor:SaveAll("force")
		ObjModified(self)
	end
end

function XColorizeTerrainBrush:RemoveColorFromPalette()
	local name = self:GetColorPalette()
	local index = table.find(Presets.TerrainColor.Default, "id", name)
	if index then
		Presets.TerrainColor.Default[index]:delete()
	end
	TerrainColor:SaveAll("force")
	ObjModified(self)
end

function XColorizeTerrainBrush:RenamePaletteColor()
	local name = self:GetColorPalette()
	self:SetColor(Presets.TerrainColor.Default[name].value)
	self:RemoveColorFromPalette()
	self:AddColorToPalette()
end

DefineClass.XColorizeObjectsTool = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true, slider = true,
		{ id = "ColorizationMode", name = "Colorization Mode", editor = "text_picker", items = function() return { "Colorize", "Clear" } end, default = "Colorize", horizontal = true, },
		{ id = "Affect", editor = "set", default = {}, items = function() return table.subtraction(ArtSpecConfig.Categories, {"Markers"}) end, horizontal = true, },
		{ id = "HeightTreshold", name = "Height Treshold", editor = "number", min = 0 * guim, max = 100 * guim, default = 5 * guim, step = guim, scale = "m", },
	},
	
	ActionSortKey = "28",
	ActionIcon = "CommonAssets/UI/Editor/Tools/TerrainObjectsColorization.tga", 
	ActionShortcut = "Alt-W",

	ToolSection = "Colorization",
	ToolTitle = "Terrain objects colorization",
	Description = {
		"Changes the tint of objects close to the terrain surface."
	},
}

function XColorizeObjectsTool:Draw(pt1, pt2)
	MapForEach(pt1, pt2, self:GetCursorRadius(), function (o)
			local entityData = EntityData[o:GetEntity()]
			local ZOverTerrain = o:GetVisualPos():z() - terrain.GetHeight(o:GetPos())
			if type(entityData) == "table" and entityData.editor_category and self:GetAffect()[entityData.editor_category] and ZOverTerrain <= self:GetHeightTreshold() then
				if self:GetColorizationMode() == "Colorize" then o:SetHierarchyGameFlags(const.gofTerrainColorization)
				else o:ClearHierarchyGameFlags(const.gofTerrainColorization) end
			end
		end)
end

function XColorizeObjectsTool:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end

end -- ColorizeGrid support
