DefineClass.PrefabPOI = {
	__parents = { "Preset", },
	properties = {
		{ category = "General", id = "PlaceModel",       name = "Placement Model",       editor = "choice",         default = "", items = { "", "terrain", "spawn", "point" }},
		{ category = "General", id = "RadiusEstim",      name = "Radius Estimate",       editor = "choice",         default = "excircle", items = function() return PrefabRadiusEstimItems() end },
		{ category = "General", id = "FillRadius",       name = "Fill Radius",           editor = "number",         default = 0, min = 0, step = const.HeightTileSize, scale = "m", help = "Fill holes in the placement area to make the fitting of large prefabs easier" },
		{ category = "General", id = "MinCount",         name = "Min Count",             editor = "number",         default = 0, help = "An error will be shown if the placed prefabs are less" },
		{ category = "General", id = "MaxCount",         name = "Max Count",             editor = "number",         default = -1, help = "The maximum allowed prefabs form that POI type" },
		{ category = "General", id = "Tags",             name = "Tags",                  editor = "set",            default = empty_table, items = function() return PrefabTagsCombo() end, help = "Keywords used to define similar POI characteristics" },
		{ category = "General", id = "TagDist",          name = "Dist To Tags",          editor = "text",           default = "", lines = 1, max_lines = 10, dont_save = true, read_only = true },
		{ category = "General", id = "DistToPlayable",   name = "Dist To Playable Area", editor = "number",         default = 0, scale = "m", help = "Limit placement distance to the playable area. Positive numbers are for the map border direction, while negative numbers are for the map center direction" },
		{ category = "General", id = "DistToSame",       name = "Dist to Same",          editor = "number",         default = 0, min = 0, scale = "m", help = "Min distance between the bounderies of POI prefabs of the same type", no_edit = function(self) return self.PoiType == "" end },
		{ category = "General", id = "TerrainSlopeMin",  name = "Min Terrain Slope",     editor = "number",         default = 0, scale = "deg", help = "Limit placement by terrain slope" },
		{ category = "General", id = "TerrainSlopeMax",  name = "Max Terrain Slope",     editor = "number",         default = 90*60, scale = "deg", help = "Limit placement by terrain slope" },
		{ category = "General", id = "PrefabTypeGroups", name = "Prefab Type Areas",     editor = "nested_list",    default = empty_table, base_class = "PrefabTypeGroup", help = "Disregard the prefab type and use type groups (areas)." },
		{ category = "General", id = "CustomTypes",      name = "Custom Prefab Types",   editor = "preset_id_list", default = empty_table, preset_class = "PrefabType", help = "(deprecated) Disregard the POI prefab types and use a custom list for all", },
		
		{ category = "Editor",  id = "OverlayColor",     name = "Overlay Color",      editor = "color",  default = false, alpha = false },
	},
	EditorMenubarName = "Prefab POI",
	EditorMenubar = "Map.Generate",
	EditorIcon = "CommonAssets/UI/Icons/puzzle.png",
	EditorView = Untranslated("<Id> <style GedConsole>[<SortKey>] <PlaceModel></style> <color 0 128 0><opt(u(Comment),' ','')>"),

	StoreAsTable = false,
	GlobalMap = "PrefabPoiToPreset",
	HasSortKey = true,
}

function PrefabPOI:GetTagDist()
	local type_tile = const.TypeTileSize
	local min_dist_to, max_dist_to = {}, {}
	local tag_to_tag_limits = GetPrefabTagsLimits()
	for poi_tag in pairs(self.Tags) do
		for tag, limits in pairs(tag_to_tag_limits[poi_tag]) do
			local min_dist, max_dist = limits[1] or min_int, limits[2] or max_int
			if min_dist >= 0 then
				min_dist_to[tag] = Max(min_dist_to[tag] or 0, min_dist)
			end
			if max_dist < max_int then
				max_dist_to[tag] = Min(max_dist_to[tag] or max_int, max_dist)
			end
		end
	end
	local text = {}
	for tag, dist in sorted_pairs(min_dist_to) do
		text[#text + 1] = string.format("%s > %.1f m", tag, 1.0 * dist / guim)
	end
	for tag, dist in sorted_pairs(max_dist_to) do
		text[#text + 1] = string.format("%s < %.1f m", tag, 1.0 * dist / guim)
	end
	return table.concat(text, "\n")
end

function PrefabPOI:GetError()
	if self.PlaceModel == "" then
		return "Placement model must be specified"
	end
	if self.TerrainSlopeMax < self.TerrainSlopeMin then
		return "Invalid slope range"
	end
	if self.MaxCount >= 0 and self.MaxCount < self.MinCount then
		return "Invalid count range"
	end
	local ids = {}
	for _, area in ipairs(self.PrefabTypeGroups) do
		if ids[area.id] then
			return "Duplicated prefab type area " .. area.id
		end
		ids[area.id] = true
	end
end

----

DefineClass.PrefabTypeGroup = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "id",     name = "Id",    editor = "text",           default = "Default" },
		{ id = "types",  name = "Types", editor = "preset_id_list", default = false, preset_class = "PrefabType", auto_expand = true, },
	},
	EditorView = Untranslated("<id> [<TypesCount>]"),
}

function PrefabTypeGroup:GetTypesCount()
	return #(self.types or "")
end

function PrefabTypeGroup:GetError()
	if (self.id or "") == "" then
		return "Group name expected."
	end
	if #(self.types or "") == 0 then
		return "At least one prefab type is required to form a group."
	end
end
