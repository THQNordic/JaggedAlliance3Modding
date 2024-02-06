DefineClass.EnrichBrushObjectSet = {
	__parents = { "PropertyObject", },
	properties = {
		{ id = "Name", editor = "text", default = "", translate = false, },
		{ id = "Objects", editor = "string_list", default = {}, items = ClassDescendantsCombo("CObject"), },
		{ id = "Weight", editor = "number", default = 100, min = 1, max = 1000, step = 1, slider = true, },
		{ id = "AngleDeviation", name = "Angle deviation", editor = "number", default = 0, min = 0, max = 180, step = 1, slider = true, },
		{ id = "Scale", editor = "number", default = 100, min = 10, max = 250, step = 1, slider = true, },
		{ id = "ScaleDeviation", name = "Scale deviation", editor = "number", default = 0, min = 0, max = 100, step = 1, slider = true, },
		{ id = "ColorMin", name = "Color min", editor = "color", default = RGB(100, 100, 100), },
		{ id = "ColorMax", name = "Color max", editor = "color", default = RGB(100, 100, 100), },
	},
	
	EditorName = "Object Set",
}

function EnrichBrushObjectSet:GetEditorView()
	local name = self.Name
	local count = #self.Objects
	local weight = self.Weight
	return string.format("%s (%s objects, weight %s)", name, count, weight)
end

DefineClass.EnrichBrushRule = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "Terrains", editor = "texture_picker", default = {}, thumb_size = 100, small_font = true, max_rows = 3, multiple = true,
		  items = GetTerrainTexturesItems, },
		{ id = "ObjectSets", name = "Object Sets", editor = "nested_list", base_class = "EnrichBrushObjectSet", default = {}, inclusive = true, },
	},
}

function EnrichBrushRule:GetEditorView()
	local objects = {}
	for _, set in ipairs(self.ObjectSets) do objects = table.union(objects, set.Objects) end
	if #objects ~= 0 then table.sort(objects) end
	return string.format("Terrains: %s\nObjects: %s", table.concat(self.Terrains, ", "), table.concat(objects, ", "))
end

DefineClass.EnrichTerrainPreset = {
	__parents = { "Preset" },
	
	EditorMenubarName = "Enrich Terrain Presets",
	EditorMenubar = "Map",
	ContainerClass = "EnrichBrushRule",
	GlobalMap = "EnrichTerrainPresets",
	PresetClass = "EnrichTerrainPreset",
}

function EnrichTerrainPreset:GetError()
	local terrains = {}
	for _, rule in ipairs(self or empty_table) do
		for i, ter in ipairs(rule.Terrains) do
			if terrains[ter] then
				return string.format("Terrain '%s' is already used by another rule.", ter)
			else
				terrains[ter] = true
			end
		end
	end
end

DefineClass.XEnrichTerrainTool = {
	__parents = { "XPlaceMultipleObjectsToolBase" },
	properties = {
		{ id = "Preset", name = "Enrich preset", editor = "preset_id", default = "", preset_class = "EnrichTerrainPreset", },
	},
	
	ToolTitle = "Enrich terrain",
	Description = {
		"Adds randomized objects according to predefined presets.",
	},
	
	classes = false,
	terrains = false,
	
	ToolSection = "Terrain",
	ActionIcon = "CommonAssets/UI/Editor/Tools/EnrichTerrain.tga",
	ActionShortcut = "Ctrl-T",
}

function XEnrichTerrainTool:OnEditorSetProperty(prop_id)
	if prop_id == "Preset" then
		local preset = EnrichTerrainPresets[self:GetPreset()]
		self.classes, self.terrains = {}, {}
		if not preset then return end
		for _, rule in ipairs(preset) do
			local terrains = rule.Terrains
			local sets = rule.ObjectSets
			for _, ter in ipairs(terrains) do 
				if not self.terrains[ter] then self.terrains[ter] = sets end
			end
			for _, set in ipairs(sets) do self.classes = table.union(self.classes, set.Objects) end
		end
	end
end

function XEnrichTerrainTool:GetObjSet(pt)
	if not self:GetPreset() or self:GetPreset() == "" then return end
	local ter = pt and TerrainTextures[terrain.GetTerrainType(pt)]
	return self.terrains[ter.id] and table.weighted_rand(self.terrains[ter.id], "Weight")
end

function XEnrichTerrainTool:GetParams(pt)
	local set = self:GetObjSet(pt)
	if set then return self.terrain_normal, set.Scale, set.ScaleDeviation, set.AngleDeviation, set.ColorMin, set.ColorMax end
end

function XEnrichTerrainTool:GetClassesForPlace(pt)
	local set = self:GetObjSet(pt)
	return set and set.Objects
end

function XEnrichTerrainTool:GetClassesForDelete()
	return self.classes
end
