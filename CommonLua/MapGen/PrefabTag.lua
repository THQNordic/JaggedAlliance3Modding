DefineClass.DistToTag = {
	__parents = { "PropertyObject", },
	properties = {
		{ category = "General", id = "Tag",  name = "Tag",  editor = "preset_id", default = false, preset_class = "PrefabTag" },
		{ category = "General", id = "Dist", name = "Dist", editor = "number", default = 0, scale = "m" },
		{ category = "General", id = "Op",   name = "Op",   editor = "choice", default = '>', items = {'>', '<'} },
	},
	EditorView = Untranslated("<Tag> <Op> <dist(Dist)>"),
}

DefineClass.PrefabTag = {
	__parents = { "Preset", },
	properties = {
		{ category = "General", id = "Persistable",      name = "Persistable",           editor = "bool",        default = false, help = "POI prefabs with such tag will try to persist their location between map generations." },
		{ category = "General", id = "TagDist",          name = "Dist To Tags",          editor = "nested_list", default = empty_table, base_class = "DistToTag", help = "Defines the distances to the border of other POI with specified tags" },
		{ category = "General", id = "TagDistStats",     name = "All Dist Stats",        editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "PrefabPOI",        name = "POI Types",             editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "PrefabTypes",      name = "Prefab Types",          editor = "text",        default = "", lines = 1, max_lines = 20, dont_save = true, read_only = true },
		{ category = "General", id = "Prefabs",          name = "Prefabs",               editor = "text",        default = "", lines = 1, max_lines = 30, dont_save = true, read_only = true },
	},
	EditorMenubarName = "Prefab Tags",
	EditorIcon = "CommonAssets/UI/Icons/list.png",
	EditorMenubar = "Map.Generate",
	StoreAsTable = false,
	GlobalMap = "PrefabTags",
}

function PrefabTag:GetEditorViewPresetPrefix()
	return self.Persistable and "<color 255 255 0>" or ""
end

function PrefabTag:GetEditorViewPresetPostfix()
	return self.Persistable and "</color>" or ""
end

function PrefabTag:GetTagDistStats()
	local tag_to_tag_limits = GetPrefabTagsLimits(true)
	local stats = {}
	for tag, limits in sorted_pairs(tag_to_tag_limits[self.id]) do
		local min_dist, max_dist = limits[1] or min_int, limits[2] or max_int
		if min_dist and min_dist >= 0 then
			stats[#stats + 1] = string.format("%s > %d m", tag, min_dist / guim)
		end
		if max_dist and max_dist < max_int then
			stats[#stats + 1] = string.format("%s < %d m", tag, max_dist / guim)
		end
	end
	table.sort(stats)
	return table.concat(stats, "\n")
end

function PrefabTag:GetPrefabPOI()
	local tag = self.id
	local presets = {}
	ForEachPreset("PrefabPOI", function(preset, group, tag, presets)
		local tags = preset.Tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = preset.id
		end
	end, tag, presets)
	table.sort(presets)
	return table.concat(presets, "\n")
end

function PrefabTag:GetPrefabTypes()
	local tag = self.id
	local presets = {}
	ForEachPreset("PrefabType", function(preset, group, tag, presets)
		local tags = preset.Tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = preset.id
		end
	end, tag, presets)
	table.sort(presets)
	return table.concat(presets, "\n")
end

function PrefabTag:GetPrefabs()
	local tag = self.id
	local presets = {}
	local markers = PrefabMarkers
	for _, marker in ipairs(markers) do
		local tags = marker.tags or empty_table
		if tags[tag] then
			presets[#presets + 1] = markers[marker]
		end
	end
	table.sort(presets)
	return table.concat(presets, "\n")
end

function PrefabTag:GetError()
	local tag_to_tag_limits = GetPrefabTagsLimits()
	for tag, limits in sorted_pairs(tag_to_tag_limits[self.id]) do
		local min_dist, max_dist = limits[1] or min_int, limits[2] or max_int
		if min_dist >= max_dist then
			return "Invalid limitst"
		end
	end
end

----

function GetPrefabTagsLimits(mirror)
	local tag_to_tag_limits = {}
	for tag1, tag_info in pairs(PrefabTags) do
		local tag_limits
		for _, entry in ipairs(tag_info.TagDist) do
			if not tag_limits then
				tag_limits = tag_to_tag_limits[tag1]
				if not tag_limits then
					tag_limits = {}
					tag_to_tag_limits[tag1] = tag_limits
				end
			end
			local tag2 = entry.Tag
			local limits = tag_limits[tag2]
			if not limits then
				limits = {}
				tag_limits[tag2] = limits
				if mirror and tag1 ~= tag2 then
					table.set(tag_to_tag_limits, tag2, tag1, limits)
				end
			end
			local dist = entry.Dist
			local op = entry.Op
			if op == '>' then
				limits[1] = Max(limits[1] or min_int, dist)
			elseif op == '<' then
				limits[2] = Min(limits[2] or max_int, dist)
			end
		end
	end
	return tag_to_tag_limits
end

function GetPrefabTagsPersistable()
	local tags = {}
	for tag, tag_info in pairs(PrefabTags) do
		if tag_info.Persistable then
			tags[tag] = true
		end
	end
	return tags
end

----

function PrefabTagsCombo()
	local tags = {}
	ForEachPreset("PrefabTag", function(preset, group, tags)
		tags[#tags + 1] = preset.id
	end, tags)
	table.sort(tags)
	return tags
end

----

AppendClass.MapDataPreset = { properties = {
	{ category = "Random Map", id = "PersistedPrefabs", editor = "prop_table", default = empty_table, no_edit = true },
	{ category = "Random Map", id = "PersistedPrefabsPreview", name = "Persisted Prefabs", editor = "text", default = "", read_only = true, lines = 1, max_lines = 10 }
}}

function MapDataPreset:GetPersistedPrefabsPreview()
	local text = {}
	for _, entry in ipairs(self.PersistedPrefabs) do
		text[#text + 1] = table.concat(entry, ", ")
	end
	return table.concat(text, "\n")
end
