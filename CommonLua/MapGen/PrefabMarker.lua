local type_tile = const.TypeTileSize
local height_tile = const.HeightTileSize
local grass_tile = const.GrassTileSize
local height_scale = const.TerrainHeightScale
local empty_table = empty_table
local GetClassFlags = CObject.GetClassFlags
local SetGameFlags = CObject.SetGameFlags
local developer = Platform.developer and Platform.desktop
local unpack = table.unpack
local def_size = point(20*guim, 20*guim)
local capture_items = {"Height", "Terrain", "Grass"}
local def_capt = set(table.unpack(capture_items))
local mask_max = 255
local invalid_type_value = 255
local invalid_grass_value = 255
local transition_max_pct = 30

function GetTerrainGridsMaxGranularity()
	local granularity = Max(grass_tile, type_tile, height_tile)
	assert(granularity % grass_tile == 0)
	assert(granularity % type_tile == 0)
	assert(granularity % height_tile == 0)
	return granularity
end

local function ApplyHeightOpCombo(first)
	local items = { 
		{value = '=', text = "Equals"}, 
		{value = '<', text = "Min"},
		{value = '>', text = "Max"},
		{value = '~', text = "Average"},
		{value = '+', text = "Add"},
	}
	if first then
		table.insert(items, 1, first)
	end
	return items
end

local post_process_items = {
	{ value = 0, text = "" },
	{ value = 1, text = "fill holes"},
	{ value = 2, text = "adjust capture"},
}

assert(type_tile == const.HeightTileSize)

if FirstLoad then
	PrefabMarkers = {}
	ExportedPrefabs = {}
	
	PrefabTypes = {}
	PrefabTypeToPrefabs = {}
	
	PrefabDimensions = empty_table
end

PrefabMarkerVersion = '1'

local p_dprint = CreatePrint{ "RM", format = print_format, output = DebugPrint }
local p_print = developer and CreatePrint{ "RM", format = print_format, color = yellow} or p_dprint

function GetPrefabFileObjs(name)
	return string.format("Prefabs/%s.bin", name)
end

function GetPrefabFileHeight(name)
	return string.format("Prefabs/%s.h.grid", name)
end

function GetPrefabFileType(name)
	return string.format("Prefabs/%s.t.grid", name)
end

function GetPrefabFileGrass(name)
	return string.format("Prefabs/%s.g.grid", name)
end

function GetPrefabFileMask(name)
	return string.format("Prefabs/%s.m.grid", name)
end

local function GetRotationModesCombo()
	return {
		{ value = false,   text = "" },
		{ value = "slope", text = "Follow Slope Angle" },
		{ value = "map",   text = "Follow Map Orientation" },
	}
end

local function GetPoiAreas(self)
	local names = {}
	local poi_preset = PrefabPoiToPreset[self.PoiType]
	for _, group in pairs(poi_preset and poi_preset.PrefabTypeGroups) do
		names[#names + 1] = group.id
	end
	table.sort(names)
	return names
end

local function GetPoiAreasCount(self)
	local poi_preset = PrefabPoiToPreset[self.PoiType]
	return #(poi_preset and poi_preset.PrefabTypeGroups or "")
end

----

DefineClass.PrefabObj = {
	__parents = { "Object", "EditorVisibleObject" },
	flags = { efWalkable = false, efCollision = false, efApplyToGrids = false },
	Scale = 250,
}

function PrefabObj:Init()
	self:SetScale(self.Scale)
	self:SetVisible(IsEditorActive())
end

----

DefineClass.DebugOverlayControl = {
	__parents = { "PropertyObject" },
}

----

DefineClass.PrefabMarker = {
	__parents = { "MapMarkerObj", "PrefabObj", "DebugOverlayControl" },
	flags = { efWalkable = false, efApplyToGrids = false, efCollision = false, gofAlwaysRenderable = true },
	entity = "WayPointBig",
	properties = {
		{ id = "PrefabName",        name = "Name",                  editor = "text",         default = "",          category = "Prefab",  read_only = true, dont_save = true, },
		{ id = "ExportedName",      name = "Exported",              editor = "text",         default = "",          category = "Prefab",  read_only = true, buttons = {{name = "Export", func = "ActionPrefabExport"}, {name = "Revision", func = "ActionPrefabRevision"}, {name = "Folder", func = "ActionExploreTo"}}},
		{ id = "ExportError",       name = "Export Error",          editor = "text",         default = "",          category = "Prefab",  read_only = true, no_edit = function(self) return self.ExportError == "" end },
		{ id = "ExportedHash",                                      editor = "number",       default = false,       category = "Prefab", export = "hash", no_edit = true },
		{ id = "AssetsRevision",    name = "Assets Revision",       editor = "number",       default = false,       category = "Prefab", export = "revision", read_only = true },
		{ id = "PrefabType",        name = "Type",                  editor = "preset_id",    default = "",          category = "Prefab", export = "type", compatibility = true, preset_class = "PrefabType", },
		{ id = "PrefabWeight",      name = "Weight",                editor = "number",       default = 100,         category = "Prefab", export = "weight", compatibility = true, min = 0 },
		{ id = "PrefabMaxCount",    name = "Max Count",             editor = "number",       default = -1,          category = "Prefab", export = "max_count", compatibility = true },
		{ id = "RepeatReduct",      name = "Repeat Reduct (%)",     editor = "number",       default = 0,           category = "Prefab", export = "repeat_reduct", compatibility = true, min = 0, max = 100, slider = true, no_edit = function(self) return self.PoiType ~= "" end },
		{ id = "PrefabOrient",      name = "Orientation",           editor = "point",        default = axis_x,      category = "Prefab", helper = "relative_pos", compatibility = true, helper_outside_object = true, use_object = true, help = "Used to specify a common orientation for a set of prefabs." },
		{ id = "PrefabAngle",       name = "Angle (deg)",           editor = "number",       default = 0,           category = "Prefab", export = "angle", compatibility = true, scale = 60, read_only = true, dont_save = true },
		{ id = "PrefabAngleVar",    name = "Angle Variate (deg)",   editor = "number",       default = 180*60,      category = "Prefab", export = "angle_variation", compatibility = true, min = 0, max = 180*60, slider = true, scale = 60, help = "Random variation around the prefab angle" },
		{ id = "PrefabRotateMode",  name = "Rotation Mode",         editor = "choice",       default = "map",       category = "Prefab", export = "rotation_mode", compatibility = true, items = GetRotationModesCombo },
		{ id = "DecorObstruct",     name = "Decor Obstruct",        editor = "bool",         default = false,       category = "Prefab", export = "decor_obstruct", compatibility = true, help = "Obstruct placement of other decor prefabs in its area. Option valid only when placed as decor." },
		{ id = "SaveCollections",   name = "Important Collections", editor = "bool",         default = false,       category = "Prefab", export = "save_collections", help = "If specified, the collections in the prefab will be persisted after the generation." },
		{ id = "Tags",              name = "Tags",                  editor = "set",          default = empty_table, category = "Prefab", export = "tags", compatibility = true, items = function() return PrefabTagsCombo() end, help = "Keywords used to group similar prefabs" },
		{ id = "AllTags",           name = "All Tags",              editor = "text",         default = "",          category = "Prefab", read_only = true, dont_save = true, help = "Includes the tags inherited from prefab type and POI type" },
		{ id = "PoiType",           name = "POI Type",              editor = "preset_id",    default = "",          category = "Prefab", export = "poi_type", compatibility = true, preset_class = "PrefabPOI", },
		{ id = "PoiArea",           name = "POI Area",              editor = "choice",       default = "",          category = "Prefab", export = "poi_area", compatibility = true, items = GetPoiAreas, no_edit = function(self) return GetPoiAreasCount(self) ==0 end, help = "Disregard prefab type and use POI area instead." },
		
		{ id = "CaptureSet",       name = "Capture",           editor = "set",          default = def_capt,  category = "Terrain", items = capture_items },
		{ id = "CaptureSize",      name = "Size",              editor = "point",        default = def_size,  category = "Terrain", export = "size", scale = "m", min = 0, granularity = GetTerrainGridsMaxGranularity(),
			helper = "terrain_rect", terrain_rect_color = RGBA(64, 196, 0, 96), terrain_rect_step = guim/2, terrain_rect_zoffset = guim/4, terrain_rect_depth_test = true, terrain_rect_grid = true,
			buttons = { {name = "Capture", func = "ActionCaptureTerrain"}, {name = "Clear", func = "ActionClearTerrain"}, },
		},
		{ id = "Centered",         name = "Centered",          editor = "bool",         default = false,     category = "Terrain", compatibility = true, help = "Specify if the marker is in the center of the capture area"}, 
		{ id = "HeightOp",         name = "Apply Height",      editor = "dropdownlist", default = '+',       category = "Terrain", export = "height_op", items = function() return ApplyHeightOpCombo() end, help = "Specify how the captured terrain height would be applied over the existing" },
		{ id = "InvalidTerrain",   name = "Invalid Terrain",   editor = "dropdownlist",                      category = "Terrain", items = function() return GetTerrainNamesCombo() end, help = "Tiles with invalid terrain type wont be captured" },
		{ id = "InvalidGrass",     name = "Invalid Grass",     editor = "number",       default = -1,        category = "Terrain", help = "Tiles with invalid grass density wont be captured. The final values will be remapped if possible to fit the whole density range." },
		{ id = "SkippedTerrains",  name = "Skipped Terrains",  editor = "string_list",  default = false,     category = "Terrain", items = function() return GetTerrainNamesCombo() end, help = "Tiles with invalid terrain type wont be captured" },
		{ id = "ApplyTerrain",     name = "Apply Terrain",     editor = "dropdownlist", default = '',        category = "Terrain", items = {'', 'invalid'}, help = "Specify how the captured terrain type would be applied over the existing", },
		{ id = "TransitionZone",   name = "Transition Zone",   editor = "number",       default = 64*guim,   category = "Terrain", compatibility = true, min = 0, max = function(o) return o:GetMaxTransitionDist() end, slider = true, scale = "m", granularity = type_tile, help = "Transition zone for smooth stitching" },
		{ id = "CircleMask",       name = "Circle Mask",       editor = "bool",         default = false,     category = "Terrain",},
		{ id = "CircleMaskRadius", name = "Custom Mask Radius",editor = "number",       default = false,     category = "Terrain", scale = "m", no_edit = PropChecker("CircleMask", false) },
		{ id = "PostProcess",      name = "Post Process",      editor = "dropdownlist", default = 2,         category = "Terrain", items = post_process_items, no_edit = function(self) return self.CircleMask end},
		{ id = "TerrainPreview",   name = "Terrain Preview",   editor = "bool",         default = true,      category = "Terrain" },
		{ id = "HeightMap",        name = "Height Map",        editor = "grid",         default = false,     category = "Terrain", read_only = true, dont_save = true, min = 128, max = 256, no_edit = function(self) return not self.TerrainPreview end, grid_offset = function(self) return self.HeightOffset end },
		{ id = "HeightHash",                                   editor = "number",       default = false,     category = "Terrain", export = "height_hash", no_edit = true },
		{ id = "HeightOffset",                                 editor = "number",       default = 0,         category = "Terrain", export = "height_offset", no_edit = true },
		{ id = "HeightMin",                                    editor = "point",        default = point30,   category = "Terrain", export = "min", no_edit = true },
		{ id = "HeightMax",                                    editor = "point",        default = point30,   category = "Terrain", export = "max", no_edit = true },
		{ id = "TypeMap",          name = "Terrain Type",      editor = "grid",         default = false,     category = "Terrain", read_only = true, dont_save = true, min = 128, max = 256, color = true, invalid_value = invalid_type_value, no_edit = function(self) return not self.TerrainPreview end, },
		{ id = "TypeHash",                                     editor = "number",       default = false,     category = "Terrain", export = "type_hash", no_edit = true },
		{ id = "TypeNames",                                    editor = "prop_table",   default = false,     category = "Terrain", export = "type_names", no_edit = true,},
		{ id = "GrassMap",         name = "Grass",             editor = "grid",         default = false,     category = "Terrain", read_only = true, dont_save = true, min = 128, max = 256, invalid_value = invalid_grass_value, no_edit = function(self) return not self.TerrainPreview end, },
		{ id = "GrassHash",                                    editor = "number",       default = false,     category = "Terrain", export = "grass_hash", no_edit = true },
		{ id = "MaskMap",          name = "Transition Mask",   editor = "grid",         default = false,     category = "Terrain", read_only = true, dont_save = true, min = 128, max = 256, no_edit = function(self) return not self.TerrainPreview end, },
		{ id = "MaskHash",                                     editor = "number",       default = false,     category = "Terrain", export = "mask_hash", no_edit = true },
		
		{ id = "RequiredMemory",     name = "Required Memory (KB)", editor = "number",       default = 0,         category = "Stats", export = "required_memory", read_only = true, scale = 1024 },
		{ id = "TerrainCaptureTime", name = "Terrain Capture (ms)", editor = "number",       default = 0,         category = "Stats", read_only = true, dont_save = true },
		{ id = "PlayArea",                                          editor = "number",       default = 0,         category = "Stats", export = "play_area", compatibility = true, no_edit = true },
		{ id = "TotalArea",                                         editor = "number",       default = 0,         category = "Stats", export = "total_area", compatibility = true, no_edit = true },
		{ id = "RadiusMin",                                         editor = "number",       default = 0,         category = "Stats", export = "min_radius", compatibility = true, no_edit = true },
		{ id = "RadiusMax",                                         editor = "number",       default = 0,         category = "Stats", export = "max_radius", compatibility = true, no_edit = true },
		{ id = "PlayAreaRatio",     name = "Play Area (%)",         editor = "number",       default = 0,         category = "Stats", read_only = true, dont_save = true },
		{ id = "MapTotalArea",      name = "Total Area (m^2)",      editor = "number",       default = 0,         category = "Stats", scale = guim*guim, read_only = true, dont_save = true },
		{ id = "MapRadiusMin",      name = "Min Radius (m)",        editor = "number",       default = 0,         category = "Stats", scale = guim, read_only = true, dont_save = true },
		{ id = "MapRadiusMax",      name = "Max Radius (m)",        editor = "number",       default = 0,         category = "Stats", scale = guim, read_only = true, dont_save = true },
		{ id = "HeightRougness",    name = "Height Rougness",       editor = "number",       default = 0,         category = "Stats", read_only = true, help = "Quantative estimation of the maximum height map roughness" },
		{ id = "ObjCount",          name = "Obj Count",             editor = "number",       default = 0,         category = "Stats", export = "obj_count", compatibility = true, read_only = true, help = "Relative to the maximum allowed object density" },
		{ id = "ObjMaxCount",       name = "Obj Max Count",         editor = "number",       default = 0,         category = "Stats", read_only = true, help = "Maximum allowed objects for the current size of the prefab" },
		{ id = "ObjRadiusMin",      name = "Obj Radius Min (m)",    editor = "number",       default = 0,         category = "Stats", export = "obj_min_radius", read_only = true, scale = guim,  },
		{ id = "ObjRadiusMax",      name = "Obj Radius Max (m)",    editor = "number",       default = 0,         category = "Stats", export = "obj_max_radius", read_only = true, scale = guim,  },
		{ id = "ObjRadiusAvg",      name = "Obj Radius Avg (m)",    editor = "number",       default = 0,         category = "Stats", export = "obj_avg_radius", read_only = true, scale = guim,  },
		{ id = "NestedColls",       name = "Nested Collections",    editor = "prop_table",   default = false,     category = "Stats", export = "nested_colls", read_only = true, indent = ' '},
		{ id = "NestedOptObjs",     name = "Nested Optional Objs",  editor = "prop_table",   default = false,     category = "Stats", export = "nested_opt_objs", read_only = true, indent = ' '},
	},
	InvalidTerrain = "", -- will be assigned later from the constant defs
}

function OnMsg.ClassesGenerate()
	PrefabMarker.InvalidTerrain = table.get(const, "Prefab", "InvalidTerrain") or ""
end

function PrefabMarker:GetPrefabAngle()
	return CalcOrientation(self.PrefabOrient)
end

local function PrefabFilter(pstyles, ptypes, revision, version)
	revision = revision or AssetsRevision
	version = version or max_int
	local matched
	local markers = PrefabMarkers
	for i=1,#markers do
		local marker = markers[i]
		if (not pstyles or marker.style == "" or pstyles[marker.style])
		and (not ptypes or marker.type == "" or ptypes[marker.type])
		and revision >= (marker.revision or 0)
		and version >= (marker.version or 1) then
			matched = matched or {}
			matched[#matched + 1] = marker
		end
	end
	return matched or empty_table
end

function PrefabMarker:GetPlayAreaRatio()
	return self.TotalArea > 0 and MulDivRound(100, self.PlayArea, self.TotalArea) or 0
end

function PrefabMarker:GetMapTotalArea()
	return self.TotalArea * type_tile * type_tile
end


function PrefabMarker:GetMapRadiusMin()
	return self.RadiusMin * type_tile
end

function PrefabMarker:GetMapRadiusMax()
	return self.RadiusMax * type_tile
end

function PrefabComposeName(props)
	local prefab_name = props.name or ""
	if #prefab_name > 0 then
		local prefab_type = props.type or ""
		if prefab_type == "" then
			prefab_type = "Any"
		end
		prefab_name = prefab_type .. "." .. prefab_name
		local prefab_style = props.style or ""
		if #prefab_style ~= 0 then
			prefab_name = prefab_style .. "." .. prefab_name
		end
	end
	return prefab_name
end

function PrefabMarker:GetPrefabName()
	return PrefabComposeName{name = self.MarkerName, type = self.PrefabType}
end

function PrefabMarker:GetAllTags()
	local poi_tags = table.get(PrefabPoiToPreset, self.PoiType, "Tags")
	local ptype_tags = table.get(PrefabTypeToPreset, self.PrefabType, "Tags")
	local marker_tags = self.Tags
	local tags = {}
	table.append(tags, ptype_tags)
	table.append(tags, marker_tags)
	table.append(tags, poi_tags)
	return table.concat(table.keys(tags, true), ", ")
end

----

function GetTypeRemapping(name_to_idx)
	local type_remapping
	local TerrainTextures = TerrainTextures
	local GetTerrainTextureIndex = GetTerrainTextureIndex
	for name, idx in pairs(name_to_idx or empty_table) do
		if TerrainTextures[idx].id ~= name then
			local new_idx = GetTerrainTextureIndex(name)
			if not new_idx then
				assert(false, "No such terrain type: " .. name)
			else
				type_remapping = type_remapping or {}
				type_remapping[idx] = new_idx
			end
		end
	end
	if type_remapping then
		for i = 0, MaxTerrainTextureIdx() do
			type_remapping[i] = type_remapping[i] or i
		end
	end
	return type_remapping
end

function PrefabMarker:GetMaxTransitionDist()
	local min_size = Min(self.CaptureSize:xy())
	return Min(type_tile * mask_max, min_size * transition_max_pct / 100)
end

function PrefabMarker:GetTransitionDist()
	return Max(0, Min(self.TransitionZone, self:GetMaxTransitionDist()))
end

----

local function PrefabUpdateExported()
	ExportedPrefabs = {}
	local err, list = AsyncListFiles("Prefabs", "*.bin")
	if err then
		p_print("PrefabUpdateExported: ", err)
		return
	end
	for i=1,#list do
		local file = list[i]
		local dir, name, ext = SplitPath(file)
		if ExportedPrefabs[name] then
			p_print("Duplicated exported prefab name:", name)
		else
			ExportedPrefabs[name] = true
		end
	end
end

function PrefabCalcStats(prefabs)
	local min_prefab_radius, max_prefab_radius = max_int, min_int
	local avg_prefab_radius, radius_prefabs = 0, 0
	local min_height, max_height = max_int, min_int
	local avg_max_height, avg_min_height, height_prefabs = 0, 0, 0
	local min_play_area, max_play_area = max_int, min_int
	local avg_play_area, play_prefabs = 0, 0
	local function get_avg(avg, count, value)
		return (avg * count + value) / (count + 1)
	end
	for i = 1,#prefabs do
		local prefab = prefabs[i]
		local play_area = prefab.play_area or 0
		if play_area > 0 then
			min_play_area = Min(min_play_area, play_area)
			max_play_area = Max(max_play_area, play_area)
			avg_play_area = get_avg(avg_play_area, play_prefabs, play_area)
			play_prefabs = play_prefabs + 1
		end
		local radius = prefab.max_radius or 0
		if radius > 0 then
			min_prefab_radius = Min(min_prefab_radius, radius)
			max_prefab_radius = Max(max_prefab_radius, radius)
			avg_prefab_radius = get_avg(avg_prefab_radius, radius_prefabs, radius)
			radius_prefabs = radius_prefabs + 1
		end
		if prefab.max and prefab.min then
			max_height = Max(max_height, prefab.max:z())
			min_height = Min(min_height, prefab.min:z())
			avg_max_height = get_avg(avg_max_height, height_prefabs, max_height)
			avg_min_height = get_avg(avg_min_height, height_prefabs, min_height)
			height_prefabs = height_prefabs + 1
		end
	end
	return {
		MinRadius = min_prefab_radius,
		MaxRadius = max_prefab_radius,
		AvgRadius = avg_prefab_radius,
		MinPlayArea = min_play_area,
		MaxPlayArea = max_play_area,
		AvgPlayArea = avg_play_area,
		MaxHeight = max_height,
		MinHeight = min_height,
		AvgMaxHeight = avg_max_height,
		AvgMinHeight = avg_min_height,
	}
end

local function ConvertTags(tags)
	return tags and table.invert(tags) or nil
end
					
function PrefabUpdateMarkers()
	local markers = Markers
	local hash_keys = {"hash", "height_hash", "type_hash", "mask_hash"}
	local versions = {}
	local prefabs = {}
	local deprecated = 0
	local type_to_prefabs = {}

	local defaults = {}
	for _, prop in ipairs(PrefabMarker:GetProperties()) do
		local export_id = prop.export
		if export_id then
			defaults[export_id] = PrefabMarker:GetProperty(prop.id)
		end
	end
	
	local PrefabTypeToPreset = PrefabTypeToPreset
	local ExportedPrefabs = ExportedPrefabs
	local PrefabComposeName = PrefabComposeName
	
	local prefab_meta = { __index = defaults }
	local any_type = {}
	for i = 1,#markers do
		local marker = markers[i]
		local data = marker.type == "Prefab" and marker.data 
		if data then
			local prefab = dostring(data)
			if not prefab then
				p_print("Prefab", marker.name, "unserialize props error!")
			else
				local name = PrefabComposeName(prefab)
				if not ExportedPrefabs[name] then
					p_print("No exported prefab found ", name, "on", marker.map, "at", marker.pos)
				elseif prefabs[name] then
					local prev = prefabs[name]
					p_print("Duplicated prefabs:\n\t1.", name, "on", marker.map, "at", marker.pos, "\n\t2.", prefabs[prev], "on", prev.marker.map, "at", prev.marker.pos)
				else
					local ptype = prefab.type or ""
					if ptype == "" or PrefabTypeToPreset[ptype] then
						setmetatable(prefab, prefab_meta)
						prefabs[#prefabs + 1] = prefab
						prefabs[name] = prefab
						prefabs[prefab] = name
						
						local type_prefabs = ptype == "" and any_type or type_to_prefabs[ptype]
						if type_prefabs then
							type_prefabs[#type_prefabs + 1] = prefab
						else
							type_to_prefabs[prefab.type] = {prefab}
						end
						if marker.data_version ~= PrefabMarkerVersion then
							deprecated = deprecated + 1
						end
						local version = prefab.version or 1
						local info = versions[version] or {count = 0}
						versions[version] = info
						info.count = info.count + 1
						for _, key in ipairs(hash_keys) do
							info[key] = xxhash(prefab[key], info[key])
						end
						prefab.marker = marker
					end
				end
			end
		end
	end
	for ptype, prefabs in ipairs(type_to_prefabs) do
		table.iappend(prefabs, any_type)
	end
	if deprecated > 0 then
		p_print(deprecated, "deprecated prefabs need re-export")
	end
	if const.RandomMap.PrefabVersionLog then
		p_dprint("Prefab marker versions:", TableToLuaCode(versions))
	end
	table.sort(prefabs, function(a, b) return prefabs[a] < prefabs[b] end)
	PrefabMarkers = prefabs
	PrefabDimensions = PrefabCalcStats(prefabs)
	PrefabTypeToPrefabs = type_to_prefabs
	PrefabTypes = table.keys(type_to_prefabs, true)
		
	Msg("PrefabMarkersChanged")
	DelayedCall(0, ReloadShortcuts)
end

function PrefabSaveCmp(cmp_version, filename, cmp_fmt, cmp_props)
	filename = filename or "cmp.txt"
	cmp_props = cmp_props or {"hash", "height_hash", "type_hash", "mask_hash"}
	cmp_fmt = cmp_fmt or "%40s | %12s | %12s | %12s | %12s |\n"
	local props = {}
	local cmp_list = {string.format(cmp_fmt, "name", unpack(cmp_props)), string.rep('-', 120), "\n"}
	for i, marker in ipairs(PrefabMarkers) do
		if not cmp_version or (marker.version or 1) == cmp_version then
			local name = PrefabMarkers[marker] or ""
			for i, key in ipairs(cmp_props) do
				props[i] = marker[key] or ""
			end
			cmp_list[#cmp_list + 1] = string.format(cmp_fmt, name, unpack(props))
		end
	end
	return AsyncStringToFile(filename, cmp_list)
end

function OnMsg.DataLoaded()
	CreateRealTimeThread(function()
		PrefabUpdateExported()
		PrefabUpdateMarkers()
	end)
end

function PrefabPreload(prefab, params_meta, skip)
	local name = PrefabMarkers[prefab]
	if not ExportedPrefabs[name] then
		p_print("No such exported prefab", name)
		return
	end
	local load_err, height_grid, type_grid, grass_grid, mask_grid, type_remapping, height_op, height_offset
	local skip_height = skip and skip.Height
	local height_file = not skip_height and prefab.height_hash and GetPrefabFileHeight(name)
	if height_file then
		height_grid, load_err = GridReadFile(height_file)
		if load_err then
			p_print("Failed to load height map of", name, ":", load_err or "failed")
			return
		end
		if developer and xxhash(height_grid) ~= prefab.height_hash then
			p_print("Detected changes in the height map of", name)
		end
		height_op = prefab.height_op
		height_offset = prefab.height_offset
	end
	local skip_type = skip and skip.Type
	local type_file = not skip_type and prefab.type_hash and GetPrefabFileType(name)
	if type_file then
		type_grid, load_err = GridReadFile(type_file)
		if load_err then
			p_print("Failed to load type map of", name, ":", load_err or "failed")
			return
		end
		if developer and xxhash(type_grid) ~= prefab.type_hash then
			p_print("Detected changes in the type map of", name)
		end
		type_remapping = GetTypeRemapping(prefab.type_names)
	end
	local skip_grass = skip and skip.Grass
	local grass_file = not skip_grass and prefab.grass_hash and GetPrefabFileGrass(name)
	if grass_file then
		grass_grid, load_err = GridReadFile(grass_file)
		if load_err then
			p_print("Failed to load grass map of", name, ":", load_err or "failed")
			return
		end
		if developer and xxhash(grass_grid) ~= prefab.grass_hash then
			p_print("Detected changes in the grass map of", name)
		end
	end
	local mask_file = prefab.mask_hash and GetPrefabFileMask(name)
	if mask_file then
		mask_grid, load_err = GridReadFile(mask_file)
		if load_err then
			p_print("Failed to load mask of", name, ":", load_err or "failed")
			return
		end
		if developer and xxhash(mask_grid) ~= prefab.mask_hash then
			p_print("Detected changes in the mask of", name)
		end
	end
	local params = {
		height_grid = height_grid,
		height_op = height_op,
		height_offset = height_offset,
		type_grid = type_grid,
		type_remapping = type_remapping,
		grass_grid = grass_grid,
		mask_grid = mask_grid,
	}
	if params_meta then
		setmetatable(params, params_meta)
	end
	return params
end

function PlacePrefab(name, prefab_pos, prefab_angle, seed, place_params)
	if (name or "") == "" or not ExportedPrefabs[name] then
		return "no exported prefab found"
	end
	local filename = GetPrefabFileObjs(name)
	local err, bin = AsyncFileToString(filename, nil, nil, "pstr")
	if err then
		return err
	end
	local defs = Unserialize(bin)
	if not defs then
		return "Failed to unserialize objects"
	end
	
	local prefab = PrefabMarkers[name]
	if not prefab then
		return "no such prefab marker"
	end
	local raster_params = PrefabPreload(prefab)
	if not raster_params then
		return "prefab loading failed"
	end
	
	local existing_objs = MapGet(prefab_pos, prefab.max_radius * type_tile, "attached", false, function(obj)
		return not IsClutterObj(obj) and GetClassFlags(obj, const.cfCodeRenderable) == 0
	end) or {}
	
	place_params = place_params or empty_table
	
	local change_height = not not raster_params.height_grid
	local change_type = not not raster_params.type_grid
	local change_grass = not not raster_params.grass_grid
	
	local create_undo = place_params.create_undo
	if create_undo then
		XEditorUndo:BeginOp{
			name = "PlacePrefab",
			height = change_height,
			terrain_type = change_type,
			grass_density = change_grass,
			objects = existing_objs,
		}
	end
	
	prefab_angle = (prefab_angle or 0) - (prefab.angle or 0)
	
	local inv_bbox
	if change_height or change_type or change_grass then
		raster_params.pos = prefab_pos
		raster_params.angle = prefab_angle
		raster_params.dither_seed = seed
		err, inv_bbox = AsyncGridSetTerrain(raster_params)
		if err then
			if create_undo then
				XEditorUndo:EndOp(existing_objs)
			end
			return "failed to apply terrain"
		elseif inv_bbox then
			if change_height then
				terrain.InvalidateHeight(inv_bbox)
			end
			if change_type then
				terrain.InvalidateType(inv_bbox)
			end
		end
	end
				
	local gof = const.gofPermanent | const.gofGenerated
	local cofComponentRandomMap = const.cofComponentRandomMap
	local g_Classes = g_Classes
	local GetPrefabObjPos, SetPrefabObjPos = GetPrefabObjPos, SetPrefabObjPos
	local PropObjSetProperty = PropObjSetProperty
	local dont_clamp_objects = place_params.dont_clamp_objects
	local ignore_ground_offset = place_params.ignore_ground_offset
	local fadein = place_params.fadein
	local save_collections = prefab.save_collections
	local placed_cols = 0
	local remap_col_idx, last_col_idx
	local objs = {}
	local base_prop_count = const.RandomMap.PrefabBasePropCount
	
	SuspendPassEdits("PlacePrefab")
	
	for _, def in ipairs(defs) do
		local class, dpos, angle, daxis,
			scale, rmf_flags, fade_dist,
			ground_offset, normal_offset,
			coll_idx, color, mirror = unpack(def, 1, base_prop_count)

		assert(class ~= "Collection")
		local class_def = g_Classes[class]
		assert(class_def)

		if dont_clamp_objects then
			fade_dist = false
		end
		if ignore_ground_offset then
			ground_offset = false
		end
		
		local new_pos, new_angle, new_axis = GetPrefabObjPos(
			dpos, angle, daxis, fade_dist,
			prefab_pos, prefab_angle,
			ground_offset, normal_offset)
		
		if class_def and new_pos then
			local components = 0
			if rmf_flags then
				components = components | cofComponentRandomMap
			end
			local obj = class_def:new(nil, components)
			if fadein then
				obj:SetOpacity(0)
				if fadein ~= -1 then
					obj:SetOpacity(100, fadein)
				end
			end
			SetPrefabObjPos(obj, new_pos, new_angle, new_axis, scale, color, mirror)
			for i=base_prop_count+1,#def,2 do
				PropObjSetProperty(obj, def[i], def[i + 1])
			end
			if rmf_flags then
				obj:SetRandomMapFlags(rmf_flags)
			end
			if coll_idx and save_collections then
				local placed_idx = remap_col_idx and remap_col_idx[coll_idx]
				if not placed_idx then
					placed_idx = (last_col_idx or 0) + 1
					local collections = Collections
					while collections[placed_idx] do
						placed_idx = placed_idx + 1
					end
					if placed_idx <= const.GameObjectMaxCollectionIndex then
						local col = Collection:new()
						col:SetIndex(placed_idx)
						col:SetName(string.format("MapGen_%s", placed_idx))
						SetGameFlags(col, gof)
						remap_col_idx = table.create_set(remap_col_idx, coll_idx, placed_idx)
					else
						assert(false, "Too many collections created!")
						placed_idx = 0
					end
					remap_col_idx[coll_idx] = placed_idx
				end
				if placed_idx ~= 0 then
					obj:SetCollectionIndex(placed_idx)
				end
			end
			SetGameFlags(obj, gof)
			objs[#objs + 1] = obj
		end
	end
	
	for _, obj in ipairs(objs) do
		if obj.__ancestors.Object then
			obj:PostLoad()
		end
	end
	if IsEditorActive() then
		for _, obj in ipairs(objs) do
			if obj.__ancestors.EditorObject then
				obj:EditorEnter()
			end
		end
	end
	
	if change_height then
		local ClearCachedZ = CObject.ClearCachedZ
		local IsValidZ = CObject.IsValidZ
		for _, obj in ipairs(existing_objs) do
			if IsValid(obj) and not IsValidZ(obj) then
				ClearCachedZ(obj)
			end
		end
	end
	
	ResumePassEdits("PlacePrefab")
	
	if create_undo then
		table.iappend(existing_objs, objs)
		XEditorUndo:EndOp(existing_objs)
	end
	Msg("PrefabPlaced", name, objs)
	return nil, objs, inv_bbox
end

----

RandomMapFlags = {
	{ id = "IgnoreHeightOffset", name = "Ignore Height Offset",  flag = const.rmfNoGroundOffset,     help = "Disregard the original terrain height offset when placing the object" },
	{ id = "KeepNormalOffset",   name = "Keep Normal Offset",    flag = const.rmfNormalOffset,       help = "Keep the original terrain normal offset when placing the object" },
	{ id = "OptionalPlacement",  name = "Optional Placement",    flag = const.rmfOptionalPlacement,  help = "The object could be removed when placing its prefab" },
	{ id = "MeshOverlapCheck",   name = "Mesh Overlap Check",    flag = const.rmfMeshOverlapCheck,   help = "Check mesh overlap ratio to detect prefab out-of-bounds objects. Otherwise only the object's position is checked" },
	{ id = "DeleteOnSteepSlope", name = "Delete On Steep Slope", flag = const.rmfDeleteOnSteepSlope, help = "Will be deleted if placed on a too steep slope" },
}

function GetDefRandomMapFlags(classdef)
	local flags = 0
	for _, info in ipairs(RandomMapFlags) do
		if classdef[info.id] then
			flags = flags | info.flag
		end
	end
	return flags
end

DefineClass.StripRandomMapProps = {
	__parents = { "PropertyObject" },
	properties = {},
}

for _, info in ipairs(RandomMapFlags) do
	local id = info.id
	local flag = info.flag
	CObject[id] = false
	local prop = { category = "Random Map", id = id, name = info.name, editor = "bool", help = info.help }
	table.insert(CObject.properties, prop)
	table.insert(StripCObjectProperties.properties, { id = id } )
	table.insert(StripRandomMapProps.properties, { id = id })
	CObject["Set" .. id] = function(self, set)
		local flags = self:GetRandomMapFlags()
		local def_flags
		if not flags then
			flags = GetDefRandomMapFlags(self)
			def_flags = flags
		end
		if set then
			flags = flags | flag
		else
			flags = flags & ~flag
		end
		if flags == def_flags then
			return
		end
		self:SetRandomMapFlags(flags)
	end
	CObject["Get" .. id] = function(self)
		local flags = self:GetRandomMapFlags()
		if not flags then
			return self[id]
		end
		return (flags & flag) ~= 0
	end
end

DefineClass.PrefabSourceInfo = {
	__parents = { "Object", "EditorCallbackObject" },
	properties = {
		{ category = "Random Map", id = "Prefab", name = "Placed From", editor = "text", default = "", read_only = true, developer = true, buttons = {{name = "Goto", func = "GotoPrefabAction"}} },
	},
}

function PrefabSourceInfo:EditorCallbackGenerate(generator, object_source)
	local prefab = object_source[self]
	self.Prefab = prefab and PrefabMarkers[prefab]
end

if not Platform.developer then
	PrefabSourceInfo.SetPrefab = empty_func
end

AppendClass.FXSource = {
	__parents = { "PrefabSourceInfo" },
}
