DefineClass.XTerrainTypeBrush = {
	__parents = { "XEditorBrushTool" },
	properties = {
		persisted_setting = true,
		{  id = "FlatOnly", name = "Draw on flat only", editor = "bool", default = false,
			persisted_setting = false, no_edit = function(self) return self.draw_on_height end, },
		{  id = "DrawOnHeight", name = "Draw on height", editor = "number", scale = "m", default = false,
			persisted_setting = false, no_edit = function(self) return not self.draw_on_height end, },
		
		{	id = "Filter", editor = "text", default = "", allowed_chars = EntityValidCharacters, translate = false, },
		{	id = "Texture", name = "Texture <style GedHighlight>(Alt-click sets vertical texture)</style>", editor = "texture_picker", default = false,
			filter_by_prop = "Filter",
			alt_prop = "VerticalTexture", base_color_map = true,
			thumb_width = 101, thumb_height = 49,
			small_font = true, multiple = true, items = GetTerrainTexturesItems,
			help = "Select multiple textures (placed according to pattern's gray levels) by holding Ctrl and/or Shift.\nSelect a vertical texture for sloped terrain by holding Alt.",
		},
		
		{	id = "VerticalTexture", name = "Vertical texture", editor = "text", default = "", no_edit = true },
		{	id = "VerticalTexturePreview", name = "Vertical texture", editor = "image", default = "", base_color_map = true,
			img_width = 101, img_height = 49,
			no_edit = function(self) return self:GetVerticalTexture() == "" end,
			persisted_setting = false,
			buttons = {{name = "Clear", func = function(self)
				self:SetProperty("VerticalTexture", "")
				self:GatherTerrainIndices()
				ObjModified(self)
			end}},
		},
		{	id = "VerticalThreshold", name = "Vertical threshold",
			editor = "number", default = 45 * 60, min = 0, max = 90 * 60, slider = true, scale = "deg",
			no_edit = function(self) return self:GetVerticalTexture() == "" end,
		},
		
		{	id = "Pattern", editor = "texture_picker", default = "CommonAssets/UI/Editor/TerrainBrushesThumbs/default.tga",
			thumb_size = 74,
			small_font = true, max_rows = 2, base_color_map = true,
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
		{	id = "PatternThreshold", name = "Pattern threshold",
			editor = "number", default = 50, min = 1, max = 99, scale = 100, slider = true,
			no_edit = function(self) return self:GetPattern() == self:GetDefaultPropertyValue("Pattern") end,
		},
	},
	
	terrain_indices = false,
	terrain_vertical_index = false,
	pattern_grid = false,
	start_pt = false,
	partial_invalidate_time = 0,
	partial_invalidate_box = false,
	
	draw_on_height = false,
	GetDrawOnHeight = function(self) return self.draw_on_height end,
	SetDrawOnHeight = function(self, v) self.draw_on_height = v self.FlatOnly = v and true end,
	
	ToolSection = "Terrain",
	ToolTitle = "Terrain texture",
	Description = {
		"(<style GedHighlight>hold Ctrl</style> to draw only over a single terrain)\n(<style GedHighlight>Alt-Click</style> to pick texture / vertical texture)"
	},
	ActionSortKey = "19",
	ActionIcon = "CommonAssets/UI/Editor/Tools/Terrain.tga", 
	ActionShortcut = "T",
}

function XTerrainTypeBrush:Init()
	self:GatherTerrainIndices()
	self:GatherPattern()
	if not self:GetTexture() then
		self:SetTexture{GetTerrainTexturesItems()[1].value}
	end
end

function XTerrainTypeBrush:Done()
	if self.pattern_grid then
		self.pattern_grid:free()
	end
end

local function GetTerrainIndex(texture)
	for idx, preset in pairs(TerrainTextures) do
		if preset.id == texture then
			return idx
		end
	end
end

function XTerrainTypeBrush:GatherTerrainIndices()
	self.terrain_indices = {}
	local textures = self:GetTexture()
	for _, texture in ipairs(textures) do
		local index = GetTerrainIndex(texture)
		if index then
			table.insert(self.terrain_indices, index)
		end
	end
	self.terrain_vertical_index = GetTerrainIndex(self:GetProperty("VerticalTexture")) or -1
end

function XTerrainTypeBrush:GatherPattern()
	if self.pattern_grid then
		self.pattern_grid:free()
		self.pattern_grid = false
	end
	if self:GetPattern() ~= self:GetDefaultPropertyValue("Pattern") then
		self.pattern_grid = ImageToGrids(self:GetPattern(), false)
	end
end

function XTerrainTypeBrush:GetVerticalTexturePreview()
	local terrain_data = table.find_value(GetTerrainTexturesItems(), "value", self:GetVerticalTexture())
	return terrain_data and GetTerrainImage(terrain_data.image)
end

function XTerrainTypeBrush:IsTerrainSlopeVertical(pt)
	local cos = cos(self:GetVerticalThreshold())
	local tile = const.TypeTileSize / 2
	return terrain.GetTerrainNormal(pt):z() <= cos and
		terrain.GetTerrainNormal(pt + point(-tile, -tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point( tile, -tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point(-tile,  tile)):z() <= cos and
		terrain.GetTerrainNormal(pt + point( tile,  tile)):z() <= cos
end

function XTerrainTypeBrush:OnMouseButtonDown(pt, button)
	if button == "L" and terminal.IsKeyPressed(const.vkAlt) then
		local index = terrain.GetTerrainType(self:GetWorldMousePos())
		if not TerrainTextures[index] then
			return "break"
		end
		local texture = TerrainTextures[index].id
		if self:IsTerrainSlopeVertical(GetTerrainCursor()) then
			self:SetVerticalTexture(texture)
		else
			self:SetTexture({texture})
		end
		self:GatherTerrainIndices()
		ObjModified(self)
		return "break"
	end
	return XEditorBrushTool.OnMouseButtonDown(self, pt, button)
end

function XTerrainTypeBrush:OnEditorSetProperty(prop_id, old_value, ged)
	if prop_id == "Texture" or prop_id == "VerticalTexture" then
		self:GatherTerrainIndices()
	elseif prop_id == "Pattern" then
		self:GatherPattern()
	end
end

function XTerrainTypeBrush:StartDraw(pt)
	self.start_pt = pt
	self.start_terrain = terminal.IsKeyPressed(const.vkControl) and terrain.GetTerrainType(pt)
	self.partial_invalidate_time = 0
	self.partial_invalidate_box = box()
	if self.FlatOnly then
		self.draw_on_height = self.draw_on_height or terrain.GetHeight(pt)
		ObjModified(self)
	end
	XEditorUndo:BeginOp{terrain_type = true, name = "Changed terrain type"}
end

function XTerrainTypeBrush:Draw(pt1, pt2)
	if #self.terrain_indices == 0 then return end
	
	local bbox = editor.SetTerrainTypeInSegment(
		self.start_pt, self.start_terrain or -1, pt1, pt2, self:GetSize() / 2,
		self.terrain_indices, self.terrain_vertical_index, self:GetProperty("VerticalThreshold"),
		self.pattern_grid or nil, self:GetProperty("PatternScale"), self:GetProperty("PatternThreshold"),
		self.draw_on_height or nil)
	
	-- the call above does not invalidate the terrain; take care to not invalidate it too often
	local time = GetPreciseTicks()
	self.partial_invalidate_box:InplaceExtend(bbox)
	if time - self.partial_invalidate_time > 30 then
		terrain.InvalidateType(self.partial_invalidate_box)
		self.partial_invalidate_time = time
		self.partial_invalidate_box = box()
	end
	
	hr.TemporalReset()
end

function XTerrainTypeBrush:EndDraw(pt1, pt2, invalid_box)
	terrain.InvalidateType(self.partial_invalidate_box)
	Msg("EditorTerrainTypeChanged", invalid_box)
	XEditorUndo:EndOp(nil, invalid_box)
	self.start_pt = false
end

function XTerrainTypeBrush:OnShortcut(shortcut, source, ...)
	if shortcut == "+" or shortcut == "-" or shortcut == "Numpad +" or shortcut == "Numpad -" then
		local textures = self:GetTexture()
		if #textures ~= 1 then return end
		
		local terrains = GetTerrainTexturesItems()
		local index = table.find(terrains, "value", textures[1])
		if shortcut == "+" or shortcut == "Numpad +" then
			index = index + 1
			index = index > #terrains and 1 or index
		else
			index = index - 1
			index = index < 1 and #terrains or index
		end
		self:SetTexture({terrains[index].value})
		self:GatherTerrainIndices()
		
		return "break"
	else
		return XEditorBrushTool.OnShortcut(self, shortcut, source, ...)
	end
end

function XTerrainTypeBrush:GetCursorRadius()
	local radius = self:GetSize() / 2
	return radius, radius
end
