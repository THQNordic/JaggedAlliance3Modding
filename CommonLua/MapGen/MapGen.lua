local height_scale = const.TerrainHeightScale
local height_tile = const.HeightTileSize
local height_max = const.MaxTerrainHeight
local type_tile = const.TypeTileSize
local developer = Platform.developer
local unity = 1000

local function print_concat(tbl)
	return table.concat(tbl, " ")
end

----

DefineClass.GridOpMapExport = {
	__parents = { "GridOpOutput" },
	GridOpType = "Map Export",
	operations = {"Type", "Height", "Biome", "Grass", "Water"}
}

function GridOpMapExport:GetGridOutput(state)
	local grid
	local op = self.Operation
	if op == "Height" then
		grid = terrain.GetHeightGrid()
	elseif op == "Type" then
		grid = terrain.GetTypeGrid()
	elseif op == "Grass" then
		grid = terrain.GetGrassGrid()
	elseif op == "Water" then
		grid = terrain.GetWaterGrid()
	elseif op == "Biome" then
		grid = BiomeGrid:clone()
	end
	if not grid then
		return "Export Grid Failed"
	end
	return nil, grid
end

function GridOpMapExport:GetEditorText()
	return "Export <Operation> to <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridOpMapImport = {
	__parents = { "GridOpInput" },
	properties = {
		{ category = "General", id = "TextureParam",   name = "Texture Param",    editor = "choice", default = "", items = GridOpParams, grid_param = true, optional = true, operation = "Type" },
		{ category = "General", id = "TextureType",    name = "Texture Type",     editor = "choice", default = "", items = GetTerrainNamesCombo(), use_param = "TextureParam", operation = "Type" },
		{ category = "General", id = "TexturePreview", name = "Texture Preview",  editor = "image",  default = false, img_size = 128, img_box = 1, dont_save = true, base_color_map = true, operation = "Type", no_edit = function(self) return self.TextureType == "" or self.UseParams and self.TextureParam ~= "" end },
		{ category = "General", id = "Alpha",          name = "Alpha",            editor = "number", default = unity, min = 0, max = unity, slider = true, scale = unity, operation = "Type" },
		{ category = "General", id = "Contrast",       name = "Contrast",         editor = "number", default = 0, min = -unity/2, max = unity/2, slider = true, scale = unity, operation = "Type" },
		{ category = "General", id = "Normalize",      name = "Normalize",        editor = "bool",   default = false, operation = {"Height", "Color"} },
		{ category = "General", id = "HeightMin",      name = "Height Min (m)",   editor = "number", default = 0, scale = guim, min = 0, max = height_max, slider = true, operation = "Height", enabled_by = "Normalize" },
		{ category = "General", id = "HeightMax",      name = "Height Max (m)",   editor = "number", default = height_max, scale = guim, min = 0, max = height_max, slider = true, operation = "Height", enabled_by = "Normalize" },
		{ category = "General", id = "ColorRed",       name = "Red",              editor = "number", default = 0, min = -unity, max = unity, scale = unity, slider = true, operation = "Color" },
		{ category = "General", id = "ColorGreen",     name = "Green",            editor = "number", default = 0, min = -unity, max = unity, scale = unity, slider = true, operation = "Color" },
		{ category = "General", id = "ColorBlue",      name = "Blue",             editor = "number", default = 0, min = -unity, max = unity, scale = unity, slider = true, operation = "Color" },
		{ category = "General", id = "ColorAlpha",     name = "Alpha",            editor = "number", default = unity, min = 0, max = unity, scale = unity, slider = true, operation = "Color" },
		{ category = "General", id = "MaskMin",        name = "Mask Min",         editor = "number", default = 0, scale = unity, operation = "Color", },
		{ category = "General", id = "MaskMax",        name = "Mask Max",         editor = "number", default = 100 * unity, scale = unity, operation = "Color", },
		
	},
	GridOpType = "Map Import",
	operations = {"Type", "Height", "Biome", "Grass", "Color"},
}

function GridOpMapImport:CollectTags(tags)
	tags.Terrain = true
	return GridOp.CollectTags(self, tags)
end

function GridOpMapImport:SetGridInput(state, grid)
	local success, err
	local op = self.Operation
	if op == "Height" then
		if not self.Normalize then
			local min, max = GridMinMax(grid)
			if min < 0 or max * height_scale > height_max then
				return "Height Limits Exceeded"
			end
			success, err = terrain.ImportHeightMap(grid)
		else
			success, err = terrain.ImportHeightMap(grid, self.HeightMin, self.HeightMax)
		end
		terrain.InvalidateHeight()
	elseif op == "Type" then
		local type_idx
		local type_name = self:GetValue("TextureType") or ""
		if type_name ~= "" then
			type_idx = GetTerrainTextureIndex(type_name)
			if not type_idx then
				return "No such terrain type: " .. type_name
			end
		end
		if not type_idx then
			err = terrain.SetTypeGrid(grid)
			success = not err
		else
			success = terrain.ImportTypeDithered{
				grid = GridRepack(grid, "F"),
				seed = state.rand,
				type = type_idx,
				gamma_mul = unity - self.Contrast,
				gamma_div = unity + self.Contrast,
				alpha_mul = self.Alpha,
				alpha_div = unity,
			}
		end
		terrain.InvalidateType()
	elseif op == "Biome" then
		BiomeGrid:copy(grid)
		success = true
	elseif op == "Grass" then
		success = terrain.SetGrassGrid(grid)
	elseif op == "Color" then
		local min, max = self.MaskMin, self.MaskMax
		local gmin, gmax = GridMinMax(grid, unity)
		if self.Normalize then
			min, max = gmin, gmax
		elseif min > gmin or max < gmax then
			return "Mask Limits Exceeded"
		end
		success = GridSetTerrainColor(grid, self.ColorRed, self.ColorGreen, self.ColorBlue, min, max, unity, self.ColorAlpha)
	end
	if not success then
		return err or "Map Import Failed"
	end
end

function GridOpMapImport:GetEditorText()
	local value = " "
	if self.Operation == "Type" then
		local type_str = self:GetValueText("TextureType", "")
		if type_str ~= "" then
			value = " " .. type_str .. " "
		end
	end
	local grid_str = self.InputName ~= "" and "from <GridOpName><InputName></GridOpName>" or ""
	return "Import <Operation>" .. value .. grid_str
end

function GridOpMapImport:GetTexturePreview()
	return GetTerrainTexturePreview(self.TextureType)
end

----

DefineClass.GridOpMapReset = {
	__parents = { "GridOp" },
	properties = {
		{ category = "General", id = "Type",          name = "Texture Type",   editor = "choice", default = "",      items = GetTerrainNamesCombo(), operation = "Type", help = "If not specified, the default invalid terrain will be used" },
		{ category = "General", id = "TypePreview",   name = "Preview",        editor = "image",  default = false,   img_size = 128, img_box = 1, base_color_map = true, dont_save = true, operation = "Type" },
		{ category = "General", id = "Height",        name = "Height",         editor = "number", default = 10*guim, min = 0, max = height_max, slider = true, scale = "m", operation = "Height" },
		{ category = "General", id = "Grass",         name = "Grass",          editor = "number", default = 0,       min = 0, max = 100, slider = true, operation = "Grass" },
		{ category = "General", id = "Color",         name = "Color",          editor = "color",  default = RGB(200, 200, 200), operation = "Color" },
		{ category = "General", id = "Overwrite",     name = "Overwrite",      editor = "bool",   default = false,   operation = "Backup" },
		{ category = "General", id = "DeleteObjects", name = "Delete Objects", editor = "bool",   default = true,    operation = "Backup" },
		{ category = "General", id = "FilterClass",   name = "Class",          editor = "text",   default = "",      operation = "Objects" },
		{ category = "General", id = "FilterFlagsAll",name = "Flags All",      editor = "set",    default = set("Generated"), items = {"Generated", "Permanent"}, operation = "Objects" },
		{ category = "General", id = "FilterFlagsAny",name = "Flags Any",      editor = "set",    default = set(),            items = {"Generated", "Permanent"}, operation = "Objects" },
		{ category = "General", id = "DeletedCount",  name = "Deleted",        editor = "number", default = 0,       operation = "Objects", read_only = true, dont_save = true },
		{ category = "General", id = "HeightMap",     name = "Height Map",     editor = "combo",  default = "",      items = GridOpOutputNames, grid_output = true, optional = true, operation = "Backup" },
		{ category = "General", id = "TypeMap",       name = "Type Map",       editor = "combo",  default = "",      items = GridOpOutputNames, grid_output = true, optional = true, operation = "Backup" },
	},
	GridOpType = "Map Reset",
	operations = {"Type", "Height", "Grass", "Biome", "Objects", "Color", "Backup"},
}

function GridOpMapReset:CollectTags(tags)
	local op = self.Operation
	if op == "Type" or op == "Height" or op == "Biome" or op == "Backup" then
		tags.Terrain = true
	end
	if op == "Objects" or op == "Backup" and self.DeleteObjects then
		tags.Objects = true
	end
	return GridOp.CollectTags(self, tags)
end

function GridOpMapReset:ResolveTerrainType()
	local ttype = self.Type or ""
	if not TerrainNameToIdx[ttype] then ttype = mapdata and mapdata.BaseLayer or "" end
	if not TerrainNameToIdx[ttype] then ttype = const.Prefab.InvalidTerrain or "" end
	if not TerrainNameToIdx[ttype] then ttype = TerrainTextures[0].id end
	return ttype
end

function GridOpMapReset:GetTypePreview()
	return GetTerrainTexturePreview(self:ResolveTerrainType())
end

local function CreatePath(path, param, ...)
	if not io.exists(path) then
		local err = AsyncCreatePath(path)
		if err then
			return false, err
		end
		SVNAddFile(path)
	end
	if not param then
		return path
	end
	return CreatePath(path .. "/" .. param, ...)
end

local function ExtractFlags(flags)
	local gameFlags = 0
	gameFlags = gameFlags + (flags.Generated and const.gofGenerated or 0)
	gameFlags = gameFlags + (flags.Permanent and const.gofPermanent or 0)
	return gameFlags ~= 0 and gameFlags or nil
end

function GridOpMapReset:Run()
	local success, err = true
	local op = self.Operation
	if op == "Type" then
		success = terrain.SetTerrainType{type = self:ResolveTerrainType()}
	elseif op == "Height" then
		success = terrain.SetHeight{height = self.Height}
	elseif op == "Biome" then
		BiomeGrid:clear()
		success = true
	elseif op == "Grass" then
		success = terrain.ClearGrassGrid(self.Grass)
	elseif op == "Color" then
		success = terrain.ClearColorizeGrid(self.Color)
	elseif op == "Objects" then
		local enumFlagsAll, enumFlagsAny
		local gameFlagsAll = ExtractFlags(self.FilterFlagsAll)
		local gameFlagsAny = ExtractFlags(self.FilterFlagsAny)
		if (self.FilterClass or "") == "" then
			self.DeletedCount = MapDelete(true, enumFlagsAll, enumFlagsAny, gameFlagsAll, gameFlagsAny)
		else
			self.DeletedCount = MapDelete(true, self.FilterClass, enumFlagsAll, enumFlagsAny, gameFlagsAll, gameFlagsAny)
		end
	elseif op == "Backup" then
		local trunc
		trunc, err = CreatePath("svnAssets/Source/MapGen", GetMapName())
		if err then
			return err
		end
		local overwrite = self.Overwrite
		local height_file = trunc .. "/height.grid"
		local height_exists = io.exists(height_file)
		local height_grid = not overwrite and height_exists and GridReadFile(height_file)
		if not height_grid then
			height_grid = terrain.GetHeightGrid()
			success, err = GridWriteFile(height_grid, height_file, true)
			if success and not height_exists then
				SVNAddFile(height_file)
			end
		else
			err = terrain.SetHeightGrid(height_grid)
			terrain.InvalidateHeight()
		end
		if err then
			return err
		end
		if self.HeightMap ~= "" then
			self:SetGridOutput(self.HeightMap, height_grid)
		end
		local type_file = trunc .. "/type.grid"
		local type_exists = io.exists(height_file)
		local type_grid = not overwrite and type_exists and GridReadFile(type_file)
		if not type_grid then
			type_grid = terrain.GetTypeGrid()
			success, err = GridWriteFile(type_grid, type_file, true)
			if success and not type_exists then
				SVNAddFile(type_file)
			end
		else
			err = terrain.SetTypeGrid(type_grid)
			terrain.InvalidateType()
		end
		if err then
			return err
		end
		if self.TypeMap ~= "" then
			self:SetGridOutput(self.TypeMap, type_grid)
		end
		if self.DeleteObjects then
			MapDelete("map", nil, nil, const.gofGenerated)
		end
		mapdata.IsPartialGen = true
	end
	if not success then
		return op .. " Reset Failed"
	end
end

function GridOpMapReset:GetEditorText()
	local value = ""
	local op = self.Operation
	if op == "Type" then
		value = "<GridOpValue><Type></GridOpValue>"
	elseif op == "Height" then
		value = "<GridOpValue><Height></GridOpValue>"
	elseif op == "Grass" then
		value = "<GridOpValue><Grass></GridOpValue>"
	elseif op == "Objects" then
		value = "<GridOpValue><FilterClass></GridOpValue>"
	end
	return "Reset <Operation> " .. value
end

----

DefineClass.GridOpMapSlope = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Units",        name = "Units",               editor = "choice", default = "degrees", items = {"", "degrees", "minutes", "radians", "normalized"} },
		{ category = "General", id = "SunAzimuth",   name = "Sun Azimuth (deg)",   editor = "number", default = 0, scale = 60, min = -180*60, max = 180*60, slider = true, operation = "Orientation", step = 60, buttons_step = 60,  },
		{ category = "General", id = "SunElevation", name = "Sun Elevation (deg)", editor = "number", default = 0, scale = 60, min = 0, max = 90*60, slider = true, operation = "Orientation", step = 60, buttons_step = 60 },
		{ category = "General", id = "Approx",       name = "Approximate",         editor = "bool",   default = true, help = "Computation speed at the cost of precision" },
	},
	GridOpType = "Map Slope",
	operations = {"Slope", "Orientation"},
	input_fmt = "F",
}

function GridOpMapSlope:GetGridOutputFromInput(state, grid)
	local res = GridDest(grid)
	local units_to_unity = {
		radians = 0,
		normalized = 1,
		degrees = 180,
		minutes = 180*60,
	}
	local unity = units_to_unity[self.Units]
	local apporx = self.Approx
	local op = self.Operation
	if op == "Slope" then
		GridSlope(grid, res, height_tile, height_scale)
		if unity then
			GridASin(res, apporx, unity)
		end
	elseif op == "Orientation" then
		GridOrientation(grid, res, height_tile, height_scale, self.SunAzimuth, self.SunElevation)
		if unity then
			GridACos(res, apporx, unity)
		end
	end
	return nil, res
end

function GridOpMapSlope:GetEditorText()
	return "Calc <Operation> of <GridOpName><InputName></GridOpName> in <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridOpMapParamType = {
	__parents = { "GridOpParam" },
	properties = {
		{ category = "General", id = "ParamValue",  name = "Type",    editor = "choice", default = "",    items = GetTerrainNamesCombo() },
		{ category = "General", id = "TypePreview", name = "Preview", editor = "image",  default = false, img_size = 128, img_box = 1, base_color_map = true, dont_save = true },
	},
	GridOpType = "Map Param Terrain Type",
}

function GridOpMapParamType:GetTypePreview()
	return GetTerrainTexturePreview(self.ParamValue)
end

----

DefineClass.GridOpMapParamColor = {
	__parents = { "GridOpParam" },
	properties = {
		{ category = "General", id = "ParamValue",  name = "Color", editor = "color",  default = white },
		{ category = "General", id = "R",           name = "R",     editor = "number", default = 0, min = 0, max = 255, slider = true, dont_save = true, buttons_step = 1 },
		{ category = "General", id = "G",           name = "G",     editor = "number", default = 0, min = 0, max = 255, slider = true, dont_save = true, buttons_step = 1 },
		{ category = "General", id = "B",           name = "B",     editor = "number", default = 0, min = 0, max = 255, slider = true, dont_save = true, buttons_step = 1 },
	},
	GridOpType = "Map Param Color",
}

function GridOpMapParamColor:GetParamStr()
	return string.format("%d %d %d", GetRGB(self.ParamValue))
end

function GridOpMapParamColor:SetParamValue(value)
	self.ParamValue = value
	self.R, self.G, self.B = GetRGB(value)
end

function GridOpMapParamColor:SetR(c) self:SetParamValue(SetR(self.ParamValue, c)) end
function GridOpMapParamColor:SetG(c) self:SetParamValue(SetG(self.ParamValue, c)) end
function GridOpMapParamColor:SetB(c) self:SetParamValue(SetB(self.ParamValue, c)) end

----

DefineClass.GridOpMapColorDist = {
	__parents = { "GridOpOutput" },
	properties = {
		{ category = "General", id = "GridR", name = "Input Name R", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
		{ category = "General", id = "GridG", name = "Input Name G", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
		{ category = "General", id = "GridB", name = "Input Name B", editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true },
		{ category = "General", id = "Color", name = "Color Value",  editor = "color",  default = white, alpha = false, use_param = true },
	},
	GridOpType = "Map Color Dist",
}

function GridOpMapColorDist:GetGridOutput(state)
	local err
	local cr, cg, cb = GetRGB(self:GetValue("Color"))
	local gr, gg, gb = self:GetGridInput(self.GridR), self:GetGridInput(self.GridG), self:GetGridInput(self.GridB)
	local mr, mg, mb = GridDest(gr), GridDest(gg), GridDest(gb)
	GridAdd(gr, mr, -cr)
	GridAdd(gg, mg, -cg)
	GridAdd(gb, mb, -cb)
	GridPow(mr, 2)
	GridPow(mg, 2)
	GridPow(mb, 2)
	GridAdd(mr, mg)
	GridAdd(mr, mb)
	GridPow(mr, 1, 2) -- sqrt
	return err, mr
end

function GridOpMapColorDist:GetEditorText()
	local color = self.UseParams and self.ColorParam ~= "" and "<GridOpParam><ColorParam></GridOpParam>" or "<GridOpValue>" .. string.format("%d %d %d", GetRGB(self.ColorValue)) .. "</GridOpValue>"
	return "Color Dist of " .. color .. " from <GridOpName><GridR></GridOpName> <GridOpName><GridG></GridOpName> <GridOpName><GridB></GridOpName> in <GridOpName><OutputName></GridOpName>"
end

----

DefineClass.GridInspect = {
	__parents = { "DebugOverlayControl" },
	properties = {
		{ category = "Debug", id = "AllowInspect", name = "Allow Inspect",     editor = "bool",   default = false, buttons = {{ name = "Toggle", func = "ToggleInspect" }} },
		{ category = "Debug", id = "OverlayAlpha", name = "Overlay Alpha (%)", editor = "number", default = 60,    slider = true, min = 0, max = 100, dont_save = true },
	},
	inspect_thread = false,
}

function GridInspect:GetInspectInfo()
end

function GridInspect:ToggleInspect()
	if IsValidThread(self.inspect_thread) then
		DbgStopInspect()
		DbgShowTerrainGrid(false)
		return
	end
	local grid, palette, callback = self:GetInspectInfo()
	if not grid then
		print("Inpsect grid not found!")
		return
	end
	DbgShowTerrainGrid(grid, palette)
	self.inspect_thread = DbgStartInspectPos(callback, grid)
end

function ToggleInspectDelayed(self)
	self:ToggleInspect()
end

function GridInspect:AutoStartInspect(state)
	if developer and state.run_mode == "Debug" and self.AllowInspect then
		DelayedCall(0, ToggleInspectDelayed, self)
	end
end

----

DefineClass.GridOpMapBiomeMatch = {
	__parents = { "GridOpOutput", "GridInspect" },
	properties = {
		{ category = "General", id = "BiomeGroup",     name = "Biome Group",    editor = "choice", default = "", items = PresetGroupsCombo("Biome"), use_param = true },
		{ category = "Preview", id = "Biomes",         name = "All Biomes",     editor = "number", default = 0, dont_save = true, read_only = true},
		{ category = "Debug",   id = "MatchedBiomes",  name = "Matched Biomes", editor = "text",   default = false, dont_save = true, lines = 10, max_lines = 10, text_style = "GedConsole" },
		{ category = "Debug",   id = "ClickPosition",  name = "Map Position",   editor = "point",  default = false, dont_save = true},
		{ category = "Debug",   id = "GridPosition",   name = "Grid Position",  editor = "point",  default = false, dont_save = true},
	},
	GridOpType = "Map Biome Match",
	input_fmt = "F",
	match_grids = false,
	match_biomes = false,
	bvalue_to_preset = false,
}

for _, match in ipairs(BiomeMatchParams) do
	local id, name, help = match.id, match.name, match.help
	table.iappend(GridOpMapBiomeMatch.properties, {
		{ category = "General", id = id .. "Map",  name = name .. " Match", editor = "combo", default = "", items = GridOpOutputNames, grid_input = true, optional = true, ignore_errors = true, help = help },
	})
end

function GridOpMapBiomeMatch:OnMoveCallback(pos)
	local biome_map = self.outputs[self.OutputName]
	if not biome_map then
		return
	end
	local mx, my = pos:xy()
	local bvalue, gx, gy = GridMapGet(biome_map, mx, my)
	local tmp = { "",
		print_concat{"map", DivToStr(mx, guim), ":", DivToStr(my, guim), "(m)"},
		print_concat{"grid", gx, ":", gy},
	}
	local biome_preset = self.bvalue_to_preset[bvalue]
	tmp[#tmp + 1] = print_concat{ "Biome", bvalue, biome_preset and biome_preset.id or "" }
	local grids = self.match_grids
	for i, params in ipairs(BiomeMatchParams) do
		local grid = grids[i]
		if grid then
			local v = GridMapGet(grid, mx, my, 1024)
			tmp[#tmp + 1] = print_concat{ params.id, DivToStr(v, params.scale), params.units }
		end
	end
	local h = #tmp
	for i=1,h do
		tmp[#tmp + 1] = ""
	end
	return table.concat(tmp, "\n")
end

function GridOpMapBiomeMatch:OnClickCallback(pos)
	local biome_map = self.outputs[self.OutputName]
	if not biome_map then
		return
	end
	local mx, my = pos:xy()
	self.ClickPosition = pos
	local _, gx, gy = GridMapGet(biome_map, mx, my)
	self.GridPosition = point(gx, gy)
	local err, biome_weights = BiomePosMatch(gx, gy, self.match_biomes, self.match_grids, BiomeMatchParams)
	local matched_dump_str
	if not err then
		local bvalue_to_preset = self.bvalue_to_preset
		table.sortby_field_descending(biome_weights, "weight")
		for i, entry in ipairs(biome_weights) do
			entry.value = bvalue_to_preset[entry.biome].id
		end
		local nweight = biome_weights[1].weight / 1000
		for i, entry in ripairs(biome_weights) do
			entry.weight = DivRound(entry.weight, nweight)
			if entry.weight == 0 then
				table.remove(biome_weights, i)
			end
		end
		local header = string.format("%20s | %6s", "Biome", "Weight")
		local line = "---------------------+--------"
		for _, entry in ipairs(BiomeMatchParams) do
			header = string.format("%s | %9s", header, entry.id)
			line = line .. "+-----------"
		end
		matched_dump_str = { header, line }
		for _, entry in ipairs(biome_weights) do
			local str = string.format("%20s | %6d", entry.value, entry.weight)
			for _, weight in ipairs(entry) do
				str = string.format("%s | %9d", str, weight)
			end
			matched_dump_str[#matched_dump_str + 1] = str
		end
		matched_dump_str = table.concat(matched_dump_str, "\n")
	end
	self.MatchedBiomes = matched_dump_str
	ObjModified(self)
end

function GridOpMapBiomeMatch:GetInspectInfo()
	local biome_map = self.outputs[self.OutputName]
	if not biome_map then
		return
	end
	local palette = DbgGetBiomePalette()
	self.bvalue_to_preset = BiomeValueToPreset()
	local function MoveCallback(pos)
		return self:OnMoveCallback(pos)
	end
	local function ClickCallback(pos)
		return self:OnClickCallback(pos)
	end
	return biome_map, palette, { MoveCallback, ClickCallback }
end
			
function GridOpMapBiomeMatch:GetGridOutput(state)
	local grids = {}
	for _, match in ipairs(BiomeMatchParams) do
		local prop_id = match.id .. "Map"
		local grid_name = self[prop_id]
		local grid = self:GetGridInput(grid_name)
		grids[#grids + 1] = grid or false
		if grid then
			local prec = 10
			local min, max = GridMinMax(grid, prec)
			if min < match.min * prec or max > match.max * prec then
				if min < match.min then
					print("Match grid", match.id, "is below its min:", min * 1.0 / prec, "<", match.min)
				else
					print("Match grid", match.id, "is above its max:", max * 1.0 / prec, ">", match.max)
				end
				return "Match grid out of bounds"
			end
		end
	end
	local match_group = self:GetValue("BiomeGroup") or ""
	if match_group == "" then
		return "Biome group not specified!"
	end
	state.BiomeGroup = match_group
	local biomes = {}
	ForEachPreset("Biome", function(preset)
		if preset.group == match_group then
			local biome = { preset.grid_value }
			for _, match in ipairs(BiomeMatchParams) do
				local id = match.id
				for _, prop in ipairs{"From", "To", "Best", "Weight"} do
					biome[#biome + 1] = preset[id .. prop]
				end
			end
			biomes[#biomes + 1] = biome
		end
	end)
	if #biomes == 0 then
		return "No biome presets found"
	end
	self.Biomes = #biomes
	local gw, gh = grids[1]:size()
	local biome_map = NewComputeGrid(gw, gh, "U", 8)
	biome_map:clear()
	local err = BiomeGridMatch(biome_map, biomes, grids, BiomeMatchParams)
	if err then
		return err
	end
	self.match_grids = grids
	self.match_biomes = biomes
	if developer then
		local x, y = GridFind(biome_map, 0)
		if x then
			local w, h = terrain.GetMapSize()
			StoreErrorSource(point(x * w / gw, y * h / gh), "Biome non matched!")
		end
	end
	self:AutoStartInspect(state)
	return nil, biome_map
end

----

DefineClass.GridOpMapPrefabTypes = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "AllowEmptyTypes", name = "Allow Empty Types", editor = "bool", default = false },
		{ category = "Preview", id = "PrefabsFound",    name = "Prefabs Found",     editor = "string_list", default = false, read_only = true, dont_save = true },
	},
	GridOpType = "Map Biome Prefab Types",
}

function GridOpMapPrefabTypes:GetGridOutputFromInput(state, grid)
	local levels = GridLevels(grid)
	local bvalue_to_preset = BiomeValueToPreset()
	local ptype_to_idx = table.invert(GetPrefabTypeList())
	local type_to_prefabs = PrefabTypeToPrefabs
	local allow_empty_types = self.AllowEmptyTypes
	local debug = state.run_mode ~= "GM"
	local biomes, ptypes = {}, {}
	for value, count in pairs(levels) do
		if value == 0 then
			goto continue
		end
		local preset = bvalue_to_preset[value]
		local weights = preset and preset.PrefabTypeWeights or empty_table
		local invalid_type
		local valid_weights = {}
		for _, pw in ipairs(weights) do
			local ptype = pw.PrefabType
			if not ptype_to_idx[ptype] then
				invalid_type = ptype
				break
			end
			if allow_empty_types or type_to_prefabs[ptype] then
				valid_weights[#valid_weights + 1] = pw
			end
		end
		if not preset then
			print("Missing preset with value:", value)
		elseif #weights == 0 then
			print("Biome without prefab types:", preset.id)
		elseif invalid_type then
			print("Biome", preset.id, "contains an invalid prefab type", invalid_type)
		elseif #weights > 1 and not NoisePresets[preset.TypeMixingPreset] then
			print("Biome", preset.id, "has an invalid mixing pattern", preset.TypeMixingPreset)
		elseif #valid_weights == 0 then
			print("Biome", preset.id, "doesn't match any prefabs")
		else
			biomes[#biomes + 1] = {
				preset = preset,
				count = count,
				weights = valid_weights,
			}
			if debug then
				for _, pw in ipairs(valid_weights) do
					ptypes[pw.PrefabType] = true
				end
			end
		end
		::continue::
	end
	
	if debug then
		local legend = {}
		for ptype in pairs(ptypes) do
			legend[#legend + 1] = string.format("%d. %s: %d", ptype_to_idx[ptype], ptype, #(type_to_prefabs[ptype] or empty_table))
		end
		table.sort(legend)
		self.PrefabsFound = legend
	end
			
	table.sort(biomes, function(a, b) return a.preset.grid_value < b.preset.grid_value end)
	local remap = {}
	local w, h = grid:size()
	local rand = state.rand
	for _, biome in ipairs(biomes) do
		local value = biome.preset.grid_value
		local valid_weights = biome.weights
		local weights = biome.preset.PrefabTypeWeights or empty_table
		if #valid_weights == 0 then
			-- continue
		elseif #weights > 1 then
			local type_mix = NewComputeGrid(w, h, "U", 16)
			rand = BraidRandom(rand)
			biome.preset:GetTypeMixingGrid(type_mix, rand, ptype_to_idx)
			remap[value] = type_mix
		else
			local type_idx = ptype_to_idx[weights[1].PrefabType]
			remap[value] = type_idx
		end
	end
	local mix_grid = NewComputeGrid(w, h, "U", 16)
	BiomeGridRemap(grid, mix_grid, remap)
	return nil, mix_grid
end

----

DefineClass.GridOpMapErosion = {
	__parents = { "GridOpInputOutput" },
	properties = {
		{ category = "General", id = "Iterations",    name = "Iterations",        editor = "number", default = 100,     min = 1 },
		{ category = "General", id = "DropSize",      name = "Drop Size (m)",     editor = "number", default = 10,      min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "Capacity",      name = "Capacity",          editor = "number", default = 10,      min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "Evaporation",   name = "Evaporation",       editor = "number", default = unity/2, min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "Solubility",    name = "Solubility",        editor = "number", default = 10,      min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "ThermalErosion",name = "Thermal Erosion",   editor = "number", default = 10,      min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "WindForce",     name = "Wind Force",        editor = "number", default = unity,   min = 0, max = unity, scale = unity, slider = true },
		{ category = "General", id = "TalusAngle",    name = "Talus Angle (deg)", editor = "number", default = 45*60,   min = 0, max = 90*60, scale = 60, slider = true },
		{ category = "General", id = "WaterMap",      name = "Water Map",         editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, grid_output = true, optional = true },
		{ category = "General", id = "SedimentMap",   name = "Sediment Map",      editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, grid_output = true, optional = true },
	},
	GridOpType = "Map Erosion",
}

function GridOpMapErosion:GetGridOutputFromInput(state, grid)
	local eroded = GridRepack(grid, "F", 32, true)
	local water = self:GetGridInput(self.WaterMap) or GridDest(eroded, true)
	local sediment = self:GetGridInput(self.SedimentMap) or GridDest(eroded, true)
	GridErosion(
		eroded, water, sediment, self.Iterations,
		self.DropSize, self.Capacity, self.Evaporation, self.Solubility,
		self.ThermalErosion, self.WindForce, self.TalusAngle,
		unity, state.rand)
	if self.WaterMap ~= "" then
		self:SetGridOutput(self.WaterMap, water)
	end
	if self.SedimentMap ~= "" then
		self:SetGridOutput(self.SedimentMap, sediment)
	end
	return nil, eroded
end

----

local def_tex = set("Main", "Noise", "Flow")
local function no_flow(self) return not self.Textures.Flow end
local function no_noise(self) return not self.Textures.Noise end

DefineClass.GridOpMapBiomeTexture = {
	__parents = { "GridOpInput", "GridInspect" },
	properties = {
		{ category = "General", id = "Textures",      name = "Textures",        editor = "set",    default = def_tex, items = {"Main", "Noise", "Flow"}, },
		{ category = "General", id = "FlowMap",       name = "Flow Map",        editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true, no_edit = no_flow },
		{ category = "General", id = "FlowMax",       name = "Flow Max",        editor = "number", default = 1, use_param = true, no_edit = no_flow },
		{ category = "General", id = "HeightMap",     name = "Height Map",      editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true, no_edit = no_noise },
		{ category = "General", id = "Transition",    name = "Transition",      editor = "bool",   default = true, },
		{ category = "General", id = "ApplyGrass",    name = "Apply Grass",     editor = "bool",   default = true, },
		{ category = "General", id = "GrassMap",      name = "Grass Map",       editor = "combo",  default = "", items = GridOpOutputNames, grid_input = true, optional = true, enabled_by = "ApplyGrass" },
		{ category = "General", id = "InvalidTerrain",name = "Invalid Terrain", editor = "choice", default = "", items = GetTerrainNamesCombo(), help = "If not specified, the default invalid terrain will be used" },
	},
	GridOpType = "Map Biome Import Textures",
	inspect_thread = false,
}

function GridOpMapBiomeTexture:CollectTags(tags)
	tags.Terrain = true
	return GridOp.CollectTags(self, tags)
end

function GridOpMapBiomeTexture:SetGridInput(state, grid)
	local invalid_terrain = self.InvalidTerrain or ""
	if invalid_terrain == "" then
		invalid_terrain = const.Prefab.InvalidTerrain or ""
	end
	local invalid_idx = invalid_terrain ~= "" and GetTerrainTextureIndex(invalid_terrain) or 0
	local ptype_list = GetPrefabTypeList()
	local type_presets, ptype_to_idx = {}, {}
	for i, ptype in ipairs(ptype_list) do
		if GridFind(grid, i) then
			type_presets[#type_presets + 1] = PrefabTypeToPreset[ptype]
			ptype_to_idx[ptype] = i
		end
	end
	table.sort(type_presets, function(a, b)
		local sa, sb = a.TexturingOrder, b.TexturingOrder
		if sa ~= sb then
			return sa < sb
		end
		local ta, tb = a.Transition, b.Transition
		if ta ~= tb then
			return ta > tb
		end
		return a.id < b.id
	end)
	local rand = state.rand
	local textures = self.Textures
	local flow_map = self:GetGridInput(self.FlowMap)
	local height_map = self:GetGridInput(self.HeightMap)
	local grass_map = self:GetGridInput(self.GrassMap)
	local marks, maski = GridDest(grid), GridDest(grid)
	local mask, noise, hmod
	local last_idx = 0
	local idx_to_type, idx_to_grass = {}, {}
	local function add_idx(type_idx, grass_mod)
		last_idx = last_idx + 1
		idx_to_type[last_idx] = type_idx
		idx_to_grass[last_idx] = grass_mod
		return last_idx
	end
	marks:clear()
	for i, type_preset in ipairs(type_presets) do
		local idx = ptype_to_idx[type_preset.id]
		GridMask(grid, maski, idx)
		if mask then
			GridRepack(maski, mask)
		else
			mask = GridRepack(maski, "F")
		end
		local transition = self.Transition and type_preset.Transition or 0
		if transition > 0 then
			GridNot(mask)
			GridDistance(mask, type_tile, transition)
			GridRemap(mask, 0, transition, 1, 0)
		end
		rand = BraidRandom(rand)
		local apply_config = { marks = marks, mask = mask, seed = rand }
		if textures.Main and type_preset.TextureMain ~= "" then
			local main_idx = GetTerrainTextureIndex(type_preset.TextureMain)
			if not main_idx then
				return "Invalid main terrain type: " .. type_preset.TextureMain
			end
			apply_config.main_idx = add_idx(main_idx, type_preset.GrassMain) 
		end
		if textures.Noise and type_preset.TextureNoise ~= "" then
			local noise_idx = GetTerrainTextureIndex(type_preset.TextureNoise)
			local noise_preset = NoisePresets[type_preset.NoisePreset]
			if not noise_preset then
				return "Noise preset missing: " .. type_preset.id
			elseif noise_preset.Min ~= 0 then
				return "Invalid noise preset: " .. type_preset.id
			elseif not noise_idx then
				return "Invalid noise terrain type: " .. type_preset.TextureNoise
			else
				rand = BraidRandom(rand)
				noise = noise or GridDest(mask)
				noise_preset:GetNoise(rand, noise)
				if type_preset.HeightModulated then
					if not height_map then
						return "Height map not provided!"
					end
					if not hmod then
						hmod = GridDest(noise)
						GridHeightMaskLevels(height_map, hmod)
					end
					noise = GridModulate(noise, hmod, hmod)
				end
				apply_config.noise = noise
				apply_config.noise_idx = add_idx(noise_idx, type_preset.GrassNoise) 
				apply_config.noise_max = noise_preset.Max
				apply_config.noise_stength = type_preset.NoiseStrength
				apply_config.noise_contrast = type_preset.NoiseContrast
			end
		end
		if textures.Flow and flow_map and type_preset.TextureFlow ~= "" then
			local flow_idx = GetTerrainTextureIndex(type_preset.TextureFlow)
			local flow_max = self:GetValue("FlowMax")
			if not flow_max then
				return "Undefined max flow value!"
			elseif not flow_idx then
				return "Invalid flow terrain type: " .. type_preset.TextureFlow
			end
			apply_config.flow = flow_map
			apply_config.flow_idx = add_idx(flow_idx, type_preset.GrassFlow)
			apply_config.flow_max = flow_max
			apply_config.flow_strength = type_preset.FlowStrength
			apply_config.flow_contrast = type_preset.FlowContrast
		end
		GridMarkPrefabTypeTerrain(apply_config)
	end
	if last_idx > 0 then
		if self.ApplyGrass then
			if not grass_map then
				return "Grass map expected"
			end
			GridModPrefabTypeGrass(marks, grass_map, idx_to_grass)
		end
		GridReplace(marks, idx_to_type, invalid_idx)
	else
		marks:clear(invalid_idx)
	end
	local err = terrain.SetTypeGrid(marks)
	if err then
		return err
	end
	terrain.InvalidateType()
	self:AutoStartInspect(state)
end

function GridOpMapBiomeTexture:GetInspectInfo()
	local grid = self.inputs[self.InputName]
	if not grid then
		return
	end
	local ptype_list = GetPrefabTypeList()
	local level_map = GridLevels(grid)
	local ptype_to_preset = PrefabTypeToPreset
	local palette = {}
	for ptype_idx in pairs(level_map) do
		local ptype = ptype_list[ptype_idx]
		local preset = ptype_to_preset[ptype]
		local color = preset and preset.OverlayColor or RandColor(xxhash(ptype))
		palette[ptype_idx] = color
	end
	local bvalue_to_preset = BiomeValueToPreset()
	return grid, palette, function(pos)
		local idx = terrain.GetTerrainType(pos)
		local texture = TerrainTextures[idx]
		local bvalue = BiomeGrid:get(pos)
		local biome_preset = bvalue_to_preset[bvalue]
		local ptype_idx = GridMapGet(grid, pos:xy())
		local ptype = ptype_list[ptype_idx]
		local tmp = {
			print_concat{"Texture", idx, texture and texture.id or ""},
			print_concat{"Prefab Type", ptype_idx, ptype or ""},
			print_concat{"Biome", bvalue, biome_preset and biome_preset.id or ""},
		}
		return table.concat(tmp, "\n")
	end
end

function OnMsg.GedPropertyEdited(_, obj, prop_id)
	local op_classes
	if IsKindOf(obj, "Biome") then
		local category = obj:GetPropertyMetadata(prop_id).category
		if category == "Prefabs" then
			return
		end
		op_classes = {"GridOpMapBiomeMatch", "GridOpMapPrefabTypes"}
	elseif IsKindOf(obj, "PrefabType") then
		op_classes = {"GridOpMapBiomeTexture"}
	else
		return
	end
	local proc, target
	ForEachPreset("MapGen", function(preset)
		if GedObjects[preset] then
			for _, op in ipairs(preset) do
				if not op.proc or not table.find(op_classes, op.class) then
					--
				elseif proc == op.proc then
					if not target or target.start_time > op.start_time then
						target = op
					end
				elseif not proc or proc.start_time < op.proc.start_time then
					proc = op.proc
					target = op
				end
			end
		end
	end)
	if target then
		target:Recalc()
	end
end

----

DefineClass.MapGen = {
	__parents = { "GridProcPreset" },
	GlobalMap = "MapGenProcs",
	EditorMenubarName = "Map Gen",
	EditorMenubar = "Map.Generate",
	EditorIcon = "CommonAssets/UI/Icons/gear option setting setup.png",
	EditorMapGenActions = {
		{ Menubar = "Action", Toolbar = "main", Name = "Open MapGen Folder", FuncName = "ActionOpenMapgenFolder", Icon = "CommonAssets/UI/Ged/explorer.tga", },
	},
}

function MapGen:GatherEditorCustomActions(actions)
	GridProcPreset.GatherEditorCustomActions(self, actions)
	table.iappend(actions, self.EditorMapGenActions)
end

function MapGen:GetSeedSaveDest()
	return "MapGenSeed", mapdata
end

function MapGen:RunOps(state, ...)
	if GetMap() == "" then
		return "No Map Loaded"
	end
	return GridProcPreset.RunOps(self, state, ...)
end

function GetMapGenSource(map_name)
	return string.format("svnAssets/Source/MapGen/%s/", map_name)
end

function MapGen:RunInit(state)
	if state.proc ~= self then
		return
	end
	local map_name = GetMapName() or ""
	if map_name == "" then
		return
	end
	Msg("MapGenStart", self)
	state.base_dir = GetMapGenSource(map_name)
	self:AddLog("Output dir: " .. state.base_dir, state)
	if state.tags.Pause then
		Pause("MapGen")
	end
	if state.tags.Terrain then
		SuspendTerrainInvalidations("MapGen")
	end
	if state.tags.Objects then
		NetPauseUpdateHash("MapGen")
		table.change(config, "MapGen", {
			PartialPassEdits = false,
			BillboardsSuspendInvalidate = true,
		})
		SuspendPassEdits("MapGen")
		DisablePassTypes()
		collision.Activate(false)
	end
	table.change(_G, "MapGen", {
		pairs = g_old_pairs,
		GetDiagnosticMessage = empty_func,
		DiagnosticMessageSuspended = true,
	})
	return GridProcPreset.RunInit(self, state)
end

function MapGen:InvalidateProc(state)
	if state.tags.Terrain then
		ResumeTerrainInvalidations("MapGen", true)
	end
end

function MapGen:RunDone(state)
	if state.proc ~= self then
		return
	end
	self:InvalidateProc(state)
	if state.tags.Objects then
		-- Hide editor objects shown after filter reset
		MapForEach(true, "EditorObject", function(obj)
			obj:ClearEnumFlags(const.efVisible)
		end)
		collision.Activate(true)
		ResumePassEdits("MapGen")
		table.restore(config, "MapGen", true)
		NetResumeUpdateHash("MapGen")
		XEditorFiltersReset()
		EnablePassTypes()
	end
	if state.tags.Pause then
		assert(IsPaused())
		Resume("MapGen")
	end
	table.restore(_G, "MapGen", true)
	Msg("MapGenDone", self)
	return GridProcPreset.RunDone(self, state)
end

function TestOcclude(pt0, hg, count)
	count = count or 1
	hg = hg or terrain.GetHeightGrid()
	--hg = GridResample(hg, 512, 512)
	--hg = GridRepack(hg, "F")
	local occlude = GridDest(hg)
	local gw, gh = hg:size()
	local mw, mh = terrain.GetMapSize()
	local goffset = 10*guim/height_scale
	while true do
		pt0 = pt0 or GetTerrainCursor()
		local x, y = pt0:xy()
		x, y = Clamp(x, 0, mw - 1), Clamp(y, 0, mh - 1)
		local pt = point(x, y)
		DbgClear()
		DbgAddCircle(pt, 5*guim)
		DbgAddVector(pt, 10*guim)
		if GridOccludeHeight(hg, occlude, x * gw / mw, y * gh / mh, goffset) then
			--GridNormalize(occlude, 0, 255) DbgShowTerrainGrid(occlude)
			terrain.SetHeightGrid(occlude) terrain.InvalidateHeight()
		end
		count = count - 1
		if count <= 0 then
			return pt0
		end
		while pt0 == GetTerrainCursor() do
			WaitNextFrame(1)
		end
		pt0 = GetTerrainCursor()
	end
end

function OccludePlayable(hg, eyeZ)
	hg = hg or terrain.GetHeightGrid()
	local st = GetPreciseTicks()
	eyeZ = eyeZ or 10*guim

	local border_divs, playable_divs = 8, 4
	local gw, gh = hg:size()
	local mw, mh = terrain.GetMapSize()
	local goffset = eyeZ / height_scale
	
	local occlude = GridDest(hg)
	local result = GridDest(hg)
	result:clear(height_max / height_scale)
	
	--DbgClearVectors()
	local function Occlude(gx, gy)
		--local mp = point(gx * mw / gw, gy * mh / gw); DbgAddVector(mp, eyeZ) DbgAddCircle(mp, eyeZ)
		if GridOccludeHeight(hg, occlude, gx, gy, goffset) then
			GridMin(result, occlude)
		end
	end
	
	local bbox = GetPlayBox()
	local minx, miny, maxx, maxy = bbox:xyxy()
	
	local pts = {{minx, miny}, {maxx - 1, miny}, {maxx - 1, maxy - 1}, {minx, maxy - 1}} -- box is exclusive
	local pt0 = pts[#pts]
	for _, pt1 in ipairs(pts) do
		local x0, y0, x1, y1 = pt0[1], pt0[2], pt1[1], pt1[2]
		for k = 1, border_divs do
			local x = x0 + (x1 - x0) * k / border_divs
			local y = y0 + (y1 - y0) * k / border_divs
			Occlude(x * gw / mw, y * gh / mh)
		end
		pt0 = pt1
	end
	local dx, dy = maxx - minx, maxy - miny
	local y0 = miny
	for i = 1, playable_divs do
		local y1 = miny + dy * i / playable_divs
		local x0 = minx
		for j = 1, playable_divs do
			local x1 = minx + dx * j / playable_divs
			local v, gx, gy = GridGetMaxHeight(hg, x0 * gw / mw, y0 * gw / mw, x1 * gw / mw, y1 * gw / mw)
			Occlude(gx, gy)
			x0 = x1
		end
		y0 = y1
	end
	
	return result
end

function OnMsg.ChangeMap()
	ForEachPreset("MapGen", function(preset)
		preset.run_state = nil
		for _, op in ipairs(preset) do
			op.inputs = nil
			op.outputs = nil
			op.params = nil
		end
	end)
end

function OnMsg.SaveMap()
	if LastGridProcDump == "" then
		return
	end
	CreateRealTimeThread(function(name, str)
		local filename = GetMap() .. LastGridProcName .. ".log"
		local err = AsyncStringToFile(filename, str)
		if err then
			print("Mapgen dump write error:", err)
		else
			local path = ConvertToOSPath(filename)
			print("Mapgen dump file saved to:", path)
		end
	end, LastGridProcName, LastGridProcDump)
	LastGridProcDump = ""
end

AppendClass.MapDataPreset = { properties = {
	{ category = "Random Map", id = "MapGenSeed", editor = "number", default = 0 },
}}