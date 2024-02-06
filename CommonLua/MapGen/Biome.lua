if const.BiomeTileSize then
	DefineMapGrid("BiomeGrid", 16, const.BiomeTileSize, 64, config.EditableBiomeGrid and "save_in_map")
end

local max_value = 254
local height_scale = const.TerrainHeightScale
local height_max = const.MaxTerrainHeight
local type_tile = const.TypeTileSize
local wd_max = const.RandomMap.BiomeMaxWaterDist
local h_max, h_scale = height_max/height_scale, guim/height_scale
local min_sl, max_sl = const.RandomMap.BiomeMinSeaLevel/height_scale, const.RandomMap.BiomeMaxSeaLevel/height_scale
assert(guim % height_scale == 0)

BiomeMatchParams = {
	{ id = "Height",    name = "Height",        units = "(m)",   min = 0,         max = h_max,  default = 0, scale = h_scale, help = "Absolute height value on the map" },
	{ id = "Slope",     name = "Slope",         units = "(deg)", min = 0,         max = 90*60,  default = 0, scale = 60, help = "Slope angle: 0 flat, 90 vertical" },
	{ id = "Wet",       name = "Humidity",      units = "(%)",   min = 0,         max = 100,    default = 50, help = "Humidity % derived from erosion intensity" },
	{ id = "Hardness",  name = "Soil Hardness", units = "(%)",   min = 0,         max = 100,    default = 0, scale = 1, help = "Defines how much rigid is the soil agains erosion: 100% is solid rock without any erosion" },
	{ id = "Orient",    name = "Orientation",                    min = 0,         max = 1000,   default = 0, scale = 1000, help = "Slope orientation towards the sun: 0 Shadow, 1 Sunlit" },
	{ id = "SeaLevel",  name = "Sea Level",     units = "(m)",   min = min_sl,    max = max_sl, default = max_sl, scale = h_scale, help = "Height above or below Sea Level set it MapData" },
	{ id = "WaterDist", name = "Water Dist",    units = "(m)",   min = -wd_max,   max = wd_max, default = wd_max, scale = guim, help = "Distance in (-) or out (+) the water border line" },
}

function BiomeWaterDist(water_grid)
	if not water_grid then return end
	local dist_out = GridDest(water_grid)
	if GridIsFlat(water_grid) then
		local value = GridGet(water_grid, 0, 0)
		dist_out:clear(value == 0 and wd_max or -wd_max)
		return dist_out
	end
	GridInvert(water_grid)
	GridDistance(water_grid, dist_out, type_tile, wd_max)
	GridInvert(water_grid)
	local dist_in = GridDest(water_grid)
	GridDistance(water_grid, dist_in, type_tile, wd_max)
	local dist = GridAddMulDiv(dist_out, dist_in, -1)
	return dist
end

function BiomeMatchItems()
	local items = {}
	for _, param in ipairs(BiomeMatchParams) do
		items[#items + 1] = { value = param.id , text = param.name }
	end
	return items
end

DefineClass.Biome = {
	__parents = { "Preset", },
	properties = {
		{ category = "Biome", id = "grid_value",    name = "Grid Value",    editor = "number", default = 0, min = 0, max = max_value, read_only = true, help = "Value stored in the Biome grid" },
		{ category = "Biome", id = "palette_color", name = "Palette Color", editor = "color",  default = -16777216, },
		
		{ category = "Prefabs", id = "PrefabTypeWeights",      name = "Prefab Types",     editor = "nested_list", default = false, base_class = "BiomePrefabTypeWeight", inclusive = true },
		{ category = "Prefabs", id = "FilteredPrefabsPreview", name = "Filtered Prefabs", editor = "number",      default = 0, dont_save = true, read_only = true, },
		{ category = "Prefabs", id = "TypeMixingPreset",       name = "Mixing Pattern",   editor = "preset_id",   default = "", preset_class = "NoisePreset", },
		{ category = "Prefabs", id = "TypeMixingPreview",      name = "Mixing Preview",   editor = "grid",        default = false, no_edit = function(self) return self.TypeMixingPreset == "" end, frame = 1, min = 512, dont_save = true, read_only = true },
		
		{ category = "Matching", id = "CompareParam",  name = "Compare Param",    editor = "set",         default = empty_table, items = BiomeMatchItems, max_items_in_set = 1, dont_save = true },
	},
	EditorMenubarName = "Biomes",
	EditorMenubar = "Map.Generate",
	EditorIcon = "CommonAssets/UI/Icons/biology plants seed.png",
	EditorView = Untranslated("<id> <color 0 128 0><grid_value></color>"),
	StoreAsTable = false,
}

for _, match in ipairs(BiomeMatchParams) do
	local maxw = 200
	local id, name, units, min, max, scale, help = match.id, match.name, match.units or "", match.min, match.max, match.scale, match.help
	local function no_edit(self)
		local cmp_id = self:GetCompareId()
		return cmp_id and cmp_id ~= id
	end
	table.iappend(Biome.properties, {
		{ category = "Matching", id = id .. "From",   name = name .. " From " .. units, editor = "number", default = false, min = min, max = max,  scale = scale, no_edit = no_edit, slider = true, recalc_curve = id, help = help }, 
		{ category = "Matching", id = id .. "Best",   name = name .. " Best " .. units, editor = "number", default = false, min = min, max = max,  scale = scale, no_edit = no_edit, slider = true, recalc_curve = id, help = help },
		{ category = "Matching", id = id .. "To",     name = name .. " To " .. units,   editor = "number", default = false, min = min, max = max,  scale = scale, no_edit = no_edit, slider = true, recalc_curve = id, help = help },
		{ category = "Matching", id = id .. "Weight", name = name .. " Weight",         editor = "number", default = 100,   min = 0,   max = maxw, scale = 100, no_edit = no_edit, slider = true, recalc_curve = id }, 
		{ category = "Matching", id = id .. "Curve",  name = name .. " Curve",          editor = "grid",   default = false, dont_save = true, read_only = true, no_edit = no_edit, dont_normalize = true, frame = 1, help = help }, 
	})
	Biome["Get" .. id .. "Curve"] = function(self)
		return self[id .. "Curve"] or self["CalcCurve" .. id](self)
	end
	Biome["CalcCurve" .. id] = function(self, notify)
		local grid = self[id .. "Curve"]
		local w, h = 256, 64
		if not grid then
			grid = NewComputeGrid(w, h, "U", 8)
			self[id .. "Curve"] = grid
		end
		grid:clear()
		local weight, x_from, x_best, x_to = self[id .. "Weight"], self[id .. "From"], self[id .. "Best"], self[id .. "To"]
		local x0, x1 = x_from or min, x_to or max
		if not x_best or x_best >= x0 and x_best <= x1 then
			for gx = 0, w-1 do
				local x = min + MulDivRound(max - min, gx, w - 1)
				if x >= x0 and x <= x1 then
					local wi = weight
					if not x_best then
						--
					elseif x_from and x >= x0 and x < x_best then
						wi = MulDivRound(weight, x - x0, x_best - x0)
					elseif x_to and x <= x1 and x > x_best then
						wi = MulDivRound(weight, x1 - x, x1 - x_best)
					end
					local gy = MulDivRound(h - 1, maxw - wi, maxw)
					GridDrawColumn(grid, gx, gy, 255, 128)
				end
			end
		end
		if notify then
			ObjModified(self)
		end
		return grid
	end
end

AppendClass.MapDataPreset = { properties = {
	{ category = "Random Map", id = "BiomeGroup", editor = "choice",    default = "", items = PresetGroupsCombo("Biome") },
	{ category = "Random Map", id = "HeightMin",  editor = "number",    default = 10 * guim, scale = "m", min = 0, max = height_max, slider = true, help = "Value corresponding to black grayscale level" },
	{ category = "Random Map", id = "HeightMax",  editor = "number",    default = height_max - 10 * guim, scale = "m", min = 0, max = height_max, slider = true, help = "Value corresponding to white grayscale level" },
	{ category = "Random Map", id = "WetMin",     editor = "number",    default = 0, scale = "%", min = 0, max = 100, slider = true, help = "Value corresponding to black grayscale level" },
	{ category = "Random Map", id = "WetMax",     editor = "number",    default = 100, scale = "%", min = 0, max = 100, slider = true, help = "Value corresponding to white grayscale level" },
	{ category = "Random Map", id = "SeaLevel",   editor = "number",    default = 0, scale = "m", min = 0, max = height_max, slider = true },
	{ category = "Random Map", id = "SeaPreset",  editor = "preset_id", default = false, preset_class = "WaterObjPreset" },
	{ category = "Random Map", id = "SeaMinDist", editor = "number",    default = 32*guim, scale = "m", min = 0 },
	{ category = "Random Map", id = "MinBumpSlope",  editor = "number", default = 10*60, scale = "deg", min = 0, max = 90*60, slider = true },
	{ category = "Random Map", id = "MaxBumpSlope",  editor = "number", default = 40*60, scale = "deg", min = 0, max = 90*60, slider = true },
}}

function Biome:GetCompareId()
	return next(self.CompareParam)
end

function Biome:GetProperties()
	local compare_id = self:GetCompareId()
	if not compare_id then
		return self.properties
	end
	local props = table.icopy(self.properties)
	ForEachPreset("Biome", function(preset)
		if self.id ~= preset.id and self.group == preset.group then
			local id = preset.id .. "_Compare"
			props[#props + 1] = { category = "Compare", id = id,  name = preset.id, editor = "grid", default = false, dont_save = true, read_only = true, dont_normalize = true, frame = 1 }, 
			rawset(self, "Get" .. id, function()
				local getter = preset["Get" .. compare_id .. "Curve"]
				return getter and getter(preset)
			end)
		end
	end)
	return props
end

function Biome:GetFilteredPrefabs()
	local types = table.map(self.PrefabTypeWeights or empty_table, "PrefabType")
	types = table.invert(types)
	
	local result = {}
	for i,prefab in ipairs(PrefabMarkers) do
		if types[prefab.type] then
			table.insert(result, prefab.name)
		end
	end
	return result
end

function Biome:GetTypeMixingGrid(result, rand_seed, ptype_to_idx)
	local preset = NoisePresets[self.TypeMixingPreset]
	local weights = self.PrefabTypeWeights or empty_table
	if not preset or #weights < 2 then
		return false
	end
	
	local noise = GridDest(result)
	rand_seed = rand_seed and BraidRandom(rand_seed) or 0
	preset:GetNoise(rand_seed, noise)
	local weights_sum = 0
	for i=1,#weights do
		weights_sum = weights_sum + weights[i].Weight
	end
	local marks = 0
	local levels = GridLevels(noise)
	local histogram = {}
	for level, count in sorted_pairs(levels) do
		histogram[#histogram + 1] = {count, level}
	end
	local w, h = noise:size()
	local total_area = w * h
	local mask = GridDest(noise)
	local prev_level = -1
	local function Mark(level)
		marks = marks + 1
		local idx = not ptype_to_idx and marks or ptype_to_idx[weights[marks].PrefabType] or 0
		GridMask(noise, mask, prev_level + 1, level)
		prev_level = level
		GridPaint(result, mask, idx)
	end
	
	local idx, area, weight = 1, 0, 0
	for i=1,#weights-1 do
		weight = weight + weights[i].Weight
		local target_area = MulDivRound(total_area, weight, weights_sum)
		while idx <= #histogram do
			local entry = histogram[idx]
			area = area + entry[1]
			idx = idx + 1
			if area >= target_area then
				Mark(entry[2])
				break
			end
		end
	end
	Mark(max_int)
	return result
end

function Biome:__paste(...)
	local res = Preset.__paste(self, ...)
	res.grid_value = nil
	return res
end

function Biome:PostLoad()
	self:AssignValue()
	Preset.PostLoad(self)
end

function Biome:AssignValue()
	if self.grid_value > 0 then return end
	local value = 0
	ForEachPreset("Biome", function(p)
		value = Max(value, p.grid_value)
	end)
	if value < max_value then
		self.grid_value = value + 1
		return
	end
	local map = BiomeValueToPreset()
	for i=1,max_value do
		if not map[i] then
			self.grid_value = i
			return
		end
	end
	assert(false, "No more biome grid values available!")
	self.grid_value = -1
end

----

DefineClass.BiomePrefabTypeWeight = {
	__parents = { "PropertyObject" },
	properties = {
		{ id = "PrefabType", name = "Type",   editor = "preset_id", default = "",  preset_class = "PrefabType" },
		{ id = "Weight",     name = "Weight", editor = "number",    default = 100, min = 0, max = 100, slider = true },
	},
	EditorView = Untranslated("<PrefabType> (weight: <Weight>)"),
}

----

function BiomeValueToPreset()
	local map = {}
	ForEachPreset("Biome", function(preset, group, map)
		local value = preset.grid_value
		if value <= 0 then
			--
		elseif map[value] then
			print("Biome value", value, "collision", map[value].id, "/", preset.group, "-", preset.id)
		else
			map[value] = preset
		end
	end, map)
	return map
end

function DbgGetBiomePalette()
	local palette = {}
	ForEachPreset("Biome", function(preset)
		palette[preset.grid_value] = preset.palette_color
	end)
	palette[255] = RGBA(255, 255, 255, 128)
	return palette
end